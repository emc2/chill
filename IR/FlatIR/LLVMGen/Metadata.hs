-- Copyright (c) 2013 Eric McCorkle.
--
-- This program is free software; you can redistribute it and/or
-- modify it under the terms of the GNU General Public License as
-- published by the Free Software Foundation; either version 2 of the
-- License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
-- 02110-1301 USA
{-# OPTIONS_GHC -Wall -Werror #-}

-- | This module contains code that generates LLVM Metadata describing
-- all the garbage collected objects.
module IR.FlatIR.LLVMGen.Metadata(
       genMetadata
       ) where

import Data.Array.IArray
import Data.Foldable
import Data.Graph.Inductive.Graph
import Data.Word
import IR.FlatIR.Syntax
import Prelude hiding (mapM_)

import qualified IR.GC.Types as GC
import qualified LLVM.Core as LLVM

-- XXX This is wrong
mutabilityValue :: GC.Mutability -> IO LLVM.ValueRef
mutabilityValue GC.Immutable = LLVM.mdString "const"
mutabilityValue GC.Mutable = LLVM.mdString "mutable"
mutabilityValue GC.WriteOnce = LLVM.mdString "writeonce"

mobilityValue :: GC.Mobility -> IO LLVM.ValueRef
mobilityValue GC.Mobile = LLVM.mdString "mobile"
mobilityValue GC.Immobile = LLVM.mdString "immobile"

ptrClassValue :: GC.PtrClass -> IO LLVM.ValueRef
ptrClassValue GC.Strong = LLVM.mdString "strong"
ptrClassValue GC.Soft = LLVM.mdString "soft"
ptrClassValue GC.Weak = LLVM.mdString "weak"
ptrClassValue GC.Finalizer = LLVM.mdString "final"
ptrClassValue GC.Phantom = LLVM.mdString "phantom"

-- Generate the metadata descriptors for all of the generated GC types
genMetadata :: Graph gr =>
               Module gr
            -- ^ The FlatIR module being translated
            -> LLVM.ModuleRef
            -- ^ The LLVM Module being created
            -> LLVM.ContextRef ->
            -- ^ The LLVM Context handle
               IO ()
genMetadata (Module { modGCHeaders = gcheaders, modGenGCs = gengcs,
                      modTypes = types}) llvmmod _ =
  let
    genFieldNode :: (String, GC.Mutability, Type) -> IO LLVM.ValueRef
    genFieldNode (str, mut, ty) =
      do
        namemd <- LLVM.mdString str
        mutmd <- mutabilityValue mut
        tymd <- genTypedesc ty
        LLVM.mdNode [ namemd, mutmd, tymd ]

    genTypedesc :: Type -> IO LLVM.ValueRef
    genTypedesc (StructType True fields) =
      do
        classmd <- LLVM.mdString "struct"
        packedmd <- LLVM.mdString "packed"
        fieldnodes <- mapM genFieldNode (elems fields)
        LLVM.mdNode (classmd : packedmd : fieldnodes)
    genTypedesc (StructType False fields) =
      do
        classmd <- LLVM.mdString "struct"
        packedmd <- LLVM.mdString "nonpacked"
        fieldnodes <- mapM genFieldNode (elems fields)
        LLVM.mdNode (classmd : packedmd : fieldnodes)
    genTypedesc (ArrayType (Just size) inner) =
      do
        classmd <- LLVM.mdString "array"
        innernode <- genTypedesc inner
        LLVM.mdNode [ classmd, LLVM.constInt LLVM.int64Type size False,
                      innernode ]
    genTypedesc (ArrayType Nothing inner) =
      do
        classmd <- LLVM.mdString "array"
        innernode <- genTypedesc inner
        LLVM.mdNode [ classmd,
                      LLVM.constInt LLVM.int64Type (0 :: Word) False,
                      innernode ]
    genTypedesc (PtrType (GC.Native inner)) =
      do
        classmd <- LLVM.mdString "nativeptr"
        innernode <- genTypedesc inner
        LLVM.mdNode [ classmd, innernode ]
    genTypedesc (PtrType (GC.GC ptrclass header)) =
      let
        (tname, mob, _) = gcheaders ! header
        (_, Just inner) = types ! tname
      in do
        classmd <- LLVM.mdString "gcptr"
        mobmd <- mobilityValue mob
        ptrclassmd <- ptrClassValue ptrclass
        innernode <- genTypedesc inner
        LLVM.mdNode [ classmd, ptrclassmd, mobmd, innernode ]
    genTypedesc (IntType _ size) =
      do
        classmd <- LLVM.mdString "int"
        LLVM.mdNode [ classmd, LLVM.constInt LLVM.int32Type size False ]
    genTypedesc (IdType tname) =
      let
        (str, _) = types ! tname
      in do
        classmd <- LLVM.mdString "named"
        mdstr <- LLVM.mdString str
        LLVM.mdNode [ classmd, mdstr ]
    genTypedesc (FloatType 32) =
      do
        classmd <- LLVM.mdString "float"
        LLVM.mdNode [ classmd ]
    genTypedesc (FloatType 64) =
      do
        classmd <- LLVM.mdString "double"
        LLVM.mdNode [ classmd ]
    genTypedesc (FloatType 128) =
      do
        classmd <- LLVM.mdString "fp128"
        LLVM.mdNode [ classmd ]
    genTypedesc (FloatType bits) =
      error ("Cannot generate " ++ show bits ++ "-bit floating point type")
    genTypedesc UnitType =
      error "Don't generate type descriptors for unit types"
    -- XXX This might not be right
    genTypedesc (FuncType _ _) =
      error "Cannot generate GC'ed function type signature"

    genHeaderMD :: GCHeader -> IO ()
    genHeaderMD header =
      let
        (tname, mob, mut) = gcheaders ! header
        (str, Just ty) = types ! tname
      in do
        typedesc <- genTypedesc ty
        mdstr <- LLVM.mdString str
        mobmd <- mobilityValue mob
        mutmd <- mutabilityValue mut
        mdnode <- LLVM.mdNode [ mdstr, mobmd, mutmd, typedesc ]
        LLVM.addNamedMetadataOperand llvmmod "core.gc.typedesc.md" mdnode
  in
    mapM_ genHeaderMD gengcs

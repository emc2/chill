-- Copyright (c) 2015 Eric McCorkle.
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
{-# OPTIONS_GHC -funbox-strict-fields -Wall -Werror #-}

module IR.Common.LValue(
       LValue(..)
       ) where

import IR.Common.Names

-- | An assignable value
data LValue exp =
  -- | An array (or pointer) index
    Index {
      -- | The indexed value.  Must be an array.
      idxVal :: exp,
      -- | The index value.  Must be an integer type.
      idxIndex :: exp,
      -- | The position in source from which this arises.
      idxPos :: !Position
    }
  -- | A field in a structure
  | Field {
      -- | The value whose field is being accessed.  Must be a
      -- structure type.
      fieldVal :: exp,
      -- | The name of the field being accessed.
      fieldName :: !Fieldname,
      -- | The position in source from which this arises.
      fieldPos :: !Position
    }
  -- | A form of a variant
  | Form {
      -- | The value whose field is being accessed.  Must be a
      -- structure type.
      formVal :: exp,
      -- | The name of the field being accessed.
      formName :: !Variantname,
      -- | The position in source from which this arises.
      formPos :: !Position
    }
  -- | Dereference a pointer
  | Deref {
      -- | The value being dereferenced.  Must be a pointer type.
      derefVal :: exp,
      -- | The position in source from which this arises.
      derefPos :: !Position
    }
  -- | A local value (local variable or argument)
  | Var {
      -- | The name of the local value.
      varName :: !Id,
      -- | The position in source from which this arises.
      varPos :: !Position
    }
  -- | A global value (global variable or function)
  | Global {
      -- | The name of the global value.
      globalName :: !Globalname,
      -- | The position in source from which this arises.
      globalPos :: !Position
    }

instance Eq1 LValue where
  Index { idxVal = val1, idxIndex = idx1 } ==#
    Index { idxVal = val2, idxIndex = idx2 } = val1 == val2 && idx1 == idx2
  Field { fieldVal = val1, fieldName = name1 } ==#
    Field { fieldVal = val2, fieldName = name2 } =
      val1 == val2 && name1 == name2
  Form { formVal = val1, formName = name1 } ==#
    Form { formVal = val2, formName = name2 } =
    val1 == val2 && name1 == name2
  Deref { derefVal = val1 } ==# Deref { derefVal = val2 } = val1 == val2
  Var { varName = name1 } ==# Var { varName = name2 } = name1 == name2
  Global { globalName = name1 } ==# Global { globalName = name2 } =
    name1 == name2
  _ ==# _ = False

instance Eq elem => Eq (LValue elem) where (==) = (==#)

instance Ord1 LValue where
  compare1 Index { idxVal = val1, idxIndex = idx1 }
          Index { idxVal = val2, idxIndex = idx2 } =
    case compare idx1 idx2 of
      EQ -> compare val1 val2
      out -> out
  compare1 Index {} _ = LT
  compare1 _ Index {} = GT
  compare1 Field { fieldVal = val1, fieldName = name1 }
          Field { fieldVal = val2, fieldName = name2 } =
    case compare name1 name2 of
      EQ -> compare val1 val2
      out -> out
  compare1 Field {} _ = LT
  compare1 _ Field {} = GT
  compare1 Form { formVal = val1, formName = name1 }
          Form { formVal = val2, formName = name2 } =
    case compare name1 name2 of
      EQ -> compare val1 val2
      out -> out
  compare1 Form {} _ = LT
  compare1 _ Form {} = GT
  compare1 Deref { derefVal = val1 } Deref { derefVal = val2 } =
    compare val1 val2
  compare1 Deref {} _ = LT
  compare1 _ Deref {} = GT
  compare1 Var { varName = name1 } Var { varName = name2 } = compare name1 name2
  compare1 Var {} _ = LT
  compare1 _ Var {} = GT
  compare1 Global { globalName = name1 } Global { globalName = name2 } =
    compare name1 name2

instance Ord elem => Ord (LValue elem) where compare = compare1

instance Hashable1 LValue where
  hashWithSalt1 s Index { idxVal = val, idxIndex = idx } =
    s `hashWithSalt` (1 :: Word) `hashWithSalt` val `hashWithSalt` idx
  hashWithSalt1 s Field { fieldVal = val, fieldName = name } =
    s `hashWithSalt` (2 :: Word) `hashWithSalt` val `hashWithSalt` name
  hashWithSalt1 s Form { formVal = val, formName = name } =
    s `hashWithSalt` (3 :: Word) `hashWithSalt` val `hashWithSalt` name
  hashWithSalt1 s Deref { derefVal = val } =
    s `hashWithSalt` (4 :: Word) `hashWithSalt`val
  hashWithSalt1 s Var { varName = name } =
    s `hashWithSalt` (5 :: Word) `hashWithSalt` name
  hashWithSalt1 s Global { globalName = name } =
    s `hashWithSalt` (6 :: Word) `hashWithSalt` name

instance Hashable elem => Hashable (LValue elem) where
  hashWithSalt = hashWithSalt1

instance RenameType Typename exp => RenameType Typename (LValue exp) where
  renameType f lval @ Index { idxVal = inner } =
    lval { idxVal = renameType f inner }
  renameType f lval @ Field { fieldVal = inner } =
    lval { fieldVal = renameType f inner }
  renameType f lval @ Form { formVal = inner } =
    lval { formVal = renameType f inner }
  renameType f lval @ Deref { derefVal = inner } =
    lval { derefVal = renameType f inner }
  renameType _ lval = lval

instance Rename Id exp => Rename Id (LValue exp) where
  rename f lval @ Index { idxVal = inner } = lval { idxVal = rename f inner }
  rename f lval @ Field { fieldVal = inner } =
    lval { fieldVal = rename f inner }
  rename f lval @ Form { formVal = inner } =
    lval { formVal = rename f inner }
  rename f lval @ Deref { derefVal = inner } =
    lval { derefVal = rename f inner }
  rename f lval @ Var { varName = name } = lval { varName = f name }
  rename _ lval = lval

instance Format exp => Format (LValue exp) where
  format (Index e i) = format e <+> brackets (formatExp i)
  format (Field (LValue (Deref e)) field) =
    format e <> "->" <> field
  format (Field e field) = format e <> "." <> field
  format Deref { derefVal = e } = "*" <+> format e
  format Global { globalName = g } = format g
  format Var { varName = v } = format v

instance FormatM exp => FormatM (LValue exp) where
  formatM (Index e i) = format e <+> brackets (formatExp i)
  formatM (Field (LValue (Deref e)) field) =
    format e <> "->" <> field
  formatM (Field e field) = format e <> "." <> field
  formatM Deref { derefVal = e } =
    do
      edoc <- formatM e
      return $! "*" <+> edoc
  formatM Global { globalName = g } = return $! format g
  formatM Var { varName = v } = return $! format v

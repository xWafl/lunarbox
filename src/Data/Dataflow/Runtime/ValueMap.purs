module Lunarbox.Data.Dataflow.Runtime.ValueMap
  ( ValueMap(..)
  ) where

import Prelude
import Data.Argonaut (class DecodeJson, class EncodeJson)
import Data.Default (class Default)
import Data.Map as Map
import Data.Newtype (class Newtype)
import Lunarbox.Data.Dataflow.Runtime.TermEnvironment (Term)

-- A map holding the runtime values of different locations
newtype ValueMap l
  = ValueMap (Map.Map l (Term l))

derive instance eqValueMap :: Eq l => Eq (ValueMap l)

derive instance newtypeValueMap :: Newtype (ValueMap l) _

instance semigroupValueMap :: Ord l => Semigroup (ValueMap l) where
  append (ValueMap m) (ValueMap m') = ValueMap $ append m m'

derive newtype instance monoidValueMap :: Ord l => Monoid (ValueMap l)

derive newtype instance encodeJsonValueMap :: (EncodeJson l, Ord l) => EncodeJson (ValueMap l)

derive newtype instance decodeJsonValueMap :: (DecodeJson l, Ord l) => DecodeJson (ValueMap l)

instance defaultValueMap :: Default (ValueMap l) where
  def = ValueMap $ Map.empty

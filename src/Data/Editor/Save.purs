module Lunarbox.Data.Editor.Save
  ( stateToJson
  , jsonToState
  ) where

import Prelude
import Data.Argonaut (Json, decodeJson, encodeJson, (.:))
import Data.Either (Either)
import Effect.Unsafe (unsafePerformEffect)
import Lunarbox.Data.Dataflow.Native.Prelude (loadPrelude)
import Lunarbox.Data.Editor.State (State, StatePermanentData, compile, emptyState, nodeCount, visualFunctionCount)
import Lunarbox.Data.ProjectList (ProjectData)
import Record as Record

type Save
  = { 
    | ProjectData
      ( project :: { | StatePermanentData () }
      , isExample :: Boolean
      , visible :: Boolean
      )
    }

-- Encoding and decoding
stateToJson :: forall a s m. State a s m -> Json
stateToJson state@{ project
, nextId
, geometries
, runtimeOverwrites
, isExample
, name
, isVisible
, currentFunction
} = encodeJson save
  where
  save :: Save
  save =
    { name
    , isExample
    , visible: isVisible
    , metadata:
      { nodeCount: nodeCount state
      , functionCount: visualFunctionCount state
      }
    , project:
      { project
      , nextId
      , geometries
      , runtimeOverwrites
      , currentFunction
      }
    }

jsonToState :: forall a s m. Json -> Either String (State a s m)
jsonToState json = do
  obj <- decodeJson json
  name :: String <- obj .: "name"
  isExample :: Boolean <- obj .: "isExample"
  isVisible :: Boolean <- obj .: "visible"
  saveData :: { | StatePermanentData () } <- obj .: "project"
  let
    recivedData = Record.merge { name, isExample, isVisible } saveData

    -- TODO: this is pretty low priority but maybe I could get rid of the call to
    -- unsafePerformEffect by making the whole function return an effect
    baseState :: State a s m
    baseState = Record.merge recivedData $ unsafePerformEffect emptyState
  pure $ compile $ loadPrelude baseState

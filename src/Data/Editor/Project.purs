module Lunarbox.Data.Editor.Project where

import Prelude
import Data.Lens (Lens', Traversal', _1, _2, over, view)
import Data.Lens.At (at)
import Data.Lens.Index (ix)
import Data.Lens.Record (prop)
import Data.Maybe (Maybe(..))
import Data.Newtype (class Newtype)
import Data.Set as Set
import Data.Symbol (SProxy(..))
import Data.Tuple (Tuple(..), fst)
import Data.Unfoldable (class Unfoldable)
import Lunarbox.Data.Dataflow.Expression (Expression)
import Lunarbox.Data.Dataflow.FunctionName (FunctionName(..))
import Lunarbox.Data.Dataflow.Graph (ExtendedLocation, compileGraph)
import Lunarbox.Data.Dataflow.NodeId (NodeId)
import Lunarbox.Data.Editor.DataflowFunction (DataflowFunction(..), _VisualFunction)
import Lunarbox.Data.Editor.Node (Node(..))
import Lunarbox.Data.Editor.NodeGroup (NodeGroup(..), _NodeGroupNodes)
import Lunarbox.Data.Graph as G
import Lunarbox.Data.Lens (newtypeIso)

newtype Project f n
  = Project
  { functions :: G.Graph FunctionName (Tuple (DataflowFunction n) f)
  , main :: FunctionName
  }

derive instance newtypeProject :: Newtype (Project f n) _

_ProjectFunctions :: forall f n. Lens' (Project f n) (G.Graph FunctionName (Tuple (DataflowFunction n) f))
_ProjectFunctions = newtypeIso <<< prop (SProxy :: _ "functions")

_ProjectMain :: forall f n. Lens' (Project f n) FunctionName
_ProjectMain = newtypeIso <<< prop (SProxy :: _ "main")

compileProject :: forall f n. Project f n -> Expression (ExtendedLocation FunctionName NodeId)
compileProject project = compileGraph (view _ProjectMain project) $ fst <$> view _ProjectFunctions project

createEmptyFunction :: forall a. a -> NodeId -> DataflowFunction a
createEmptyFunction data' id =
  VisualFunction
    $ NodeGroup
        { inputs: mempty
        , nodes: G.singleton id $ Tuple (OutputNode Nothing) data'
        , output: id
        }

emptyProject :: forall f n. Monoid f => Monoid n => NodeId -> Project f n
emptyProject id =
  Project
    { main: FunctionName "main"
    , functions: G.singleton (FunctionName "main") $ Tuple function mempty
    }
  where
  function = createEmptyFunction mempty id

createFunction :: forall f n. f -> n -> FunctionName -> NodeId -> Project f n -> Project f n
createFunction functionData nodeData name outputId =
  over
    _ProjectFunctions
    $ G.insert name (Tuple function functionData)
  where
  function = createEmptyFunction nodeData outputId

getFunctions :: forall u a b. Unfoldable u => Project a b -> u FunctionName
getFunctions = Set.toUnfoldable <<< G.keys <<< view _ProjectFunctions

_atProjectFunction :: forall f n. FunctionName -> Traversal' (Project f n) (Maybe (Tuple (DataflowFunction n) f))
_atProjectFunction name = _ProjectFunctions <<< at name

_projectNodeGroup :: forall f n. FunctionName -> Traversal' (Project f n) (NodeGroup n)
_projectNodeGroup name = _ProjectFunctions <<< ix name <<< _1 <<< _VisualFunction

_atProjectNode :: forall f n. FunctionName -> NodeId -> Traversal' (Project f n) (Maybe (Tuple Node n))
_atProjectNode name id = _projectNodeGroup name <<< _NodeGroupNodes <<< at id

_projectFunctionData :: forall f n. FunctionName -> Traversal' (Project f n) f
_projectFunctionData name = _ProjectFunctions <<< ix name <<< _2

module Lunarbox.Component.Editor where

import Prelude
import Control.Monad.Reader (class MonadReader)
import Control.Monad.State (get, modify_)
import Control.MonadZero (guard)
import Data.Maybe (Maybe(..))
import Data.Symbol (SProxy(..))
import Effect.Class (class MonadEffect)
import Halogen (ClassName(..), Component, HalogenM, Slot, defaultEval, mkComponent, mkEval, query)
import Halogen.HTML as HH
import Halogen.HTML.Events (onClick)
import Halogen.HTML.Properties (classes, id_)
import Halogen.HTML.Properties as HP
import Lunarbox.Component.Editor.Scene as Scene
import Lunarbox.Component.Editor.Tree as TreeC
import Lunarbox.Component.Icon (icon)
import Lunarbox.Component.Utils (container)
import Lunarbox.Config (Config)
import Lunarbox.Data.Project (FunctionName, NodeId(..), Project, createFunction, emptyProject, getFunctions)

data Tab
  = Settings
  | Add
  | Tree
  | Problems

derive instance eqTab :: Eq Tab

tabIcon :: Tab -> String
tabIcon = case _ of
  Settings -> "settings"
  Add -> "add"
  Tree -> "account_tree"
  Problems -> "error"

type State
  = { currentTab :: Tab
    , panelIsOpen :: Boolean
    , project :: Project
    , nextId :: Int
    , currentFunction :: Maybe FunctionName
    }

data Action
  = ChangeTab Tab
  | CreateFunction FunctionName
  | SelectFunction (Maybe FunctionName)
  | StartFunctionCreation

data Query a
  = Void

type ChildSlots
  = ( scene :: Slot Scene.Query Void Unit
    , tree :: Slot TreeC.Query TreeC.Output Unit
    )

component :: forall m. MonadEffect m => MonadReader Config m => Component HH.HTML Query {} Void m
component =
  mkComponent
    { initialState:
        const
          { currentTab: Settings
          , panelIsOpen: false
          , project: emptyProject $ NodeId $ "firstOutput"
          , nextId: 0
          , currentFunction: Nothing
          }
    , render
    , eval:
        mkEval
          $ defaultEval
              { handleAction = handleAction
              }
    }
  where
  createId :: HalogenM State Action ChildSlots Void m NodeId
  createId = do
    { nextId } <- get
    modify_ (_ { nextId = nextId + 1 })
    pure $ NodeId $ show nextId

  handleAction :: Action -> HalogenM State Action ChildSlots Void m Unit
  handleAction = case _ of
    ChangeTab tab -> do
      modify_
        ( \state@{ panelIsOpen: open, currentTab } ->
            state
              { currentTab = tab
              , panelIsOpen =
                if (currentTab == tab) then
                  not open
                else
                  open
              }
        )
    CreateFunction name -> do
      id <- createId
      modify_ (\state@{ project } -> state { project = createFunction name id project })
      pure unit
    StartFunctionCreation -> do
      void $ query (SProxy :: _ "tree") unit (TreeC.StartCreation unit)
    SelectFunction function -> do
      modify_ (_ { currentFunction = function })
      void $ query (SProxy :: _ "scene") unit (Scene.SelectFunction function)

  handleTreeOutput :: TreeC.Output -> Maybe Action
  handleTreeOutput = case _ of
    TreeC.CreatedFunction name -> Just $ CreateFunction name
    TreeC.SelectedFunction name -> Just $ SelectFunction name

  sidebarIcon activeTab current =
    HH.div
      [ classes $ ClassName <$> [ "sidebar-icon" ] <> (guard isActive $> "active")
      , onClick $ const $ Just $ ChangeTab current
      ]
      [ icon iconName ]
    where
    iconName = tabIcon current

    isActive = current == activeTab

  tabs currentTab =
    [ icon Settings
    , icon Add
    , icon Tree
    , icon Problems
    ]
    where
    icon = sidebarIcon currentTab

  panel { currentTab, project, currentFunction } = case currentTab of
    Settings ->
      container "panel-container"
        [ container "title" [ HH.text "Project settings" ]
        ]
    Tree ->
      container "panel-container"
        [ container "title" [ HH.text "Explorer" ]
        , container "tree"
            [ container "actions"
                [ HH.hr [ HP.id_ "line" ]
                , HH.div [ onClick $ const $ Just StartFunctionCreation ] [ icon "note_add" ]
                ]
            , HH.slot (SProxy :: _ "tree") unit TreeC.component
                { functions: getFunctions project, selected: currentFunction
                }
                handleTreeOutput
            ]
        ]
    _ -> HH.text "not implemented"

  render s@{ currentTab, panelIsOpen, project, currentFunction } =
    container "editor"
      [ container "sidebar"
          $ tabs currentTab
      , HH.div
          [ id_ "panel", classes $ ClassName <$> (guard panelIsOpen $> "active") ]
          [ panel s ]
      , container "scene"
          [ HH.slot (SProxy :: _ "scene") unit Scene.component { project, currentFunction } absurd ]
      ]

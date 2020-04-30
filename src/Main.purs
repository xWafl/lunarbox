module Main where

import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Effect.Aff (Aff, launchAff_)
import Effect.Aff.Bus as Bus
import Effect.Class (liftEffect)
import Effect.Ref as Ref
import Halogen (Component, hoist, tell)
import Halogen.Aff (awaitBody, runHalogenAff)
import Halogen.HTML (HTML)
import Halogen.VDom.Driver (runUI)
import Lunarbox.Api.Request (BaseUrl(..), profile)
import Lunarbox.AppM (runAppM)
import Lunarbox.Component.Router as Router
import Lunarbox.Config (Config(..))
import Lunarbox.Control.Monad.Effect (printString)
import Lunarbox.Data.Route (parseRoute)
import Prelude (Unit, Void, bind, discard, void, when, ($), (/=))
import Routing.PushState (makeInterface, matchesWith)

baseUrl :: BaseUrl
baseUrl = BaseUrl "http://localhost:8090"

main :: Effect Unit
main =
  runHalogenAff do
    currentUser <- liftEffect $ Ref.new Nothing
    -- Bus to store the current user profile
    userBus <- liftEffect $ Bus.make
    -- Request the current suer
    responseWithError <- profile baseUrl
    case responseWithError of
      Left err -> do
        printString err
        liftEffect $ Ref.write Nothing currentUser
      Right user -> liftEffect $ Ref.write (Just user) currentUser
    -- create a routing interface
    nav <- liftEffect makeInterface
    -- wait for the body to be created
    body <- awaitBody
    -- TODO: make this depend on some .env file
    let
      env :: Config
      env =
        Config
          { devOptions: Just { cancelInputsOnBlur: true }
          , baseUrl
          , pushStateInterface: nav
          , user:
            { currentUser
            , userBus
            }
          }

      rootComponent :: Component HTML Router.Query {} Void Aff
      rootComponent = hoist (runAppM env) Router.component
    halogenIO <- runUI rootComponent {} body
    let
      onRouteChange = \old new ->
        when (old /= Just new) do
          launchAff_ $ halogenIO.query $ tell $ Router.Navigate new
    void $ liftEffect $ matchesWith parseRoute onRouteChange nav

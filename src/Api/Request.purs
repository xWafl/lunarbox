module Lunarbox.Api.Request where

import Prelude
import Affjax (Request, printError, request)
import Affjax.RequestBody as RB
import Affjax.ResponseFormat as RF
import Affjax.StatusCode (StatusCode(..))
import Data.Argonaut (Json, decodeJson, encodeJson)
import Data.Bifunctor (lmap)
import Data.Either (Either(..))
import Data.HTTP.Method (Method(..))
import Data.Maybe (Maybe(..))
import Data.Tuple (Tuple(..))
import Effect.Aff.Class (class MonadAff, liftAff)
import Lunarbox.Api.Endpoint (Endpoint(..), endpointCodec)
import Lunarbox.Data.Profile (Email, Profile, Username(..))
import Lunarbox.Data.Utils (decodeAt)
import Routing.Duplex (print)

-- Possible methods we can perform
data RequestMethod
  = Get
  | Post (Maybe Json)
  | Put (Maybe Json)
  | Delete

-- The options we pass to out defaultRequest function
type RequestOptions
  = { endpoint :: Endpoint
    , method :: RequestMethod
    }

-- Url to send requests to
newtype BaseUrl
  = BaseUrl String

-- Default request we can reuse troughout the app
defaultRequest :: BaseUrl -> RequestOptions -> Request Json
defaultRequest (BaseUrl baseUrl) { endpoint, method } =
  { method: Left method
  , url: baseUrl <> print endpointCodec endpoint
  , content: RB.json <$> body
  , username: Nothing
  , password: Nothing
  , withCredentials: true
  , responseFormat: RF.json
  , headers: []
  }
  where
  Tuple method body = case method of
    Get -> Tuple GET Nothing
    Post b -> Tuple POST b
    Put b -> Tuple PUT b
    Delete -> Tuple DELETE Nothing

-- Basically an identity type
type Unlifted a
  = a

-- Now we can define a shared row for various requests which manage user credentials. And the
-- password field can be a `Maybe String` or a `String`, depending on what we need!
type AuthFieldsRep box r
  = ( email :: Email, password :: box String | r )

type RegisterFields
  = { | AuthFieldsRep Unlifted ( username :: Username ) }

type LoginFields
  = { | AuthFieldsRep Unlifted () }

login :: forall m. MonadAff m => BaseUrl -> LoginFields -> m (Either String Profile)
login baseUrl fields = response $> Right { username: Username "wait for bg to fix this" }
  where
  response =
    requestJson baseUrl
      { endpoint: Login, method: Post $ Just $ encodeJson fields
      }

register :: forall m. MonadAff m => BaseUrl -> RegisterFields -> m (Either String Profile)
register baseUrl fields = response $> Right { username: fields.username }
  where
  response =
    requestJson baseUrl
      { endpoint: Register, method: Post $ Just $ encodeJson fields
      }

-- Get the current signed in profile
profile :: forall m. MonadAff m => BaseUrl -> m (Either String Profile)
profile baseUrl = requestUser baseUrl { endpoint: Profile, method: Get }

-- Helper for requests which only care about the body and the status being 200
requestJson :: forall m. MonadAff m => BaseUrl -> RequestOptions -> m (Either String Json)
requestJson baseUrl opts = do
  res <- liftAff $ request $ defaultRequest baseUrl opts
  pure do
    response <- lmap printError res
    case response.status of
      StatusCode 200 -> pure response.body
      _ -> Left =<< decodeAt "message" response.body

-- | The login and registration requests share the same underlying implementation, just a different
-- | endpoint. This function can be re-used by both requests.
requestUser :: forall m. MonadAff m => BaseUrl -> RequestOptions -> m (Either String Profile)
requestUser baseUrl opts = requestJson baseUrl opts <#> (_ >>= decodeJson)
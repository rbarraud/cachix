{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE TypeOperators #-}

module Cachix.Api
  ( api
  , servantApi
  , swaggerDoc
  , CachixAPI(..)
  , BinaryCacheAPI(..)
  , CachixServantAPI
  , module Cachix.Api.Types
  , module Cachix.Types.ContentTypes
  ) where

import Control.Lens

import Data.Proxy (Proxy(..))
import Data.Swagger hiding (Header)
import Data.Text
import GHC.Generics (Generic)
import Network.AWS (AWS)
import Servant.API
import Servant.Auth
import Servant.API.Generic
import Servant.Streaming
import Servant.Swagger
import Servant.Swagger.UI.Core   (SwaggerSchemaUI)
import Web.Cookie                (SetCookie)

import Cachix.Types.ContentTypes
import Cachix.Types.Servant      (Get302, Post302, Head)
import Cachix.Types.Session      (Session)
import Cachix.Api.Types
import Cachix.Api.Swagger        ()


type CachixAuth = Auth '[Cookie,JWT] Session

data BinaryCacheAPI route = BinaryCacheAPI
  { get :: route :-
      Get '[JSON] BinaryCache
  , create :: route :-
      CachixAuth :>
      ReqBody '[JSON] BinaryCacheCreate :>
      Post '[JSON] NoContent
  -- https://cache.nixos.org/nix-cache-info
  , nixCacheInfo :: route :-
      "nix-cache-info" :>
      Get '[XNixCacheInfo, JSON] NixCacheInfo
  -- Hydra: src/lib/Hydra/View/NixNAR.pm
  , nar :: route :-
      "nar" :>
      Capture "nar" NarC :>
      StreamResponseGet '[XNixNar, JSON]
  , createNar :: route :-
      "nar" :>
      StreamBodyMonad '[XNixNar, JSON] AWS :>
      Post '[JSON] NoContent
  -- Hydra: src/lib/Hydra/View/NARInfo.pm
  , narinfo :: route :-
      Capture "narinfo" NarInfoC :>
      Get '[XNixNarInfo, JSON] NarInfo
  , narinfoHead :: route :-
      Capture "narinfo" NarInfoC :>
      Head
  , createNarinfo :: route :-
      Capture "narinfo" NarInfoC :>
      ReqBody '[JSON] NarInfoCreate :>
      Post '[JSON] NoContent
  } deriving Generic

data CachixAPI route = CachixAPI
   { logout :: route :-
       "logout" :>
       CachixAuth :>
       Post302 '[JSON] '[ Header "Set-Cookie" SetCookie
                        , Header "Set-Cookie" SetCookie
                        ]
   , login :: route :-
       "login" :>
       Get302 '[JSON] '[]
   , loginCallback :: route :-
       "login" :>
       "callback" :>
       QueryParam "code" Text :>
       QueryParam "state" Text :>
       Get302 '[JSON] '[ Header "Set-Cookie" SetCookie
                       , Header "Set-Cookie" SetCookie
                       ]
   , user :: route :-
      CachixAuth :>
      "user" :>
      Get '[JSON] User
   , createToken :: route :-
      CachixAuth :>
      "token" :>
       Post '[JSON] Text
   , caches :: route :-
       CachixAuth :>
       "cache" :>
       Get '[JSON] [BinaryCache]
   , cache :: route :-
       "cache" :>
       Capture "name" Text :>
       ToServantApi BinaryCacheAPI
   } deriving Generic

type CachixServantAPI = "api" :> "v1" :> ToServantApi CachixAPI

servantApi :: Proxy CachixServantAPI
servantApi = Proxy

type API = CachixServantAPI
   :<|> "api" :> SwaggerSchemaUI "v1" "swagger.json"

api :: Proxy API
api = Proxy

swaggerDoc :: Swagger
swaggerDoc = toSwagger servantApi
    & info.title       .~ "cachix.org API"
    & info.version     .~ "1.0"
    & info.description ?~ "TODO"

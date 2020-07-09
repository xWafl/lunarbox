module Lunarbox.Component.Editor.Problems where

import Prelude
import Data.Filterable (filterMap)
import Data.Maybe (Maybe(..))
import Halogen.HTML as HH
import Lunarbox.Component.Icon (icon)
import Lunarbox.Component.Utils (className)
import Lunarbox.Data.Dataflow.TypeError (TypeError, getLocation, printError)
import Lunarbox.Data.Editor.Location (Location(..))
import Lunarbox.Data.String (toHtml)

type ProblemsInput
  = Array (TypeError Location)

-- Icons
error :: forall h a. HH.HTML h a
error = icon "error"

warning :: forall h a. HH.HTML h a
warning = icon "warning"

-- The actual component
problems :: forall h a. ProblemsInput -> HH.HTML h a
problems [] = HH.main [ className "problems__empty" ] [ HH.text "No errors here!" ]

problems errors =
  HH.main [ className "problems__container" ]
    $ filterMap
        ( \{ typeError, location } ->
            if location == UnknownLocation then
              Nothing
            else
              Just
                $ HH.section [ className "problems__card problems__card--error" ]
                    [ HH.div [ className "problems__card-header" ]
                        [ HH.div [ className "problems__card-icon" ] [ error ]
                        , HH.button [ className "problems__card-location" ]
                            [ HH.text $ show location
                            ]
                        ]
                    , HH.div [ className "problems__card-message" ]
                        [ toHtml $ printError typeError ]
                    ]
        )
    $ (\typeError -> { typeError, location: getLocation typeError })
    <$> errors

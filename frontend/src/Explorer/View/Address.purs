module Explorer.View.Address where

import Prelude
import Data.Array (length, null, slice)
import Data.Lens ((^.))
import Data.Maybe (Maybe(..), isJust)
import Explorer.I18n.Lang (Language, translate)
import Explorer.I18n.Lenses (addNotFound, cAddress, cBack2Dashboard, common, cLoading, cOf, cTransactions, address, addScan, addQrCode, addFinalBalance, tx, txEmpty, txNotFound) as I18nL
import Explorer.Lenses.State (_PageNumber, addressDetail, addressTxPagination, addressTxPaginationEditable, currentAddressSummary, lang, viewStates)
import Explorer.Routes (Route(..), toUrl)
import Explorer.State (addressQRImageId, minPagination)
import Explorer.Types.Actions (Action(..))
import Explorer.Types.State (CCurrency(..), PageNumber(..), State, CTxBriefs)
import Explorer.Util.String (formatADA)
import Explorer.View.Common (currencyCSSClass, getMaxPaginationNumber, mkTxBodyViewProps, mkTxHeaderViewProps, txBodyView, txEmptyContentView, txHeaderView, txPaginationView)
import Network.RemoteData (RemoteData(..))
import Pos.Explorer.Web.ClientTypes (CAddressSummary(..), CTxBrief)
import Pos.Explorer.Web.Lenses.ClientTypes (_CAddress, caAddress, caBalance, caTxNum)
import Pux.Html (Html, div, text, span, h3, p) as P
import Pux.Html.Attributes (className, dangerouslySetInnerHTML, id_) as P
import Pux.Router (link) as P


addressView :: State -> P.Html Action
addressView state =
    let lang' = state ^. lang in
    P.div
        [ P.className "explorer-address" ]
        [ P.div
            [ P.className "explorer-address__wrapper" ]
            [ P.div
                  [ P.className "explorer-address__container" ]
                  [ P.h3
                        [ P.className "headline"]
                        [ P.text $ translate (I18nL.common <<< I18nL.cAddress) lang' ]
                  , addressOverview (state ^. currentAddressSummary) lang'
                  ]
            ]
            , P.div
                [ P.className "explorer-address__wrapper" ]
                [ P.div
                      [ P.className "explorer-address__container" ]
                      [ case state ^. currentAddressSummary of
                            NotAsked  -> txEmptyContentView ""
                            Loading   -> txEmptyContentView $
                                translate (I18nL.common <<< I18nL.cLoading) lang'
                            Failure _ -> txEmptyContentView $
                                translate (I18nL.tx <<< I18nL.txNotFound) lang'
                            Success (CAddressSummary addressSummary) ->
                                addressTxsView addressSummary.caTxList state
                ]
            ]
        ]

-- | Address overview, we leave the error abstract (we are not using it)
addressOverview :: forall e. RemoteData e CAddressSummary -> Language -> P.Html Action
addressOverview NotAsked    lang = emptyAddressDetail ""
addressOverview Loading     lang = emptyAddressDetail <<< translate (I18nL.common <<< I18nL.cLoading) $ lang
addressOverview (Failure _) lang = failureView lang
addressOverview (Success addressSummary) lang =
    P.div
        [ P.className "address-overview"]
        [ addressDetailView addressSummary lang
        , addressQr addressSummary lang
        ]

addressDetailView :: CAddressSummary -> Language -> P.Html Action
addressDetailView addressSummary lang =
    P.div
        [ P.className "address-detail" ]
        $ map addressDetailRow $ addressDetailRowItems addressSummary lang

addressQr :: CAddressSummary -> Language -> P.Html Action
addressQr _ lang =
    P.div
      [ P.className "address-qr" ]
      [ P.p
          [ P.className "address-qr__tab" ]
          [ P.text $ translate (I18nL.address <<< I18nL.addQrCode) lang  ]
      , P.div
          [ P.className "address-qr__wrapper" ]
          [ P.div
              [ P.className "address-qr__image"
              , P.id_ addressQRImageId
              ]
              []
            , P.p
                [ P.className "address-qr__description" ]
                [ P.text $ translate (I18nL.address <<< I18nL.addScan) lang ]
          ]
      ]

type SummaryRowItem =
    { label :: String
    , value :: String
    , mCurrency :: Maybe CCurrency
    }

type SummaryItems = Array SummaryRowItem

addressDetailRowItems :: CAddressSummary -> Language -> SummaryItems
addressDetailRowItems (CAddressSummary address) lang =
    [ { label: translate (I18nL.common <<< I18nL.cAddress) lang
      , value: address ^. (caAddress <<< _CAddress)
      , mCurrency: Nothing
    }
    , { label: translate (I18nL.common <<< I18nL.cTransactions) lang
      , value: show $ address ^. caTxNum
      , mCurrency: Nothing
    }
    , { label: translate (I18nL.address <<< I18nL.addFinalBalance) lang
      , value: formatADA (address ^. caBalance) lang
      , mCurrency: Just ADA
      }
    ]

addressDetailRow :: SummaryRowItem -> P.Html Action
addressDetailRow item =
    P.div
        [ P.className "address-detail__row" ]
        [ P.div
            [ P.className "address-detail__column label" ]
            [ P.text item.label ]
        , P.div
              [ P.className $ "address-detail__column amount" ]
              if isJust item.mCurrency
              then
              [ P.span
                [ P.className $ currencyCSSClass item.mCurrency ]
                [ P.text item.value ]
              ]
              else
              [ P.text item.value ]
        ]

emptyAddressDetail :: String -> P.Html Action
emptyAddressDetail message =
    P.div
        [ P.className "message" ]
        [ P.div
            [ P.dangerouslySetInnerHTML message ]
            []
        ]

maxTxRows :: Int
maxTxRows = 5

addressTxsView :: CTxBriefs -> State -> P.Html Action
addressTxsView txs state =
    if null txs then
        txEmptyContentView $ translate (I18nL.tx <<< I18nL.txEmpty) (state ^. lang)
    else
    let txPagination = state ^. (viewStates <<< addressDetail <<< addressTxPagination <<< _PageNumber)
        lang' = state ^. lang
        minTxIndex = (txPagination - minPagination) * maxTxRows
        currentTxs = slice minTxIndex (minTxIndex + maxTxRows) txs
    in
    P.div
        []
        [ P.div
              []
              $ map (\tx -> addressTxView tx lang') currentTxs
        , txPaginationView  { label: translate (I18nL.common <<< I18nL.cOf) $ lang'
                            , currentPage: PageNumber txPagination
                            , minPage: PageNumber minPagination
                            , maxPage: PageNumber $ getMaxPaginationNumber (length txs) maxTxRows
                            , changePageAction: AddressPaginateTxs
                            , editable: state ^. (viewStates <<< addressDetail <<< addressTxPaginationEditable)
                            , editableAction: AddressEditTxsPageNumber
                            , invalidPageAction: AddressInvalidTxsPageNumber
                            , disabled: false
                            }
        ]

addressTxView :: CTxBrief -> Language -> P.Html Action
addressTxView tx lang =
    P.div
        []
        [ txHeaderView lang $ mkTxHeaderViewProps tx
        , txBodyView lang $ mkTxBodyViewProps tx
        ]

-- let txList = addressSummary ^. caTxList
--     txPagination = state ^. (viewStates <<< addressDetail <<< addressTxPagination <<< _PageNumber)
--     currentTxBrief = txList !! (txPagination - 1)
-- in
-- P.div
--     []
--     [ P.h3
--           [ P.className "headline"]
--           [ P.text $ translate (I18nL.common <<< I18nL.cTransactions) lang' ]
--     , case currentTxBrief of
--         Nothing ->
--             txEmptyContentView $ translate (I18nL.tx <<< I18nL.txEmpty) lang'
--         Just txBrief ->
--             P.div []
--             [ txHeaderView lang' $ mkTxHeaderViewProps txBrief
--             , txBodyView lang' $ mkTxBodyViewProps txBrief
--             , txPaginationView
--                   { label: translate (I18nL.common <<< I18nL.cOf) $ lang'
--                   , currentPage: PageNumber txPagination
--                   , minPage: PageNumber minPagination
--                   , maxPage: PageNumber $ length txList
--                   , changePageAction: AddressPaginateTxs
--                   , editable: state ^. (viewStates <<< addressDetail <<< addressTxPaginationEditable)
--                   , editableAction: AddressEditTxsPageNumber
--                   , invalidPageAction: AddressInvalidTxsPageNumber
--                   , disabled: false
--                   }
--             ]
--     ]

failureView :: Language -> P.Html Action
failureView lang =
    P.div
        []
        [ P.p
            [ P.className "address-failed" ]
            [ P.text $ translate (I18nL.address <<< I18nL.addNotFound) lang ]
        , P.link (toUrl Dashboard)
            [ P.className "btn-back" ]
            [ P.text $ translate (I18nL.common <<< I18nL.cBack2Dashboard) lang ]
        ]

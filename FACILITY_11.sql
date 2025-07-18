drop view CALC.VIEW_FACILITY;
create or replace view CALC.VIEW_FACILITY as
with PORTFOLIO as (
    select PORTFOLIO.CUT_OFF_DATE,
           DATA_CUT_OFF_DATE,
           BRANCH_SYSTEM,
           PORTFOLIO.SYSTEM as SOURCE,
           BRANCH_CLIENT,
           CLIENT_NO,
           CLIENT_ID_ORIG,
           CLIENT_ID_LEADING,
           CLIENT_ID_ALT,
           BORROWER_NO,
           BRANCH_FACILITY,
           FACILITY_ID,
           FACILITY_ID_LEADING,
           FACILITY_ID_NLB,
           FACILITY_ID_BLB,
           FACILITY_ID_CBB,
           CURRENCY,
           PORTFOLIO_EY_FACILITY,
           PORTFOLIO_EY_CLIENT_ROOT,
           PORTFOLIO_IWHS_CLIENT_KUNDENBERATER,
           PORTFOLIO_IWHS_CLIENT_SERVICE,
           PORTFOLIO_KR_CLIENT,
           PORTFOLIO_GARANTIEN_CLIENT,
           IS_CLIENT_GUARANTEE_FLAGGED,
           IS_FACILITY_GUARANTEE_FLAGGED,
           IS_FACILITY_FROM_SINGAPORE,
           case
               when LEFT(PORTFOLIO.FACILITY_ID, 4) = 'K028' then
                   'LUX'
               when LEFT(PORTFOLIO.FACILITY_ID, 4) = 'ISIN' then
                   'ISIN'
               when SYSTEM2PRODUCT.SYSTEM_SATZART is not NULL then
                   SYSTEM2PRODUCT.SYSTEM_SATZART
               when LENGTH(PORTFOLIO.FACILITY_ID) = 34 then
                       SUBSTR(PORTFOLIO.FACILITY_ID, 6, 2) || '-' ||
                       SUBSTR(PORTFOLIO.FACILITY_ID, 22, 2)
               else
                   'Other'
               end          as SYSTEM_SATZART,
           SYSTEM2PRODUCT.SYSTEM,
           SYSTEM2PRODUCT.PRODUCT_GROUP,
           SYSTEM2PRODUCT.PRODUCT,
           case
               when LEFT(PORTFOLIO.FACILITY_ID, 11) = '0009-13-007' or
                    LEFT(PORTFOLIO.FACILITY_ID, 11) = '0004-13-007' then
                   -- Alle 13-20 Konten die mit 007 beginnen sind Aval Bürgschaften
                   'Aval Bürgschaften'
               when SYSTEM2PRODUCT.SYSTEM_SATZART = '13-20' then
                   -- Alle 13-20 Konten die nicht mit 007 beginnen sind Girokonten
                   'Girokonten'
               when LEFT(PORTFOLIO.FACILITY_ID, 4) = 'K028' and RIGHT(PORTFOLIO.FACILITY_ID, 5) = '_4200' then
                   -- K028-*******_4200
                   'offenes Limit'
               else
                   SYSTEM2PRODUCT.PRODUCT
               end          as PRODUCTTYPE_DETAIL,
           case
               when SYSTEM2PRODUCT.SYSTEM_SATZART in ('13-20', '30-31', '33-31', '49-20') then
                   TRUE
               else FALSE
               end          as IS_PWC_FOCUS
    from CALC.SWITCH_PORTFOLIO_CURRENT as PORTFOLIO
             left join SMAP.SYSTEM_TO_PRODUCT as SYSTEM2PRODUCT
                       on SYSTEM2PRODUCT.SYSTEM = SUBSTR(PORTFOLIO.FACILITY_ID, 6, 2) and
                          SYSTEM2PRODUCT.SATZART = SUBSTR(PORTFOLIO.FACILITY_ID, 22, 2) and
                          LENGTH(PORTFOLIO.FACILITY_ID) >= 34
),
     CLIENTS as (
         select *
         from CALC.SWITCH_PORTFOLIO_DESIRED_CLIENTS_CURRENT
     ),
     CLIENT_INFO as (
         select ACCOUNTHOLDER.CUT_OFF_DATE,
                ACCOUNTHOLDER.CLIENT_ID_ORIG,
                ACCOUNTHOLDER.BORROWERNAME,
                ACCOUNTHOLDER.CLIENT_TYPE,
                ACCOUNTHOLDER.CLIENT_NAME_ANONYMIZED,
                ACCOUNTHOLDER.COUNTRY_APLHA2,
                ACCOUNTHOLDER.NACE,
                ACCOUNTHOLDER.KONZERN_ID,
                ACCOUNTHOLDER.KONZERN_BEZEICHNUNG_ANONYMIZED,
                ACCOUNTHOLDER.GVK_BUNDESBANKNUMMER,
                ACCOUNTHOLDER.RATING_MODUL,
                ACCOUNTHOLDER.RATING_ID,
                max(GUARANTOR.RECOURSE) as RECOURSE
         from CALC.SWITCH_CLIENT_ACCOUNTHOLDER_CURRENT as ACCOUNTHOLDER
                  left join CALC.SWITCH_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_CURRENT as A2G
                            on (ACCOUNTHOLDER.CLIENT_ID_ORIG, ACCOUNTHOLDER.CUT_OFF_DATE) =
                               (A2G.CLIENT_ID_BORROWER_ORIG, A2G.CUT_OFF_DATE)
                  left join CALC.SWITCH_CLIENT_THIRDPARTY_CURRENT as GUARANTOR
                            on (GUARANTOR.CLIENT_ID_ORIG, GUARANTOR.CUT_OFF_DATE) =
                               (A2G.CLIENT_ID_NOBORROWER_ORIG, A2G.CUT_OFF_DATE)
         group by ACCOUNTHOLDER.CUT_OFF_DATE, ACCOUNTHOLDER.CLIENT_ID_ORIG, ACCOUNTHOLDER.BORROWERNAME,
                  ACCOUNTHOLDER.CLIENT_TYPE,
                  ACCOUNTHOLDER.CLIENT_NAME_ANONYMIZED, ACCOUNTHOLDER.COUNTRY_APLHA2, ACCOUNTHOLDER.NACE,
                  ACCOUNTHOLDER.KONZERN_ID,
                  ACCOUNTHOLDER.KONZERN_BEZEICHNUNG_ANONYMIZED, ACCOUNTHOLDER.GVK_BUNDESBANKNUMMER,
                  ACCOUNTHOLDER.RATING_MODUL,
                  ACCOUNTHOLDER.RATING_ID
     ),
     FACILITY_CORE as (
         select F.CUT_OFF_DATE,
                F.BRANCH,
                F.FACILITY_ID_LEADING,
                F.FACILITY_ID,
                F.CLIENT_ID,
                FACILITY_ID_ALTERNATIVE,
                PRODUCTTYPE,
                ORIGINAL_CURRENCY,
                FVC_RATING_NOTE,
                FVC_RATING_DATE,
                SYNDICATION_ROLE,
                max(OWN_SYNDICATE_QUOTA)         as OWN_SYNDICATE_QUOTA,
                ORIGINATION_DATE,
                CURRENT_CONTRACTUAL_MATURITY_DATE,
                LOANSTATE_LIQ,
                LOANSTATE_SPOT,
                ZEB_R_RATING_ID,
                ZEB_R_RATING_MODULE,
                ZEB_R_RATING_SUB_MODULE,
                PRICIPAL_OST_EUR_SPOT            as PRINCIPAL_OUTSTANDING_EUR_SPOT_RAW, -- GNI_PRINCIPAL_RAW
                case
                    when P.SYSTEM_SATZART = '30-31' then
                        -1 * PRICIPAL_OST_EUR_SPOT
                    else
                        -0.01 * PRICIPAL_OST_EUR_SPOT * max(OWN_SYNDICATE_QUOTA)
                    end                          as PRINCIPAL_OUTSTANDING_EUR_SPOT,
                PRICIPAL_OST_EUR_BW,
                AMORTIZATION_IN_ARREARS_EUR_SPOT as AMORTIZATION_IN_ARREARS_EUR_SPOT_RAW,
                case
                    when P.SYSTEM = '30' then
                        -- AZ6 Darlehen
                        --TODO:Wieder aufnehmen, wenn Zulieferungsprobleme behoben sind!
                        -- (-1 * AMORTIZATION_IN_ARREARS_EUR_SPOT)
                        null
                    else
                        -0.01 * AMORTIZATION_IN_ARREARS_EUR_SPOT * max(OWN_SYNDICATE_QUOTA)
                    end                          as AMORTIZATION_IN_ARREARS_EUR_SPOT,
                AMORTIZATION_IN_ARREARS_EUR_BW,
                INTEREST_IN_ARREARS_EUR_SPOT     as INTEREST_IN_ARREARS_EUR_SPOT_RAW,
                case
                    when P.SYSTEM = '30' then
                        -- AZ6 Darlehen
                        --TODO:Wieder aufnehmen, wenn Zulieferungsprobleme behoben sind!
                        -- (-1 * INTEREST_IN_ARREARS_EUR_SPOT)
                        null
                    else
                        -0.01 * INTEREST_IN_ARREARS_EUR_SPOT * max(OWN_SYNDICATE_QUOTA)
                    end                          as INTEREST_IN_ARREARS_EUR_SPOT,
                INTEREST_IN_ARREARS_EUR_BW,
                FEES_IN_ARREARS_EUR_SPOT         as FEES_IN_ARREARS_EUR_SPOT_RAW,
                case
                    when P.SYSTEM = '30' then
                        -- AZ6 Darlehen
                        -1 * FEES_IN_ARREARS_EUR_SPOT
                    else
                        -0.01 * FEES_IN_ARREARS_EUR_SPOT * max(OWN_SYNDICATE_QUOTA)
                    end                          as FEES_IN_ARREARS_EUR_SPOT,
                BILANZWERT_BRUTTO_EUR,
                BILANZWERT_BRUTTO_TC,
                BILANZWERT_IFRS9_EUR,
                BILANZWERT_IFRS9_TC,
                HGB_EUR,
                HGB_TC,
                OFFBALANCE_EUR,
                OFFBALANCE_TC,
                ZEB_R_EXPOSURE_AT_DEFAULT_AMT_EUR,
                ZEB_R_EXPOSURE_AT_DEFAULT_AMT_TC,
                ZEB_R_EAD_TOTAL_AMT_EUR,
                ZEB_R_EAD_TOTAL_AMT_TC,
                ZEB_E_LGD_COLL_RATE,
                ZEB_R_LGD_NET_RATE,
                ZEB_R_LOSS_GIVEN_DEFAULT_RATE,
                FVC_LGD_IN_PROZENT,
                FVA_EUR,
                FVA_TC,
                ZUSAGE_AKTIV,
                PARENT_FACILITY_ID,
                RIVO_STAGE,
                RIVO_STAGE_1_EUR,
                RIVO_STAGE_2_EUR,
                RIVO_STAGE_3_EUR,
                RIVO_STAGE_POCI_EUR,
                RISK_PROVISION_EUR,
                RISK_PROVISION_TC,
                FVC_RISIKOGEWICHT_IN_PROZENT,
                AMORTIZATION_TYPE,
                AMORTIZATION_FREQUENCY_DAYS,
                NEXT_AMORTIZATION_TO_BE_PAID,
                TOTAL_PAST_DUE,
                ZEB_E_DAYS_PAST_DUE_NO,
                ZEB_R_ONE_YEAR_PROB_OF_DEFAULT_RATE,
                AUSZAHLUNGSPLICHT_EUR,
                ZEB_PRJ_IS_FINREP_FORBORNE,
                NICHT_IM_BW_REWE,
                INAKTIV,
                F.FACILITY_ID_CBB,
                CBB_GESCHAEFTS_ID,
                ZUGEHOERIGER_RAHMEN,
                DAYS_PAST_DUE,
                GUARANTEE_FLAG,
                PORTFOLIO,
                KUNDENBETREUER_OE_BEZEICHNUNG
         from CALC.SWITCH_FACILITY_CORE_CURRENT as F
                  left join PORTFOLIO as P on F.FACILITY_ID = P.FACILITY_ID
         group by F.CUT_OFF_DATE
                , F.BRANCH
                , F.FACILITY_ID_LEADING
                , F.FACILITY_ID
                , F.CLIENT_ID
                , FACILITY_ID_ALTERNATIVE
                , PRODUCTTYPE
                , ORIGINAL_CURRENCY
                , FVC_RATING_DATE
                , SYNDICATION_ROLE
                , ORIGINATION_DATE
                , CURRENT_CONTRACTUAL_MATURITY_DATE
                , LOANSTATE_LIQ
                , LOANSTATE_SPOT
                , ZEB_R_RATING_ID
                , ZEB_R_RATING_MODULE
                , ZEB_R_RATING_SUB_MODULE
                , PRICIPAL_OST_EUR_SPOT
                , P.SYSTEM_SATZART
                , PRICIPAL_OST_EUR_BW
                , AMORTIZATION_IN_ARREARS_EUR_SPOT
                , P.SYSTEM
                , AMORTIZATION_IN_ARREARS_EUR_BW
                , INTEREST_IN_ARREARS_EUR_SPOT
                , INTEREST_IN_ARREARS_EUR_BW
                , FEES_IN_ARREARS_EUR_SPOT
                , BILANZWERT_BRUTTO_EUR
                , BILANZWERT_BRUTTO_TC
                , BILANZWERT_IFRS9_EUR
                , BILANZWERT_IFRS9_TC
                , HGB_EUR
                , HGB_TC
                , OFFBALANCE_EUR
                , OFFBALANCE_TC
                , ZEB_R_EXPOSURE_AT_DEFAULT_AMT_EUR
                , ZEB_R_EXPOSURE_AT_DEFAULT_AMT_TC
                , ZEB_R_EAD_TOTAL_AMT_EUR
                , ZEB_R_EAD_TOTAL_AMT_TC
                , ZEB_E_LGD_COLL_RATE
                , ZEB_R_LGD_NET_RATE
                , ZEB_R_LOSS_GIVEN_DEFAULT_RATE
                , FVC_LGD_IN_PROZENT
                , FVA_EUR
                , FVA_TC
                , FVC_RATING_NOTE
                , ZUSAGE_AKTIV
                , PARENT_FACILITY_ID
                , RIVO_STAGE
                , RIVO_STAGE_1_EUR
                , RIVO_STAGE_2_EUR
                , RIVO_STAGE_3_EUR
                , RIVO_STAGE_POCI_EUR
                , RISK_PROVISION_EUR
                , RISK_PROVISION_TC
                , FVC_RISIKOGEWICHT_IN_PROZENT
                , AMORTIZATION_TYPE, AMORTIZATION_FREQUENCY_DAYS, NEXT_AMORTIZATION_TO_BE_PAID
                , TOTAL_PAST_DUE
                , ZEB_E_DAYS_PAST_DUE_NO
                , ZEB_R_ONE_YEAR_PROB_OF_DEFAULT_RATE
                , AUSZAHLUNGSPLICHT_EUR
                , ZEB_PRJ_IS_FINREP_FORBORNE
                , NICHT_IM_BW_REWE
                , INAKTIV
                , F.FACILITY_ID_CBB
                , CBB_GESCHAEFTS_ID
                , ZUGEHOERIGER_RAHMEN
                , DAYS_PAST_DUE
                , GUARANTEE_FLAG
                , PORTFOLIO
                , KUNDENBETREUER_OE_BEZEICHNUNG
     ),
     FACILITY_MAPPING as (
         select FOCS.CUT_OFF_DATE, FOCS.FACILITY_ID, FOCS.LEITKONTO_FACILITY_ID
         from NLB.FOCS_LEITKONTO_CURRENT as FOCS
     ),
     COMPENSATIONS as (
         select FOCS.CUT_OFF_DATE,
                FOCS.LEITKONTO_FACILITY_ID,
                sum(FACILITY.PRINCIPAL_OUTSTANDING_EUR_SPOT)   as PRINCIPAL_OUTSTANDING_EUR_SPOT_COMPENSATED,
                sum(FACILITY.AMORTIZATION_IN_ARREARS_EUR_SPOT) as AMORTIZATION_IN_ARREARS_EUR_SPOT_COMPENSATED,
                sum(FACILITY.INTEREST_IN_ARREARS_EUR_SPOT)     as INTEREST_IN_ARREARS_EUR_SPOT_COMPENSATED
         from FACILITY_MAPPING as FOCS
                  left join FACILITY_CORE as FACILITY on FOCS.FACILITY_ID = FACILITY.FACILITY_ID
         group by FOCS.CUT_OFF_DATE, FOCS.LEITKONTO_FACILITY_ID
     ),
     FACILITY_SAP as (
         select *
         from CALC.SWITCH_FACILITY_BW_P80_AOER_CURRENT
     ),
     FACILITY_KR as (
         select *
         from CALC.SWITCH_KREDITRISIKO_BANKANALYSER_CURRENT
     ),
     FACILITY_LAST_YEAR as ( -- 31.12. des Vorjahres
         select distinct -- Distinct zur Sicherheit, ist nicht zwingend nötig
                         FA.CUT_OFF_DATE,
                         FA.FACILITY_ID,
                         FA.PRINCIPAL_OUTSTANDING_EUR_SPOT_RAW,
                         FA.PRINCIPAL_OUTSTANDING_EUR_SPOT,
                         FA.PRINCIPAL_OUTSTANDING_EUR_BW,
                         FA.RISK_PROVISION_ZEB_EXCHANGE_RATE_EUR2OC,
                         FA.ZEB_STAGE_ONBALANCE,
                         FA.ZEB_EWB_EUR_ONBALANCE,
                         FA.ZEB_EWB_OC_ONBALANCE,
                         FA.ZEB_STAGE_OFFBALANCE,
                         FA.ZEB_EWB_EUR_OFFBALANCE,
                         FA.ZEB_EWB_OC_OFFBALANCE,
                         FA.FREIE_LINIE,
                         FA.RATING_ALPHA,
                         FA.RATING_ID_KUNDE,
                         FA.RATING_BW,
                         COD.CUT_OFF_DATE as CUT_OFF_DATE_NEXT_YEAR
         from CALC.SWITCH_FACILITY_ARCHIVE as FA
                  inner join CALC.AUTO_TABLE_CUTOFFDATES as COD
                             on FA.CUT_OFF_DATE = last_day(COD.CUT_OFF_DATE - month(COD.CUT_OFF_DATE) MONTHS)
                                 and COD.IS_ACTIVE
     ),
     PORTFOLIO2SUMMARY as (
         select distinct OE_TEXT, OE_TEXT_SIMPLIFIED
         from SMAP.PORTFOLIO_TEXT
     ),
     FACILITY_UNION as (
         select PORTFOLIO.CUT_OFF_DATE                                                     as CUT_OFF_DATE,                                 -- nicht PWC relevant
                PORTFOLIO.DATA_CUT_OFF_DATE                                                as DATA_CUT_OFF_DATE,                            -- nicht PWC relevant
                -- KONTEN IDS
                PORTFOLIO.BRANCH_FACILITY                                                  as BRANCH_FACILITY,
                PORTFOLIO.FACILITY_ID                                                      as FACILITY_ID,
                PORTFOLIO.FACILITY_ID_LEADING                                              as FACILITY_ID_LEADING,                          -- GNI_LEITKONTO
                FACILITY_CORE.FACILITY_ID_ALTERNATIVE                                      as FACILITY_ID_ALTERNATIVE,                      -- nicht PWC relevant
                FACILITY_MAPPING.LEITKONTO_FACILITY_ID                                     as LEADING_FACILITY_ID,
                FACILITY_CORE.PARENT_FACILITY_ID                                           as PARENT_FACILITY_ID,                           -- GNI_PARENTFACILITY
                FACILITY_CORE.ZUGEHOERIGER_RAHMEN                                          as CORRESPONDING_LIMIT_ID,                       -- GNI_RAHMEN
                PORTFOLIO.SYSTEM_SATZART                                                   as SYSTEM_SATZART,                               -- SYSTEM
                -- KATEGORISIERUNG
                case
                    when PORTFOLIO.PRODUCT_GROUP is not NULL then
                        PORTFOLIO.PRODUCT_GROUP
                    when lower(FACILITY_CORE.PRODUCTTYPE) like '%termingeld%' then
                        'Kontenprodukte'
                    when lower(FACILITY_CORE.PRODUCTTYPE) like '%darlehen%' then
                        'Darlehen'
                    end                                                                    as PRODUCT_GROUP,                                -- SYSTEM_PRODUKTGRUPPE
                case
                    when PORTFOLIO.PRODUCT_GROUP is not NULL then
                        PORTFOLIO.PRODUCT_GROUP
                    when lower(FACILITY_CORE.PRODUCTTYPE) like '%termingeld%' then
                        'Kontenprodukte'
                    when lower(FACILITY_CORE.PRODUCTTYPE) like '%darlehen%' then
                        'Darlehen'
                    else
                        'Sonstiges'
                    end ||
                case
                    when FACILITY_CORE.PRODUCTTYPE is not null then
                        ' (' || FACILITY_CORE.PRODUCTTYPE || ')'
                    when PORTFOLIO.PRODUCTTYPE_DETAIL is not null
                        and PORTFOLIO.PRODUCTTYPE_DETAIL <> coalesce(PORTFOLIO.PRODUCT_GROUP, 'ALPACA') then
                        ' (' || PORTFOLIO.PRODUCTTYPE_DETAIL || ')'
                    else
                        ''
                    end                                                                    as PRODUCTTYPE,                                  -- SYSTEM_PRODUKT
                --FACILITY_CORE.PRODUCTTYPE,                                                                                                     -- GNI_PRODUKTTYP
                --FACILITY_CORE.PRODUCTGROUP_AVIATION,  -- nicht PWC relevant
                --SYSTEM2PRODUCT.PRODUCT,  -- nicht PWC relevant
                SAP_PRODUCTS.PRODUCT_NO                                                    as PRODUCT_BW,                                   -- SAP_PRODUKT
                SAP_PRODUCTS.PRODUCT_TXT_SHORT                                             as PRODUCT_BW_TEXT,                              -- SAP_PRODUKTTEXT
                case when FACILITY_CORE.FACILITY_ID is NULL then FALSE else TRUE end       as IN_SPOT,                                      -- GNI
                case when FACILITY_SAP.FACILITY_ID is NULL then FALSE else TRUE end        as IN_BW,                                        -- SAP
                PORTFOLIO.SOURCE                                                           as PRIMARY_SOURCE,
                FACILITY_CORE.BRANCH                                                       as BRANCH,                                       -- GNI_ZUORDNUNG
                --TRANSFER_PORTFOLIO                                           as PORTFOLIO_TRANSFER, -- nicht PWC relevant
                --PORTFOLIO.PORTFOLIO_IWHS_CLIENT_SERVICE                                                as PORTFOLIO_CLIENT_SERVICE_IWHS, -- nicht PWC relevant
                FACILITY_CORE.KUNDENBETREUER_OE_BEZEICHNUNG                                as PORTFOLIO_CLIENT_PERSON_IWHS,                 -- GNI_KUBE_OE
                FACILITY_SAP.SAP_KUSY                                                      as KUSY,                                         -- SAP_KUSY
                FACILITY_SAP.SAP_SEGMENT                                                   as SEGMENT,                                      -- SAP_SEGMENT
                -- KUNDEN INFOS
                coalesce(CLIENTS.CLIENT_ID, PORTFOLIO.CLIENT_ID_ORIG)                      as CLIENT_ID,                                    -- GNI_KUNDE
                PORTFOLIO.CLIENT_ID_LEADING                                                as CLIENT_ID_LEADING,                            -- GNI_KUNDE_LEADING
                FACILITY_SAP.SAP_KUNDE                                                     as CLIENT_NO_BW,                                 -- SAP_KUNDE
                CLIENT_INFO.CLIENT_TYPE                                                    as CLIENT_TYPE,                                  -- GNI_TYP
                CLIENT_INFO.BORROWERNAME                                                   as CLIENT_NAME,                                  -- nicht PWC relevant
                CLIENT_INFO.CLIENT_NAME_ANONYMIZED                                         as CLIENT_NAME_ANONYMIZED,                       -- GNI_NAME
                CLIENT_INFO.COUNTRY_APLHA2                                                 as CLIENT_COUNTRY_ALPHA2,
                CLIENT_INFO.NACE                                                           as CLIENT_NACE,                                  -- GNI_NACE
                CLIENT_INFO.KONZERN_ID                                                     as GROUP_ID,                                     -- GNI_KONZERNID
                CLIENT_INFO.KONZERN_BEZEICHNUNG_ANONYMIZED                                 as GROUP_NAME,                                   -- GNI_KONZERN
                CLIENT_INFO.GVK_BUNDESBANKNUMMER,
                -- BASICS
                coalesce(FACILITY_CORE.ORIGINAL_CURRENCY,
                         PORTFOLIO.CURRENCY,
                         FACILITY_KR.ORIGINAL_CURRENCY)                                    as CURRENCY,                                     -- GNI_WAEHRUNG
                FACILITY_SAP.SAP_WAEHRUNG                                                  as CURRENCY_BW,                                  -- SAP_WAEHRUNG
                FACILITY_CORE.SYNDICATION_ROLE                                             as SYNDICATION_ROLE,                             -- Rolle im Konsortium
                FACILITY_CORE.ORIGINATION_DATE,
                FACILITY_CORE.CURRENT_CONTRACTUAL_MATURITY_DATE,
                --HALTEKATEGORIE as VALUATION_BASIS,
                FACILITY_CORE.LOANSTATE_LIQ,
                FACILITY_CORE.LOANSTATE_SPOT,
                --FACILITY_CORE.IFRS_STAGE,
                -- RATING INFOS
                CLIENT_INFO.RATING_MODUL                                                   as RATING_MODULE_CLIENT,
                FACILITY_CORE.ZEB_R_RATING_ID                                              as RATING_ID_ZEB,
                FACILITY_CORE.ZEB_R_RATING_MODULE                                          as RATING_MODULE_ZEB,                            -- GNI_ZEB_RATINGMODUL
                FACILITY_CORE.ZEB_R_RATING_SUB_MODULE                                      as RATING_SUBMODULE_ZEB,
                FACILITY_SAP.SAP_RATINGMODUL                                               as RATING_MODULE_BW,                             -- SAP_RATINGMODUL TODO: fixen
                FACILITY_SAP.SAP_MODULNAME                                                 as RATING_MODULE_NAME_BW,                        -- SAP_MODULNAME TODO: fixen
                FACILITY_SAP.SAP_SUBMODUL                                                  as RATING_SUBMODULE_BW,                          -- SAP_SUBMODUL TODO: fixen
                FACILITY_SAP.SAP_MODULBESCHREIBUNG                                         as RATING_MODULE_DESCRIPTION_BW,                 -- SAP_MODULBESCHREIBUNG TODO: fixen
                case
                    when max(FACILITY_CORE.FVC_RATING_NOTE, FACILITY_KR.RATINGSTUFE_IRBA,
                             FACILITY_KR.RATINGSTUFE_KSA) in (16, 17, 18) then
                        --TODO: Mit Marcus checken, welches Rating hier ausschlaggebend ist und ob es nicht einheitlich pro Kunde sein sollte
                        'Non performing'
                    when max(FACILITY_CORE.FVC_RATING_NOTE, FACILITY_KR.RATINGSTUFE_IRBA, FACILITY_KR.RATINGSTUFE_KSA) <
                         16 then
                        'Performing'
                    else
                        NULL
                    end                                                                    as PERFORMANCE_STATUS,
                coalesce(FACILITY_KR.RATINGKLASSE_IRBA,
                         FACILITY_KR.RATINGKLASSE_KSA)                                     as RATING_ALPHA,                                 --TODO oder KSA? beides Alphanumerisch...
                FACILITY_LAST_YEAR.RATING_ALPHA                                            as RATING_ALPHA_PREV_YEAR,                       --TODO oder KSA? beides Alphanumerisch...
                FACILITY_KR.RATINGKLASSE_IRBA                                              as RATING_ALPHA_IRBA,
                FACILITY_KR.RATINGSTUFE_IRBA                                               as RATING_NUMERIC_IRBA,
                FACILITY_KR.RATINGKLASSE_KSA                                               as RATING_ALPHA_KSA,
                FACILITY_KR.RATINGSTUFE_KSA                                                as RATING_NUMERIC_KSA,
                FACILITY_CORE.FVC_RATING_NOTE                                              as RATING_NUMERIC_FVC,
                FACILITY_CORE.FVC_RATING_DATE                                              as RATING_DATE_FVC,                              -- GNI_FVC_RATINGDATUM
                FACILITY_SAP.SAP_RATING_E                                                  as RATING_BW,                                    -- SAP_RATING
                FACILITY_LAST_YEAR.RATING_BW                                               as RATING_BW_LAST_YEAR,                          -- SAP_RATING_VJ
                FACILITY_SAP.SAP_IRBA_KSA                                                  as RATING_BW_TYPE,                               -- SAP_IRBA_KSA -- Entweder IRBA oder KSA, je nachdem
                CLIENT_INFO.RATING_ID                                                      as RATING_ID_KUNDE,
                FACILITY_LAST_YEAR.RATING_ID_KUNDE                                         as RATING_ID_KUNDE_LAST_YEAR,
                FACILITY_SAP.SAP_HEDGING_FLAG                                              as HEDGING_FLAG_BW,
                FACILITY_SAP.SAP_STUECKZINSEN                                              as STUECKZINSEN_BW,
                --?
                ----- GELDBETRÄGE -----
                -- PRINCIPAL OUTSTANDING / INANSPRUCHNAHME
                case
                    when coalesce(FACILITY_CORE.PRINCIPAL_OUTSTANDING_EUR_SPOT_RAW, 0) > 0 then
                        'Guthaben'
                    when coalesce(FACILITY_CORE.PRINCIPAL_OUTSTANDING_EUR_SPOT_RAW, 0) < 0 then
                        'Forderung'
                    else
                        'Kein Bestand'
                    end                                                                    as PRINCIPAL_TYPE,                               -- GNI_PRINCIPALTYP
                FACILITY_CORE.PRINCIPAL_OUTSTANDING_EUR_SPOT_RAW                           as PRINCIPAL_OUTSTANDING_EUR_SPOT_RAW,           -- GNI_PRINCIPAL_RAW
                FACILITY_LAST_YEAR.PRINCIPAL_OUTSTANDING_EUR_SPOT_RAW                      as PRINCIPAL_OUTSTANDING_EUR_SPOT_RAW_LAST_YEAR, -- GNI_PRINCIPAL_RAW
                FACILITY_CORE.PRINCIPAL_OUTSTANDING_EUR_SPOT                               as PRINCIPAL_OUTSTANDING_EUR_SPOT,               -- GNI_PRINCIPAL
                FACILITY_LAST_YEAR.PRINCIPAL_OUTSTANDING_EUR_SPOT                          as PRINCIPAL_OUTSTANDING_EUR_SPOT_LAST_YEAR,     -- GNI_PRINCIPAL_RAW_VJ
                case
                    when SAP_PRODUCTS.IS_AVAL and FACILITY_CORE.OWN_SYNDICATE_QUOTA = 0 then
                        coalesce(-1 * FACILITY_CORE.PRINCIPAL_OUTSTANDING_EUR_SPOT_RAW, 0)
                    when SAP_PRODUCTS.IS_AVAL and PORTFOLIO.SYSTEM_SATZART = '30-31' then
                        coalesce(-1 * FACILITY_CORE.PRINCIPAL_OUTSTANDING_EUR_SPOT_RAW, 0)
                    when SAP_PRODUCTS.IS_AVAL then
                        coalesce(-0.01 * FACILITY_CORE.PRINCIPAL_OUTSTANDING_EUR_SPOT_RAW *
                                 FACILITY_CORE.OWN_SYNDICATE_QUOTA, 0)
                    else
                        0
                    end                                                                    as PRINCIPAL_OUTSTANDING_EUR_AVAL,
                max(coalesce(FACILITY_SAP.SAP_INANSPRUCHNAHME,
                             FACILITY_CORE.PRICIPAL_OST_EUR_BW),
                    0)                                                                     as PRINCIPAL_OUTSTANDING_EUR_BW,
                FACILITY_LAST_YEAR.PRINCIPAL_OUTSTANDING_EUR_BW                            as PRINCIPAL_OUTSTANDING_EUR_BW_LAST_YEAR,
                FACILITY_KR.PRINCIPAL_OUTSTANDING                                          as PRINCIPAL_OUTSTANDING_EUR_KR,
                case
                    when FACILITY_MAPPING.LEITKONTO_FACILITY_ID is NULL then
                        NULL
                    when FACILITY_MAPPING.LEITKONTO_FACILITY_ID = PORTFOLIO.FACILITY_ID then
                        COMPENSATIONS.PRINCIPAL_OUTSTANDING_EUR_SPOT_COMPENSATED
                    else
                        0
                    end                                                                    as PRINCIPAL_OUTSTANDING_EUR_COMPENSATION,       -- GNI_PRINCIPAL_BEI_KOMPENSATION

                FACILITY_CORE.OWN_SYNDICATE_QUOTA                                          as OWN_SYNDICATE_QUOTA,                          -- GNI_PRINCIPALKONS                                 -- GNI_INANSPRUCHNAHME
                -- BILANZWERT
                FACILITY_CORE.BILANZWERT_BRUTTO_EUR,
                FACILITY_CORE.BILANZWERT_BRUTTO_TC,
                FACILITY_CORE.BILANZWERT_IFRS9_EUR,
                FACILITY_CORE.BILANZWERT_IFRS9_TC,
                FACILITY_CORE.HGB_EUR                                                      as BILANZWERT_HGB_EUR,
                FACILITY_CORE.HGB_TC                                                       as BILANZWERT_HGB_TC,
                -- EXPOSURE AT DEFAULT
                FACILITY_CORE.ZEB_R_EXPOSURE_AT_DEFAULT_AMT_EUR                            as EAD_EUR_ZEB,
                FACILITY_CORE.ZEB_R_EXPOSURE_AT_DEFAULT_AMT_TC                             as EAD_TC_ZEB,
                coalesce(FACILITY_KR.EAD_TOTAL_EUR, FACILITY_CORE.ZEB_R_EAD_TOTAL_AMT_EUR) as EAD_TOTAL_EUR,
                FACILITY_CORE.ZEB_R_EAD_TOTAL_AMT_TC                                       as EAD_TOTAL_TC_ZEB,
                FACILITY_KR.EAD_NON_SECURITIZED_EUR                                        as EAD_NON_SECURITIZED_EUR,
                FACILITY_KR.EAD_SECURITIZED                                                as EAD_SECURITIZED,
                FACILITY_SAP.SAP_EAD                                                       as EAD_BW,                                       -- SAP_EAD
                FACILITY_SAP.SAP_EL                                                        as EL_BW,                                        -- SAP_EL
                -- LOSS GIVEN DEFAULT
                FACILITY_CORE.ZEB_E_LGD_COLL_RATE                                          as LGD_COLL_RATE_ZEB,                            -- GNI_ZEB_LGD?
                FACILITY_CORE.ZEB_R_LGD_NET_RATE                                           as LGD_NET_RATE_ZEB,                             -- GNI_ZEB_LGD?
                FACILITY_CORE.ZEB_R_LOSS_GIVEN_DEFAULT_RATE                                as LGD_DEFAULT_RATE_ZEB,                         -- GNI_ZEB_LGD?
                FACILITY_CORE.FVC_LGD_IN_PROZENT                                           as LGD_PERCENT_FVC,
                FACILITY_SAP.LOSS_GIVEN_DEFAULT_RATE                                       as LGD_DEFAULT_RATE_BW,                          -- SAP_LGD
--                 -- RWA
--                 FACILITY_KR.RWA_NON_SECURITIZED_EUR,
--                 FACILITY_KR.RWA_SECURITIZED_EUR,
--                 FACILITY_KR.RWA_TOTAL_EUR,
--                 -- ACCRUED INTEREST
--                 FACILITY_CORE.ACCRUED_INTEREST_EUR,
--                 FACILITY_CORE.ACCRUED_INTEREST_TC,
                -- AMORTIZATION IN ARREAR (Tilgungsrückstände)
                FACILITY_CORE.AMORTIZATION_IN_ARREARS_EUR_SPOT_RAW                         as AMORTIZATION_IN_ARREARS_EUR_SPOT_RAW,
                FACILITY_CORE.AMORTIZATION_IN_ARREARS_EUR_SPOT                             as AMORTIZATION_IN_ARREARS_EUR_SPOT,
                FACILITY_CORE.AMORTIZATION_IN_ARREARS_EUR_BW                               as AMORTIZATION_IN_ARREARS_EUR_BW,
                case
                    when PORTFOLIO.FACILITY_ID = FACILITY_MAPPING.LEITKONTO_FACILITY_ID then
                        COMPENSATIONS.AMORTIZATION_IN_ARREARS_EUR_SPOT_COMPENSATED
                    else
                        0
                    end                                                                    as AMORTIZATION_IN_ARREARS_FOR_COMPENSATION,
                -- INTEREST IN ARREAR (Zinsrückstände)
                FACILITY_CORE.INTEREST_IN_ARREARS_EUR_SPOT_RAW                             as INTEREST_IN_ARREARS_EUR_SPOT_RAW,
                FACILITY_CORE.INTEREST_IN_ARREARS_EUR_SPOT                                 as INTEREST_IN_ARREARS_EUR_SPOT,
                FACILITY_CORE.INTEREST_IN_ARREARS_EUR_BW                                   as INTEREST_IN_ARREARS_EUR_BW,
                case
                    when PORTFOLIO.FACILITY_ID = FACILITY_MAPPING.LEITKONTO_FACILITY_ID then
                        COMPENSATIONS.INTEREST_IN_ARREARS_EUR_SPOT_COMPENSATED
                    else
                        0
                    end                                                                    as INTEREST_IN_ARREARS_FOR_COMPENSATION,
                -- FEES IN ARREAR
                FACILITY_CORE.FEES_IN_ARREARS_EUR_SPOT_RAW                                 as FEES_IN_ARREARS_EUR_SPOT_RAW,
                FACILITY_CORE.FEES_IN_ARREARS_EUR_SPOT                                     as FEES_IN_ARREARS_EUR_SPOT,
                -- BLANKOANTEIL
                FACILITY_SAP.SAP_SUMME_BLANKO                                              as BLANKO_BW,                                    -- SAP_BLANKO                             -- SAP_BLANKO
                -- OFFBALANCE
                FACILITY_CORE.OFFBALANCE_EUR,                                                                                               -- GNI_OFFBALANCE                                                                                                    -- GNI_OFFBALANCE
                FACILITY_CORE.OFFBALANCE_TC,
                -- ANDERES
                FACILITY_SAP.SAP_EWBTES,
                ----- ENDE GELDBETRÄGE -----


                -- RISIKO VORSORGE
                FACILITY_CORE.RIVO_STAGE,
                FACILITY_CORE.RIVO_STAGE_1_EUR,
                FACILITY_CORE.RIVO_STAGE_2_EUR,
                FACILITY_CORE.RIVO_STAGE_3_EUR,
                FACILITY_CORE.RIVO_STAGE_POCI_EUR,
                ABIT_RIVO.EXCHANGE_RATE_EUR2OC                                             as RISK_PROVISION_ABIT_EXCHANGE_RATE_EUR2OC,
                ABIT_RIVO.ORIGINAL_CURRENCY                                                as RISK_PROVISION_ABIT_OC,
                ABIT_RIVO.IFRSMETHOD                                                       as RISK_PROVISION_ABIT_IFRSMETHOD,
                ABIT_RIVO.IFRSMETHOD_PREV_YEAR                                             as RISK_PROVISION_ABIT_IFRSMETHOD_PREV_YEAR,
                ABIT_RIVO.POCI_ACCOUNT                                                     as RISK_PROVISION_ABIT_POCI_ACCOUNT,
                ABIT_RIVO.SPECIFIC_PROVISION_AMOUNT_EUR,
                ABIT_RIVO.SPECIFIC_PROVISION_AMOUNT_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_AMOUNT_PREV_YEAR_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_AMOUNT_PREV_YEAR_EUR,
                ABIT_RIVO.SPECIFIC_PROVISION_AMOUNT_PREV_MONTH_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_AMOUNT_PREV_MONTH_EUR,
                ABIT_RIVO.SPECIFIC_PROVISION_AMOUNT_PREV_QUARTER_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_SUPPLY_FULL_YTD_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_SUPPLY_FULL_YTD_EUR,
                ABIT_RIVO.SPECIFIC_PROVISION_SUPPLY_BAL_YTD_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_SUPPLY_BAL_YTD_EUR,
                ABIT_RIVO.SPECIFIC_PROVISION_SUPPLY_ELSE_YTD_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_SUPPLY_ELSE_YTD_EUR,
                ABIT_RIVO.SPECIFIC_PROVISION_SUPPLY_FULL_MTM_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_SUPPLY_FULL_MTM_EUR,
                ABIT_RIVO.SPECIFIC_PROVISION_SUPPLY_BAL_MTM_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_SUPPLY_BAL_MTM_EUR,
                ABIT_RIVO.SPECIFIC_PROVISION_SUPPLY_ELSE_MTM_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_SUPPLY_ELSE_MTM_EUR,
                ABIT_RIVO.SPECIFIC_PROVISION_LIQUIDATION_FULL_YTD_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_LIQUIDATION_FULL_YTD_EUR,
                ABIT_RIVO.SPECIFIC_PROVISION_LIQUIDATION_BAL_YTD_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_LIQUIDATION_BAL_YTD_EUR,
                ABIT_RIVO.SPECIFIC_PROVISION_LIQUIDATION_ELSE_YTD_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_LIQUIDATION_ELSE_YTD_EUR,
                ABIT_RIVO.SPECIFIC_PROVISION_LIQUIDATION_FULL_MTM_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_LIQUIDATION_FULL_MTM_EUR,
                ABIT_RIVO.SPECIFIC_PROVISION_LIQUIDATION_BAL_MTM_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_LIQUIDATION_BAL_MTM_EUR,
                ABIT_RIVO.SPECIFIC_PROVISION_LIQUIDATION_ELSE_MTM_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_LIQUIDATION_ELSE_MTM_EUR,
                ABIT_RIVO.SPECIFIC_PROVISION_DEBIT_YTD_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_DEBIT_YTD_EUR,
                ABIT_RIVO.SPECIFIC_PROVISION_DEBIT_MTM_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_DEBIT_MTM_EUR,
                ABIT_RIVO.SPECIFIC_PROVISION_UNWINDING_YTD_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_UNWINDING_YTD_EUR,
                ABIT_RIVO.SPECIFIC_PROVISION_UNWINDING_MTM_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_UNWINDING_MTM_EUR,
                ABIT_RIVO.SPECIFIC_PROVISION_MANUAL_AMOUNT_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_MANUAL_AMOUNT_EUR,
                ABIT_RIVO.SPECIFIC_PROVISION_WRITE_OFF_FULL_GUV_YTD_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_WRITE_OFF_FULL_GUV_YTD_EUR,
                ABIT_RIVO.SPECIFIC_PROVISION_WRITE_OFF_FULL_GUV_MTM_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_WRITE_OFF_FULL_GUV_MTM_EUR,
                ABIT_RIVO.SPECIFIC_PROVISION_WRITE_OFF_PART_GUV_YTD_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_WRITE_OFF_PART_GUV_YTD_EUR,
                ABIT_RIVO.SPECIFIC_PROVISION_WRITE_OFF_PART_GUV_MTM_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_WRITE_OFF_PART_GUV_MTM_EUR,
                ABIT_RIVO.SPECIFIC_PROVISION_WRITE_OFF_FULL_DATE,
                ABIT_RIVO.SPECIFIC_PROVISION_WRITE_OFF_PART_DATE,
                ABIT_RIVO.SPECIFIC_PROVISION_POCI_NOMINAL_AMOUNT_ORIG_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_POCI_NOMINAL_AMOUNT_ORIG_EUR,
                ABIT_RIVO.SPECIFIC_PROVISION_POCI_NOMINAL_AMOUNT_ADJ_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_POCI_NOMINAL_AMOUNT_ADJ_EUR,
                ABIT_RIVO.SPECIFIC_PROVISION_POCI_REGEN_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_POCI_REGEN_EUR,
                ABIT_RIVO.SPECIFIC_PROVISION_POCI_LIQUIDATION_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_POCI_LIQUIDATION_EUR,
                ABIT_RIVO.SPECIFIC_PROVISION_POCI_CONSUMPTION_OC,
                ABIT_RIVO.SPECIFIC_PROVISION_POCI_CONSUMPTION_EUR,
                ABIT_RIVO.LOAN_LOSS_PROVISION_AMOUNT_EUR,
                ABIT_RIVO.LOAN_LOSS_PROVISION_AMOUNT_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_AMOUNT_PREV_YEAR_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_AMOUNT_PREV_YEAR_EUR,
                ABIT_RIVO.LOAN_LOSS_PROVISION_AMOUNT_PREV_MONTH_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_AMOUNT_PREV_MONTH_EUR,
                ABIT_RIVO.LOAN_LOSS_PROVISION_AMOUNT_PREV_QUARTER_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_SUPPLY_FULL_YTD_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_SUPPLY_FULL_YTD_EUR,
                ABIT_RIVO.LOAN_LOSS_PROVISION_SUPPLY_BAL_YTD_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_SUPPLY_BAL_YTD_EUR,
                ABIT_RIVO.LOAN_LOSS_PROVISION_SUPPLY_ELSE_YTD_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_SUPPLY_ELSE_YTD_EUR,
                ABIT_RIVO.LOAN_LOSS_PROVISION_SUPPLY_FULL_MTM_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_SUPPLY_FULL_MTM_EUR,
                ABIT_RIVO.LOAN_LOSS_PROVISION_SUPPLY_BAL_MTM_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_SUPPLY_BAL_MTM_EUR,
                ABIT_RIVO.LOAN_LOSS_PROVISION_SUPPLY_ELSE_MTM_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_SUPPLY_ELSE_MTM_EUR,
                ABIT_RIVO.LOAN_LOSS_PROVISION_LIQUIDATION_FULL_YTD_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_LIQUIDATION_FULL_YTD_EUR,
                ABIT_RIVO.LOAN_LOSS_PROVISION_LIQUIDATION_BAL_YTD_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_LIQUIDATION_BAL_YTD_EUR,
                ABIT_RIVO.LOAN_LOSS_PROVISION_LIQUIDATION_ELSE_YTD_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_LIQUIDATION_ELSE_YTD_EUR,
                ABIT_RIVO.LOAN_LOSS_PROVISION_LIQUIDATION_FULL_MTM_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_LIQUIDATION_FULL_MTM_EUR,
                ABIT_RIVO.LOAN_LOSS_PROVISION_LIQUIDATION_BAL_MTM_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_LIQUIDATION_BAL_MTM_EUR,
                ABIT_RIVO.LOAN_LOSS_PROVISION_LIQUIDATION_ELSE_MTM_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_LIQUIDATION_ELSE_MTM_EUR,
                ABIT_RIVO.LOAN_LOSS_PROVISION_DEBIT_YTD_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_DEBIT_YTD_EUR,
                ABIT_RIVO.LOAN_LOSS_PROVISION_DEBIT_MTM_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_DEBIT_MTM_EUR,
                ABIT_RIVO.LOAN_LOSS_PROVISION_UNWINDING_YTD_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_UNWINDING_YTD_EUR,
                ABIT_RIVO.LOAN_LOSS_PROVISION_UNWINDING_MTM_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_UNWINDING_MTM_EUR,
                ABIT_RIVO.LOAN_LOSS_PROVISION_MANUAL_AMOUNT_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_MANUAL_AMOUNT_EUR,
                ABIT_RIVO.LOAN_LOSS_PROVISION_WRITE_OFF_FULL_GUV_YTD_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_WRITE_OFF_FULL_GUV_YTD_EUR,
                ABIT_RIVO.LOAN_LOSS_PROVISION_WRITE_OFF_FULL_GUV_MTM_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_WRITE_OFF_FULL_GUV_MTM_EUR,
                ABIT_RIVO.LOAN_LOSS_PROVISION_WRITE_OFF_PART_GUV_YTD_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_WRITE_OFF_PART_GUV_YTD_EUR,
                ABIT_RIVO.LOAN_LOSS_PROVISION_WRITE_OFF_PART_GUV_MTM_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_WRITE_OFF_PART_GUV_MTM_EUR,
                ABIT_RIVO.LOAN_LOSS_PROVISION_WRITE_OFF_FULL_DATE,
                ABIT_RIVO.LOAN_LOSS_PROVISION_WRITE_OFF_PART_DATE,
                ABIT_RIVO.LOAN_LOSS_PROVISION_POCI_NOMINAL_AMOUNT_ORIG_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_POCI_NOMINAL_AMOUNT_ORIG_EUR,
                ABIT_RIVO.LOAN_LOSS_PROVISION_POCI_NOMINAL_AMOUNT_ADJ_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_POCI_NOMINAL_AMOUNT_ADJ_EUR,
                ABIT_RIVO.LOAN_LOSS_PROVISION_POCI_REGEN_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_POCI_REGEN_EUR,
                ABIT_RIVO.LOAN_LOSS_PROVISION_POCI_LIQUIDATION_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_POCI_LIQUIDATION_EUR,
                ABIT_RIVO.LOAN_LOSS_PROVISION_POCI_CONSUMPTION_OC,
                ABIT_RIVO.LOAN_LOSS_PROVISION_POCI_CONSUMPTION_EUR,
                ZEB_RIVO.EXCHANGE_RATE_EUR2OC                                              as RISK_PROVISION_ZEB_EXCHANGE_RATE_EUR2OC,
                FACILITY_LAST_YEAR.RISK_PROVISION_ZEB_EXCHANGE_RATE_EUR2OC                 as RISK_PROVISION_ZEB_EXCHANGE_RATE_EUR2OC_LAST_YEAR,
                ZEB_RIVO.ZEB_STAGE_ONBALANCE,
                FACILITY_LAST_YEAR.ZEB_STAGE_ONBALANCE                                     as ZEB_STAGE_ONBALANCE_LAST_YEAR,
                ZEB_RIVO.ZEB_EWB_EUR_ONBALANCE,
                FACILITY_LAST_YEAR.ZEB_EWB_EUR_ONBALANCE                                   as ZEB_EWB_EUR_ONBALANCE_LAST_YEAR,
                ZEB_RIVO.ZEB_EWB_OC_ONBALANCE,
                FACILITY_LAST_YEAR.ZEB_EWB_OC_ONBALANCE                                    as ZEB_EWB_OC_ONBALANCE_LAST_YEAR,
                ZEB_RIVO.ZEB_STAGE_OFFBALANCE,
                FACILITY_LAST_YEAR.ZEB_STAGE_OFFBALANCE                                    as ZEB_STAGE_OFFBALANCE_LAST_YEAR,
                ZEB_RIVO.ZEB_EWB_EUR_OFFBALANCE,
                FACILITY_LAST_YEAR.ZEB_EWB_EUR_OFFBALANCE                                  as ZEB_EWB_EUR_OFFBALANCE_LAST_YEAR,
                ZEB_RIVO.ZEB_EWB_OC_OFFBALANCE,
                FACILITY_LAST_YEAR.ZEB_EWB_OC_OFFBALANCE                                   as ZEB_EWB_OC_OFFBALANCE_LAST_YEAR,
                FACILITY_CORE.FVA_EUR                                                      as FAIR_VALUE_ADJUSTMENT_EUR,                    --GNI_FVA
                FACILITY_CORE.FVA_TC                                                       as FAIR_VALUE_ADJUSTMENT_TC,
                CLIENT_INFO.RECOURSE                                                       as RECOURSE,
                FACILITY_CORE.RISK_PROVISION_EUR,
                FACILITY_CORE.RISK_PROVISION_TC,
                FACILITY_CORE.FVC_RISIKOGEWICHT_IN_PROZENT,
--                 -- FAIR VALUE
--                 FACILITY_CORE.DERIVATIVES_FAIR_VALUE_DIRTY_EUR,
--                 FACILITY_CORE.DERIVATIVES_FAIR_VALUE_DIRTY_TC,
--                 FACILITY_CORE.DERIVATE_FAIR_VALUE_EUR,
--                 -- INTEREST RATE
--                 FACILITY_CORE.INTEREST_RATE_TYPE,
--                 FIXED_INTEREST_RATE                                         as INTEREST_RATE_FIXED,
--                 FIXED_INTEREST_RATE_END_DATE                                as INTEREST_RATE_FIXED_END_DATE,
--                 FACILITY_CORE.INTEREST_RATE,
--                 FACILITY_CORE.INTEREST_RATE_FREQUENCY,
--                 FACILITY_CORE.INTEREST_RATE_INDEX,
--                 FACILITY_CORE.INTEREST_RATE_MARGIN,
--                 NEXT_INTEREST_PAYMENT_DATE                                  as INTEREST_NEXT_PAYMENT_DATE,
                -- Amortization
                FACILITY_CORE.AMORTIZATION_TYPE,
                FACILITY_CORE.AMORTIZATION_FREQUENCY_DAYS,
                FACILITY_CORE.NEXT_AMORTIZATION_TO_BE_PAID,
                -- PAST DUE
                FACILITY_CORE.TOTAL_PAST_DUE                                               as PAST_DUE_TOTAL_EUR,
                FACILITY_CORE.ZEB_E_DAYS_PAST_DUE_NO                                       as DAYS_PAST_DUE_ZEB,
                FACILITY_CORE.DAYS_PAST_DUE                                                as DAYS_PAST_DUE_BW,                             --
                FACILITY_SAP.PROBABILITY_OF_DEFAULT_RATE                                   as PROBABILITY_OF_DEFAULT_RATE_BW,               -- SAP_PD
                FACILITY_CORE.ZEB_R_ONE_YEAR_PROB_OF_DEFAULT_RATE                          as PROBABILITY_OF_DEFAULT_RATE_ZEB,              -- GNI_ZEB_PD
                FACILITY_SAP.DEFAULT                                                       as DEFAULT_BW,
                FACILITY_SAP.CREDIT_CONVERSION_FACTOR                                      as CREDIT_CONVERSION_FACTOR_BW,                  -- SAP_CCF
                FACILITY_CORE.AUSZAHLUNGSPLICHT_EUR,                                                                                        -- GNI_AUSZAHLUNGSPFLICHT
                coalesce(FACILITY_SAP.SAP_FREIELINIE, FACILITY_KR.FREIE_LINIE)             as FREIE_LINIE,                                  -- SAP_FREIELINIE
                FACILITY_LAST_YEAR.FREIE_LINIE                                             as FREIE_LINIE_LAST_YEAR,                        -- SAP_FREIELINIE_VJ

                -- FLAGS
                FACILITY_CORE.ZEB_PRJ_IS_FINREP_FORBORNE                                   as PRJ_IS_FINREP_FORBORNE,                       -- GNI_ZEB_FORBORNE
                FACILITY_CORE.GUARANTEE_FLAG                                               as IS_IN_GUARANTEE,
                case when FACILITY_CORE.NICHT_IM_BW_REWE = 1 then FALSE else TRUE end      as IS_IN_BW_P62,
                FACILITY_CORE.INAKTIV                                                      as IS_INACTIVE,
                PORTFOLIO.IS_FACILITY_FROM_SINGAPORE                                       as IS_FACILITY_FROM_SINGAPORE,
                PORTFOLIO.IS_PWC_FOCUS                                                     as IS_PWC_FOCUS,                                 -- FOKUSSYSTEM
                SAP_PRODUCTS.IS_AVAL                                                       as IS_AVAL,
                -- ZUSATZINFO zum Filtern
                COALESCE(FACILITY_CORE.PRODUCTTYPE, PORTFOLIO.PRODUCTTYPE_DETAIL)          as PRODUCTTYPE_DETAIL,                           -- nicht PWC relevant
                coalesce(PORTFOLIO2SUMMARY.OE_TEXT_SIMPLIFIED,
                         FACILITY_CORE.KUNDENBETREUER_OE_BEZEICHNUNG,
                         PORTFOLIO.PORTFOLIO_IWHS_CLIENT_SERVICE
                    )                                                                      as PORTFOLIO_CLIENT_SIMPLIFIED                   -- nicht PWC relevant
         from PORTFOLIO
                  left join CLIENTS on (CLIENTS.BRANCH_CLIENT, CLIENTS.CLIENT_NO) =
                                       (PORTFOLIO.BRANCH_CLIENT, PORTFOLIO.CLIENT_NO)
                  left join FACILITY_CORE
                            on (FACILITY_CORE.CUT_OFF_DATE, FACILITY_CORE.FACILITY_ID) =
                               (PORTFOLIO.CUT_OFF_DATE, PORTFOLIO.FACILITY_ID)
                  left join FACILITY_MAPPING
                            on (FACILITY_MAPPING.CUT_OFF_DATE, FACILITY_MAPPING.FACILITY_ID) =
                               (PORTFOLIO.CUT_OFF_DATE, PORTFOLIO.FACILITY_ID)
                  left join CALC.SWITCH_FACILITY_ABIT_RISK_PROVISION_CURRENT as ABIT_RIVO
                            on (ABIT_RIVO.CUT_OFF_DATE, ABIT_RIVO.FACILITY_ID) =
                               (PORTFOLIO.CUT_OFF_DATE, PORTFOLIO.FACILITY_ID)
                  left join CALC.SWITCH_FACILITY_ZEB_RISK_PROVISION_CURRENT as ZEB_RIVO
                            on (ZEB_RIVO.CUT_OFF_DATE, ZEB_RIVO.FACILITY_ID) =
                               (PORTFOLIO.CUT_OFF_DATE, PORTFOLIO.FACILITY_ID)
                  left join FACILITY_KR on (FACILITY_KR.CUT_OFF_DATE, FACILITY_KR.FACILITY_ID) =
                                           (PORTFOLIO.CUT_OFF_DATE, PORTFOLIO.FACILITY_ID)
                  left join FACILITY_SAP on (FACILITY_SAP.CUT_OFF_DATE, FACILITY_SAP.FACILITY_ID) =
                                            (PORTFOLIO.CUT_OFF_DATE, PORTFOLIO.FACILITY_ID)
                  left join SMAP.SAP_PRODUCTS as SAP_PRODUCTS on (SAP_PRODUCTS.PRODUCT_NO) = (FACILITY_SAP.SAP_PRODUKT)
                  left join COMPENSATIONS as COMPENSATIONS
                            on (COMPENSATIONS.LEITKONTO_FACILITY_ID) = (PORTFOLIO.FACILITY_ID)
                  left join FACILITY_LAST_YEAR
                            on (FACILITY_LAST_YEAR.CUT_OFF_DATE_NEXT_YEAR, FACILITY_LAST_YEAR.FACILITY_ID) =
                               (PORTFOLIO.CUT_OFF_DATE, PORTFOLIO.FACILITY_ID)
                  left join CLIENT_INFO on (CLIENT_INFO.CLIENT_ID_ORIG, CLIENT_INFO.CUT_OFF_DATE) =
                                           (PORTFOLIO.CLIENT_ID_ORIG, PORTFOLIO.CUT_OFF_DATE)
                  left join PORTFOLIO2SUMMARY on coalesce(PORTFOLIO.PORTFOLIO_IWHS_CLIENT_KUNDENBERATER,
                                                          PORTFOLIO.PORTFOLIO_IWHS_CLIENT_SERVICE) =
                                                 PORTFOLIO2SUMMARY.OE_TEXT
     ),
     DATA as (
         select *,
                case
                    when not IS_PWC_FOCUS then
                        NULL
                    when LEADING_FACILITY_ID is NULL and IS_AVAL then
                        max(0, coalesce(PRINCIPAL_OUTSTANDING_EUR_AVAL, 0))
                    when LEADING_FACILITY_ID is NULL and PORTFOLIO_CLIENT_PERSON_IWHS = 'RSM Markets' and
                         PRINCIPAL_OUTSTANDING_EUR_BW is NULL then
                        NULL
                    when LEADING_FACILITY_ID is NULL then
                            max(0, coalesce(PRINCIPAL_OUTSTANDING_EUR_SPOT, 0)) -
                            coalesce(AMORTIZATION_IN_ARREARS_EUR_SPOT, 0) - coalesce(INTEREST_IN_ARREARS_EUR_SPOT, 0)
                    when PRINCIPAL_OUTSTANDING_EUR_COMPENSATION < 0 then
                        0
                    else
                            coalesce(PRINCIPAL_OUTSTANDING_EUR_COMPENSATION, 0) -
                            coalesce(AMORTIZATION_IN_ARREARS_FOR_COMPENSATION, 0) -
                            coalesce(INTEREST_IN_ARREARS_FOR_COMPENSATION, 0)
                    end           as PRINCIPAL_OUTSTANDING_EUR_SEGUE,
                -- INFO STEMPEL
                CURRENT_USER      as CREATED_USER,
                CURRENT_TIMESTAMP as CREATED_TIMESTAMP
         from FACILITY_UNION
     )
select DATE(CUT_OFF_DATE)                                                     as CUT_OFF_DATE,
       DATE(DATA_CUT_OFF_DATE)                                                as DATA_CUT_OFF_DATE,
       cast(BRANCH_FACILITY as VARCHAR(4))                                    as BRANCH_FACILITY,
       cast(FACILITY_ID as VARCHAR(64))                                       as FACILITY_ID,
       cast(FACILITY_ID_LEADING as VARCHAR(64))                               as FACILITY_ID_LEADING,
       nullif(cast(FACILITY_ID_ALTERNATIVE as VARCHAR(64)), null)             as FACILITY_ID_ALTERNATIVE,
       nullif(cast(LEADING_FACILITY_ID as VARCHAR(64)), null)                 as LEADING_FACILITY_ID,
       nullif(cast(PARENT_FACILITY_ID as VARCHAR(64)), null)                  as PARENT_FACILITY_ID,
       nullif(cast(CORRESPONDING_LIMIT_ID as VARCHAR(64)), null)              as CORRESPONDING_LIMIT_ID,
       nullif(cast(SYSTEM_SATZART as VARCHAR(8)), null)                       as SYSTEM_SATZART,
       nullif(cast(PRODUCT_GROUP as VARCHAR(64)), null)                       as PRODUCT_GROUP,
       nullif(cast(PRODUCTTYPE as VARCHAR(256)), null)                        as PRODUCTTYPE,
       nullif(BIGINT(PRODUCT_BW), null)                                       as PRODUCT_BW,
       nullif(cast(PRODUCT_BW_TEXT as VARCHAR(256)), null)                    as PRODUCT_BW_TEXT,
       nullif(cast(IN_SPOT as BOOLEAN), null)                                 as IN_SPOT,
       nullif(cast(IN_BW as BOOLEAN), null)                                   as IN_BW,
       nullif(cast(PRIMARY_SOURCE as VARCHAR(64)), null)                      as PRIMARY_SOURCE,
       nullif(cast(BRANCH as VARCHAR(4)), null)                               as BRANCH,
       nullif(cast(PORTFOLIO_CLIENT_PERSON_IWHS as VARCHAR(512)), null)       as PORTFOLIO_CLIENT_PERSON_IWHS,
       nullif(BIGINT(KUSY), null)                                             as KUSY,
       nullif(BIGINT(SEGMENT), null)                                          as SEGMENT,
       cast(CLIENT_ID as VARCHAR(32))                                         as CLIENT_ID,
       cast(CLIENT_ID_LEADING as VARCHAR(32))                                 as CLIENT_ID_LEADING,
       nullif(cast(CLIENT_NO_BW as VARCHAR(32)), null)                        as CLIENT_NO_BW,
       nullif(cast(CLIENT_TYPE as VARCHAR(1)), null)                          as CLIENT_TYPE,
       nullif(cast(CLIENT_NAME as VARCHAR(512)), null)                        as CLIENT_NAME,
       nullif(cast(CLIENT_NAME_ANONYMIZED as VARCHAR(512)), null)             as CLIENT_NAME_ANONYMIZED,
       nullif(cast(CLIENT_COUNTRY_ALPHA2 as VARCHAR(2)), null)                as CLIENT_COUNTRY_ALPHA2,
       nullif(cast(CLIENT_NACE as VARCHAR(8)), null)                          as CLIENT_NACE,
       nullif(cast(GROUP_ID as VARCHAR(32)), null)                            as GROUP_ID,
       nullif(cast(GROUP_NAME as VARCHAR(512)), null)                         as GROUP_NAME,
       nullif(BIGINT(GVK_BUNDESBANKNUMMER), null)                             as GVK_BUNDESBANKNUMMER,
       nullif(cast(CURRENCY as VARCHAR(3)), null)                             as CURRENCY,
       nullif(cast(CURRENCY_BW as VARCHAR(3)), null)                          as CURRENCY_BW,
       nullif(cast(SYNDICATION_ROLE as VARCHAR(64)), null)                    as SYNDICATION_ROLE,
       nullif(DATE(ORIGINATION_DATE), null)                                   as ORIGINATION_DATE,
       nullif(DATE(CURRENT_CONTRACTUAL_MATURITY_DATE), null)                  as CURRENT_CONTRACTUAL_MATURITY_DATE,
       nullif(cast(RATING_MODULE_CLIENT as VARCHAR(32)), null)                as RATING_MODULE_CLIENT,
       nullif(cast(RATING_ID_ZEB as VARCHAR(10)), null)                       as RATING_ID_ZEB,
       nullif(cast(RATING_MODULE_ZEB as VARCHAR(8)), null)                    as RATING_MODULE_ZEB,
       nullif(cast(RATING_SUBMODULE_ZEB as VARCHAR(32)), null)                as RATING_SUBMODULE_ZEB,
       nullif(INTEGER(RATING_MODULE_BW), null)                                as RATING_MODULE_BW,
       nullif(cast(RATING_MODULE_NAME_BW as VARCHAR(16)), null)               as RATING_MODULE_NAME_BW,
       nullif(cast(RATING_SUBMODULE_BW as VARCHAR(64)), null)                 as RATING_SUBMODULE_BW,
       nullif(cast(RATING_MODULE_DESCRIPTION_BW as VARCHAR(512)), null)       as RATING_MODULE_DESCRIPTION_BW,
       nullif(cast(PERFORMANCE_STATUS as VARCHAR(16)), null)                  as PERFORMANCE_STATUS,
       nullif(cast(RATING_ALPHA as VARCHAR(8)), null)                         as RATING_ALPHA,
       nullif(cast(RATING_ALPHA_PREV_YEAR as VARCHAR(8)), null)               as RATING_ALPHA_PREV_YEAR,
       nullif(cast(RATING_ALPHA_IRBA as VARCHAR(8)), null)                    as RATING_ALPHA_IRBA,
       nullif(INTEGER(RATING_NUMERIC_IRBA), null)                             as RATING_NUMERIC_IRBA,
       nullif(cast(RATING_ALPHA_KSA as VARCHAR(8)), null)                     as RATING_ALPHA_KSA,
       nullif(INTEGER(RATING_NUMERIC_KSA), null)                              as RATING_NUMERIC_KSA,
       nullif(INTEGER(RATING_NUMERIC_FVC), null)                              as RATING_NUMERIC_FVC,
       nullif(DATE(RATING_DATE_FVC), null)                                    as RATING_DATE_FVC,
       nullif(INTEGER(RATING_BW), null)                                       as RATING_BW,
       nullif(INTEGER(RATING_BW_LAST_YEAR), null)                             as RATING_BW_LAST_YEAR,
       nullif(cast(RATING_BW_TYPE as VARCHAR(16)), null)                      as RATING_BW_TYPE,
       nullif(INTEGER(HEDGING_FLAG_BW), null)                                 as HEDGING_FLAG_BW,
       nullif(DOUBLE(STUECKZINSEN_BW), null)                                  as STUECKZINSEN_BW,
       nullif(BIGINT(RATING_ID_KUNDE), null)                                  as RATING_ID_KUNDE,
       nullif(BIGINT(RATING_ID_KUNDE_LAST_YEAR), null)                        as RATING_ID_KUNDE_LAST_YEAR,
       nullif(cast(PRINCIPAL_TYPE as VARCHAR(32)), null)                      as PRINCIPAL_TYPE,
       nullif(DOUBLE(PRINCIPAL_OUTSTANDING_EUR_SPOT_RAW), null)               as PRINCIPAL_OUTSTANDING_EUR_SPOT_RAW,
       nullif(DOUBLE(PRINCIPAL_OUTSTANDING_EUR_SPOT_RAW_LAST_YEAR), null)     as PRINCIPAL_OUTSTANDING_EUR_SPOT_RAW_LAST_YEAR,
       nullif(DOUBLE(PRINCIPAL_OUTSTANDING_EUR_SPOT), null)                   as PRINCIPAL_OUTSTANDING_EUR_SPOT,
       nullif(DOUBLE(PRINCIPAL_OUTSTANDING_EUR_SPOT_LAST_YEAR), null)         as PRINCIPAL_OUTSTANDING_EUR_SPOT_LAST_YEAR,
       nullif(DOUBLE(PRINCIPAL_OUTSTANDING_EUR_AVAL), null)                   as PRINCIPAL_OUTSTANDING_EUR_AVAL,
       nullif(DOUBLE(PRINCIPAL_OUTSTANDING_EUR_BW), null)                     as PRINCIPAL_OUTSTANDING_EUR_BW,
       nullif(DOUBLE(PRINCIPAL_OUTSTANDING_EUR_BW_LAST_YEAR), null)           as PRINCIPAL_OUTSTANDING_EUR_BW_LAST_YEAR,
       nullif(DOUBLE(PRINCIPAL_OUTSTANDING_EUR_KR), null)                     as PRINCIPAL_OUTSTANDING_EUR_KR,
       nullif(DOUBLE(PRINCIPAL_OUTSTANDING_EUR_COMPENSATION), null)           as PRINCIPAL_OUTSTANDING_EUR_COMPENSATION,
       nullif(DOUBLE(PRINCIPAL_OUTSTANDING_EUR_SEGUE), null)                  as PRINCIPAL_OUTSTANDING_EUR_SEGUE,
       nullif(DOUBLE(OWN_SYNDICATE_QUOTA), null)                              as OWN_SYNDICATE_QUOTA,
       nullif(DOUBLE(BILANZWERT_BRUTTO_EUR), null)                            as BILANZWERT_BRUTTO_EUR,
       nullif(DOUBLE(BILANZWERT_BRUTTO_TC), null)                             as BILANZWERT_BRUTTO_TC,
       nullif(DOUBLE(BILANZWERT_IFRS9_EUR), null)                             as BILANZWERT_IFRS9_EUR,
       nullif(DOUBLE(BILANZWERT_IFRS9_TC), null)                              as BILANZWERT_IFRS9_TC,
       nullif(DOUBLE(BILANZWERT_HGB_EUR), null)                               as BILANZWERT_HGB_EUR,
       nullif(DOUBLE(BILANZWERT_HGB_TC), null)                                as BILANZWERT_HGB_TC,
       nullif(DOUBLE(EAD_EUR_ZEB), null)                                      as EAD_EUR_ZEB,
       nullif(DOUBLE(EAD_TC_ZEB), null)                                       as EAD_TC_ZEB,
       nullif(DOUBLE(EAD_TOTAL_EUR), null)                                    as EAD_TOTAL_EUR,
       nullif(DOUBLE(EAD_TOTAL_TC_ZEB), null)                                 as EAD_TOTAL_TC_ZEB,
       nullif(DOUBLE(EAD_NON_SECURITIZED_EUR), null)                          as EAD_NON_SECURITIZED_EUR,
       nullif(DOUBLE(EAD_SECURITIZED), null)                                  as EAD_SECURITIZED,
       nullif(DOUBLE(EAD_BW), null)                                           as EAD_BW,
       nullif(DOUBLE(EL_BW), null)                                            as EL_BW,
       nullif(DOUBLE(LGD_COLL_RATE_ZEB), null)                                as LGD_COLL_RATE_ZEB,
       nullif(DOUBLE(LGD_NET_RATE_ZEB), null)                                 as LGD_NET_RATE_ZEB,
       nullif(DOUBLE(LGD_DEFAULT_RATE_ZEB), null)                             as LGD_DEFAULT_RATE_ZEB,
       nullif(DOUBLE(LGD_PERCENT_FVC), null)                                  as LGD_PERCENT_FVC,
       nullif(DOUBLE(LGD_DEFAULT_RATE_BW), null)                              as LGD_DEFAULT_RATE_BW,
       nullif(DOUBLE(AMORTIZATION_IN_ARREARS_EUR_SPOT_RAW), null)             as AMORTIZATION_IN_ARREARS_EUR_SPOT_RAW,
       nullif(DOUBLE(AMORTIZATION_IN_ARREARS_EUR_SPOT), null)                 as AMORTIZATION_IN_ARREARS_EUR_SPOT,
       nullif(DOUBLE(AMORTIZATION_IN_ARREARS_EUR_BW), null)                   as AMORTIZATION_IN_ARREARS_EUR_BW,
       coalesce(nullif(DOUBLE(AMORTIZATION_IN_ARREARS_FOR_COMPENSATION), null),
                0)                                                            as AMORTIZATION_IN_ARREARS_FOR_COMPENSATION,
       nullif(DOUBLE(INTEREST_IN_ARREARS_EUR_SPOT_RAW), null)                 as INTEREST_IN_ARREARS_EUR_SPOT_RAW,
       nullif(DOUBLE(INTEREST_IN_ARREARS_EUR_SPOT), null)                     as INTEREST_IN_ARREARS_EUR_SPOT,
       nullif(DOUBLE(INTEREST_IN_ARREARS_EUR_BW), null)                       as INTEREST_IN_ARREARS_EUR_BW,
       coalesce(nullif(DOUBLE(INTEREST_IN_ARREARS_FOR_COMPENSATION), null),
                0)                                                            as INTEREST_IN_ARREARS_FOR_COMPENSATION,
       nullif(DOUBLE(FEES_IN_ARREARS_EUR_SPOT_RAW), null)                     as FEES_IN_ARREARS_EUR_SPOT_RAW,
       nullif(DOUBLE(FEES_IN_ARREARS_EUR_SPOT), null)                         as FEES_IN_ARREARS_EUR_SPOT,
       nullif(DOUBLE(BLANKO_BW), null)                                        as BLANKO_BW,
       nullif(DOUBLE(OFFBALANCE_EUR), null)                                   as OFFBALANCE_EUR,
       nullif(DOUBLE(OFFBALANCE_TC), null)                                    as OFFBALANCE_TC,
       nullif(DOUBLE(SAP_EWBTES), null)                                       as SAP_EWBTES,
       nullif(cast(RIVO_STAGE as VARCHAR(8)), null)                           as RIVO_STAGE,
       nullif(DOUBLE(RIVO_STAGE_1_EUR), null)                                 as RIVO_STAGE_1_EUR,
       nullif(DOUBLE(RIVO_STAGE_2_EUR), null)                                 as RIVO_STAGE_2_EUR,
       nullif(DOUBLE(RIVO_STAGE_3_EUR), null)                                 as RIVO_STAGE_3_EUR,
       nullif(DOUBLE(RIVO_STAGE_POCI_EUR), null)                              as RIVO_STAGE_POCI_EUR,
       nullif(DOUBLE(RISK_PROVISION_ABIT_EXCHANGE_RATE_EUR2OC), null)         as RISK_PROVISION_ABIT_EXCHANGE_RATE_EUR2OC,
       nullif(cast(RISK_PROVISION_ABIT_OC as CHARACTER(3)), null)             as RISK_PROVISION_ABIT_OC,
       nullif(INTEGER(RISK_PROVISION_ABIT_IFRSMETHOD), null)                  as RISK_PROVISION_ABIT_IFRSMETHOD,
       nullif(INTEGER(RISK_PROVISION_ABIT_IFRSMETHOD_PREV_YEAR), null)        as RISK_PROVISION_ABIT_IFRSMETHOD_PREV_YEAR,
       nullif(INTEGER(RISK_PROVISION_ABIT_POCI_ACCOUNT), null)                as RISK_PROVISION_ABIT_POCI_ACCOUNT,
       nullif(DOUBLE(SPECIFIC_PROVISION_AMOUNT_EUR), null)                    as SPECIFIC_PROVISION_AMOUNT_EUR,
       nullif(DOUBLE(SPECIFIC_PROVISION_AMOUNT_OC), null)                     as SPECIFIC_PROVISION_AMOUNT_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_AMOUNT_PREV_YEAR_OC), null)           as SPECIFIC_PROVISION_AMOUNT_PREV_YEAR_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_AMOUNT_PREV_YEAR_EUR), null)          as SPECIFIC_PROVISION_AMOUNT_PREV_YEAR_EUR,
       nullif(DOUBLE(SPECIFIC_PROVISION_AMOUNT_PREV_MONTH_OC), null)          as SPECIFIC_PROVISION_AMOUNT_PREV_MONTH_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_AMOUNT_PREV_MONTH_EUR), null)         as SPECIFIC_PROVISION_AMOUNT_PREV_MONTH_EUR,
       nullif(DOUBLE(SPECIFIC_PROVISION_AMOUNT_PREV_QUARTER_OC), null)        as SPECIFIC_PROVISION_AMOUNT_PREV_QUARTER_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_SUPPLY_FULL_YTD_OC), null)            as SPECIFIC_PROVISION_SUPPLY_FULL_YTD_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_SUPPLY_FULL_YTD_EUR), null)           as SPECIFIC_PROVISION_SUPPLY_FULL_YTD_EUR,
       nullif(DOUBLE(SPECIFIC_PROVISION_SUPPLY_BAL_YTD_OC), null)             as SPECIFIC_PROVISION_SUPPLY_BAL_YTD_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_SUPPLY_BAL_YTD_EUR), null)            as SPECIFIC_PROVISION_SUPPLY_BAL_YTD_EUR,
       nullif(DOUBLE(SPECIFIC_PROVISION_SUPPLY_ELSE_YTD_OC), null)            as SPECIFIC_PROVISION_SUPPLY_ELSE_YTD_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_SUPPLY_ELSE_YTD_EUR), null)           as SPECIFIC_PROVISION_SUPPLY_ELSE_YTD_EUR,
       nullif(DOUBLE(SPECIFIC_PROVISION_SUPPLY_FULL_MTM_OC), null)            as SPECIFIC_PROVISION_SUPPLY_FULL_MTM_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_SUPPLY_FULL_MTM_EUR), null)           as SPECIFIC_PROVISION_SUPPLY_FULL_MTM_EUR,
       nullif(DOUBLE(SPECIFIC_PROVISION_SUPPLY_BAL_MTM_OC), null)             as SPECIFIC_PROVISION_SUPPLY_BAL_MTM_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_SUPPLY_BAL_MTM_EUR), null)            as SPECIFIC_PROVISION_SUPPLY_BAL_MTM_EUR,
       nullif(DOUBLE(SPECIFIC_PROVISION_SUPPLY_ELSE_MTM_OC), null)            as SPECIFIC_PROVISION_SUPPLY_ELSE_MTM_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_SUPPLY_ELSE_MTM_EUR), null)           as SPECIFIC_PROVISION_SUPPLY_ELSE_MTM_EUR,
       nullif(DOUBLE(SPECIFIC_PROVISION_LIQUIDATION_FULL_YTD_OC), null)       as SPECIFIC_PROVISION_LIQUIDATION_FULL_YTD_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_LIQUIDATION_FULL_YTD_EUR), null)      as SPECIFIC_PROVISION_LIQUIDATION_FULL_YTD_EUR,
       nullif(DOUBLE(SPECIFIC_PROVISION_LIQUIDATION_BAL_YTD_OC), null)        as SPECIFIC_PROVISION_LIQUIDATION_BAL_YTD_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_LIQUIDATION_BAL_YTD_EUR), null)       as SPECIFIC_PROVISION_LIQUIDATION_BAL_YTD_EUR,
       nullif(DOUBLE(SPECIFIC_PROVISION_LIQUIDATION_ELSE_YTD_OC), null)       as SPECIFIC_PROVISION_LIQUIDATION_ELSE_YTD_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_LIQUIDATION_ELSE_YTD_EUR), null)      as SPECIFIC_PROVISION_LIQUIDATION_ELSE_YTD_EUR,
       nullif(DOUBLE(SPECIFIC_PROVISION_LIQUIDATION_FULL_MTM_OC), null)       as SPECIFIC_PROVISION_LIQUIDATION_FULL_MTM_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_LIQUIDATION_FULL_MTM_EUR), null)      as SPECIFIC_PROVISION_LIQUIDATION_FULL_MTM_EUR,
       nullif(DOUBLE(SPECIFIC_PROVISION_LIQUIDATION_BAL_MTM_OC), null)        as SPECIFIC_PROVISION_LIQUIDATION_BAL_MTM_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_LIQUIDATION_BAL_MTM_EUR), null)       as SPECIFIC_PROVISION_LIQUIDATION_BAL_MTM_EUR,
       nullif(DOUBLE(SPECIFIC_PROVISION_LIQUIDATION_ELSE_MTM_OC), null)       as SPECIFIC_PROVISION_LIQUIDATION_ELSE_MTM_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_LIQUIDATION_ELSE_MTM_EUR), null)      as SPECIFIC_PROVISION_LIQUIDATION_ELSE_MTM_EUR,
       nullif(DOUBLE(SPECIFIC_PROVISION_DEBIT_YTD_OC), null)                  as SPECIFIC_PROVISION_DEBIT_YTD_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_DEBIT_YTD_EUR), null)                 as SPECIFIC_PROVISION_DEBIT_YTD_EUR,
       nullif(DOUBLE(SPECIFIC_PROVISION_DEBIT_MTM_OC), null)                  as SPECIFIC_PROVISION_DEBIT_MTM_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_DEBIT_MTM_EUR), null)                 as SPECIFIC_PROVISION_DEBIT_MTM_EUR,
       nullif(DOUBLE(SPECIFIC_PROVISION_UNWINDING_YTD_OC), null)              as SPECIFIC_PROVISION_UNWINDING_YTD_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_UNWINDING_YTD_EUR), null)             as SPECIFIC_PROVISION_UNWINDING_YTD_EUR,
       nullif(DOUBLE(SPECIFIC_PROVISION_UNWINDING_MTM_OC), null)              as SPECIFIC_PROVISION_UNWINDING_MTM_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_UNWINDING_MTM_EUR), null)             as SPECIFIC_PROVISION_UNWINDING_MTM_EUR,
       nullif(DOUBLE(SPECIFIC_PROVISION_MANUAL_AMOUNT_OC), null)              as SPECIFIC_PROVISION_MANUAL_AMOUNT_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_MANUAL_AMOUNT_EUR), null)             as SPECIFIC_PROVISION_MANUAL_AMOUNT_EUR,
       nullif(DOUBLE(SPECIFIC_PROVISION_WRITE_OFF_FULL_GUV_YTD_OC), null)     as SPECIFIC_PROVISION_WRITE_OFF_FULL_GUV_YTD_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_WRITE_OFF_FULL_GUV_YTD_EUR), null)    as SPECIFIC_PROVISION_WRITE_OFF_FULL_GUV_YTD_EUR,
       nullif(DOUBLE(SPECIFIC_PROVISION_WRITE_OFF_FULL_GUV_MTM_OC), null)     as SPECIFIC_PROVISION_WRITE_OFF_FULL_GUV_MTM_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_WRITE_OFF_FULL_GUV_MTM_EUR), null)    as SPECIFIC_PROVISION_WRITE_OFF_FULL_GUV_MTM_EUR,
       nullif(DOUBLE(SPECIFIC_PROVISION_WRITE_OFF_PART_GUV_YTD_OC), null)     as SPECIFIC_PROVISION_WRITE_OFF_PART_GUV_YTD_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_WRITE_OFF_PART_GUV_YTD_EUR), null)    as SPECIFIC_PROVISION_WRITE_OFF_PART_GUV_YTD_EUR,
       nullif(DOUBLE(SPECIFIC_PROVISION_WRITE_OFF_PART_GUV_MTM_OC), null)     as SPECIFIC_PROVISION_WRITE_OFF_PART_GUV_MTM_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_WRITE_OFF_PART_GUV_MTM_EUR), null)    as SPECIFIC_PROVISION_WRITE_OFF_PART_GUV_MTM_EUR,
       nullif(DATE(SPECIFIC_PROVISION_WRITE_OFF_FULL_DATE), null)             as SPECIFIC_PROVISION_WRITE_OFF_FULL_DATE,
       nullif(DATE(SPECIFIC_PROVISION_WRITE_OFF_PART_DATE), null)             as SPECIFIC_PROVISION_WRITE_OFF_PART_DATE,
       nullif(DOUBLE(SPECIFIC_PROVISION_POCI_NOMINAL_AMOUNT_ORIG_OC), null)   as SPECIFIC_PROVISION_POCI_NOMINAL_AMOUNT_ORIG_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_POCI_NOMINAL_AMOUNT_ORIG_EUR),
              null)                                                           as SPECIFIC_PROVISION_POCI_NOMINAL_AMOUNT_ORIG_EUR,
       nullif(DOUBLE(SPECIFIC_PROVISION_POCI_NOMINAL_AMOUNT_ADJ_OC), null)    as SPECIFIC_PROVISION_POCI_NOMINAL_AMOUNT_ADJ_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_POCI_NOMINAL_AMOUNT_ADJ_EUR), null)   as SPECIFIC_PROVISION_POCI_NOMINAL_AMOUNT_ADJ_EUR,
       nullif(DOUBLE(SPECIFIC_PROVISION_POCI_REGEN_OC), null)                 as SPECIFIC_PROVISION_POCI_REGEN_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_POCI_REGEN_EUR), null)                as SPECIFIC_PROVISION_POCI_REGEN_EUR,
       nullif(DOUBLE(SPECIFIC_PROVISION_POCI_LIQUIDATION_OC), null)           as SPECIFIC_PROVISION_POCI_LIQUIDATION_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_POCI_LIQUIDATION_EUR), null)          as SPECIFIC_PROVISION_POCI_LIQUIDATION_EUR,
       nullif(DOUBLE(SPECIFIC_PROVISION_POCI_CONSUMPTION_OC), null)           as SPECIFIC_PROVISION_POCI_CONSUMPTION_OC,
       nullif(DOUBLE(SPECIFIC_PROVISION_POCI_CONSUMPTION_EUR), null)          as SPECIFIC_PROVISION_POCI_CONSUMPTION_EUR,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_AMOUNT_EUR), null)                   as LOAN_LOSS_PROVISION_AMOUNT_EUR,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_AMOUNT_OC), null)                    as LOAN_LOSS_PROVISION_AMOUNT_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_AMOUNT_PREV_YEAR_OC), null)          as LOAN_LOSS_PROVISION_AMOUNT_PREV_YEAR_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_AMOUNT_PREV_YEAR_EUR), null)         as LOAN_LOSS_PROVISION_AMOUNT_PREV_YEAR_EUR,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_AMOUNT_PREV_MONTH_OC), null)         as LOAN_LOSS_PROVISION_AMOUNT_PREV_MONTH_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_AMOUNT_PREV_MONTH_EUR), null)        as LOAN_LOSS_PROVISION_AMOUNT_PREV_MONTH_EUR,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_AMOUNT_PREV_QUARTER_OC), null)       as LOAN_LOSS_PROVISION_AMOUNT_PREV_QUARTER_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_SUPPLY_FULL_YTD_OC), null)           as LOAN_LOSS_PROVISION_SUPPLY_FULL_YTD_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_SUPPLY_FULL_YTD_EUR), null)          as LOAN_LOSS_PROVISION_SUPPLY_FULL_YTD_EUR,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_SUPPLY_BAL_YTD_OC), null)            as LOAN_LOSS_PROVISION_SUPPLY_BAL_YTD_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_SUPPLY_BAL_YTD_EUR), null)           as LOAN_LOSS_PROVISION_SUPPLY_BAL_YTD_EUR,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_SUPPLY_ELSE_YTD_OC), null)           as LOAN_LOSS_PROVISION_SUPPLY_ELSE_YTD_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_SUPPLY_ELSE_YTD_EUR), null)          as LOAN_LOSS_PROVISION_SUPPLY_ELSE_YTD_EUR,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_SUPPLY_FULL_MTM_OC), null)           as LOAN_LOSS_PROVISION_SUPPLY_FULL_MTM_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_SUPPLY_FULL_MTM_EUR), null)          as LOAN_LOSS_PROVISION_SUPPLY_FULL_MTM_EUR,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_SUPPLY_BAL_MTM_OC), null)            as LOAN_LOSS_PROVISION_SUPPLY_BAL_MTM_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_SUPPLY_BAL_MTM_EUR), null)           as LOAN_LOSS_PROVISION_SUPPLY_BAL_MTM_EUR,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_SUPPLY_ELSE_MTM_OC), null)           as LOAN_LOSS_PROVISION_SUPPLY_ELSE_MTM_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_SUPPLY_ELSE_MTM_EUR), null)          as LOAN_LOSS_PROVISION_SUPPLY_ELSE_MTM_EUR,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_LIQUIDATION_FULL_YTD_OC), null)      as LOAN_LOSS_PROVISION_LIQUIDATION_FULL_YTD_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_LIQUIDATION_FULL_YTD_EUR), null)     as LOAN_LOSS_PROVISION_LIQUIDATION_FULL_YTD_EUR,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_LIQUIDATION_BAL_YTD_OC), null)       as LOAN_LOSS_PROVISION_LIQUIDATION_BAL_YTD_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_LIQUIDATION_BAL_YTD_EUR), null)      as LOAN_LOSS_PROVISION_LIQUIDATION_BAL_YTD_EUR,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_LIQUIDATION_ELSE_YTD_OC), null)      as LOAN_LOSS_PROVISION_LIQUIDATION_ELSE_YTD_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_LIQUIDATION_ELSE_YTD_EUR), null)     as LOAN_LOSS_PROVISION_LIQUIDATION_ELSE_YTD_EUR,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_LIQUIDATION_FULL_MTM_OC), null)      as LOAN_LOSS_PROVISION_LIQUIDATION_FULL_MTM_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_LIQUIDATION_FULL_MTM_EUR), null)     as LOAN_LOSS_PROVISION_LIQUIDATION_FULL_MTM_EUR,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_LIQUIDATION_BAL_MTM_OC), null)       as LOAN_LOSS_PROVISION_LIQUIDATION_BAL_MTM_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_LIQUIDATION_BAL_MTM_EUR), null)      as LOAN_LOSS_PROVISION_LIQUIDATION_BAL_MTM_EUR,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_LIQUIDATION_ELSE_MTM_OC), null)      as LOAN_LOSS_PROVISION_LIQUIDATION_ELSE_MTM_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_LIQUIDATION_ELSE_MTM_EUR), null)     as LOAN_LOSS_PROVISION_LIQUIDATION_ELSE_MTM_EUR,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_DEBIT_YTD_OC), null)                 as LOAN_LOSS_PROVISION_DEBIT_YTD_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_DEBIT_YTD_EUR), null)                as LOAN_LOSS_PROVISION_DEBIT_YTD_EUR,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_DEBIT_MTM_OC), null)                 as LOAN_LOSS_PROVISION_DEBIT_MTM_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_DEBIT_MTM_EUR), null)                as LOAN_LOSS_PROVISION_DEBIT_MTM_EUR,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_UNWINDING_YTD_OC), null)             as LOAN_LOSS_PROVISION_UNWINDING_YTD_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_UNWINDING_YTD_EUR), null)            as LOAN_LOSS_PROVISION_UNWINDING_YTD_EUR,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_UNWINDING_MTM_OC), null)             as LOAN_LOSS_PROVISION_UNWINDING_MTM_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_UNWINDING_MTM_EUR), null)            as LOAN_LOSS_PROVISION_UNWINDING_MTM_EUR,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_MANUAL_AMOUNT_OC), null)             as LOAN_LOSS_PROVISION_MANUAL_AMOUNT_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_MANUAL_AMOUNT_EUR), null)            as LOAN_LOSS_PROVISION_MANUAL_AMOUNT_EUR,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_WRITE_OFF_FULL_GUV_YTD_OC), null)    as LOAN_LOSS_PROVISION_WRITE_OFF_FULL_GUV_YTD_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_WRITE_OFF_FULL_GUV_YTD_EUR), null)    as LOAN_LOSS_PROVISION_WRITE_OFF_FULL_GUV_YTD_EUR,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_WRITE_OFF_FULL_GUV_MTM_OC), null)    as LOAN_LOSS_PROVISION_WRITE_OFF_FULL_GUV_MTM_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_WRITE_OFF_FULL_GUV_MTM_EUR), null)   as LOAN_LOSS_PROVISION_WRITE_OFF_FULL_GUV_MTM_EUR,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_WRITE_OFF_PART_GUV_YTD_OC), null)    as LOAN_LOSS_PROVISION_WRITE_OFF_PART_GUV_YTD_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_WRITE_OFF_PART_GUV_YTD_EUR), null)   as LOAN_LOSS_PROVISION_WRITE_OFF_PART_GUV_YTD_EUR,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_WRITE_OFF_PART_GUV_MTM_OC), null)    as LOAN_LOSS_PROVISION_WRITE_OFF_PART_GUV_MTM_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_WRITE_OFF_PART_GUV_MTM_EUR), null)   as LOAN_LOSS_PROVISION_WRITE_OFF_PART_GUV_MTM_EUR,
       nullif(DATE(LOAN_LOSS_PROVISION_WRITE_OFF_FULL_DATE), null)            as LOAN_LOSS_PROVISION_WRITE_OFF_FULL_DATE,
       nullif(DATE(LOAN_LOSS_PROVISION_WRITE_OFF_PART_DATE), null)            as LOAN_LOSS_PROVISION_WRITE_OFF_PART_DATE,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_POCI_NOMINAL_AMOUNT_ORIG_OC),
              null)                                                           as LOAN_LOSS_PROVISION_POCI_NOMINAL_AMOUNT_ORIG_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_POCI_NOMINAL_AMOUNT_ORIG_EUR),
              null)                                                           as LOAN_LOSS_PROVISION_POCI_NOMINAL_AMOUNT_ORIG_EUR,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_POCI_NOMINAL_AMOUNT_ADJ_OC), null)   as LOAN_LOSS_PROVISION_POCI_NOMINAL_AMOUNT_ADJ_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_POCI_NOMINAL_AMOUNT_ADJ_EUR),
              null)                                                           as LOAN_LOSS_PROVISION_POCI_NOMINAL_AMOUNT_ADJ_EUR,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_POCI_REGEN_OC), null)                as LOAN_LOSS_PROVISION_POCI_REGEN_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_POCI_REGEN_EUR), null)               as LOAN_LOSS_PROVISION_POCI_REGEN_EUR,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_POCI_LIQUIDATION_OC), null)          as LOAN_LOSS_PROVISION_POCI_LIQUIDATION_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_POCI_LIQUIDATION_EUR), null)         as LOAN_LOSS_PROVISION_POCI_LIQUIDATION_EUR,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_POCI_CONSUMPTION_OC), null)          as LOAN_LOSS_PROVISION_POCI_CONSUMPTION_OC,
       nullif(DOUBLE(LOAN_LOSS_PROVISION_POCI_CONSUMPTION_EUR), null)         as LOAN_LOSS_PROVISION_POCI_CONSUMPTION_EUR,
       nullif(DOUBLE(RISK_PROVISION_ZEB_EXCHANGE_RATE_EUR2OC), null)          as RISK_PROVISION_ZEB_EXCHANGE_RATE_EUR2OC,
       nullif(DOUBLE(RISK_PROVISION_ZEB_EXCHANGE_RATE_EUR2OC_LAST_YEAR),
              null)                                                           as RISK_PROVISION_ZEB_EXCHANGE_RATE_EUR2OC_LAST_YEAR,
       nullif(cast(ZEB_STAGE_ONBALANCE as VARCHAR(32)), null)                 as ZEB_STAGE_ONBALANCE,
       nullif(cast(ZEB_STAGE_ONBALANCE_LAST_YEAR as VARCHAR(32)), null)       as ZEB_STAGE_ONBALANCE_LAST_YEAR,
       nullif(DOUBLE(ZEB_EWB_EUR_ONBALANCE), null)                            as ZEB_EWB_EUR_ONBALANCE,
       nullif(DOUBLE(ZEB_EWB_EUR_ONBALANCE_LAST_YEAR), null)                  as ZEB_EWB_EUR_ONBALANCE_LAST_YEAR,
       nullif(DOUBLE(ZEB_EWB_OC_ONBALANCE), null)                             as ZEB_EWB_OC_ONBALANCE,
       nullif(DOUBLE(ZEB_EWB_OC_ONBALANCE_LAST_YEAR), null)                   as ZEB_EWB_OC_ONBALANCE_LAST_YEAR,
       nullif(cast(ZEB_STAGE_OFFBALANCE as VARCHAR(32)), null)                as ZEB_STAGE_OFFBALANCE,
       nullif(cast(ZEB_STAGE_OFFBALANCE_LAST_YEAR as VARCHAR(32)), null)      as ZEB_STAGE_OFFBALANCE_LAST_YEAR,
       nullif(DOUBLE(ZEB_EWB_EUR_OFFBALANCE), null)                           as ZEB_EWB_EUR_OFFBALANCE,
       nullif(DOUBLE(ZEB_EWB_EUR_OFFBALANCE_LAST_YEAR), null)                 as ZEB_EWB_EUR_OFFBALANCE_LAST_YEAR,
       nullif(DOUBLE(ZEB_EWB_OC_OFFBALANCE), null)                            as ZEB_EWB_OC_OFFBALANCE,
       nullif(DOUBLE(ZEB_EWB_OC_OFFBALANCE_LAST_YEAR), null)                  as ZEB_EWB_OC_OFFBALANCE_LAST_YEAR,
       nullif(DOUBLE(FAIR_VALUE_ADJUSTMENT_EUR), null)                        as FAIR_VALUE_ADJUSTMENT_EUR,
       nullif(DOUBLE(FAIR_VALUE_ADJUSTMENT_TC), null)                         as FAIR_VALUE_ADJUSTMENT_TC,
       nullif(DOUBLE(RECOURSE), null)                                         as RECOURSE,
       nullif(DOUBLE(RISK_PROVISION_EUR), null)                               as RISK_PROVISION_EUR,
       nullif(DOUBLE(RISK_PROVISION_TC), null)                                as RISK_PROVISION_TC,
       nullif(DOUBLE(FVC_RISIKOGEWICHT_IN_PROZENT), null)                     as FVC_RISIKOGEWICHT_IN_PROZENT,
       nullif(cast(AMORTIZATION_TYPE as VARCHAR(16)), null)                   as AMORTIZATION_TYPE,
       nullif(BIGINT(AMORTIZATION_FREQUENCY_DAYS), null)                      as AMORTIZATION_FREQUENCY_DAYS,
       nullif(DOUBLE(NEXT_AMORTIZATION_TO_BE_PAID), null)                     as NEXT_AMORTIZATION_TO_BE_PAID,
       nullif(cast(PAST_DUE_TOTAL_EUR as VARCHAR(1)), null)                   as PAST_DUE_TOTAL_EUR,
       nullif(BIGINT(DAYS_PAST_DUE_ZEB), null)                                as DAYS_PAST_DUE_ZEB,
       nullif(BIGINT(DAYS_PAST_DUE_BW), null)                                 as DAYS_PAST_DUE_BW,
       nullif(DOUBLE(PROBABILITY_OF_DEFAULT_RATE_BW), null)                   as PROBABILITY_OF_DEFAULT_RATE_BW,
       nullif(DOUBLE(PROBABILITY_OF_DEFAULT_RATE_ZEB), null)                  as PROBABILITY_OF_DEFAULT_RATE_ZEB,
       nullif(INTEGER(DEFAULT_BW), null)                                      as DEFAULT_BW,
       nullif(DOUBLE(CREDIT_CONVERSION_FACTOR_BW), null)                      as CREDIT_CONVERSION_FACTOR_BW,
       nullif(DOUBLE(AUSZAHLUNGSPLICHT_EUR), null)                            as AUSZAHLUNGSPLICHT_EUR,
       nullif(DOUBLE(FREIE_LINIE), null)                                      as FREIE_LINIE,
       nullif(DOUBLE(FREIE_LINIE_LAST_YEAR), null)                            as FREIE_LINIE_LAST_YEAR,
       nullif(cast(LOANSTATE_LIQ as VARCHAR(32)), null)                       as LOANSTATE_LIQ,
       nullif(cast(LOANSTATE_SPOT as VARCHAR(16)), null)                      as LOANSTATE_SPOT,
       nullif(cast(PRJ_IS_FINREP_FORBORNE as VARCHAR(1)), null)               as PRJ_IS_FINREP_FORBORNE,
       nullif(cast(IS_IN_GUARANTEE as BOOLEAN), null)                         as IS_IN_GUARANTEE,
       nullif(cast(IS_IN_BW_P62 as BOOLEAN), null)                            as IS_IN_BW_P62,
       nullif(INTEGER(IS_INACTIVE), null)                                     as IS_INACTIVE,
       nullif(cast(IS_FACILITY_FROM_SINGAPORE as BOOLEAN), null)              as IS_FACILITY_FROM_SINGAPORE,
       cast(IS_PWC_FOCUS as BOOLEAN)                                          as IS_PWC_FOCUS,
       cast(IS_AVAL as BOOLEAN)                                               as IS_AVAL,
       nullif(cast(PRODUCTTYPE_DETAIL as VARCHAR(512)), null)                 as PRODUCTTYPE_DETAIL,
       nullif(cast(PORTFOLIO_CLIENT_SIMPLIFIED as VARCHAR(512)), null)        as PORTFOLIO_CLIENT_SIMPLIFIED,
       CREATED_USER,
       CREATED_TIMESTAMP
from DATA;

-- CI START FOR ALL TAPES

-- CURRENT TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_FACILITY_CURRENT');
create table AMC.TABLE_FACILITY_CURRENT like CALC.VIEW_FACILITY distribute by hash (FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_CURRENT_FACILITY_ID on AMC.TABLE_FACILITY_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_FACILITY_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- ARCHIVE TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_FACILITY_ARCHIVE');
create table AMC.TABLE_FACILITY_ARCHIVE like AMC.TABLE_FACILITY_CURRENT distribute by hash (FACILITY_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_ARCHIVE_FACILITY_ID on AMC.TABLE_FACILITY_ARCHIVE (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_FACILITY_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCHES erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_FACILITY_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_FACILITY_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------


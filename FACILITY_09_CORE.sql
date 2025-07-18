-- View erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_FACILITY_CORE;
create or replace view CALC.VIEW_FACILITY_CORE as
    with PORTFOLIO as (
        select
               FACILITY_ID, SUBSTR(FACILITY_ID,11,10) as KONTONR,FACILITY_ID_LEADING, FACILITY_ID_NLB,FACILITY_ID_BLB,FACILITY_ID_CBB,DATA_CUT_OFF_DATE,CUT_OFF_DATE,BRANCH_FACILITY as BRANCH_SHORT,BRANCH_CLIENT,CLIENT_NO,IS_FACILITY_GUARANTEE_FLAGGED as GUARANTEE_FLAG,CURRENCY as ORIGINAL_CURRENCY,PORTFOLIO_EY_FACILITY as PORTFOLIO, PORTFOLIO_EY_CLIENT_ROOT as PORTFOLIO_ROOT, PORTFOLIO_GARANTIEN_CLIENT, BRANCH_SYSTEM, NULL as PRODUCT_TYPE, PORTFOLIO_IWHS_CLIENT_KUNDENBERATER
                ,case
                    when LKM.CLIENT_NO_CBB is not NULL and left(coalesce(FACILITY_ID_CBB,FACILITY_ID),4) = 'K028' then BRANCH_CLIENT  || '_'|| CLIENT_NO
                else NULL
        end                                                                                                                                        AS CLIENT_ID_NLB
        ,'CBB_' || LKM.CLIENT_NO_CBB                                                                                                               AS CLIENT_ID_LUX
        ,case
            when LKM.CLIENT_NO_CBB is not NULL and left(coalesce(FACILITY_ID_CBB,FACILITY_ID),4) = 'K028' then 'CBB_' || LKM.CLIENT_NO_CBB
            else BRANCH_CLIENT  || '_'|| CLIENT_NO
        end                                                                                                                                        AS CLIENT_ID
        from CALC.SWITCH_PORTFOLIO_CURRENT
        left join CALC.VIEW_CLIENT_CBB_TO_NLB                            AS LKM              on LKM.CLIENT_NO_NLB = CLIENT_NO              and BRANCH_CLIENT = 'NLB'
    )
    ,BW_KENNZAHLEN as(
        select FACILITY_ID, Bilanzteile_BW_EUR, Bilanzteile_BW_TC, HALTEKATEGORIE from CALC.SWITCH_BW_KENNZAHLEN_CURRENT
        )
    ,BW_DAT_CHECK as (
        select distinct CUT_OFF_DATE from  CALC.SWITCH_BW_KENNZAHLEN_CURRENT
    ),
    SPECIFICS_PRODUCTGROUPS as (
        select CUT_OFF_DATE, FACILITY_ID, SPECIFICS_PRODUCTGROUP from CALC.VIEW_FACILITY_SPECIFICS_PRODUCTGROUPS
    ),
    PROD_NUM_KR as (
        select distinct
            FACILITY_ID,
            first_value(PRODUCT_TYPE_DETAIL) over (partition by FACILITY_ID order by CUT_OFF_DATE DESC) as PRODUCT_TYPE_DETAIL
        from AMC.AMC_GG
    ),
    PROD_NUM_BW as (
        select
               FACILITY_ID as FACILITY_ID,
               PRODUCT_TYPE as PRODUCT_TYPE_DETAIL,
               PR_KEY_DATA_DATE
        from (
            select PRODUCT_TYPE,FACILITY_ID,CUT_OFF_DATE as PR_KEY_DATA_DATE,
                   row_number() over (partition by FACILITY_ID order by CUT_OFF_DATE desc) as NBR
            from CALC.SWITCH_BW_STAMMDATEN_CURRENT
            )
        where NBR = 1
     )
    ,LIQ_INACTIVE as (
        select * from (
                          select *,
                                 row_number()
                                         over (partition by CUTOFFDATE,OUTSTANDING_ID order by COALESCE(INACTIVE_DATE, '31.12.9999') desc) as NBR
                          from NLB.LIQ_DEAL_STATUS
                          --where OUTSTANDING_ID = 4250026250
                      )where NBR = 1
        ),
    mapping as (
    select distinct
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        PORTFOLIO.CUT_OFF_DATE                                                                                                                                                                  AS CUT_OFF_DATE
        , PORTFOLIO.DATA_CUT_OFF_DATE                                                                                                                                                           AS DATA_CUT_OFF_DATE
        ,case
            when substr(PORTFOLIO.FACILITY_ID,6,2)='69' then 'NL07'
            when substr(PORTFOLIO.FACILITY_ID,6,2)='70' then 'NL01'
            when substr(PORTFOLIO.FACILITY_ID,6,2)='71' then 'NL02'
            when substr(PORTFOLIO.FACILITY_ID,6,2)='73' then 'NL03'
            when left(coalesce(PORTFOLIO.FACILITY_ID_CBB,PORTFOLIO.FACILITY_ID),4) = 'K028' then 'CBB'
            else PORTFOLIO.BRANCH_SHORT
        end                                                                                                                                                                                     AS BRANCH,
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        PORTFOLIO.FACILITY_ID_LEADING                                                                                                                                                          AS FACILITY_ID_LEADING,
        PORTFOLIO.FACILITY_ID                                                                                                                                                                  AS FACILITY_ID,
        case
            when (PORTFOLIO.FACILITY_ID_CBB <> PORTFOLIO.FACILITY_ID_LEADING) then
                PORTFOLIO.FACILITY_ID_CBB
            when (PORTFOLIO.FACILITY_ID_BLB <> PORTFOLIO.FACILITY_ID_LEADING) then
                PORTFOLIO.FACILITY_ID_BLB
            when (PORTFOLIO.FACILITY_ID_NLB <> PORTFOLIO.FACILITY_ID_LEADING) then
                PORTFOLIO.FACILITY_ID_NLB
            else
                NULL
        end                                                                                                                                                                                     AS FACILITY_ID_ALTERNATIVE
        ,derivate.TRADE_ID  AS TRADE_ID
        ,derivate.INITIAL_TRADE_ID  AS INITIAL_TRADE_ID
        ,PORTFOLIO.CLIENT_ID                                                                                                                                                                    AS CLIENT_ID
        ,PORTFOLIO.CLIENT_ID_LUX                                                                                                                                                                AS CLIENT_ID_LUX
        ,PORTFOLIO.CLIENT_ID_NLB                                                                                                                                                                AS CLIENT_ID_NLB
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
       -- ,cast(NULL as VARCHAR(500))                                                                                                                                                             AS TRANSFER_PORTFOLIO
     --   ,cast(NULL as VARCHAR(500))                                                                                                                                                             AS AVIATION_PORTFOLIO
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                  ,case
            when substr(PORTFOLIO.FACILITY_ID,6,2) = '02'
                then 'Sachkonto'
            when PORTFOLIO.FACILITY_ID in ('0009-33-004230002539-21-0000000000', '0009-33-004230002627-21-0000000000', '0009-33-004230002628-21-0000000000')
                then 'Durchleitungskredite an Kreditinstitute'
            when substr(PORTFOLIO.FACILITY_ID,22,2) = '21'
             and substr(PORTFOLIO.FACILITY_ID,6,2) = '33'
             and coalesce(PROD_BW.PRODUCT_DESCRIPTION,PROD_KR.PRODUCT_DESCRIPTION) is NULL
                then 'Rahmenkreditzusage'
            when substr(PORTFOLIO.FACILITY_ID,22,2) = '10'
             and substr(PORTFOLIO.FACILITY_ID,6,2) = '11'
             and coalesce(PROD_BW.PRODUCT_DESCRIPTION, PROD_KR.PRODUCT_DESCRIPTION) is NULL
                then 'Rahmenkredit'
            when substr(PORTFOLIO.FACILITY_ID,22,2) = '20'
             and substr(PORTFOLIO.FACILITY_ID,6,2) = '11'
             and coalesce(PROD_BW.PRODUCT_DESCRIPTION, PROD_KR.PRODUCT_DESCRIPTION) is NULL
                then 'Rahmennettingvertrag'
            when CBB.PRODUCT_CATEGORY = 'Limit'
                then 'Limit'
            else coalesce(CBB.PRODUCT_TYPE,CBB.PRODUCT_CATEGORY,PROD_BW.PRODUCT_DESCRIPTION,PROD_KR.PRODUCT_DESCRIPTION)
        end                                                                                                                                                                                     AS PRODUCTTYPE
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,PROD_SPECIFICS.SPECIFICS_PRODUCTGROUP                                                                                                                                                  as PRODUCTGROUP_AVIATION
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,PORTFOLIO.GUARANTEE_FLAG
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,PORTFOLIO.PORTFOLIO_GARANTIEN_CLIENT                                                                                                                                                   as TRANSFER_PORTFOLIO
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,CASE
         WHEN SUBSTR(PORTFOLIO.FACILITY_ID,6,2)='15' and SUBSTR(PORTFOLIO.FACILITY_ID,22,2)='11' THEN derivate.ORIGINAL_CURRENCY
         WHEN SUBSTR(PORTFOLIO.FACILITY_ID,6,2)='15' and SUBSTR(PORTFOLIO.FACILITY_ID,22,2)='74' THEN derivate.ORIGINAL_CURRENCY
         WHEN SUBSTR(PORTFOLIO.FACILITY_ID,6,2)='15' and SUBSTR(PORTFOLIO.FACILITY_ID,22,2)='76' THEN derivate.ORIGINAL_CURRENCY
         else coalesce(CBB.ORIGINAL_CURRENCY, BW.ZM_AOCURR, PORTFOLIO.ORIGINAL_CURRENCY)
        END                                                                                                                                                                                     AS ORIGINAL_CURRENCY
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,FLOAT(RISIKO.RISIKOGEWICHT_IN_PROZENT_FVC)                                                                                                                                                                      AS FVC_RISIKOGEWICHT_IN_PROZENT
        ,FLOAT(RISIKO.LGD_IN_PRoZENT_FVC)                                                                                                                                                                                AS FVC_LGD_IN_PROZENT
        ,RISIKO.RATING_ID_FVC                                                                                                                                                                                     AS FVC_RATING_NOTE
        ,RISIKO.RATING_DATE                                                                                                                                                                                        AS FVC_RATING_DATE
        ,RISIKO.R_EXPOSURE_AT_DEFAULT_AMT / RISIKO.R_EXCHANGE_RATE  as ZEB_R_EXPOSURE_AT_DEFAULT_AMT_EUR
        ,RISIKO.R_EXPOSURE_AT_DEFAULT_AMT       as ZEB_R_EXPOSURE_AT_DEFAULT_AMT_TC
        ,RISIKO.E_LGD_COLL_RATE                 as ZEB_E_LGD_COLL_RATE
        ,RISIKO.R_LGD_NET_RATE                  as ZEB_R_LGD_NET_RATE
        ,RISIKO.R_LOSS_GIVEN_DEFAULT_RATE       as ZEB_R_LOSS_GIVEN_DEFAULT_RATE
        ,RISIKO.R_EAD_TOTAL_AMT / RISIKO.R_EXCHANGE_RATE            as ZEB_R_EAD_TOTAL_AMT_EUR
        ,RISIKO.R_EAD_TOTAL_AMT                 as ZEB_R_EAD_TOTAL_AMT_TC
        ,RISIKO.R_EXP_LOSS_AMT                  as ZEB_R_EXP_LOSS_AMT
        ,RISIKO.E_DAYS_PAST_DUE_NO              as ZEB_E_DAYS_PAST_DUE_NO
        ,RISIKO.R_RATING_ID                     as ZEB_R_RATING_ID
        ,RISIKO.R_INIT_RATING_MODULE            as ZEB_R_INIT_RATING_MODULE
        ,RISIKO.R_INIT_RATING_SECTOR            as ZEB_R_INIT_RATING_SECTOR
        ,RISIKO.R_RATING_SUB_MODULE             as ZEB_R_RATING_SUB_MODULE
        ,RISIKO.E_BOOK_VALUE_AC_AMT             as ZEB_E_BOOK_VALUE_AC_AMT
        ,RISIKO.E_CONTRACT_SIGNING_DATE         as ZEB_E_CONTRACT_SIGNING_DATE
        ,RISIKO.E_BALANCE_AMT                   as ZEB_E_BALANCE_AMT
        ,RISIKO.E_NOMINAL_VALUE_AMT             as ZEB_E_NOMINAL_VALUE_AMT
        ,RISIKO.PRJ_IS_FINREP_FORBORNE          as ZEB_PRJ_IS_FINREP_FORBORNE
        ,RISIKO.R_CREDIT_CONVERSION_FACTOR_RATE as ZEB_R_CREDIT_CONVERSION_FACTOR_RATE
        ,RISIKO.R_ONE_YEAR_PROB_OF_DEFAULT_RATE as ZEB_R_ONE_YEAR_PROB_OF_DEFAULT_RATE
        ,RISIKO.R_LIFETIME_PROB_DEF_RATE        as ZEB_R_LIFETIME_PROB_DEF_RATE,
        -- neue Spalten nach Issue #487
        RISIKO.R_EXP_LIFETIME_LOSS_AMT          as ZEB_R_EXP_LIFETIME_LOSS_AMT,
        RISIKO.E_END_OF_CONTRACT_DATE           as ZEB_E_END_OF_CONTRACT_DATE,
        RISIKO.R_IS_POCI                        as ZEB_R_IS_POCI,
        RISIKO.R_INIT_RATING_ID                                                                                                                                                                 as ZEB_R_INIT_RATING_ID,
        RISIKO.R_LOAN_LOSS_PROVISION_AMT                                                                                                                                                        as ZEB_R_LOAN_LOSS_PROVISION_AMT,
        RISIKO.R_RATING_MODULE                                                                                                                                                                  as ZEB_R_RATING_MODULE,
        RISIKO.R_STAGE_LLP_ID                                                                                                                                                                   as ZEB_R_STAGE_LLP_ID,
        RISIKO.R_STAGE_LLP_REASON_DESC                                                                                                                                                          as ZEB_R_STAGE_LLP_REASON_DESC,
        RISIKO.E_PROLONGATION_DATE                                                                                                                                                              as ZEB_E_PROLONGATION_DATE
        -- Ende neue Spalten nach Issue #487
        ,BW.MARKETS_PRODUKTE_AMOUNT_EUR
        ,BW.MARKETS_PRODUKTE_AMOUNT_TC
        ,coalesce(CBB.SYNDICATION_ROLE, SPOT.SYNDICATION_ROLE)                                                                                                                                  AS SYNDICATION_ROLE
        ,case when SUBSTR(PORTFOLIO.FACILITY_ID,6,2) in ('11','15') then 100.0 else coalesce(CBB.OWN_SYNDICATE_QUOTA, LIQ_PD.NETTO_ANTEIL, SPOT.OWNSYNDICATEQUOTA , 100.0 ) end                 AS OWN_SYNDICATE_QUOTA     --sysdizierungsquote für Derivate ist immer 100% Telefonat mit Herrn Hüsken 09.05.2019
        ,coalesce(CBB.ORIGINATION_DATE,SPOT.ORIGINATIONDATE,RAHMEN.ORIGINATION_DATE,DERIVATE.TRADE_DATE)                                                                                        AS ORIGINATION_DATE
        ,coalesce(CBB.CURRENT_CONTRACTUAL_MATURITY_DATE,SPOT.CURRENTCONTRACTUALMATURITYDATE,derivate.MATURITYDATE,RAHMEN.MATURITY_DATE)                                                         AS CURRENT_CONTRACTUAL_MATURITY_DATE
        ,replace(coalesce(CBB.AMORTIZATION_TYPE,atype.AMORTIZATION_TYPE),'at maturity','Bullet')                                                                                                AS AMORTIZATION_TYPE
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,coalesce(CBB.AMORTIZATION_FREQUENCY_DAYS,SPOT.AMORTIZATION_FREQUENCY,
            case
                when SPOT.MATURITYINFORMATION  between 0    and 30   and SUBSTR(PORTFOLIO.FACILITY_ID,6,2)='33' and SPOT.AMORTIZATION_TYPE = 2 /* das Entspricht : 'Installments'*/ then 30
                when SPOT.MATURITYINFORMATION  between 30   and 60   and SUBSTR(PORTFOLIO.FACILITY_ID,6,2)='33' and SPOT.AMORTIZATION_TYPE = 2 then 60
                when SPOT.MATURITYINFORMATION  between 60   and 90   and SUBSTR(PORTFOLIO.FACILITY_ID,6,2)='33' and SPOT.AMORTIZATION_TYPE = 2 then 90
                when SPOT.MATURITYINFORMATION  between 90   and 120  and SUBSTR(PORTFOLIO.FACILITY_ID,6,2)='33' and SPOT.AMORTIZATION_TYPE = 2 then 120
                when SPOT.MATURITYINFORMATION  between 120  and 180  and SUBSTR(PORTFOLIO.FACILITY_ID,6,2)='33' and SPOT.AMORTIZATION_TYPE = 2 then 180
                when SPOT.MATURITYINFORMATION  between 180  and 360  and SUBSTR(PORTFOLIO.FACILITY_ID,6,2)='33' and SPOT.AMORTIZATION_TYPE = 2 then 360
                else NULL
            end
        )                                                                                                                                                                                       AS AMORTIZATION_FREQUENCY_DAYS
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,coalesce(CBB.AMORTIZATION_AMOUNT_EUR,cf.ZAHLUNGSSTROM_BTR_next/cf_XR.KURS,cf.ZAHLUNGSSTROM_BTR_last/cf_XR.KURS,SPOT.AMORTIZATIONAMOUNT_EUR)                                                              AS NEXT_AMORTIZATION_TO_BE_PAID
        ,cf.ZAHLUNGSSTROM_BTR_last/cf_XR.KURS                                                                                                                                                                     AS AMOUNT_DUE_AT_MATURITY_EUR
        ,coalesce(CBB.INTEREST_RATE_TYPE,SPOT.INTERESTRATETYPE)                                                                                                                                                   AS INTEREST_RATE_TYPE
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,case
        when LIQ_PD.FULL_PAST_DUE_PRICING_OPTION like 'PAST DUE ___ FREE OF' and SPOT.INTERESTRATETYPE in ('FLOAT','FIXED') then 0
        else coalesce(CBB.INTEREST_RATE / 100,LIQ_PD.FULL_PAST_DUE_ALL_IN_RATE,SPOT.INTERESTRATE /100.)
          end                                                                                                                                                                                                     AS INTEREST_RATE
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,case when LIQ_PD.FULL_PAST_DUE_PRICING_OPTION like 'PAST DUE ___ FREE OF' and SPOT.INTERESTRATETYPE  = 'FIXED' then 0 else coalesce(CBB.FIXED_INTEREST_RATE / 100,SPOT.FIXEDINTERESTRATE /100.) end      AS FIXED_INTEREST_RATE
        ,coalesce(CBB.INTEREST_RATE_FREQUENCY_DAYS,SPOT.INTERESTFREQUENCY )                                                                                                                                       AS INTEREST_RATE_FREQUENCY
        ,coalesce(CBB.FIXED_INTEREST_RATE_END_DATE,SPOT.FIXEDINTERESTRATEENDDATE)                                                                                                                                 AS FIXED_INTEREST_RATE_END_DATE
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,case
            when coalesce(LIQ_PD.FULL_PAST_DUE_PRICING_OPTION,SPOT.INTERESTRATEINDEX) is NULL and SPOT.INTERESTRATETYPE = 'FLOAT' and substr(PORTFOLIO.FACILITY_ID,6,8) = '33-00425' and LIQ_PD.CURRENCY = 'USD' then 'LIBOR'
            when coalesce(LIQ_PD.FULL_PAST_DUE_PRICING_OPTION,SPOT.INTERESTRATEINDEX) is NULL and SPOT.INTERESTRATETYPE = 'FLOAT' and substr(PORTFOLIO.FACILITY_ID,6,8) = '33-00425' and LIQ_PD.CURRENCY = 'EUR' then 'EURIBOR'
            else coalesce(CBB.INTEREST_RATE_INDEX,LIQ_PD.FULL_PAST_DUE_PRICING_OPTION,replace(SPOT.INTERESTRATEINDEX,'-',''))
                                                                                                                                                            end                                 AS INTEREST_RATE_INDEX
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,case when LIQ_PD.FULL_PAST_DUE_PRICING_OPTION like 'PAST DUE ___ FREE OF' then 0 else coalesce(CBB.INTEREST_RATE_MARGIN / 100,SPOT.INTERESTRATEMARGIN /100.)    end                                      AS INTEREST_RATE_MARGIN
        ,case when LIQ_PD.FULL_PAST_DUE_PRICING_OPTION like 'PAST DUE ___ FREE OF' then NULL else coalesce(CBB.NEXT_INTEREST_PAYMENT_DATE,SPOT.NEXTINTERESTPAYMENTDATE)  end                                      AS NEXT_INTEREST_PAYMENT_DATE
        ,coalesce(CBB.COMMITMENT_FEE_RATE, SPOT.COMMITMENTFEERATE)                                                                                                                                               AS COMMITMENT_FEE_RATE
        ,coalesce(CBB.COMMITMENT_FEE_FREQUENCY,SPOT.COMMITMENTFEEFREQUENCY)                                                                                                                                   AS COMMITMENT_FEE_FREQUENCY
        ,coalesce(CBB.COMMITMENT_FEE_NEXT_PAYMENT_DATE,SPOT.COMMITMENTFEENEXTPAYMENTDATE)                                                                                                                         AS COMMITMENT_FEE_NEXT_PAYMENT_DATE
        ,coalesce(CBB.COMMITMENT_FEE_RATE_END_DATE,SPOT.COMMITMENTFEERATEENDDATE)                                                                                                                            AS COMMITMENT_FEE_RATE_END_DATE
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,case when ELIGIBILITY_FOR_COVERSTOCK is not NULL then 'in Deckung'
            when LIQ_G.ASSIGNMENT_PLACEMENT in ('F1','F2','F3','F4','H1','H2','H3','H4','K1','K2','K3','K4','S1','S2','S3','S4','O1','O2','O3','O4','P1','R1')  then 'in Deckung'
            when LIQ_G.ASSIGNMENT_PLACEMENT in ('F0','H0', 'K0','S0', 'P0', 'R0', 'O0')  then 'für Deckung vorgesehen'
            --when LIQg.ID_OF_SECURITIZATION_1 is not null then 'in Deckung'
            else NULL end                                                                                                                                                                                         AS ELIGIBILITY_FOR_COVERSTOCK
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,coalesce(CBB.COVERSTOCK_NAME,
                case when left(LIQ_G.ASSIGNMENT_PLACEMENT,1) ='F' then 'Flugzeugpfandbrief'
                     when left(LIQ_G.ASSIGNMENT_PLACEMENT,1) ='H' then 'Hypothekenpfandbrief'
                     when left(LIQ_G.ASSIGNMENT_PLACEMENT,1) ='S' then 'Schiffspfandbrief'
                     when left(LIQ_G.ASSIGNMENT_PLACEMENT,1) ='K' then 'Öffentlicher Pfandbrief'
                     when left(LIQ_G.ASSIGNMENT_PLACEMENT,1) ='O' then 'ÖPG_Öffentlicher Pfandbrief'
                     else NULL
                end )                                                                                                                                                                           AS COVERSTOCK_NAME
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        --,coalesce(cbb.ELIGIBLE_COVER_AMOUNT_EUR,qm.ELIGIBLECOVERAMOUNT_EUR           )                                                                                                                          AS ELIGIBLE_COVER_AMOUNT_EUR
        ,coalesce(CBB.EFFECTIVE_COVERAMOUNT_EUR, LIQ_G.TARGET_COVERAGE       )                                                                                                                  AS EFFECTIVE_COVER_AMOUNT_EUR
        ,BW_ALT.HALTEKATEGORIE                                                                                                                                                                  as HALTEKATEGORIE
        ,case when substr(PORTFOLIO.FACILITY_ID, 6,2)='15' then BW.BILANZWERT_IFRS9_EUR else NULL end                                                                                           AS DERIVATIVES_FAIR_VALUE_DIRTY_EUR
        ,case when substr(PORTFOLIO.FACILITY_ID, 6,2)='15' then BW.BILANZWERT_IFRS9_TC else NULL end                                                                                            AS DERIVATIVES_FAIR_VALUE_DIRTY_TC
        ,DERIVATE.FAIR_VALUE_EUR as DERIVATE_FAIR_VALUE_EUR
        ,DERIVATE.CVA_EUR
        ,DERIVATE.DVA_EUR
        ,DERIVATE.FBA_EUR
        ,DERIVATE.FCA_EUR
        ,DERIVATE.DERIVATE_PO_EUR
        ,DERIVATE.DERIVATE_PO_TC
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,coalesce(CBB.BRUTTO_BUCHWERT_LC
                ,case
                    when substr(PORTFOLIO.FACILITY_ID, 6,2)='15' then BW.BILANZWERT_IFRS9_EUR
                    else BW.BILANZWERT_BRUTTO_EUR
                end )                                                                                                                                                                           AS BILANZWERT_BRUTTO_EUR
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,case
            WHEN SUBSTR(PORTFOLIO.FACILITY_ID,6,2)='15' and SUBSTR(PORTFOLIO.FACILITY_ID,22,2) in ('11','74','76') THEN NULL
            else coalesce(CBB.BRUTTO_BUCHWERT_TC, BW.BILANZWERT_BRUTTO_TC )
        end                                                                                                                                                                                     AS BILANZWERT_BRUTTO_TC
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,coalesce(CBB.ACCRUED_INTEREST_EUR,BW.ACCRUED_INTEREST_EUR, AI_GEVO.ACCRUEDINTEREST_GEVO / cf_XR_STAMM.KURS)                                                                                              AS ACCRUED_INTEREST_EUR
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,coalesce(CBB.ACCRUED_INTEREST_TC,BW.ACCRUED_INTEREST_TC, AI_GEVO.ACCRUEDINTEREST_GEVO)                                                                                                                   AS ACCRUED_INTEREST_TC
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,coalesce(
                 CBB.NETTO_BUCHWERT_LC
                ,case
                    when substr(PORTFOLIO.FACILITY_ID, 6,2)='15' then BW.BILANZWERT_IFRS9_EUR
                    else BW.Bilanzwert_IFRS9_EUR
                end )
                                                                                                                                                                                                AS Bilanzwert_IFRS9_EUR
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,case
            WHEN SUBSTR(PORTFOLIO.FACILITY_ID,6,2)='15' and SUBSTR(PORTFOLIO.FACILITY_ID,22,2) in ('11','74','76') THEN NULL
            ELSE coalesce(CBB.NETTO_BUCHWERT_TC, BW.Bilanzwert_IFRS9_TC )
        end                                                                                                                                                                                     AS Bilanzwert_IFRS9_TC
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,coalesce(CBB.RIVO_LC,BW.RISK_PROVISION_EUR)                                                                                                                                                            AS RISK_PROVISION_EUR
        ,coalesce(CBB.RIVO_TC,BW.RISK_PROVISION_TC)                                                                                                                                                             AS RISK_PROVISION_TC
        ,coalesce(LIQ_PD.PAST_DUE_AMORTIZATION_ALL_IN_RATE, AVQ_PD.PAST_DUE_AMORTIZATION_ALL_IN_RATE)                                                                                                           AS PD_ALL_IN_RATE_TILG
        ,LIQ_PD.GLOBAL_CURRENT                                                                                                                                                                                  AS LIQ_GLOBAL_CURRENT_AMOUNT_ORIGINAL_CURRENCY
        ,LIQ_PD.NETTO_ANTEIL                                                                                                                                                                                    AS LIQ_HOST_BANK_SHARE
        ,coalesce(LIQ_PD.PAST_DUE_INTEREST_AMOUNT, AVQ_PD.PAST_DUE_INTEREST_AMOUNT_TC)                                                                                                                          AS LOAN_PAST_DUE_ZINS_ORIGINAL_CURRENCY
        ,coalesce(LIQ_PD.PAST_DUE_INTEREST_SINCE, AVQ_PD.PAST_DUE_INTEREST_SINCE)                                                                                                                               AS LOAN_PAST_DUE_ZINS_SINCE
        ,coalesce(LIQ_PD.PAST_DUE_AMORTIZATION_AMOUNT, AVQ_PD.PAST_DUE_AMORTIZATION_AMOUNT_TC)                                                                                                                  AS LOAN_PAST_DUE_TILG_ORIGINAL_CURRENCY
        ,coalesce(LIQ_PD.PAST_DUE_AMORTIZATION_SINCE, AVQ_PD.PAST_DUE_AMORTIZATION_SINCE)                                                                                                                       AS LOAN_PAST_DUE_TILG_SINCE
        ,BW.IFRS_STAGE                                                                                                                                                                                          AS IFRS_STAGE
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,case
            when max(LIQ.ACTIVATION_STATUS) over (partition by LIQ.OUTSTANDING_ID) = 'Inactive' then coalesce(SPOT.LOANSTATE,'I_VOR_GESC')
            when PORTFOLIO.DATA_CUT_OFF_DATE = PORTFOLIO.CUT_OFF_DATE and substr(PORTFOLIO.FACILITY_ID,22,2) = '10' and SUBSTR(PORTFOLIO.FACILITY_ID,6,2) = '11' then 'Active' --aus Anforderung von EY zur korrekten erkennung der Status, siehe auch #437
            when PORTFOLIO.DATA_CUT_OFF_DATE <> PORTFOLIO.CUT_OFF_DATE and substr(PORTFOLIO.FACILITY_ID,22,2) = '10' and SUBSTR(PORTFOLIO.FACILITY_ID,6,2) = '11' then 'I_VOR_GESC' --aus Anforderung von EY zur korrekten erkennung der Status, siehe auch #437
            --when BAS.DATA_CUT_OFF_DATE = BAS.CUT_OFF_DATE and SUBSTR(BAS.FACILITY_ID,6,2) = '15' then 'Active' --aus Anforderung von EY zur korrekten erkennung der Status, siehe auch #437
            when SUBSTR(PORTFOLIO.FACILITY_ID,6,2) = '15' then derivate.LOANSTATE
            when PORTFOLIO.DATA_CUT_OFF_DATE <> PORTFOLIO.CUT_OFF_DATE and SUBSTR(PORTFOLIO.FACILITY_ID,6,2) = '15' then 'I_VOR_GESC' --aus Anforderung von EY zur korrekten erkennung der Status, siehe auch #437
            else SPOT.LOANSTATE
        end                                                                                                                                                                                     AS LOANSTATE_SPOT
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,CASE when (LIQ_PD.GLOBAL_CURRENT = 0 and LIQ_PD.PAST_DUE_AMORTIZATION_AMOUNT <> 0 ) or LIQ_PD.GLOBAL_CURRENT=LIQ_PD.PAST_DUE_AMORTIZATION_AMOUNT then '1' else '0' end                                 AS TOTAL_PAST_DUE
        ,max(LIQ.ACTIVATION_STATUS) over (partition by LIQ.OUTSTANDING_ID)                                                                                                                                      AS LOANSTATE_LIQ
        ,FLOAT(coalesce(-CBB.PRINCIPAL_OUTSTANDING_EUR,SPOT.PRINCIPALOUTSTANDING_EUR))                                                                                                                                 AS PRICIPAL_OST_EUR_SPOT
        ,FLOAT(coalesce(-CBB.PRINCIPAL_OST_TC,SPOT.PRINCIPALOUTSTANDING_TC))                                                                                                                                           AS PRICIPAL_OST_TC_SPOT
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,FLOAT(coalesce(CBB.PRINCIPAL_OST_TC/coalesce(cf_XR_STAMM.KURS,1)
                    ,BW.PRINCIPAL_OUTSTANDING_TC/Coalesce(cf_XR_STAMM.KURS,1)
                    ,-1*SPOT.PRINCIPALOUTSTANDING_TC/coalesce(cf_XR_STAMM.Kurs,1)*coalesce(SPOT.OWNSYNDICATEQUOTA,100)/100))                                                                                     AS PRICIPAL_OST_EUR_AUS_TC_MIT_KURS_ERRECHNET
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,case
            when BW_COD.CUT_OFF_DATE is null then NULL
            else FLOAT(coalesce(CBB.PRINCIPAL_OUTSTANDING_EUR,coalesce(BW.PRINCIPAL_OUTSTANDING_EUR,0),-1*SPOT.PRINCIPALOUTSTANDING_EUR*coalesce(SPOT.OWNSYNDICATEQUOTA,100)/100))
        end                                                                                                                                                                                                     AS PRICIPAL_OST_EUR_BW
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,case
            when BW_COD.CUT_OFF_DATE is null then NULL
            else FLOAT(coalesce(CBB.PRINCIPAL_OST_TC,coalesce(FLOAT(BW.PRINCIPAL_OUTSTANDING_TC),0),-1*SPOT.PRINCIPALOUTSTANDING_TC*coalesce(SPOT.OWNSYNDICATEQUOTA,100)/100))
        end                                                                                                                                                                                                     AS PRICIPAL_OST_TC_BW
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,coalesce(case when right(CBB.FACILITY_ID,4) = '1020' then null else  CBB.OFFBALANCESHEET_EXPOSURE_EUR end ,BW.OFFBALANCE_EUR)                                                                         as OFFBALANCE_EUR
        ,coalesce(case when right(CBB.FACILITY_ID,4) = '1020' then null else CBB.OFFBALANCESHEET_EXPOSURE_TC end ,BW.OFFBALANCE_TC)                                                                            as OFFBALANCE_TC
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,FLOAT(coalesce(nullif(
                        coalesce(CBB.PRINCIPAL_OUTSTANDING_EUR,0)
                        +coalesce(CBB.ACCRUED_INTEREST_EUR,0)
                        +COALESCE(CBB.INTEREST_IN_ARREARS_EUR,0)
                        +COALESCE(CBB.AMORTIZATION_IN_ARREARS_EUR,0)
                        +COALESCE(CBB.UNPAID_AMORTIZATION_EUR,0)
                        +COALESCE(CBB.UNPAID_FEES_EUR,0)
                        +COALESCE(CBB.UNPAID_INTEREST_EUR,0)
                        +COALESCE(CBB.UNPAID_OTHER_COSTS_EUR,0)
                    ,0)
                ,BW.HGB_EUR))                                                                                                                                                                                    AS HGB_EUR
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,FLOAT(coalesce(nullif(
                        coalesce(CBB.PRINCIPAL_OST_TC,0)
                        +coalesce(CBB.ACCRUED_INTEREST_TC,0)
                        +COALESCE(CBB.AMORTIZATION_IN_ARREAS_TC,0)
                        +COALESCE(CBB.INTERETST_IN_ARREAS_TC,0)
                    ,0)
                ,BW.HGB_TC))                                                                                                                                                                                     AS HGB_TC
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,FLOAT(bw.FVA_EUR)                                                                                                                                                                                             AS FVA_EUR
        --lux konten OHNE FVA adj, da immer zu AC bewertet
        ,FLOAT(bw.FVA_TC)                                                                                                                                                                                              AS FVA_TC
        --lux konten OHNE FVA adj, da immer zu AC bewertet
                  --Im folgenden sin die Amortization in Arreas Werte aus dem SPOT und BW getrennt, da die SPOT Vor-Syndizierung sind und die Werte aus dem BW nach Syndizierung
        ,coalesce((case when coalesce(cbb.AMORTIZATION_IN_ARREARS_EUR,0)+coalesce(cbb.UNPAID_AMORTIZATION_EUR,0)=0 then null
                        else coalesce(cbb.AMORTIZATION_IN_ARREARS_EUR,0)+coalesce(cbb.UNPAID_AMORTIZATION_EUR,0) end),
                    (case when coalesce(spot.AMORTIZATIONINARREARS_EUR,0)+coalesce(spot.UNPAIDAMORTIZATION_EUR,0)=0 then null
                          else coalesce(spot.AMORTIZATIONINARREARS_EUR,0)+coalesce(spot.UNPAIDAMORTIZATION_EUR,0) end), AVQ_PD.PAST_DUE_AMORTIZATION_AMOUNT_EUR)                                            AS AMORTIZATION_IN_ARREARS_EUR_SPOT
        ,coalesce((case when coalesce(CBB.AMORTIZATION_IN_ARREAS_TC,0)+coalesce(CBB.UNPAID_AMORTIZATION_EUR*coalesce(cf_XR_STAMM.KURS,1),0)=0 then null
                        else coalesce(CBB.AMORTIZATION_IN_ARREAS_TC,0)+coalesce(CBB.UNPAID_AMORTIZATION_EUR*coalesce(cf_XR_STAMM.KURS,1),0) end),
                    (case when coalesce(spot.AMORTIZATIONINARREARS_TC,0)+coalesce(spot.UNPAIDAMORTIZATION_TC,0)=0 then null
                    else coalesce(spot.AMORTIZATIONINARREARS_TC,0)+coalesce(spot.UNPAIDAMORTIZATION_TC,0) end), AVQ_PD.PAST_DUE_AMORTIZATION_AMOUNT_TC)                                                     AS AMORTIZATION_IN_ARREARS_TC_SPOT
        ,bw.AMORTIZATION_IN_ARREARS_EUR                                                                                                                                                                     AS AMORTIZATION_IN_ARREARS_EUR_BW
        ,bw.AMORTIZATION_IN_ARREARS_TC                                                                                                                                                                      AS AMORTIZATION_IN_ARREARS_TC_BW
        ,coalesce((case when coalesce(cbb.INTEREST_IN_ARREARS_EUR,0)+coalesce(cbb.UNPAID_INTEREST_EUR,0)=0 then null
                        else coalesce(cbb.INTEREST_IN_ARREARS_EUR,0)+coalesce(cbb.UNPAID_INTEREST_EUR,0) end),
                    (case when coalesce(spot.INTEREST_INNARREARS_EUR,0)+coalesce(spot.UNPAIDINTEREST_EUR,0)=0 then null
                          else coalesce(spot.INTEREST_INNARREARS_EUR,0)+coalesce(spot.UNPAIDINTEREST_EUR,0) end), AVQ_PD.PAST_DUE_INTEREST_AMOUNT_EUR)                                                      AS INTEREST_IN_ARREARS_EUR_SPOT
        ,coalesce((case when coalesce(CBB.INTERETST_IN_ARREAS_TC,0)+coalesce(CBB.UNPAID_INTEREST_EUR*coalesce(cf_XR_STAMM.KURS,1),0)=0 then null
                        else coalesce(CBB.INTERETST_IN_ARREAS_TC,0)+coalesce(CBB.UNPAID_INTEREST_EUR*coalesce(cf_XR_STAMM.KURS,1),0) end),
                    (case when coalesce(spot.INTEREST_INNARREARS_TC,0)+coalesce(spot.UNPAIDINTEREST_TC,0)=0 then null
                          else coalesce(spot.INTEREST_INNARREARS_TC,0)+coalesce(spot.UNPAIDINTEREST_TC,0) end), AVQ_PD.PAST_DUE_INTEREST_AMOUNT_TC)                                                         AS INTEREST_IN_ARREARS_TC_SPOT
        ,bw.INTEREST_IN_ARREARS_EUR                                                                                                                                                                         AS INTEREST_IN_ARREARS_EUR_BW
        ,bw.INTEREST_IN_ARREARS_TC                                                                                                                                                                          AS INTEREST_IN_ARREARS_TC_BW
        ,coalesce(cbb.UNPAID_FEES_EUR,
                 (case when coalesce(spot.UNPAIDFEES_EUR,0)+coalesce(spot.FEESINARREARS_EUR,0)=0 then null
                       else coalesce(spot.UNPAIDFEES_EUR,0)+coalesce(spot.FEESINARREARS_EUR,0) end), AVQ_PD.PAST_DUE_FEES_AMOUNT_TC)                                                                        AS FEES_IN_ARREARS_EUR_SPOT
        ,coalesce(CBB.UNPAID_FEES_EUR*coalesce(cf_XR_STAMM.KURS,1),
                 (case when coalesce(spot.UNPAIDFEES_EUR*coalesce(cf_XR_STAMM.KURS,1),0)+coalesce(spot.FEESINARREARS_TC,0)=0 then null
                       else coalesce(spot.UNPAIDFEES_EUR*coalesce(cf_XR_STAMM.KURS,1),0)+coalesce(spot.FEESINARREARS_TC,0) end), AVQ_PD.PAST_DUE_FEES_AMOUNT_EUR)                                           AS FEES_IN_ARREARS_TC_SPOT
        ,SPOT.AUSZAHLUNGSPLICHT_EUR
        ,SPOT.ZUSAGE_UNWIDERR_JN                                                                                                                                                                                as ZUSAGE_AKTIV
        ,SPOT.FACILITY_SAP_ID                                                                                                                                                                                   as PARENT_FACILITY_ID
                  --zugehöriges Parent-Element (bezogen auf die Auszahlungspflicht), LIQ-Sprech: Facility-ID zum Outstanding
        ,BW.RIVO_STAGE                                                                                                                                                                                          as RIVO_STAGE
        ,BW.RIVO_STAGE_1_EUR                                                                                                                                                                                    as RIVO_STAGE_1_EUR
        ,BW.RIVO_STAGE_1_TC                                                                                                                                                                                     as RIVO_STAGE_1_TC
        ,BW.RIVO_STAGE_2_EUR                                                                                                                                                                                    as RIVO_STAGE_2_EUR
        ,BW.RIVO_STAGE_2_TC                                                                                                                                                                                     as RIVO_STAGE_2_TC
        ,BW.RIVO_STAGE_3_EUR                                                                                                                                                                                    as RIVO_STAGE_3_EUR
        ,BW.RIVO_STAGE_3_TC                                                                                                                                                                                     as RIVO_STAGE_3_TC
        ,BW.RIVO_STAGE_POCI_EUR                                                                                                                                                                                 as RIVO_STAGE_POCI_EUR
        ,BW.RIVO_STAGE_POCI_TC                                                                                                                                                                                  as RIVO_STAGE_POCI_TC
        ,BW_ALT.BILANZTEILE_BW_EUR                                                                                                                                                                              as AKTUELLSTE_Bilanzteile_BW_EUR
        ,BW_ALT.BILANZTEILE_BW_TC                                                                                                                                                                               as AKTUELLSTE_Bilanzteile_BW_TC
        /* DER CODE FÜR DIE SIMULIERTEN BILANZWERTE IST FEHLERHAFT UND NICHT FERTIG ENTWICKELT. AUSSCHLUSS WEGEN UMSTELLUNG AUF MONATLICHE BW-ZULIEFERUNGEN, siehe #358
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,coalesce(BW_ALT.BILANZTEILE_BW_EUR,0)
             + coalesce(SPOT.UNPAIDAMORTIZATION_EUR,0)
             + coalesce(SPOT.AMORTIZATIONINARREARS_EUR,0)
             + coalesce(SPOT.UNPAIDINTEREST_EUR,0)
             + coalesce(SPOT.INTEREST_INNARREARS_EUR,0)
             + coalesce(SPOT.FEESINARREARS_EUR,0)
             - coalesce(-CBB.PRINCIPAL_OUTSTANDING_EUR,SPOT.PRINCIPALOUTSTANDING_EUR*(coalesce(SPOT.OWNSYNDICATEQUOTA,100)/100),0)
             + coalesce(CBB.ACCRUED_INTEREST_EUR,AI_GEVO.ACCRUEDINTEREST_GEVO / coalesce(cf_XR_STAMM.Kurs,1),0)                                                                                                as SIMULIERTER_BILANZWERT_IFRS_EUR
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,coalesce(BW_ALT.BILANZTEILE_BW_TC,0)
             + coalesce(SPOT.UNPAIDAMORTIZATION_TC,0)
             + coalesce(SPOT.AMORTIZATIONINARREARS_TC,0)
             + coalesce(SPOT.UNPAIDINTEREST_TC,0)
             + coalesce(SPOT.INTEREST_INNARREARS_TC,0)
             + coalesce(SPOT.FEESINARREARS_TC,0)
             - coalesce(-CBB.PRINCIPAL_OST_TC,SPOT.PRINCIPALOUTSTANDING_TC*(coalesce(SPOT.OWNSYNDICATEQUOTA,100)/100),0)
             + coalesce(CBB.ACCRUED_INTEREST_TC,AI_GEVO.ACCRUEDINTEREST_GEVO,0)                                                                                                                                 as SIMULIERTER_BILANZWERT_IFRS_TC
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        */
        ,CASE
        WHEN BW.FACILITY_ID is null THEN 1
        ELSE 0
        END                                                                                                                                                                                     AS NICHT_IM_BW_REWE
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,CASE
         WHEN SUBSTR(PORTFOLIO.FACILITY_ID,6,2)='33' and SUBSTR(PORTFOLIO.FACILITY_ID,22,1)='3' and LIQ.OUTSTANDING_ID is null THEN 2
         WHEN LIQ.INACTIVE_DATE<= PORTFOLIO.CUT_OFF_DATE THEN 1
         WHEN LEFT(SPOT.FACILITY_ID,7)='0004-31%' THEN 1
         WHEN SUBSTR(PORTFOLIO.FACILITY_ID,6,2)<>'33' then NULL
         ELSE 0
        END                                                                                                                                                                                     AS inaktiv,
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        PORTFOLIO.FACILITY_ID_CBB                                                                                                                                                               AS FACILITY_ID_CBB
        ,CBB.FACILITY_ID                                                                                                                                                                        AS CBB_GESCHAEFTS_ID
        ,RAHMEN_2.FACILITY_ID_RAHMEN                                                                                                                                                            AS ZUGEHOERIGER_RAHMEN
        ,coalesce(bigint(BW.ZM_ANVETA), RISIKO.E_DAYS_PAST_DUE_NO )                                                                                                                             AS DAYS_PAST_DUE
        --,REST.DATE_OF_MODIFICATION                                                                                                                                                                             AS RESTRUCTURING
        , PORTFOLIO.PORTFOLIO                                                                                                                                                                   AS Portfolio
        , PORTFOLIO.PORTFOLIO_IWHS_CLIENT_KUNDENBERATER                                                                                                                                         as KUNDENBETREUER_OE_BEZEICHNUNG
        ,Current_USER                                                                                                                                                                           as TAPE_CREATED_USER       -- Letzter Nutzer, der dieses Tape gebaut hat.
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,'CF: ' || cf.CREATED_USER  ||
            '; BW: ' || BW.CREATED_USER ||
            '; DERIVATE: ' ||  derivate.CREATED_USER ||
            '; LUX: ' ||  CBB.CREATED_USER ||
            '; STAMMDATEN: ' || SPOT.CREATED_USER  || ', ' || Rahmen.CREATED_USER || ', ' || Rahmen_2.CREATED_USER || ', ' || LIQ_PD.CREATED_USER                                               as PRE_TAPE_CREATED_USER   -- Letzte Nutzer, welche die unterliegenden Tabellen gebaut haben.
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        ,Current_TIMESTAMP                                                                                                                                                                      as TAPE_CREATED_TIMESTAMP  -- Neuester Zeitstempel, wann dieses Tape zuletzt gebaut wurde.
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    from PORTFOLIO                                                  AS PORTFOLIO
    left join CALC.SWITCH_FACILITY_PRE_SPOT_STAMMDATEN_AOER_CURRENT AS SPOT             on PORTFOLIO.CUT_OFF_DATE=SPOT.CUT_OFF_DATE           and PORTFOLIO.FACILITY_ID=SPOT.FACILITY_ID                                                                         -- Aus Schritt 04
    left join CALC.SWITCH_BW_KENNZAHLEN_CURRENT                     AS BW               on PORTFOLIO.CUT_OFF_DATE=BW.CUT_OFF_DATE             and PORTFOLIO.FACILITY_ID=BW.FACILITY_ID
    left join CALC.SWITCH_ACCRUED_INTEREST_GEVO_CURRENT             as AI_GEVO          on PORTFOLIO.CUT_OFF_DATE=AI_GEVO.CUT_OFF_DATE        and PORTFOLIO.FACILITY_ID=AI_GEVO.FACILITY_ID
    left join CALC.SWITCH_NEXT_AMORTIZATION_AMOUNTS_CURRENT         AS cf               on PORTFOLIO.CUT_OFF_DATE=cf.CUT_OFF_DATE             and PORTFOLIO.FACILITY_ID=cf.FACILITYID                                                                            -- Aus Schritt 01
    left join BW_KENNZAHLEN                                         AS BW_ALT           on BW_ALT.FACILITY_ID= PORTFOLIO.FACILITY_ID   --Aufgrund der Konstruktion kein join über CutOffDate nötig
    left join IMAP.CURRENCY_MAP                                     AS cf_XR            on PORTFOLIO.CUT_OFF_DATE=cf_XR.CUT_OFF_DATE          and cf.ZAHLUNGSSTROM_WHRG_last=cf_XR.ZIEL_WHRG
    left join CALC.SWITCH_FACILITY_PRE_SPOT_STAMMDATEN_CBB_CURRENT  as CBB              on PORTFOLIO.CUT_OFF_DATE=CBB.CUT_OFF_DATE            and PORTFOLIO.FACILITY_ID_CBB=CBB.FACILITY_ID_CBB                                                                  -- Aus Schritt 01
    left join IMAP.CURRENCY_MAP                                     AS cf_XR_STAMM      on PORTFOLIO.CUT_OFF_DATE=cf_XR_STAMM.CUT_OFF_DATE    and coalesce(CBB.ORIGINAL_CURRENCY, BW.ZM_AOCURR,
                                                                                                                                                           PORTFOLIO.ORIGINAL_CURRENCY)= cf_XR_STAMM.ZIEL_WHRG
    left join CALC.SWITCH_PRE_FACILITY_DERIVATE_CURRENT             AS derivate         on PORTFOLIO.CUT_OFF_DATE=derivate.CUT_OFF_DATE       and PORTFOLIO.FACILITY_ID=derivate.FACILITYID_SAP_ID                                                               -- Aus Schritt 02
    left join CALC.SWITCH_PRE_FACILITY_ALIS_RAHMEN_CURRENT          AS Rahmen           on PORTFOLIO.CUT_OFF_DATE=RAHMEN.CUTOFFDATE           and PORTFOLIO.FACILITY_ID=Rahmen.FACILITY_ID                                                                       -- Aus Schritt 04
    left join CALC.SWITCH_PRE_FACILITY_ALIS_RAHMEN_2_CURRENT        AS Rahmen_2         on PORTFOLIO.CUT_OFF_DATE=RAHMEN_2.CUTOFFDATE         and PORTFOLIO.FACILITY_ID=Rahmen_2.FACILITY_ID                                                                     -- Aus Schritt 04
    left join CALC.VIEW_AVALOQ_PAST_DUE                             AS AVQ_PD           on PORTFOLIO.CUT_OFF_DATE=AVQ_PD.CUT_OFF_DATE         and PORTFOLIO.FACILITY_ID=AVQ_PD.FACILITY_ID
    left join CALC.SWITCH_LOANIQ_PAST_DUE_INFOS_CURRENT             AS LIQ_PD           on PORTFOLIO.CUT_OFF_DATE=LIQ_PD.CUTOFFDATE           and PORTFOLIO.FACILITY_ID=LIQ_PD.FACILITY_ID                                                                       -- Aus Schritt 04
    left join LIQ_INACTIVE                                          AS LIQ              on PORTFOLIO.CUT_OFF_DATE=LIQ.CUTOFFDATE              and PORTFOLIO.KONTONR=LIQ.OUTSTANDING_ID
    left join NLB.LIQ_GESCHAEFTE                                    AS LIQ_G            on PORTFOLIO.CUT_OFF_DATE=LIQ_G.BESTANDSDATUM          and PORTFOLIO.KONTONR=LIQ_G.ALIAS
    --left join NLB.LIQ_UMSTRUKTURIERUNG                            AS REST             on REST.OST_NME_ALIAS=SUBSTR(BAS.FACILITY_ID,11,10)
    left join SMAP.AMORTIZATION_TYPE                                AS atype            on SUBSTR(atype.VALUE,1)=SUBSTR(SPOT.AMORTIZATION_TYPE,1)
    left join PROD_NUM_KR                                           as PROD_NUM_KR      on PORTFOLIO.FACILITY_ID=PROD_NUM_KR.FACILITY_ID --and PORTFOLIO.DATA_CUT_OFF_DATE = PROD_NUM_KR.CUT_OFF_DATE
    left join PROD_NUM_BW                                           as PROD_NUM_BW      on PORTFOLIO.FACILITY_ID=PROD_NUM_BW.FACILITY_ID --and PORTFOLIO.DATA_CUT_OFF_DATE = PROD_NUM_KR.CUT_OFF_DATE
    left join IMAP.PRODUKTKATALOG                                   AS PROD_KR          on coalesce(PORTFOLIO.PRODUCT_TYPE,PROD_NUM_BW.PRODUCT_TYPE_DETAIL,PROD_NUM_KR.PRODUCT_TYPE_DETAIL)=lpad(PROD_KR.PRODUCT_KEY,4,'0')
    left join IMAP.PRODUKTKATALOG                                   AS PROD_BW          on BW.ZM_PRKEY=lpad(PROD_BW.PRODUCT_KEY,4,'0')
    left join SPECIFICS_PRODUCTGROUPS                               AS PROD_SPECIFICS   on (PORTFOLIO.FACILITY_ID,PORTFOLIO.CUT_OFF_DATE) = (PROD_SPECIFICS.FACILITY_ID, PROD_SPECIFICS.CUT_OFF_DATE)
    left join bw_DAT_CHECK                                          AS BW_COD           on PORTFOLIO.CUT_OFF_DATE=BW.CUT_OFF_DATE
    left join CALC.SWITCH_FACILITY_KREDITRISIKO_KENNZAHLEN_CURRENT  AS RISIKO           on PORTFOLIO.CUT_OFF_DATE=RISIKO.CUT_OFF_DATE         and PORTFOLIO.FACILITY_ID=RISIKO.FACILITY_ID
    where 1=1
    )
select * from MAPPING
;
------------------------------------------------------------------------------------------------------------------------

-- CI START FOR ALL TAPES

-- CURRENT TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_FACILITY_CORE_CURRENT');
create table AMC.TABLE_FACILITY_CORE_CURRENT like CALC.VIEW_FACILITY_CORE distribute by hash(FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_CORE_CURRENT_FACILITY_ID on AMC.TABLE_FACILITY_CORE_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_FACILITY_CORE_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- ARCHIVE TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_FACILITY_CORE_ARCHIVE');
create table AMC.TABLE_FACILITY_CORE_ARCHIVE like AMC.TABLE_FACILITY_CORE_CURRENT distribute by hash(FACILITY_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_CORE_ARCHIVE_FACILITY_ID on AMC.TABLE_FACILITY_CORE_ARCHIVE (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_FACILITY_CORE_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCHES erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_FACILITY_CORE_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_FACILITY_CORE_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

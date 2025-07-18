drop view CALC.VIEW_CLIENT_ACCOUNTHOLDER_FACILITY;
create or replace view CALC.VIEW_CLIENT_ACCOUNTHOLDER_FACILITY  as
with
 -- Kunden Basisdaten
    BASIS as (
        select distinct PORTFOLIO.CUT_OFF_DATE            as CUT_OFF_DATE -- Stichtag (gemappt)
                      , CLIENT_NO                         as CLIENT_NO    -- Kundennummer als Zahl
                      , BRANCH_CLIENT                     as BRANCH       -- Institut des Kunden (passend zu CLIENT_ID_NO, nicht CLIENT_ID_ORIG!)
                      , FACILITY_ID
                      , PORTFOLIO_IWHS_CLIENT_KUNDENBERATER as KUBE_OE
        from CALC.SWITCH_PORTFOLIO_CURRENT as PORTFOLIO
    ),
    SAP_DATA as (
        select SAP.CUT_OFF_DATE,
               SAP.SAP_KUNDE,
               SAP.SAP_EAD,
               SAP.SAP_EL,
               SAP.SAP_INANSPRUCHNAHME,
               SAP.SAP_SUMME_BLANKO,
               SAP.SAP_FREIELINIE,
               SAP.SAP_EWBTES,
               SAP.FACILITY_ID,
               SAP_PRODUCTS.IS_AVAL as IS_AVAL
        from CALC.SWITCH_FACILITY_BW_P80_AOER_CURRENT as SAP
                 left join SMAP.SAP_PRODUCTS as SAP_PRODUCTS on (SAP_PRODUCTS.PRODUCT_NO) = (SAP.SAP_PRODUKT)
    ),
     ABIT_RIVO_DATA as (
         select ABIT.CUT_OFF_DATE,
                ABIT.CLIENT_ID_ORIG,
                ABIT.FACILITY_ID,
                ABIT.LOAN_LOSS_PROVISION_AMOUNT_EUR as ABIT_RST_EUR,
                ABIT.SPECIFIC_PROVISION_AMOUNT_EUR as ABIT_EWB_EUR
         from CALC.SWITCH_FACILITY_ABIT_RISK_PROVISION_CURRENT as ABIT
     ),
     ZEB_RIVO_DATA as (
         select ZEB.CUT_OFF_DATE,
                ZEB.CLIENT_ID_ORIG,
                ZEB.FACILITY_ID,
                ZEB.ZEB_EWB_EUR_ONBALANCE,
                ZEB.ZEB_EWB_EUR_OFFBALANCE
         from CALC.SWITCH_FACILITY_ZEB_RISK_PROVISION_CURRENT as ZEB
     ),
     FACILITY_CORE_DATA as (
         select CUT_OFF_DATE,
                FACILITY_ID,
                AMORTIZATION_IN_ARREARS_EUR_SPOT as TILGUNGSRUECKSTAND_RAW,
                AVG(PRICIPAL_OST_EUR_SPOT) as PRINCIPAL_RAW,
                AVG(OWN_SYNDICATE_QUOTA) as KONSORTIALANTEIL,
                AVG(INTEREST_IN_ARREARS_EUR_SPOT) as ZINSRUECKSTAND_RAW,
                AVG(FEES_IN_ARREARS_EUR_SPOT) as PROVISIONSRUECKSTAND_RAW,
                AVG(OFFBALANCE_EUR) as OFFBALANCE,
                AVG(FVA_EUR) as FVA,
                case when AVG(OWN_SYNDICATE_QUOTA) = 0
                    then coalesce(-AVG(PRICIPAL_OST_EUR_SPOT),0)
                    else (case when SUBSTR(FACILITY_ID,5,4) = '-30-'
                    then -AVG(PRICIPAL_OST_EUR_SPOT)
                    else -AVG(PRICIPAL_OST_EUR_SPOT) * AVG(OWN_SYNDICATE_QUOTA)*0.01 end) end as PRINCIPALAVAL,
                case when SUBSTR(FACILITY_ID,5,4) = '-30-'
                    then -AVG(PRICIPAL_OST_EUR_SPOT)
                    else -AVG(PRICIPAL_OST_EUR_SPOT) * AVG(OWN_SYNDICATE_QUOTA)*0.01 end as PRINCIPAL,
                case when SUBSTR(FACILITY_ID,5,4) = '-30-'
                    then NULL
                    else -AMORTIZATION_IN_ARREARS_EUR_SPOT * AVG(OWN_SYNDICATE_QUOTA)*0.01 end as TILGUNGSRUECKSTAND,
                case when SUBSTR(FACILITY_ID,5,4) = '-30-'
                    then NULL
                    else -AVG(INTEREST_IN_ARREARS_EUR_SPOT) * AVG(OWN_SYNDICATE_QUOTA)*0.01 end as ZINSRUECKSTAND,
                case when SUBSTR(FACILITY_ID,5,4) = '-30-'
                    then -AVG(FEES_IN_ARREARS_EUR_SPOT)
                    else -AVG(FEES_IN_ARREARS_EUR_SPOT) * AVG(OWN_SYNDICATE_QUOTA)*0.01 end as PROVISIONSRUECKSTAND
         from CALC.SWITCH_FACILITY_CORE_CURRENT
         group by CUT_OFF_DATE, FACILITY_ID, AMORTIZATION_IN_ARREARS_EUR_SPOT
     ),
    FINAL_DATA as (
        select  BASIS.CUT_OFF_DATE
               ,BASIS.CLIENT_NO
               ,BASIS.BRANCH
               , Sum(coalesce(ZEB.ZEB_EWB_EUR_ONBALANCE, 0))           as ZEB_EWB_EUR_ONBALANCE_SUMME
               , Sum(coalesce(ZEB.ZEB_EWB_EUR_OFFBALANCE, 0))          as ZEB_EWB_EUR_OFFBALANCE_SUMME
               , Sum(coalesce(ABIT.ABIT_RST_EUR, 0))                   as ABIT_RST_EUR_SUMME
               , Sum(coalesce(ABIT.ABIT_EWB_EUR, 0))                   as ABIT_EWB_EUR_SUMME
               , Sum(coalesce(SAP.SAP_EAD, 0))                         as SAP_EAD_SUMME
               , Sum(coalesce(SAP.SAP_EL, 0))                          as SAP_EL_SUMME
               , Sum(coalesce(SAP.SAP_INANSPRUCHNAHME, 0))             as SAP_INANSPRUCHNAHME_SUMME
               , Sum(coalesce(SAP.SAP_SUMME_BLANKO, 0))                as SAP_BLANKO_SUMME
               , Sum(coalesce(SAP.SAP_FREIELINIE, 0))                  as SAP_FREILINIE_SUMME
               , Sum(coalesce(SAP.SAP_EWBTES, 0))                      as SAP_EWBTES_SUMME
               , Sum(case
                     when SUBSTR(BASIS.FACILITY_ID, 6, 2) = '30' then
                         coalesce(SAP.SAP_INANSPRUCHNAHME, 0) else 0 end) as SAP_INANSPRUCHNAHME_AZ6_SUMME
               , SUM(
               case
                     when SAP.IS_AVAL then
                         coalesce(SAP.SAP_INANSPRUCHNAHME, 0) else 0 end) as SAP_INANSPRUCHNAHME_AVAL_SUMME
               , Sum(max(coalesce(FACILITY_CORE.PRINCIPAL, 0),0)) as FORDERUNG_SUMME
               , Sum(
                   case when SAP.IS_AVAL then
                   max(coalesce(FACILITY_CORE.PRINCIPALAVAL, 0),0) else 0 end) as FORDERUNGAVAL_SUMME
               , SUM(case
                     when LEFT(BASIS.FACILITY_ID, 3) = 'K02' then
                         max(coalesce(FACILITY_CORE.PRINCIPAL, 0),0)
                     else 0 end)                                        as FORDERUNG_K028_SUMME
               , case
                     when BASIS.KUBE_OE = 'RSM Markets' then
                         Sum(max(coalesce(FACILITY_CORE.PRINCIPAL, 0),0))
                     else 0 end                                        as FORDERUNG_RSMMARKETS_SUMME
               , Sum(max(coalesce(-FACILITY_CORE.PRINCIPAL, 0),0))     as GUTHABEN_SUMME
               , Sum(coalesce(FACILITY_CORE.TILGUNGSRUECKSTAND, 0))    as TILGUNGSRUECKSTAND_SUMME
               , Sum(coalesce(FACILITY_CORE.ZINSRUECKSTAND, 0))        as ZINSRUECKSTAND_SUMME
               , Sum(coalesce(FACILITY_CORE.PROVISIONSRUECKSTAND, 0))  as PROVISIONSRUECKSTAND_SUMME
               , Sum(coalesce(FACILITY_CORE.OFFBALANCE, 0))            as OFFBALANCE_SUMME
               , Sum(coalesce(FACILITY_CORE.FVA, 0))                   as FVA_SUMME
        from BASIS
        left join SAP_DATA              as SAP              on (SAP.CUT_OFF_DATE, SAP.FACILITY_ID) = (BASIS.CUT_OFF_DATE, BASIS.FACILITY_ID)
        left join ABIT_RIVO_DATA        as ABIT             on (ABIT.CUT_OFF_DATE, ABIT.FACILITY_ID) = (BASIS.CUT_OFF_DATE, BASIS.FACILITY_ID)
        left join ZEB_RIVO_DATA         as ZEB              on (ZEB.CUT_OFF_DATE, ZEB.FACILITY_ID) = (BASIS.CUT_OFF_DATE, BASIS.FACILITY_ID)
        left join FACILITY_CORE_DATA    as FACILITY_CORE    on (FACILITY_CORE.CUT_OFF_DATE, FACILITY_CORE.FACILITY_ID) = (BASIS.CUT_OFF_DATE, BASIS.FACILITY_ID)
        group by  BASIS.CUT_OFF_DATE, BASIS.CLIENT_NO, BASIS.BRANCH, BASIS.KUBE_OE
    )
    select FINAL_DATA.CUT_OFF_DATE,
           FINAL_DATA.CLIENT_NO,
           FINAL_DATA.BRANCH,
           ROUND(FINAL_DATA.ZEB_EWB_EUR_ONBALANCE_SUMME,2) as ZEB_EWB_EUR_ONBALANCE_SUMME,
           ROUND(FINAL_DATA.ZEB_EWB_EUR_OFFBALANCE_SUMME,2) as ZEB_EWB_EUR_OFFBALANCE_SUMME,
           ROUND(FINAL_DATA.ABIT_EWB_EUR_SUMME,2) as ABIT_EWB_EUR_SUMME,
           ROUND(FINAL_DATA.ABIT_RST_EUR_SUMME,2) as ABIT_RST_EUR_SUMME,
           ROUND(FINAL_DATA.SAP_BLANKO_SUMME,2) as SAP_BLANKO_SUMME,
           ROUND(FINAL_DATA.SAP_EAD_SUMME,2) as SAP_EAD_SUMME,
           ROUND(FINAL_DATA.SAP_EL_SUMME,2) as SAP_EL_SUMME,
           ROUND(FINAL_DATA.SAP_EWBTES_SUMME,2) as SAP_EWBTES_SUMME,
           ROUND(FINAL_DATA.SAP_FREILINIE_SUMME,2) as SAP_FREILINIE_SUMME,
           ROUND(FINAL_DATA.SAP_INANSPRUCHNAHME_AVAL_SUMME,2) as SAP_INANSPRUCHNAHME_AVAL_SUMME,
           ROUND(FINAL_DATA.SAP_INANSPRUCHNAHME_AZ6_SUMME,2) as SAP_INANSPRUCHNAHME_AZ6_SUMME,
           ROUND(FINAL_DATA.SAP_INANSPRUCHNAHME_SUMME,2) as SAP_INANSPRUCHNAHME_SUMME,
           ROUND(FINAL_DATA.FORDERUNG_K028_SUMME,2) as FORDERUNG_K028_SUMME,
           ROUND(FINAL_DATA.FORDERUNG_RSMMARKETS_SUMME,2) as FORDERUNG_RSMMARKETS_SUMME,
           ROUND(FINAL_DATA.FORDERUNG_SUMME,2) as FORDERUNG_SUMME,
           ROUND(FINAL_DATA.FORDERUNGAVAL_SUMME,2) as FORDERUNGAVAL_SUMME,
           ROUND(FINAL_DATA.GUTHABEN_SUMME,2) as GUTHABEN_SUMME,
           ROUND(FINAL_DATA.TILGUNGSRUECKSTAND_SUMME,2) as TILGUNGSRUECKSTAND_SUMME,
           ROUND(FINAL_DATA.ZINSRUECKSTAND_SUMME,2) as ZINSRUECKSTAND_SUMME,
           ROUND(FINAL_DATA.PROVISIONSRUECKSTAND_SUMME,2) as PROVISIONSRUECKSTAND_SUMME,
           ROUND(FINAL_DATA.OFFBALANCE_SUMME,2) as OFFBALANCE_SUMME,
           ROUND(FINAL_DATA.FVA_SUMME,2) as FVA_SUMME
    from FINAL_DATA;


-- CI START FOR ALL TAPES

-- Current-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_CLIENT_ACCOUNTHOLDER_FACILITY_CURRENT');
create table AMC.TABLE_CLIENT_ACCOUNTHOLDER_FACILITY_CURRENT like CALC.VIEW_CLIENT_ACCOUNTHOLDER_FACILITY distribute by hash(BRANCH,CLIENT_NO) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CLIENT_ACCOUNTHOLDER_FACILITY_CURRENT_BRANCH    on AMC.TABLE_CLIENT_ACCOUNTHOLDER_FACILITY_CURRENT (BRANCH);
create index AMC.INDEX_CLIENT_ACCOUNTHOLDER_FACILITY_CURRENT_CLIENT_NO on AMC.TABLE_CLIENT_ACCOUNTHOLDER_FACILITY_CURRENT (CLIENT_NO);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_CLIENT_ACCOUNTHOLDER_FACILITY_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCHES erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_CLIENT_ACCOUNTHOLDER_FACILITY_CURRENT');
------------------------------------------------------------------------------------------------------------------------
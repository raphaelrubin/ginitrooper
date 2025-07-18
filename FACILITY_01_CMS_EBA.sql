-- View erstellen
drop view CALC.VIEW_FACILITY_CMS_EBA;
create or replace view CALC.VIEW_FACILITY_CMS_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
-- Quelldaten
CMS_LI as (
    select CUTOFFDATE      as CUT_OFF_DATE,
           GW_FORDERUNGSID as FACILITY_ID,
           AKT_RISK_KONTO,
           RISK_KONTO_WAEHR
    from NLB.CMS_LINK_CURRENT
    where CUTOFFDATE = (select CUT_OFF_DATE from COD)
      and UPPER(SV_STATUS) = 'RECHTLICH AKTIV'
      and GW_FORDERUNGSID is not null
),
-- Währungsumrechnung
CMS_EUR as (
    select C.CUT_OFF_DATE,
           FACILITY_ID,
           AKT_RISK_KONTO * CM.RATE_TARGET_TO_EUR as AKT_RISK_KONTO,
           case
               when CM.ZIEL_WHRG is not null
                   then 'EUR'
               else RISK_KONTO_WAEHR
               end                                as AKT_RISK_KONTO_CURRENCY,
           RISK_KONTO_WAEHR                       as AKT_RISK_KONTO_CURRENCY_OC
    from CMS_LI C
             left join IMAP.CURRENCY_MAP CM on (C.CUT_OFF_DATE, C.RISK_KONTO_WAEHR) = (CM.CUT_OFF_DATE, CM.ZIEL_WHRG)
),
-- Je Facility aufsummieren
CMS_SUM_EUR as (
    select CUT_OFF_DATE,
           FACILITY_ID,
           SUM(AKT_RISK_KONTO) as AKT_RISK_KONTO_SUM,
           case
               when COUNT(distinct AKT_RISK_KONTO_CURRENCY) > 1
                   then cast('UNEINDEUTIG: ' || LISTAGG(distinct AKT_RISK_KONTO_CURRENCY, ', ') as VARCHAR(500))
               else MAX(AKT_RISK_KONTO_CURRENCY)
               end             as AKT_RISK_KONTO_SUM_CURRENCY,
           case
               when COUNT(distinct AKT_RISK_KONTO_CURRENCY_OC) > 1
                   then cast('UNEINDEUTIG: ' || LISTAGG(distinct AKT_RISK_KONTO_CURRENCY_OC, ', ') as VARCHAR(500))
               else MAX(AKT_RISK_KONTO_CURRENCY_OC)
               end             as AKT_RISK_KONTO_SUM_CURRENCY_OC
    from CMS_EUR
    group by CUT_OFF_DATE, FACILITY_ID
),
--
FINAL as (
    select CUT_OFF_DATE,
           FACILITY_ID,
           AKT_RISK_KONTO_SUM             as ALLOCATED_COLLATERAL_VALUE,
           AKT_RISK_KONTO_SUM_CURRENCY    as ALLOCATED_COLLATERAL_VALUE_CURRENCY,
           AKT_RISK_KONTO_SUM_CURRENCY_OC as ALLOCATED_COLLATERAL_VALUE_CURRENCY_OC
    from CMS_SUM_EUR
),
-- Gefiltert nach noetigen Datenfeldern
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        FACILITY_ID,
        ALLOCATED_COLLATERAL_VALUE,
        ALLOCATED_COLLATERAL_VALUE_CURRENCY,
        ALLOCATED_COLLATERAL_VALUE_CURRENCY_OC,
        -- Defaults
        CURRENT_USER      as USER,
        CURRENT_TIMESTAMP as TIMESTAMP_LOAD
    from FINAL
)
select *
from FINAL_FILTERED;

-- CI START FOR ALL TAPES

-- Current-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_FACILITY_CMS_EBA_CURRENT');
create table AMC.TABLE_FACILITY_CMS_EBA_CURRENT like CALC.VIEW_FACILITY_CMS_EBA distribute by hash (FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_CMS_EBA_CURRENT_FACILITY_ID on AMC.TABLE_FACILITY_CMS_EBA_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_FACILITY_CMS_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_FACILITY_CMS_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------



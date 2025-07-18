-- View erstellen
drop view CALC.VIEW_FACILITY_TO_COLLATERAL_CMS_EBA;
create or replace view CALC.VIEW_FACILITY_TO_COLLATERAL_CMS_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
-- Quelldaten
CMS_LI as (
    select CUTOFFDATE           as CUT_OFF_DATE,
           GW_FORDERUNGSID      as FACILITY_ID,
           SV_ID                as COLLATERAL_ID,
           'NLB_' || GW_PARTNER as GNI_KUNDE,
           MAX_RISK_KONTO,
           AKT_RISK_KONTO,
           RISK_KONTO_WAEHR
    from NLB.CMS_LINK_CURRENT
    where CUTOFFDATE = (select CUT_OFF_DATE from COD)
      and UPPER(SV_STATUS) = 'RECHTLICH AKTIV'
      and GW_FORDERUNGSID is not null
),
CMS_FAC as (
    select distinct FACILITY_ID
    from CALC.SWITCH_FACILITY_CMS_EBA_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- C2F filtern auf vorhanden in Facility
CMS_LI_FILTERED as (
    select distinct LI.*
    from CMS_LI LI
             inner join CMS_FAC FAC on LI.FACILITY_ID = FAC.FACILITY_ID
),
-- Währungsumrechnung
CMS_EUR as (
    select C.CUT_OFF_DATE,
           FACILITY_ID,
           COLLATERAL_ID,
           GNI_KUNDE,
           case
               when CM.ZIEL_WHRG is not null
                   then MAX_RISK_KONTO * CM.RATE_TARGET_TO_EUR
               else MAX_RISK_KONTO
               end          as MAX_RISK_KONTO,
           case
               when CM.ZIEL_WHRG is not null
                   then AKT_RISK_KONTO * CM.RATE_TARGET_TO_EUR
               else AKT_RISK_KONTO
               end          as AKT_RISK_KONTO,
           case
               when CM.ZIEL_WHRG is not null
                   then 'EUR'
               else RISK_KONTO_WAEHR
               end          as RISK_KONTO_CURRENCY,
           RISK_KONTO_WAEHR as RISK_KONTO_CURRENCY_OC
    from CMS_LI_FILTERED C
             left join IMAP.CURRENCY_MAP CM on (C.CUT_OFF_DATE, C.RISK_KONTO_WAEHR) = (CM.CUT_OFF_DATE, CM.ZIEL_WHRG)
),
--
FINAL as (
    select CUT_OFF_DATE,
           FACILITY_ID,
           COLLATERAL_ID,
           GNI_KUNDE,
           MAX_RISK_KONTO,
           AKT_RISK_KONTO,
           RISK_KONTO_CURRENCY,
           RISK_KONTO_CURRENCY_OC
    from CMS_EUR
),
-- Gefiltert nach noetigen Datenfeldern
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        FACILITY_ID,
        COLLATERAL_ID,
        GNI_KUNDE,
        MAX_RISK_KONTO,
        AKT_RISK_KONTO,
        RISK_KONTO_CURRENCY,
        RISK_KONTO_CURRENCY_OC,
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
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_FACILITY_TO_COLLATERAL_CMS_EBA_CURRENT');
create table AMC.TABLE_FACILITY_TO_COLLATERAL_CMS_EBA_CURRENT like CALC.VIEW_FACILITY_TO_COLLATERAL_CMS_EBA distribute by hash (COLLATERAL_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_TO_COLLATERAL_CMS_EBA_CURRENT_COLLATERAL_ID on AMC.TABLE_FACILITY_TO_COLLATERAL_CMS_EBA_CURRENT (COLLATERAL_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_FACILITY_TO_COLLATERAL_CMS_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_FACILITY_TO_COLLATERAL_CMS_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------



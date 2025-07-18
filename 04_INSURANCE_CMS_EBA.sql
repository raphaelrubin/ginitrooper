-- View erstellen
drop view CALC.VIEW_INSURANCE_CMS_EBA;
-- Satellitentabelle Asset EBA
create or replace view CALC.VIEW_INSURANCE_CMS_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
-- Quelldaten
CMS_VV as (
    select CUT_OFF_DATE,
           VO_ID as ASSET_ID,
           INS_CATEGORY,
           INS_TYP,
           INS_SUM,
           INS_CURR,
           INS_EXPIRY_DATE,
           INS_BPID_INSURER,
           INS_BPF_INSURER,
           INS_BPID_POLICYHOLDER,
           INS_BPF_POLICYHOLDER
    from NLB.CMS_VV_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
---- Filter auf ASSET_EBA mit Vermeidung zyklischer Abhängigkeiten
PWC_ASSET as (
    select distinct ASSET_ID
    from CALC.SWITCH_ASSET_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
      and SOURCE = 'CMS'
),
CMS_ASSET as (
    select distinct ASSET_ID
    from CALC.SWITCH_ASSET_CMS_EBA_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
CMS_VV_FILTERED as (
    select VV.*
    from CMS_VV VV
             inner join CMS_ASSET CMS on VV.ASSET_ID = CMS.ASSET_ID
             inner join PWC_ASSET PWC on VV.ASSET_ID = PWC.ASSET_ID
),
-- Währungsumrechnung
CMS_VV_EUR as (
    select C.CUT_OFF_DATE,
           ASSET_ID as INS_ASSET_ID,
           INS_CATEGORY,
           INS_TYP,
           case
               when CM.ZIEL_WHRG is not null
                   then INS_SUM * CM.RATE_TARGET_TO_EUR
               else INS_SUM
               end  as INS_SUM,
           case
               when CM.ZIEL_WHRG is not null
                   then 'EUR'
               else INS_CURR
               end  as INS_SUM_CURRENCY,
           INS_CURR as INS_SUM_CURRENCY_OC,
           INS_EXPIRY_DATE,
           INS_BPID_INSURER,
           INS_BPF_INSURER,
           INS_BPID_POLICYHOLDER,
           INS_BPF_POLICYHOLDER
    from CMS_VV_FILTERED C
             left join IMAP.CURRENCY_MAP CM on (C.CUT_OFF_DATE, C.INS_CURR) = (CM.CUT_OFF_DATE, CM.ZIEL_WHRG)
),
-- Alles zusammenführen
FINAL as (
    select CUT_OFF_DATE,
           INS_ASSET_ID,
           INS_CATEGORY,
           INS_TYP,
           INS_SUM,
           INS_SUM_CURRENCY,
           INS_SUM_CURRENCY_OC,
           INS_EXPIRY_DATE,
           INS_BPID_INSURER,
           INS_BPF_INSURER,
           INS_BPID_POLICYHOLDER,
           INS_BPF_POLICYHOLDER
    from CMS_VV_EUR
),
-- Gefiltert nach noetigen Datenfeldern
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        INS_ASSET_ID,
        INS_CATEGORY,
        INS_TYP,
        INS_SUM,
        INS_SUM_CURRENCY,
        INS_SUM_CURRENCY_OC,
        INS_EXPIRY_DATE,
        INS_BPID_INSURER,
        INS_BPF_INSURER,
        INS_BPID_POLICYHOLDER,
        INS_BPF_POLICYHOLDER,
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
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_INSURANCE_CMS_EBA_CURRENT');
create table AMC.TABLE_INSURANCE_CMS_EBA_CURRENT like CALC.VIEW_INSURANCE_CMS_EBA distribute by hash (INS_ASSET_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_INSURANCE_CMS_EBA_CURRENT_INS_ASSET_ID on AMC.TABLE_INSURANCE_CMS_EBA_CURRENT (INS_ASSET_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_INSURANCE_CMS_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- Archiv-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_INSURANCE_CMS_EBA_ARCHIVE');
create table AMC.TABLE_INSURANCE_CMS_EBA_ARCHIVE like CALC.VIEW_INSURANCE_CMS_EBA distribute by hash (INS_ASSET_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_INSURANCE_CMS_EBA_ARCHIVE_ZEBRA_REXID on AMC.TABLE_INSURANCE_CMS_EBA_ARCHIVE (INS_ASSET_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_INSURANCE_CMS_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_INSURANCE_CMS_EBA_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_INSURANCE_CMS_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------


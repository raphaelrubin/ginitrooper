-- View erstellen
drop view CALC.VIEW_FACILITY_TO_COLLATERAL_EBA;
-- Verknüpfungstabelle Facility-Collateral EBA
create or replace view CALC.VIEW_FACILITY_TO_COLLATERAL_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
---- Quelldaten
PWC_F2C as (
    select *, CLIENT_ID as GNI_KUNDE
    from CALC.SWITCH_COLLATERAL_TO_FACILITY_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
CMS_F2C as (
    select *
    from CALC.SWITCH_FACILITY_TO_COLLATERAL_CMS_EBA_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- Alles zusammenführen
FINAL as (
    select distinct PWC.CUT_OFF_DATE,
                    PWC.GNI_KUNDE,
                    PWC.FACILITY_ID,
                    PWC.COLLATERAL_ID,
                    CMS.MAX_RISK_KONTO         as CMS_MAX_RISK_KONTO,
                    CMS.AKT_RISK_KONTO         as CMS_AKT_RISK_KONTO,
                    CMS.RISK_KONTO_CURRENCY    as CMS_RISK_KONTO_CURRENCY,
                    CMS.RISK_KONTO_CURRENCY_OC as CMS_RISK_KONTO_CURRENCY_OC
    from PWC_F2C PWC
             left join CMS_F2C CMS on PWC.DATA_SOURCE = 'CMS' and
                                      (PWC.GNI_KUNDE, PWC.FACILITY_ID, PWC.COLLATERAL_ID) = (CMS.GNI_KUNDE, CMS.FACILITY_ID, cast(CMS.COLLATERAL_ID as VARCHAR(32)))
),
-- Gefiltert nach noetigen Datenfeldern
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        NULLIF(GNI_KUNDE, null)                  as GNI_KUNDE,
        NULLIF(FACILITY_ID, null)                as FACILITY_ID,
        NULLIF(COLLATERAL_ID, null)              as COLLATERAL_ID,
        NULLIF(CMS_MAX_RISK_KONTO, null)         as CMS_MAX_RISK_KONTO,
        NULLIF(CMS_AKT_RISK_KONTO, null)         as CMS_AKT_RISK_KONTO,
        NULLIF(CMS_RISK_KONTO_CURRENCY, null)    as CMS_RISK_KONTO_CURRENCY,
        NULLIF(CMS_RISK_KONTO_CURRENCY_OC, null) as CMS_RISK_KONTO_CURRENCY_OC,
        -- Defaults
        CURRENT_USER                             as USER,
        CURRENT_TIMESTAMP                        as TIMESTAMP_LOAD
    from FINAL
)
select *
from FINAL_FILTERED;

-- CI START FOR ALL TAPES

-- Current-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_FACILITY_TO_COLLATERAL_EBA_CURRENT');
create table AMC.TABLE_FACILITY_TO_COLLATERAL_EBA_CURRENT like CALC.VIEW_FACILITY_TO_COLLATERAL_EBA distribute by hash (FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_TO_COLLATERAL_EBA_CURRENT_FACILITY_ID on AMC.TABLE_FACILITY_TO_COLLATERAL_EBA_CURRENT (FACILITY_ID);
create index AMC.INDEX_FACILITY_TO_COLLATERAL_EBA_CURRENT_COLLATERAL_ID on AMC.TABLE_FACILITY_TO_COLLATERAL_EBA_CURRENT (COLLATERAL_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_FACILITY_TO_COLLATERAL_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- Archiv-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_FACILITY_TO_COLLATERAL_EBA_ARCHIVE');
create table AMC.TABLE_FACILITY_TO_COLLATERAL_EBA_ARCHIVE like CALC.VIEW_FACILITY_TO_COLLATERAL_EBA distribute by hash (FACILITY_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_TO_COLLATERAL_EBA_ARCHIVE_FACILITY_ID on AMC.TABLE_FACILITY_TO_COLLATERAL_EBA_ARCHIVE (FACILITY_ID);
create index AMC.INDEX_FACILITY_TO_COLLATERAL_EBA_ARCHIVE_COLLATERAL_ID on AMC.TABLE_FACILITY_TO_COLLATERAL_EBA_ARCHIVE (COLLATERAL_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_FACILITY_TO_COLLATERAL_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_FACILITY_TO_COLLATERAL_EBA_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_FACILITY_TO_COLLATERAL_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------


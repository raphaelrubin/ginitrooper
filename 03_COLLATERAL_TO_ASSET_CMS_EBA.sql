-- View erstellen
drop view CALC.VIEW_COLLATERAL_TO_ASSET_CMS_EBA;
create or replace view CALC.VIEW_COLLATERAL_TO_ASSET_CMS_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
-- Quelldaten
CMS_VO as (
    select distinct VO_ID as ASSET_ID
    from NLB.CMS_VO_CURRENT
    where CUTOFFDATE = (select CUT_OFF_DATE from COD)
      and UPPER(VO_STATUS) = 'RECHTLICH AKTIV'
),
CMS_LA as (
    select distinct CUTOFFDATE as CUT_OFF_DATE,
                    SV_ID      as COLLATERAL_ID,
                    VO_ID      as ASSET_ID
    from NLB.CMS_LAST_CURRENT LA
    where CUTOFFDATE = (select CUT_OFF_DATE from COD)
),
CMS_COLL as (
    select distinct COLLATERAL_ID
    from CALC.SWITCH_COLLATERAL_CMS_EBA_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- C2A filtern auf vorhanden in Collateral
CMS_LA_FILTERED as (
    select LA.*
    from CMS_LA LA
             inner join CMS_COLL COLL on LA.COLLATERAL_ID = COLL.COLLATERAL_ID
),
--
FINAL as (
    select LA.CUT_OFF_DATE,
           LA.COLLATERAL_ID,
           LA.ASSET_ID
    from CMS_LA_FILTERED LA
             -- inner join für Filter auf Status rechtlich aktiv
             inner join CMS_VO VO on LA.ASSET_ID = VO.ASSET_ID
),
-- Gefiltert nach noetigen Datenfeldern
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        COLLATERAL_ID,
        ASSET_ID,
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
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_COLLATERAL_TO_ASSET_CMS_EBA_CURRENT');
create table AMC.TABLE_COLLATERAL_TO_ASSET_CMS_EBA_CURRENT like CALC.VIEW_COLLATERAL_TO_ASSET_CMS_EBA distribute by hash (COLLATERAL_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_COLLATERAL_TO_ASSET_CMS_EBA_CURRENT_COLLATERAL_ID on AMC.TABLE_COLLATERAL_TO_ASSET_CMS_EBA_CURRENT (COLLATERAL_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_COLLATERAL_TO_ASSET_CMS_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_COLLATERAL_TO_ASSET_CMS_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------


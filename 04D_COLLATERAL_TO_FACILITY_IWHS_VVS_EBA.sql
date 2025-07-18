-- View erstellen
drop view CALC.VIEW_COLLATERAL_TO_FACILITY_IWHS_VVS_EBA;
create or replace view CALC.VIEW_COLLATERAL_TO_FACILITY_IWHS_VVS_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
-- Collateral IDs von IWHS
IWHS_COLL as (
    select distinct CUT_OFF_DATE,
                    COLLATERAL_ID
    from CALC.SWITCH_COLLATERAL_IWHS_VVS_EBA_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- Collateral 2 Facility von PWC für Mapping an Facility IDs
PWC_C2F as (
    select distinct CUT_OFF_DATE,
                    COLLATERAL_ID,
                    FACILITY_ID
    from CALC.SWITCH_COLLATERAL_TO_FACILITY_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- Alles zusammenführen
FINAL as (
    select C.CUT_OFF_DATE,
           C.COLLATERAL_ID,
           C2F.FACILITY_ID
    from IWHS_COLL C
             left join PWC_C2F C2F on C.COLLATERAL_ID = C2F.COLLATERAL_ID
),
-- Gefiltert nach noetigen Datenfeldern
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        COLLATERAL_ID,
        FACILITY_ID,
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
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_COLLATERAL_TO_FACILITY_IWHS_VVS_EBA_CURRENT');
create table AMC.TABLE_COLLATERAL_TO_FACILITY_IWHS_VVS_EBA_CURRENT like CALC.VIEW_COLLATERAL_TO_FACILITY_IWHS_VVS_EBA distribute by hash (COLLATERAL_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_COLLATERAL_TO_FACILITY_IWHS_VVS_EBA_CURRENT_COLLATERAL_ID on AMC.TABLE_COLLATERAL_TO_FACILITY_IWHS_VVS_EBA_CURRENT (COLLATERAL_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_COLLATERAL_TO_FACILITY_IWHS_VVS_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_COLLATERAL_TO_FACILITY_IWHS_VVS_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- View erstellen
drop view CALC.VIEW_FACILITY_TO_COLLATERAL_IWHS_VVS_EBA;
create or replace view CALC.VIEW_FACILITY_TO_COLLATERAL_IWHS_VVS_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
---- Quelldaten
IWHS_ES as (
    select *
    from NLB.IWHS_EIGENTUEMER_UND_SICHERHEITENVERR_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
IWHS_SV as (
    select *
    from NLB.IWHS_SV_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- Alles zusammenführen
FINAL as (
    select distinct ES.CUT_OFF_DATE,
                    ES.FACILITY_ID,
                    ES.SIRE_ID_IWHS as COLLATERAL_ID
    from IWHS_ES ES
             inner join IWHS_SV SV on ES.SIRE_ID_IWHS = SV.SIRE_ID_IWHS
    where ES.FACILITY_ID is not null
      and ES.SIRE_ID_IWHS is not null
),
-- Gefiltert nach noetigen Datenfeldern + nullable
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        NULLIF(FACILITY_ID, null)   as FACILITY_ID,
        NULLIF(COLLATERAL_ID, null) as COLLATERAL_ID,
        -- Defaults
        CURRENT_USER                as USER,
        CURRENT_TIMESTAMP           as TIMESTAMP_LOAD
    from FINAL
)
select *
from FINAL_FILTERED;

-- CI START FOR ALL TAPES

-- Current-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_FACILITY_TO_COLLATERAL_IWHS_VVS_EBA_CURRENT');
create table AMC.TABLE_FACILITY_TO_COLLATERAL_IWHS_VVS_EBA_CURRENT like CALC.VIEW_FACILITY_TO_COLLATERAL_IWHS_VVS_EBA distribute by hash (FACILITY_ID, COLLATERAL_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_TO_COLLATERAL_IWHS_VVS_EBA_CURRENT_FACILITY_ID on AMC.TABLE_FACILITY_TO_COLLATERAL_IWHS_VVS_EBA_CURRENT (FACILITY_ID);
create index AMC.INDEX_FACILITY_TO_COLLATERAL_IWHS_VVS_EBA_CURRENT_COLLATERAL_ID on AMC.TABLE_FACILITY_TO_COLLATERAL_IWHS_VVS_EBA_CURRENT (COLLATERAL_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_FACILITY_TO_COLLATERAL_IWHS_VVS_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_FACILITY_TO_COLLATERAL_IWHS_VVS_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------


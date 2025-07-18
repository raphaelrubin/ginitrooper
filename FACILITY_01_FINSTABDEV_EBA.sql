-- View erstellen
drop view CALC.VIEW_FACILITY_FINSTABDEV_EBA;
create or replace view CALC.VIEW_FACILITY_FINSTABDEV_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
---- Output besteht aus gesamtem FinStabDev, Current + Archiv
-- Quelldaten Current
FSD_C as (
    select CUT_OFF_DATE,
           CUT_OFF_DATE          as MELDESTICHTAG_NEUGESCHAEFT,
           LEFT(POSITION_ID, 34) as FACILITY_ID,
           OBJECT_ID,
           PER027,
           PER028,
           PER031,
           PER033,
           RLV106
    from NLB.FINSTABDEV_DM_RRE_STAT_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
      -- Regelmäßige Lieferung -> Filter auf (1)
      and RLV106 like '%(1)%'
),
-- Quelldaten Archiv
FSD_A as (
    select (select CUT_OFF_DATE from COD) as CUT_OFF_DATE,
           case
               when CUT_OFF_DATE = DATE('2015-01-31')
                   -- Einmaliger Bestand, klarer kennzeichnen
                   then DATE('1900-01-01')
               else CUT_OFF_DATE
               end                        as MELDESTICHTAG_NEUGESCHAEFT,
           LEFT(POSITION_ID, 34)          as FACILITY_ID,
           OBJECT_ID,
           PER027,
           PER028,
           PER031,
           PER033,
           RLV106
    from NLB.FINSTABDEV_DM_RRE_STAT
    where
      -- Nur Daten vor Stichtag
        (CUT_OFF_DATE < (select CUT_OFF_DATE from COD))
      and
      -- Einmaliger Bestand -> Filter auf (2) + richtige POSITION_ID
        (OBJECT_ID != 'DUMMY_HIST' or (RLV106 like '%(2)%' and POSITION_ID not like '%#%'))
      and
      -- Regelmäßige Lieferung -> Filter auf (1)
        (OBJECT_ID = 'DUMMY_HIST' or RLV106 like '%(1)%')
),
-- Union
FSD_UNION as (
    select *
    from FSD_C
    union all
    select *
    from FSD_A
),
-- Duplikate entfernen
FSD_UNIQUE as (
    select *
    from (select *, ROW_NUMBER() over (partition by FACILITY_ID, OBJECT_ID) as RN
          from FSD_UNION)
    where RN = 1
),
-- Spalten Bezeichnung angepasst
FINAL as (
    select CUT_OFF_DATE,
           MELDESTICHTAG_NEUGESCHAEFT,
           FACILITY_ID,
           OBJECT_ID,
           PER027 as DSTI,
           PER028 as DTI,
           PER031 as VERHAELTNIS_DARLEHENSVOLUMEN_BELEIHUNGSWERT,
           PER033 as LTV,
           RLV106 as RELEVANZ_WIFSTA
    from FSD_UNIQUE
),
-- Gefiltert nach noetigen Datenfeldern
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        MELDESTICHTAG_NEUGESCHAEFT,
        FACILITY_ID,
        OBJECT_ID,
        DSTI,
        DTI,
        VERHAELTNIS_DARLEHENSVOLUMEN_BELEIHUNGSWERT,
        LTV,
        RELEVANZ_WIFSTA,
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
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_FACILITY_FINSTABDEV_EBA_CURRENT');
create table AMC.TABLE_FACILITY_FINSTABDEV_EBA_CURRENT like CALC.VIEW_FACILITY_FINSTABDEV_EBA distribute by hash (FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_FINSTABDEV_EBA_CURRENT_FACILITY_ID on AMC.TABLE_FACILITY_FINSTABDEV_EBA_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_FACILITY_FINSTABDEV_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_FACILITY_FINSTABDEV_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

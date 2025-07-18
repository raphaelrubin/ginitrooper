-- View erstellen
drop view CALC.VIEW_FACILITY_DIVERS_EBA;
-- Sammeltabelle für diverse EBA Spalten
create or replace view CALC.VIEW_FACILITY_DIVERS_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
---- Quelldaten
SPOT_INSTRMNT as (
    select *, SAPFDB_ID as FACILITY_ID
    from NLB.SPOT_LOANTAPE_INSTRUMENT_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
SPOT_CR_INSTRMNT as (
    select *, SAPFDB_ID as FACILITY_ID
    from NLB.SPOT_LOANTAPE_CLIENT_RATING_INSTRUMENT_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
ABCS_POS as (
    select *, POSITION_ID as FACILITY_ID
    from NLB.ABACUS_POSITION_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
      -- Abacus Zeilen mit „#“ in der POSITION_ID ausschließen
      and POSITION_ID not like '%#%'
),
P80_NLB as (
    select *, BA1_C11EXTCON as FACILITY_ID
    from NLB.BW_P80_RDL_EXTERNAL_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
P80_ANL as (
    select *, BA1_C11EXTCON as FACILITY_ID
    from ANL.BW_P80_RDL_EXTERNAL_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
P80_CBB as (
    select *, BA1_C11EXTCON as FACILITY_ID
    from CBB.BW_P80_RDL_EXTERNAL_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
P80_UNION as (
    select *
    from P80_NLB
    union all
    select *
    from P80_ANL
    union all
    select *
    from P80_CBB
),
-- P80 Logik
P80_SUM as (
    select CUT_OFF_DATE,
           FACILITY_ID,
           BIC_XS_CONTCU  as CURRENCY_OC,
           BIC_EVAL_CURR  as CURRENCY,
           SUM(BIC_E_EAD) as EAD_REGULATORISCH,
           case
               when SUM(BIC_E_EAD) != 0
                   then SUM(BIC_E_EAD * BIC_B_LGDWER) / SUM(BIC_E_EAD)
               else 0
               end        as LGD_REGULATORISCH
    from P80_UNION
    group by CUT_OFF_DATE, FACILITY_ID, BIC_XS_CONTCU, BIC_EVAL_CURR
),
-- Alles zusammenführen
FINAL as (
    select NVL(SPOT1.CUT_OFF_DATE, SPOT2.CUT_OFF_DATE, ABCS.CUT_OFF_DATE, P80.CUT_OFF_DATE) as CUT_OFF_DATE,
           NVL(SPOT1.FACILITY_ID, SPOT2.FACILITY_ID, ABCS.FACILITY_ID, P80.FACILITY_ID)     as FACILITY_ID,
           SPOT1.PD_CRR_RD,
           SPOT1.FBE_STUFE,
           SPOT2.DT_INTRNL_RTNG,
           SPOT2.INTRNL_RTNG,
           ABCS.CRI114                                                                      as CRI114_STUNDUNGS_U_NEUVERHANDLUNGSSTATUS,
           P80.LGD_REGULATORISCH,
           P80.EAD_REGULATORISCH,
           P80.CURRENCY_OC,
           P80.CURRENCY
    from SPOT_INSTRMNT SPOT1
             full outer join SPOT_CR_INSTRMNT SPOT2 on SPOT1.FACILITY_ID = SPOT2.FACILITY_ID
             full outer join ABCS_POS ABCS on NVL(SPOT1.FACILITY_ID, SPOT2.FACILITY_ID) = ABCS.FACILITY_ID
             full outer join P80_SUM P80 on NVL(SPOT1.FACILITY_ID, SPOT2.FACILITY_ID, ABCS.FACILITY_ID) = P80.FACILITY_ID
),
-- Gefiltert nach noetigen Datenfeldern
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        FACILITY_ID,
        DT_INTRNL_RTNG,
        INTRNL_RTNG,
        LGD_REGULATORISCH,
        EAD_REGULATORISCH,
        CURRENCY_OC,
        CURRENCY,
        PD_CRR_RD,
        FBE_STUFE,
        CRI114_STUNDUNGS_U_NEUVERHANDLUNGSSTATUS,
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
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_FACILITY_DIVERS_EBA_CURRENT');
create table AMC.TABLE_FACILITY_DIVERS_EBA_CURRENT like CALC.VIEW_FACILITY_DIVERS_EBA distribute by hash (FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_DIVERS_EBA_CURRENT_FACILITY_ID on AMC.TABLE_FACILITY_DIVERS_EBA_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_FACILITY_DIVERS_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_FACILITY_DIVERS_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------


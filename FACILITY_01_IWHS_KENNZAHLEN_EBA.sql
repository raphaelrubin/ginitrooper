-- View erstellen
drop view CALC.VIEW_FACILITY_IWHS_KENNZAHLEN_EBA;
create or replace view CALC.VIEW_FACILITY_IWHS_KENNZAHLEN_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
---- Quelldaten
KNZHL as (
    select *
    from NLB.IWHS_KENNZAHLEN_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
      and FACILITY_ID is not null
),
-- Keine Duplikate in den relevanten Spalten
KNZHL_DIST as (
    select distinct CUT_OFF_DATE,
                    PERSONEN_NR,
                    GSPR_VGNG_NR,
                    LVTV,
                    LSTI,
                    LTI,
                    DSCR,
                    EIGENER_ANTEIL_DES_SCHULDENDIENSTES_EINER_PERSON_FUER_EIGENE_VEREINBARUNGEN as PERS_EIGN_SCHD_DNST,
                    FREMDER_ANTEIL_DES_SCHULDENDIENSTES_EINER_PERSON_FUER_FREMDE_VEREINBARUNGEN as PERS_FRMD_SCHD_DNST,
                    FINANZIERUNGSBAUSTEIN,
                    VORHABENART,
                    FACILITY_ID,
                    FACILITY_SAP_ID
    from KNZHL
),
-- Spalten aggregieren für distinct FACILITY_ID
FINAL as (
    select CUT_OFF_DATE,
           LISTAGG(PERSONEN_NR, ', ') within group (order by PERSONEN_NR)                                                   as PERSONEN_NR,
           MAX(GSPR_VGNG_NR)                                                                                                as GSPR_VGNG_NR,
           MAX(LVTV)                                                                                                        as LVTV,
           MAX(LSTI)                                                                                                        as LSTI,
           MAX(LTI)                                                                                                         as LTI,
           MAX(DSCR)                                                                                                        as DSCR,
           -- Cast as decfloat for nice format
           LISTAGG(CAST(ROUND(DECFLOAT(PERS_EIGN_SCHD_DNST), 2) as VARCHAR(500)), ', ') within group (order by PERSONEN_NR) as PERS_EIGN_SCHD_DNST,
           LISTAGG(CAST(ROUND(DECFLOAT(PERS_FRMD_SCHD_DNST), 2) as VARCHAR(500)), ', ') within group (order by PERSONEN_NR) as PERS_FRMD_SCHD_DNST,
           MAX(FINANZIERUNGSBAUSTEIN)                                                                                       as FINANZIERUNGSBAUSTEIN,
           MAX(VORHABENART)                                                                                                 as VORHABENART,
           FACILITY_ID,
           FACILITY_SAP_ID
    from KNZHL_DIST
    group by CUT_OFF_DATE, FACILITY_ID, FACILITY_SAP_ID
),
-- Gefiltert nach noetigen Datenfeldern
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        NULLIF(PERSONEN_NR, null)           as PERSONEN_NR,
        NULLIF(GSPR_VGNG_NR, null)          as GSPR_VGNG_NR,
        NULLIF(LVTV, null)                  as LVTV,
        NULLIF(LSTI, null)                  as LSTI,
        NULLIF(LTI, null)                   as LTI,
        NULLIF(DSCR, null)                  as DSCR,
        NULLIF(PERS_EIGN_SCHD_DNST, null)   as PERS_EIGN_SCHD_DNST,
        NULLIF(PERS_FRMD_SCHD_DNST, null)   as PERS_FRMD_SCHD_DNST,
        NULLIF(FINANZIERUNGSBAUSTEIN, null) as FINANZIERUNGSBAUSTEIN,
        NULLIF(VORHABENART, null)           as VORHABENART,
        NULLIF(FACILITY_ID, null)           as FACILITY_ID,
        NULLIF(FACILITY_SAP_ID, null)       as FACILITY_SAP_ID,
        -- Defaults
        CURRENT_USER                        as USER,
        CURRENT_TIMESTAMP                   as TIMESTAMP_LOAD
    from FINAL
)
select *
from FINAL_FILTERED;

-- CI START FOR ALL TAPES

-- Current-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_FACILITY_IWHS_KENNZAHLEN_EBA_CURRENT');
create table AMC.TABLE_FACILITY_IWHS_KENNZAHLEN_EBA_CURRENT like CALC.VIEW_FACILITY_IWHS_KENNZAHLEN_EBA distribute by hash (FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_IWHS_KENNZAHLEN_EBA_CURRENT_FACILITY_ID on AMC.TABLE_FACILITY_IWHS_KENNZAHLEN_EBA_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_FACILITY_IWHS_KENNZAHLEN_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_FACILITY_IWHS_KENNZAHLEN_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------


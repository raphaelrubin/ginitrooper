-- View erstellen
drop view CALC.VIEW_COLLATERAL_IWHS_VVS_EBA;
create or replace view CALC.VIEW_COLLATERAL_IWHS_VVS_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
---- Quelldaten
IWHS_SV as (
    select *
    from NLB.IWHS_SV_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
IWHS_ES as (
    select *
    from NLB.IWHS_EIGENTUEMER_UND_SICHERHEITENVERR_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
---- Alles zusammenführen
FINAL as (
    select distinct SV.CUT_OFF_DATE,
                    SV.SIRE_ID_IWHS                             as COLLATERAL_ID,
                    SV.SIRE_ART_ELEMENTAR,
                    SV.SICHERHEITENBETRAG,
                    SV.GPFR_NTRT_ASLF_PROZ,
                    SV.GPFR_NTRT_ASLF_BTRG,
                    SV.SIBB_MAX_REAL,
                    SV.SIBB_MAX_PERS,
                    SV.SIBB_MAX_WSFT,
                    SV.SIRE_AFTL_PROZ,
                    SV.SIHT_GSI_KWG_SCHL,
                    ES.SIRE_PRODUKTNAME,
                    ES.VMGO_PRODUKTNAME,
                    ES.SICHERHEITENSCHLUESSEL,
                    ES.SICHERUNGSRECHT_ART,
                    ES.SICHERHEIT_BEFRISTET_BIS,
                    ES.NOMINALWERT_DER_SICHERHEIT               as NOMINALWERT_SICHERHEIT,
                    ES.NOMINALWERT_DER_SICHERHEIT_FREMDWAEHRUNG as NOMINALWERT_SICHERHEIT_FW,
                    ES.FORDERUNGSBETRAG,
                    ES.URSPRUNGSWAEHRUNG,
                    ES.FORDERUNGSWERT,
                    ES.SICHERHEITENWERT_PERSONAL,
                    ES.SICHERHEITENWERT_REAL,
                    ES.SICHERHEITENWERT_WIRTSCHFTLICH,
                    ES.SICHERHEITENWERT_BLANKO,
                    ES.SICHERHEITENWERT_FREI
    from IWHS_SV SV
             left join IWHS_ES ES on SV.SIRE_ID_IWHS = ES.SIRE_ID_IWHS
),
-- Gefiltert nach noetigen Datenfeldern
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        COLLATERAL_ID,
        SIRE_PRODUKTNAME,
        VMGO_PRODUKTNAME,
        SICHERHEITENSCHLUESSEL,
        SICHERUNGSRECHT_ART,
        SIRE_ART_ELEMENTAR,
        SICHERHEIT_BEFRISTET_BIS,
        NOMINALWERT_SICHERHEIT,
        NOMINALWERT_SICHERHEIT_FW,
        SICHERHEITENBETRAG,
        FORDERUNGSBETRAG,
        URSPRUNGSWAEHRUNG,
        FORDERUNGSWERT,
        SICHERHEITENWERT_PERSONAL,
        SICHERHEITENWERT_REAL,
        SICHERHEITENWERT_WIRTSCHFTLICH,
        SICHERHEITENWERT_BLANKO,
        SICHERHEITENWERT_FREI,
        GPFR_NTRT_ASLF_PROZ,
        GPFR_NTRT_ASLF_BTRG,
        SIBB_MAX_REAL,
        SIBB_MAX_PERS,
        SIBB_MAX_WSFT,
        SIRE_AFTL_PROZ,
        SIHT_GSI_KWG_SCHL,
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
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_COLLATERAL_IWHS_VVS_EBA_CURRENT');
create table AMC.TABLE_COLLATERAL_IWHS_VVS_EBA_CURRENT like CALC.VIEW_COLLATERAL_IWHS_VVS_EBA distribute by hash (COLLATERAL_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_COLLATERAL_IWHS_VVS_EBA_CURRENT_VMGO_NR on AMC.TABLE_COLLATERAL_IWHS_VVS_EBA_CURRENT (COLLATERAL_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_COLLATERAL_IWHS_VVS_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_COLLATERAL_IWHS_VVS_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------


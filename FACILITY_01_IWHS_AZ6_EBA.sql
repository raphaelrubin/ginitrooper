-- View erstellen
drop view CALC.VIEW_FACILITY_IWHS_AZ6_EBA;
create or replace view CALC.VIEW_FACILITY_IWHS_AZ6_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
---- Quelldaten
IWHS_AZ6 as (
    select *
    from NLB.IWHS_AZ6_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
IWHS_STM as (
    select CUTOFFDATE as CUT_OFF_DATE,
           FACILITY_ID,
           OWNSYNDICATEQUOTA
    from NLB.SPOT_STAMMDATEN_CURRENT
    where CUTOFFDATE = (select CUT_OFF_DATE from COD)
      -- Nur IWHS ziehen
      and QUELLE in ('NLB_IWHS', 'BLB_IWHS')
),
--
FINAL as (
    select AZ6.CUT_OFF_DATE,
           AZ6.FACILITY_ID,
           FACILITY_SAP_ID,
           case
               when WAEHRUNG is not null
                   then WAEHRUNG
               end                                        as CURRENCY,
           WAEHRUNG                                       as CURRENCY_OC,
           DARLEHENSART,
           BEFRISTUNG_DER_ZUSAGE                          as BEFRISTUNG_ZUSAGE,
           PRODUKTSCHLUESSEL,
           VERWENDUNGSZWECK,
           SOLLZINSSATZ / 100                             as SOLLZINSSATZ,
           AKTUELLE_ENDE_DATUM,
           DATUM_ERSTE_VALUTIERUNG,
           STUNDUNGSSALDO,
           BETRAG,
           TILGUNGSFORM_FUER_DARLEHENSART                 as TILGUNGSFORM_DARLEHENSART,
           KZ_MITHAFTUNG_MITTELGEBER,
           RISIKO_FREMD_KI_PROZENT / 100                  as RISIKO_FREMD_KI,
           KONTOSALDO,
           ENTGELTVERZUG,
           GESAMTVERZUG,
           UNVERZINSLICHER_VERZUG,
           VERZINSLICHER_VERZUG_BIS_31_12                 as VERZINSLICHER_VERZUG_BIS_31_DEZ,
           SONDERTILGUNG_MAXIMALBETRAG,
           SONDERTILGUNG_MINDESTBETRAG,
           LEISTUNGSSTOERUNGSBETRAG_SONDERTILGUNG,
           NICHT_PLANMAESSIGE_AENDERUNG_VERZINGSUNGSSALDO as NICHT_PLANMAESSIGE_AENDERUNG_VERZINSUNGSSALDO,
           LEISTUNGSSTOERUNGSBETRAG_SONDERTILGUNG_WG_PROLONGATION,
           STM.OWNSYNDICATEQUOTA,
           LOANSTATE
    from IWHS_AZ6 AZ6
             left join IWHS_STM STM on AZ6.FACILITY_ID = STM.FACILITY_ID
),
-- Gefiltert nach noetigen Datenfeldern
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        FACILITY_ID,
        FACILITY_SAP_ID,
        CURRENCY,
        CURRENCY_OC,
        DARLEHENSART,
        BEFRISTUNG_ZUSAGE,
        PRODUKTSCHLUESSEL,
        VERWENDUNGSZWECK,
        SOLLZINSSATZ,
        AKTUELLE_ENDE_DATUM,
        DATUM_ERSTE_VALUTIERUNG,
        STUNDUNGSSALDO,
        BETRAG,
        TILGUNGSFORM_DARLEHENSART,
        KZ_MITHAFTUNG_MITTELGEBER,
        RISIKO_FREMD_KI,
        KONTOSALDO,
        ENTGELTVERZUG,
        GESAMTVERZUG,
        UNVERZINSLICHER_VERZUG,
        VERZINSLICHER_VERZUG_BIS_31_DEZ,
        SONDERTILGUNG_MAXIMALBETRAG,
        SONDERTILGUNG_MINDESTBETRAG,
        LEISTUNGSSTOERUNGSBETRAG_SONDERTILGUNG,
        NICHT_PLANMAESSIGE_AENDERUNG_VERZINSUNGSSALDO,
        LEISTUNGSSTOERUNGSBETRAG_SONDERTILGUNG_WG_PROLONGATION,
        OWNSYNDICATEQUOTA,
        LOANSTATE,
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
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_FACILITY_IWHS_AZ6_EBA_CURRENT');
create table AMC.TABLE_FACILITY_IWHS_AZ6_EBA_CURRENT like CALC.VIEW_FACILITY_IWHS_AZ6_EBA distribute by hash (FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_IWHS_AZ6_EBA_CURRENT_FACILITY_ID on AMC.TABLE_FACILITY_IWHS_AZ6_EBA_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_FACILITY_IWHS_AZ6_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_FACILITY_IWHS_AZ6_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------



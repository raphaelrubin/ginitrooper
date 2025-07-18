-- View erstellen
drop view CALC.VIEW_FACILITY_LIQ_EBA;
create or replace view CALC.VIEW_FACILITY_LIQ_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
-- Quelldaten
LIQ_EBA as (
    select *, UPPER(SYSTEM_ID) = 'AVALOQ_LUX' as IS_LUX
    from NLB.LIQ_EBAGLOM_CURRENT
    where UPPER(AKTIV_PASSIV) = 'A'
      and CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
LIQ_PD as (
    select distinct CUTOFFDATE as CUT_OFF_DATE,
                    case
                        when LENGTH(RTRIM(TRANSLATE(FACILITY, '', ' 0123456789'))) = 0
                            -- Nur Zahlen da EBA.FACILITY_ID BIGINT ist
                            then CAST(FACILITY as BIGINT)
                        end    as FACILITY_ID,
                    DEAL
    from NLB.LIQ_PAST_DUE
    where CUTOFFDATE = (select CUT_OFF_DATE from COD)
),
-- Währungsumrechnung + SMAP
LOGIC as (
    select EBA.CUT_OFF_DATE,
           case
               when UPPER(EBA.GESCHAEFT_ART) = 'DAR_OUT_B'
                   then EBA.OUTSTANDING_EIGEN_ANTEIL_SAPFDB_ID
               else EBA.FACILITY_EIGEN_ANTEIL_SAPFDB_ID
               end                                                    as FACILITY_ID,
           case
               when UPPER(EBA.GESCHAEFT_ART) = 'DAR_OUT_B'
                   then EBA.FACILITY_EIGEN_ANTEIL_SAPFDB_ID
               end                                                    as PARENTFACILITY,
           case
               when IS_LUX
                   then LEFT(EBA.OUTSTANDING_ID_QUELLSYSTEM, INSTR(EBA.OUTSTANDING_ID_QUELLSYSTEM, '-') - 1)
               end                                                    as QUELLSYSTEM_ID_LUX,
           EBA.IS_LUX,
           PD.DEAl                                                    as DEAL_ID,
           EBA.GESCHAEFT_ART,
           EBA.KREDITNEHMER_GP_NR,
           EBA.KREDITNEHMER_GP_NAME,
           EBA.STATUS,
           EBA.AKTIV_PASSIV,
           EBA.SYSTEM_ID,
           case
               when WAEHRUNG is not null
                   then 'EUR'
               end                                                    as CURRENCY,
           EBA.WAEHRUNG                                               as CURRENCY_OC,
           EBA.AUSZAHLUNG_BEGINN_DATUM,
           EBA.AUSZAHLUNGSVERPFLICHTUNG_BTR * CM.RATE_TARGET_TO_EUR   as AUSZAHLUNGSVERPFLICHTUNG_BTR,
           EBA.EINSTANDSATZ_PRZ / 100                                 as EINSTANDSATZ_PRZ,
           EBA.FINANZIERUNG_VORHABEN,
           EBA.FINANZIERUNG_VORHABEN_BESCHREIBUNG,
           EBA.IOPC_ID,
           EBA.KREDITZUSAGE_ENDE_DATUM,
           EBA.PRODUKT_SCHLUESSEL,
           EBA.PRODUKT_SCHLUESSEL_BESCHREIBUNG,
           EBA.RESTKAPITAL_BTR_BRUTTO * CM.RATE_TARGET_TO_EUR         as RESTKAPITAL_BTR_BRUTTO,
           EBA.RESTKAPITAL_BTR_KONSORTEN * CM.RATE_TARGET_TO_EUR      as RESTKAPITAL_BTR_KONSORTEN,
           EBA.RESTKAPITAL_BTR_NETTO * CM.RATE_TARGET_TO_EUR          as RESTKAPITAL_BTR_NETTO,
           EBA.RUECKST_GEBUEHR_BTR * CM.RATE_TARGET_TO_EUR            as RUECKST_GEBUEHR_BTR,
           EBA.RUECKST_TILGUNG_BTR * CM.RATE_TARGET_TO_EUR            as RUECKST_TILGUNG_BTR,
           EBA.RUECKST_ZINSEN_BTR * CM.RATE_TARGET_TO_EUR             as RUECKST_ZINSEN_BTR,
           EBA.STUNDUNG_SALDO * CM.RATE_TARGET_TO_EUR                 as STUNDUNG_SALDO,
           SM.S_VALUE                                                 as TILGUNG_ART_MM,
           EBA.TILGUNG_ENDE_DATUM,
           EBA.URSPRUNGSKAPITAL_BTR_BRUTTO * CM.RATE_TARGET_TO_EUR    as URSPRUNGSKAPITAL_BTR_BRUTTO,
           EBA.URSPRUNGSKAPITAL_BTR_KONSORTEN * CM.RATE_TARGET_TO_EUR as URSPRUNGSKAPITAL_BTR_KONSORTEN,
           EBA.URSPRUNGSKAPITAL_BTR_NETTO * CM.RATE_TARGET_TO_EUR     as URSPRUNGSKAPITAL_BTR_NETTO,
           EBA.VERTRAG_ENDE_DATUM,
           EBA.VERZUG_BEGINN_DATUM,
           EBA.VERZUG_BTR_SUM * CM.RATE_TARGET_TO_EUR                 as VERZUG_BTR_SUM,
           EBA.ZINS_TYP,
           EBA.SUMME_VERZUGSTAGE,
           EBA.SOLL_ZINSSATZ / 100                                    as SOLL_ZINSSATZ,
           EBA.ZINSBINDUNG_ENDE_DATUM
    from LIQ_EBA EBA
             left join LIQ_PD PD on EBA.FACILITY_ID = PD.FACILITY_ID
             left join IMAP.CURRENCY_MAP CM on (EBA.CUT_OFF_DATE, EBA.WAEHRUNG) = (CM.CUT_OFF_DATE, CM.ZIEL_WHRG)
             left join SMAP.LIQ_TILGUNG_ART_MM SM on EBA.TILGUNG_ART_MM = SM.S_KEY
),
-- CBB/LUX-Spalten zuende berechnen
FINAL as (
    select CUT_OFF_DATE,
           FACILITY_ID,
           PARENTFACILITY,
           case
               when IS_LUX and LENGTH(RTRIM(TRANSLATE(QUELLSYSTEM_ID_LUX, '', ' 0123456789'))) = 0
                   -- Führende Nullen entfernen
                   then CAST(QUELLSYSTEM_ID_LUX as BIGINT)
               end as QUELLSYSTEM_ID_LUX,
           case
               when IS_LUX and LENGTH(RTRIM(TRANSLATE(QUELLSYSTEM_ID_LUX, '', ' 0123456789'))) = 0
                   -- Führende Nullen entfernen und +1, Präfix & Suffix anfügen
                   then CAST('K028-' || (CAST(QUELLSYSTEM_ID_LUX as BIGINT) + 1) || '_1020' as VARCHAR(500))
               end as FACILITY_ID_LUX,
           IS_LUX,
           DEAL_ID,
           KREDITNEHMER_GP_NR,
           KREDITNEHMER_GP_NAME,
           STATUS,
           CURRENCY,
           CURRENCY_OC,
           AUSZAHLUNG_BEGINN_DATUM,
           PRODUKT_SCHLUESSEL,
           PRODUKT_SCHLUESSEL_BESCHREIBUNG,
           IOPC_ID,
           FINANZIERUNG_VORHABEN,
           FINANZIERUNG_VORHABEN_BESCHREIBUNG,
           AUSZAHLUNGSVERPFLICHTUNG_BTR,
           KREDITZUSAGE_ENDE_DATUM,
           VERZUG_BEGINN_DATUM,
           SUMME_VERZUGSTAGE,
           VERZUG_BTR_SUM,
           RUECKST_GEBUEHR_BTR,
           RUECKST_TILGUNG_BTR,
           RUECKST_ZINSEN_BTR,
           EINSTANDSATZ_PRZ,
           STUNDUNG_SALDO,
           RESTKAPITAL_BTR_BRUTTO,
           RESTKAPITAL_BTR_NETTO,
           RESTKAPITAL_BTR_KONSORTEN,
           URSPRUNGSKAPITAL_BTR_BRUTTO,
           URSPRUNGSKAPITAL_BTR_NETTO,
           URSPRUNGSKAPITAL_BTR_KONSORTEN,
           TILGUNG_ART_MM,
           TILGUNG_ENDE_DATUM,
           ZINS_TYP,
           SOLL_ZINSSATZ,
           ZINSBINDUNG_ENDE_DATUM,
           VERTRAG_ENDE_DATUM
    from LOGIC
),
-- Gefiltert nach noetigen Datenfeldern + nullable
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        NULLIF(FACILITY_ID, null)                        as FACILITY_ID,
        NULLIF(PARENTFACILITY, null)                     as PARENTFACILITY,
        NULLIF(QUELLSYSTEM_ID_LUX, null)                 as QUELLSYSTEM_ID_LUX,
        NULLIF(FACILITY_ID_LUX, null)                    as FACILITY_ID_LUX,
        NULLIF(IS_LUX, null)                             as IS_LUX,
        NULLIF(DEAL_ID, null)                            as DEAL_ID,
        NULLIF(KREDITNEHMER_GP_NR, null)                 as KREDITNEHMER_GP_NR,
        NULLIF(KREDITNEHMER_GP_NAME, null)               as KREDITNEHMER_GP_NAME,
        NULLIF(STATUS, null)                             as STATUS,
        NULLIF(CURRENCY, null)                           as CURRENCY,
        NULLIF(CURRENCY_OC, null)                        as CURRENCY_OC,
        NULLIF(AUSZAHLUNG_BEGINN_DATUM, null)            as AUSZAHLUNG_BEGINN_DATUM,
        NULLIF(PRODUKT_SCHLUESSEL, null)                 as PRODUKT_SCHLUESSEL,
        NULLIF(PRODUKT_SCHLUESSEL_BESCHREIBUNG, null)    as PRODUKT_SCHLUESSEL_BESCHREIBUNG,
        NULLIF(IOPC_ID, null)                            as IOPC_ID,
        NULLIF(FINANZIERUNG_VORHABEN, null)              as FINANZIERUNG_VORHABEN,
        NULLIF(FINANZIERUNG_VORHABEN_BESCHREIBUNG, null) as FINANZIERUNG_VORHABEN_BESCHREIBUNG,
        NULLIF(AUSZAHLUNGSVERPFLICHTUNG_BTR, null)       as AUSZAHLUNGSVERPFLICHTUNG_BTR,
        NULLIF(KREDITZUSAGE_ENDE_DATUM, null)            as KREDITZUSAGE_ENDE_DATUM,
        NULLIF(VERZUG_BEGINN_DATUM, null)                as VERZUG_BEGINN_DATUM,
        NULLIF(SUMME_VERZUGSTAGE, null)                  as SUMME_VERZUGSTAGE,
        NULLIF(VERZUG_BTR_SUM, null)                     as VERZUG_BTR_SUM,
        NULLIF(RUECKST_GEBUEHR_BTR, null)                as RUECKST_GEBUEHR_BTR,
        NULLIF(RUECKST_TILGUNG_BTR, null)                as RUECKST_TILGUNG_BTR,
        NULLIF(RUECKST_ZINSEN_BTR, null)                 as RUECKST_ZINSEN_BTR,
        NULLIF(EINSTANDSATZ_PRZ, null)                   as EINSTANDSATZ_PRZ,
        NULLIF(STUNDUNG_SALDO, null)                     as STUNDUNG_SALDO,
        NULLIF(RESTKAPITAL_BTR_BRUTTO, null)             as RESTKAPITAL_BTR_BRUTTO,
        NULLIF(RESTKAPITAL_BTR_NETTO, null)              as RESTKAPITAL_BTR_NETTO,
        NULLIF(RESTKAPITAL_BTR_KONSORTEN, null)          as RESTKAPITAL_BTR_KONSORTEN,
        NULLIF(URSPRUNGSKAPITAL_BTR_BRUTTO, null)        as URSPRUNGSKAPITAL_BTR_BRUTTO,
        NULLIF(URSPRUNGSKAPITAL_BTR_NETTO, null)         as URSPRUNGSKAPITAL_BTR_NETTO,
        NULLIF(URSPRUNGSKAPITAL_BTR_KONSORTEN, null)     as URSPRUNGSKAPITAL_BTR_KONSORTEN,
        NULLIF(TILGUNG_ART_MM, null)                     as TILGUNG_ART_MM,
        NULLIF(TILGUNG_ENDE_DATUM, null)                 as TILGUNG_ENDE_DATUM,
        NULLIF(ZINS_TYP, null)                           as ZINS_TYP,
        NULLIF(SOLL_ZINSSATZ, null)                      as SOLL_ZINSSATZ,
        NULLIF(ZINSBINDUNG_ENDE_DATUM, null)             as ZINSBINDUNG_ENDE_DATUM,
        NULLIF(VERTRAG_ENDE_DATUM, null)                 as VERTRAG_ENDE_DATUM,
        -- Defaults
        CURRENT_USER                                     as USER,
        CURRENT_TIMESTAMP                                as TIMESTAMP_LOAD
    from FINAL
)
select *
from FINAL_FILTERED;

-- CI START FOR ALL TAPES

-- Current-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_FACILITY_LIQ_EBA_CURRENT');
create table AMC.TABLE_FACILITY_LIQ_EBA_CURRENT like CALC.VIEW_FACILITY_LIQ_EBA distribute by hash (FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_LIQ_EBA_CURRENT_FACILITY_ID on AMC.TABLE_FACILITY_LIQ_EBA_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_FACILITY_LIQ_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_FACILITY_LIQ_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------


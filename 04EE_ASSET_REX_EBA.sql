-- View erstellen
drop view CALC.VIEW_ASSET_REX_EBA;
create or replace view CALC.VIEW_ASSET_REX_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
---- Basisdaten ----
-- Filter nach an CMS mappbare Daten
BASIS_CMS as (
    select *
    from (select C.VO_ID,
                 B.*,
                 -- Selten gibt es mehrere VO_IDs für die selbe REXID, einfach größte nehmen
                 ROW_NUMBER() over (partition by C.VO_REX_NUMMER order by C.VO_ID desc) as RN1
          from NLB.CMS_VO_CURRENT C
                   -- inner join für Filter
                   inner join NLB.REX_BASISDATEN_CURRENT B on (C.CUTOFFDATE, C.VO_REX_NUMMER) = (B.CUT_OFF_DATE, B.STAMMNUMMER)
          where UPPER(STATUS) = 'GÜLTIG'
            and UPPER(C.VO_STATUS) = 'RECHTLICH AKTIV'
            and C.CUTOFFDATE = (select CUT_OFF_DATE from COD)
            and B.CUT_OFF_DATE = (select CUT_OFF_DATE from COD))
    where RN1 = 1
),
-- Neueste Version
BASIS_VERSION as (
    -- Basisdaten 1:n Version, nur neueste nehmen
    select *
    from (
             select *,
                    ROWNUMBER() over (PARTITION BY STAMMNUMMER ORDER BY VERSION desc nulls last) as RN2
             from BASIS_CMS
         )
    where RN2 = 1
),
-- Waehrungsumrechnung
BASIS_EUR as (
    select BSD.CUT_OFF_DATE,
           BSD.STAMMNUMMER,
           BSD.VERSION,
           BSD.CMS_IDENT_NR,
           BSD.STRASSE,
           BSD.HAUSNR,
           BSD.ERGAENZUNG,
           BSD.PLZ,
           BSD.ORT,
           BSD.LANDKREIS,
           BSD.BUNDESLAND,
           BSD.STAAT,
           BSD.AMTLICHER_GEMEINDESCHLUESSEL,
           BSD.ADRESSE_LAENGENGRAD,
           BSD.ADRESSE_BREITENGRAD,
           BSD.MAKROLAGE,
           BSD.MIKROLAGE,
           BSD.LAENGENMASS,
           BSD.VORLAEUFIGE_WERTE,
           BSD.WERTDARSTELLUNG_MARKTWERT * CM.RATE_TARGET_TO_EUR      as WERTDARSTELLUNG_MARKTWERT,
           BSD.WERTDARSTELLUNG_BELEIHUNGSWERT * CM.RATE_TARGET_TO_EUR as WERTDARSTELLUNG_BELEIHUNGSWERT,
           BSD.FESTGESETZTER_BELEIHUNGSWERT * CM.RATE_TARGET_TO_EUR   as FESTGESETZTER_BELEIHUNGSWERT,
           BSD.MARKTWERT_WNFL,
           BSD.BELEIHUNGSWERT_WNFL,
           BSD.MARKTWERT_MAKLERFAKTOR,
           BSD.BELEIHUNGSWERT_MAKLERFAKTOR,
           BSD.BODENWERT_GESAMT,
           BSD.BRUTTOANFANGSRENDITE_KUNDE,
           BSD.BRUTTOANFANGSRENDITE_REX,
           BSD.NETTOANFANGSRENDITE_KUNDE,
           BSD.NETTOANFANGSRENDITE_REX,
           BSD.NUTZUNG,
           BSD.VERMIETBARKEIT,
           BSD.VERWERTBARKEIT,
           BSD.BEWERTUNGSZUSTAND,
           BSD.OBJEKTART,
           BSD.ERBBAURECHT,
           BSD.ERBBAUZINS,
           BSD.ZUSTAND,
           BSD.GRAD_DER_FERTIGSTELLUNG / 100                          as GRAD_DER_FERTIGSTELLUNG, -- Prozent
           BSD.BAUJAHR,
           BSD.ZUSATZ_ZUM_BAUJAHR,
           BSD.FIKTIVES_BAUJAHR,
           BSD.SANIERUNGSJAHR,
           BSD.RENOVIERUNG,
           BSD.VOEB_IA_GESAMTNOTE,
           BSD.VOEB_IA_MARKTNOTE,
           BSD.VOEB_IA_STANDORTNOTE,
           BSD.VOEB_IA_OBJEKTNOTE,
           BSD.VOEB_IA_CASHFLOWNOTE,
           BSD.AUFTRAGSART,
           BSD.TERMINVORGABE,
           BSD.BESICHTIGUNGSDATUM,
           BSD.GUTACHTEN_ERSTELLT_AM,
           BSD.DATUM_KONTROLLE,
           BSD.RESTLAUFZEIT,
           BSD.POSTEINGANG,
           BSD.POSTAUSGANG,
           BSD.ANLASS_DER_BEWERTUNG,
           BSD.ERFASST_AM,
           BSD.AUFTRAGSGRUPPE,
           BSD.LORA_AUFTRAGSNUMMER,
           BSD.PARIS_OBJEKTNUMMER,
           BSD.REALKREDITFAEHIG,
           BSD.EIGENKAPITALENTLASTEND,
           BSD.STATUS,
           BSD.EMPFAENGERKOSTENSTELLE,
           BSD.DBE,
           BSD.BEARBEITER_MITARBEITERART,
           BSD.GUTACHTERBUERO,
           BSD.TIMESTAMP_LOAD,
           BSD.ETL_NR,
           BSD.QUELLE,
           BSD.BRANCH,
           BSD.USER,
           case
               when RC.CODE is not null
                   then 'EUR'
               end                                                    as CURRENCY,
           RC.CODE                                                    as CURRENCY_OC
    from BASIS_VERSION BSD
             -- Waehrung Text -> ISO-Code
             left join SMAP.REX_CURRENCY RC on BSD.WAEHRUNG = RC.WAEHRUNG_TXT
        -- Waehrungsumrechnung
             left join IMAP.CURRENCY_MAP CM on (BSD.CUT_OFF_DATE, RC.CODE) = (CM.CUT_OFF_DATE, CM.ZIEL_WHRG)
),
---- Bauteile ----
-- Filter nach an CMS mappbare Daten
BAUTL_CMS as (
    select C.VO_ID, B.*
    from NLB.CMS_VO_CURRENT C
             -- inner join für Filter
             inner join NLB.REX_BAUTEILE_CURRENT B on (C.CUTOFFDATE, C.VO_REX_NUMMER) = (B.CUT_OFF_DATE, B.STAMMNUMMER)
    where UPPER(STATUS) = 'GÜLTIG'
      and C.CUTOFFDATE = (select CUT_OFF_DATE from COD)
      and B.CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- Neueste Version
BAUTL_VERSION as (
    -- Bauteil m:n Version, alle Bauteile mit neuester Version nehmen
    select BAU.CUT_OFF_DATE,
           BAU.STAMMNUMMER,
           BAU.VERSION,
           BAU.CMS_IDENT_NR,
           BAU.BAUTEIL,
           BAU.NUTZUNG,
           BAU.FLAECHE,
           BAU.STUECK,
           BAU.MIETSITUATION,
           BAU.WAEHRUNG,
           BAU.TATSAECHLICHE_MIETE,
           BAU.TATSAECHLICHE_MIETE_PA,
           BAU.MARKTWERT_ANGESETZTE_MIETE,
           BAU.MARKTWERT_ANGESETZTE_MIETE_PA,
           BAU.ROHERTRAG_PA,
           BAU.BWK_PROZENT,
           BAU.REINERTRAG_PA,
           BAU.MARKTWERT_RND,
           BAU.LIEGENSCHAFTSZINS,
           BAU.ERTRAGSWERT_MARKTWERT,
           BAU.ERTRAG_EINHEIT_MARKTWERT,
           BAU.MIETE_KOPPLUNG_ANGESETZT,
           BAU.MIETE_BELEIHUNGSWERT_ANGESETZT,
           BAU.MIETE_BELEIHUNGSWERT_ANGESETZT_PA,
           BAU.ROHERTRAG_PA_BELEIHUNGSWERT,
           BAU.BWK_PROZENT_BELEIHUNGSWERT,
           BAU.REINERTRAG_PA_BELEIHUNGSWERT,
           BAU.RESTNUTZUNGSDAUER_KOPPLUNG,
           BAU.BELEIHUNGSWERT_RND,
           BAU.KAPITALISIERUNGSZINS,
           BAU.ERTRAGSWERT,
           BAU.ERTRAG_EINHEIT,
           BAU.POSTAUSGANG,
           BAU.STATUS,
           BAU.TIMESTAMP_LOAD,
           BAU.ETL_NR,
           BAU.QUELLE,
           BAU.BRANCH,
           BAU.USER
    from (
             select STAMMNUMMER, MAX(VERSION) as MAX_VERSION
             from BAUTL_CMS
             group by STAMMNUMMER
         ) MV
             left join BAUTL_CMS BAU on (BAU.STAMMNUMMER, BAU.VERSION) = (MV.STAMMNUMMER, MV.MAX_VERSION)
),
-- Waehrungsumrechnung
BAUTL_EUR as (
    select BAU.CUT_OFF_DATE,
           BAU.STAMMNUMMER,
           BAU.VERSION,
           BAU.CMS_IDENT_NR,
           BAU.BAUTEIL,
           BAU.NUTZUNG,
           BAU.FLAECHE,
           BAU.STUECK,
           BAU.MIETSITUATION,
           BAU.TATSAECHLICHE_MIETE,
           BAU.TATSAECHLICHE_MIETE_PA,
           BAU.MARKTWERT_ANGESETZTE_MIETE,
           BAU.MARKTWERT_ANGESETZTE_MIETE_PA,
           BAU.ROHERTRAG_PA * CM.RATE_TARGET_TO_EUR  as ROHERTRAG_PA,
           BAU.BWK_PROZENT,
           BAU.REINERTRAG_PA * CM.RATE_TARGET_TO_EUR as REINERTRAG_PA,
           BAU.MARKTWERT_RND,
           BAU.LIEGENSCHAFTSZINS,
           BAU.ERTRAGSWERT_MARKTWERT,
           BAU.ERTRAG_EINHEIT_MARKTWERT,
           BAU.MIETE_KOPPLUNG_ANGESETZT,
           BAU.MIETE_BELEIHUNGSWERT_ANGESETZT,
           BAU.MIETE_BELEIHUNGSWERT_ANGESETZT_PA,
           BAU.ROHERTRAG_PA_BELEIHUNGSWERT,
           BAU.BWK_PROZENT_BELEIHUNGSWERT,
           BAU.REINERTRAG_PA_BELEIHUNGSWERT,
           BAU.RESTNUTZUNGSDAUER_KOPPLUNG,
           BAU.BELEIHUNGSWERT_RND,
           BAU.KAPITALISIERUNGSZINS,
           BAU.ERTRAGSWERT,
           BAU.ERTRAG_EINHEIT,
           BAU.POSTAUSGANG,
           BAU.STATUS,
           BAU.TIMESTAMP_LOAD,
           BAU.ETL_NR,
           BAU.QUELLE,
           BAU.BRANCH,
           BAU.USER,
           case
               when BAU.WAEHRUNG is not null
                   then 'EUR'
               end                                   as CURRENCY,
           BAU.WAEHRUNG                              as CURRENCY_OC
    from BAUTL_VERSION BAU
             -- Waehrung Text -> ISO-Code
             inner join SMAP.REX_CURRENCY RC on BAU.WAEHRUNG = RC.WAEHRUNG_TXT
        -- Waehrungsumrechnung
             inner join IMAP.CURRENCY_MAP CM on (BAU.CUT_OFF_DATE, RC.CODE) = (CM.CUT_OFF_DATE, CM.ZIEL_WHRG)
),
-- Aggregation
BAUTL_AGG as (
    select BAU.CUT_OFF_DATE,
           BAU.STAMMNUMMER,
           BAU.VERSION,
           sum(BAU.ROHERTRAG_PA)  as ROHERTRAG_PA_SUM,
           sum(BAU.REINERTRAG_PA) as REINERTRAG_PA_SUM
    from BAUTL_EUR BAU
    group by BAU.CUT_OFF_DATE, BAU.STAMMNUMMER, BAU.VERSION
),
---- Basis + Bau ----
FINAL as (
    select
        -- BSD
        BSD.CUT_OFF_DATE,
        BSD.STAMMNUMMER,
        BSD.VERSION,
        BSD.CMS_IDENT_NR,
        BSD.STRASSE,
        BSD.HAUSNR,
        BSD.ERGAENZUNG,
        BSD.PLZ,
        BSD.ORT,
        BSD.LANDKREIS,
        BSD.BUNDESLAND,
        BSD.STAAT,
        BSD.AMTLICHER_GEMEINDESCHLUESSEL,
        BSD.ADRESSE_LAENGENGRAD,
        BSD.ADRESSE_BREITENGRAD,
        BSD.MAKROLAGE,
        BSD.MIKROLAGE,
        BSD.LAENGENMASS,
        BSD.VORLAEUFIGE_WERTE,
        BSD.WERTDARSTELLUNG_MARKTWERT,
        BSD.WERTDARSTELLUNG_BELEIHUNGSWERT,
        BSD.FESTGESETZTER_BELEIHUNGSWERT,
        BSD.MARKTWERT_WNFL,
        BSD.BELEIHUNGSWERT_WNFL,
        BSD.MARKTWERT_MAKLERFAKTOR,
        BSD.BELEIHUNGSWERT_MAKLERFAKTOR,
        BSD.BODENWERT_GESAMT,
        BSD.BRUTTOANFANGSRENDITE_KUNDE,
        BSD.BRUTTOANFANGSRENDITE_REX,
        BSD.NETTOANFANGSRENDITE_KUNDE,
        BSD.NETTOANFANGSRENDITE_REX,
        BSD.NUTZUNG,
        BSD.VERMIETBARKEIT,
        BSD.VERWERTBARKEIT,
        BSD.BEWERTUNGSZUSTAND,
        BSD.OBJEKTART,
        BSD.ERBBAURECHT,
        BSD.ERBBAUZINS,
        BSD.ZUSTAND,
        BSD.GRAD_DER_FERTIGSTELLUNG,
        BSD.BAUJAHR,
        BSD.ZUSATZ_ZUM_BAUJAHR,
        BSD.FIKTIVES_BAUJAHR,
        BSD.SANIERUNGSJAHR,
        BSD.RENOVIERUNG,
        BSD.VOEB_IA_GESAMTNOTE,
        BSD.VOEB_IA_MARKTNOTE,
        BSD.VOEB_IA_STANDORTNOTE,
        BSD.VOEB_IA_OBJEKTNOTE,
        BSD.VOEB_IA_CASHFLOWNOTE,
        BSD.AUFTRAGSART,
        BSD.TERMINVORGABE,
        BSD.BESICHTIGUNGSDATUM,
        BSD.GUTACHTEN_ERSTELLT_AM,
        BSD.DATUM_KONTROLLE,
        BSD.RESTLAUFZEIT,
        BSD.POSTEINGANG,
        BSD.POSTAUSGANG,
        BSD.ANLASS_DER_BEWERTUNG,
        BSD.ERFASST_AM,
        BSD.AUFTRAGSGRUPPE,
        BSD.LORA_AUFTRAGSNUMMER,
        BSD.PARIS_OBJEKTNUMMER,
        BSD.REALKREDITFAEHIG,
        BSD.EIGENKAPITALENTLASTEND,
        BSD.STATUS,
        BSD.EMPFAENGERKOSTENSTELLE,
        BSD.DBE,
        BSD.BEARBEITER_MITARBEITERART,
        BSD.GUTACHTERBUERO,
        BSD.TIMESTAMP_LOAD,
        BSD.ETL_NR,
        BSD.QUELLE,
        BSD.BRANCH,
        BSD.USER,
        BSD.CURRENCY,
        BSD.CURRENCY_OC,
        -- BAU
        BAU.BAUTEIL,
        BAU.FLAECHE,
        BAU.STUECK,
        BAU.MIETSITUATION,
        BAU.TATSAECHLICHE_MIETE,
        BAU.TATSAECHLICHE_MIETE_PA,
        BAU.MARKTWERT_ANGESETZTE_MIETE,
        BAU.MARKTWERT_ANGESETZTE_MIETE_PA,
        BAU.BWK_PROZENT,
        BAU.MARKTWERT_RND,
        BAU.LIEGENSCHAFTSZINS,
        BAU.ERTRAGSWERT_MARKTWERT,
        BAU.ERTRAG_EINHEIT_MARKTWERT,
        BAU.MIETE_KOPPLUNG_ANGESETZT,
        BAU.MIETE_BELEIHUNGSWERT_ANGESETZT,
        BAU.MIETE_BELEIHUNGSWERT_ANGESETZT_PA,
        BAU.ROHERTRAG_PA_BELEIHUNGSWERT,
        BAU.BWK_PROZENT_BELEIHUNGSWERT,
        BAU.REINERTRAG_PA_BELEIHUNGSWERT,
        BAU.RESTNUTZUNGSDAUER_KOPPLUNG,
        BAU.BELEIHUNGSWERT_RND,
        BAU.KAPITALISIERUNGSZINS,
        BAU.ERTRAGSWERT,
        BAU.ERTRAG_EINHEIT,
        -- BAG
        BAG.ROHERTRAG_PA_SUM,
        BAG.REINERTRAG_PA_SUM
    from BASIS_EUR BSD
             left join BAUTL_EUR BAU on (BSD.CUT_OFF_DATE, BSD.STAMMNUMMER, BSD.VERSION) = (BAU.CUT_OFF_DATE, BAU.STAMMNUMMER, BAU.VERSION)
             left join BAUTL_AGG BAG on (BSD.CUT_OFF_DATE, BSD.STAMMNUMMER, BSD.VERSION) = (BAG.CUT_OFF_DATE, BAG.STAMMNUMMER, BAG.VERSION)
),
-- Duplikate entfernen
FINAL_DUP as (
    -- Stammnummer im Ergebnis eindeutig da Bauteile aggregiert
    select *
    from (
             select *,
                    ROWNUMBER() over (PARTITION BY STAMMNUMMER) as RN
             from FINAL
         )
    where RN = 1
),
-- Gefiltert nach noetigen Datenfeldern
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        STAMMNUMMER,
        VERSION,
        CMS_IDENT_NR,
        CURRENCY,
        CURRENCY_OC,
        PLZ,
        STAAT,
        MAKROLAGE,
        MIKROLAGE,
        WERTDARSTELLUNG_MARKTWERT,
        WERTDARSTELLUNG_BELEIHUNGSWERT,
        FESTGESETZTER_BELEIHUNGSWERT,
        REINERTRAG_PA_SUM,
        ROHERTRAG_PA_SUM,
        NUTZUNG,
        OBJEKTART,
        ZUSTAND,
        GRAD_DER_FERTIGSTELLUNG,
        BAUJAHR,
        VOEB_IA_OBJEKTNOTE,
        AUFTRAGSART,
        BESICHTIGUNGSDATUM,
        GUTACHTEN_ERSTELLT_AM,
        -- Defaults
        CURRENT_USER      as USER,
        CURRENT_TIMESTAMP as TIMESTAMP_LOAD
    from FINAL_DUP
)
select *
from FINAL_FILTERED;

-- CI START FOR ALL TAPES

-- Current-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_ASSET_REX_EBA_CURRENT');
create table AMC.TABLE_ASSET_REX_EBA_CURRENT like CALC.VIEW_ASSET_REX_EBA distribute by hash (STAMMNUMMER) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_ASSET_REX_EBA_CURRENT_STAMMNUMMER on AMC.TABLE_ASSET_REX_EBA_CURRENT (STAMMNUMMER);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_ASSET_REX_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_ASSET_REX_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------



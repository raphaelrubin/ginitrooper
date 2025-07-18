-- View erstellen
drop view CALC.VIEW_CLIENT_IWHS_KREDIT_EBA;
-- Satellitentabelle Customer EBA
create or replace view CALC.VIEW_CLIENT_IWHS_KREDIT_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
-- Quelldaten
KREDIT as (
    select *,
           'NLB_' || KUNDENNUMMER as GNI_KUNDE
    from NLB.IWHS_KREDIT_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- Alles zusammenführen
MAPPED as (
    select CUT_OFF_DATE,
           GNI_KUNDE                          as IWHS_GNI_KUNDE,
           ART_DER_EINNAHME                   as IWHS_ART_DER_EINNAHME,
           WERT_DER_EINNAHME                  as IWHS_WERT_DER_EINNAHME,
           WAEHRUNG_DER_EINNAHME              as IWHS_WAEHRUNG_DER_EINNAHME,
           ERMITTL_DER_EINNAHME               as IWHS_ERMITTL_DER_EINNAHME,
           ANZAHL_DER_ZAHLUNGEN_P_A_EINNAHME  as IWHS_ANZAHL_DER_ZAHLUNGEN_P_A_EINNAHME,
           EINNAHME_VON                       as IWHS_EINNAHME_VON,
           EINNAHME_BIS                       as IWHS_EINNAHME_BIS,
           HERKUNFT_EINNAHME                  as IWHS_HERKUNFT_EINNAHME,
           VEREINBARUNGS_KONTONUMMER_EINNAHME as IWHS_VEREINBARUNGS_KONTONUMMER_EINNAHME,
           INSTITUT_EINNAHME                  as IWHS_INSTITUT_EINNAHME,
           BEMERKUNG_EINNAHME                 as IWHS_BEMERKUNG_EINNAHME,
           ART_DER_AUSGABE                    as IWHS_ART_DER_AUSGABE,
           WERT_DER_AUSGABE                   as IWHS_WERT_DER_AUSGABE,
           WAEHRUNG_DER_AUSGABE               as IWHS_WAEHRUNG_DER_AUSGABE,
           ERMITTL_DER_AUSGABE                as IWHS_ERMITTL_DER_AUSGABE,
           ANZAHL_DER_ZAHLUNGEN_P_A_AUSGABE   as IWHS_ANZAHL_DER_ZAHLUNGEN_P_A_AUSGABE,
           AUSGABE_VON                        as IWHS_AUSGABE_VON,
           AUSGABE_BIS                        as IWHS_AUSGABE_BIS,
           HERKUNFT_AUSGABE                   as IWHS_HERKUNFT_AUSGABE,
           VEREINBARUNGS_KONTONUMMER_AUSGABE  as IWHS_VEREINBARUNGS_KONTONUMMER_AUSGABE,
           INSTITUT_AUSGABE                   as IWHS_INSTITUT_AUSGABE,
           BEMERKUNG_AUSGABE                  as IWHS_BEMERKUNG_AUSGABE,
           GEPRUEFT_DURCH_BERATER             as IWHS_GEPRUEFT_DURCH_BERATER,
           ARBEITGEBER                        as IWHS_ARBEITGEBER,
           BESCHAEFTIGT_SEIT                  as IWHS_BESCHAEFTIGT_SEIT,
           KRANKENKASSE                       as IWHS_KRANKENKASSE,
           MITGLIEDSNUMMER                    as IWHS_MITGLIEDSNUMMER,
           ARBEITSERLAUBNIS_BIS               as IWHS_ARBEITSERLAUBNIS_BIS,
           BEMERKUNGEN                        as IWHS_BEMERKUNGEN,
           LOHNABTRETUNG_AM                   as IWHS_LOHNABTRETUNG_AM,
           BESTAETIGUNG_DES_ARBEITG_AM        as IWHS_BESTAETIGUNG_DES_ARBEITG_AM,
           PERSONENNUMMER                     as IWHS_PERSONENNUMMER,
           SM.KURZBESCHREIBUNG                as IWHS_WIRTSCHAFTSZWEIG_ARBEITGEBER,
           PERSONALNUMMER                     as IWHS_PERSONALNUMMER,
           ABTEILUNG                          as IWHS_ABTEILUNG,
           EINBRINGUNG_EIGENKAPITAL           as IWHS_EINBRINGUNG_EIGENKAPITAL,
           GEHALTSKONTO                       as IWHS_GEHALTSKONTO,
           WAEHRUNG_EINKOMMEN                 as IWHS_WAEHRUNG_EINKOMMEN,
           DURCHSCHNITTSEINKOMMEN             as IWHS_DURCHSCHNITTSEINKOMMEN,
           A_E_GRUPPE                         as IWHS_A_E_GRUPPE,
           EINKOMMEN_JANUAR                   as IWHS_EINKOMMEN_JANUAR,
           EINKOMMEN_FEBRUAR                  as IWHS_EINKOMMEN_FEBRUAR,
           EINKOMMEN_MAERZ                    as IWHS_EINKOMMEN_MAERZ,
           EINKOMMEN_APRIL                    as IWHS_EINKOMMEN_APRIL,
           EINKOMMEN_MAI                      as IWHS_EINKOMMEN_MAI,
           EINKOMMEN_JUNI                     as IWHS_EINKOMMEN_JUNI,
           EINKOMMEN_JULI                     as IWHS_EINKOMMEN_JULI,
           EINKOMMEN_AUGUST                   as IWHS_EINKOMMEN_AUGUST,
           EINKOMMEN_SEPTEMBER                as IWHS_EINKOMMEN_SEPTEMBER,
           EINKOMMEN_OKTOBER                  as IWHS_EINKOMMEN_OKTOBER,
           EINKOMMEN_NOVEMBER                 as IWHS_EINKOMMEN_NOVEMBER,
           EINKOMMEN_DEZEMBER                 as IWHS_EINKOMMEN_DEZEMBER,
           RISIKO_FINANZIERUNG                as IWHS_RISIKO_FINANZIERUNG,
           RISIKO_FORDERUNGSAUSFALL           as IWHS_RISIKO_FORDERUNGSAUSFALL
    from KREDIT K
             left join SMAP.IWHS_WIRTSCHAFTS_ZWEIG SM on SM.S_KEY = K.WIRTSCHAFTSZWEIG_ARBEITGEBER
),
---- Filter auf CUSTOMER_EBA mit Vermeidung zyklischer Abhängigkeiten
PWC_CUST as (
    select distinct CLIENT_ID_TXT as GNI_KUNDE
    from CALC.SWITCH_CLIENT_ACCOUNTHOLDER_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- Einschränken auf CUSTOMER_EBA
FINAL as (
    select A.*
    from MAPPED A
             inner join PWC_CUST PWC on PWC.GNI_KUNDE = A.IWHS_GNI_KUNDE
),
-- Gefiltert nach noetigen Datenfeldern
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        IWHS_GNI_KUNDE,
        IWHS_ART_DER_EINNAHME,
        IWHS_WERT_DER_EINNAHME,
        IWHS_WAEHRUNG_DER_EINNAHME,
        IWHS_ERMITTL_DER_EINNAHME,
        IWHS_ANZAHL_DER_ZAHLUNGEN_P_A_EINNAHME,
        IWHS_EINNAHME_VON,
        IWHS_EINNAHME_BIS,
        IWHS_HERKUNFT_EINNAHME,
        IWHS_VEREINBARUNGS_KONTONUMMER_EINNAHME,
        IWHS_INSTITUT_EINNAHME,
        IWHS_BEMERKUNG_EINNAHME,
        IWHS_ART_DER_AUSGABE,
        IWHS_WERT_DER_AUSGABE,
        IWHS_WAEHRUNG_DER_AUSGABE,
        IWHS_ERMITTL_DER_AUSGABE,
        IWHS_ANZAHL_DER_ZAHLUNGEN_P_A_AUSGABE,
        IWHS_AUSGABE_VON,
        IWHS_AUSGABE_BIS,
        IWHS_HERKUNFT_AUSGABE,
        IWHS_VEREINBARUNGS_KONTONUMMER_AUSGABE,
        IWHS_INSTITUT_AUSGABE,
        IWHS_BEMERKUNG_AUSGABE,
        IWHS_GEPRUEFT_DURCH_BERATER,
        IWHS_ARBEITGEBER,
        IWHS_BESCHAEFTIGT_SEIT,
        IWHS_KRANKENKASSE,
        IWHS_MITGLIEDSNUMMER,
        IWHS_ARBEITSERLAUBNIS_BIS,
        IWHS_BEMERKUNGEN,
        IWHS_LOHNABTRETUNG_AM,
        IWHS_BESTAETIGUNG_DES_ARBEITG_AM,
        IWHS_PERSONENNUMMER,
        IWHS_WIRTSCHAFTSZWEIG_ARBEITGEBER,
        IWHS_PERSONALNUMMER,
        IWHS_ABTEILUNG,
        IWHS_EINBRINGUNG_EIGENKAPITAL,
        IWHS_GEHALTSKONTO,
        IWHS_WAEHRUNG_EINKOMMEN,
        IWHS_DURCHSCHNITTSEINKOMMEN,
        IWHS_A_E_GRUPPE,
        IWHS_EINKOMMEN_JANUAR,
        IWHS_EINKOMMEN_FEBRUAR,
        IWHS_EINKOMMEN_MAERZ,
        IWHS_EINKOMMEN_APRIL,
        IWHS_EINKOMMEN_MAI,
        IWHS_EINKOMMEN_JUNI,
        IWHS_EINKOMMEN_JULI,
        IWHS_EINKOMMEN_AUGUST,
        IWHS_EINKOMMEN_SEPTEMBER,
        IWHS_EINKOMMEN_OKTOBER,
        IWHS_EINKOMMEN_NOVEMBER,
        IWHS_EINKOMMEN_DEZEMBER,
        IWHS_RISIKO_FINANZIERUNG,
        IWHS_RISIKO_FORDERUNGSAUSFALL,
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
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_CLIENT_IWHS_KREDIT_EBA_CURRENT');
create table AMC.TABLE_CLIENT_IWHS_KREDIT_EBA_CURRENT like CALC.VIEW_CLIENT_IWHS_KREDIT_EBA distribute by hash (IWHS_GNI_KUNDE) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CLIENT_IWHS_KREDIT_EBA_CURRENT_IWHS_GNI_KUNDE on AMC.TABLE_CLIENT_IWHS_KREDIT_EBA_CURRENT (IWHS_GNI_KUNDE);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_CLIENT_IWHS_KREDIT_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- Archiv-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_CLIENT_IWHS_KREDIT_EBA_ARCHIVE');
create table AMC.TABLE_CLIENT_IWHS_KREDIT_EBA_ARCHIVE like CALC.VIEW_CLIENT_IWHS_KREDIT_EBA distribute by hash (IWHS_GNI_KUNDE) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CLIENT_IWHS_KREDIT_EBA_ARCHIVE_IWHS_GNI_KUNDE on AMC.TABLE_CLIENT_IWHS_KREDIT_EBA_ARCHIVE (IWHS_GNI_KUNDE);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_CLIENT_IWHS_KREDIT_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_CLIENT_IWHS_KREDIT_EBA_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_CLIENT_IWHS_KREDIT_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------


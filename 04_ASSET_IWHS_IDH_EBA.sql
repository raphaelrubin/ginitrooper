-- View erstellen
drop view CALC.VIEW_ASSET_IWHS_IDH_EBA;
-- Satellitentabelle Asset EBA
create or replace view CALC.VIEW_ASSET_IWHS_IDH_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
-- Quelldaten
IDH as (
    select *
    from NLB.IWHS_IDH_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- Alles zusammenführen
MAPPED as (
    select CUT_OFF_DATE,
           VORGANGS_NR                                                                     as IDH_VORGANGS_NR,
           VORGANGS_BEZEICHNUNG                                                            as IDH_VORGANGS_BEZEICHNUNG,
           FACILITY_ID                                                                     as IDH_FACILITY_ID,
           FACILITY_SAP_ID                                                                 as IDH_FACILITY_SAP_ID,
           KONTO_PRODUKT                                                                   as IDH_KONTO_PRODUKT,
           DARLEHENSBEWILLIGUNG_AM                                                         as IDH_DARLEHENSBEWILLIGUNG_AM,
           VMGO_PERSONEN_NR                                                                as IDH_VMGO_PERSONEN_NR,
           VMGO_BESITZER_NAME                                                              as IDH_VMGO_BESITZER_NAME,
           SICHERUNGSRECHT                                                                 as IDH_SICHERUNGSRECHT,
           RANG_DER_BELASTUNG_EINES_SICHERUNGSRECHTES_AN_EINEM_VERMOEGENSOBJEKT            as IDH_RANG_BELASTUNG_SICHERUNGSRECHTES_AN_VO,
           STRASSE_KUNDE                                                                   as IDH_STRASSE_KUNDE,
           HAUSNUMMER                                                                      as IDH_HAUSNUMMER,
           PLZ                                                                             as IDH_PLZ,
           ORT                                                                             as IDH_ORT,
           KREDITNEHMER_PERSONEN_NR                                                        as IDH_KREDITNEHMER_PERSONEN_NR,
           KREDITNEHMER_NAME                                                               as IDH_KREDITNEHMER_NAME,
           SM.KURZBESCHREIBUNG                                                             as IDH_WIRTSCHAFTSZWEIG,
           VERMOEGENSOBJEKT_NR                                                             as IDH_ASSET_ID,
           VERMOEGENSOBJEKT_ART                                                            as IDH_VERMOEGENSOBJEKT_ART,
           BELEIHUNGSWERT                                                                  as IDH_BELEIHUNGSWERT,
           BELEIHUNGSWERT_FESTSETZUNGDATUM                                                 as IDH_BELEIHUNGSWERT_FESTSETZUNGDATUM,
           MARKTWERT                                                                       as IDH_MARKTWERT,
           MARKTWERT_VOM                                                                   as IDH_MARKTWERT_VOM,
           BELEIHUNGSWERT_VORTAXE                                                          as IDH_BELEIHUNGSWERT_VORTAXE,
           BELEIHUNGSWERT_VORTAXE_VOM                                                      as IDH_BELEIHUNGSWERT_VORTAXE_VOM,
           VERKEHSWERT_VORTAXE                                                             as IDH_VERKEHSWERT_VORTAXE,
           VERKEHSWERT_VORTAXE_VOM                                                         as IDH_VERKEHSWERT_VORTAXE_VOM,
           BELASTUNGS_FORDERUNGSBETRAG_DES_ABGESICHERTEN_RECHTES_AN_EINEM_VERMOEGENSOBJEKT as IDH_BLST_FORD_BTRG,
           BEWILLIGUNGSSTATUS                                                              as IDH_BEWILLIGUNGSSTATUS,
           VORGANGSART                                                                     as IDH_VORGANGSART
    from IDH
             left join SMAP.IWHS_WIRTSCHAFTS_ZWEIG SM on IDH.WIRTSCHAFTSZWEIG = SM.S_KEY
),
---- Filter auf ASSET_EBA mit Vermeidung zyklischer Abhängigkeiten
PWC_ASSET as (
    select distinct ASSET_ID
    from CALC.SWITCH_ASSET_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
      and SOURCE = 'IWHS'
),
-- Einschränken auf ASSET_EBA
FINAL as (
    select M.*
    from MAPPED M
             inner join PWC_ASSET PWC on PWC.ASSET_ID = M.IDH_ASSET_ID
),
-- Gefiltert nach noetigen Datenfeldern
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        IDH_VORGANGS_NR,
        IDH_VORGANGS_BEZEICHNUNG,
        IDH_FACILITY_ID,
        IDH_KONTO_PRODUKT,
        IDH_DARLEHENSBEWILLIGUNG_AM,
        IDH_VMGO_PERSONEN_NR,
        IDH_VMGO_BESITZER_NAME,
        IDH_SICHERUNGSRECHT,
        IDH_RANG_BELASTUNG_SICHERUNGSRECHTES_AN_VO,
        IDH_STRASSE_KUNDE,
        IDH_HAUSNUMMER,
        IDH_PLZ,
        IDH_ORT,
        IDH_KREDITNEHMER_PERSONEN_NR,
        IDH_KREDITNEHMER_NAME,
        IDH_WIRTSCHAFTSZWEIG,
        IDH_ASSET_ID,
        IDH_VERMOEGENSOBJEKT_ART,
        IDH_BELEIHUNGSWERT,
        IDH_BELEIHUNGSWERT_FESTSETZUNGDATUM,
        IDH_MARKTWERT,
        IDH_MARKTWERT_VOM,
        IDH_BELEIHUNGSWERT_VORTAXE,
        IDH_BELEIHUNGSWERT_VORTAXE_VOM,
        IDH_VERKEHSWERT_VORTAXE,
        IDH_VERKEHSWERT_VORTAXE_VOM,
        IDH_BLST_FORD_BTRG,
        IDH_BEWILLIGUNGSSTATUS,
        IDH_VORGANGSART,
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
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_ASSET_IWHS_IDH_EBA_CURRENT');
create table AMC.TABLE_ASSET_IWHS_IDH_EBA_CURRENT like CALC.VIEW_ASSET_IWHS_IDH_EBA distribute by hash (IDH_FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_ASSET_IWHS_IDH_EBA_CURRENT_IDH_FACILITY_ID on AMC.TABLE_ASSET_IWHS_IDH_EBA_CURRENT (IDH_FACILITY_ID);
create index AMC.INDEX_ASSET_IWHS_IDH_EBA_CURRENT_IDH_ASSET_ID on AMC.TABLE_ASSET_IWHS_IDH_EBA_CURRENT (IDH_ASSET_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_ASSET_IWHS_IDH_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- Archiv-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_ASSET_IWHS_IDH_EBA_ARCHIVE');
create table AMC.TABLE_ASSET_IWHS_IDH_EBA_ARCHIVE like CALC.VIEW_ASSET_IWHS_IDH_EBA distribute by hash (IDH_FACILITY_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_ASSET_IWHS_IDH_EBA_ARCHIVE_IDH_FACILITY_ID on AMC.TABLE_ASSET_IWHS_IDH_EBA_ARCHIVE (IDH_FACILITY_ID);
create index AMC.INDEX_ASSET_IWHS_IDH_EBA_ARCHIVE_IDH_ASSET_ID on AMC.TABLE_ASSET_IWHS_IDH_EBA_ARCHIVE (IDH_ASSET_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_ASSET_IWHS_IDH_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_ASSET_IWHS_IDH_EBA_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_ASSET_IWHS_IDH_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------


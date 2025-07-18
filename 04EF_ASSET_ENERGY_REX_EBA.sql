-- View erstellen
drop view CALC.VIEW_ASSET_ENERGY_REX_EBA;
-- Satellitentabelle Asset EBA
create or replace view CALC.VIEW_ASSET_ENERGY_REX_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
---- Energie-Eigenschaften
-- Filter nach an Basisdaten mappbare Daten
ENRGY_CMS as (
    select E.*
    from CALC.SWITCH_ASSET_REX_EBA_CURRENT B
             -- inner join für Filter
             inner join NLB.REX_ENERG_EIGENSCHAFTEN_CURRENT E
                        on (B.CUT_OFF_DATE, B.STAMMNUMMER, B.VERSION) = (E.CUT_OFF_DATE, E.STAMMNUMMER, E.VERSION)
    where UPPER(E.STATUS) = 'GÜLTIG'
      and B.CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
      and E.CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- Neueste Version
ENRGY_VERSION as (
    -- Energie m:n Version, alle Energie-Eigenschaften mit neuester Version nehmen
    select E.CUT_OFF_DATE,
           E.STAMMNUMMER,
           E.VERSION,
           E.CMS_IDENT_NR,
           E.BAUTEIL,
           E.FUEHRENDES_BAUTEIL,
           E.GEBAEUDENUTZFLAECHE,
           E.NETTOGRUNDFLAECHE,
           E.BODENVERSIEGELUNG,
           E.OEPNV_HALTESTELLE,
           E.ENERGIEEFFIZIENZKLASSE,
           E.ENERGIEEFFIZIENZKLASSE_MANUELL,
           E.ENERGIEKENNWERT,
           E.ENERGIEEINHEIT,
           E.ENDENERGIEBEDARF_ENDENERGIEVERBRAUCH,
           E.WAERME,
           E.STROM,
           E.PRIMAERENERGIEBEDARF_PRIMAERENERGIEVERBRAUCH,
           E.DATEN_NACHHALTIGKEIT,
           E.AUSGESTELLT_AM_ENERGIEAUSWEIS,
           E.GUELTIG_BIS_ENERGIEAUSWEIS,
           E.ZERTIFIZIERER,
           E.AUSPRAEGUNG,
           E.AUSGESTELLT_AM_SONSTIGES_ZERTIFIKAT,
           E.GUELTIG_BIS_SONSTIGES_ZERTIFIKAT,
           E.CO2_EMISSIONEN,
           E.AUFTRAGSGRUPPE,
           E.STATUS,
           E.POSTAUSGANG,
           E.AUFTRAGSART,
           E.TIMESTAMP_LOAD,
           E.ETL_NR,
           E.QUELLE,
           E.BRANCH,
           E.USER
    from (
             select STAMMNUMMER, MAX(VERSION) as MAX_VERSION
             from ENRGY_CMS
             group by STAMMNUMMER
         ) MV
             left join ENRGY_CMS E
                       on (E.STAMMNUMMER, E.VERSION) = (MV.STAMMNUMMER, MV.MAX_VERSION)
),
-- Energieeinheiten umrechnen
ENRGY_UNIT as (
    select E.CUT_OFF_DATE,
           E.STAMMNUMMER                         as REX_REXID,
           E.VERSION                             as REX_VERSION,
           E.CMS_IDENT_NR                        as REX_CMS_IDENT_NR,
           E.BAUTEIL                             as REX_BAUTEIL,
           E.FUEHRENDES_BAUTEIL                  as REX_FUEHRENDES_BAUTEIL,
           E.GEBAEUDENUTZFLAECHE                 as REX_ZEBRA_LEADING_GEBAEUDENUTZFLAECHE,
           E.NETTOGRUNDFLAECHE                   as REX_ZEBRA_LEADING_NETTOGRUNDFLAECHE,
           E.BODENVERSIEGELUNG                   as REX_ZEBRA_LEADING_BODENVERSIEGELUNG,
           E.OEPNV_HALTESTELLE                   as REX_ZEBRA_LEADING_OEPNV_HALTESTELLE,
           E.ENERGIEEFFIZIENZKLASSE              as REX_ZEBRA_LEADING_ENERGIEEFFIZIENZKLASSE,
           E.ENERGIEEFFIZIENZKLASSE_MANUELL      as REX_ZEBRA_LEADING_ENERGIEEFFIZIENZKLASSE_MANUELL,
           E.ENERGIEKENNWERT                     as REX_ZEBRA_LEADING_ENERGIEKENNWERT,
           case
               when UPPER(E.ENERGIEEINHEIT) in ('KILOWATTSTUNDEN', 'KW_H')
                   then E.ENDENERGIEBEDARF_ENDENERGIEVERBRAUCH
               when UPPER(E.ENERGIEEINHEIT) in ('MEGAJOULE', 'MJ')
                   then E.ENDENERGIEBEDARF_ENDENERGIEVERBRAUCH / 3.6
               else E.ENDENERGIEBEDARF_ENDENERGIEVERBRAUCH
               end
                                                 as REX_ZEBRA_LEADING_ENDENERGIEBEDARF_ENDENERGIEVERBRAUCH,
           E.WAERME                              as REX_ZEBRA_LEADING_WAERME,
           E.STROM                               as REX_ZEBRA_LEADING_STROM,
           case
               when UPPER(E.ENERGIEEINHEIT) in ('KILOWATTSTUNDEN', 'KW_H')
                   then E.PRIMAERENERGIEBEDARF_PRIMAERENERGIEVERBRAUCH
               when UPPER(E.ENERGIEEINHEIT) in ('MEGAJOULE', 'MJ')
                   then E.PRIMAERENERGIEBEDARF_PRIMAERENERGIEVERBRAUCH / 3.6
               else E.PRIMAERENERGIEBEDARF_PRIMAERENERGIEVERBRAUCH
               end
                                                 as REX_ZEBRA_LEADING_PRIMAERENERGIEBEDARF_PRIMAERENERGIEVERBRAUCH,
           E.DATEN_NACHHALTIGKEIT                as REX_ZEBRA_LEADING_DATEN_NACHHALTIGKEIT,
           E.AUSGESTELLT_AM_ENERGIEAUSWEIS       as REX_ZEBRA_LEADING_AUSGESTELLT_AM_ENERGIEAUSWEIS,
           E.GUELTIG_BIS_ENERGIEAUSWEIS          as REX_ZEBRA_LEADING_GUELTIG_BIS_ENERGIEAUSWEIS,
           E.ZERTIFIZIERER                       as REX_ZEBRA_LEADING_ZERTIFIZIERER,
           E.AUSPRAEGUNG                         as REX_ZEBRA_LEADING_AUSPRAEGUNG,
           E.AUSGESTELLT_AM_SONSTIGES_ZERTIFIKAT as REX_ZEBRA_LEADING_AUSGESTELLT_AM_SONSTIGES_ZERTIFIKAT,
           E.GUELTIG_BIS_SONSTIGES_ZERTIFIKAT    as REX_ZEBRA_LEADING_GUELTIG_BIS_SONSTIGES_ZERTIFIKAT,
           E.CO2_EMISSIONEN                      as REX_ZEBRA_LEADING_CO2_EMISSIONEN,
           E.AUFTRAGSGRUPPE                      as REX_ZEBRA_LEADING_AUFTRAGSGRUPPE,
           E.STATUS                              as REX_ZEBRA_LEADING_STATUS,
           E.POSTAUSGANG                         as REX_ZEBRA_LEADING_POSTAUSGANG,
           E.AUFTRAGSART                         as REX_ZEBRA_LEADING_AUFTRAGSART,
           case
               when E.PRIMAERENERGIEBEDARF_PRIMAERENERGIEVERBRAUCH is not null
                   or E.ENDENERGIEBEDARF_ENDENERGIEVERBRAUCH is not null
                   then case
                            when E.ENERGIEEINHEIT is null or UPPER(E.ENERGIEEINHEIT) not in ('KILOWATTSTUNDEN', 'KW_H', 'MEGAJOULE', 'MJ')
                                then 'UNBEKANNT'
                            else 'Kilowattstunden'
                   end
               end                               as REX_ZEBRA_LEADING_ENERGIEEINHEIT,
           E.ENERGIEEINHEIT                      as REX_ZEBRA_LEADING_ENERGIEEINHEIT_OC
    from ENRGY_VERSION E
),
---- Filter auf ASSET_EBA mit Vermeidung zyklischer Abhängigkeiten
PWC_ASSET as (
    select *
    from CALC.SWITCH_ASSET_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
CMS_ASSET as (
    select *
    from CALC.SWITCH_ASSET_CMS_EBA_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- Alle VO_REX_NUMMERn aus ASSET_EBA
ASSET_EBA as (
    select distinct VO_REX_NUMMER
    from PWC_ASSET PWC
             left join CMS_ASSET CMS on PWC.SOURCE = 'CMS' and PWC.ASSET_ID = CMS.ASSET_ID
),
-- Einschränken auf ASSET_EBA
FINAL as (
    select EU.*
    from ENRGY_UNIT EU
             inner join ASSET_EBA ASSET on ASSET.VO_REX_NUMMER = EU.REX_REXID
),
-- Gefiltert nach noetigen Datenfeldern
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        REX_REXID,
        REX_VERSION,
        REX_BAUTEIL,
        REX_ZEBRA_LEADING_OEPNV_HALTESTELLE,
        REX_ZEBRA_LEADING_ENERGIEEFFIZIENZKLASSE,
        REX_ZEBRA_LEADING_ENERGIEEFFIZIENZKLASSE_MANUELL,
        REX_ZEBRA_LEADING_ENERGIEKENNWERT,
        REX_ZEBRA_LEADING_ENERGIEEINHEIT_OC,
        REX_ZEBRA_LEADING_ENERGIEEINHEIT,
        REX_ZEBRA_LEADING_ENDENERGIEBEDARF_ENDENERGIEVERBRAUCH,
        REX_ZEBRA_LEADING_PRIMAERENERGIEBEDARF_PRIMAERENERGIEVERBRAUCH,
        REX_ZEBRA_LEADING_AUSGESTELLT_AM_ENERGIEAUSWEIS,
        REX_ZEBRA_LEADING_GUELTIG_BIS_ENERGIEAUSWEIS,
        REX_ZEBRA_LEADING_CO2_EMISSIONEN,
        REX_ZEBRA_LEADING_AUFTRAGSART,
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
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_ASSET_ENERGY_REX_EBA_CURRENT');
create table AMC.TABLE_ASSET_ENERGY_REX_EBA_CURRENT like CALC.VIEW_ASSET_ENERGY_REX_EBA distribute by hash (REX_REXID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_ASSET_ENERGY_REX_EBA_CURRENT_REX_REXID on AMC.TABLE_ASSET_ENERGY_REX_EBA_CURRENT (REX_REXID);
comment on table AMC.TABLE_ASSET_ENERGY_REX_EBA_CURRENT is 'Liste der Energie-Eigenschaften, welche zu einem Asset gehören (Aktueller Stichtag)';
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_ASSET_ENERGY_REX_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- Archiv-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_ASSET_ENERGY_REX_EBA_ARCHIVE');
create table AMC.TABLE_ASSET_ENERGY_REX_EBA_ARCHIVE like CALC.VIEW_ASSET_ENERGY_REX_EBA distribute by hash (REX_REXID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_ASSET_ENERGY_REX_EBA_ARCHIVE_ZEBRA_REXID on AMC.TABLE_ASSET_ENERGY_REX_EBA_ARCHIVE (REX_REXID);
comment on table AMC.TABLE_ASSET_ENERGY_REX_EBA_ARCHIVE is 'Liste der Energie-Eigenschaften, welche zu einem Asset gehören (Alle Stichtage)';
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_ASSET_ENERGY_REX_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_ASSET_ENERGY_REX_EBA_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_ASSET_ENERGY_REX_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------


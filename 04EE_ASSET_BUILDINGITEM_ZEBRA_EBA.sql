-- View erstellen
drop view CALC.VIEW_ASSET_BUILDINGITEM_ZEBRA_EBA;
-- Satellitentabelle Asset EBA
create or replace view CALC.VIEW_ASSET_BUILDINGITEM_ZEBRA_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
---- Buildingitem
-- Alle an CMS mappbare Real Estates
REST_CMS as (
    select *
    from (select C.VO_ID,
                 R.*,
                 -- Selten gibt es mehrere VO_IDs für die selbe REXID, einfach größte nehmen
                 ROW_NUMBER() over (partition by C.VO_REX_NUMMER order by C.VO_ID desc, R.REALESTATEENTRIES_ID desc) as RN
          from NLB.CMS_VO_CURRENT C
                   -- inner join für Filter
                   inner join NLB.ZEBRA_REAL_ESTATE_ENTRIES_CURRENT R
                              on (C.CUTOFFDATE, C.VO_REX_NUMMER) = (R.CUT_OFF_DATE, R.REALESTATEENTRIES_REXID)
          where UPPER(C.VO_STATUS) = 'RECHTLICH AKTIV'
            and C.CUTOFFDATE = (select CUT_OFF_DATE from COD)
            and R.CUT_OFF_DATE = (select CUT_OFF_DATE from COD))
    where RN = 1
),
-- Buildingitem zusammenstellen + Filter nach an CMS mappbare Daten
BLDITM_CMS as (
    select RE.CUT_OFF_DATE,
           RE.VO_ID,
           RE.REALESTATEENTRIES_ID,
           RE.REALESTATEENTRIES_REXID                           as REXID,
           B.BUILDINGITEMENTRIES_ID,
           G.GREENLOANENTRIES_ID,
           B.BUILDINGITEMENTRIES_CERTIFICATE                    as CERTIFICATE,
           B.BUILDINGITEMENTRIES_ENERGYCERTIFICATEISSUANCEDATE  as ENERGYCERTIFICATEISSUANCEDATE,
           B.BUILDINGITEMENTRIES_CONSTRUCTIONYEAR               as CONSTRUCTIONYEAR,
           B.BUILDINGITEMENTRIES_EMISSIONCO2                    as EMISSIONCO2,
           B.BUILDINGITEMENTRIES_DISTANCEPUBLICTRANSPORT        as DISTANCEPUBLICTRANSPORT,
           B.BUILDINGITEMENTRIES_ENERGYDEMANDHEAT               as ENERGYDEMANDHEAT,
           B.BUILDINGITEMENTRIES_ENERGYDEMANDELECTRICITY        as ENERGYDEMANDELECTRICITY,
           B.BUILDINGITEMENTRIES_ENERGYEFFICIENCYCLASS          as ENERGYEFFICIENCYCLASS,
           B.BUILDINGITEMENTRIES_ENERGYCERTIFICATEVALID         as ENERGYCERTIFICATEVALID,
           B.BUILDINGITEMENTRIES_ENERGYCONSUMPTIONUNIT          as ENERGYCONSUMPTIONUNIT,
           B.BUILDINGITEMENTRIES_ENERGYCERTIFICATEDUEDATE       as ENERGYCERTIFICATEDUEDATE,
           B.BUILDINGITEMENTRIES_CERTIFICATEDUEDATE             as CERTIFICATEDUEDATE,
           B.BUILDINGITEMENTRIES_PRIMARYENERGYDEMANDCONSUMPTION as PRIMARYENERGYDEMANDCONSUMPTION,
           B.BUILDINGITEMENTRIES_CERTIFIER                      as CERTIFIER,
           B.BUILDINGITEMENTRIES_BUILDINGUSABLEAREA             as BUILDINGUSABLEAREA,
           B.BUILDINGITEMENTRIES_VERSION                        as VERSION,
           G.GREENLOANENTRIES_GREENBUILDINGVALUE                as GREENBUILDINGVALUE
    from REST_CMS RE
             -- inner join für Filter
             inner join NLB.ZEBRA_GREEN_LOAN_ENTRIES_CURRENT G
                        on (RE.CUT_OFF_DATE, RE.REALESTATEENTRIES_ID) = (G.CUT_OFF_DATE, G.GREENLOANENTRIES_REALESTATEID)
             inner join NLB.ZEBRA_BUILDING_ITEM_ENTRIES_CURRENT B
                        on (G.CUT_OFF_DATE, G.GREENLOANENTRIES_ID) = (B.CUT_OFF_DATE, B.BUILDINGITEMENTRIES_GREENLOANDATAID)
    where G.CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
      and B.CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- Energieeinheiten umrechnen
BLDITEM_UNIT as (
    select CUT_OFF_DATE,
           REALESTATEENTRIES_ID          as ZEBRA_REALESTATEID,
           REXID                         as ZEBRA_REXID,
           VO_ID                         as ZEBRA_CMSID,
           BUILDINGITEMENTRIES_ID        as ZEBRA_BUILDINGITEMID,
           GREENLOANENTRIES_ID           as ZEBRA_GREENLOANID,
           CRT.ENGLISH_TEXT              as ZEBRA_CERTIFICATE,
           ENERGYCERTIFICATEISSUANCEDATE as ZEBRA_ENERGYCERTIFICATEISSUANCEDATE,
           CONSTRUCTIONYEAR              as ZEBRA_CONSTRUCTIONYEAR,
           EMISSIONCO2                   as ZEBRA_EMISSIONCO2,
           DPT.S_VALUE                   as ZEBRA_DISTANCEPUBLICTRANSPORT,
           case
               when UPPER(ENERGYCONSUMPTIONUNIT) in ('KILOWATTSTUNDEN', 'KW_H')
                   then ENERGYDEMANDHEAT
               when UPPER(ENERGYCONSUMPTIONUNIT) in ('MEGAJOULE', 'MJ')
                   then ENERGYDEMANDHEAT / 3.6
               else ENERGYDEMANDHEAT
               end                       as ZEBRA_ENERGYDEMANDHEAT,
           case
               when UPPER(ENERGYCONSUMPTIONUNIT) in ('KILOWATTSTUNDEN', 'KW_H')
                   then ENERGYDEMANDELECTRICITY
               when UPPER(ENERGYCONSUMPTIONUNIT) in ('MEGAJOULE', 'MJ')
                   then ENERGYDEMANDELECTRICITY / 3.6
               else ENERGYDEMANDELECTRICITY
               end                       as ZEBRA_ENERGYDEMANDELECTRICITY,
           LBL.ENGLISH_TXT               as ZEBRA_ENERGYEFFICIENCYCLASS,
           ENERGYCERTIFICATEVALID        as ZEBRA_ENERGYCERTIFICATEVALID,
           ENERGYCONSUMPTIONUNIT         as ZEBRA_ENERGYCONSUMPTIONUNIT_OC,
           ENERGYCERTIFICATEDUEDATE      as ZEBRA_ENERGYCERTIFICATEDUEDATE,
           CERTIFICATEDUEDATE            as ZEBRA_CERTIFICATEDUEDATE,
           case
               when UPPER(ENERGYCONSUMPTIONUNIT) in ('KILOWATTSTUNDEN', 'KW_H')
                   then PRIMARYENERGYDEMANDCONSUMPTION
               when UPPER(ENERGYCONSUMPTIONUNIT) in ('MEGAJOULE', 'MJ')
                   then PRIMARYENERGYDEMANDCONSUMPTION / 3.6
               else PRIMARYENERGYDEMANDCONSUMPTION
               end                       as ZEBRA_PRIMARYENERGYDEMANDCONSUMPTION,
           CRT.ASSOCIATED_CERTIFIER      as ZEBRA_CERTIFIER,
           BUILDINGUSABLEAREA            as ZEBRA_BUILDINGUSABLEAREA,
           VERSION                       as ZEBRA_VERSION,
           GREENBUILDINGVALUE            as ZEBRA_GREENBUILDINGVALUE,
           case
               when ENERGYCONSUMPTIONUNIT is null or UPPER(ENERGYCONSUMPTIONUNIT) not in ('KILOWATTSTUNDEN', 'KW_H', 'MEGAJOULE', 'MJ')
                   then 'UNBEKANNT'
               else 'Kilowattstunden'
               end                       as ZEBRA_ENERGYCONSUMPTIONUNIT
    from BLDITM_CMS
             left join SMAP.ZEBRA_GLS_LABEL LBL on ENERGYEFFICIENCYCLASS = LBL.GLSLABEL
             left join SMAP.ZEBRA_GLS_CERTIFICATE CRT on CERTIFICATE = CRT.SELECTABLE_CODE
             left join SMAP.ZEBRA_GLS_DISTANCE_PUBLIC_TRANSPORT DPT on DISTANCEPUBLICTRANSPORT = DPT.S_KEY
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
    select B.*
    from BLDITEM_UNIT B
             inner join ASSET_EBA ASSET on ASSET.VO_REX_NUMMER = B.ZEBRA_REXID
),
-- Gefiltert nach noetigen Datenfeldern
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        ZEBRA_REXID,
        ZEBRA_BUILDINGITEMID,
        ZEBRA_REALESTATEID,
        ZEBRA_GREENLOANID,
        ZEBRA_VERSION,
        ZEBRA_CONSTRUCTIONYEAR,
        ZEBRA_BUILDINGUSABLEAREA,
        ZEBRA_ENERGYCERTIFICATEISSUANCEDATE,
        ZEBRA_EMISSIONCO2,
        ZEBRA_DISTANCEPUBLICTRANSPORT,
        ZEBRA_ENERGYDEMANDHEAT,
        ZEBRA_ENERGYDEMANDELECTRICITY,
        ZEBRA_ENERGYEFFICIENCYCLASS,
        ZEBRA_ENERGYCERTIFICATEVALID,
        ZEBRA_ENERGYCONSUMPTIONUNIT,
        ZEBRA_ENERGYCONSUMPTIONUNIT_OC,
        ZEBRA_CERTIFICATEDUEDATE,
        ZEBRA_CERTIFIER,
        ZEBRA_ENERGYCERTIFICATEDUEDATE,
        ZEBRA_CERTIFICATE,
        ZEBRA_PRIMARYENERGYDEMANDCONSUMPTION,
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
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_ASSET_BUILDINGITEM_ZEBRA_EBA_CURRENT');
create table AMC.TABLE_ASSET_BUILDINGITEM_ZEBRA_EBA_CURRENT like CALC.VIEW_ASSET_BUILDINGITEM_ZEBRA_EBA distribute by hash (ZEBRA_REXID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_ASSET_BUILDINGITEM_ZEBRA_EBA_CURRENT_ZEBRA_REXID on AMC.TABLE_ASSET_BUILDINGITEM_ZEBRA_EBA_CURRENT (ZEBRA_REXID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_ASSET_BUILDINGITEM_ZEBRA_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- Archiv-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_ASSET_BUILDINGITEM_ZEBRA_EBA_ARCHIVE');
create table AMC.TABLE_ASSET_BUILDINGITEM_ZEBRA_EBA_ARCHIVE like CALC.VIEW_ASSET_BUILDINGITEM_ZEBRA_EBA distribute by hash (ZEBRA_REXID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_ASSET_BUILDINGITEM_ZEBRA_EBA_ARCHIVE_ZEBRA_REXID on AMC.TABLE_ASSET_BUILDINGITEM_ZEBRA_EBA_ARCHIVE (ZEBRA_REXID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_ASSET_BUILDINGITEM_ZEBRA_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_ASSET_BUILDINGITEM_ZEBRA_EBA_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_ASSET_BUILDINGITEM_ZEBRA_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------


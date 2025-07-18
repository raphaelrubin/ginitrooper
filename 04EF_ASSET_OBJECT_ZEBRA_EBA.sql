-- View erstellen
drop view CALC.VIEW_ASSET_OBJECT_ZEBRA_EBA;
create or replace view CALC.VIEW_ASSET_OBJECT_ZEBRA_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
---- Object
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
-- Object zusammenstellen + Filter nach an CMS mappbare Daten
OBJECT_CMS as (
    select RE.CUT_OFF_DATE,
           RE.VO_ID,
           RE.REALESTATEENTRIES_ID,
           G.GREENLOANENTRIES_ID,
           RE.REALESTATEENTRIES_REXID                                                          as REXID,
           RE.REALESTATEADDRESS_ZIPCODE                                                        as ADDRESS_ZIPCODE,
           RE.REALESTATEENTRIES_COUNTRYCODE                                                    as COUNTRYCODE,
           RE.REALESTATEENTRIES_USETYPE                                                        as USETYPE,
           RE.REALESTATEENTRIES_PROPERTYTYPEECONOMICAL                                         as PROPERTYTYPEECONOMICAL,
           NVL(RE.REALESTATEENTRIES_PROJECTDEVELOPMENT, G.GREENLOANENTRIES_PROJECTDEVELOPMENT) as PROJECTDEVELOPMENT,
           G.GREENLOANENTRIES_GREENBUILDINGVALUE                                               as GREENBUILDINGVALUE
    from REST_CMS RE
             left join NLB.ZEBRA_GREEN_LOAN_ENTRIES_CURRENT G
                       on (RE.CUT_OFF_DATE, RE.REALESTATEENTRIES_ID) = (G.CUT_OFF_DATE, G.GREENLOANENTRIES_REALESTATEID)
    where NVL(G.CUT_OFF_DATE, RE.CUT_OFF_DATE) = (select CUT_OFF_DATE from COD)
),
-- Rent an REXID mappen
RNT_CMS as (
    select RE.CUT_OFF_DATE,
           RE.REALESTATEENTRIES_REXID        as REXID,
           RE.REALESTATEENTRIES_CURRENCYCODE as CURRENCYCODE,
           R.RENTENTRIES_NETCOLDRENT         as NETCOLDRENT
    from REST_CMS RE
             -- inner join für Filter
             inner join NLB.ZEBRA_RENTAL_AGREEMENT_ENTRIES_CURRENT RA
                        on (RE.CUT_OFF_DATE, RE.REALESTATEENTRIES_ID) = (RA.CUT_OFF_DATE, RA.RENTALAGREEMENTENTRIES_REALESTATEID)
             left join NLB.ZEBRA_RENT_ENTRIES_CURRENT R
                       on (RA.CUT_OFF_DATE, RA.RENTALAGREEMENTENTRIES_ID) = (R.CUT_OFF_DATE, R.RENTENTRIES_RENTALAGREEMENTID)
    where
      -- Keep RENTVALIDUNTIL = null rows
        NVL(R.RENTENTRIES_RENTVALIDUNTIL, R.CUT_OFF_DATE + 1 days) > R.CUT_OFF_DATE
      -- Keep CONTRACTTERMINATED = null rows
      and not NVL(RA.RENTALAGREEMENTENTRIES_CONTRACTTERMINATED, false)
      and RA.CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
      and R.CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- Für jede REXID NETCOLDRENT in EUR aufsummieren
REX_RNT_SUM_EUR as (
    select R.CUT_OFF_DATE,
           R.REXID,
           sum(NETCOLDRENT * CM.RATE_TARGET_TO_EUR) as NETCOLDRENT_SUM,
           'EUR'                                    as CURRENCY,
           case
               when count(distinct CURRENCYCODE) > 1
                   then 'UNEINDEUTIG'
               else max(CURRENCYCODE)
               end                                  as NETCOLDRENT_CURRENCY_SUM_OC
    from RNT_CMS R
             left join IMAP.CURRENCY_MAP CM on (R.CUT_OFF_DATE, R.CURRENCYCODE) = (CM.CUT_OFF_DATE, CM.ZIEL_WHRG)
    group by R.CUT_OFF_DATE, R.REXID
),
-- Zugehörige BuildingItems aufsummieren
BLDITM_SUM as (
    select CUT_OFF_DATE,
           ZEBRA_GREENLOANID                                 as GREENLOANID,
           SUM(ZEBRA_EMISSIONCO2 * ZEBRA_BUILDINGUSABLEAREA) AS EMISSIONCO2_SUM,
           SUM(case
                   when UPPER(ZEBRA_ENERGYCONSUMPTIONUNIT) like 'UNBEKANNT'
                       then 0
                   else ZEBRA_ENERGYDEMANDHEAT * ZEBRA_BUILDINGUSABLEAREA
               end)                                          AS ENERGYDEMANDHEAT_SUM,
           SUM(case
                   when UPPER(ZEBRA_ENERGYCONSUMPTIONUNIT) like 'UNBEKANNT'
                       then 0
                   else ZEBRA_ENERGYDEMANDELECTRICITY * ZEBRA_BUILDINGUSABLEAREA
               end)                                          AS ENERGYDEMANDELECTRICITY_SUM,
           SUM(case
                   when UPPER(ZEBRA_ENERGYCONSUMPTIONUNIT) like 'UNBEKANNT'
                       then 0
                   else ZEBRA_PRIMARYENERGYDEMANDCONSUMPTION * ZEBRA_BUILDINGUSABLEAREA
               end)                                          AS PRIMARYENERGYDEMANDCONSUMPTION_SUM,
           SUM(ZEBRA_BUILDINGUSABLEAREA)                     AS TOTALAREA,
           case
               when count(distinct ZEBRA_ENERGYCONSUMPTIONUNIT) > 1
                   then 'UNEINDEUTIG'
               else max(ZEBRA_ENERGYCONSUMPTIONUNIT)
               end                                           as ENERGYCONSUMPTIONUNIT,
           case
               when count(distinct ZEBRA_ENERGYCONSUMPTIONUNIT_OC) > 1
                   then 'UNEINDEUTIG'
               else max(ZEBRA_ENERGYCONSUMPTIONUNIT_OC)
               end                                           as ENERGYCONSUMPTIONUNIT_OC
    from CALC.SWITCH_ASSET_BUILDINGITEM_ZEBRA_EBA_CURRENT
    where ZEBRA_ENERGYDEMANDELECTRICITY is not null
    group by CUT_OFF_DATE, ZEBRA_GREENLOANID
),
-- Übrige Spalten umrechnen und mit Summen joinen
BLDITM_GRN as (
    select BSUM.*,
           G.GREENLOANENTRIES_WEIGHTEDEMISSIONCO2 as GREENTABLECO2,
           case
               when UPPER(BSUM.ENERGYCONSUMPTIONUNIT_OC) in ('KILOWATTSTUNDEN', 'KW_H')
                   then G.GREENLOANENTRIES_WEIGHTEDPRIMARYENERGYDEMAND
               when UPPER(BSUM.ENERGYCONSUMPTIONUNIT_OC) in ('MEGAJOULE', 'MJ')
                   then G.GREENLOANENTRIES_WEIGHTEDPRIMARYENERGYDEMAND / 3.6
               else G.GREENLOANENTRIES_WEIGHTEDPRIMARYENERGYDEMAND
               end                                as GREENTABLEPRIMARYENERGYDEMAND
    from BLDITM_SUM BSUM
             left join NLB.ZEBRA_GREEN_LOAN_ENTRIES_CURRENT G
                       on (BSUM.CUT_OFF_DATE, BSUM.GREENLOANID) = (G.CUT_OFF_DATE, G.GREENLOANENTRIES_ID)
    where G.CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
--
BLDITM_GRN_UNQ as (
    select *
    from BLDITM_GRN
),
-- Alles zusammenführen
OBJ as (
    select O.CUT_OFF_DATE,
           O.REXID,
           O.VO_ID                              as CMSID,
           O.GREENLOANENTRIES_ID                as GREENLOANID,
           O.ADDRESS_ZIPCODE,
           O.COUNTRYCODE,
           UT.ENGLISH_DESCRIPTION               as USETYPE,
           PRP.ENGLISH_DESCRIPTION              as PROPERTYTYPEECONOMICAL,
           O.PROJECTDEVELOPMENT,
           O.GREENBUILDINGVALUE,
           R.NETCOLDRENT_SUM,
           R.NETCOLDRENT_CURRENCY_SUM_OC,
           R.CURRENCY,
           B.GREENTABLECO2                      as WEIGHTEDEMISSIONCO2_OBJECT,
           B.GREENTABLEPRIMARYENERGYDEMAND      as PRIMARYENERGYDEMAND_OBJECT,
           B.ENERGYDEMANDHEAT_SUM               as ENERGYDEMANDHEATTOTAL_FROMBUILDINGITEMS,
           B.ENERGYDEMANDELECTRICITY_SUM        as ENERGYDEMANDELECTRICITYTOTAL_FROMBUILDINGITEMS,
           B.PRIMARYENERGYDEMANDCONSUMPTION_SUM as PRIMARYENERGYDEMANDCONSUMPTIONTOTAL_FROMBUILDINGITEMS
    from OBJECT_CMS O
             left join BLDITM_GRN_UNQ B on (O.CUT_OFF_DATE, O.GREENLOANENTRIES_ID) = (B.CUT_OFF_DATE, B.GREENLOANID)
             left join REX_RNT_SUM_EUR R on (O.CUT_OFF_DATE, O.REXID) = (R.CUT_OFF_DATE, R.REXID)
             left join SMAP.ZEBRA_PROPERTY_TYPES PRP on O.PROPERTYTYPEECONOMICAL = PRP.KEY
             left join SMAP.ZEBRA_REALESTATE_USETYPES UT on O.USETYPE = UT.KEY
),
-- Manchmal haben REXIDs mehrere Greenloan IDs, aggregieren für eindeutigen REXID Output
FINAL as (
    select CUT_OFF_DATE,
           REXID,
           CMSID,
           -- Listagg distinct behält vorige Sortierung nicht bei
           LISTAGG(distinct GREENLOANID, ', ') within group (order by VARCHAR(GREENLOANID)) as GREENLOANID,
           LISTAGG(distinct ADDRESS_ZIPCODE, ', ') within group (order by ADDRESS_ZIPCODE)  as ADDRESS_ZIPCODE,
           LISTAGG(distinct COUNTRYCODE, ', ') within group (order by COUNTRYCODE)          as COUNTRYCODE,
           MAX(USETYPE)                                                                     as USETYPE,
           MAX(PROPERTYTYPEECONOMICAL)                                                      as PROPERTYTYPEECONOMICAL,
           MAX(PROJECTDEVELOPMENT)                                                          as PROJECTDEVELOPMENT,
           SUM(GREENBUILDINGVALUE)                                                          as GREENBUILDINGVALUE,
           MAX(NETCOLDRENT_SUM)                                                             as NETCOLDRENT_SUM,
           MAX(NETCOLDRENT_CURRENCY_SUM_OC)                                                 as NETCOLDRENT_CURRENCY_SUM_OC,
           MAX(CURRENCY)                                                                    as CURRENCY,
           SUM(WEIGHTEDEMISSIONCO2_OBJECT)                                                  as WEIGHTEDEMISSIONCO2_OBJECT,
           SUM(PRIMARYENERGYDEMAND_OBJECT)                                                  as PRIMARYENERGYDEMAND_OBJECT,
           SUM(ENERGYDEMANDHEATTOTAL_FROMBUILDINGITEMS)                                     as ENERGYDEMANDHEATTOTAL_FROMBUILDINGITEMS,
           SUM(ENERGYDEMANDELECTRICITYTOTAL_FROMBUILDINGITEMS)                              as ENERGYDEMANDELECTRICITYTOTAL_FROMBUILDINGITEMS,
           SUM(PRIMARYENERGYDEMANDCONSUMPTIONTOTAL_FROMBUILDINGITEMS)                       as PRIMARYENERGYDEMANDCONSUMPTIONTOTAL_FROMBUILDINGITEMS
    from OBJ
    group by CUT_OFF_DATE, REXID, CMSID
),
-- Gefiltert nach noetigen Datenfeldern + nullable
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        NULLIF(REXID, null)                                                 as REXID,
        NULLIF(CMSID, null)                                                 as CMSID,
        NULLIF(GREENLOANID, null)                                           as GREENLOANID,
        NULLIF(ADDRESS_ZIPCODE, null)                                       as ADDRESS_ZIPCODE,
        NULLIF(COUNTRYCODE, null)                                           as COUNTRYCODE,
        NULLIF(USETYPE, null)                                               as USETYPE,
        NULLIF(PROPERTYTYPEECONOMICAL, null)                                as PROPERTYTYPEECONOMICAL,
        NULLIF(PROJECTDEVELOPMENT, null)                                    as PROJECTDEVELOPMENT,
        NULLIF(GREENBUILDINGVALUE, null)                                    as GREENBUILDINGVALUE,
        NULLIF(NETCOLDRENT_SUM, null)                                       as NETCOLDRENT_SUM,
        NULLIF(NETCOLDRENT_CURRENCY_SUM_OC, null)                           as NETCOLDRENT_CURRENCY_SUM_OC,
        NULLIF(CURRENCY, null)                                              as CURRENCY,
        NULLIF(WEIGHTEDEMISSIONCO2_OBJECT, null)                            as WEIGHTEDEMISSIONCO2_OBJECT,
        NULLIF(PRIMARYENERGYDEMAND_OBJECT, null)                            as PRIMARYENERGYDEMAND_OBJECT,
        NULLIF(ENERGYDEMANDHEATTOTAL_FROMBUILDINGITEMS, null)               as ENERGYDEMANDHEATTOTAL_FROMBUILDINGITEMS,
        NULLIF(ENERGYDEMANDELECTRICITYTOTAL_FROMBUILDINGITEMS, null)        as ENERGYDEMANDELECTRICITYTOTAL_FROMBUILDINGITEMS,
        NULLIF(PRIMARYENERGYDEMANDCONSUMPTIONTOTAL_FROMBUILDINGITEMS, null) as PRIMARYENERGYDEMANDCONSUMPTIONTOTAL_FROMBUILDINGITEMS,
        -- Defaults
        CURRENT_USER                                                        as USER,
        CURRENT_TIMESTAMP                                                   as TIMESTAMP_LOAD
    from FINAL
)
select *
from FINAL_FILTERED;

-- CI START FOR ALL TAPES

-- Current-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_ASSET_OBJECT_ZEBRA_EBA_CURRENT');
create table AMC.TABLE_ASSET_OBJECT_ZEBRA_EBA_CURRENT like CALC.VIEW_ASSET_OBJECT_ZEBRA_EBA distribute by hash (REXID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_ASSET_OBJECT_ZEBRA_EBA_CURRENT_REXID on AMC.TABLE_ASSET_OBJECT_ZEBRA_EBA_CURRENT (REXID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_ASSET_OBJECT_ZEBRA_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_ASSET_OBJECT_ZEBRA_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------



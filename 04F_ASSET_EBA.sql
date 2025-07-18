-- View erstellen
drop view CALC.VIEW_ASSET_EBA;
-- Haupttabelle Asset EBA
create or replace view CALC.VIEW_ASSET_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
---- Quelldaten
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
IWHS_VVS_ASSET as (
    select *
    from CALC.SWITCH_ASSET_IWHS_VVS_EBA_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
REX_ASSET as (
    select *
    from CALC.SWITCH_ASSET_REX_EBA_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
ZEBRA_ASSET as (
    select *
    from CALC.SWITCH_ASSET_OBJECT_ZEBRA_EBA_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- Alles zusammenführen
FINAL as (
    select distinct PWC.CUT_OFF_DATE,
                    PWC.ASSET_ID,
                    CMS.VO_ART                                                  as CMS_VO_ART,
                    CMS.VO_GEBAEUDE_KZ                                          as CMS_VO_GEBAEUDE_KZ,
                    CMS.VO_TYP                                                  as CMS_VO_TYP,
                    CMS.VO_NUTZUNG_OBJEKT                                       as CMS_VO_NUTZUNG_OBJEKT,
                    CMS.VO_NUTZUNGSART                                          as CMS_VO_NUTZUNGSART,
                    CMS.VO_FESTSETZ_DATUM                                       as CMS_VO_FESTSETZ_DATUM,
                    CMS.VO_GEWERB_NUTZUNG_P                                     as CMS_VO_GEWERB_NUTZUNG_P,
                    CMS.VO_LETZT_NACHWEIS_DATUM                                 as CMS_VO_LETZT_NACHWEIS_DATUM,
                    CMS.VO_ANWEND_RECHT                                         as CMS_VO_ANWEND_RECHT,
                    CMS.VO_NOMINAL_WERT                                         as CMS_VO_NOMINAL_WERT,
                    CMS.VO_NOMINAL_WERT_CURRENCY                                as CMS_VO_NOMINAL_WERT_CURRENCY,
                    CMS.VO_NOMINAL_WERT_CURRENCY_OC                             as CMS_VO_NOMINAL_WERT_CURRENCY_OC,
                    CMS.VO_ANZUS_WERT                                           as CMS_VO_ANZUS_WERT,
                    CMS.VO_ANZUS_WERT_CURRENCY                                  as CMS_VO_ANZUS_WERT_CURRENCY,
                    CMS.VO_ANZUS_WERT_CURRENCY_OC                               as CMS_VO_ANZUS_WERT_CURRENCY_OC,
                    CMS.VO_CALC_LENDING_VALUE                                   as CMS_VO_CALC_LENDING_VALUE,
                    CMS.VO_CALC_LENDING_LIMIT                                   as CMS_VO_CALC_LENDING_LIMIT,
                    CMS.VO_CALC_CURRENCY                                        as CMS_VO_CALC_CURRENCY,
                    CMS.VO_CALC_CURRENCY_OC                                     as CMS_VO_CALC_CURRENCY_OC,
                    CMS.VO_BELEIHUNGSGRENZE_PROZ                                as CMS_VO_BELEIHUNGSGRENZE_PROZ,
                    CMS.VO_BELEIHSATZ1_P                                        as CMS_VO_BELEIHSATZ1_P,
                    CMS.VO_URSPRUNGSWERT                                        as CMS_VO_URSPRUNGSWERT,
                    CMS.VO_URSPRUNGSWERT_CURRENCY                               as CMS_VO_URSPRUNGSWERT_CURRENCY,
                    CMS.VO_URSPRUNGSWERT_CURRENCY_OC                            as CMS_VO_URSPRUNGSWERT_CURRENCY_OC,
                    CMS.VO_CRR_PROPERTY_VALUE                                   as CMS_VO_CRR_PROPERTY_VALUE,
                    CMS.VO_CRR_PROPERTY_VALUE_CURRENCY                          as CMS_VO_CRR_PROPERTY_VALUE_CURRENCY,
                    CMS.VO_CRR_PROPERTY_VALUE_CURRENCY_OC                       as CMS_VO_CRR_PROPERTY_VALUE_CURRENCY_OC,
                    CMS.VO_STRASSE                                              as CMS_VO_STRASSE,
                    CMS.VO_HAUS_NR                                              as CMS_VO_HAUS_NR,
                    CMS.VO_PLZ                                                  as CMS_VO_PLZ,
                    CMS.VO_ORT                                                  as CMS_VO_ORT,
                    CMS.VO_REGION                                               as CMS_VO_REGION,
                    CMS.VO_LAND                                                 as CMS_VO_LAND,
                    CMS.VO_OWNERS                                               as CMS_VO_OWNERS,
                    CMS.VO_REX_NUMMER                                           as CMS_VO_REX_NUMMER,
                    ZEBRA.REXID                                                 as ZEBRA_REXID,
                    ZEBRA.GREENLOANID                                           as ZEBRA_GREENLOANID,
                    ZEBRA.ADDRESS_ZIPCODE                                       as ZEBRA_ADDRESS_ZIPCODE,
                    ZEBRA.COUNTRYCODE                                           as ZEBRA_COUNTRYCODE,
                    ZEBRA.USETYPE                                               as ZEBRA_USETYPE,
                    ZEBRA.PROPERTYTYPEECONOMICAL                                as ZEBRA_PROPERTYTYPEECONOMICAL,
                    ZEBRA.PROJECTDEVELOPMENT                                    as ZEBRA_PROJECTDEVELOPMENT,
                    ZEBRA.GREENBUILDINGVALUE                                    as ZEBRA_GREENBUILDINGVALUE,
                    ZEBRA.NETCOLDRENT_SUM                                       as ZEBRA_NETCOLDRENT_SUM,
                    ZEBRA.NETCOLDRENT_CURRENCY_SUM_OC                           as ZEBRA_NETCOLDRENT_CURRENCY_SUM_OC,
                    ZEBRA.CURRENCY                                              as ZEBRA_CURRENCY,
                    ZEBRA.WEIGHTEDEMISSIONCO2_OBJECT                            as ZEBRA_WEIGHTEDEMISSIONCO2_OBJECT,
                    ZEBRA.PRIMARYENERGYDEMAND_OBJECT                            as ZEBRA_PRIMARYENERGYDEMAND_OBJECT,
                    ZEBRA.ENERGYDEMANDHEATTOTAL_FROMBUILDINGITEMS               as ZEBRA_ENERGYDEMANDHEATTOTAL_FROMBUILDINGITEMS,
                    ZEBRA.ENERGYDEMANDELECTRICITYTOTAL_FROMBUILDINGITEMS        as ZEBRA_ENERGYDEMANDELECTRICITYTOTAL_FROMBUILDINGITEMS,
                    ZEBRA.PRIMARYENERGYDEMANDCONSUMPTIONTOTAL_FROMBUILDINGITEMS as ZEBRA_PRIMARYENERGYDEMANDCONSUMPTIONTOTAL_FROMBUILDINGITEMS,
                    REX.STAMMNUMMER                                             as REX_REXID,
                    REX.VERSION                                                 as REX_VERSION,
                    REX.CURRENCY                                                as REX_CURRENCY,
                    REX.CURRENCY_OC                                             as REX_CURRENCY_OC,
                    REX.PLZ                                                     as REX_PLZ,
                    REX.STAAT                                                   as REX_STAAT,
                    REX.MAKROLAGE                                               as REX_MAKROLAGE,
                    REX.MIKROLAGE                                               as REX_MIKROLAGE,
                    REX.WERTDARSTELLUNG_MARKTWERT                               as REX_WERTDARSTELLUNG_MARKTWERT,
                    REX.WERTDARSTELLUNG_BELEIHUNGSWERT                          as REX_WERTDARSTELLUNG_BELEIHUNGSWERT,
                    REX.FESTGESETZTER_BELEIHUNGSWERT                            as REX_FESTGESETZTER_BELEIHUNGSWERT,
                    REX.REINERTRAG_PA_SUM                                       as REX_REINERTRAG_PA_SUM,
                    REX.ROHERTRAG_PA_SUM                                        as REX_ROHERTRAG_PA_SUM,
                    REX.NUTZUNG                                                 as REX_NUTZUNG,
                    REX.OBJEKTART                                               as REX_OBJEKTART,
                    REX.ZUSTAND                                                 as REX_ZUSTAND,
                    REX.GRAD_DER_FERTIGSTELLUNG                                 as REX_GRAD_DER_FERTIGSTELLUNG,
                    REX.BAUJAHR                                                 as REX_BAUJAHR,
                    REX.VOEB_IA_OBJEKTNOTE                                      as REX_VOEB_IA_OBJEKTNOTE,
                    REX.AUFTRAGSART                                             as REX_AUFTRAGSART,
                    REX.BESICHTIGUNGSDATUM                                      as REX_BESICHTIGUNGSDATUM,
                    REX.GUTACHTEN_ERSTELLT_AM                                   as REX_GUTACHTEN_ERSTELLT_AM,
                    VVS.VMGO_PRODUKTNAME                                        as VVS_VMGO_PRODUKTNAME,
                    VVS.IMMOBILIENART                                           as VVS_IMMOBILIENART,
                    VVS.IMMOBILIENUNTERART                                      as VVS_IMMOBILIENUNTERART,
                    VVS.IMO_NTZG_ART                                            as VVS_IMO_NTZG_ART,
                    VVS.NORDLB_IMO_ART                                          as VVS_NORDLB_IMO_ART,
                    VVS.VMGO_OBJ_STRASSE                                        as VVS_VMGO_OBJ_STRASSE,
                    VVS.VMGO_HAUS_NR                                            as VVS_VMGO_HAUS_NR,
                    VVS.VMGO_PLZ                                                as VVS_VMGO_PLZ,
                    VVS.VMGO_OBJ_ORT                                            as VVS_VMGO_OBJ_ORT,
                    VVS.VMGO_ISO_LAND_CODE                                      as VVS_VMGO_ISO_LAND_CODE,
                    VVS.PNR_EIGENTUEMER                                         as VVS_PNR_EIGENTUEMER,
                    VVS.VMGO_WTEM_GRDL_DTM                                      as VVS_VMGO_WTEM_GRDL_DTM,
                    VVS.VMGO_WERT_MRKT                                          as VVS_VMGO_WERT_MRKT,
                    VVS.VMGO_WERT_MRKT_DTM                                      as VVS_VMGO_WERT_MRKT_DTM,
                    VVS.VMGO_WERT_VKHR                                          as VVS_VMGO_WERT_VKHR,
                    VVS.VMGO_WERT_VKHR_FW                                       as VVS_VMGO_WERT_VKHR_FW,
                    VVS.VMGO_WERT_BELH                                          as VVS_VMGO_WERT_BELH,
                    VVS.VMGO_WERT_BELH_FW                                       as VVS_VMGO_WERT_BELH_FW,
                    VVS.VMGO_BLGR_PERS                                          as VVS_VMGO_BLGR_PERS,
                    VVS.VMGO_BLGR_PERS_FW                                       as VVS_VMGO_BLGR_PERS_FW,
                    VVS.VMGO_BLGR_PERS_PRZ                                      as VVS_VMGO_BLGR_PERS_PRZ,
                    VVS.VMGO_BLGR_REAL                                          as VVS_VMGO_BLGR_REAL,
                    VVS.VMGO_BLGR_REAL_FW                                       as VVS_VMGO_BLGR_REAL_FW,
                    VVS.VMGO_BLGR_REAL_PRZ                                      as VVS_VMGO_BLGR_REAL_PRZ,
                    VVS.VMGO_BLGR_WSFT                                          as VVS_VMGO_BLGR_WSFT,
                    VVS.VMGO_BLGR_WSFT_FW                                       as VVS_VMGO_BLGR_WSFT_FW,
                    VVS.VMGO_BLGR_WSFT_PRZ                                      as VVS_VMGO_BLGR_WSFT_PRZ,
                    VVS.VMGO_BLGR_BSIG_PRIV                                     as VVS_VMGO_BLGR_BSIG_PRIV,
                    VVS.VMGO_BLGR_BSIG                                          as VVS_VMGO_BLGR_BSIG,
                    VVS.VMGO_BLWT_HKFT                                          as VVS_VMGO_BLWT_HKFT,
                    VVS.VMGO_BLST_VWRT                                          as VVS_VMGO_BLST_VWRT,
                    VVS.VMGO_BLST_VWRT_FW                                       as VVS_VMGO_BLST_VWRT_FW,
                    VVS.VMGO_BLST_VWRT_DTM                                      as VVS_VMGO_BLST_VWRT_DTM,
                    VVS.VMGO_WERT_BSIS                                          as VVS_VMGO_WERT_BSIS,
                    VVS.VMGO_ABSG_BTRG                                          as VVS_VMGO_ABSG_BTRG,
                    VVS.VMGO_ABSG_BTRG_SUM                                      as VVS_VMGO_ABSG_BTRG_SUM,
                    VVS.VMGO_ABSG_TN                                            as VVS_VMGO_ABSG_TN,
                    VVS.VMGO_ABSG_ADTM                                          as VVS_VMGO_ABSG_ADTM,
                    VVS.SIHT_UEBW_LDTM                                          as VVS_SIHT_UEBW_LDTM,
                    VVS.SIHT_PRFG_LDTM                                          as VVS_SIHT_PRFG_LDTM,
                    VVS.IMO_ENRG_AUSW_KZ                                        as VVS_IMO_ENRG_AUSW_KZ,
                    VVS.IMO_ENRG_AUSW_DTM                                       as VVS_IMO_ENRG_AUSW_DTM,
                    VVS.IMO_ENGE_KLSS                                           as VVS_IMO_ENGE_KLSS,
                    VVS.ENERGIESTANDARD                                         as VVS_ENERGIESTANDARD,
                    VVS.IMO_ENRG_TRG_1_MM                                       as VVS_IMO_ENRG_TRG_1_MM,
                    VVS.IMO_ENRG_TRG_2_MM                                       as VVS_IMO_ENRG_TRG_2_MM
    from PWC_ASSET PWC
             left join CMS_ASSET CMS on PWC.SOURCE = 'CMS' and PWC.ASSET_ID = CMS.ASSET_ID
             left join ZEBRA_ASSET ZEBRA on CMS.VO_REX_NUMMER = ZEBRA.REXID
             left join REX_ASSET REX on CMS.VO_REX_NUMMER = REX.STAMMNUMMER
             left join IWHS_VVS_ASSET VVS on PWC.SOURCE = 'IWHS' and PWC.ASSET_ID = cast(VVS.ASSET_ID as VARCHAR(64))
),
-- Gefiltert nach noetigen Datenfeldern + nullable
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        NULLIF(ASSET_ID, null)                                                    as ASSET_ID,
        NULLIF(CMS_VO_ART, null)                                                  as CMS_VO_ART,
        NULLIF(CMS_VO_GEBAEUDE_KZ, null)                                          as CMS_VO_GEBAEUDE_KZ,
        NULLIF(CMS_VO_TYP, null)                                                  as CMS_VO_TYP,
        NULLIF(CMS_VO_NUTZUNG_OBJEKT, null)                                       as CMS_VO_NUTZUNG_OBJEKT,
        NULLIF(CMS_VO_NUTZUNGSART, null)                                          as CMS_VO_NUTZUNGSART,
        NULLIF(CMS_VO_FESTSETZ_DATUM, null)                                       as CMS_VO_FESTSETZ_DATUM,
        NULLIF(CMS_VO_GEWERB_NUTZUNG_P, null)                                     as CMS_VO_GEWERB_NUTZUNG_P,
        NULLIF(CMS_VO_LETZT_NACHWEIS_DATUM, null)                                 as CMS_VO_LETZT_NACHWEIS_DATUM,
        NULLIF(CMS_VO_ANWEND_RECHT, null)                                         as CMS_VO_ANWEND_RECHT,
        NULLIF(CMS_VO_NOMINAL_WERT, null)                                         as CMS_VO_NOMINAL_WERT,
        NULLIF(CMS_VO_NOMINAL_WERT_CURRENCY, null)                                as CMS_VO_NOMINAL_WERT_CURRENCY,
        NULLIF(CMS_VO_NOMINAL_WERT_CURRENCY_OC, null)                             as CMS_VO_NOMINAL_WERT_CURRENCY_OC,
        NULLIF(CMS_VO_ANZUS_WERT, null)                                           as CMS_VO_ANZUS_WERT,
        NULLIF(CMS_VO_ANZUS_WERT_CURRENCY, null)                                  as CMS_VO_ANZUS_WERT_CURRENCY,
        NULLIF(CMS_VO_ANZUS_WERT_CURRENCY_OC, null)                               as CMS_VO_ANZUS_WERT_CURRENCY_OC,
        NULLIF(CMS_VO_CALC_LENDING_VALUE, null)                                   as CMS_VO_CALC_LENDING_VALUE,
        NULLIF(CMS_VO_CALC_LENDING_LIMIT, null)                                   as CMS_VO_CALC_LENDING_LIMIT,
        NULLIF(CMS_VO_CALC_CURRENCY, null)                                        as CMS_VO_CALC_CURRENCY,
        NULLIF(CMS_VO_CALC_CURRENCY_OC, null)                                     as CMS_VO_CALC_CURRENCY_OC,
        NULLIF(CMS_VO_BELEIHUNGSGRENZE_PROZ, null)                                as CMS_VO_BELEIHUNGSGRENZE_PROZ,
        NULLIF(CMS_VO_BELEIHSATZ1_P, null)                                        as CMS_VO_BELEIHSATZ1_P,
        NULLIF(CMS_VO_URSPRUNGSWERT, null)                                        as CMS_VO_URSPRUNGSWERT,
        NULLIF(CMS_VO_URSPRUNGSWERT_CURRENCY, null)                               as CMS_VO_URSPRUNGSWERT_CURRENCY,
        NULLIF(CMS_VO_URSPRUNGSWERT_CURRENCY_OC, null)                            as CMS_VO_URSPRUNGSWERT_CURRENCY_OC,
        NULLIF(CMS_VO_CRR_PROPERTY_VALUE, null)                                   as CMS_VO_CRR_PROPERTY_VALUE,
        NULLIF(CMS_VO_CRR_PROPERTY_VALUE_CURRENCY, null)                          as CMS_VO_CRR_PROPERTY_VALUE_CURRENCY,
        NULLIF(CMS_VO_CRR_PROPERTY_VALUE_CURRENCY_OC, null)                       as CMS_VO_CRR_PROPERTY_VALUE_CURRENCY_OC,
        NULLIF(CMS_VO_STRASSE, null)                                              as CMS_VO_STRASSE,
        NULLIF(CMS_VO_HAUS_NR, null)                                              as CMS_VO_HAUS_NR,
        NULLIF(CMS_VO_PLZ, null)                                                  as CMS_VO_PLZ,
        NULLIF(CMS_VO_ORT, null)                                                  as CMS_VO_ORT,
        NULLIF(CMS_VO_REGION, null)                                               as CMS_VO_REGION,
        NULLIF(CMS_VO_LAND, null)                                                 as CMS_VO_LAND,
        NULLIF(CMS_VO_OWNERS, null)                                               as CMS_VO_OWNERS,
        NULLIF(CMS_VO_REX_NUMMER, null)                                           as CMS_VO_REX_NUMMER,
        NULLIF(ZEBRA_REXID, null)                                                 as ZEBRA_REXID,
        NULLIF(ZEBRA_GREENLOANID, null)                                           as ZEBRA_GREENLOANID,
        NULLIF(ZEBRA_ADDRESS_ZIPCODE, null)                                       as ZEBRA_ADDRESS_ZIPCODE,
        NULLIF(ZEBRA_COUNTRYCODE, null)                                           as ZEBRA_COUNTRYCODE,
        NULLIF(ZEBRA_USETYPE, null)                                               as ZEBRA_USETYPE,
        NULLIF(ZEBRA_PROPERTYTYPEECONOMICAL, null)                                as ZEBRA_PROPERTYTYPEECONOMICAL,
        NULLIF(ZEBRA_PROJECTDEVELOPMENT, null)                                    as ZEBRA_PROJECTDEVELOPMENT,
        NULLIF(ZEBRA_GREENBUILDINGVALUE, null)                                    as ZEBRA_GREENBUILDINGVALUE,
        NULLIF(ZEBRA_NETCOLDRENT_SUM, null)                                       as ZEBRA_NETCOLDRENT_SUM,
        NULLIF(ZEBRA_NETCOLDRENT_CURRENCY_SUM_OC, null)                           as ZEBRA_NETCOLDRENT_CURRENCY_SUM_OC,
        NULLIF(ZEBRA_CURRENCY, null)                                              as ZEBRA_CURRENCY,
        NULLIF(ZEBRA_WEIGHTEDEMISSIONCO2_OBJECT, null)                            as ZEBRA_WEIGHTEDEMISSIONCO2_OBJECT,
        NULLIF(ZEBRA_PRIMARYENERGYDEMAND_OBJECT, null)                            as ZEBRA_PRIMARYENERGYDEMAND_OBJECT,
        NULLIF(ZEBRA_ENERGYDEMANDHEATTOTAL_FROMBUILDINGITEMS, null)               as ZEBRA_ENERGYDEMANDHEATTOTAL_FROMBUILDINGITEMS,
        NULLIF(ZEBRA_ENERGYDEMANDELECTRICITYTOTAL_FROMBUILDINGITEMS, null)        as ZEBRA_ENERGYDEMANDELECTRICITYTOTAL_FROMBUILDINGITEMS,
        NULLIF(ZEBRA_PRIMARYENERGYDEMANDCONSUMPTIONTOTAL_FROMBUILDINGITEMS, null) as ZEBRA_PRIMARYENERGYDEMANDCONSUMPTIONTOTAL_FROMBUILDINGITEMS,
        NULLIF(REX_REXID, null)                                                   as REX_REXID,
        NULLIF(REX_VERSION, null)                                                 as REX_VERSION,
        NULLIF(REX_CURRENCY, null)                                                as REX_CURRENCY,
        NULLIF(REX_CURRENCY_OC, null)                                             as REX_CURRENCY_OC,
        NULLIF(REX_PLZ, null)                                                     as REX_PLZ,
        NULLIF(REX_STAAT, null)                                                   as REX_STAAT,
        NULLIF(REX_MAKROLAGE, null)                                               as REX_MAKROLAGE,
        NULLIF(REX_MIKROLAGE, null)                                               as REX_MIKROLAGE,
        NULLIF(REX_WERTDARSTELLUNG_MARKTWERT, null)                               as REX_WERTDARSTELLUNG_MARKTWERT,
        NULLIF(REX_WERTDARSTELLUNG_BELEIHUNGSWERT, null)                          as REX_WERTDARSTELLUNG_BELEIHUNGSWERT,
        NULLIF(REX_FESTGESETZTER_BELEIHUNGSWERT, null)                            as REX_FESTGESETZTER_BELEIHUNGSWERT,
        NULLIF(REX_REINERTRAG_PA_SUM, null)                                       as REX_REINERTRAG_PA_SUM,
        NULLIF(REX_ROHERTRAG_PA_SUM, null)                                        as REX_ROHERTRAG_PA_SUM,
        NULLIF(REX_NUTZUNG, null)                                                 as REX_NUTZUNG,
        NULLIF(REX_OBJEKTART, null)                                               as REX_OBJEKTART,
        NULLIF(REX_ZUSTAND, null)                                                 as REX_ZUSTAND,
        NULLIF(REX_GRAD_DER_FERTIGSTELLUNG, null)                                 as REX_GRAD_DER_FERTIGSTELLUNG,
        NULLIF(REX_BAUJAHR, null)                                                 as REX_BAUJAHR,
        NULLIF(REX_VOEB_IA_OBJEKTNOTE, null)                                      as REX_VOEB_IA_OBJEKTNOTE,
        NULLIF(REX_AUFTRAGSART, null)                                             as REX_AUFTRAGSART,
        NULLIF(REX_BESICHTIGUNGSDATUM, null)                                      as REX_BESICHTIGUNGSDATUM,
        NULLIF(REX_GUTACHTEN_ERSTELLT_AM, null)                                   as REX_GUTACHTEN_ERSTELLT_AM,
        NULLIF(VVS_VMGO_PRODUKTNAME, null)                                        as VVS_VMGO_PRODUKTNAME,
        NULLIF(VVS_IMMOBILIENART, null)                                           as VVS_IMMOBILIENART,
        NULLIF(VVS_IMMOBILIENUNTERART, null)                                      as VVS_IMMOBILIENUNTERART,
        NULLIF(VVS_IMO_NTZG_ART, null)                                            as VVS_IMO_NTZG_ART,
        NULLIF(VVS_NORDLB_IMO_ART, null)                                          as VVS_NORDLB_IMO_ART,
        NULLIF(VVS_VMGO_OBJ_STRASSE, null)                                        as VVS_VMGO_OBJ_STRASSE,
        NULLIF(VVS_VMGO_HAUS_NR, null)                                            as VVS_VMGO_HAUS_NR,
        NULLIF(VVS_VMGO_PLZ, null)                                                as VVS_VMGO_PLZ,
        NULLIF(VVS_VMGO_OBJ_ORT, null)                                            as VVS_VMGO_OBJ_ORT,
        NULLIF(VVS_VMGO_ISO_LAND_CODE, null)                                      as VVS_VMGO_ISO_LAND_CODE,
        NULLIF(VVS_PNR_EIGENTUEMER, null)                                         as VVS_PNR_EIGENTUEMER,
        NULLIF(VVS_VMGO_WTEM_GRDL_DTM, null)                                      as VVS_VMGO_WTEM_GRDL_DTM,
        NULLIF(VVS_VMGO_WERT_MRKT, null)                                          as VVS_VMGO_WERT_MRKT,
        NULLIF(VVS_VMGO_WERT_MRKT_DTM, null)                                      as VVS_VMGO_WERT_MRKT_DTM,
        NULLIF(VVS_VMGO_WERT_VKHR, null)                                          as VVS_VMGO_WERT_VKHR,
        NULLIF(VVS_VMGO_WERT_VKHR_FW, null)                                       as VVS_VMGO_WERT_VKHR_FW,
        NULLIF(VVS_VMGO_WERT_BELH, null)                                          as VVS_VMGO_WERT_BELH,
        NULLIF(VVS_VMGO_WERT_BELH_FW, null)                                       as VVS_VMGO_WERT_BELH_FW,
        NULLIF(VVS_VMGO_BLGR_PERS, null)                                          as VVS_VMGO_BLGR_PERS,
        NULLIF(VVS_VMGO_BLGR_PERS_FW, null)                                       as VVS_VMGO_BLGR_PERS_FW,
        NULLIF(VVS_VMGO_BLGR_PERS_PRZ, null)                                      as VVS_VMGO_BLGR_PERS_PRZ,
        NULLIF(VVS_VMGO_BLGR_REAL, null)                                          as VVS_VMGO_BLGR_REAL,
        NULLIF(VVS_VMGO_BLGR_REAL_FW, null)                                       as VVS_VMGO_BLGR_REAL_FW,
        NULLIF(VVS_VMGO_BLGR_REAL_PRZ, null)                                      as VVS_VMGO_BLGR_REAL_PRZ,
        NULLIF(VVS_VMGO_BLGR_WSFT, null)                                          as VVS_VMGO_BLGR_WSFT,
        NULLIF(VVS_VMGO_BLGR_WSFT_FW, null)                                       as VVS_VMGO_BLGR_WSFT_FW,
        NULLIF(VVS_VMGO_BLGR_WSFT_PRZ, null)                                      as VVS_VMGO_BLGR_WSFT_PRZ,
        NULLIF(VVS_VMGO_BLGR_BSIG_PRIV, null)                                     as VVS_VMGO_BLGR_BSIG_PRIV,
        NULLIF(VVS_VMGO_BLGR_BSIG, null)                                          as VVS_VMGO_BLGR_BSIG,
        NULLIF(VVS_VMGO_BLWT_HKFT, null)                                          as VVS_VMGO_BLWT_HKFT,
        NULLIF(VVS_VMGO_BLST_VWRT, null)                                          as VVS_VMGO_BLST_VWRT,
        NULLIF(VVS_VMGO_BLST_VWRT_FW, null)                                       as VVS_VMGO_BLST_VWRT_FW,
        NULLIF(VVS_VMGO_BLST_VWRT_DTM, null)                                      as VVS_VMGO_BLST_VWRT_DTM,
        NULLIF(VVS_VMGO_WERT_BSIS, null)                                          as VVS_VMGO_WERT_BSIS,
        NULLIF(VVS_VMGO_ABSG_BTRG, null)                                          as VVS_VMGO_ABSG_BTRG,
        NULLIF(VVS_VMGO_ABSG_BTRG_SUM, null)                                      as VVS_VMGO_ABSG_BTRG_SUM,
        NULLIF(VVS_VMGO_ABSG_TN, null)                                            as VVS_VMGO_ABSG_TN,
        NULLIF(VVS_VMGO_ABSG_ADTM, null)                                          as VVS_VMGO_ABSG_ADTM,
        NULLIF(VVS_SIHT_UEBW_LDTM, null)                                          as VVS_SIHT_UEBW_LDTM,
        NULLIF(VVS_SIHT_PRFG_LDTM, null)                                          as VVS_SIHT_PRFG_LDTM,
        NULLIF(VVS_IMO_ENRG_AUSW_KZ, null)                                        as VVS_IMO_ENRG_AUSW_KZ,
        NULLIF(VVS_IMO_ENRG_AUSW_DTM, null)                                       as VVS_IMO_ENRG_AUSW_DTM,
        NULLIF(VVS_IMO_ENGE_KLSS, null)                                           as VVS_IMO_ENGE_KLSS,
        NULLIF(VVS_ENERGIESTANDARD, null)                                         as VVS_ENERGIESTANDARD,
        NULLIF(VVS_IMO_ENRG_TRG_1_MM, null)                                       as VVS_IMO_ENRG_TRG_1_MM,
        NULLIF(VVS_IMO_ENRG_TRG_2_MM, null)                                       as VVS_IMO_ENRG_TRG_2_MM,
        -- Defaults
        CURRENT_USER                                                              as USER,
        CURRENT_TIMESTAMP                                                         as TIMESTAMP_LOAD
    from FINAL
)
select *
from FINAL_FILTERED;

-- CI START FOR ALL TAPES

-- Current-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_ASSET_EBA_CURRENT');
create table AMC.TABLE_ASSET_EBA_CURRENT like CALC.VIEW_ASSET_EBA distribute by hash (ASSET_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_ASSET_EBA_CURRENT_ASSET_ID on AMC.TABLE_ASSET_EBA_CURRENT (ASSET_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_ASSET_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- Archiv-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_ASSET_EBA_ARCHIVE');
create table AMC.TABLE_ASSET_EBA_ARCHIVE like CALC.VIEW_ASSET_EBA distribute by hash (ASSET_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_ASSET_EBA_ARCHIVE_ASSET_ID on AMC.TABLE_ASSET_EBA_ARCHIVE (ASSET_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_ASSET_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_ASSET_EBA_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_ASSET_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------


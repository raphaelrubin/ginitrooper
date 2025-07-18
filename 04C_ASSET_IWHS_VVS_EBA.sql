-- View erstellen
drop view CALC.VIEW_ASSET_IWHS_VVS_EBA;
create or replace view CALC.VIEW_ASSET_IWHS_VVS_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
---- Quelldaten
IWHS_VO as (
    select *
    from NLB.IWHS_VO_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
IWHS_FV as (
    select *
    from NLB.IWHS_FREMDE_VEREINBARUNG_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
IWHS_ES as (
    select *
    from NLB.IWHS_EIGENTUEMER_UND_SICHERHEITENVERR_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
---- Logik
-- PNR aggregiert je VMGO_NR
PNR_AGG as (
    select CUT_OFF_DATE,
           VMGO_NR,
           LISTAGG(PNR_EIGENTUEMER, ', ') within group (order by PNR_EIGENTUEMER) as PNR_EIGENTUEMER
    from (select distinct CUT_OFF_DATE,
                          VMGO_NR,
                          PNR_EIGENTUEMER
          from IWHS_ES)
    group by CUT_OFF_DATE, VMGO_NR
),
-- FV Fremde und Verbundpartner in einheitliche Felder zusammenführen
FV_FLDS as (
    select CUT_OFF_DATE,
           VMGO_NR,
           VERSICHERER,
           NVL(FRMD_VERSICHERUNGSNR, cast(VP_VERTRAGS_NR as VARCHAR(500))) as VERSICHERUNGSNR,
           FRMD_VERSICHERUNGSSUMME_ERBELEBSFALL,
           NVL(FRMD_VERSICHERUNGSSUMME_TOD, VERSICHERUNGSSUMME_TOD)        as VERSICHERUNGSSUMME_TOD,
           FRMD_ABLAUFLEISTUNG,
           FRMD_ART_LEBENSVERSICHERUNG                                     as ART_LEBENSVERSICHERUNG,
           FRMD_LAUFZEITBEGINN                                             as LAUFZEITBEGINN
    from IWHS_FV
    where NVL(FRMD_VERSICHERUNGSSUMME_TOD, VERSICHERUNGSSUMME_TOD) is not null
),
-- Vorberechnungen full outer join für
PNR_FV as (
    select NVL(PNR.CUT_OFF_DATE, FV.CUT_OFF_DATE) as CUT_OFF_DATE,
           NVL(PNR.VMGO_NR, FV.VMGO_NR)           as VMGO_NR,
           PNR.PNR_EIGENTUEMER,
           FV.VERSICHERER,
           FV.VERSICHERUNGSNR,
           FV.FRMD_VERSICHERUNGSSUMME_ERBELEBSFALL,
           FV.VERSICHERUNGSSUMME_TOD,
           FV.FRMD_ABLAUFLEISTUNG,
           FV.ART_LEBENSVERSICHERUNG,
           FV.LAUFZEITBEGINN
    from PNR_AGG PNR
             full outer join FV_FLDS FV on PNR.VMGO_NR = FV.VMGO_NR
),
-- Alles zusammenführen
FINAL as (
    select distinct VO.CUT_OFF_DATE,
                    VO.VMGO_NR                           as ASSET_ID,
                    VMGO_PRODUKTNAME,
                    IMMOBILIENART,
                    IMMOBILIENUNTERART,
                    IMO_NTZG_ART,
                    NORDLB_IMO_ART,
                    VMGO_OBJ_STRASSE,
                    VMGO_HAUS_NR,
                    VMGO_PLZ,
                    VMGO_OBJ_ORT,
                    VMGO_ISO_LAND_CODE,
                    PNR_EIGENTUEMER,
                    VMGO_WTEM_GRDL_DTM,
                    VMGO_WERT_MRKT,
                    VMGO_WERT_MRKT_DTM,
                    VMGO_WERT_VKHR,
                    VMGO_WERT_VKHR_FW,
                    VMGO_WERT_BELH,
                    VMGO_WERT_BELH_FW,
                    VMGO_BLGR_PERS,
                    VMGO_BLGR_PERS_FW,
                    VMGO_BLGR_PERS_PRZ,
                    VMGO_BLGR_REAL,
                    VMGO_BLGR_REAL_FW,
                    VMGO_BLGR_REAL_PRZ,
                    VMGO_BLGR_WSFT,
                    VMGO_BLGR_WSFT_FW,
                    VMGO_BLGR_WSFT_PRZ,
                    VMGO_BLGR_BSIG_PRIV,
                    VMGO_BLGR_BSIG,
                    VMGO_BLWT_HKFT,
                    VMGO_BLST_VWRT,
                    VMGO_BLST_VWRT_FW,
                    VMGO_BLST_VWRT_DTM,
                    VMGO_WERT_BSIS,
                    VMGO_ABSG_BTRG,
                    VMGO_ABSG_BTRG_SUM,
                    VMGO_ABSG_TN,
                    VMGO_ABSG_ADTM,
                    SIHT_UEBW_LDTM,
                    SIHT_PRFG_LDTM,
                    IMO_ENRG_AUSW_KZ,
                    IMO_ENRG_AUSW_DTM,
                    IMO_ENGE_KLSS,
                    KURZBESCHREIBUNG                     as ENERGIESTANDARD,
                    IMO_ENRG_TRG_1_MM,
                    IMO_ENRG_TRG_2_MM,
                    VERSICHERER                          as LV_VERSICHERER,
                    VERSICHERUNGSNR                      as LV_VERSICHERUNGSNR,
                    ART_LEBENSVERSICHERUNG               as LV_ART_LEBENSVERSICHERUNG,
                    LAUFZEITBEGINN                       as LV_LAUFZEITBEGINN,
                    VERSICHERUNGSSUMME_TOD               as LV_VERSICHERUNGSSUMME_TOD,
                    FRMD_VERSICHERUNGSSUMME_ERBELEBSFALL as LV_FRMD_VERSICHERUNGSSUMME_ERBELEBSFALL,
                    FRMD_ABLAUFLEISTUNG                  as LV_FRMD_ABLAUFLEISTUNG
    from IWHS_VO VO
             left join PNR_FV on VO.VMGO_NR = PNR_FV.VMGO_NR
),
-- Gefiltert nach noetigen Datenfeldern
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        ASSET_ID,
        VMGO_PRODUKTNAME,
        IMMOBILIENART,
        IMMOBILIENUNTERART,
        IMO_NTZG_ART,
        NORDLB_IMO_ART,
        VMGO_OBJ_STRASSE,
        VMGO_HAUS_NR,
        VMGO_PLZ,
        VMGO_OBJ_ORT,
        VMGO_ISO_LAND_CODE,
        PNR_EIGENTUEMER,
        VMGO_WTEM_GRDL_DTM,
        VMGO_WERT_MRKT,
        VMGO_WERT_MRKT_DTM,
        VMGO_WERT_VKHR,
        VMGO_WERT_VKHR_FW,
        VMGO_WERT_BELH,
        VMGO_WERT_BELH_FW,
        VMGO_BLGR_PERS,
        VMGO_BLGR_PERS_FW,
        VMGO_BLGR_PERS_PRZ,
        VMGO_BLGR_REAL,
        VMGO_BLGR_REAL_FW,
        VMGO_BLGR_REAL_PRZ,
        VMGO_BLGR_WSFT,
        VMGO_BLGR_WSFT_FW,
        VMGO_BLGR_WSFT_PRZ,
        VMGO_BLGR_BSIG_PRIV,
        VMGO_BLGR_BSIG,
        VMGO_BLWT_HKFT,
        VMGO_BLST_VWRT,
        VMGO_BLST_VWRT_FW,
        VMGO_BLST_VWRT_DTM,
        VMGO_WERT_BSIS,
        VMGO_ABSG_BTRG,
        VMGO_ABSG_BTRG_SUM,
        VMGO_ABSG_TN,
        VMGO_ABSG_ADTM,
        SIHT_UEBW_LDTM,
        SIHT_PRFG_LDTM,
        IMO_ENRG_AUSW_KZ,
        IMO_ENRG_AUSW_DTM,
        IMO_ENGE_KLSS,
        ENERGIESTANDARD,
        IMO_ENRG_TRG_1_MM,
        IMO_ENRG_TRG_2_MM,
        LV_VERSICHERER,
        LV_VERSICHERUNGSNR,
        LV_ART_LEBENSVERSICHERUNG,
        LV_LAUFZEITBEGINN,
        LV_VERSICHERUNGSSUMME_TOD,
        LV_FRMD_VERSICHERUNGSSUMME_ERBELEBSFALL,
        LV_FRMD_ABLAUFLEISTUNG,
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
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_ASSET_IWHS_VVS_EBA_CURRENT');
create table AMC.TABLE_ASSET_IWHS_VVS_EBA_CURRENT like CALC.VIEW_ASSET_IWHS_VVS_EBA distribute by hash (ASSET_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_ASSET_IWHS_VVS_EBA_CURRENT_ASSET_ID on AMC.TABLE_ASSET_IWHS_VVS_EBA_CURRENT (ASSET_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_ASSET_IWHS_VVS_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_ASSET_IWHS_VVS_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------


-- View erstellen
drop view CALC.VIEW_COLLATERAL_EBA;
-- Haupttabelle Collateral EBA
create or replace view CALC.VIEW_COLLATERAL_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
---- Quelldaten
PWC_COLL as (
    select *
    from CALC.SWITCH_COLLATERAL_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
CMS_COLL as (
    select *
    from CALC.SWITCH_COLLATERAL_CMS_EBA_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
IWHS_VVS_COLL as (
    select *
    from CALC.SWITCH_COLLATERAL_IWHS_VVS_EBA_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- Alles zusammenführen
FINAL as (
    select distinct PWC.CUT_OFF_DATE,
                    PWC.COLLATERAL_ID,
                    CMS.SV_ART                         as CMS_SV_ART,
                    CMS.SV_TYP                         as CMS_SV_TYP,
                    CMS.SV_NOMINALWERT                 as CMS_SV_NOMINALWERT,
                    CMS.SV_NOMINALWERT_CURRENCY        as CMS_SV_NOMINALWERT_CURRENCY,
                    CMS.SV_NOMINALWERT_CURRENCY_OC     as CMS_SV_NOMINALWERT_CURRENCY_OC,
                    CMS.SV_ANZUSETZ_WERT               as CMS_SV_ANZUSETZ_WERT,
                    CMS.SV_ANZUSETZ_WERT_CURRENCY      as CMS_SV_ANZUSETZ_WERT_CURRENCY,
                    CMS.SV_ANZUSETZ_WERT_CURRENCY_OC   as CMS_SV_ANZUSETZ_WERT_CURRENCY_OC,
                    CMS.SV_ANWENDBARES_RECHT           as CMS_SV_ANWENDBARES_RECHT,
                    CMS.SV_AUSFBUERGSCHAFT             as CMS_SV_AUSFBUERGSCHAFT,
                    CMS.SV_AUSFALLBUERG_PROZ           as CMS_SV_AUSFALLBUERG_PROZ,
                    CMS.SV_BUERG_BELEIHSATZ_PROZ       as CMS_SV_BUERG_BELEIHSATZ_PROZ,
                    CMS.SV_GUELTIG_VON                 as CMS_SV_GUELTIG_VON,
                    CMS.SV_GUELTIG_BIS                 as CMS_SV_GUELTIG_BIS,
                    CMS.SV_HOECHSTBETRBUERG            as CMS_SV_HOECHSTBETRBUERG,
                    CMS.SV_VERBUERGUNGSSATZ_PROZ       as CMS_SV_VERBUERGUNGSSATZ_PROZ,
                    CMS.SV_GUARANTORS                  as CMS_SV_GUARANTORS,
                    VVS.SIRE_PRODUKTNAME               as VVS_SIRE_PRODUKTNAME,
                    VVS.VMGO_PRODUKTNAME               as VVS_VMGO_PRODUKTNAME,
                    VVS.SICHERHEITENSCHLUESSEL         as VVS_SICHERHEITENSCHLUESSEL,
                    VVS.SICHERUNGSRECHT_ART            as VVS_SICHERUNGSRECHT_ART,
                    VVS.SIRE_ART_ELEMENTAR             as VVS_SIRE_ART_ELEMENTAR,
                    VVS.SICHERHEIT_BEFRISTET_BIS       as VVS_SICHERHEIT_BEFRISTET_BIS,
                    VVS.NOMINALWERT_SICHERHEIT         as VVS_NOMINALWERT_SICHERHEIT,
                    VVS.NOMINALWERT_SICHERHEIT_FW      as VVS_NOMINALWERT_SICHERHEIT_FW,
                    VVS.SICHERHEITENBETRAG             as VVS_SICHERHEITENBETRAG,
                    VVS.FORDERUNGSBETRAG               as VVS_FORDERUNGSBETRAG,
                    VVS.URSPRUNGSWAEHRUNG              as VVS_URSPRUNGSWAEHRUNG,
                    VVS.FORDERUNGSWERT                 as VVS_FORDERUNGSWERT,
                    VVS.SICHERHEITENWERT_PERSONAL      as VVS_SICHERHEITENWERT_PERSONAL,
                    VVS.SICHERHEITENWERT_REAL          as VVS_SICHERHEITENWERT_REAL,
                    VVS.SICHERHEITENWERT_WIRTSCHFTLICH as VVS_SICHERHEITENWERT_WIRTSCHFTLICH,
                    VVS.SICHERHEITENWERT_BLANKO        as VVS_SICHERHEITENWERT_BLANKO,
                    VVS.SICHERHEITENWERT_FREI          as VVS_SICHERHEITENWERT_FREI,
                    VVS.GPFR_NTRT_ASLF_PROZ            as VVS_GPFR_NTRT_ASLF_PROZ,
                    VVS.GPFR_NTRT_ASLF_BTRG            as VVS_GPFR_NTRT_ASLF_BTRG,
                    VVS.SIBB_MAX_REAL                  as VVS_SIBB_MAX_REAL,
                    VVS.SIBB_MAX_PERS                  as VVS_SIBB_MAX_PERS,
                    VVS.SIBB_MAX_WSFT                  as VVS_SIBB_MAX_WSFT,
                    VVS.SIRE_AFTL_PROZ                 as VVS_SIRE_AFTL_PROZ,
                    VVS.SIHT_GSI_KWG_SCHL              as VVS_SIHT_GSI_KWG_SCHL
    from PWC_COLL PWC
             left join CMS_COLL CMS on PWC.SOURCE = 'CMS' and PWC.COLLATERAL_ID = cast(CMS.COLLATERAL_ID as VARCHAR(32))
             left join IWHS_VVS_COLL VVS on PWC.SOURCE = 'IWHS' and PWC.COLLATERAL_ID = VVS.COLLATERAL_ID
),
-- Gefiltert nach noetigen Datenfeldern
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        NULLIF(COLLATERAL_ID, null)                      as COLLATERAL_ID,
        NULLIF(CMS_SV_ART, null)                         as CMS_SV_ART,
        NULLIF(CMS_SV_TYP, null)                         as CMS_SV_TYP,
        NULLIF(CMS_SV_NOMINALWERT, null)                 as CMS_SV_NOMINALWERT,
        NULLIF(CMS_SV_NOMINALWERT_CURRENCY, null)        as CMS_SV_NOMINALWERT_CURRENCY,
        NULLIF(CMS_SV_NOMINALWERT_CURRENCY_OC, null)     as CMS_SV_NOMINALWERT_CURRENCY_OC,
        NULLIF(CMS_SV_ANZUSETZ_WERT, null)               as CMS_SV_ANZUSETZ_WERT,
        NULLIF(CMS_SV_ANZUSETZ_WERT_CURRENCY, null)      as CMS_SV_ANZUSETZ_WERT_CURRENCY,
        NULLIF(CMS_SV_ANZUSETZ_WERT_CURRENCY_OC, null)   as CMS_SV_ANZUSETZ_WERT_CURRENCY_OC,
        NULLIF(CMS_SV_ANWENDBARES_RECHT, null)           as CMS_SV_ANWENDBARES_RECHT,
        NULLIF(CMS_SV_AUSFBUERGSCHAFT, null)             as CMS_SV_AUSFBUERGSCHAFT,
        NULLIF(CMS_SV_AUSFALLBUERG_PROZ, null)           as CMS_SV_AUSFALLBUERG_PROZ,
        NULLIF(CMS_SV_BUERG_BELEIHSATZ_PROZ, null)       as CMS_SV_BUERG_BELEIHSATZ_PROZ,
        NULLIF(CMS_SV_GUELTIG_VON, null)                 as CMS_SV_GUELTIG_VON,
        NULLIF(CMS_SV_GUELTIG_BIS, null)                 as CMS_SV_GUELTIG_BIS,
        NULLIF(CMS_SV_HOECHSTBETRBUERG, null)            as CMS_SV_HOECHSTBETRBUERG,
        NULLIF(CMS_SV_VERBUERGUNGSSATZ_PROZ, null)       as CMS_SV_VERBUERGUNGSSATZ_PROZ,
        NULLIF(CMS_SV_GUARANTORS, null)                  as CMS_SV_GUARANTORS,
        NULLIF(VVS_SIRE_PRODUKTNAME, null)               as VVS_SIRE_PRODUKTNAME,
        NULLIF(VVS_VMGO_PRODUKTNAME, null)               as VVS_VMGO_PRODUKTNAME,
        NULLIF(VVS_SICHERHEITENSCHLUESSEL, null)         as VVS_SICHERHEITENSCHLUESSEL,
        NULLIF(VVS_SICHERUNGSRECHT_ART, null)            as VVS_SICHERUNGSRECHT_ART,
        NULLIF(VVS_SIRE_ART_ELEMENTAR, null)             as VVS_SIRE_ART_ELEMENTAR,
        NULLIF(VVS_SICHERHEIT_BEFRISTET_BIS, null)       as VVS_SICHERHEIT_BEFRISTET_BIS,
        NULLIF(VVS_Nominalwert_Sicherheit, null)         as VVS_Nominalwert_Sicherheit,
        NULLIF(VVS_Nominalwert_Sicherheit_FW, null)      as VVS_Nominalwert_Sicherheit_FW,
        NULLIF(VVS_SICHERHEITENBETRAG, null)             as VVS_SICHERHEITENBETRAG,
        NULLIF(VVS_FORDERUNGSBETRAG, null)               as VVS_FORDERUNGSBETRAG,
        NULLIF(VVS_URSPRUNGSWAEHRUNG, null)              as VVS_URSPRUNGSWAEHRUNG,
        NULLIF(VVS_FORDERUNGSWERT, null)                 as VVS_FORDERUNGSWERT,
        NULLIF(VVS_SICHERHEITENWERT_PERSONAL, null)      as VVS_SICHERHEITENWERT_PERSONAL,
        NULLIF(VVS_SICHERHEITENWERT_REAL, null)          as VVS_SICHERHEITENWERT_REAL,
        NULLIF(VVS_SICHERHEITENWERT_WIRTSCHFTLICH, null) as VVS_SICHERHEITENWERT_WIRTSCHFTLICH,
        NULLIF(VVS_SICHERHEITENWERT_BLANKO, null)        as VVS_SICHERHEITENWERT_BLANKO,
        NULLIF(VVS_SICHERHEITENWERT_FREI, null)          as VVS_SICHERHEITENWERT_FREI,
        NULLIF(VVS_GPFR_NTRT_ASLF_PROZ, null)            as VVS_GPFR_NTRT_ASLF_PROZ,
        NULLIF(VVS_GPFR_NTRT_ASLF_BTRG, null)            as VVS_GPFR_NTRT_ASLF_BTRG,
        NULLIF(VVS_SIBB_MAX_REAL, null)                  as VVS_SIBB_MAX_REAL,
        NULLIF(VVS_SIBB_MAX_PERS, null)                  as VVS_SIBB_MAX_PERS,
        NULLIF(VVS_SIBB_MAX_WSFT, null)                  as VVS_SIBB_MAX_WSFT,
        NULLIF(VVS_SIRE_AFTL_PROZ, null)                 as VVS_SIRE_AFTL_PROZ,
        NULLIF(VVS_SIHT_GSI_KWG_SCHL, null)              as VVS_SIHT_GSI_KWG_SCHL,
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
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_COLLATERAL_EBA_CURRENT');
create table AMC.TABLE_COLLATERAL_EBA_CURRENT like CALC.VIEW_COLLATERAL_EBA distribute by hash (COLLATERAL_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_COLLATERAL_EBA_CURRENT_COLLATERAL_ID on AMC.TABLE_COLLATERAL_EBA_CURRENT (COLLATERAL_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_COLLATERAL_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- Archiv-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_COLLATERAL_EBA_ARCHIVE');
create table AMC.TABLE_COLLATERAL_EBA_ARCHIVE like CALC.VIEW_COLLATERAL_EBA distribute by hash (COLLATERAL_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_COLLATERAL_EBA_ARCHIVE_COLLATERAL_ID on AMC.TABLE_COLLATERAL_EBA_ARCHIVE (COLLATERAL_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_COLLATERAL_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_COLLATERAL_EBA_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_COLLATERAL_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------


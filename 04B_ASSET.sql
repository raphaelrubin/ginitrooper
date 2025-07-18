------------------------------------------------------------------------------------------------------------------------
/* Assets
 *
 * Das Collateralization Tape besteht aus 4 Schritten, wovon dieser der vierte zum Ausführen ist.
 * Dieses Tape zeigt die Beziehung zwischen Konten (Facilities), Sicherheitenverträgen (Collaterals) und
 * Vermögensobjekten (Assets) auf.
 *
 * (1) Collateral to (A) Facility/ (B) Client
 * (2) Collaterals
 * (3) Asset to Collateral
 * (4) Assets
 */
------------------------------------------------------------------------------------------------------------------------

-- View erstellen
drop view CALC.VIEW_ASSET;
create or replace view CALC.VIEW_ASSET as
with
    -- Vermögensobjekte aus CMS
    CMS_ASSETS as (
        select * from NLB.CMS_VO_CURRENT where VO_STATUS = 'Rechtlich aktiv'
        union all
        select * from BLB.CMS_VO_CURRENT where VO_STATUS = 'Rechtlich aktiv'
    ),
    -- Vermögensobjekte aus VVS
    IWHS_ASSETS as (
        select * from NLB.IWHS_VO_CURRENT
        --union all
        --select * from BLB.IWHS_VO_CURRENT
    ),
    ASSETS as (
        select cast(VO_ID as VARCHAR(64)) as VO_ID, cast(NULL as VARCHAR(64)) as VO_ID_IWHS, cast(NULL as VARCHAR(32)) as VO_ID_ORACLE,
               VO_BELEIHSATZ1_P, VO_BELEIHSATZ1_T,
               cast(NULL as DOUBLE) as VO_BELEIHSATZ_REAL_P, cast(NULL as DOUBLE) as VO_BELEIHSATZ_REAL_T,
               cast(NULL as DOUBLE) as VO_BELEIHSATZ_PERS_P, cast(NULL as DOUBLE) as VO_BELEIHSATZ_PERS_T,
               cast(NULL as DOUBLE) as VO_BELEIHSATZ_WSFT_P, cast(NULL as DOUBLE) as VO_BELEIHSATZ_WSFT_T,
               cast(NULL as DOUBLE) as LTV_RATIO_DENOMINATOR,
               cast(VO_NOMINAL_WERT as DOUBLE) as VO_NOMINAL_WERT, VO_NOMINAL_WERT_WAEHR,
               cast(VO_ANZUS_WERT as DOUBLE) as VO_ANZUS_WERT, VO_ANZUS_WERT_WAEHR,
               VO_KUST, VO_PAS, VO_TYP, VO_ART, VO_STATUS, VO_CRR_KZ, VO_VOE,
               VO_DECKUNGSKZ_TXS, cast(VO_GEBAEUDE_KZ as VARCHAR(32)) as VO_GEBAEUDE_KZ,
               CUTOFFDATE, 'CMS' as QUELLE, BRANCH
        from CMS_ASSETS
        union all
        -- VVS kennt keine Fremdwährung, daher immer in EUR
        select cast(VMGO_ID_VVS as VARCHAR(64)) as VO_ID, VMGO_ID_IWHS as VO_ID_IWHS, VMGO_ID_ORACLE as VO_ID_ORACLE,
               NULL as VO_BELEIHSATZ1_P, NULL as VO_BELEIHSATZ1_T,
               cast(VMGO_BLGR_REAL_PRZ as DOUBLE) as VO_BELEIHSATZ_REAL_P, cast(VMGO_BLGR_REAL as DOUBLE) as VO_BELEIHSATZ_REAL_T,
               cast(VMGO_BLGR_PERS_PRZ as DOUBLE) as VO_BELEIHSATZ_PERS_P, cast(VMGO_BLGR_PERS as DOUBLE) as VO_BELEIHSATZ_PERS_T,
               cast(VMGO_BLGR_WSFT_PRZ as DOUBLE) as VO_BELEIHSATZ_WSFT_P, cast(VMGO_BLGR_WSFT as DOUBLE) as VO_BELEIHSATZ_WSFT_T,
               cast(VMGO_WERT_VKHR as DOUBLE) as LTV_RATIO_DENOMINATOR,
               cast(VMGO_WERT_VKHR as DOUBLE) as VO_NOMINAL_WERT, 'EUR' as VO_NOMINAL_WERT_WAEHR, cast(VMGO_WERT_BELH as DOUBLE) as VO_ANZUS_WERT, 'EUR' as VO_ANZUS_WERT_WAEHR,
               NULL as VO_KUST, NULL as VO_PAS, IMMOBILIENART as VO_TYP, IMMOBILIENUNTERART as VO_ART, NULL as VO_STATUS, TXS_PFBR_DKNG_ANDG_MM as VO_CRR_KZ, NULL as VO_VOE,
               TXS_PFBR_DKNG_ANDG_MM as VO_DECKUNGSKZ_TXS, cast(NORDLB_IMO_ART as VARCHAR(32)) as VO_GEBAEUDE_KZ,
               CUT_OFF_DATE as CUTOFFDATE, 'IWHS' as QUELLE, BRANCH
        from IWHS_ASSETS
    ),
    data as (
    select distinct
        ASSET.CUTOFFDATE                                                                            as CUT_OFF_DATE,
        ASSET.VO_ID                                                                                 as ASSET_ID,
--      ASSET.VO_ID_IWHS                                                                            as ASSET_ID_IWHS,
--      ASSET.VO_ID_ORACLE                                                                          as ASSET_ID_ORACLE,
        ASSET.VO_TYP                                                                                as ASSET_TYPE,
        ASSET.VO_ART                                                                                as ASSET_DESCRIPTION,
        ASSET.BRANCH                                                                                as BRANCH,
        --------------------------------------------------------------------------------------------------------------------------
        case
            when VO_TYP in ('Schiffe', 'Schiff', 'Flugzeuge', 'Flugzeug', 'Triebwerk') then
                round(VO_ANZUS_WERT / coalesce(RATE_ASSESSMENT_CURRENCY.KURS, 1), 2)
            else
                round(VO_NOMINAL_WERT / coalesce(RATE_NOMINAL_CURRENCY.KURS, 1), 2)
            end                                                                                     as NOMINAL_VALUE_EUR,
        --------------------------------------------------------------------------------------------------------------------------
        case
            when VO_TYP in ('Schiffe', 'Schiff', 'Flugzeuge', 'Flugzeug', 'Triebwerk') then
                round(VO_ANZUS_WERT, 2)
            else
                round(VO_NOMINAL_WERT, 2)
            end                                                                                     as NOMINAL_VALUE_OC,
        --------------------------------------------------------------------------------------------------------------------------
        VO_NOMINAL_WERT_WAEHR                                                                       as NOMINAL_VALUE_CURRENCY,
        round(VO_ANZUS_WERT / coalesce(RATE_ASSESSMENT_CURRENCY.KURS, 1), 2)                        as ASSET_VALUE_EUR,
        round(VO_ANZUS_WERT, 2)                                                                     as ASSET_VALUE_OC,
        VO_ANZUS_WERT_WAEHR                                                                         as ASSET_VALUE_CURRENCY,
        nullif(LTV_RATIO_DENOMINATOR,NULL)                                                          as LTV_RATIO_DENOMINATOR,
        nullif(VO_BELEIHSATZ1_P,NULL)                                                               as LTV_LIMIT_1_PERCENT,
        nullif(VO_BELEIHSATZ1_T,NULL)                                                               as LTV_LIMIT_1,
        nullif(VO_BELEIHSATZ_REAL_P,NULL)                                                           as LTV_LIMIT_REAL_PERCENT,
        nullif(VO_BELEIHSATZ_REAL_T,NULL)                                                           as LTV_LIMIT_REAL,
        nullif(VO_BELEIHSATZ_PERS_P,NULL)                                                           as LTV_LIMIT_PERS_PERCENT,
        nullif(VO_BELEIHSATZ_PERS_T,NULL)                                                           as LTV_LIMIT_PERS,
        nullif(VO_BELEIHSATZ_WSFT_P,NULL)                                                           as LTV_LIMIT_ECON_PERCENT,
        nullif(VO_BELEIHSATZ_WSFT_T,NULL)                                                           as LTV_LIMIT_ECON,
        nullif(VO_KUST,NULL)                                                                        as VO_KUST,
        --,VO_PAS                                                                                   as
        nullif(VO_VOE,NULL)                                                                         as VO_VOE,
        nullif(VO_CRR_KZ,NULL)                                                                      as VO_CRR_KZ,
        nullif(VO_GEBAEUDE_KZ,NULL)                                                                 as BUILDING_TYPE,                   -- nur für Immobilien
        nullif(VO_DECKUNGSKZ_TXS,NULL)                                                              as COVER_STOCK_RELEVANCE,           -- nur für Immobilien
        cast(ASSET.QUELLE as VARCHAR(8))                                                            as SOURCE,                          -- Quellsystem
        Current USER                                                                                as CREATED_USER,                    -- Letzter Nutzer, der dieses Tape gebaut hat.
        Current TIMESTAMP                                                                           as CREATED_TIMESTAMP                -- Neuester Zeitstempel, wann dieses Tape zuletzt gebaut wurde.
    from ASSETS as ASSET
             --inner join AMC.TAPE_SHIP_ASSET_TO_COLLATERAL_CURRENT as A2C
             inner join CALC.SWITCH_ASSET_TO_COLLATERAL_CURRENT as A2C
                        on (ASSET.VO_ID,ASSET.QUELLE) = (A2C.ASSET_ID,A2C.SOURCE) and A2C.CUT_OFF_DATE = ASSET.CUTOFFDATE
             left join IMAP.CURRENCY_MAP as RATE_NOMINAL_CURRENCY
                       on ASSET.VO_NOMINAL_WERT_WAEHR = RATE_NOMINAL_CURRENCY.ZIEL_WHRG and
                          ASSET.CUTOFFDATE = RATE_NOMINAL_CURRENCY.CUT_OFF_DATE
             left join IMAP.CURRENCY_MAP as RATE_ASSESSMENT_CURRENCY
                       on ASSET.VO_ANZUS_WERT_WAEHR = RATE_ASSESSMENT_CURRENCY.ZIEL_WHRG and
                          ASSET.CUTOFFDATE = RATE_ASSESSMENT_CURRENCY.CUT_OFF_DATE
    where VO_STATUS = 'Rechtlich aktiv' or ASSET.QUELLE = 'IWHS'
)
select * from data
;

-- CI START FOR ALL TAPES
-- Current-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_ASSET_CURRENT');
create table AMC.TABLE_ASSET_CURRENT like CALC.VIEW_ASSET distribute by hash(ASSET_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_ASSET_CURRENT_ASSET_ID on AMC.TABLE_ASSET_CURRENT (ASSET_ID);
comment on table AMC.TABLE_ASSET_CURRENT is 'Liste aller Assets, welche an einem der gewünschten Collaterals hängen (Aktueller Stichtag)';
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_ASSET_CURRENT');
-- Archiv-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_ASSET_ARCHIVE');
create table AMC.TABLE_ASSET_ARCHIVE like CALC.VIEW_ASSET distribute by hash(ASSET_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2025' EVERY 1 MONTH) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_ASSET_ARCHIVE_ASSET_ID on AMC.TABLE_ASSET_ARCHIVE (ASSET_ID);
comment on table AMC.TABLE_ASSET_ARCHIVE is 'Liste aller Assets, welche an einem der gewünschten Collaterals hängen (Alle Stichtage)';
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_ASSET_ARCHIVE');
-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_ASSET_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_ASSET_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------
/* Ship Tape (4) Assets
 *
 * Das Ship Tape besteht aus 4 Dateien, wovon diese die vierte zum Ausführen ist.
 * Dieses Tape zeigt die Beziehung zwischen Konten (Facilities), Sicherheitenverträgen (Collaterals) und
 * Vermögensobjekten (Assets) auf.
 *
 * (1) Collateral to Facility
 * (2) Collaterals
 * (3) Asset to Collateral
 * (4) Assets
 */
------------------------------------------------------------------------------------------------------------------------
--
-- select VO_BELEIHSATZ1_P,VO_KUST,VO_PAS,VO_VOE as VO_PAS,VO_CRR_KZ
--     ,VO_GEBAEUDE_KZ -- nur für Immobilien
--     ,VO_DECKUNGSKZ_TXS --nur für Immobilien
-- from NLB.CMS_VO_CURRENT where VO_STATUS = 'Rechtlich aktiv';
--



-- View erstellen
drop view CALC.VIEW_GENERAL_ASSET;
create or replace view CALC.VIEW_GENERAL_ASSET as
with
    -- Vermögensobjekte aus CMS
    CMS_ASSETS as (
        select  *  from NLB.CMS_VO_CURRENT where VO_STATUS = 'Rechtlich aktiv' and VO_TYP not in ('Schiffe','Flugzeuge')
        union all
        select * from BLB.CMS_VO_CURRENT where VO_STATUS = 'Rechtlich aktiv' and VO_TYP not in ('Schiffe','Flugzeuge')
    ),
    data as (
    select distinct CMS_ASSET.CUTOFFDATE                                                                         as CUT_OFF_DATE,
                    VO_ID                                                                                        as ASSET_ID,
                    VO_TYP                                                                                       as ASSET_TYPE,
                    VO_ART                                                                                       as ASSET_DESCRIPTION,
                    CMS_ASSET.BRANCH                                                                             as BRANCH,
                    --------------------------------------------------------------------------------------------------------------------------
                    case
                        when VO_TYP in ('Schiffe', 'Schiff', 'Flugzeuge', 'Flugzeug', 'Triebwerk') then
                            round(VO_ANZUS_WERT / coalesce(RATE_ASSESSMENT_CURRENCY.KURS, 1), 2)
                        else
                            round(VO_NOMINAL_WERT / coalesce(RATE_NOMINAL_CURRENCY.KURS, 1), 2)
                        end                                                                                     as VO_NOMINAL_VALUE_EUR,
                    --------------------------------------------------------------------------------------------------------------------------
                    case
                        when VO_TYP in ('Schiffe', 'Schiff', 'Flugzeuge', 'Flugzeug', 'Triebwerk') then
                            round(VO_ANZUS_WERT, 2)
                        else
                            round(VO_NOMINAL_WERT, 2)
                        end                                                                                     as VO_NOMINAL_VALUE_OC,
                    --------------------------------------------------------------------------------------------------------------------------
                    VO_NOMINAL_WERT_WAEHR                                                                       as VO_NOMINAL_ORIGINAL_CURRENCY,
                    round(VO_ANZUS_WERT / coalesce(RATE_ASSESSMENT_CURRENCY.KURS, 1), 2)                        as VO_ANZUS_VALUE_EUR,
                    round(VO_ANZUS_WERT, 2)                                                                     as VO_ANZUS_VALUE_OC,
                    VO_ANZUS_WERT_WAEHR                                                                         as VO_ANZUS_ORIGINAL_CURRENCY,
                    VO_BELEIHSATZ1_P                                                                            as VO_BELEIHSATZ1_P
                    ,VO_KUST                                                                                    as VO_KUST
                    --,VO_PAS                                                                                   as
                    ,VO_VOE                                                                                     as VO_VOE
                    ,VO_CRR_KZ                                                                                  as VO_CRR_KZ
                    ,VO_GEBAEUDE_KZ                                                                             as VO_GEBAEUDE_KZ                   -- nur für Immobilien
                    ,VO_DECKUNGSKZ_TXS                                                                          as VO_DECKUNGSKZ_TXS                -- nur für Immobilien
                    ,Current USER                                                                               as CREATED_USER                     -- Letzter Nutzer, der dieses Tape gebaut hat.
                    ,Current TIMESTAMP                                                                          as CREATED_TIMESTAMP                -- Neuester Zeitstempel, wann dieses Tape zuletzt gebaut wurde.
    from CMS_ASSETS as CMS_ASSET
             --inner join AMC.TAPE_SHIP_ASSET_TO_COLLATERAL_CURRENT as A2C
             inner join CALC.SWITCH_ASSET_TO_COLLATERAL_CURRENT as A2C
                        on cast(CMS_ASSET.VO_ID as VARCHAR(64)) = cast(A2C.ASSET_ID as VARCHAR(64)) and A2C.CUT_OFF_DATE = CMS_ASSET.CUTOFFDATE
             left join IMAP.CURRENCY_MAP as RATE_NOMINAL_CURRENCY
                       on CMS_ASSET.VO_NOMINAL_WERT_WAEHR = RATE_NOMINAL_CURRENCY.ZIEL_WHRG and
                          CMS_ASSET.CUTOFFDATE = RATE_NOMINAL_CURRENCY.CUT_OFF_DATE
             left join IMAP.CURRENCY_MAP as RATE_ASSESSMENT_CURRENCY
                       on CMS_ASSET.VO_ANZUS_WERT_WAEHR = RATE_ASSESSMENT_CURRENCY.ZIEL_WHRG and
                          CMS_ASSET.CUTOFFDATE = RATE_ASSESSMENT_CURRENCY.CUT_OFF_DATE
    where VO_STATUS = 'Rechtlich aktiv'
)
select * from data
;

-- CI START FOR ALL TAPES
-- Current-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_GENERAL_ASSET_CURRENT');
create table AMC.TABLE_GENERAL_ASSET_CURRENT like CALC.VIEW_GENERAL_ASSET distribute by hash(ASSET_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_GENERAL_ASSET_CURRENT_ASSET_ID on AMC.TABLE_GENERAL_ASSET_CURRENT (ASSET_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_GENERAL_ASSET_CURRENT');
-- Archiv-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_GENERAL_ASSET_ARCHIVE');
create table AMC.TABLE_GENERAL_ASSET_ARCHIVE like AMC.TABLE_GENERAL_ASSET_CURRENT distribute by hash(ASSET_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2025' EVERY 1 MONTH) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_GENERAL_ASSET_ARCHIVE_ASSET_ID on AMC.TABLE_GENERAL_ASSET_ARCHIVE (ASSET_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_GENERAL_ASSET_ARCHIVE');
-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_GENERAL_ASSET_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_GENERAL_ASSET_ARCHIVE');
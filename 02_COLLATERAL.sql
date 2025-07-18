------------------------------------------------------------------------------------------------------------------------
/* Collaterals
 *
 * Das Collateralization Tape besteht aus 4 Schritten, wovon dieser der zweite zum Ausführen ist.
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
drop view CALC.VIEW_COLLATERAL;
create or replace view CALC.VIEW_COLLATERAL as
with
CMS_COLLATERALS as (
    select * from NLB.CMS_SV_CURRENT
    union all
    select * from BLB.CMS_SV_CURRENT
),
IWHS_COLLATERALS as (
    select * from NLB.IWHS_SV_CURRENT
    --union all
    --select * from BLB.IWHS_SV_CURRENT
),
COLLATERALS as (
    select CUTOFFDATE, 'CMS' as QUELLE, BRANCH, cast(SV_ID as VARCHAR(32)) as SV_ID, NULL as SV_ID_ORACLE, SV_AUSPLATZIERT, SV_TYP, SV_TYP as SV_SUBTYP, SV_ART, SV_STATUS, SV_CRR_KZ, SV_BESCHREIBUNG, SV_GUELTIG_VON, SV_GUELTIG_BIS, SV_BERECHTBEREICH, SV_CRR_HIND_GRUND, SV_CRR_HIND_GRUND_BEM, SV_ANWENDBARES_RECHT,
           SV_NOMINALWERT, SV_NOMINALWERT_WAEHR, SV_ANZUSETZ_WERT, SV_ANZUSETZ_WERT_WAEHR, SV_WERT_VWERT_PROZENT, SV_KUST, VO_PAS, SV_VERWALT_OE, SV_VERBUERGUNGSSATZ_PROZ, SV_HOECHSTBETRBUERG, SV_SELBSTSCH_BUERG, SV_AUSFBUERGSCHAFT, SV_AUSFALLBUERG_PROZ, SV_BEHOERDL_GENEHMIG, SV_KREDITEREIGNIS, SV_BUERG_BELEIHSATZ_PROZ, SV_ABTRETG_ANGEZEIGT, SV_EDR_VERFUEG_BETR, SV_EDR_VERFBETR_WAEHR, SV_GESAMTGRUNDSCHULD,
           NULL as LTV_RATIO, NULL as LTV_RATIO_NUMERATOR, NULL as DEBIT_MAX_REAL, NULL as DEBIT_MAX_PERS, NULL as DEBIT_MAX_ECON, NULL as CLAIM_AMOUNT, NULL as NORDLB_SHARE_PERCENT
    from CMS_COLLATERALS
    union all
    select CUT_OFF_DATE as CUTOFFDATE, 'IWHS' as QUELLE, BRANCH, SIRE_ID_IWHS as SV_ID, SIRE_ID_ORACLE as SV_ID_ORACLE, NULL as SV_AUSPLATZIERT, SIRE_ART as SV_TYP, SIRE_ART_ELEMENTAR as SV_SUBTYP, SICHERHEITENSCHLUESSEL as SV_ART, NULL as SV_STATUS, SIHT_GSI_KWG_SCHL as SV_CRR_KZ, SIRE_BZNG as SV_BESCHREIBUNG, NULL as SV_GUELTIG_VON, NULL as SV_GUELTIG_BIS, NULL as SV_BERECHTBEREICH, SIHT_GSI_KWG_SCHL as SV_CRR_HIND_GRUND, NULL as SV_CRR_HIND_GRUND_BEM, NULL as SV_ANWENDBARES_RECHT,
           SIRE_WERT_NOM as SV_NOMINALWERT, SIRE_WERT_WS_URSP as SV_NOMINALWERT_WAEHR, SICHERHEITENBETRAG as SV_ANZUSETZ_WERT, SIRE_WERT_WS_URSP as SV_ANZUSETZ_WERT_WAEHR, NULL as SV_WERT_VWERT_PROZENT, NULL as SV_KUST, NULL as VO_PAS, NULL as SV_VERWALT_OE, NULL as SV_VERBUERGUNGSSATZ_PROZ, NULL as SV_HOECHSTBETRBUERG, NULL as SV_SELBSTSCH_BUERG, NULL as SV_AUSFBUERGSCHAFT, NULL as SV_AUSFALLBUERG_PROZ, NULL as SV_BEHOERDL_GENEHMIG, NULL as SV_KREDITEREIGNIS, NULL as SV_BUERG_BELEIHSATZ_PROZ, NULL as SV_ABTRETG_ANGEZEIGT, NULL as SV_EDR_VERFUEG_BETR, NULL as SV_EDR_VERFBETR_WAEHR, NULL as SV_GESAMTGRUNDSCHULD,
           GPFR_NTRT_ASLF_PROZ as LTV_RATIO, GPFR_NTRT_ASLF_BTRG as LTV_RATIO_NUMERATOR, SIBB_MAX_REAL as DEBIT_MAX_REAL, SIBB_MAX_PERS as DEBIT_MAX_PERS, SIBB_MAX_WSFT as DEBIT_MAX_ECON, VERAENDERUNGSBETRAG as CLAIM_AMOUNT, SIRE_AFTL_PROZ as NORDLB_SHARE_PERCENT
    from IWHS_COLLATERALS
),
COLLATERALS_DESIRED as (
    select distinct CUT_OFF_DATE, COLLATERAL_ID, SOURCE from
     (
         select CUT_OFF_DATE, COLLATERAL_ID, DATA_SOURCE as SOURCE
         from CALC.SWITCH_COLLATERAL_TO_FACILITY_CURRENT
         union all
         select CUT_OFF_DATE, COLLATERAL_ID, SOURCE
         from CALC.SWITCH_COLLATERAL_TO_CLIENT_CURRENT
     )
),
KO2SV_CMS_NLB as (
    select
        cast(SV_ID as VARCHAR(32)) as SV_ID,
        CUTOFFDATE,
        BRANCH,
        MAX_RISK_SV_ZUR_VERT as MAX_RISK_SV_ZUR_VERT_IN_EUR  -- Der verteilte Scherheitenwert sämtlicher Forderungen (belibigerer Kunden) durch den Rechenkern CMS in EUR
    from NLB.CMS_LINK_CURRENT
),
KO2SV_CMS_BLB as (
    select
        cast(SV_ID as VARCHAR(32)) as SV_ID,
        CUTOFFDATE,
        BRANCH,
        MAX_RISK_SV_ZUR_VERT as MAX_RISK_SV_ZUR_VERT_IN_EUR  -- Der verteilte Scherheitenwert sämtlicher Forderungen (belibigerer Kunden) durch den Rechenkern CMS in EUR
    from BLB.CMS_LINK_CURRENT
),
KO2SV_CMS as (
     select * from KO2SV_CMS_BLB
        union all
     select * from KO2SV_CMS_NLB
),
SHARES_CMS_NLB as (
    select distinct
        KO2SV_CMS_NLB.CUTOFFDATE            as CUT_OFF_DATE,
        KO2SV_CMS_NLB.SV_ID                 as SV_ID,
        KO2SV_CMS_NLB.TEILWERT_PROZ         as PART_SHARE_PERCENT,
        KO2SV_CMS_NLB.SV_TEIL_ID            as PART_ID,
        KO2SV_CMS_NLB.TEILWERT_BETRAG       as PART_VALUE,
        KO2SV_CMS_NLB.TEILWERT_BETRAG_WAEHR as CURRENCY,
        BUSINESS_PARTNER.PARTNER_ID, -- für Lux Abgleich
        BUSINESS_PARTNER.PARTNER_NAME_1,
        KO2SV_CMS_NLB.TEIL_EINSCHRAENKUNG
    from NLB.CMS_LINK_CURRENT       as KO2SV_CMS_NLB
    left join NLB.CMS_GP_CURRENT    as BUSINESS_PARTNER   on BUSINESS_PARTNER.CUTOFFDATE = KO2SV_CMS_NLB.CUTOFFDATE
                                              and left(KO2SV_CMS_NLB.SV_ID, 15) = left(BUSINESS_PARTNER.CMS_ID, 15)
                                              and KO2SV_CMS_NLB.SV_TEIL_ID = BUSINESS_PARTNER.CMS_SUB_ID
    where SV_STATUS = 'Rechtlich aktiv'
),
SHARES_CMS_BLB as (
    select distinct
        KO2SV_CMS_BLB.CUTOFFDATE            as CUT_OFF_DATE,
        KO2SV_CMS_BLB.SV_ID                 as SV_ID,
        KO2SV_CMS_BLB.TEILWERT_PROZ         as PART_SHARE_PERCENT,
        KO2SV_CMS_BLB.SV_TEIL_ID            as PART_ID,
        KO2SV_CMS_BLB.TEILWERT_BETRAG       as PART_VALUE,
        KO2SV_CMS_BLB.TEILWERT_BETRAG_WAEHR as CURRENCY,
        BUSINESS_PARTNER.PARTNER_ID, -- für Lux Abgleich
        BUSINESS_PARTNER.PARTNER_NAME_1,
        KO2SV_CMS_BLB.TEIL_EINSCHRAENKUNG
    from BLB.CMS_LINK_CURRENT       as KO2SV_CMS_BLB
    left join BLB.CMS_GP_CURRENT    as BUSINESS_PARTNER   on BUSINESS_PARTNER.CUTOFFDATE = KO2SV_CMS_BLB.CUTOFFDATE
                                        and left(KO2SV_CMS_BLB.SV_ID, 15) = left(BUSINESS_PARTNER.CMS_ID, 15)
                                        and KO2SV_CMS_BLB.SV_TEIL_ID = BUSINESS_PARTNER.CMS_SUB_ID
    where SV_STATUS = 'Rechtlich aktiv'
),
SHARES_CMS as (
    select * from SHARES_CMS_NLB
    union all
    select * from SHARES_CMS_BLB
),
SHARES_AOER as (
    select distinct
        CUT_OFF_DATE,
        cast(SV_ID as VARCHAR(32)) as SV_ID,
        max(PART_SHARE_PERCENT)       as MAX_SHARE,
        SUM(PART_VALUE)               as TOTAL_VALUE
    from SHARES_CMS where TEIL_EINSCHRAENKUNG is null
    group by SV_ID, CUT_OFF_DATE, CURRENCY
),
SHARES_CBB as (
    select distinct
         CUT_OFF_DATE,
         cast(SV_ID as VARCHAR(32)) as SV_ID,
         max(PART_SHARE_PERCENT)       as MAX_SHARE,
         SUM(PART_VALUE)               as TOTAL_VALUE
         --SUM(AKT_VERTEILTER_WERT_PRE) as LUX_AKT_VERTEILTER_WERT,   hier scheinbar nicht relevant?
         --SUM(AKT_ZU_BES_WERT_PRE)     as LUX_AKT_ZU_BES_WERT        hier scheinbar nicht relevant?
    from SHARES_CMS where PARTNER_ID = '8595462'
    group by SV_ID, CUT_OFF_DATE, CURRENCY
)
select distinct
    COLLATERAL.CUTOFFDATE                                                                                                                                as CUT_OFF_DATE,
    cast(COLLATERAL.SV_ID as VARCHAR(32))                                                                                                                as COLLATERAL_ID,
    cast(COLLATERAL.SV_ID_ORACLE as VARCHAR(64))                                                                                                         as COLLATERAL_ID_ORACLE,
    -- Kategorisierung
    COLLATERAL.SV_TYP                                                                                                                                    as COLLATERAL_TYPE,
    COLLATERAL.SV_SUBTYP                                                                                                                                 as COLLATERAL_SUBTYPE,
    COLLATERAL.SV_ART                                                                                                                                    as COLLATERAL_DESCRIPTION,
    -- Werte
    COLLATERAL.SV_NOMINALWERT * coalesce(NOMINAL_WERT_EXCHANGE.RATE_TARGET_TO_EUR,1.000)                                                                 as NOMINAL_VALUE_EUR,
    COLLATERAL.SV_NOMINALWERT                                                                                                                            as NOMINAL_VALUE_OC,
    cast(COLLATERAL.SV_NOMINALWERT_WAEHR as VARCHAR(3))                                                                                                  as NOMINAL_VALUE_ORIGINAL_CURRENCY,
    nullif(NOMINAL_WERT_EXCHANGE.KURS,null)                                                                                                                           as NOMINAL_EXCHANGE_RATE,
    CALC.convert2eur(double(COLLATERAL.SV_ANZUSETZ_WERT),double(coalesce(ANZUSETZENDER_WERT_EXCHANGE.KURS,1.000)),COLLATERAL.SV_ANZUSETZ_WERT_WAEHR) as COLLATERAL_VALUE_EUR,
    COLLATERAL.SV_ANZUSETZ_WERT                                                                                                                          as COLLATERAL_VALUE_OC,
    cast(COLLATERAL.SV_ANZUSETZ_WERT_WAEHR as VARCHAR(3))                                                                                                as COLLATERAL_VALUE_ORIGINAL_CURRENCY,
    nullif(ANZUSETZENDER_WERT_EXCHANGE.KURS,null)                                                                                                                     as COLLATERAL_EXCHANGE_RATE,
    COLLATERAL.CLAIM_AMOUNT,
    COLLATERAL.LTV_RATIO,
    COLLATERAL.LTV_RATIO_NUMERATOR,
    -- Anteile
    coalesce(COLLATERAL.NORDLB_SHARE_PERCENT,NLB_SHARE.MAX_SHARE)/100                                                                                                       as NORDLB_SHARE_PERCENT,
    (coalesce(NLB_SHARE.TOTAL_VALUE,0) + coalesce(coalesce(COLLATERAL.NORDLB_SHARE_PERCENT,NLB_SHARE.MAX_SHARE),0)/100.*COLLATERAL.SV_ANZUSETZ_WERT) * coalesce(ANZUSETZENDER_WERT_EXCHANGE.RATE_TARGET_TO_EUR,1.000) as NORDLB_SHARE_EUR,
    (coalesce(NLB_SHARE.TOTAL_VALUE,0) + coalesce(coalesce(COLLATERAL.NORDLB_SHARE_PERCENT,NLB_SHARE.MAX_SHARE),0)/100.*COLLATERAL.SV_ANZUSETZ_WERT)                                                                  as NORDLB_SHARE_OC,
    cast(COLLATERAL.SV_NOMINALWERT_WAEHR as VARCHAR(3))                                                                                                                                                               as NORDLB_SHARE_ORIGINAL_CURRENCY,
    nullif(ANZUSETZENDER_WERT_EXCHANGE.KURS,null)                                                                                                                                        as NORDLB_SHARE_EXCHANGE_RATE,
    (coalesce(LUX_SHARE.TOTAL_VALUE,0) + coalesce(LUX_SHARE.MAX_SHARE,0)/100.*COLLATERAL.SV_ANZUSETZ_WERT) * coalesce(ANZUSETZENDER_WERT_EXCHANGE.RATE_TARGET_TO_EUR,1.000) as LUX_SHARE_EUR,
    (coalesce(LUX_SHARE.TOTAL_VALUE,0) + coalesce(LUX_SHARE.MAX_SHARE,0)/100.*COLLATERAL.SV_ANZUSETZ_WERT)                                                                  as LUX_SHARE_OC,
    -- Anderes
    COLLATERAL.DEBIT_MAX_REAL,
    COLLATERAL.DEBIT_MAX_PERS,
    COLLATERAL.DEBIT_MAX_ECON,
    C2F_CMS.MAX_RISK_SV_ZUR_VERT_IN_EUR,
    COLLATERAL.SV_AUSFBUERGSCHAFT,
    COLLATERAL.SV_AUSFALLBUERG_PROZ,
    COLLATERAL.SV_HOECHSTBETRBUERG,
    COLLATERAL.SV_VERBUERGUNGSSATZ_PROZ,
    COLLATERAL.SV_BUERG_BELEIHSATZ_PROZ,
    COLLATERAL.SV_ANWENDBARES_RECHT,
    COLLATERAL.SV_GESAMTGRUNDSCHULD, -- nur für Immobielien
    COLLATERAL.SV_KUST,
    COLLATERAL.SV_VERWALT_OE,
    COLLATERAL.VO_PAS                                                       as SV_PAS,
    COLLATERAL.SV_CRR_KZ,
    COLLATERAL.BRANCH                                                       as BRANCH,           -- Institut
    nullif(COLLATERAL.QUELLE,null)                                          as SOURCE,
    Current USER                                                            as CREATED_USER,     -- Letzter Nutzer, der dieses Tape gebaut hat.
    Current TIMESTAMP                                                       as CREATED_TIMESTAMP -- Neuester Zeitstempel, wann dieses Tape zuletzt gebaut wurde.
from COLLATERALS                 as COLLATERAL
left join KO2SV_CMS              as C2F_CMS                      on COLLATERAL.SV_ID=C2F_CMS.SV_ID
                                                                    and C2F_CMS.BRANCH=COLLATERAL.BRANCH
                                                                    and C2F_CMS.CUTOFFDATE=COLLATERAL.CUTOFFDATE
inner join COLLATERALS_DESIRED   as COLLATERAL_DESIRED           on (COLLATERAL.SV_ID,COLLATERAL.QUELLE)=(COLLATERAL_DESIRED.COLLATERAL_ID,COLLATERAL_DESIRED.SOURCE)
                                                                    and COLLATERAL_DESIRED.CUT_OFF_DATE=COLLATERAL.CUTOFFDATE
left join IMAP.CURRENCY_MAP      as NOMINAL_WERT_EXCHANGE        on NOMINAL_WERT_EXCHANGE.CUT_OFF_DATE = COLLATERAL.CUTOFFDATE
                                                                    and NOMINAL_WERT_EXCHANGE.ZIEL_WHRG = COLLATERAL.SV_NOMINALWERT_WAEHR
left join IMAP.CURRENCY_MAP      as ANZUSETZENDER_WERT_EXCHANGE  on ANZUSETZENDER_WERT_EXCHANGE.CUT_OFF_DATE = COLLATERAL.CUTOFFDATE
                                                                    and ANZUSETZENDER_WERT_EXCHANGE.ZIEL_WHRG = COLLATERAL.SV_ANZUSETZ_WERT_WAEHR
left join SHARES_AOER            as NLB_SHARE                    on NLB_SHARE.SV_ID=COLLATERAL.SV_ID
                                                                    and NLB_SHARE.CUT_OFF_DATE=COLLATERAL.CUTOFFDATE
left join SHARES_CBB             as LUX_SHARE                    on LUX_SHARE.SV_ID=COLLATERAL.SV_ID
                                                                    and LUX_SHARE.CUT_OFF_DATE=COLLATERAL.CUTOFFDATE
where COLLATERAL.SV_STATUS='Rechtlich aktiv' or COLLATERAL.QUELLE = 'IWHS'
;


-- CI START FOR ALL TAPES
-- Current-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_COLLATERAL_CURRENT');
create table AMC.TABLE_COLLATERAL_CURRENT like CALC.VIEW_COLLATERAL distribute by hash(COLLATERAL_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_COLLATERAL_CURRENT_COLLATERAL_ID on AMC.TABLE_COLLATERAL_CURRENT (COLLATERAL_ID);
comment on table AMC.TABLE_COLLATERAL_CURRENT is 'Liste aller Collaterals, welche an einem der gewünschten Kunden hängen (Aktueller Stichtag)';
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_COLLATERAL_CURRENT');
-- Archiv-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_COLLATERAL_ARCHIVE');
create table AMC.TABLE_COLLATERAL_ARCHIVE like CALC.VIEW_COLLATERAL distribute by hash(COLLATERAL_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2025' EVERY 1 MONTH) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_COLLATERAL_ARCHIVE_COLLATERAL_ID on AMC.TABLE_COLLATERAL_ARCHIVE (COLLATERAL_ID);
comment on table AMC.TABLE_COLLATERAL_ARCHIVE is 'Liste aller Collaterals, welche an einem der gewünschten Kunden (Alle Stichtage)';
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_COLLATERAL_ARCHIVE');
-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_COLLATERAL_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_COLLATERAL_ARCHIVE');
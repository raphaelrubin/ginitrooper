------------------------------------------------------------------------------------------------------------------------
/* Collaterals Aviation and Maritime
 *
 * Das Collateralization Tape besteht aus 4 Schritten, wovon dieser der zweite zum Ausführen ist.
 * Dieses Tape zeigt die Beziehung zwischen Konten (Facilities), Sicherheitenverträgen (Collaterals) und
 * Vermögensobjekten (Assets) auf.
 *
 * In diesem Tape sind nur die Collaterals aus CMS enthalten. Die Spalten sind speziell für EY zugeschnitten
 *
 * (1) Collateral to (A) Facility/ (B) Client
 * (2) Collaterals (und Collateral_AV_MA)
 * (3) Asset to Collateral
 * (4) Assets
 */
------------------------------------------------------------------------------------------------------------------------
-- View erstellen
drop view CALC.VIEW_COLLATERAL_AV_MA;
create or replace view CALC.VIEW_COLLATERAL_AV_MA as
with
     LINK_NLB as (
        select
            SV_ID
            ,CUTOFFDATE
            ,BRANCH
            ,MAX_RISK_SV_ZUR_VERT as MAX_RISK_SV_ZUR_VERT_IN_EUR  -- Der verteilte Sicherheitenwert sämtlicher Forderungen (beliebigerer Kunden) durch den Rechenkern CMS in EUR
        from CALC.SWITCH_NLB_CMS_LINK_REPLACEMENT_CURRENT
                 --Replacements aus issue #678
     ),
    LINK_BLB as (
        select
            SV_ID
            ,CUTOFFDATE
            ,BRANCH
            ,MAX_RISK_SV_ZUR_VERT as MAX_RISK_SV_ZUR_VERT_IN_EUR  -- Der verteilte Sicherheitenwert sämtlicher Forderungen (beliebigerer Kunden) durch den Rechenkern CMS in EUR
        from CALC.SWITCH_BLB_CMS_LINK_REPLACEMENT_CURRENT
                --Replacements aus issue #678
     ),
     LINK as (
         select * from LINK_BLB
            union all
         select * from LINK_NLB
     ),
    CMS_NLB as (
        select distinct
            LINK.CUTOFFDATE             as CUT_OFF_DATE,
            LINK.SV_ID,
            MAX(LINK.TEILWERT_PROZ)          as Teil_Anteil,
            LINK.SV_TEIL_ID              as Teil_ID,
            MAX(LINK.TEILWERT_BETRAG)         as Teil_Wert,
            LINK.TEILWERT_BETRAG_WAEHR   as CURRENCY,
            SUM(MAX_RISK_VERT_JE_GW)         as AKT_VERTEILTER_WERT_PRE,
            SUM(MAX_RISK_KONTO)              as AKT_ZU_BES_WERT_PRE,
            BUSINESS_PARTNER.PARTNER_ID,
            BUSINESS_PARTNER.PARTNER_NAME_1,
            TEIL_EINSCHRAENKUNG
        from CALC.SWITCH_NLB_CMS_LINK_REPLACEMENT_CURRENT       as LINK
                    --Replacements aus issue #678
        left join NLB.CMS_GP_CURRENT    as BUSINESS_PARTNER   on BUSINESS_PARTNER.CUTOFFDATE = LINK.CUTOFFDATE
                                                  and left(LINK.SV_ID, 15) = left(BUSINESS_PARTNER.CMS_ID, 15)
                                                  and LINK.SV_TEIL_ID = BUSINESS_PARTNER.CMS_SUB_ID
        where SV_STATUS = 'Rechtlich aktiv' --and (MAX_RISK_KONTO > 0 or MAX_RISK_VERT_JE_GW > 0)
        group by link.CUTOFFDATE, LINK.SV_ID, LINK.SV_TEIL_ID, LINK.TEILWERT_BETRAG_WAEHR, BUSINESS_PARTNER.PARTNER_ID, BUSINESS_PARTNER.PARTNER_NAME_1, TEIL_EINSCHRAENKUNG
    ),
    CMS_BLB as (
        select distinct
            LINK.CUTOFFDATE             as CUT_OFF_DATE,
            LINK.SV_ID,
            MAX(LINK.TEILWERT_PROZ)          as Teil_Anteil,
            LINK.SV_TEIL_ID              as Teil_ID,
            MAX(LINK.TEILWERT_BETRAG)         as Teil_Wert,
            LINK.TEILWERT_BETRAG_WAEHR   as CURRENCY,
            SUM(MAX_RISK_VERT_JE_GW)         as AKT_VERTEILTER_WERT_PRE,
            SUM(MAX_RISK_KONTO)              as AKT_ZU_BES_WERT_PRE,
            BUSINESS_PARTNER.PARTNER_ID,
            BUSINESS_PARTNER.PARTNER_NAME_1,
            TEIL_EINSCHRAENKUNG
        from CALC.SWITCH_BLB_CMS_LINK_REPLACEMENT_CURRENT       as LINK
                    --Replacements aus issue #678
        left join BLB.CMS_GP_CURRENT    as BUSINESS_PARTNER   on BUSINESS_PARTNER.CUTOFFDATE = LINK.CUTOFFDATE
                                                  and left(LINK.SV_ID, 15) = left(BUSINESS_PARTNER.CMS_ID, 15)
                                                  and LINK.SV_TEIL_ID = BUSINESS_PARTNER.CMS_SUB_ID
        where SV_STATUS = 'Rechtlich aktiv' --and (MAX_RISK_KONTO > 0 or MAX_RISK_VERT_JE_GW > 0)
        group by link.CUTOFFDATE, LINK.SV_ID, LINK.SV_TEIL_ID, LINK.TEILWERT_BETRAG_WAEHR, BUSINESS_PARTNER.PARTNER_ID, BUSINESS_PARTNER.PARTNER_NAME_1, TEIL_EINSCHRAENKUNG
    ),
    CMS_COLLATERALS as (
        select * from NLB.CMS_SV_CURRENT
        union all
        select * from BLB.CMS_SV_CURRENT
    ),
    nlb_shares_PO as (
        select * from CMS_NLB
        union all
        select * from CMS_BLB
    ),
    nlb_shares as (
        select distinct
            CUT_OFF_DATE,
            SV_ID,
            max(Teil_Anteil)             as Teil_Anteil,
            SUM(Teil_Wert)               as Teil_Wert,
            SUM(AKT_VERTEILTER_WERT_PRE) as AKT_VERTEILTER_WERT,
            SUM(AKT_ZU_BES_WERT_PRE)     as AKT_ZU_BES_WERT
        from nlb_shares_PO where TEIL_EINSCHRAENKUNG is null
        group by SV_ID, CUT_OFF_DATE, CURRENCY
    ),lux_shares as (
        select distinct
            CUT_OFF_DATE,
            SV_ID,
            max(Teil_Anteil)             as LUX_Teil_Anteil,
            SUM(Teil_Wert)               as LUX_Teil_Wert,
            SUM(AKT_VERTEILTER_WERT_PRE) as LUX_AKT_VERTEILTER_WERT,
            SUM(AKT_ZU_BES_WERT_PRE)     as LUX_AKT_ZU_BES_WERT
        from nlb_shares_PO where PARTNER_ID = '8595462'
        group by SV_ID, CUT_OFF_DATE, CURRENCY
 ),
     other_shares as (
     select distinct
             CUT_OFF_DATE,
             SV_ID,
             max(Teil_Anteil)             as Other_Teil_Anteil,
             SUM(Teil_Wert)               as Other_Teil_Wert
         from nlb_shares_PO where PARTNER_ID <> '8595462' and TEIL_EINSCHRAENKUNG is not null
         group by SV_ID, CUT_OFF_DATE, CURRENCY
 )
select distinct
    CMS_COLLATERALS.CUTOFFDATE                                                                                                                                as CUT_OFF_DATE,
    CMS_COLLATERALS.SV_ID                                                                                                                                     as COLLATERAL_ID,
    CMS_COLLATERALS.SV_TYP                                                                                                                                    as COLLATERAL_TYPE,
    CMS_COLLATERALS.SV_ART                                                                                                                                    as COLLATERAL_DESCRIPTION,
    CMS_COLLATERALS.SV_NOMINALWERT / coalesce(NOMINAL_WERT_EXCHANGE.KURS,1.000)                                                                               as NOMINAL_VALUE_EUR,
    CMS_COLLATERALS.SV_NOMINALWERT                                                                                                                            as NOMINAL_VALUE_OC,
    CMS_COLLATERALS.SV_NOMINALWERT_WAEHR                                                                                                                      as NOMINAL_VALUE_ORIGINAL_CURRENCY,
    NOMINAL_WERT_EXCHANGE.KURS                                                                                                                                as NOMINAL_EXCANGE_RATE,
    CALC.convert2eur(double(CMS_COLLATERALS.SV_ANZUSETZ_WERT),double(coalesce(ANZUSETZENDER_WERT_EXCHANGE.KURS,1.000)),CMS_COLLATERALS.SV_ANZUSETZ_WERT_WAEHR) as COLLATERAL_VALUE_EUR,
    CMS_COLLATERALS.SV_ANZUSETZ_WERT                                                                                                                          as COLLATERAL_VALUE_OC,
    CMS_COLLATERALS.SV_ANZUSETZ_WERT_WAEHR                                                                                                                    as COLLATERAL_VALUE_ORIGINAL_CURRENCY,
    ANZUSETZENDER_WERT_EXCHANGE.KURS                                                                                                                          as COLLATERAL_EXCANGE_RATE,
    coalesce(nlbs.Teil_Anteil/100, coalesce(nlbs.Teil_Wert,0)/nullif(coalesce(nlbs.Teil_Wert,0)+coalesce(luxs.lux_Teil_Wert,0)+coalesce(others.Other_Teil_Wert,0),0))       as NORDLB_SHARE_PERCENT,
    coalesce(nlbs.Teil_Wert, coalesce(nlbs.Teil_Anteil,0)/100.*CMS_COLLATERALS.SV_ANZUSETZ_WERT)  / coalesce(ANZUSETZENDER_WERT_EXCHANGE.KURS,1.000)          as NORDLB_SHARE_EUR,
    coalesce(nlbs.Teil_Wert, coalesce(nlbs.Teil_Anteil,0)/100.*CMS_COLLATERALS.SV_ANZUSETZ_WERT)                                                              as NORDLB_SHARE_OC,
    CMS_COLLATERALS.SV_NOMINALWERT_WAEHR                                                                                                                      as NORDLB_SHARE_ORIGINAL_CURRENCY,
    ANZUSETZENDER_WERT_EXCHANGE.KURS                                                                                                                          as NORDLB_SHARE_EXCANGE_RATE,
    AKT_VERTEILTER_WERT / coalesce(ANZUSETZENDER_WERT_EXCHANGE.KURS,1.000)                                                                                    as AKT_VERTEILTER_WERT_EUR,
    AKT_VERTEILTER_WERT                                                                                                                                       as AKT_VERTEILTER_WERT_OC,
    CMS_COLLATERALS.SV_NOMINALWERT_WAEHR                                                                                                                      as AKT_VERTEILTER_ORIGINAL_CURRENCY,
    ANZUSETZENDER_WERT_EXCHANGE.KURS                                                                                                                          as AKT_VERTEILTER_EXCANGE_RATE,
    AKT_ZU_BES_WERT / coalesce(ANZUSETZENDER_WERT_EXCHANGE.KURS,1.000)                                                                                        as AKT_ZU_BES_WERT_EUR,
    AKT_ZU_BES_WERT                                                                                                                                           as AKT_ZU_BES_WERT_OC,
    CMS_COLLATERALS.SV_NOMINALWERT_WAEHR                                                                                                                      as AKT_ZU_BES_ORIGINAL_CURRENCY,
    ANZUSETZENDER_WERT_EXCHANGE.KURS                                                                                                                          as AKT_ZU_BES_EXCANGE_RATE,
    coalesce(luxs.LUX_Teil_Anteil/100, coalesce(luxs.LUX_Teil_Wert,0)/nullif(coalesce(nlbs.Teil_Wert,0)+coalesce(luxs.lux_Teil_Wert,0)+coalesce(others.Other_Teil_Wert,0),0))        as LUX_SHARE_PERCENT,
    coalesce(luxs.LUX_Teil_Wert, coalesce(luxs.LUX_Teil_Anteil,0)/100.*CMS_COLLATERALS.SV_ANZUSETZ_WERT)  / coalesce(ANZUSETZENDER_WERT_EXCHANGE.KURS,1.000)               as LUX_SHARE_EUR,
    coalesce(luxs.LUX_Teil_Wert, coalesce(luxs.LUX_Teil_Anteil,0)/100.*CMS_COLLATERALS.SV_ANZUSETZ_WERT)                                                                   as LUX_SHARE_OC,
    luxs.LUX_AKT_VERTEILTER_WERT / coalesce(ANZUSETZENDER_WERT_EXCHANGE.KURS,1.000)                                                                                   as LUX_AKT_VERTEILTER_WERT_EUR,
    luxs.LUX_AKT_VERTEILTER_WERT                                                                                                                                      as LUX_AKT_VERTEILTER_WERT_OC,
    luxs.LUX_AKT_ZU_BES_WERT / coalesce(ANZUSETZENDER_WERT_EXCHANGE.KURS,1.000)                                                                                       as LUX_AKT_ZU_BES_WERT_EUR,
    luxs.LUX_AKT_ZU_BES_WERT                                                                                                                                        as LUX_AKT_ZU_BES_WERT_OC
    ,CMS_COLLATERALS.BRANCH                                                                                                                                    AS BRANCH                      -- Institut
    ,Current USER                                                                                                                                              as CREATED_USER                -- Letzter Nutzer, der dieses Tape gebaut hat.
    ,Current TIMESTAMP                                                                                                                                         as CREATED_TIMESTAMP           -- Neuester Zeitstempel, wann dieses Tape zuletzt gebaut wurde.
from CMS_COLLATERALS                                    as CMS_COLLATERALS
left join LINK                                          as LINK                     on CMS_COLLATERALS.SV_ID=LINK.SV_ID and LINK.BRANCH=CMS_COLLATERALS.BRANCH and LINk.CUTOFFDATE=CMS_COLLATERALS.CUTOFFDATE
--inner join AMC.TAPE_SHIP_COLLATERAL_TO_FACILITY_CURRENT as C2F                          on CMS_COLLATERALS.SV_ID=C2F.COLLATERAL_ID
inner join CALC.SWITCH_COLLATERAL_TO_FACILITY_CURRENT as C2F                          on cast(CMS_COLLATERALS.SV_ID as VARCHAR(64))=cast(C2F.COLLATERAL_ID as VARCHAR(64))
                                                                                          and C2F.CUT_OFF_DATE=CMS_COLLATERALS.CUTOFFDATE
left join IMAP.CURRENCY_MAP                             as NOMINAL_WERT_EXCHANGE             on NOMINAL_WERT_EXCHANGE.CUT_OFF_DATE = CMS_COLLATERALS.CUTOFFDATE
                                                                                          and NOMINAL_WERT_EXCHANGE.ZIEL_WHRG = CMS_COLLATERALS.SV_NOMINALWERT_WAEHR
left join IMAP.CURRENCY_MAP                             as ANZUSETZENDER_WERT_EXCHANGE  on ANZUSETZENDER_WERT_EXCHANGE.CUT_OFF_DATE = CMS_COLLATERALS.CUTOFFDATE
                                                                                          and ANZUSETZENDER_WERT_EXCHANGE.ZIEL_WHRG = CMS_COLLATERALS.SV_ANZUSETZ_WERT_WAEHR
left join nlb_shares                                    as nlbs                         on nlbs.SV_ID=CMS_COLLATERALS.SV_ID
                                                                                          and nlbs.CUT_OFF_DATE=CMS_COLLATERALS.CUTOFFDATE
left join lux_shares                                    as luxs                         on luxs.SV_ID=CMS_COLLATERALS.SV_ID
                                                                                          and luxs.CUT_OFF_DATE=CMS_COLLATERALS.CUTOFFDATE
left join other_shares                                  as others                         on others.SV_ID=CMS_COLLATERALS.SV_ID
                                                                                          and others.CUT_OFF_DATE=CMS_COLLATERALS.CUTOFFDATE
where CMS_COLLATERALS.SV_STATUS='Rechtlich aktiv'
;

-- CI START FOR ALL TAPES
-- Current-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_COLLATERAL_AV_MA_CURRENT');
create table AMC.TABLE_COLLATERAL_AV_MA_CURRENT like CALC.VIEW_COLLATERAL_AV_MA distribute by hash(COLLATERAL_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_COLLATERAL_AV_MA_CURRENT_COLLATERAL_ID on AMC.TABLE_COLLATERAL_AV_MA_CURRENT (COLLATERAL_ID);
comment on table AMC.TABLE_COLLATERAL_CURRENT is 'Liste aller CMS Collaterals, welche an einem der gewünschten Kunden hängen (Aktueller Stichtag)';
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_COLLATERAL_AV_MA_CURRENT');
-- Archiv-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_COLLATERAL_AV_MA_ARCHIVE');
create table AMC.TABLE_COLLATERAL_AV_MA_ARCHIVE like AMC.TABLE_COLLATERAL_AV_MA_CURRENT distribute by hash(COLLATERAL_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2025' EVERY 1 MONTH) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_COLLATERAL_AV_MA_ARCHIVE_COLLATERAL_ID on AMC.TABLE_COLLATERAL_AV_MA_ARCHIVE (COLLATERAL_ID);
comment on table AMC.TABLE_COLLATERAL_ARCHIVE is 'Liste aller CMS Collaterals, welche an einem der gewünschten Kunden hängen (Alle Stichtage)';
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_COLLATERAL_AV_MA_ARCHIVE');
-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_COLLATERAL_AV_MA_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_COLLATERAL_AV_MA_ARCHIVE');
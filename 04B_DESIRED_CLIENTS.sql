/* VIEW_PORTFOLIO_DESIRED_CLIENTS
 * Diese View gibt alle möglichen Kundennummern wieder, die zu Kunden gehören, die uns für das Tape interessieren.
 */

-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view  CALC.VIEW_PORTFOLIO_DESIRED_CLIENTS;
create or replace view CALC.VIEW_PORTFOLIO_DESIRED_CLIENTS as
with
    CURRENT_CUTOFFDATE as (
        select CUT_OFF_DATE from CALC.AUTO_TABLE_CUTOFFDATES where IS_ACTIVE
    ),
    ALL_DESIRED_CLIENTS as (
        select * from CALC.SWITCH_PORTFOLIO_DESIRED_CLIENTS_PRE_CURRENT
    ),
    -- IWHS GARANTIE FLAGGING
    CLIENTS_WITH_GUARANTEE_FLAG as (
        select distinct *
        from (
           select CUTOFFDATE as CUT_OFF_DATE, BRANCH as BRANCH_CLIENT, BORROWERID as CLIENT_NO
           from NLB.IWHS_GARANTIEFLAG_CURRENT
           union all
           select CUTOFFDATE as CUT_OFF_DATE, BRANCH as BRANCH_CLIENT, BORROWERID as CLIENT_NO
           from BLB.IWHS_GARANTIEFLAG_CURRENT
       )
    ),
    -- IWHS GARANTIE FLAGGING
    CLIENTS_WITH_BORROWER_NO as (
        select distinct *
        from (
           select CUTOFFDATE as CUT_OFF_DATE, 'NLB' as BRANCH_CLIENT, PARTNER_C072 as CLIENT_NO, KREDITNEHMER as BORROWER_NO
           from NLB.ZO_KUNDE_CURRENT
           union all
           select CUTOFFDATE as CUT_OFF_DATE, 'BLB' as BRANCH_CLIENT, PARTNER_C072 as CLIENT_NO, KREDITNEHMER as BORROWER_NO
           from BLB.ZO_KUNDE_CURRENT
       )
    ),
    ALL_DESIRED_CLIENTS_WITH_FILLED_PORTFOLIO as (
        select distinct
            DATE(CURRENT_CUTOFFDATE.CUT_OFF_DATE) as CUT_OFF_DATE,
            BASE.BRANCH_CLIENT,
            BASE.CLIENT_NO,
            BASE.CLIENT_ID,
            BASE.CLIENT_ID_LEADING,
            BASE.CLIENT_ID_NLB, BASE.CLIENT_ID_BLB, BASE.CLIENT_ID_CBB,
            ZO.BORROWER_NO as BORROWER_NO,
            case
                 when BASE.PORTFOLIO_EY_CLIENT_ROOT is not NULL then
                     BASE.PORTFOLIO_EY_CLIENT_ROOT
                 when KUNDENBETREUER.OE_KOSTENSTELLE in (103304, 103330, 103332, 103335, 859149, 859241, 859244, 859347, 859348)
                   or KUNDENBETREUER.VB = '037' then
                     'Aviation'
                 when KUNDENBETREUER.OE_KOSTENSTELLE in (1) then
                     'Maritime Industries'
                 when KUNDE.OE_BEZEICHNUNG is not NULL then
                     KUNDE.OE_BEZEICHNUNG
                 else
                     NULL
            end as PORTFOLIO_EY_CLIENT_ROOT,
            BASE.PORTFOLIO_IWHS_CLIENT_KUNDENBERATER as PORTFOLIO_IWHS_CLIENT_KUNDENBERATER,
            BASE.PORTFOLIO_IWHS_CLIENT_SERVICE as PORTFOLIO_IWHS_CLIENT_SERVICE,
            BASE.PORTFOLIO_KR_CLIENT as PORTFOLIO_KR_CLIENT,
            BASE.SOURCE,
            case
                 when BASE.PORTFOLIO_EY_CLIENT_ROOT is not NULL then
                     BASE.PORTFOLIO_ORDER
                 when KUNDENBETREUER.OE_KOSTENSTELLE in (103304, 103330, 103332, 103335, 859149, 859241, 859244, 859347, 859348)
                   or KUNDENBETREUER.VB = '037' then
                     3
                 when KUNDENBETREUER.OE_KOSTENSTELLE in (1) then
                     3
                 when KUNDE.OE_BEZEICHNUNG is not NULL then
                     4
                 else
                     NULL
            end as PORTFOLIO_ORDER,
            case
                when CURRENT_CUTOFFDATE.CUT_OFF_DATE < '30.04.2020' then
                    NULL
                when FLAGGED.CLIENT_NO is NULL then
                    FALSE
                else
                    TRUE
            end as IS_GUARANTEE_FLAGGED -- Garantie Flagging aus IWHS hinzufügen
        from ALL_DESIRED_CLIENTS as BASE
        cross join CURRENT_CUTOFFDATE
        left join CLIENTS_WITH_BORROWER_NO as ZO on (ZO.CUT_OFF_DATE, ZO.CLIENT_NO, ZO.BRANCH_CLIENT) = (CURRENT_CUTOFFDATE.CUT_OFF_DATE, BASE.CLIENT_NO, BASE.BRANCH_CLIENT)
        left join NLB.IWHS_KUNDE_CURRENT as KUNDE on KUNDE.CUTOFFDATE = CURRENT_CUTOFFDATE.CUT_OFF_DATE and ('NLB_'||KUNDE.BORROWERID) = (BASE.CLIENT_ID_NLB)
        left join NLB.SPOT_KOSTENSTELLEN_CURRENT as KUNDENBETREUER on /*KOST.CUT_OFF_DATE = KUNDE.CUTOFFDATE and*/ Left(KUNDENBETREUER.OSPLUS_OE,6) = Left(KUNDE.OE_NR,6)
        left join CLIENTS_WITH_GUARANTEE_FLAG as FLAGGED on (CURRENT_CUTOFFDATE.CUT_OFF_DATE, BASE.CLIENT_NO, BASE.BRANCH_CLIENT) = (FLAGGED.CUT_OFF_DATE,FLAGGED.CLIENT_NO,FLAGGED.BRANCH_CLIENT) -- Garantie Flagging aus IWHS hinzufügen
    ),
    -- Make Clients Unique
    ALL_DESIRED_CLIENTS_UNIQUE as (
        select
            CUT_OFF_DATE,
            BRANCH_CLIENT,
            CLIENT_NO,
            CLIENT_ID,
            first_value(CLIENT_ID_LEADING) over (partition by CLIENT_NO, BRANCH_CLIENT order by CLIENT_ID_LEADING) as CLIENT_ID_LEADING,
            --LISTAGG(CLIENT_ID_NLB,'+') over (partition by CLIENT_NO, BRANCH_CLIENT order by CLIENT_ID_NLB) as CLIENT_IDS_NLB, --TODO: distinct wird nicht unterstützt - brauche ich aber hier
            --LISTAGG(CLIENT_ID_BLB,'+') over (partition by CLIENT_NO, BRANCH_CLIENT order by CLIENT_ID_BLB) as CLIENT_IDS_BLB, --TODO: distinct wird nicht unterstützt - brauche ich aber hier
            --LISTAGG(CLIENT_ID_CBB,'+') over (partition by CLIENT_NO, BRANCH_CLIENT order by CLIENT_ID_CBB) as CLIENT_IDS_CBB, --TODO: distinct wird nicht unterstützt - brauche ich aber hier
            first_value(CLIENT_ID_NLB) over (partition by CLIENT_NO, BRANCH_CLIENT order by CLIENT_ID_NLB) as CLIENT_IDS_NLB,
            first_value(CLIENT_ID_BLB) over (partition by CLIENT_NO, BRANCH_CLIENT order by CLIENT_ID_BLB) as CLIENT_IDS_BLB,
            first_value(CLIENT_ID_CBB) over (partition by CLIENT_NO, BRANCH_CLIENT order by CLIENT_ID_CBB) as CLIENT_IDS_CBB,
            first_value(BORROWER_NO) over (partition by CLIENT_NO, BRANCH_CLIENT) as BORROWER_NO,
            --first_value(PORTFOLIO_ROOT) over (partition by CLIENT_NO, BRANCH_CLIENT order by PORTFOLIO_ORDER, PORTFOLIO_ROOT DESC nulls last) as PORTFOLIO_ROOT_DESC,
            first_value(PORTFOLIO_EY_CLIENT_ROOT) over (partition by CLIENT_NO, BRANCH_CLIENT order by PORTFOLIO_ORDER, PORTFOLIO_EY_CLIENT_ROOT ASC nulls last) as PORTFOLIO_EY_CLIENT_ROOT,
            --first_value(SOURCE) over (partition by CLIENT_NO, BRANCH_CLIENT order by PORTFOLIO_ORDER, PORTFOLIO_ROOT DESC nulls last) as SOURCE_DESC,
            first_value(PORTFOLIO_IWHS_CLIENT_KUNDENBERATER) over (partition by CLIENT_NO, BRANCH_CLIENT order by PORTFOLIO_ORDER, PORTFOLIO_EY_CLIENT_ROOT ASC nulls last) as PORTFOLIO_IWHS_CLIENT_KUNDENBERATER,
            first_value(PORTFOLIO_IWHS_CLIENT_SERVICE) over (partition by CLIENT_NO, BRANCH_CLIENT order by PORTFOLIO_ORDER, PORTFOLIO_EY_CLIENT_ROOT ASC nulls last) as PORTFOLIO_IWHS_CLIENT_SERVICE,
            MAX(PORTFOLIO_KR_CLIENT) over (partition by CLIENT_NO, BRANCH_CLIENT) as PORTFOLIO_KR_CLIENT,
            first_value(SOURCE) over (partition by CLIENT_NO, BRANCH_CLIENT order by PORTFOLIO_ORDER, PORTFOLIO_EY_CLIENT_ROOT ASC nulls last) as SOURCE,
            first_value(PORTFOLIO_ORDER) over (partition by CLIENT_NO, BRANCH_CLIENT order by PORTFOLIO_ORDER, PORTFOLIO_EY_CLIENT_ROOT ASC nulls last) as PORTFOLIO_ORDER,
            MAX(IS_GUARANTEE_FLAGGED) over (partition by CLIENT_NO, BRANCH_CLIENT) as IS_GUARANTEE_FLAGGED
        from ALL_DESIRED_CLIENTS_WITH_FILLED_PORTFOLIO
    ),
    ALL_DESIRED_CLIENTS_FORMATTED as (
        select distinct
            BASE.CUT_OFF_DATE,      -- Stichtag
            BASE.BRANCH_CLIENT,     -- Institut des Kunden
            BASE.CLIENT_NO,         -- Kundennummer
            BASE.CLIENT_ID,         -- Kunden ID aus Institut und Kundenummer
            BASE.CLIENT_ID_LEADING, -- Führende Kundennummer
            CLIENT_IDS_NLB,CLIENT_IDS_BLB,CLIENT_IDS_CBB,   -- Alternative Kundennummern aus anderen Instituten
            --nullif(trim(B '+' FROM replace(cast('++'||CLIENT_IDS_NLB||'++' as VARCHAR(512)),'+'||CLIENT_ID||'+','+')),'') as CLIENT_IDS_NLB,
            BASE.BORROWER_NO,
            coalesce(PORTFOLIO_MAP.PORTFOLIO_ROOT,BASE.PORTFOLIO_EY_CLIENT_ROOT) as PORTFOLIO_EY_CLIENT_ROOT,   -- Portfolio Bezeichnung
            PORTFOLIO_IWHS_CLIENT_KUNDENBERATER as PORTFOLIO_IWHS_CLIENT_KUNDENBERATER,    -- OE Bezeichnung des Kunden laut IWHS
            PORTFOLIO_IWHS_CLIENT_SERVICE,
            PORTFOLIO_KR_CLIENT,
            SOURCE,                 -- Quelle über den wir diesen Kunden gefunden haben
            IS_GUARANTEE_FLAGGED    -- Ist der Kunde im IWHS geflaggt?
        from ALL_DESIRED_CLIENTS_UNIQUE as BASE
        left join SMAP.AMC_OENAME_TO_PORTFOLIO as PORTFOLIO_MAP on BASE.PORTFOLIO_EY_CLIENT_ROOT = PORTFOLIO_MAP.OE_BEZEICHNUNG and BASE.CUT_OFF_DATE between PORTFOLIO_MAP.VALID_FROM_DATE and PORTFOLIO_MAP.VALID_TO_DATE
    ),
    ALL_DESIRED_CLIENTS_FORMATTED_PORTFOLIO as(
        select distinct
            CUT_OFF_DATE,                        -- Stichtag
            BRANCH_CLIENT,                       -- Institut des Kunden
            CLIENT_NO,                           -- Kundennummer
            CLIENT_ID,                           -- Kunden ID aus Institut und Kundenummer
            CLIENT_ID_LEADING,                   -- Führende Kundennummer
            CLIENT_IDS_NLB,                      -- Alternative Kundennummern aus Hannover
            CLIENT_IDS_BLB,                      -- Alternative Kundennummern aus Bremen
            CLIENT_IDS_CBB,                      -- Alternative Kundennummern aus Luxemburg
            BORROWER_NO,                         -- Kreditnehmernummer aus dem System ZO
            PORTFOLIO_EY_CLIENT_ROOT,            -- Portfolio Bezeichnung
            PORTFOLIO_IWHS_CLIENT_KUNDENBERATER, -- OE Bezeichnung des Kunden laut IWHS
            PORTFOLIO_IWHS_CLIENT_SERVICE,
            PORTFOLIO_KR_CLIENT,
            case
                when PORTFOLIO_KR_CLIENT is not null then PORTFOLIO_KR_CLIENT
                when (upper(coalesce(PORTFOLIO_EY_CLIENT_ROOT, '') ||
                            coalesce(PORTFOLIO_IWHS_CLIENT_SERVICE, '')) like '%MARITIME INDUSTRIES%'
                    or upper(coalesce(PORTFOLIO_EY_CLIENT_ROOT, '') ||
                             coalesce(PORTFOLIO_IWHS_CLIENT_SERVICE, '')) like '%SHIP%'
                    or upper(coalesce(PORTFOLIO_EY_CLIENT_ROOT, '') ||
                             coalesce(PORTFOLIO_IWHS_CLIENT_SERVICE, '')) like '%SCHIFF%')
                    THEN 'Maritime Industries'
                when (upper(coalesce(PORTFOLIO_EY_CLIENT_ROOT, '') ||
                            coalesce(PORTFOLIO_IWHS_CLIENT_SERVICE, '')) like '%AVIATION%'
                    or upper(coalesce(PORTFOLIO_EY_CLIENT_ROOT, '') ||
                             coalesce(PORTFOLIO_IWHS_CLIENT_SERVICE, '')) like '%PORTFOLIOM.&EXEC.I%')
                    THEN 'Aviation'
                else coalesce(PORTFOLIO_IWHS_CLIENT_SERVICE, PORTFOLIO_EY_CLIENT_ROOT) end as PORTFOLIO_GARANTIEN_CLIENT,
            SOURCE,                              -- Quelle über den wir diesen Kunden gefunden haben
            IS_GUARANTEE_FLAGGED                 -- Ist der Kunde im IWHS geflaggt?
        from ALL_DESIRED_CLIENTS_FORMATTED
     )
select
    DATE(CUT_OFF_DATE)          as CUT_OFF_DATE,
    VARCHAR(BRANCH_CLIENT,3)    as BRANCH_CLIENT,
    BIGINT(CLIENT_NO)           as CLIENT_NO,
    VARCHAR(CLIENT_ID,16)       as CLIENT_ID,
    VARCHAR(CLIENT_ID_LEADING,16) as CLIENT_ID_LEADING,
    CLIENT_IDS_NLB, CLIENT_IDS_BLB, CLIENT_IDS_CBB,
    BORROWER_NO,
    PORTFOLIO_EY_CLIENT_ROOT, -- as PORTFOLIO_ROOT,
    PORTFOLIO_IWHS_CLIENT_KUNDENBERATER, -- as PORTFOLIO_ROOT_IWHS,
    PORTFOLIO_IWHS_CLIENT_SERVICE,
    PORTFOLIO_KR_CLIENT,
    PORTFOLIO_GARANTIEN_CLIENT,
    SOURCE,
    IS_GUARANTEE_FLAGGED,
    Current USER                        as CREATED_USER,     -- Letzter Nutzer, der diese Tabelle gebaut hat.
    Current TIMESTAMP                   as CREATED_TIMESTAMP -- Neuester Zeitstempel, wann diese Tabelle zuletzt gebaut wurde.
from ALL_DESIRED_CLIENTS_FORMATTED_PORTFOLIO
;
------------------------------------------------------------------------------------------------------------------------

-- CI START FOR ALL TAPES

-- CURRENT TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_PORTFOLIO_DESIRED_CLIENTS_CURRENT');
create table AMC.TABLE_PORTFOLIO_DESIRED_CLIENTS_CURRENT like CALC.VIEW_PORTFOLIO_DESIRED_CLIENTS distribute by hash(BRANCH_CLIENT,CLIENT_NO) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_PORTFOLIO_DESIRED_CLIENTS_CURRENT_BRANCH_CLIENT on AMC.TABLE_PORTFOLIO_DESIRED_CLIENTS_CURRENT (BRANCH_CLIENT);
create index AMC.INDEX_PORTFOLIO_DESIRED_CLIENTS_CURRENT_CLIENT_NO     on AMC.TABLE_PORTFOLIO_DESIRED_CLIENTS_CURRENT (CLIENT_NO);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_PORTFOLIO_DESIRED_CLIENTS_CURRENT');
grant select on AMC.TABLE_PORTFOLIO_DESIRED_CLIENTS_CURRENT to group NLB_MW_ADAP_S_GNI_TROOPER;
------------------------------------------------------------------------------------------------------------------------

-- ARCHIVE TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_PORTFOLIO_DESIRED_CLIENTS_ARCHIVE');
create table AMC.TABLE_PORTFOLIO_DESIRED_CLIENTS_ARCHIVE like CALC.VIEW_PORTFOLIO_DESIRED_CLIENTS distribute by hash(BRANCH_CLIENT,CLIENT_NO) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_PORTFOLIO_DESIRED_CLIENTS_ARCHIVE_BRANCH_CLIENT on AMC.TABLE_PORTFOLIO_DESIRED_CLIENTS_ARCHIVE (BRANCH_CLIENT);
create index AMC.INDEX_PORTFOLIO_DESIRED_CLIENTS_ARCHIVE_CLIENT_NO     on AMC.TABLE_PORTFOLIO_DESIRED_CLIENTS_ARCHIVE (CLIENT_NO);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_PORTFOLIO_DESIRED_CLIENTS_ARCHIVE');
grant select on AMC.TABLE_PORTFOLIO_DESIRED_CLIENTS_ARCHIVE to group NLB_MW_ADAP_S_GNI_TROOPER;
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_PORTFOLIO_DESIRED_CLIENTS_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_PORTFOLIO_DESIRED_CLIENTS_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

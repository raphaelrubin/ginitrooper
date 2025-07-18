
-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_CLIENT_THIRDPARTY;
create or replace view CALC.VIEW_CLIENT_THIRDPARTY as
with
    -- Distincte Garantoren + Informationen
    GUARANTORS as (
        select distinct
            CUT_OFF_DATE                            AS CUT_OFF_DATE,
            BRANCH                                  AS BRANCH,
            CLIENT_NO                               AS CLIENT_ID,
            GUARANTOR_BALANCESHEET_CURRENCY_ISO     AS BALANCESHEET_CURRENCY_ISO,
            GUARANTOR_BALANCESHEET_EBITDA           AS BALANCESHEET_EBITDA,
            GUARANTOR_BALANCESHEET_DATE             AS BALANCESHEET_DATE,
            GUARANTOR_BALANCESHEET_TURNOVER_TOTAL   AS BALANCESHEET_TURNOVER_TOTAL,
            GUARANTOR_BALANCESHEET_COUNTRY_ALPHA2   AS BALANCESHEET_COUNTRY_ALPHA2,
            GUARANTOR_BALANCESHEET_CAPITAL_SHARE    AS BALANCESHEET_CAPITAL_SHARE,
            RECOURSE                                AS RECOURSE,               -- Risikorückbehalt?
            RECOURSE_REASON                         AS RECOURSE_REASON,        -- Grund für Risikorückbehalt?
            ORDER_NUMBER                            AS ORDER_NUMBER,           -- Nummer um Garantoren (nach Wichtigkeit?) zu sortieren
            'GUARANTOR'                             AS ROLE,
            COMMENT                                 AS COMMENT                 -- Kommentarspalte
        from CALC.VIEW_GUARANTORS
    ),
    -- Distinkte Fluggesellschaften + Informationen
    AIRLINES as (
        select distinct
            CUT_OFF_DATE                                 AS CUT_OFF_DATE,                -- Stichtag
            AIRLINE_BRANCH                               AS BRANCH,                      -- Institut des Bürgen
            AIRLINE_CLIENT_ID                            AS CLIENT_ID,                   -- Kundennummer des Bürgen
            AIRLINE_BALANCESHEET_CURRENCY_ISO            AS BALANCESHEET_CURRENCY_ISO,   -- Währung der Geld-Felder
            AIRLINE_BALANCESHEET_EBITDA                  AS BALANCESHEET_EBITDA,         -- EBITDA
            AIRLINE_BALANCESHEET_DATE                    AS BALANCESHEET_DATE,           -- Bilanzstichtag
            AIRLINE_BALANCESHEET_TURNOVER_TOTAL          AS BALANCESHEET_TURNOVER_TOTAL, -- Gesammtumsatz
            AIRLINE_BALANCESHEET_COUNTRY_ALPHA2          AS BALANCESHEET_COUNTRY_ALPHA2, -- 2-stelliger Ländercode
            AIRLINE_BALANCESHEET_SHARE_CAPITAL           AS BALANCESHEET_CAPITAL_SHARE,  -- Stammkapital
            RECOURSE                                     AS RECOURSE,                    -- Risikorückbehalt?
            NULL                                         AS RECOURSE_REASON,             -- N.A. (Grund für Risikorückbehalt)
            ORDER_NUMBER                                 AS ORDER_NUMBER,                -- Nummer um Einträge (nach Wichtigkeit?) zu sortieren
            'AIRLINE'                                    AS ROLE,                        -- Dies ist eine Fluggesellschaft
            NULL                                         AS COMMENT                      -- N.A. (Kommentar)
        from CALC.VIEW_AIRLINES
    ),
    PARTNERS as (
        select distinct *
        from GUARANTORS
        where CLIENT_ID is not null
            union all
        select distinct *
        from AIRLINES
        where CLIENT_ID is not null
    ),
     -- mapping um CLIENT_ID_ORIG und CLIENT_ID_ALT in der FINAL richtig anzuzeigen.
    PORTFOLIO_PRE as (
        select distinct
            CUT_OFF_DATE,
            DATA_CUT_OFF_DATE,
            BRANCH_CLIENT,
            CLIENT_NO as CLIENT_NO,
            CLIENT_ID_ORIG,
            CLIENT_ID_ALT
        from CALC.SWITCH_PORTFOLIO_CURRENT
    ),
    PORTFOLIO as (
        select distinct
            CUT_OFF_DATE,
            BRANCH_CLIENT,
            CLIENT_NO as CLIENT_NO,
            CLIENT_ID_ORIG,
            first_value(CLIENT_ID_ALT) over (partition by CUT_OFF_DATE, BRANCH_CLIENT, CLIENT_NO order by DATA_CUT_OFF_DATE DESC) as CLIENT_ID_ALT
        from PORTFOLIO_PRE
    ),
    ZO_KUNDE as (
       select *
        from NLB.ZO_KUNDE_CURRENT
        union all
        select *
        from BLB.ZO_KUNDE_CURRENT
        union all
        select *
        from ANL.ZO_KUNDE_CURRENT
    ),
    IWHS_KUNDE as (
        select *
        from NLB.IWHS_KUNDE_CURRENT
        union all
        select *
        from BLB.IWHS_KUNDE_CURRENT
        union all
        select *
        from ANL.IWHS_KUNDE_CURRENT
    ),
              CLIENT_KONZERN as ( -- aus KNDB, Konzern-Zugehörigkeit
        select CUTOFFDATE as CUT_OFF_DATE, BRANCH, KND_NR as CLIENT_NO, BRANCH || '_' || KONZERN_NR as KONZERN_ID, KONZERN_BEZ as KONZERN_BEZEICHNUNG
        from NLB.KN_KNE_CURRENT
        union
        select CUTOFFDATE as CUT_OFF_DATE, BRANCH, KND_NR as CLIENT_NO, BRANCH || '_' || KONZERN_NR as KONZERN_ID, KONZERN_BEZ as KONZERN_BEZEICHNUNG
        from BLB.KN_KNE_CURRENT
        union
        select CUTOFFDATE as CUT_OFF_DATE, BRANCH, KND_NR as CLIENT_NO, BRANCH || '_' || KONZERN_NR as KONZERN_ID, KONZERN_BEZ as KONZERN_BEZEICHNUNG
        from ANL.KN_KNE_CURRENT
    ),
     -- Bis zu zwei Kreditnehmer-Gruppen für jeden Kunden
     BORROWER_GROUPS as (
         select distinct DATA.BRANCH
                       , DATA.CLIENT_ID
                       , DATA.GROUP_1
                       , DATA.GROUP_2
                       , DATA.CUT_OFF_DATE
         from (
                  select PORTFOLIO.BRANCH_CLIENT                                            as BRANCH
                       , PORTFOLIO.CLIENT_NO                                                as CLIENT_ID
                       , MAX( CLIENT_ZO.KREDITNEHMEREINHEIT_SAP)
                             over (partition by PORTFOLIO.CLIENT_NO,CUT_OFF_DATE )          as GROUP_1
                       , nullif(MIN(CLIENT_ZO.KREDITNEHMEREINHEIT_SAP)
                                    over (partition by PORTFOLIO.CLIENT_NO,CUT_OFF_DATE ),
                                MAX(CLIENT_ZO.KREDITNEHMEREINHEIT_SAP)
                                    over (partition by PORTFOLIO.CLIENT_NO,CUT_OFF_DATE))   as GROUP_2
                       , PORTFOLIO.CUT_OFF_DATE                                             as CUT_OFF_DATE
                  from PORTFOLIO        as PORTFOLIO
                  left join ZO_KUNDE    as CLIENT_ZO     on    CLIENT_ZO.CUTOFFDATE = PORTFOLIO.CUT_OFF_DATE
                                                          and CLIENT_ZO.BRANCH || '_' || CLIENT_ZO.PARTNER_C072 = PORTFOLIO.BRANCH_CLIENT || '_' || PORTFOLIO.CLIENT_NO
                                                          and B913 = 1
              ) as DATA
     ),
          RATING as (
         select distinct
                         GP_NR
                         ,RATING_ID
                         ,SUBMODUL
                         ,'NLB' as Branch
                        ,CUT_OFF_DATE
         from NLB.SPOT_RATING_GESCHAEFTSPARTNER_CURRENT
         union all
         select distinct GP_NR
                         ,RATING_ID
                         ,SUBMODUL
                         ,'BLB' as Branch
                        ,CUT_OFF_DATE
         from BLB.SPOT_RATING_GESCHAEFTSPARTNER_CURRENT

     ),
    -- alle Daten zusammen
    data as (
        select
            PARTNER.*,
            PORTFOLIO_PARTNER.CLIENT_ID_ALT                                                     as CLIENT_ID_ALT,
            COALESCE(PORTFOLIO_PARTNER.CLIENT_ID_ORIG, PARTNER.BRANCH||'_'|| PARTNER.CLIENT_ID) as CLIENT_ID_ORIG
            ,CLIENT_IWHS.BORROWERNAME                                                          as BORROWERNAME
            ,CLIENT_KONZERN.KONZERN_BEZEICHNUNG                                                 as KONZERN_BEZEICHNUNG
            ,CLIENT_KONZERN.KONZERN_ID                                                         as KONZERN_ID
            ,CLIENT_IWHS.NACE                                                                  as NACE
            ,CLIENT_IWHS.COUNTRY
            ,COUNTRY_MAP.COUNTRY_APLHA2                                                       as COUNTRY_APLHA2
            ,CLIENT_IWHS.LEGALFORM                                                             as LEGALFORM
            ,RATING.RATING_ID                                                                   as RATING_ID
            ,RATING.SUBMODUL                                                                   as RATING_MODUL
            ,borrower_groups.GROUP_1                                                           as BORROWER_GROUP_1
            ,borrower_groups.GROUP_2                                                           as BORROWER_GROUP_2
        from PARTNERS               as PARTNER
        left join PORTFOLIO         as PORTFOLIO_PARTNER    on (PARTNER.CUT_OFF_DATE, PARTNER.BRANCH, PARTNER.CLIENT_ID) = (PORTFOLIO_PARTNER.CUT_OFF_DATE, PORTFOLIO_PARTNER.BRANCH_CLIENT, PORTFOLIO_PARTNER.CLIENT_NO)
        left join IWHS_KUNDE        as CLIENT_IWHS          on (PARTNER.CUT_OFF_DATE, PARTNER.BRANCH, PARTNER.CLIENT_ID) = (CLIENT_IWHS.CUTOFFDATE,         CLIENT_IWHS.Branch,              left(CLIENT_IWHS.BORROWERID,10))
        left join IMAP.ISO_LAENDER  as COUNTRY_MAP          on left(CLIENT_IWHS.COUNTRY,3) = lpad(COUNTRY_MAP.LNDKNK,3,'0')
        left join borrower_groups   as BORROWER_GROUPS      on (PARTNER.CUT_OFF_DATE, PARTNER.CLIENT_ID, PARTNER.BRANCH) = (BORROWER_GROUPS.CUT_OFF_DATE,left(BORROWER_GROUPS.CLIENT_ID,10),BORROWER_GROUPS.BRANCH)
        left join RATING                                    on (PARTNER.CUT_OFF_DATE, PARTNER.CLIENT_ID, PARTNER.BRANCH) = (RATING.CUT_OFF_DATE,RATING.GP_NR,RATING.Branch)
        left join CLIENT_KONZERN                            on (PARTNER.CUT_OFF_DATE, PARTNER.CLIENT_ID, PARTNER.BRANCH) = (CLIENT_KONZERN.CUT_OFF_DATE,CLIENT_KONZERN.CLIENT_NO,CLIENT_KONZERN.Branch)
    )
,prefin as (
    select distinct CUT_OFF_DATE,                                                                                       -- Stichtag
                    BRANCH,                                                                                             -- Institut des Bürgen
                    CLIENT_ID,                                                                                          -- Kundennummer des Bürgen+
                    CLIENT_ID_ORIG,                                                                                     -- Original Kundennummer zum Reporten
                    CLIENT_ID_ALT,                                                                                      -- Alternative Kundennummer zu CLIENT_ID_ORIG
                    BORROWERNAME,
                    NACE,                                                                                               -- Nace Code des Kunden
                    KONZERN_BEZEICHNUNG,                                                                                -- Konzern-Bezeichnung laut KNDB
                    KONZERN_ID,                                                                                         -- Konzern_ID laut KNDB
                    COUNTRY                                                             as CLIENT_COUNTRY,              -- Registerland des Kunden
                    COUNTRY_APLHA2                                                      as CLIENT_COUNTRY_ALPHA2,       -- Registerland des Kunden
                    BALANCESHEET_CURRENCY_ISO,                                                                          -- Währung der Geld-Felder
                    min(BALANCESHEET_EBITDA) over (partition by CLIENT_ID_ORIG,CUT_OFF_DATE) as BALANCESHEET_EBITDA,                                                                                -- EBITDA
                    BALANCESHEET_DATE,                                                                                  -- Bilanzstichtag
                    min(BALANCESHEET_TURNOVER_TOTAL) over (partition by CLIENT_ID_ORIG,CUT_OFF_DATE) as BALANCESHEET_TURNOVER_TOTAL, -- Gesammtumsatz
                    BALANCESHEET_COUNTRY_ALPHA2,                                                                        -- 2-stelliger Ländercode
                    min(BALANCESHEET_CAPITAL_SHARE) over (partition by CLIENT_ID_ORIG,CUT_OFF_DATE)  as BALANCESHEET_CAPITAL_SHARE,  -- Stammkapital
                    max(RECOURSE) over (partition by CLIENT_ID_ORIG,CUT_OFF_DATE)                    as RECOURSE,                    -- Risikorückbehalt
                    RECOURSE_REASON,             -- Grund für Risikorückbehalt
                    RATING_ID,                                                                                          --Rating-Note
                    RATING_MODUL,                                                                                       --Rating-Modul
                    BORROWER_GROUP_1                                                    as CLIENT_EBA_GVK_1,            -- GVK nach EBA Richtlinen
                    BORROWER_GROUP_2                                                    as CLIENT_EBA_GVK_2,            -- GVK nach EBA Richtlinen
                    Current USER                                                        as CREATED_USER,                -- Letzter Nutzer, der dieses Tape gebaut hat.
                    Current TIMESTAMP                                                   as CREATED_TIMESTAMP            -- Neuester Zeitstempel, wann dieses Tape zuletzt gebaut wurde.
    from data
)
select distinct CUT_OFF_DATE, BRANCH, CLIENT_ID, CLIENT_ID_ORIG, CLIENT_ID_ALT, NACE, CLIENT_EBA_GVK_1, CLIENT_EBA_GVK_2, CLIENT_COUNTRY, CLIENT_COUNTRY_ALPHA2, BALANCESHEET_CURRENCY_ISO, BALANCESHEET_EBITDA, BALANCESHEET_DATE, BALANCESHEET_TURNOVER_TOTAL, BALANCESHEET_COUNTRY_ALPHA2, BALANCESHEET_CAPITAL_SHARE, RATING_ID, RATING_MODUL, RECOURSE
     , listagg(RECOURSE_REASON, ',') over (partition by CLIENT_ID_ORIG,CUT_OFF_DATE)    as RECOURSE_REASON, CREATED_USER, CREATED_TIMESTAMP
from prefin
;
------------------------------------------------------------------------------------------------------------------------

-- CI START FOR ALL TAPES

-- Current-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_CLIENT_THIRDPARTY_CURRENT');
create table AMC.TABLE_CLIENT_THIRDPARTY_CURRENT like CALC.VIEW_CLIENT_THIRDPARTY distribute by hash(BRANCH,CLIENT_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CLIENT_THIRDPARTY_CURRENT_BRANCH    on AMC.TABLE_CLIENT_THIRDPARTY_CURRENT (BRANCH);
create index AMC.INDEX_CLIENT_THIRDPARTY_CURRENT_CLIENT_ID on AMC.TABLE_CLIENT_THIRDPARTY_CURRENT (CLIENT_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_CLIENT_THIRDPARTY_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- Archiv-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_CLIENT_THIRDPARTY_ARCHIVE');
create table AMC.TABLE_CLIENT_THIRDPARTY_ARCHIVE like CALC.VIEW_CLIENT_THIRDPARTY distribute by hash(BRANCH,CLIENT_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CLIENT_THIRDPARTY_ARCHIVE_BRANCH    on AMC.TABLE_CLIENT_THIRDPARTY_ARCHIVE (BRANCH);
create index AMC.INDEX_CLIENT_THIRDPARTY_ARCHIVE_CLIENT_ID on AMC.TABLE_CLIENT_THIRDPARTY_ARCHIVE (CLIENT_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_CLIENT_THIRDPARTY_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCHES erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_CLIENT_THIRDPARTY_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_CLIENT_THIRDPARTY_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

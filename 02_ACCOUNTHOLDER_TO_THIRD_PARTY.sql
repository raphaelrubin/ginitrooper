-- View erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY;
create or replace view CALC.VIEW_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY as
with
    -- Garantorinformationen (roh)
    GUARANTORS_RAW as (
        select A.*,row_number() over (PARTITION BY KUNDENNUMMER,CUTOFFDATE) as NBR from CALC.VIEW_PRE_GUARANTOR_NLB as A
            union all
        select A.*,row_number() over (PARTITION BY KUNDENNUMMER,CUTOFFDATE) as NBR from CALC.VIEW_PRE_GUARANTOR_BLB as A
    ),
    -- Garantoren fertig formatiert
    GUARANTORS as (
        select distinct
                        CUTOFFDATE                                           as CUT_OFF_DATE        -- Stichtag
                        ,LEFT(KUNDENNUMMER,3)                                as CLIENT_BRANCH       -- Institut des Schuldners/Kreditnehmers
                        ,SUBSTRING(KUNDENNUMMER,5,LENGTH(KUNDENNUMMER)-4)    as CLIENT_ID           -- Kundennummer des Schuldners/Kreditnehmers
                        ,BRANCH                                              as PARTNER_BRANCH      -- Institut des Bürgen
                        ,KUNDENNUMMER_GARANT                                 as PARTNER_CLIENT_ID   -- Kundennummer des Bürgen
                        ,'GUARANTOR'                                         as PARTNER_ROLE        -- Dies ist ein Garantor
                        ,NBR                                                 as ORDER_NUMBER        -- Nummer um Garantoren (nach Wichtigkeit?) zu sortieren
                        ,Kommentar                                           as GUARANTOR_FUNCTION  -- stellt die Funktion das welche ein Garantiegeber genau inne hat, bzw: ECA
        from GUARANTORS_RAW
    ),
    -- Fluggesellschaften fertig formattiert
    AIRLINES as (
        select distinct
                        CUT_OFF_DATE            as CUT_OFF_DATE         -- Stichtag
                        ,CLIENT_BRANCH          as CLIENT_BRANCH        -- Institut des Schuldners/Kreditnehmers
                        ,CLIENT_ID              as CLIENT_ID            -- Kundennummer des Schuldners/Kreditnehmers
                        ,AIRLINE_BRANCH         as PARTNER_BRANCH       -- Institut des Bürgen
                        ,AIRLINE_CLIENT_ID      as PARTNER_CLIENT_ID    -- Kundennummer des Bürgen
                        ,ROLE                   as PARTNER_ROLE         -- Dies ist eine Fluggesellschaft
                        ,ORDER_NUMBER           as ORDER_NUMBER         -- Nummer um Einträge (nach Wichtigkeit?) zu sortieren
                        ,NULL                   as GUARANTOR_FUNCTION   -- ist immer leer, da diese Spalte nur für Garantiegeber und nicht für Airlines gefüllt werden muss
        from CALC.VIEW_AIRLINES
    ),
    -- mapping um CLIENT_ID_ORIG und CLIENT_ID_ALT in der FINAL richtig anzuzeigen.
    PORTFOLIO as (
        select distinct
            CUT_OFF_DATE,
            BRANCH_CLIENT,
            CLIENT_NO as CLIENT_ID,
            CLIENT_ID_ORIG,
            first_value(CLIENT_ID_ALT) over (partition by CUT_OFF_DATE, BRANCH_CLIENT, CLIENT_NO, CLIENT_ID_ORIG order by DATA_CUT_OFF_DATE DESC) as CLIENT_ID_ALT
        from CALC.SWITCH_PORTFOLIO_CURRENT
    ),
    -- Alle Daten zudsammengefügt
    data as (
        select
            main.*,
            PORTFOLIO_B.CLIENT_ID_ALT                                                                   AS CLIENT_ID_ALT,
            COALESCE(PORTFOLIO_B.CLIENT_ID_ORIG,MAIN.CLIENT_BRANCH||'_'||MAIN.CLIENT_ID)                AS CLIENT_ID_ORIG,
            PORTFOLIO_NB.CLIENT_ID_ALT                                                                  AS PARTNER_CLIENT_ID_ALT,
            COALESCE(PORTFOLIO_NB.CLIENT_ID_ORIG,MAIN.PARTNER_BRANCH||'_'||MAIN.PARTNER_CLIENT_ID)      AS PARTNER_CLIENT_ID_ORIG
        from (
                 select *
                 from GUARANTORS
                 union all
                 select *
                 from AIRLINES
             ) AS main
        left join PORTFOLIO as PORTFOLIO_B  on (MAIN.CUT_OFF_DATE, MAIN.CLIENT_BRANCH,   MAIN.CLIENT_ID)   = (PORTFOLIO_B.CUT_OFF_DATE, PORTFOLIO_B.BRANCH_CLIENT, PORTFOLIO_B.CLIENT_ID)
        left join PORTFOLIO as PORTFOLIO_NB on (MAIN.CUT_OFF_DATE, MAIN.PARTNER_BRANCH, MAIN.PARTNER_CLIENT_ID) = (PORTFOLIO_NB.CUT_OFF_DATE, PORTFOLIO_NB.BRANCH_CLIENT, PORTFOLIO_NB.CLIENT_ID)
        where PORTFOLIO_B.CUT_OFF_DATE is not NULL -- Ausschließen der Kunden, die nicht im Portfolio sind
    )
select
    DATE(CUT_OFF_DATE)                          as CUT_OFF_DATE,              -- Stichtag
    cast(CLIENT_BRANCH as VARCHAR(3))           as BRANCH_BORROWER,           -- Haupt-Institut des Schuldners/Kreditnehmers
    BIGINT(CLIENT_ID)                           as CLIENT_ID_BORROWER,        -- Haupt-Kundennummer des Schuldners/Kreditnehmers als Zahl
    cast(CLIENT_ID_ORIG as VARCHAR(64))         as CLIENT_ID_BORROWER_ORIG,   -- Originale Haupt-Kundennummer des Schuldners/Kreditnehmers (zu reporten)
    cast(CLIENT_ID_ALT as VARCHAR(64))          as CLIENT_ID_BORROWER_ALT,    -- Alternative Haupt-Kundennummer des Schuldners/Kreditnehmers
    cast(PARTNER_BRANCH as VARCHAR(3))          as BRANCH_NOBORROWER,         -- Haupt-Institut des Bürgen
    BIGINT(PARTNER_CLIENT_ID)                   as CLIENT_ID_NOBORROWER,      -- Haupt-Kundennummer des Bürgen als Zahl
    cast(PARTNER_CLIENT_ID_ORIG as VARCHAR(64)) as CLIENT_ID_NOBORROWER_ORIG, -- Originale Haupt-Kundennummer des Bürgen (zu reporten)
    cast(PARTNER_CLIENT_ID_ALT as VARCHAR(64))  as CLIENT_ID_NOBORROWER_ALT,  -- Alternative Haupt-Kundennummer des Bürgen
    cast(PARTNER_ROLE as VARCHAR(32))           as ROLE,                      -- Fluggesellschaft oder Garantor?
    cast(GUARANTOR_FUNCTION as VARCHAR(256))    as GUARANTOR_FUNCTION,        -- stellt die Funktion dar, welche ein Garantiegeber genau inne hat, bzw: ECA
    BIGINT(ORDER_NUMBER)                        as ORDER_NUMBER,              -- Nummer um Einträge (nach Wichtigkeit?) zu sortieren
    Current_USER                                as CREATED_USER,              -- Letzter Nutzer, der dieses Tape gebaut hat.
    Current_TIMESTAMP                           as CREATED_TIMESTAMP          -- Neuester Zeitstempel, wann dieses Tape zuletzt gebaut wurde.
from data
;
------------------------------------------------------------------------------------------------------------------------

-- CI START FOR ALL TAPES

-- Current-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_CURRENT');
create table AMC.TABLE_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_CURRENT like CALC.VIEW_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY distribute by hash(BRANCH_BORROWER,CLIENT_ID_BORROWER) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_CURRENT_BRANCH_BORROWER      on AMC.TABLE_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_CURRENT (BRANCH_BORROWER);
create index AMC.INDEX_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_CURRENT_CLIENT_ID_BORROWER   on AMC.TABLE_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_CURRENT (CLIENT_ID_BORROWER);
create index AMC.INDEX_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_CURRENT_BRANCH_NOBORROWER    on AMC.TABLE_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_CURRENT (BRANCH_NOBORROWER);
create index AMC.INDEX_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_CURRENT_CLIENT_ID_NOBORROWER on AMC.TABLE_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_CURRENT (CLIENT_ID_NOBORROWER);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- Archiv-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_ARCHIVE');
create table AMC.TABLE_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_ARCHIVE like CALC.VIEW_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY distribute by hash(BRANCH_BORROWER,CLIENT_ID_BORROWER) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_ARCHIVE_BRANCH_BORROWER      on AMC.TABLE_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_ARCHIVE (BRANCH_BORROWER);
create index AMC.INDEX_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_ARCHIVE_CLIENT_ID_BORROWER   on AMC.TABLE_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_ARCHIVE (CLIENT_ID_BORROWER);
create index AMC.INDEX_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_ARCHIVE_BRANCH_NOBORROWER    on AMC.TABLE_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_ARCHIVE (BRANCH_NOBORROWER);
create index AMC.INDEX_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_ARCHIVE_CLIENT_ID_NOBORROWER on AMC.TABLE_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_ARCHIVE (CLIENT_ID_NOBORROWER);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCHES erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

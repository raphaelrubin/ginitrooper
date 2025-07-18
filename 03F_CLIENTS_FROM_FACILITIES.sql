-- Alle Kunden, denen Facilities gehören, an denen wir explizit interessiert sind oder die wir in der Vergangenheit schon hatten

-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_PORTFOLIO_CLIENTS_FROM_FACILITIES;
create or replace view CALC.VIEW_PORTFOLIO_CLIENTS_FROM_FACILITIES as
with
    -- Alle Kunden aus den einzelnen Systemen
    ALL_CLIENTS as (
        select * from CALC.VIEW_PORTFOLIO_CLIENTS_ALIS
        union all
        select * from CALC.VIEW_PORTFOLIO_CLIENTS_BW
        union all
        select * from CALC.VIEW_PORTFOLIO_CLIENTS_DERIVATE
        union all
        select * from CALC.VIEW_PORTFOLIO_CLIENTS_DLD
        union all
        select * from CALC.VIEW_PORTFOLIO_CLIENTS_SPOT
    ),
    -- Doppelte Einträge ausschließen
    ALL_CLIENTS_UNIQUE as (
        select distinct
            CUT_OFF_DATE, BRANCH_CLIENT, CLIENT_NO, CLIENT_ID,
            first_value(PORTFOLIO_ROOT) over (partition by CUT_OFF_DATE, BRANCH_CLIENT, CLIENT_NO order by SOURCE DESC) as PORTFOLIO_ROOT,
            first_value(SOURCE) over (partition by CUT_OFF_DATE, BRANCH_CLIENT, CLIENT_NO order by SOURCE DESC) as SOURCE
        from ALL_CLIENTS
    )
select
    DATE(CUT_OFF_DATE)                      as CUT_OFF_DATE,     -- Stichtag
    cast(BRANCH_CLIENT as CHAR(3))          as BRANCH_CLIENT,    -- Institut der Kundennummer
    BIGINT(CLIENT_NO)                       as CLIENT_NO,        -- Kundennummer
    cast(CLIENT_ID as VARCHAR(32))          as CLIENT_ID,        -- Kunden ID
    cast(PORTFOLIO_ROOT as VARCHAR(128))    as PORTFOLIO_ROOT,   -- Portfolio Bezeichnung (ohne Zusätze)
    cast(SOURCE as VARCHAR(32))             as SOURCE,           -- Quelle (Konten Grundgesamtheit/Konten Archiv)
    Current USER                            as CREATED_USER,     -- Letzter Nutzer, der diese Tabelle gebaut hat.
    Current TIMESTAMP                       as CREATED_TIMESTAMP -- Neuester Zeitstempel, wann diese Tabelle zuletzt gebaut wurde.
from ALL_CLIENTS_UNIQUE
;
------------------------------------------------------------------------------------------------------------------------

-- CI START FOR ALL TAPES

-- CURRENT TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_PORTFOLIO_CLIENTS_FROM_FACILITIES_CURRENT');
create table AMC.TABLE_PORTFOLIO_CLIENTS_FROM_FACILITIES_CURRENT like CALC.VIEW_PORTFOLIO_CLIENTS_FROM_FACILITIES distribute by hash(BRANCH_CLIENT,CLIENT_NO) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_PORTFOLIO_CLIENTS_FROM_FACILITIES_CURRENT_BRANCH_CLIENT on AMC.TABLE_PORTFOLIO_CLIENTS_FROM_FACILITIES_CURRENT (BRANCH_CLIENT);
create index AMC.INDEX_PORTFOLIO_CLIENTS_FROM_FACILITIES_CURRENT_CLIENT_NO     on AMC.TABLE_PORTFOLIO_CLIENTS_FROM_FACILITIES_CURRENT (CLIENT_NO);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_PORTFOLIO_CLIENTS_FROM_FACILITIES_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_PORTFOLIO_CLIENTS_FROM_FACILITIES_CURRENT');
------------------------------------------------------------------------------------------------------------------------
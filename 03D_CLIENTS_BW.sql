/* VIEW_PORTFOLIO_CLIENTS_BW
 * Sammelt alle Kunden für die DESIRED FACILITIES und archivierten Portfolio Konten aus den BW Stammdaten Quelltabellen
 */

-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_PORTFOLIO_CLIENTS_BW;
create or replace view CALC.VIEW_PORTFOLIO_CLIENTS_BW as
with
    -- Konten aus GG und Manueller Kontenliste
    DESIRED_FACILITIES as (
        select
               case when BRANCH_FACILITY not in ('NLB','BLB','CBB') then 'ANL' else BRANCH_FACILITY end as BRANCH,
               FACILITY_ID as ID,
               PORTFOLIO_ROOT,
               'Konten Grundgesamtheit' as SOURCE
        from CALC.SWITCH_PORTFOLIO_DESIRED_FACILITIES_CURRENT
    ),
    -- Konten aus dem Portfolio Archiv
    ARCHIVED_FACILITIES as (
        select distinct
                BRANCH_FACILITY as BRANCH,
                FACILITY_ID as ID,
                PORTFOLIO_ROOT as PORTFOLIO_ROOT,
                'Konten Archiv' as SOURCE
        from CALC.SWITCH_PORTFOLIO_EXISTING_FACILITIES_CURRENT
    ),
    -- Alle Konten für die wir Kunden suchen
    ALL_FACILITIES as (
        select distinct *
        from (
            select *
            from DESIRED_FACILITIES
            union all
            select *
            from ARCHIVED_FACILITIES
        )
    ),
    -- Aktueller Stichtag
    CURRENT_CUTOFFDATE as (
        select CUT_OFF_DATE from CALC.AUTO_TABLE_CUTOFFDATES where IS_ACTIVE
    ),
    -- BW Konten
    BW_STAMMDATEN as (
        select A.* from CALC.SWITCH_BW_STAMMDATEN_CURRENT as A
        inner join CURRENT_CUTOFFDATE as B on A.CUT_OFF_DATE=B.CUT_OFF_DATE --nur aktuelles Datum mitnehmen
    ),
    -- Kunden für gewünschte BW Konten
    BW_STAMMDATEN_REMAINING_KR_CLIENTS
    as (
        select
            BW_STAMMDATEN.CUT_OFF_DATE      as CUT_OFF_DATE,
            BW_STAMMDATEN.BRANCH_CLIENT     as BRANCH_CLIENT,
            BW_STAMMDATEN.CLIENT_NO         as CLIENT_NO,
            BW_STAMMDATEN.BRANCH_CLIENT || '_' || BW_STAMMDATEN.CLIENT_NO  as CLIENT_ID,
            PORTFOLIO_ROOT,
            FACILITY.SOURCE                 as SOURCE
        from BW_STAMMDATEN              as BW_STAMMDATEN
        inner join ALL_FACILITIES       as FACILITY     on (BW_STAMMDATEN.FACILITY_ID,BW_STAMMDATEN.BRANCH_ACCOUNT)=(FACILITY.ID,FACILITY.BRANCH)
        where LEFT(BW_STAMMDATEN.FACILITY_ID,14) <> '0009-N001-DAR-' -- Gruppenkorrekturen ausschließen (#327)
    ),
    UNIQUE_NBR as (
        select *, row_number() over (partition by BRANCH_CLIENT, CLIENT_NO order by SOURCE desc) as NBR
        from BW_STAMMDATEN_REMAINING_KR_CLIENTS
    )
select
    DATE(CUT_OFF_DATE)                      as CUT_OFF_DATE,
    cast(BRANCH_CLIENT as CHAR(3))          as BRANCH_CLIENT,
    BIGINT(CLIENT_NO)                       as CLIENT_NO,
    cast(CLIENT_ID as VARCHAR(32))          as CLIENT_ID,
    cast(PORTFOLIO_ROOT as VARCHAR(128))    as PORTFOLIO_ROOT,
    cast(SOURCE as VARCHAR(32))             as SOURCE,
    Current USER                            as CREATED_USER,     -- Letzter Nutzer, der diese Tabelle gebaut hat.
    Current TIMESTAMP                       as CREATED_TIMESTAMP -- Neuester Zeitstempel, wann diese Tabelle zuletzt gebaut wurde.
from UNIQUE_NBR
where NBR = 1
;
------------------------------------------------------------------------------------------------------------------------

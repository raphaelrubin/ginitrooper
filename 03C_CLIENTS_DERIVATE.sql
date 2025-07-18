/* VIEW_PORTFOLIO_CLIENTS_DERIVATE
 * Sammelt alle Kunden für die DESIRED FACILITIES und archivierten Portfolio Konten aus den DERIVATE Quelltabellen
 * - NLB.SPOT_DERIVATE_CURRENT
 * - NLB.DERIVATE_TEMP_CURRENT
 * - NLB.DERIVATE_MUREX_CURRENT
 */

-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_PORTFOLIO_CLIENTS_DERIVATE;
create or replace view CALC.VIEW_PORTFOLIO_CLIENTS_DERIVATE as
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
    -- Alle Derivate Konten
    DERIVATE_PRE as (
        select distinct
            CUT_OFF_DATE,
            FACILITY_ID,
            TRADE_ID,
            BORROWERID
        from NLB.SPOT_DERIVATE_CURRENT
        where LOANSTATE='AKTIV'
        union
        select distinct
            CUT_OFF_DATE,
            FACILITY_ID,
            TRADE_ID,
            KUNDENNUMMER as BORROWERID
        from NLB.DERIVATE_TEMP_CURRENT
        union
         select distinct
                MUR.CUT_OFF_DATE,
                MAP.FACILITY_ID,
                TRADE_ID,
                MUR.KUNDENNUMMER as BORROWERID
         from NLB.DERIVATE_MUREX_CURRENT as MUR
         left join NLB.DERIVATE_FACILITY_ID_MUREX_ID_MAPPING_CURRENT as MAP on MAP.MUREX_ID=MUR.TRADE_ID and MAP.CUT_OFF_DATE=MUR.CUT_OFF_DATE
         where MAP.FACILITY_ID is not NULL
    ),
    -- Kunden für gewünschte Derivate Konten
    DERIVATE_AUS_FLAGGING as (
        select
            DERIVATE.CUT_OFF_DATE           as CUT_OFF_DATE,
            'NLB'                           as BRANCH_CLIENT,
            DERIVATE.BORROWERID             as CLIENT_NO,
            'NLB_'||DERIVATE.BORROWERID     as CLIENT_ID,
            PORTFOLIO_ROOT,
            FACILITY.SOURCE as SOURCE
        from DERIVATE_PRE                    as DERIVATE
        inner join CURRENT_CUTOFFDATE                       on CURRENT_CUTOFFDATE.CUT_OFF_DATE = DERIVATE.CUT_OFF_DATE
        inner join ALL_FACILITIES           as FACILITY     on (DERIVATE.FACILITY_ID,'NLB')=(FACILITY.ID,FACILITY.BRANCH)
    ),
    UNIQUE_NBR as (
        select *, row_number() over (partition by BRANCH_CLIENT, CLIENT_NO order by SOURCE desc) as NBR
        from DERIVATE_AUS_FLAGGING
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

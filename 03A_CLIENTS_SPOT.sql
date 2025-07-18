/* VIEW_PORTFOLIO_CLIENTS_SPOT
 * Sammelt alle Kunden für die DESIRED FACILITIES und archivierten Portfolio Konten aus den SPOT Stammdaten Quelltabellen
 */

-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_PORTFOLIO_CLIENTS_SPOT;
create or replace view CALC.VIEW_PORTFOLIO_CLIENTS_SPOT as
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
    -- Kunden für gewünschte Konten aus NLB SPOT
    SPOT_NLB as (
        select distinct
            STAMMDATEN.CUTOFFDATE           as CUT_OFF_DATE,
            'NLB'                           as BRANCH_CLIENT,
            STAMMDATEN.CLIENT_ID            as CLIENT_NO,
            'NLB_'||STAMMDATEN.CLIENT_ID    as CLIENT_ID,
            PORTFOLIO_ROOT,
            FACILITY.SOURCE                 as SOURCE
        from NLB.SPOT_STAMMDATEN_CURRENT        as STAMMDATEN
        inner join ALL_FACILITIES               as FACILITY     on (STAMMDATEN.FACILITY_ID,'NLB')=(FACILITY.ID,FACILITY.BRANCH)
    ),
    -- Kunden für gewünschte Konten aus BLB SPOT
    SPOT_BLB as (
        select distinct
            STAMMDATEN.CUTOFFDATE           as CUT_OFF_DATE,
            'BLB'                           as BRANCH_CLIENT,
            STAMMDATEN.CLIENT_ID            as CLIENT_NO,
            'BLB_'||STAMMDATEN.CLIENT_ID    as CLIENT_ID,
            PORTFOLIO_ROOT,
            FACILITY.SOURCE                 as SOURCE
        from BLB.SPOT_STAMMDATEN_CURRENT        as STAMMDATEN
        inner join ALL_FACILITIES               as FACILITY     on (STAMMDATEN.FACILITY_ID,'BLB')=(FACILITY.ID,FACILITY.BRANCH)
    ),
    -- Kunden für gewünschte Konten aus ANL SPOT
    SPOT_ANL as (
        select distinct
            STAMMDATEN.CUTOFFDATE           as CUT_OFF_DATE,
            'NLB'                           as BRANCH_CLIENT,
            STAMMDATEN.CLIENT_ID            as CLIENT_NO,
            'NLB_'||STAMMDATEN.CLIENT_ID    as CLIENT_ID,
            PORTFOLIO_ROOT,
            FACILITY.SOURCE                 as SOURCE
        from ANL.SPOT_STAMMDATEN_CURRENT        as STAMMDATEN
        inner join ALL_FACILITIES               as FACILITY     on (STAMMDATEN.FACILITY_ID,'ANL')=(FACILITY.ID,FACILITY.BRANCH)
    ),
    -- Kunden für gewünschte 1020 Konten aus CBB SPOT
    SPOT_CBB as (
        select
            STAMMDATEN.CUTOFFDATE           as CUT_OFF_DATE,
            'NLB'                           as BRANCH_CLIENT,
            STAMMDATEN.KRKUND               as CLIENT_NO,
            'NLB_'||STAMMDATEN.KRKUND       as CLIENT_ID,
            PORTFOLIO_ROOT,
            FACILITY.SOURCE                 as SOURCE
        from CBB.SPOT_STAMMDATEN_CURRENT        as STAMMDATEN
        inner join ALL_FACILITIES                  as FACILITY     on ('K028-'|| (STAMMDATEN.KKTOAVA + case when STAMMDATEN.KKTOAVA = '2588650' then 3 else 1 end ) || '_1020','CBB')=(FACILITY.ID,FACILITY.BRANCH)
        where STAMMDATEN.KKTOAVA is not NULL
    ),
     -- Kunden für gewünschte 4200 Konten aus CBB SPOT
    SPOT_CBB_SSART20 as (
        select
            STAMMDATEN.CUTOFFDATE           as CUT_OFF_DATE,
            'NLB'                           as BRANCH_CLIENT,
            STAMMDATEN.KRKUND               as CLIENT_NO,
            'NLB_'||STAMMDATEN.KRKUND       as CLIENT_ID,
            PORTFOLIO_ROOT,
            FACILITY.SOURCE                 as SOURCE
        from CBB.SPOT_STAMMDATEN_CURRENT        as STAMMDATEN
        inner join ALL_FACILITIES               as FACILITY     on ('K028-'|| (STAMMDATEN.KKTOAVA + case when STAMMDATEN.KKTOAVA = '2588650' then 3 else 1 end ) || '_4200','CBB')=(FACILITY.ID,FACILITY.BRANCH)
        where STAMMDATEN.KKTOAVA is not NULL
          and STAMMDATEN.SSART = '20'
    ),
     -- Alle Kunden aus dem SPOT
    COLLECTION as (
        select * from SPOT_NLB
        union all
        select * from SPOT_BLB
        union all
        select * from SPOT_ANL
        union all
        select * from SPOT_CBB
        union all
        select * from SPOT_CBB_SSART20
    ),
    UNIQUE_NBR as (
        select *, row_number() over (partition by BRANCH_CLIENT, CLIENT_NO order by SOURCE desc) as NBR
        from COLLECTION
    )
select distinct
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

/* VIEW_PORTFOLIO_CLIENTS_ALIS
 * Sammelt alle Kunden für die DESIRED FACILITIES und archivierten Portfolio Konten aus den ALIS Quelltabellen
 */

-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_PORTFOLIO_CLIENTS_ALIS;
create or replace view CALC.VIEW_PORTFOLIO_CLIENTS_ALIS as
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
    -- Alle ALIS Konten
    ALIS_KONTEN as (
         select * from NLB.ALIS_KONTO
         union all
         select * from BLB.ALIS_KONTO
    ),
    -- Alle Kreditnehmer Infos
    KN_KNE as (
         select BRANCH as BRANCH_SYSTEM, BRANCH as BRANCH_CLIENT, KND_NR as CLIENT_NO, KREDITN_NR as NO from NLB.KN_KNE_CURRENT
         union all
         select BRANCH as BRANCH_SYSTEM, BRANCH as BRANCH_CLIENT, KND_NR as CLIENT_NO, KREDITN_NR as NO from BLB.KN_KNE_CURRENT
         union all
         select BRANCH as BRANCH_SYSTEM, 'NLB' as BRANCH_CLIENT, KND_NR as CLIENT_NO, KREDITN_NR as NO from ANL.KN_KNE_CURRENT
    ),
    -- KONTONUMMERN aus SPOT Stammdaten für alle gewünschten Kunden
    STAMM_SPOT as (
        select
            STAMM.CUTOFFDATE as CUT_OFF_DATE,
            'NLB' as BRANCH,
            STAMM.CLIENT_ID,
            trim(L '0' from substr(STAMM.FACILITY_ID,11,10)) as SKTO,
            PORTFOLIO_ROOT,
            FACILITY.SOURCE                 as SOURCE
        from NLB.SPOT_STAMMDATEN_CURRENT as STAMM
        inner join ALL_FACILITIES          as FACILITY     on (STAMM.FACILITY_ID,STAMM.BRANCH)=(FACILITY.ID,FACILITY.BRANCH)
        union all
        select
            STAMM.CUTOFFDATE as CUT_OFF_DATE,
            'BLB' as BRANCH,
            STAMM.CLIENT_ID,
            trim(L '0' from substr(STAMM.FACILITY_ID,11,10)) as SKTO,
            PORTFOLIO_ROOT,
            FACILITY.SOURCE                 as SOURCE
        from BLB.SPOT_STAMMDATEN_CURRENT as STAMM
        inner join ALL_FACILITIES     as FACILITY     on (STAMM.FACILITY_ID,STAMM.BRANCH)=(FACILITY.ID,FACILITY.BRANCH)
        union all
        select
            STAMM.CUTOFFDATE as CUT_OFF_DATE,
            'ANL' as BRANCH,
            STAMM.CLIENT_ID,
            trim(L '0' from substr(STAMM.FACILITY_ID,11,10)) as SKTO,
            PORTFOLIO_ROOT,
            FACILITY.SOURCE                 as SOURCE
        from ANL.SPOT_STAMMDATEN_CURRENT as STAMM
        inner join ALL_FACILITIES     as FACILITY     on (STAMM.FACILITY_ID,'NLB')=(FACILITY.ID,FACILITY.BRANCH)
    ),
    -- Kunden aus SPOT Stammdaten für alle gewünschten ALIS Rahmen
    ALIS_RAHMEN as (
        select
            ALIS.CUTOFFDATE                                                                                                                                              as CUT_OFF_DATE,
            coalesce(ALIS.BRANCH,STAMM.BRANCH)                                                                                                                           as BRANCH_CLIENT,
            coalesce(case when ALIS.branch = 'BLB' then DPK.CLIENT_NO_2 else BORROWER.CLIENT_NO end, STAMM.CLIENT_ID)                                                    as CLIENT_NO,
            coalesce(ALIS.branch || '_' ||  case when ALIS.branch = 'BLB' then DPK.CLIENT_NO_2 else BORROWER.CLIENT_NO end, STAMM.BRANCH || '_' || STAMM.CLIENT_ID) as CLIENT_ID,
            PORTFOLIO_ROOT,
            STAMM.SOURCE
        from ALIS_KONTEN as ALIS
        inner join STAMM_SPOT                  as STAMM        on STAMM.SKTO=ALIS.SKTO and STAMM.CUT_OFF_DATE=ALIS.CUTOFFDATE
        left join KN_KNE                       as BORROWER     on (STAMM.BRANCH, STAMM.CLIENT_ID) = (BORROWER.BRANCH_CLIENT, BORROWER.CLIENT_NO)
        left join CALC.VIEW_GEKO_DOPPELKUNDEN as DPK on DPK.CLIENT_NO_1=BORROWER.CLIENT_NO and BRANCH_1 = 'NLB'
    ),
    UNIQUE_NBR as (
        -- Wenn ein Konto mehrere Kunden hat (bei Rahmen möglich) nehmen wir den mit der größten Kundennummer (siehe auch #508)
        select *, row_number() over (partition by BRANCH_CLIENT, CLIENT_NO order by SOURCE desc, CLIENT_ID desc) as NBR
        from ALIS_RAHMEN
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

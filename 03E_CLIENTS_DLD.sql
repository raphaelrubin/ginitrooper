/* VIEW_PORTFOLIO_CLIENTS_DLD
 * Sammelt alle Kunden für die DESIRED FACILITIES und archivierten Portfolio Konten aus den DLD Rahmen Quelltabellen
 */

-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_PORTFOLIO_CLIENTS_DLD;
create or replace view CALC.VIEW_PORTFOLIO_CLIENTS_DLD as
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
    -- Alle Kunden für Rahmen Netting Verträge
    LEDIS_RAHMEN_NLB as (
        select
            DLD_IFRS.CUT_OFF_DATE           as CUT_OFF_DATE,
            'NLB'                           as BRANCH_CLIENT,
            DLD_IFRS.BIC_XS_IDNUM           as CLIENT_NO,
            'NLB_'||DLD_IFRS.BIC_XS_IDNUM   as CLIENT_ID,
            PORTFOLIO_ROOT,
            FACILITY.SOURCE                 as SOURCE
        from NLB.DLD_DR_IFRS_CURRENT as DLD_IFRS
        inner join ALL_FACILITIES    as FACILITY     on (DLD_IFRS.BA1_C11EXTCON,'NLB')=(FACILITY.ID,FACILITY.BRANCH)
    ),
    UNIQUE_NBR as (
        select *, row_number() over (partition by BRANCH_CLIENT, CLIENT_NO order by SOURCE desc) as NBR
        from LEDIS_RAHMEN_NLB
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

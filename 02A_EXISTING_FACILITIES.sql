/* VIEW_PORTFOLIO_EXISTING_FACILITIES
 * Diese View gibt alle möglichen Kontonummern wieder, die uns für das Tape interessieren weil sie in einem vorherigen
 * Stichtag enthalten waren.
 */

-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_PORTFOLIO_EXISTING_FACILITIES;
create or replace view CALC.VIEW_PORTFOLIO_EXISTING_FACILITIES as
with
    CURRENT_CUTOFFDATE as (
        select CUT_OFF_DATE from CALC.AUTO_TABLE_CUTOFFDATES where IS_ACTIVE
    ),
    -- alle gewünschten Konten zusammenführen
    FACILITY_COLLECTION as (
        -- Bekannte Konten (aus dem Archiv)
        select distinct BRANCH_FACILITY,
                        FACILITY_ID,
                        coalesce(PORTFOLIO_EY_CLIENT_ROOT,CALC.MAP_FUNC_PORTFOLIO_TO_ROOT(PORTFOLIO_EY_FACILITY)) as PORTFOLIO,
                        DATA_CUT_OFF_DATE
        from CALC.SWITCH_PORTFOLIO_ARCHIVE
    ),
    -- Bekannte Kontenmappings:
    -- Kontenumbenennungen (Surrogate)
    FACILITY_SURROGATE as (
        select DUPLICATES.FACILITY_ID_INIT as FACILITY_ID_OLD, FACILITY_ID_NEW
        from CALC.VIEW_SURROGATE as DUPLICATES
        inner join CURRENT_CUTOFFDATE    as COD          on COD.CUT_OFF_DATE >= DUPLICATES.VALID_FROM_DATE
    ),
    -- Luxemburg Bezeichnungen (K028)
    FACILITY_NLB_TO_LUX as (
        select FACILITY_ID_NLB, FACILITY_ID_CBB
        from CALC.VIEW_FACILITY_CBB_TO_NLB as MAPPING
        inner join CURRENT_CUTOFFDATE                        as COD      on COD.CUT_OFF_DATE between MAPPING.VALID_FROM and coalesce(MAPPING.VALID_TO,CURRENT_DATE)
    ),
    -- INSTITUTSFUSION (BLB -> NLB)
    FACILITY_INSTITUTSFUSION as (
        select FACILITY_ID_ALT, FACILITY_ID_NEU
        from SMAP.FACILITY_INSTITUTSFUSION as MAPPING
    ),
    -- Portfolio eindeutig machen
    PORTFOLIO_SELECTION as (
        select distinct
            BRANCH_FACILITY,
            FACILITY_ID,
            CALC.MAP_FUNC_PORTFOLIO_TO_ROOT(first_value(PORTFOLIO) over (partition by FACILITY_ID, BRANCH_FACILITY order by DATA_CUT_OFF_DATE DESC nulls last)) as PORTFOLIO_ROOT_DESC
        from FACILITY_COLLECTION
        where FACILITY_ID is not NULL
    ),
    -- bevorzugten Portfolionamen auswählen
    -- Dies ist eine eindeutige Liste aller explizit gewünschten Kunden
    DESIRED_FACILITIES_REPORTED as (
        select
            case
                when LENGTH(BRANCH_FACILITY) > 3 then
                    'ANL'
                else
                    BRANCH_FACILITY
            end as BRANCH_FACILITY,
            FACILITY_ID,
            NULL as FACILITY_ID_REPORT,
            PORTFOLIO_ROOT_DESC as PORTFOLIO_ROOT
        from PORTFOLIO_SELECTION
    ),
    -- hinzufügen der Surrugate
    DESIRED_FACILITY_SURROGATE as (
        select
            BASE.BRANCH_FACILITY         as BRANCH_FACILITY, -- TODO: figure out a solution for this
            DUPLICATES.FACILITY_ID_NEW   as FACILITY_ID,
            BASE.FACILITY_ID             as FACILITY_ID_REPORT,
            PORTFOLIO_ROOT               as PORTFOLIO_ROOT
        from DESIRED_FACILITIES_REPORTED as BASE
        left join FACILITY_SURROGATE     as DUPLICATES on (DUPLICATES.FACILITY_ID_OLD) = (BASE.FACILITY_ID)
        where FACILITY_ID_NEW is not NULL
    ),
    -- hinzufügen der LUX-Kundennummern
    DESIRED_FACILITY_LUX_FROM_NLB as (
        select
            'CBB'                        as BRANCH_FACILITY,
            MAPPING.FACILITY_ID_CBB      as FACILITY_ID,
            BASE.FACILITY_ID             as FACILITY_ID_REPORT,
            PORTFOLIO_ROOT               as PORTFOLIO_ROOT
        from DESIRED_FACILITIES_REPORTED as BASE
        left join FACILITY_NLB_TO_LUX    as MAPPING on ('NLB', MAPPING.FACILITY_ID_NLB) = (BASE.BRANCH_FACILITY, BASE.FACILITY_ID)
        where MAPPING.FACILITY_ID_CBB is not NULL
    ),
     DESIRED_FACILITY_NLB_FROM_LUX as (
        select
            'NLB'                        as BRANCH_FACILITY,
            MAPPING.FACILITY_ID_NLB      as FACILITY_ID,
            BASE.FACILITY_ID             as FACILITY_ID_REPORT,
            PORTFOLIO_ROOT               as PORTFOLIO_ROOT
        from DESIRED_FACILITIES_REPORTED as BASE
        left join FACILITY_NLB_TO_LUX    as MAPPING on ('CBB', MAPPING.FACILITY_ID_CBB) = (BASE.BRANCH_FACILITY, BASE.FACILITY_ID)
        where MAPPING.FACILITY_ID_NLB is not NULL
    ),
    -- hinzufügen der Umbenennungen aus der Institutsfusion
    DESIRED_FACILITY_INSTITUTSFUSION as (
        select
            case when LEFT(MAPPING.FACILITY_ID_NEU,4) = '0009' then 'NLB' else 'BLB' end as BRANCH_FACILITY,
            MAPPING.FACILITY_ID_NEU        as FACILITY_ID,
            BASE.FACILITY_ID               as FACILITY_ID_REPORT,
            PORTFOLIO_ROOT                 as PORTFOLIO_ROOT
        from DESIRED_FACILITIES_REPORTED   as BASE
        left join FACILITY_INSTITUTSFUSION as MAPPING on (MAPPING.FACILITY_ID_ALT) = (BASE.FACILITY_ID)
        where MAPPING.FACILITY_ID_NEU is not NULL
    ),
    ALL_DESIRED_FACILITIES as (
        select *
        from DESIRED_FACILITIES_REPORTED
        union all
        select *
        from DESIRED_FACILITY_SURROGATE
        union all
        select *
        from DESIRED_FACILITY_LUX_FROM_NLB
        union all
        select *
        from DESIRED_FACILITY_NLB_FROM_LUX
        union all
        select *
        from DESIRED_FACILITY_INSTITUTSFUSION
    ),
    UNIQUE_DESIRED_FACILITIES as (
        select distinct 
            BRANCH_FACILITY, 
            FACILITY_ID, 
            coalesce(
                first_value(FACILITY_ID_REPORT) 
                    over (partition by FACILITY_ID, BRANCH_FACILITY order by FACILITY_ID_REPORT DESC nulls first),
                FACILITY_ID) as FACILITY_ID_REPORT, 
            PORTFOLIO_ROOT 
        from ALL_DESIRED_FACILITIES
    )
select *,
    Current USER                        as CREATED_USER,     -- Letzter Nutzer, der diese Tabelle gebaut hat.
    Current TIMESTAMP                   as CREATED_TIMESTAMP -- Neuester Zeitstempel, wann diese Tabelle zuletzt gebaut wurde.
from UNIQUE_DESIRED_FACILITIES
;
------------------------------------------------------------------------------------------------------------------------

-- CI START FOR ALL TAPES

-- CURRENT TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_PORTFOLIO_EXISTING_FACILITIES_CURRENT');
create table AMC.TABLE_PORTFOLIO_EXISTING_FACILITIES_CURRENT like CALC.VIEW_PORTFOLIO_EXISTING_FACILITIES distribute by hash(FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_TABLE_PORTFOLIO_EXISTING_FACILITIES_CURRENT_FACILITY_ID  on AMC.TABLE_PORTFOLIO_EXISTING_FACILITIES_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_PORTFOLIO_EXISTING_FACILITIES_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_PORTFOLIO_EXISTING_FACILITIES_CURRENT');
------------------------------------------------------------------------------------------------------------------------
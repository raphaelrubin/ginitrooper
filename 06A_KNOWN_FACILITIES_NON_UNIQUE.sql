/* Diese View enthällt alle Konten aus allen Systemen für deren Kontoinhaber wir uns interessieren. Dabei können Konten
   mehrfach vorkommen. */

-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_PORTFOLIO_KNOWN_FACILITIES_NON_UNIQUE;
create or replace view CALC.VIEW_PORTFOLIO_KNOWN_FACILITIES_NON_UNIQUE as
    with
    CURRENT_CUT_OFF_DATE as (
        select CUT_OFF_DATE from CALC.AUTO_TABLE_CUTOFFDATES where IS_ACTIVE
    ),
    -- Konten aus den einzelnen Quellsystemen zusammensammeln.
    -- PORTFOLIO_SYSTEM stellt die Bezeichnung im Portfoliotext dar
    -- ORDER_SYSTEM ist die bevorzugte Reihenfolge der Quellsysteme. Einträge mit einer niedrigen Nummer werden bevorzugt ausgewählt.
    RAW_FACILITIES(CUT_OFF_DATE, BRANCH_SYSTEM, BRANCH_CLIENT, CLIENT_NO, CLIENT_ID, CLIENT_IDS_NLB, CLIENT_IDS_BLB, CLIENT_IDS_CBB, BORROWER_NO, BRANCH_FACILITY, FACILITY_ID, CURRENCY, CREATED_USER, CREATED_TIMESTAMP, PORTFOLIO_SYSTEM, ORDER_SYSTEM) as (
        select FACILITY.*, 'SPOT' as PORTFOLIO_SYSTEM, 1 as ORDER_SYSTEM from CALC.SWITCH_PORTFOLIO_SPOT_CURRENT as FACILITY inner join CURRENT_CUT_OFF_DATE on FACILITY.CUT_OFF_DATE = CURRENT_CUT_OFF_DATE.CUT_OFF_DATE
        union all
        select FACILITY.*, 'ALIS' as PORTFOLIO_SYSTEM, 2 as ORDER_SYSTEM from CALC.SWITCH_PORTFOLIO_ALIS_CURRENT as FACILITY inner join CURRENT_CUT_OFF_DATE on FACILITY.CUT_OFF_DATE = CURRENT_CUT_OFF_DATE.CUT_OFF_DATE
        union all
        select FACILITY.*, 'DERIVATE' as PORTFOLIO_SYSTEM, 3 as ORDER_SYSTEM from CALC.SWITCH_PORTFOLIO_DERIVATE_CURRENT as FACILITY inner join CURRENT_CUT_OFF_DATE on FACILITY.CUT_OFF_DATE = CURRENT_CUT_OFF_DATE.CUT_OFF_DATE
        union all
        select FACILITY.*, 'BW' as PORTFOLIO_SYSTEM, 4 as ORDER_SYSTEM from CALC.SWITCH_PORTFOLIO_BW_CURRENT as FACILITY inner join CURRENT_CUT_OFF_DATE on FACILITY.CUT_OFF_DATE = CURRENT_CUT_OFF_DATE.CUT_OFF_DATE
        union all
        select FACILITY.*, 'DLD' as PORTFOLIO_SYSTEM, 5 as ORDER_SYSTEM from CALC.SWITCH_PORTFOLIO_DLD_CURRENT as FACILITY inner join CURRENT_CUT_OFF_DATE on FACILITY.CUT_OFF_DATE = CURRENT_CUT_OFF_DATE.CUT_OFF_DATE
        union all
        select FACILITY.*, 'AVALOQ' as PORTFOLIO_SYSTEM, 6 as ORDER_SYSTEM from CALC.SWITCH_PORTFOLIO_AVALOQ_CURRENT as FACILITY inner join CURRENT_CUT_OFF_DATE on FACILITY.CUT_OFF_DATE = CURRENT_CUT_OFF_DATE.CUT_OFF_DATE
    ),
    -- Konten aus der Grundgesamtheit und der Manuellen Kontenliste
    DESIRED_FACILITIES as (
        select * from CALC.SWITCH_PORTFOLIO_DESIRED_FACILITIES_CURRENT
    ),
    -- START CBB Facility Anpassung
    -- Kontenübersetzung von Luxemburg nach NLB
    CBB_FACILITY_TO_NLB_FACILITY(FACILITY_ID_CBB, FACILITY_ID_NLB,VALID_FROM_DATE,VALID_TO_DATE) as (
        select * from CALC.VIEW_FACILITY_CBB_TO_NLB
    ),
    -- Institutsfusionsüberführung
    MAPPING_INSTITUTSFUSION as (
        select FACILITY_ID_ALT as FACILITY_ID_BLB, FACILITY_ID_NEU as FACILITY_ID_NLB from SMAP.FACILITY_INSTITUTSFUSION
    ),
    -- CBB Facilities wenn möglich durch NLB ersetzen
    FACILITIES_WITH_CBB_RAW as (
        select
            SELECTION.*,
            case
                when FACILITY_BLB2NLB.FACILITY_ID_NLB is not NULL then
                    -- System FID hat zugehörige NLB FID durch Institutsfusion
                    FACILITY_BLB2NLB.FACILITY_ID_NLB
                when FACILITY_CBB2NLB.FACILITY_ID_NLB is not NULL then
                    -- System FID hat zugehörige NLB FID durch CBB Mapping
                    FACILITY_CBB2NLB.FACILITY_ID_NLB
                else
                    SELECTION.FACILITY_ID
            end as FACILITY_ID_LEADING, -- führende Facility ID (vorzugsweise NLB, berücksichtigt CBB und Institutsfusonsmapping)
            case
                when FACILITY_NLB2CBB.FACILITY_ID_CBB is not NULL then
                    -- System FID hat alternative CBB FID
                    FACILITY_NLB2CBB.FACILITY_ID_CBB
                when SELECTION.FACILITY_ID like 'K028%' then
                    -- System FID ist eine CBB FID
                    SELECTION.FACILITY_ID
                else
                    NULL
            end as FACILITY_ID_CBB, -- alternative CBB FID falls vorhanden
            case
                when FACILITY_NLB2BLB.FACILITY_ID_BLB is not NULL then
                    -- System FID hat eine alternative BLB FID
                    FACILITY_NLB2BLB.FACILITY_ID_BLB
                when SELECTION.FACILITY_ID like '0004%' then
                    -- System FID ist eine BLB FID
                    SELECTION.FACILITY_ID
                else
                    NULL
            end as FACILITY_ID_BLB, -- alternative BLB FID falls vorhanden
            case
                when FACILITY_BLB2NLB.FACILITY_ID_NLB is not NULL then
                    -- System FID hat alternative NLB FID durch Institutsfusion
                    FACILITY_BLB2NLB.FACILITY_ID_NLB
                when FACILITY_CBB2NLB.FACILITY_ID_NLB is not NULL then
                    -- System FID hat alternative NLB FID durch CBB Mapping
                    FACILITY_CBB2NLB.FACILITY_ID_NLB
                when SELECTION.FACILITY_ID like '0009%' then
                    -- System FID ist eine NLB FID
                    SELECTION.FACILITY_ID
                else
                    NULL
            end as FACILITY_ID_NLB -- alternative NLB FID falls vorhanden
        from RAW_FACILITIES as SELECTION
        left join CBB_FACILITY_TO_NLB_FACILITY  as FACILITY_NLB2CBB on SELECTION.FACILITY_ID= FACILITY_NLB2CBB.FACILITY_ID_NLB and SELECTION.CUT_OFF_DATE between FACILITY_NLB2CBB.VALID_FROM_DATE and FACILITY_NLB2CBB.VALID_TO_DATE
        left join CBB_FACILITY_TO_NLB_FACILITY  as FACILITY_CBB2NLB on SELECTION.FACILITY_ID=FACILITY_CBB2NLB.FACILITY_ID_CBB and SELECTION.CUT_OFF_DATE between FACILITY_CBB2NLB.VALID_FROM_DATE and FACILITY_CBB2NLB.VALID_TO_DATE
        left join MAPPING_INSTITUTSFUSION       as FACILITY_BLB2NLB on SELECTION.FACILITY_ID=FACILITY_BLB2NLB.FACILITY_ID_BLB
        left join MAPPING_INSTITUTSFUSION       as FACILITY_NLB2BLB on SELECTION.FACILITY_ID=FACILITY_NLB2BLB.FACILITY_ID_NLB
    ),
    FACILITIES_WITH_CBB as (
        select
            CUT_OFF_DATE, BRANCH_SYSTEM,
            BRANCH_CLIENT, CLIENT_NO, CLIENT_ID,
            CLIENT_IDS_NLB, CLIENT_IDS_BLB, CLIENT_IDS_CBB,
            BORROWER_NO,
            case when FACILITY_ID_NLB is not NULL then 'NLB' else trim(BRANCH_FACILITY) end as BRANCH_FACILITY,
            FACILITY_ID as FACILITY_ID, FACILITY_ID_LEADING, FACILITY_ID_NLB, FACILITY_ID_BLB, FACILITY_ID_CBB,
            PORTFOLIO_SYSTEM,
            CURRENCY,
            ORDER_SYSTEM
        from FACILITIES_WITH_CBB_RAW
    ),
    -- ENDE CBB facility anpassung
    -- Entscheidung Kontoauffüllung oder Konto Ergänzung?
    FACILITIES_WITH_PORTFOLIO_FACILITY as (
        select
            ALL_FACILITIES.*,
            case
                when DESIRED_FACILITIES.FACILITY_ID is NULL -- alle geforderten Konten sind Kontoauffüllungen
                 and PORTFOLIO_SYSTEM <> 'DERIVATE' -- alle Derivate sind Kontoauffüllungen
                 and (PORTFOLIO_SYSTEM <> 'DLD' or SUBSTR(ALL_FACILITIES.FACILITY_ID,6,2)||SUBSTR(ALL_FACILITIES.FACILITY_ID,22,2) <> '1120') then -- alle DLD 11-20 sind Kontoauffüllungen
                    0 -- Zusatzkonto
                else
                    1 -- Kontoauffüllung
            end as ORDER_FACILITY -- TODO: kann genutzt werden um festzustellen, ob alle Einträge ZUSATZKONTEN sind oder nicht
        from FACILITIES_WITH_CBB as ALL_FACILITIES
        left join DESIRED_FACILITIES on DESIRED_FACILITIES.FACILITY_ID in (ALL_FACILITIES.FACILITY_ID_CBB, ALL_FACILITIES.FACILITY_ID)
    ),
    FACILITY_IDS_WITH_ORDER_NO as (
        select *,
            case
                when ORDER_FACILITY = 0 then
                    'ZUSATZKONTO'
                else
                    'KONTOAUFFÜLLUNG'
            end as PORTFOLIO_FACILITY,
            (1-ORDER_FACILITY) * 10 + ORDER_SYSTEM as ORDER_NUMBER
         from FACILITIES_WITH_PORTFOLIO_FACILITY
    )
    select DATE(CUT_OFF_DATE)                                     as CUT_OFF_DATE,
           cast(BRANCH_SYSTEM as VARCHAR(3))                      as BRANCH_SYSTEM,
           cast(BRANCH_CLIENT as VARCHAR(3))                      as BRANCH_CLIENT,
           BIGINT(CLIENT_NO)                                      as CLIENT_NO,
           cast(CLIENT_ID as VARCHAR(32))                         as CLIENT_ID_SYSTEM,
           cast(CLIENT_IDS_NLB as VARCHAR(32))                    as CLIENT_IDS_NLB,
           cast(CLIENT_IDS_BLB as VARCHAR(32))                    as CLIENT_IDS_BLB,
           cast(CLIENT_IDS_CBB as VARCHAR(32))                    as CLIENT_IDS_CBB,
           --CLIENT_IDS_ALT  as CLIENT_IDS_ALTERNATIVE,
           cast(BORROWER_NO as VARCHAR(32))                       as BORROWER_NO,
           cast(BRANCH_FACILITY as VARCHAR(8))                    as BRANCH_FACILITY,
           FACILITY_ID                                            as FACILITY_ID,
           FACILITY_ID_LEADING                                    as FACILITY_ID_LEADING,
           cast(nullif(FACILITY_ID_NLB, NULL) as VARCHAR(64))     as FACILITY_ID_NLB,
           cast(nullif(FACILITY_ID_BLB, NULL) as VARCHAR(64))     as FACILITY_ID_BLB,
           cast(nullif(FACILITY_ID_CBB, NULL) as VARCHAR(64))     as FACILITY_ID_CBB,
           cast(nullif(PORTFOLIO_SYSTEM, NULL) as VARCHAR(64))    as SYSTEM,
           cast(nullif(PORTFOLIO_FACILITY, NULL) as VARCHAR(128)) as FACILITY_REQUEST_TYPE,
           --coalesce(PORTFOLIO_ROOT,'Ohne Portfolio')||' '||case when PORTFOLIO_SYSTEM = 'AVALOQ' then 'AVALOQ REACTIVATION' else PORTFOLIO_SYSTEM end||' '||PORTFOLIO_FACILITY as PORTFOLIO,
           BIGINT(ORDER_FACILITY)                                 as ORDER_FACILITY,
           cast(CURRENCY as VARCHAR(3))                           as CURRENCY,
           BIGINT(ORDER_NUMBER)                                   as ORDER_NUMBER
    from FACILITY_IDS_WITH_ORDER_NO
;
------------------------------------------------------------------------------------------------------------------------

-- CI START FOR ALL TAPES

-- CURRENT TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_PORTFOLIO_KNOWN_FACILITIES_NON_UNIQUE_CURRENT');
create table AMC.TABLE_PORTFOLIO_KNOWN_FACILITIES_NON_UNIQUE_CURRENT like CALC.VIEW_PORTFOLIO_KNOWN_FACILITIES_NON_UNIQUE distribute by hash(FACILITY_ID,FACILITY_ID_CBB) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_PORTFOLIO_KNOWN_FACILITIES_NON_UNIQUE_CURRENT_BRANCH_CLIENT   on AMC.TABLE_PORTFOLIO_KNOWN_FACILITIES_NON_UNIQUE_CURRENT (BRANCH_CLIENT);
create index AMC.INDEX_PORTFOLIO_KNOWN_FACILITIES_NON_UNIQUE_CURRENT_CLIENT_NO       on AMC.TABLE_PORTFOLIO_KNOWN_FACILITIES_NON_UNIQUE_CURRENT (CLIENT_NO);
create index AMC.INDEX_PORTFOLIO_KNOWN_FACILITIES_NON_UNIQUE_CURRENT_FACILITY_ID     on AMC.TABLE_PORTFOLIO_KNOWN_FACILITIES_NON_UNIQUE_CURRENT (FACILITY_ID);
create index AMC.INDEX_PORTFOLIO_KNOWN_FACILITIES_NON_UNIQUE_CURRENT_FACILITY_ID_CBB on AMC.TABLE_PORTFOLIO_KNOWN_FACILITIES_NON_UNIQUE_CURRENT (FACILITY_ID_CBB);
create index AMC.INDEX_PORTFOLIO_KNOWN_FACILITIES_NON_UNIQUE_CURRENT_FACILITY_ID_NLB on AMC.TABLE_PORTFOLIO_KNOWN_FACILITIES_NON_UNIQUE_CURRENT (FACILITY_ID_NLB);
create index AMC.INDEX_PORTFOLIO_KNOWN_FACILITIES_NON_UNIQUE_CURRENT_FACILITY_ID_BLB on AMC.TABLE_PORTFOLIO_KNOWN_FACILITIES_NON_UNIQUE_CURRENT (FACILITY_ID_BLB);
create index AMC.INDEX_PORTFOLIO_KNOWN_FACILITIES_NON_UNIQUE_CURRENT_FACILITY_ID_LEADING on AMC.TABLE_PORTFOLIO_KNOWN_FACILITIES_NON_UNIQUE_CURRENT (FACILITY_ID_LEADING);

create index AMC.INDEX_PORTFOLIO_KNOWN_FACILITIES_NON_UNIQUE_CURRENT_ORDER_NUMBER    on AMC.TABLE_PORTFOLIO_KNOWN_FACILITIES_NON_UNIQUE_CURRENT (ORDER_NUMBER);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_PORTFOLIO_KNOWN_FACILITIES_NON_UNIQUE_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_PORTFOLIO_KNOWN_FACILITIES_NON_UNIQUE_CURRENT');
------------------------------------------------------------------------------------------------------------------------

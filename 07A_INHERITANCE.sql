/*Komplette Portfolio Vererbung (PAST und FUTURE)*/

-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_PORTFOLIO_INHERITANCE;
create or replace view CALC.VIEW_PORTFOLIO_INHERITANCE as
with
--     CBB_FACILITY_TO_NLB_FACILITY(FACILITY_ID_CBB, FACILITY_ID_NLB,VALID_FROM_DATE,VALID_TO_DATE) as (
--         select * from CALC.VIEW_FACILITY_CBB_TO_NLB
--     ),
     -- zu bauende Stichtag
    CURRENT_CUT_OFF_DATE as (
        select CUT_OFF_DATE
        from CALC.AUTO_TABLE_CUTOFFDATES
        where IS_ACTIVE
    ),
--     CLIENT_TO_PORTFOLIO as (
--         select BRANCH_CLIENT, CLIENT_NO, PORTFOLIO_EY_CLIENT_ROOT as PORTFOLIO_ROOT,
--         PORTFOLIO_IWHS_CLIENT_KUNDENBERATER,
--         PORTFOLIO_IWHS_CLIENT_SERVICE,
--         PORTFOLIO_KR_CLIENT,
--         PORTFOLIO_GARANTIEN_CLIENT
--         from CALC.SWITCH_PORTFOLIO_DESIRED_CLIENTS_CURRENT
--     ),
    CURRENT_DATA as (
        select
            CUT_OFF_DATE as CUT_OFF_DATE,
            CUT_OFF_DATE as DATA_CUT_OFF_DATE,
            BRANCH_SYSTEM as BRANCH_SYSTEM,
            SYSTEM as SYSTEM,
            BRANCH_CLIENT as BRANCH_CLIENT,
            CLIENT_NO as CLIENT_NO,
            CLIENT_ID as CLIENT_ID,
            CLIENT_IDS_ALT as CLIENT_IDS_ALT,
            BORROWER_NO as BORROWER_NO,
            cast(BRANCH_FACILITY as VARCHAR(8)) as BRANCH_FACILITY,
            FACILITY_ID as FACILITY_ID,
            FACILITY_ID_LEADING,FACILITY_ID_NLB,FACILITY_ID_BLB,
            FACILITY_ID_CBB as FACILITY_ID_CBB,
            ORIGINAL_CURRENCY as CURRENCY,
            FACILITY_REQUEST_TYPE
        from CALC.SWITCH_PORTFOLIO_KNOWN_FACILITIES_CURRENT as CURRENT_FACILITIES
    ),
    ARCHIVED_DATA_RAW as (
        select distinct
            arch.CUT_OFF_DATE as CUT_OFF_DATE,
            DATA_CUT_OFF_DATE,
            BRANCH_SYSTEM as BRANCH_SYSTEM,
            SYSTEM as SYSTEM,
            arch.BRANCH_CLIENT,
            arch.CLIENT_NO AS CLIENT_NO,
            CLIENT_ID_ORIG as CLIENT_ID,
            CLIENT_ID_ALT as CLIENT_IDS_ALT,
            BORROWER_NO AS BORROWER_NO,
            cast(BRANCH_FACILITY as VARCHAR(8)) as BRANCH_FACILITY,
            FACILITY_ID,FACILITY_ID_LEADING,FACILITY_ID_NLB,FACILITY_ID_BLB,
            arch.FACILITY_ID_CBB as FACILITY_ID_CBB,
            CURRENCY as CURRENCY,
            NULL as FACILITY_REQUEST_TYPE
            --coalesce(CLIENT_NEW.PORTFOLIO_ROOT,CALC.MAP_FUNC_PORTFOLIO_TO_ROOT(PORTFOLIO)) AS PORTFOLIO_ROOT
        from CALC.SWITCH_PORTFOLIO_ARCHIVE as arch
        --left join CBB_FACILITY_TO_NLB_FACILITY  as FACILITY_N2C on ARCH.FACILITY_ID=FACILITY_N2C.FACILITY_ID_NLB and ARCH.CUT_OFF_DATE between FACILITY_N2C.VALID_FROM_DATE and FACILITY_N2C.VALID_TO_DATE
        --left join CLIENT_TO_PORTFOLIO as CLIENT_NEW on (ARCH.CLIENT_NO, ARCH.BRANCH_CLIENT) = (CLIENT_NEW.CLIENT_NO, CLIENT_NEW.BRANCH_CLIENT)
        -- exclude results from last run for this cutoffdate
        left join CURRENT_CUT_OFF_DATE as A on A.CUT_OFF_DATE=ARCH.CUT_OFF_DATE
        --left join CURRENT_CUT_OFF_DATE as B on B.CUT_OFF_DATE=ARCH.DATA_CUT_OFF_DATE
        where (A.CUT_OFF_DATE is null ) --and B.CUT_OFF_DATE is null
          and arch.CUT_OFF_DATE = arch.DATA_CUT_OFF_DATE
    ),
    ARCHIVED_DATA as (
        select
            CUT_OFF_DATE,DATA_CUT_OFF_DATE,BRANCH_SYSTEM,
            SYSTEM as SYSTEM,
            BRANCH_CLIENT,
            CLIENT_NO,CLIENT_ID,CLIENT_IDS_ALT,BORROWER_NO,
            BRANCH_FACILITY,FACILITY_ID,FACILITY_ID_LEADING,FACILITY_ID_NLB,FACILITY_ID_BLB,FACILITY_ID_CBB,CURRENCY,
            FACILITY_REQUEST_TYPE
--             IS_GUARANTEE_FLAGGED,
--             coalesce(PORTFOLIO_MAP.PORTFOLIO_ROOT,ARCHIVED_DATA.PORTFOLIO_ROOT) as PORTFOLIO,
--             coalesce(PORTFOLIO_MAP.PORTFOLIO_ROOT,ARCHIVED_DATA.PORTFOLIO_ROOT) as PORTFOLIO_ROOT,
--             NULL as KUNDENBETREUER_OE_BEZEICHNUNG -- TODO: später befüllen, wenn bis ins Portfolio Archiv weitergegeben
        from ARCHIVED_DATA_RAW as ARCHIVED_DATA
        --left join SMAP.AMC_OENAME_TO_PORTFOLIO as PORTFOLIO_MAP on ARCHIVED_DATA.PORTFOLIO_ROOT = PORTFOLIO_MAP.OE_BEZEICHNUNG and ARCHIVED_DATA.CUT_OFF_DATE between PORTFOLIO_MAP.VALID_FROM_DATE and PORTFOLIO_MAP.VALID_TO_DATE
    ),
    -- Alle Daten aus der vorherigen Schicht, welche dem jetzigen Cut Off Date entsprechen (überflüssig, wenn die vorherige Schicht nur noch ein COD liefert)
    RELEVANT_FACILITIES as (
        select PORTFOLIO_PRE.*, ADD_MONTHS(DATA_CUT_OFF_DATE,7) AS DATA_CUT_OFF_DATE_PLUS_7
        from CURRENT_DATA AS PORTFOLIO_PRE
        union all
        select PORTFOLIO_PAST_PRE.*, ADD_MONTHS(DATA_CUT_OFF_DATE,7) AS DATA_CUT_OFF_DATE_PLUS_7
        from ARCHIVED_DATA AS PORTFOLIO_PAST_PRE
    ),
    -- VERERBUNG START --
    -- Gebe jedem Cut Off Date eine Nummer absteigend (i.e. neuestes COD ist Nummer 1)
    CUTOFFDATES_NUMBERED as (
        select DATA_CUT_OFF_DATE AS CUT_OFF_DATE,ROW_NUMBER() over (order by DATA_CUT_OFF_DATE desc) as NBR
        from (select distinct DATA_CUT_OFF_DATE from RELEVANT_FACILITIES)
    ),
    -- alle Stichtage für die ein COD in der Vergangenheit vorliegt werden hier erzeugt
    INHERITANCE_PRE as (
        select
            RELEVANT_FACILITIES.CUT_OFF_DATE as CUT_OFF_DATE,
            CUTOFFDATE_NUMBERED.CUT_OFF_DATE as NEW_CUT_OFF_DATE,
            RELEVANT_FACILITIES.DATA_CUT_OFF_DATE as DATA_CUT_OFF_DATE, DATA_CUT_OFF_DATE_PLUS_7,
            BRANCH_SYSTEM,SYSTEM,BRANCH_CLIENT,CLIENT_NO,CLIENT_ID,CLIENT_IDS_ALT,BORROWER_NO,
            BRANCH_FACILITY,FACILITY_ID,FACILITY_ID_LEADING,FACILITY_ID_NLB,FACILITY_ID_BLB,FACILITY_ID_CBB,CURRENCY,FACILITY_REQUEST_TYPE,
            ABS(DATA_CUT_OFF_DATE - CUTOFFDATE_NUMBERED.CUT_OFF_DATE) AS INHERITANCE_TIME_DIFFERENCE, -- Differenz zwischen gewünschtem Stichtag und Stichtag des Datensatzes
            MOD(SIGN(DATA_CUT_OFF_DATE - CUTOFFDATE_NUMBERED.CUT_OFF_DATE)+2,3) AS INHERITANCE_DIRECTION_ORDER -- 2 = Identisch, 1 = aus Vergangenheit, 0 = aus Zukunft
        from CUTOFFDATES_NUMBERED as CUTOFFDATE_NUMBERED
        cross join RELEVANT_FACILITIES as RELEVANT_FACILITIES -- jede Kombination von CUT_OFF_DATE und Eintrag ...(2)
        where CUTOFFDATE_NUMBERED.CUT_OFF_DATE < DATA_CUT_OFF_DATE_PLUS_7 -- .. nach 7 Monaten mit dem Vererben aufhören
    --todo: umzug der berechnung der ADD MONTH in die zugehörigen ausgangstabellen.
        ),
     INHERITANCE_FILTER as (
        select
            NEW_CUT_OFF_DATE, DATA_CUT_OFF_DATE, DATA_CUT_OFF_DATE_PLUS_7,
            BRANCH_SYSTEM,BRANCH_CLIENT,SYSTEM,CLIENT_NO,CLIENT_ID,CLIENT_IDS_ALT,BORROWER_NO,
            BRANCH_FACILITY,FACILITY_ID,FACILITY_ID_LEADING,FACILITY_ID_NLB,FACILITY_ID_BLB,FACILITY_ID_CBB,CURRENCY,
            INHERITANCE_DIRECTION_ORDER,
            FACILITY_REQUEST_TYPE,
            ROW_NUMBER() over (partition by FACILITY_ID,NEW_CUT_OFF_DATE order by INHERITANCE_DIRECTION_ORDER DESC, INHERITANCE_TIME_DIFFERENCE, PRE.CUT_OFF_DATE DESC) as FILTER -- gleiches Datum vor Vergangenheitsdaten vor Zukunftsdaten, nähere Daten zuerst
        from INHERITANCE_PRE as PRE
        inner join CURRENT_CUT_OFF_DATE on PRE.NEW_CUT_OFF_DATE = CURRENT_CUT_OFF_DATE.CUT_OFF_DATE -- Wir berechnen nur einen stichtag - das andere wird sowieso nicht durchgeleitet an andere Stichtage sondern dann neu berechnet.
     )
    select distinct
        NEW_CUT_OFF_DATE as NEW_CUT_OFF_DATE,
        DATA_CUT_OFF_DATE as DATA_CUT_OFF_DATE,
        BRANCH_SYSTEM as BRANCH_SYSTEM,
        SYSTEM as SYSTEM,
        BRANCH_CLIENT as BRANCH_CLIENT,
        CLIENT_NO as CLIENT_NO,
        CLIENT_ID as CLIENT_ID_ORIG,
        CLIENT_IDS_ALT as CLIENT_IDS_ALT,
        BORROWER_NO as BORROWER_NO,
        BRANCH_FACILITY as BRANCH_FACILITY,
        FACILITY_ID as FACILITY_ID,
        FACILITY_ID_LEADING as FACILITY_ID_LEADING,
        FACILITY_ID_NLB as FACILITY_ID_NLB,
        FACILITY_ID_BLB as FACILITY_ID_BLB,
        FACILITY_ID_CBB as FACILITY_ID_CBB,
        CURRENCY as CURRENCY,
        nullif(trim(coalesce(FACILITY_REQUEST_TYPE,'') ||
        case
            when INHERITANCE_DIRECTION_ORDER = 1 then ' Konto Auffüllung aus Vergangenheit'
            when INHERITANCE_DIRECTION_ORDER = 0 then ' Konto Auffüllung aus Zukunft'
            else ''
        end), NULL) as FACILITY_REQUEST_TYPE
    from INHERITANCE_FILTER
    cross join CURRENT_CUT_OFF_DATE as CURRENT
    where 1=1
      and FILTER = 1
      and (CURRENT.CUT_OFF_DATE = NEW_CUT_OFF_DATE or CURRENT.CUT_OFF_DATE = DATA_CUT_OFF_DATE)
;
------------------------------------------------------------------------------------------------------------------------

-- CI START FOR ALL TAPES

-- CURRENT TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_PORTFOLIO_INHERITANCE_CURRENT');
create table AMC.TABLE_PORTFOLIO_INHERITANCE_CURRENT like CALC.VIEW_PORTFOLIO_INHERITANCE distribute by hash(FACILITY_ID,FACILITY_ID_CBB) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_PORTFOLIO_INHERITANCE_CURRENT_BRANCH_CLIENT   on AMC.TABLE_PORTFOLIO_INHERITANCE_CURRENT (BRANCH_CLIENT);
create index AMC.INDEX_PORTFOLIO_INHERITANCE_CURRENT_CLIENT_NO       on AMC.TABLE_PORTFOLIO_INHERITANCE_CURRENT (CLIENT_NO);
create index AMC.INDEX_PORTFOLIO_INHERITANCE_CURRENT_FACILITY_ID     on AMC.TABLE_PORTFOLIO_INHERITANCE_CURRENT (FACILITY_ID);
create index AMC.INDEX_PORTFOLIO_INHERITANCE_CURRENT_FACILITY_ID_CBB on AMC.TABLE_PORTFOLIO_INHERITANCE_CURRENT (FACILITY_ID_CBB);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_PORTFOLIO_INHERITANCE_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_PORTFOLIO_INHERITANCE_CURRENT');
------------------------------------------------------------------------------------------------------------------------

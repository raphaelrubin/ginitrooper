/* VIEW_PORTFOLIO_SPOT
 * Sammelt alle Konten für die DESIRED CLIENTS aus den SPOT Stammdaten Quelltabellen
 */

-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_PORTFOLIO_SPOT;
create or replace view CALC.VIEW_PORTFOLIO_SPOT as
with
    ALL_CLIENTS as (
        select * from CALC.SWITCH_PORTFOLIO_DESIRED_CLIENTS_CURRENT
    ),
    SPOT_NLB as (
        select
            STAMMDATEN.CUTOFFDATE           as CUT_OFF_DATE,
            'NLB'                           as BRANCH_SYSTEM,
            CLIENT.BRANCH_CLIENT            as BRANCH_CLIENT,
            CLIENT.CLIENT_NO                as CLIENT_NO,
            CLIENT.CLIENT_ID                as CLIENT_ID,
            CLIENT.CLIENT_IDS_NLB           as CLIENT_IDS_NLB,
            CLIENT.CLIENT_IDS_BLB           as CLIENT_IDS_BLB,
            CLIENT.CLIENT_IDS_CBB           as CLIENT_IDS_CBB,
            CLIENT.BORROWER_NO              as BORROWER_NO,
            STAMMDATEN.BRANCH               as BRANCH_FACILITY,
            STAMMDATEN.FACILITY_ID          as FACILITY_ID,
            STAMMDATEN.ACCOUNT_CURRENCY     as ORIGINAL_CURRENCY
        from NLB.SPOT_STAMMDATEN_CURRENT        as STAMMDATEN
        inner join ALL_CLIENTS                  as CLIENT     on (STAMMDATEN.CLIENT_ID,'NLB',STAMMDATEN.CUTOFFDATE)=(CLIENT.CLIENT_NO,CLIENT.BRANCH_CLIENT,CLIENT.CUT_OFF_DATE)
    ),
    SPOT_BLB as (
        select
            STAMMDATEN.CUTOFFDATE           as CUT_OFF_DATE,
            'BLB'                           as BRANCH_SYSTEM,
            CLIENT.BRANCH_CLIENT            as BRANCH_CLIENT,
            CLIENT.CLIENT_NO                as CLIENT_NO,
            CLIENT.CLIENT_ID                as CLIENT_ID,
            CLIENT.CLIENT_IDS_NLB           as CLIENT_IDS_NLB,
            CLIENT.CLIENT_IDS_BLB           as CLIENT_IDS_BLB,
            CLIENT.CLIENT_IDS_CBB           as CLIENT_IDS_CBB,
            CLIENT.BORROWER_NO              as BORROWER_NO,
            STAMMDATEN.BRANCH               as BRANCH_FACILITY,
            STAMMDATEN.FACILITY_ID          as FACILITY_ID,
            STAMMDATEN.ACCOUNT_CURRENCY     as ORIGINAL_CURRENCY
        from BLB.SPOT_STAMMDATEN_CURRENT        as STAMMDATEN
        inner join ALL_CLIENTS                  as CLIENT     on (STAMMDATEN.CLIENT_ID,'BLB',STAMMDATEN.CUTOFFDATE)=(CLIENT.CLIENT_NO,CLIENT.BRANCH_CLIENT,CLIENT.CUT_OFF_DATE)
    ),
    SPOT_ANL as (
        select
            STAMMDATEN.CUTOFFDATE           as CUT_OFF_DATE,
            'ANL'                           as BRANCH_SYSTEM,
            CLIENT.BRANCH_CLIENT            as BRANCH_CLIENT,
            CLIENT.CLIENT_NO                as CLIENT_NO,
            CLIENT.CLIENT_ID                as CLIENT_ID,
            CLIENT.CLIENT_IDS_NLB           as CLIENT_IDS_NLB,
            CLIENT.CLIENT_IDS_BLB           as CLIENT_IDS_BLB,
            CLIENT.CLIENT_IDS_CBB           as CLIENT_IDS_CBB,
            CLIENT.BORROWER_NO              as BORROWER_NO,
            STAMMDATEN.BRANCH               as BRANCH_FACILITY,
            STAMMDATEN.FACILITY_ID          as FACILITY_ID,
            STAMMDATEN.ACCOUNT_CURRENCY     as ORIGINAL_CURRENCY
        from ANL.SPOT_STAMMDATEN_CURRENT        as STAMMDATEN
        inner join ALL_CLIENTS                  as CLIENT     on (STAMMDATEN.CLIENT_ID,'NLB',STAMMDATEN.CUTOFFDATE)=(CLIENT.CLIENT_NO,CLIENT.BRANCH_CLIENT,CLIENT.CUT_OFF_DATE)
    ),
    SPOT_CBB as (
        select
            STAMMDATEN.CUTOFFDATE           as CUT_OFF_DATE,
            'CBB'                           as BRANCH_SYSTEM,
            CLIENT.BRANCH_CLIENT            as BRANCH_CLIENT,
            CLIENT.CLIENT_NO                as CLIENT_NO,
            CLIENT.CLIENT_ID                as CLIENT_ID,
            CLIENT.CLIENT_IDS_NLB           as CLIENT_IDS_NLB,
            CLIENT.CLIENT_IDS_BLB           as CLIENT_IDS_BLB,
            CLIENT.CLIENT_IDS_CBB           as CLIENT_IDS_CBB,
            CLIENT.BORROWER_NO              as BORROWER_NO,
            'CBB'                           as BRANCH_FACILITY,
            'K028-'|| (STAMMDATEN.KKTOAVA + case when STAMMDATEN.KKTOAVA = '2588650' then 3 else 1 end ) || '_1020' as FACILITY_ID,
            STAMMDATEN.KRISO                as ORIGINAL_CURRENCY
        from CBB.SPOT_STAMMDATEN_CURRENT        as STAMMDATEN
        inner join ALL_CLIENTS                  as CLIENT     on (STAMMDATEN.KRKUND,'NLB',STAMMDATEN.CUTOFFDATE)=(CLIENT.CLIENT_NO,CLIENT.BRANCH_CLIENT,CLIENT.CUT_OFF_DATE)
        where STAMMDATEN.KKTOAVA is not NULL
    ),
    SPOT_CBB_SSART20 as (
        select
            STAMMDATEN.CUTOFFDATE           as CUT_OFF_DATE,
            'CBB'                           as BRANCH_SYSTEM,
            CLIENT.BRANCH_CLIENT            as BRANCH_CLIENT,
            CLIENT.CLIENT_NO                as CLIENT_NO,
            CLIENT.CLIENT_ID                as CLIENT_ID,
            CLIENT.CLIENT_IDS_NLB           as CLIENT_IDS_NLB,
            CLIENT.CLIENT_IDS_BLB           as CLIENT_IDS_BLB,
            CLIENT.CLIENT_IDS_CBB           as CLIENT_IDS_CBB,
            CLIENT.BORROWER_NO              as BORROWER_NO,
            'CBB'                           as BRANCH_FACILITY,
            'K028-'|| (STAMMDATEN.KKTOAVA + case when STAMMDATEN.KKTOAVA = '2588650' then 3 else 1 end ) || '_4200' as FACILITY_ID,
            STAMMDATEN.KRISO                as ORIGINAL_CURRENCY
        from CBB.SPOT_STAMMDATEN_CURRENT        as STAMMDATEN
        inner join ALL_CLIENTS                  as CLIENT     on (STAMMDATEN.KRKUND,'NLB',STAMMDATEN.CUTOFFDATE)=(CLIENT.CLIENT_NO,CLIENT.BRANCH_CLIENT,CLIENT.CUT_OFF_DATE)
        where STAMMDATEN.KKTOAVA is not NULL
          and STAMMDATEN.SSART = '20'
    ),
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
    )
select
    DATE(CUT_OFF_DATE)                      as CUT_OFF_DATE,
    cast(BRANCH_SYSTEM as CHAR(3))          as BRANCH_SYSTEM,
    cast(BRANCH_CLIENT as CHAR(3))          as BRANCH_CLIENT,
    BIGINT(CLIENT_NO)                       as CLIENT_NO,
    cast(CLIENT_ID as VARCHAR(32))          as CLIENT_ID,
    cast(CLIENT_IDS_NLB as VARCHAR(32))     as CLIENT_IDS_NLB,
    cast(CLIENT_IDS_BLB as VARCHAR(32))     as CLIENT_IDS_BLB,
    cast(CLIENT_IDS_CBB as VARCHAR(32))     as CLIENT_IDS_CBB,
    cast(BORROWER_NO as BIGINT)             as BORROWER_NO,
    cast(BRANCH_FACILITY as CHAR(8))        as BRANCH_FACILITY,
    cast(FACILITY_ID as VARCHAR(64))        as FACILITY_ID,
    cast(ORIGINAL_CURRENCY as CHAR(3))      as CURRENCY,
    Current USER                            as CREATED_USER,     -- Letzter Nutzer, der diese Tabelle gebaut hat.
    Current TIMESTAMP                       as CREATED_TIMESTAMP -- Neuester Zeitstempel, wann diese Tabelle zuletzt gebaut wurde.
from COLLECTION
;
------------------------------------------------------------------------------------------------------------------------

-- CI START FOR ALL TAPES

-- CURRENT TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_PORTFOLIO_SPOT_CURRENT');
create table AMC.TABLE_PORTFOLIO_SPOT_CURRENT like CALC.VIEW_PORTFOLIO_SPOT distribute by hash(FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_PORTFOLIO_SPOT_CURRENT_BRANCH_CLIENT on AMC.TABLE_PORTFOLIO_SPOT_CURRENT (BRANCH_CLIENT);
create index AMC.INDEX_PORTFOLIO_SPOT_CURRENT_CLIENT_NO     on AMC.TABLE_PORTFOLIO_SPOT_CURRENT (CLIENT_NO);
create index AMC.INDEX_PORTFOLIO_SPOT_CURRENT_FACILITY_ID   on AMC.TABLE_PORTFOLIO_SPOT_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_PORTFOLIO_SPOT_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_PORTFOLIO_SPOT_CURRENT');
------------------------------------------------------------------------------------------------------------------------

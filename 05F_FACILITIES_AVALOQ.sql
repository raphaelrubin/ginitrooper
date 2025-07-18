/* VIEW_PORTFOLIO_AVALOQ
 * Sammelt alle Konten für die DESIRED CLIENTS aus den AVALOQ Stammdaten Quelltabellen
 */

-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_PORTFOLIO_AVALOQ;
create or replace view CALC.VIEW_PORTFOLIO_AVALOQ as
with
    ALL_CLIENTS as (
        select * from CALC.SWITCH_PORTFOLIO_DESIRED_CLIENTS_CURRENT
    ),
    AVALOQ_ANL as (
        select
            STAMMDATEN.CUT_OFF_DATE         as CUT_OFF_DATE,
            'ANL'                           as BRANCH_SYSTEM,
            CLIENT.BRANCH_CLIENT            as BRANCH_CLIENT,
            CLIENT.CLIENT_NO                as CLIENT_NO,
            CLIENT.CLIENT_ID                as CLIENT_ID,
            CLIENT.CLIENT_IDS_NLB           as CLIENT_IDS_NLB,
            CLIENT.CLIENT_IDS_BLB           as CLIENT_IDS_BLB,
            CLIENT.CLIENT_IDS_CBB           as CLIENT_IDS_CBB,
            CLIENT.BORROWER_NO              as BORROWER_NO,
            STAMMDATEN.BRANCH               as BRANCH_FACILITY,
            STAMMDATEN.HO_ACC_NUMBER        as FACILITY_ID,
            STAMMDATEN.POS_CCY              as ORIGINAL_CURRENCY
        from ANL.AVALOQ_PAST_DUE   as STAMMDATEN
        inner join ALL_CLIENTS     as CLIENT     on (STAMMDATEN.BP_KIS,'NLB',STAMMDATEN.CUT_OFF_DATE)=(CLIENT.CLIENT_NO,CLIENT.BRANCH_CLIENT,CLIENT.CUT_OFF_DATE)
        where HO_ACC_NUMBER <> 'not defined'
    ),
    COLLECTION as (
        select * from AVALOQ_ANL
    ),
    AVALOQ_UNIQUE as (
        select *, row_number() over (partition by FACILITY_ID, CUT_OFF_DATE order by CLIENT_ID desc) as NBR
        from AVALOQ_ANL
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
from AVALOQ_UNIQUE where NBR = 1
;
------------------------------------------------------------------------------------------------------------------------

-- CI START FOR ALL TAPES

-- CURRENT TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_PORTFOLIO_AVALOQ_CURRENT');
create table AMC.TABLE_PORTFOLIO_AVALOQ_CURRENT like CALC.VIEW_PORTFOLIO_AVALOQ distribute by hash(FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_PORTFOLIO_AVALOQ_CURRENT_BRANCH_CLIENT on AMC.TABLE_PORTFOLIO_AVALOQ_CURRENT (BRANCH_CLIENT);
create index AMC.INDEX_PORTFOLIO_AVALOQ_CURRENT_CLIENT_NO     on AMC.TABLE_PORTFOLIO_AVALOQ_CURRENT (CLIENT_NO);
create index AMC.INDEX_PORTFOLIO_AVALOQ_CURRENT_FACILITY_ID   on AMC.TABLE_PORTFOLIO_AVALOQ_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_PORTFOLIO_AVALOQ_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_PORTFOLIO_AVALOQ_CURRENT');
------------------------------------------------------------------------------------------------------------------------

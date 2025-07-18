/* VIEW_PORTFOLIO_BW
 * Sammelt alle Konten für die DESIRED CLIENTS aus den BW Stammdaten Quelltabellen
 */

-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_PORTFOLIO_BW;
create or replace view CALC.VIEW_PORTFOLIO_BW as
with
    CURRENT_CUTOFFDATE as (
        select CUT_OFF_DATE from CALC.AUTO_TABLE_CUTOFFDATES where IS_ACTIVE
    ),
    ALL_CLIENTS as (
        select * from CALC.SWITCH_PORTFOLIO_DESIRED_CLIENTS_CURRENT
    ),
    -- BW Konten
    BW_STAMMDATEN as (
        select A.* from CALC.SWITCH_BW_STAMMDATEN_CURRENT as A
        inner join CURRENT_CUTOFFDATE as B on A.CUT_OFF_DATE=B.CUT_OFF_DATE --nur aktuelles Datum mitnehmen --todo: ist dies notwendig?
    ),
    -- BW Zusatzkonten
    BW_STAMMDATEN_REMAINING_KR_CLIENTS
    as (

        select distinct
            BW_STAMMDATEN.CUT_OFF_DATE as CUT_OFF_DATE,
            BW_STAMMDATEN.BRANCH_SHORT      as BRANCH_SYSTEM,
            CLIENT.BRANCH_CLIENT            as BRANCH_CLIENT,
            CLIENT.CLIENT_NO                as CLIENT_NO,
            CLIENT.CLIENT_ID                as CLIENT_ID,
            CLIENT.CLIENT_IDS_NLB           as CLIENT_IDS_NLB,
            CLIENT.CLIENT_IDS_BLB           as CLIENT_IDS_BLB,
            CLIENT.CLIENT_IDS_CBB           as CLIENT_IDS_CBB,
            CLIENT.BORROWER_NO              as BORROWER_NO,
            BW_STAMMDATEN.BRANCH_ACCOUNT    as BRANCH_FACILITY,
            BW_STAMMDATEN.FACILITY_ID       as FACILITY_ID,
--             CLIENT.PORTFOLIO_EY_CLIENT_ROOT as PORTFOLIO_ROOT,
            BW_STAMMDATEN.CURRENCY          as ORIGINAL_CURRENCY
--             BW_STAMMDATEN.PRODUCT_TYPE_DETAIL as PRODUCT_TYPE_DETAIL,
--             BW_STAMMDATEN.PRODUCT_TYPE      as PRODUCT_TYPE
        from BW_STAMMDATEN              as BW_STAMMDATEN
        inner join ALL_CLIENTS          as CLIENT on (BW_STAMMDATEN.CLIENT_NO, BW_STAMMDATEN.BRANCH_CLIENT, BW_STAMMDATEN.CUT_OFF_DATE)=(CLIENT.CLIENT_NO, CLIENT.BRANCH_CLIENT, CLIENT.CUT_OFF_DATE) -- inner join über den Kunden um alle Konten zu kriegen
        where LEFT(BW_STAMMDATEN.FACILITY_ID,14) <> '0009-N001-DAR-' -- Gruppenkorrekturen ausschließen (#327)
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
from BW_STAMMDATEN_REMAINING_KR_CLIENTS
;
------------------------------------------------------------------------------------------------------------------------

-- CI START FOR ALL TAPES

-- CURRENT TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_PORTFOLIO_BW_CURRENT');
create table AMC.TABLE_PORTFOLIO_BW_CURRENT like CALC.VIEW_PORTFOLIO_BW distribute by hash(FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_PORTFOLIO_BW_CURRENT_BRANCH_CLIENT on AMC.TABLE_PORTFOLIO_BW_CURRENT (BRANCH_CLIENT);
create index AMC.INDEX_PORTFOLIO_BW_CURRENT_CLIENT_NO     on AMC.TABLE_PORTFOLIO_BW_CURRENT (CLIENT_NO);
create index AMC.INDEX_PORTFOLIO_BW_CURRENT_FACILITY_ID   on AMC.TABLE_PORTFOLIO_BW_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_PORTFOLIO_BW_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_PORTFOLIO_BW_CURRENT');
------------------------------------------------------------------------------------------------------------------------

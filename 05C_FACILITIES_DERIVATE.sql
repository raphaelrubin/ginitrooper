/* VIEW_PORTFOLIO_DERIVATE
 * Sammelt alle Konten für die DESIRED CLIENTS aus den DERIVATE Quelltabellen
 * - NLB.SPOT_DERIVATE_CURRENT
 * - NLB.DERIVATE_TEMP_CURRENT
 * - NLB.DERIVATE_MUREX_CURRENT
 */

-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_PORTFOLIO_DERIVATE;
create or replace view CALC.VIEW_PORTFOLIO_DERIVATE as
with
    CURRENT_CUTOFFDATE as (
        select CUT_OFF_DATE from CALC.AUTO_TABLE_CUTOFFDATES where IS_ACTIVE
    ),
    ALL_CLIENTS as (
        select * from CALC.SWITCH_PORTFOLIO_DESIRED_CLIENTS_CURRENT
    ),
    -- Alle Derivate
    DERIVATE_PRE as (
        select distinct
            CUT_OFF_DATE,
            FACILITY_ID,
            TRADE_ID,
            BORROWERID as CLIENT_NO,
            'NLB' as BRANCH
        from NLB.SPOT_DERIVATE_CURRENT
        where LOANSTATE='AKTIV'
        union
        select distinct
            CUT_OFF_DATE,
            FACILITY_ID,
            TRADE_ID,
            KUNDENNUMMER as CLIENT_NO,
            'NLB' as BRANCH
        from NLB.DERIVATE_TEMP_CURRENT
        union
         select distinct
            MUR.CUT_OFF_DATE,
            MAP.FACILITY_ID,
            TRADE_ID,
            MUR.KUNDENNUMMER as CLIENT_NO,
            'NLB' as BRANCH
         from NLB.DERIVATE_MUREX_CURRENT as MUR
         left join NLB.DERIVATE_FACILITY_ID_MUREX_ID_MAPPING_CURRENT as MAP on MAP.MUREX_ID=MUR.TRADE_ID and MAP.CUT_OFF_DATE=MUR.CUT_OFF_DATE
         where MAP.FACILITY_ID is not NULL
    ),
    DERIVATE_AUS_FLAGGING as (
        select distinct
            DERIVATE.CUT_OFF_DATE           as CUT_OFF_DATE,
            'NLB'                           as BRANCH_SYSTEM,
            'NLB'                           as BRANCH_CLIENT,
            DERIVATE.CLIENT_NO              as CLIENT_NO,
            coalesce(CLIENT.CLIENT_ID,'NLB_'||DERIVATE.CLIENT_NO)              as CLIENT_ID,
            coalesce(nullif(CLIENT.CLIENT_IDS_NLB,CLIENT.CLIENT_ID),'NLB_'||DERIVATE.CLIENT_NO,CLIENT.CLIENT_IDS_NLB)           as CLIENT_IDS_NLB,
            CLIENT.CLIENT_IDS_BLB           as CLIENT_IDS_BLB,
            CLIENT.CLIENT_IDS_CBB           as CLIENT_IDS_CBB,
            CLIENT.BORROWER_NO              as BORROWER_NO,
            DERIVATE.BRANCH                 as BRANCH_FACILITY,
            DERIVATE.FACILITY_ID            as FACILITY_ID,
            coalesce(HUS.WAEHRUNG, SPOT.ORIGINALCURRENCY, MUREX.P_AND_L_CURRENCY) as ORIGINAL_CURRENCY
        from DERIVATE_PRE                    as DERIVATE
        inner join CURRENT_CUTOFFDATE                       on CURRENT_CUTOFFDATE.CUT_OFF_DATE = DERIVATE.CUT_OFF_DATE
        inner join ALL_CLIENTS               as CLIENT      on (DERIVATE.CLIENT_NO, 'NLB', DERIVATE.CUT_OFF_DATE) = (CLIENT.CLIENT_NO, CLIENT.BRANCH_CLIENT, CLIENT.CUT_OFF_DATE) -- left join sichert, dass alle derivate eingesammelt werden. Sollte nicht mehr notwendig sein. ToDo: TBC!
        left join NLB.DERIVATE_TEMP_CURRENT  as HUS         on HUS.CUT_OFF_DATE = DERIVATE.CUT_OFF_DATE     and HUS.FACILITY_ID = DERIVATE.FACILITY_ID
        left join NLB.SPOT_DERIVATE_CURRENT  as SPOT        on SPOT.CUT_OFF_DATE = DERIVATE.CUT_OFF_DATE    and SPOT.FACILITY_ID = DERIVATE.FACILITY_ID
        left join NLB.DERIVATE_MUREX_CURRENT as MUREX       on MUREX.CUT_OFF_DATE = DERIVATE.CUT_OFF_DATE   and MUREX.TRADE_ID = DERIVATE.TRADE_ID
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
from DERIVATE_AUS_FLAGGING
;
------------------------------------------------------------------------------------------------------------------------

-- CI START FOR ALL TAPES

-- CURRENT TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_PORTFOLIO_DERIVATE_CURRENT');
create table AMC.TABLE_PORTFOLIO_DERIVATE_CURRENT like CALC.VIEW_PORTFOLIO_DERIVATE distribute by hash(FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_PORTFOLIO_DERIVATE_CURRENT_BRANCH_CLIENT on AMC.TABLE_PORTFOLIO_DERIVATE_CURRENT (BRANCH_CLIENT);
create index AMC.INDEX_PORTFOLIO_DERIVATE_CURRENT_CLIENT_NO     on AMC.TABLE_PORTFOLIO_DERIVATE_CURRENT (CLIENT_NO);
create index AMC.INDEX_PORTFOLIO_DERIVATE_CURRENT_FACILITY_ID   on AMC.TABLE_PORTFOLIO_DERIVATE_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_PORTFOLIO_DERIVATE_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_PORTFOLIO_DERIVATE_CURRENT');
------------------------------------------------------------------------------------------------------------------------
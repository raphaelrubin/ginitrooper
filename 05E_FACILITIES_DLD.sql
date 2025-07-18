/* VIEW_PORTFOLIO_DLD
 * Sammelt alle Konten für die DESIRED CLIENTS aus den DLD Rahmen Quelltabellen
 */

-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_PORTFOLIO_DLD;
create or replace view CALC.VIEW_PORTFOLIO_DLD as
with
    ALL_CLIENTS as (
        select * from CALC.SWITCH_PORTFOLIO_DESIRED_CLIENTS_CURRENT
    ),
    -- Alle Rahmen Netting Verträge
    LEDIS_RAHMEN_NLB as (
        select distinct
            DLD_IFRS.CUT_OFF_DATE           as CUT_OFF_DATE,
            'NLB'                           as BRANCH_SYSTEM,
            CLIENT.BRANCH_CLIENT            as BRANCH_CLIENT,
            CLIENT.CLIENT_NO                as CLIENT_NO,
            CLIENT.CLIENT_ID                as CLIENT_ID,
            CLIENT.CLIENT_IDS_NLB           as CLIENT_IDS_NLB,
            CLIENT.CLIENT_IDS_BLB           as CLIENT_IDS_BLB,
            CLIENT.CLIENT_IDS_CBB           as CLIENT_IDS_CBB,
            CLIENT.BORROWER_NO              as BORROWER_NO,
            DLD_IFRS.BRANCH                 as BRANCH_FACILITY,
            DLD_IFRS.BA1_C11EXTCON          as FACILITY_ID,
--             CLIENT.PORTFOLIO_EY_CLIENT_ROOT as PORTFOLIO_ROOT,
--             NULL                            as PRINCIPAL_OUTSTANDING_EUR,
            DLD_IFRS.BIC_XS_CONTCU          as ORIGINAL_CURRENCY
--             NULL                            as ORIGINATION_DATE,
--             NULL                            as MATURITY_IN_MONTHS,
--             NULL                            as PRODUCT_TYPE
        from NLB.DLD_DR_IFRS_CURRENT as DLD_IFRS
        inner join ALL_CLIENTS as CLIENT on (DLD_IFRS.BIC_XS_IDNUM, 'NLB', DLD_IFRS.CUT_OFF_DATE) = (CLIENT.CLIENT_NO, CLIENT.BRANCH_CLIENT, CLIENT.CUT_OFF_DATE)
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
--     cast(PORTFOLIO_ROOT as VARCHAR(1024))   as PORTFOLIO_ROOT,
    cast(ORIGINAL_CURRENCY as CHAR(3))      as CURRENCY,
    Current USER                            as CREATED_USER,     -- Letzter Nutzer, der diese Tabelle gebaut hat.
    Current TIMESTAMP                       as CREATED_TIMESTAMP -- Neuester Zeitstempel, wann diese Tabelle zuletzt gebaut wurde.
from LEDIS_RAHMEN_NLB;
------------------------------------------------------------------------------------------------------------------------

-- CURRENT TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_PORTFOLIO_DLD_CURRENT');
create table AMC.TABLE_PORTFOLIO_DLD_CURRENT like CALC.VIEW_PORTFOLIO_DLD distribute by hash(FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_PORTFOLIO_DLD_CURRENT_BRANCH_CLIENT on AMC.TABLE_PORTFOLIO_DLD_CURRENT (BRANCH_CLIENT);
create index AMC.INDEX_PORTFOLIO_DLD_CURRENT_CLIENT_NO     on AMC.TABLE_PORTFOLIO_DLD_CURRENT (CLIENT_NO);
create index AMC.INDEX_PORTFOLIO_DLD_CURRENT_FACILITY_ID   on AMC.TABLE_PORTFOLIO_DLD_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_PORTFOLIO_DLD_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- SWITCH erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_PORTFOLIO_DLD_CURRENT');
------------------------------------------------------------------------------------------------------------------------

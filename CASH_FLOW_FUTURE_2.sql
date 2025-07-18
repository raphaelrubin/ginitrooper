-- gesammte zukünftige Umsätze

-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_CASH_FLOW_FUTURE;
create or replace view CALC.VIEW_CASH_FLOW_FUTURE as
with
    AOER_CASH_FLOW as (
        select
            CUT_OFF_DATE, FACILITY_ID, CASH_FLOW_TYPE, VALUTA_DATE, PAYMENT_DATE, CASH_FLOW_VALUE_CURRENCY, CASH_FLOW_VALUE_CURRENCY_ISO,
            Current USER        as CREATED_USER,     -- Letzter Nutzer, der dieses Tape gebaut hat.
            Current TIMESTAMP   as CREATED_TIMESTAMP -- Neuester Zeitstempel, wann dieses Tape zuletzt gebaut wurde.
        from CALC.SWITCH_CASH_FLOW_FUTURE_AOER_CURRENT
    ),
    CBB_CASH_FLOW as (
        select distinct
            CUT_OFF_DATE, FACILITY_ID, CASH_FLOW_TYPE, VALUTA_DATE, PAYMENT_DATE, CASH_FLOW_VALUE_CURRENCY, CASH_FLOW_VALUE_CURRENCY_ISO,
            Current USER        as CREATED_USER,     -- Letzter Nutzer, der dieses Tape gebaut hat.
            Current TIMESTAMP   as CREATED_TIMESTAMP -- Neuester Zeitstempel, wann dieses Tape zuletzt gebaut wurde.
        from CALC.VIEW_CASH_FLOW_FUTURE_CBB
    )

select * from AOER_CASH_FLOW

union all

select * from CBB_CASH_FLOW
;
------------------------------------------------------------------------------------------------------------------------

-- CI START FOR ALL TAPES

-- CURRENT TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_CASH_FLOW_FUTURE_CURRENT');
create table AMC.TABLE_CASH_FLOW_FUTURE_CURRENT like CALC.VIEW_CASH_FLOW_FUTURE distribute by hash(FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CASH_FLOW_FUTURE_CURRENT_FACILITY_ID on AMC.TABLE_CASH_FLOW_FUTURE_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_CASH_FLOW_FUTURE_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- ARCHIVE TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_CASH_FLOW_FUTURE_ARCHIVE');
create table AMC.TABLE_CASH_FLOW_FUTURE_ARCHIVE like CALC.VIEW_CASH_FLOW_FUTURE distribute by hash(FACILITY_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2025' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CASH_FLOW_FUTURE_ARCHIVE_FACILITY_ID on AMC.TABLE_CASH_FLOW_FUTURE_ARCHIVE (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_CASH_FLOW_FUTURE_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCHES erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_CASH_FLOW_FUTURE_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_CASH_FLOW_FUTURE_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

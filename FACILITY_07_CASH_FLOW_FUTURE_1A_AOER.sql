-- Zukünftige Umsätze der AOER (NLB, BLB, ANL)
-- View erstellen
drop view CALC.VIEW_CASH_FLOW_FUTURE_AOER;
create or replace view CALC.VIEW_CASH_FLOW_FUTURE_AOER as
with
    PORTFOLIO as (
        select distinct FACILITY_ID, FACILITY_ID_LEADING, CUT_OFF_DATE from CALC.SWITCH_PORTFOLIO_CURRENT
    ),
    DARLEHEN_CASH_FLOW_AOER_PRE as (
        select
            case when SUBSTR(FACILITYID,6,2) = '30' and SUBSTR(FACILITYID,22,2) = '30' then
                LEFT(FACILITYID,20)||'-31-'||RIGHT(FACILITYID,10)
            else
                FACILITYID
            end as FACILITYID,
            ZAHLUNGSSTROM_TYP, VALUTA_DATUM, ZAHLUNG_DATUM, ZAHLUNGSSTROM_BTR, ZAHLUNGSSTROM_WHRG, CUTOFFDATE, TIMESTAMP_LOAD, QUELLE, BRANCH
        from NLB.DARLEHEN_CASH_FLOW_CURRENT
        union all
        select
            case when SUBSTR(FACILITYID,6,2) = '30' and SUBSTR(FACILITYID,22,2) = '30' then
                LEFT(FACILITYID,20)||'-31-'||RIGHT(FACILITYID,10)
            else
                FACILITYID
            end as FACILITYID,
            ZAHLUNGSSTROM_TYP, VALUTA_DATUM, ZAHLUNG_DATUM, ZAHLUNGSSTROM_BTR, ZAHLUNGSSTROM_WHRG, CUTOFFDATE, TIMESTAMP_LOAD, QUELLE, BRANCH
        from BLB.DARLEHEN_CASH_FLOW_CURRENT
        union all
        select
            FACILITYID,
            ZAHLUNGSSTROM_TYP, VALUTA_DATUM, ZAHLUNG_DATUM, ZAHLUNGSSTROM_BTR, ZAHLUNGSSTROM_WHRG, CUTOFFDATE, TIMESTAMP_LOAD, QUELLE, BRANCH
        from ANL.DARLEHEN_CASH_FLOW_CURRENT
    ),
    DARLEHEN_CASH_FLOW_AOER as (
        select
            CUTOFFDATE                                      as CUT_OFF_DATE,
            CASH_FLOW_AOER.facilityID                       as FACILITY_ID,
            CASH_FLOW_AOER.ZAHLUNGSSTROM_TYP                as CASH_FLOW_TYPE,
            CAST(CASH_FLOW_AOER.VALUTA_DATUM as DATE)       as VALUTA_DATE,
            CAST(CASH_FLOW_AOER.ZAHLUNG_DATUM as DATE)      as PAYMENT_DATE,
            CASH_FLOW_AOER.ZAHLUNGSSTROM_BTR                as CASH_FLOW_VALUE_CURRENCY,
            CASH_FLOW_AOER.ZAHLUNGSSTROM_WHRG               as CASH_FLOW_VALUE_CURRENCY_ISO,
            ZAHLUNG_DATUM                                   as ZAHLUNG_DATUM,
            Current USER                                    as CREATED_USER,     -- Letzter Nutzer, der dieses Tape gebaut hat.
            Current TIMESTAMP                               as CREATED_TIMESTAMP -- Neuester Zeitstempel, wann dieses Tape zuletzt gebaut wurde.
        from DARLEHEN_CASH_FLOW_AOER_PRE as CASH_FLOW_AOER
         inner join PORTFOLIO as PORTFOLIO
                    on (CASH_FLOW_AOER.facilityid = PORTFOLIO.FACILITY_ID or CASH_FLOW_AOER.facilityid = PORTFOLIO.FACILITY_ID_LEADING) and PORTFOLIO.CUT_OFF_DATE = CASH_FLOW_AOER.CUTOFFDATE
        where CAST(CASH_FLOW_AOER.VALUTA_DATUM  as DATE) > CASH_FLOW_AOER.CUTOFFDATE
           or CAST(CASH_FLOW_AOER.ZAHLUNG_DATUM as DATE) > CASH_FLOW_AOER.CUTOFFDATE
          and ZAHLUNGSSTROM_TYP in ('TILGUNGSRATE', 'ZINSZAHLUNG', 'SONDERTILGUNG', 'VORNOT_AUSZAHLUNG')
    )
select * from DARLEHEN_CASH_FLOW_AOER
;

-- CI START FOR ALL TAPES
-- Current-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_CASH_FLOW_FUTURE_AOER_CURRENT');
create table AMC.TABLE_CASH_FLOW_FUTURE_AOER_CURRENT like CALC.VIEW_CASH_FLOW_FUTURE_AOER distribute by hash(FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CASH_FLOW_FUTURE_AOER_CURRENT_FACILITY_ID on AMC.TABLE_CASH_FLOW_FUTURE_AOER_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_CASH_FLOW_FUTURE_AOER_CURRENT');
-- Archiv-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_CASH_FLOW_FUTURE_AOER_ARCHIVE');
create table AMC.TABLE_CASH_FLOW_FUTURE_AOER_ARCHIVE like CALC.VIEW_CASH_FLOW_FUTURE_AOER distribute by hash(FACILITY_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CASH_FLOW_FUTURE_AOER_ARCHIVE_FACILITY_ID on AMC.TABLE_CASH_FLOW_FUTURE_AOER_ARCHIVE (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_CASH_FLOW_FUTURE_AOER_ARCHIVE');
-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_CASH_FLOW_FUTURE_AOER_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_CASH_FLOW_FUTURE_AOER_ARCHIVE');
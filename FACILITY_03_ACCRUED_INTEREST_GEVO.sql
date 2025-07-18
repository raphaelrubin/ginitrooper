-- View erstellen
drop view CALC.VIEW_ACCRUED_INTEREST_GEVO;
create or replace view CALC.VIEW_ACCRUED_INTEREST_GEVO as
with PORTFOLIO as (
  select * from CALC.SWITCH_PORTFOLIO_CURRENT
)
,BASIS_NLB_BLB as (
    select SAP_ID, BUCHUNG_DATUM, VALUTA_DATUM, TRANSAKTION_WERT_WHRG, NOMINAL_WERT_WHRG, UMSATZ_ART_GEVO_1, UMSATZ_ART_GEVO_2, BUCHUNG_ID, CUTOFFDATE
    from NLB.SPOT_UMSATZ_CURRENT
    union
    select SAP_ID, BUCHUNG_DATUM, VALUTA_DATUM, TRANSAKTION_WERT_WHRG, NOMINAL_WERT_WHRG, UMSATZ_ART_GEVO_1, UMSATZ_ART_GEVO_2, BUCHUNG_ID, CUTOFFDATE
    from NLB.SPOT_UMSATZ
    union
    select SAP_ID, BUCHUNG_DATUM, VALUTA_DATUM, TRANSAKTION_WERT_WHRG, NOMINAL_WERT_WHRG, UMSATZ_ART_GEVO_1, UMSATZ_ART_GEVO_2, BUCHUNG_ID, CUTOFFDATE
    from BLB.SPOT_UMSATZ_CURRENT
    union
    select SAP_ID, BUCHUNG_DATUM, VALUTA_DATUM, TRANSAKTION_WERT_WHRG, NOMINAL_WERT_WHRG, UMSATZ_ART_GEVO_1, UMSATZ_ART_GEVO_2, BUCHUNG_ID, CUTOFFDATE
    from BLB.SPOT_UMSATZ
)
,BASIS_ANL as (
    select SAP_ID, BUCHUNG_DATUM, VALUTA_DATUM, TRANSAKTION_WERT_WHRG, NOMINAL_WERT_WHRG, UMSATZ_ART_GEVO_1, UMSATZ_ART_GEVO_2, BUCHUNG_ID, CUTOFFDATE
    from ANL.SPOT_UMSATZ_CURRENT
    union
    select SAP_ID, BUCHUNG_DATUM, VALUTA_DATUM, TRANSAKTION_WERT_WHRG, NOMINAL_WERT_WHRG, UMSATZ_ART_GEVO_1, UMSATZ_ART_GEVO_2, BUCHUNG_ID, CUTOFFDATE
    from ANL.SPOT_UMSATZ
)
,GEVO_FIN_LIQ as (select sum(NOMINAL_WERT_WHRG) as ACCRUEDINTEREST_GEVO,
                     PORTFOLIO.FACILITY_ID,
                    PORTFOLIO.CUT_OFF_DATE
              from PORTFOLIO as PORTFOLIO
                       left join BASIS_NLB_BLB as B on left(B.SAP_ID, 20) || right(B.SAP_ID, 10) =
                                               left(PORTFOLIO.FACILITY_ID, 20) || right(PORTFOLIO.FACILITY_ID, 10) and PORTFOLIO.CUT_OFF_DATE >= b.CUTOFFDATE
            where (UMSATZ_ART_GEVO_1 in ('DARL_ABG_ZINS_A', 'GP_DARL_ABG_ZINS_A','DARL_ABG_ZINS_ZAHLUNG_A', 'GP_DARL_ABG_ZINS_ZAHLUNG_A')
                or UMSATZ_ART_GEVO_2 in ('AGR_ZS_ERTR'))
                and substr(FACILITY_ID,6,2)='33'
                and b.CUTOFFDATE>'30.09.2019'
            group by PORTFOLIO.FACILITY_ID, PORTFOLIO.CUT_OFF_DATE
)
,GEVO_FIN_ANL_HELP as (
            select DISTINCT
                    first_value(VALUTA_DATUM) over (partition by SAP_ID order by VALUTA_DATUM DESC) as REL_DATE,
                    BASIS.SAP_ID,
                    PORTFOLIO.CUT_OFF_DATE
            from BASIS_ANL as BASIS
            left join PORTFOLIO as PORTFOLIO on PORTFOLIO.FACILITY_ID= BASIS.SAP_ID
            where UMSATZ_ART_GEVO_2 in ('DARL_AUFL_ABGRZINS_A_W')
            and PORTFOLIO.CUT_OFF_DATE >= BASIS.CUTOFFDATE
)
,GEVO_FIN_ANL as (
            select DISTINCT
                    first_value(NOMINAL_WERT_WHRG) over (partition by FACILITY_ID order by VALUTA_DATUM desc) as ACCRUEDINTEREST_GEVO,
                    PORTFOLIO.FACILITY_ID,
                    PORTFOLIO.CUT_OFF_DATE
            from PORTFOLIO as PORTFOLIO
                left join BASIS_ANL as BASIS on left(BASIS.SAP_ID, 20) || right(BASIS.SAP_ID, 10) = left(PORTFOLIO.FACILITY_ID, 20) || right(PORTFOLIO.FACILITY_ID, 10) and PORTFOLIO.CUT_OFF_DATE >= BASIS.CUTOFFDATE
                left join GEVO_FIN_ANL_HELP as ANL_H on ANL_H.sap_id = BASIS.sap_id AND ANL_H.CUT_OFF_DATE = BASIS.CUTOFFDATE
            where 1=1
                AND UMSATZ_ART_GEVO_1 in ('LEND_ABGRZINS_AIPD_A')
                and VALUTA_DATUM >= COALESCE(REL_DATE,'01.01.0001')
)
,GEVO_FIN_FWV_HELP as (
            select DISTINCT
                    first_value(VALUTA_DATUM) over (partition by SAP_ID order by VALUTA_DATUM DESC) as REL_DATE,
                    BASIS.SAP_ID,
                    PORTFOLIO.CUT_OFF_DATE
            from BASIS_NLB_BLB as BASIS
            left join PORTFOLIO as PORTFOLIO on PORTFOLIO.FACILITY_ID= BASIS.SAP_ID
            where UMSATZ_ART_GEVO_2 in ('ZINSERTRAG')
            and substr(SAP_ID,6,2)='49'
            and PORTFOLIO.CUT_OFF_DATE >= BASIS.CUTOFFDATE
)
,GEVO_FIN_FWV as (
            select DISTINCT
                    first_value(NOMINAL_WERT_WHRG) over (partition by FACILITY_ID order by VALUTA_DATUM desc) as ACCRUEDINTEREST_GEVO,
                    PORTFOLIO.FACILITY_ID,
                    PORTFOLIO.CUT_OFF_DATE
            from PORTFOLIO as PORTFOLIO
                left join BASIS_NLB_BLB as BASIS on left(BASIS.SAP_ID, 20) || right(BASIS.SAP_ID, 10) = left(PORTFOLIO.FACILITY_ID, 20) || right(PORTFOLIO.FACILITY_ID, 10) and PORTFOLIO.CUT_OFF_DATE >= BASIS.CUTOFFDATE
                left join GEVO_FIN_FWV_HELP as FWV_H on FWV_H.sap_id = BASIS.sap_id AND FWV_H.CUT_OFF_DATE = BASIS.CUTOFFDATE
            where 1=1
                AND UMSATZ_ART_GEVO_2 in ('ABGRENZUNG_150_S','ABGRENZUNG_150_H_K','ABGRENZUNG_191_S','ABGRENZUNG_150_S_K')
                and VALUTA_DATUM >= COALESCE(REL_DATE,'01.01.0001')
                and substr(FACILITY_ID,6,2)='49'
)
,GEVO_FIN_OSP as (
            select DISTINCT
                    first_value(-NOMINAL_WERT_WHRG) over (partition by FACILITY_ID order by VALUTA_DATUM desc) as ACCRUEDINTEREST_GEVO,
                    PORTFOLIO.FACILITY_ID,
                    PORTFOLIO.CUT_OFF_DATE
            from PORTFOLIO as PORTFOLIO
                left join BASIS_NLB_BLB as BASIS on left(BASIS.SAP_ID, 20) || right(BASIS.SAP_ID, 10) = left(PORTFOLIO.FACILITY_ID, 20) || right(PORTFOLIO.FACILITY_ID, 10) and PORTFOLIO.CUT_OFF_DATE = BASIS.CUTOFFDATE
            where 1=1
                AND UMSATZ_ART_GEVO_2 in ('AGR_ZS_ERTR')
                and substr(FACILITY_ID,6,2)='13'
                and not substr(FACILITY_ID,11,1)='7'
)
,GEVO_FIN_OSP_AVAL as (
            select DISTINCT
                    first_value(-NOMINAL_WERT_WHRG) over (partition by FACILITY_ID order by VALUTA_DATUM desc) as ACCRUEDINTEREST_GEVO,
                    PORTFOLIO.FACILITY_ID,
                    PORTFOLIO.CUT_OFF_DATE
            from PORTFOLIO as PORTFOLIO
                left join BASIS_NLB_BLB as B on left(B.SAP_ID, 20) || right(B.SAP_ID, 10) = left(PORTFOLIO.FACILITY_ID, 20) || right(PORTFOLIO.FACILITY_ID, 10) and PORTFOLIO.CUT_OFF_DATE >= B.CUTOFFDATE
            where 1=1
                AND UMSATZ_ART_GEVO_2 in ('AGR_GEB_ERTR')
                and substr(FACILITY_ID,6,2)='13'
                and substr(FACILITY_ID,11,1)='7'
)
,RESULT AS (
    select
        CASE
            WHEN substr(PORTFOLIO.FACILITY_ID,6,2) IN ('33') THEN (coalesce(AIF.ACCRUED_INTEREST_TC, 0)- COalesce(LOANIQ.ACCRUEDINTEREST_GEVO, 0))
            else COALESCE(ANL.ACCRUEDINTEREST_GEVO,0) + COALESCE(fwv.ACCRUEDINTEREST_GEVO,0) + COALESCE(OSPLUS.ACCRUEDINTEREST_GEVO,0) + COALESCE(OSPLUS_AVAL.ACCRUEDINTEREST_GEVO,0)
        end as ACCRUEDINTEREST_GEVO
        , PORTFOLIO.FACILITY_ID
        , PORTFOLIO.CUT_OFF_DATE
         --BUCHUNG_DATUM, VALUTA_DATUM, TRANSAKTION_WERT_WHRG, NOMINAL_WERT_WHRG, UMSATZ_ART_GEVO_1, BUCHUNG_ID
    from PORTFOLIO as PORTFOLIO
        left join GEVO_FIN_LIQ as LOANIQ on LOANIQ.FACILITY_ID = PORTFOLIO.FACILITY_ID and PORTFOLIO.CUT_OFF_DATE = LOANIQ.CUT_OFF_DATE
        Left join GEVO_FIN_ANL as ANL on ANL.FACILITY_ID=PORTFOLIO.FACILITY_ID and PORTFOLIO.CUT_OFF_DATE = ANL.CUT_OFF_DATE
        Left join GEVO_FIN_FWV as fwv on fwv.FACILITY_ID=PORTFOLIO.FACILITY_ID and PORTFOLIO.CUT_OFF_DATE = fwv.CUT_OFF_DATE
        Left join GEVO_FIN_OSP as OSPLUS on OSPLUS.FACILITY_ID=PORTFOLIO.FACILITY_ID and PORTFOLIO.CUT_OFF_DATE = OSPLUS.CUT_OFF_DATE
        Left join GEVO_FIN_OSP_AVAL as OSPLUS_AVAL on OSPLUS_AVAL.FACILITY_ID=PORTFOLIO.FACILITY_ID and PORTFOLIO.CUT_OFF_DATE = OSPLUS_AVAL.CUT_OFF_DATE
        left join SMAP.MQT_2018_ACCRUED_INTEREST_FULL as AIF on AIF.FACILITYID = PORTFOLIO.FACILITY_ID
)
SELECT distinct * FROM RESULT
;

-- CI START FOR ALL TAPES
-- Current-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_ACCRUED_INTEREST_GEVO_CURRENT');
create table AMC.TABLE_ACCRUED_INTEREST_GEVO_CURRENT like CALC.VIEW_ACCRUED_INTEREST_GEVO distribute by hash(FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_ACCRUED_INTEREST_GEVO_CURRENT on AMC.TABLE_ACCRUED_INTEREST_GEVO_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_ACCRUED_INTEREST_GEVO_CURRENT');
-- Archiv-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_ACCRUED_INTEREST_GEVO_ARCHIVE');
create table AMC.TABLE_ACCRUED_INTEREST_GEVO_ARCHIVE like AMC.TABLE_ACCRUED_INTEREST_GEVO_CURRENT distribute by hash(FACILITY_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_ACCRUED_INTEREST_GEVO_ARCHIVE on AMC.TABLE_ACCRUED_INTEREST_GEVO_ARCHIVE (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_ACCRUED_INTEREST_GEVO_ARCHIVE');
-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_ACCRUED_INTEREST_GEVO_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_ACCRUED_INTEREST_GEVO_ARCHIVE');
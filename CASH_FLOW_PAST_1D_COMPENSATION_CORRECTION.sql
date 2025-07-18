-- Kompensationskonten Korrektur

-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_CASH_FLOW_PAST_COMPENSATION_CORRECTION;
create or replace view CALC.VIEW_CASH_FLOW_PAST_COMPENSATION_CORRECTION(CUT_OFF_DATE, FACILITY_ID,CASH_FLOW_TYPE,TRANSACTION_VALUE_TRADECURRENCY,TRANSACTION_TRADECURRENCY_ISO,VALUTA_DATE,PAYMENT_DATE,ERFOLGSART,SOURCE_SYSTEM,PAST_DUE_ALIAS,TRANSACTION_ID,CANCELLATION_TRANSACTION_ID,IS_BAD_DEBT_LOSS,COMMENT,CREATED_USER,CREATED_TIMESTAMP) as
    select distinct
        PORTFOLIO.CUT_OFF_DATE      as CUT_OFF_DATE,
        ZM_PRODID                   as FACILITY_ID,
        'KORREKTUR KOMPENSATION'    as CASH_FLOW_TYPE,
        case when CUTOFFDATE = PORTFOLIO.CUT_OFF_DATE then -1 else 1 end * CS_TRN_TC
                                    as TRANSACTION_VALUE_TRADECURRENCY,
        ZM_AOCURR                   as TRANSACTION_TRADECURRENCY_ISO,
        CUTOFFDATE                  as VALUTA_DATE,
        CUTOFFDATE                  as PAYMENT_DATE,
        NULL                        as ERFOLGSART, -- SPÄTER ÜBER MAPPING
        'Blossom'                   as SOURCE_SYSTEM,
        NULL                        as PAST_DUE_ALIAS,
        'SWilbert_KORR_BW_KOMP_'|| dbms_utility.get_hash_value(ZM_PRODID || CUTOFFDATE,10000000,99999999)
                                    as TRANSACTION_ID,
        NULL                        as CANCELLATION_TRANSACTION_ID,
        cast(NULL as BOOLEAN)       as IS_BAD_DEBT_LOSS, -- Handelt es sich um eine Abschreibung?  (siehe Blossom #541)
        'Kompensations Korrektur'   as COMMENT,
        Current USER                as CREATED_USER,          -- Letzter Nutzer, der dieses View gebaut hat.
        Current TIMESTAMP           as CREATED_TIMESTAMP      -- Neuester Zeitstempel, wann diese View zuletzt gebaut wurde.
    from BLB.BW_ZBC_IFRS                    as IFRS -- Bewusst das Archiv um die Kombination in der where Bedingung sinnvoll zu machen.
    inner join CALC.SWITCH_PORTFOLIO_CURRENT  as PORTFOLIO on PORTFOLIO.FACILITY_ID = IFRS.ZM_PRODID
    where left(FACILITY_ID,7)='0004-13'
      and ZM_KFSEM = 'A_BWKOMP'
      and (PORTFOLIO.CUT_OFF_DATE=IFRS.CUTOFFDATE or last_day(PORTFOLIO.CUT_OFF_DATE - Dayofyear(PORTFOLIO.CUT_OFF_DATE) Day) = IFRS.CUTOFFDATE )
;
------------------------------------------------------------------------------------------------------------------------

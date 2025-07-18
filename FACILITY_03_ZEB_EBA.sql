-- View erstellen
drop view CALC.VIEW_FACILITY_ZEB_EBA;
create or replace view CALC.VIEW_FACILITY_ZEB_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
---- Quelldaten
-- ZEB nach Schema
ZEB_NLB as (
    select CUTOFFDATE      as CUT_OFF_DATE,
           case
               when LENGTH(FACILITY_ID) < 20 then
                   FACILITY_SUB_ID
               when SUBSTR(FACILITY_ID, 6, 2) <> '30' then
                   FACILITY_ID
               else LEFT(FACILITY_ID, 20) || '-31-' || SUBSTR(FACILITY_ID, 25, LENGTH(FACILITY_ID) - 24)
               end         as FACILITY_ID,
           FACILITY_ID     as POSITION_ID,
           FACILITY_SUB_ID as POSITION_SUB_ID,
           R_ON_BALANCE_ID,
           R_CURRENCY_ID,
           R_LOAN_LOSS_PROVISION_AMT,
           R_LOAN_LOSS_PROVISION_PREV_AMT,
           R_STAGE_LLP_CALCULATED_ID,
           R_STAGE_LLP_REASON_DESC,
           R_CREDIT_CONVERSION_FACTOR_RATE,
           R_EAD_TOTAL_AMT,
           R_EXP_LIFETIME_LOSS_AMT,
           R_EXP_LOSS_AMT,
           R_LIFETIME_PROB_DEF_RATE,
           R_LOSS_GIVEN_DEFAULT_RATE,
           R_ONE_YEAR_PROB_OF_DEFAULT_RATE,
           E_DIRECT_WRITE_OFF_AMT,
           R_IFRS_EFF_INTEREST_RATE
    from NLB.ZEB_CONTROL_CURRENT
    where CUTOFFDATE = (select CUT_OFF_DATE from COD)
),
ZEB_ANL as (
    select CUTOFFDATE      as CUT_OFF_DATE,
           FACILITY_ID,
           FACILITY_ID     as POSITION_ID,
           FACILITY_SUB_ID as POSITION_SUB_ID,
           R_ON_BALANCE_ID,
           R_CURRENCY_ID,
           R_LOAN_LOSS_PROVISION_AMT,
           R_LOAN_LOSS_PROVISION_PREV_AMT,
           R_STAGE_LLP_CALCULATED_ID,
           R_STAGE_LLP_REASON_DESC,
           R_CREDIT_CONVERSION_FACTOR_RATE,
           R_EAD_TOTAL_AMT,
           R_EXP_LIFETIME_LOSS_AMT,
           R_EXP_LOSS_AMT,
           R_LIFETIME_PROB_DEF_RATE,
           R_LOSS_GIVEN_DEFAULT_RATE,
           R_ONE_YEAR_PROB_OF_DEFAULT_RATE,
           E_DIRECT_WRITE_OFF_AMT,
           R_IFRS_EFF_INTEREST_RATE
    from ANL.ZEB_CONTROL_CURRENT
    where CUTOFFDATE = (select CUT_OFF_DATE from COD)
),
ZEB_CBB as (
    select CUT_OFF_DATE,
           case
               -- CBB Facility ID zusammenbauen
               when UPPER(PRJ_POSITION_DESC1) = 'LOAN'
                   then 'K028-' || POSITION_ID || '_1020'
               when UPPER(PRJ_POSITION_DESC1) = 'LIMIT'
                   then 'K028-' || POSITION_ID || '_4200'
               end                       as FACILITY_ID,
           POSITION_ID,
           POSITION_SUB_ID,
           ON_BALANCE_ID                 as R_ON_BALANCE_ID,
           CURRENCY_ID                   as R_CURRENCY_ID,
           LOAN_LOSS_PROVISION_AMT       as R_LOAN_LOSS_PROVISION_AMT,
           LOAN_LOSS_PROVISION_PREV_AMT  as R_LOAN_LOSS_PROVISION_PREV_AMT,
           STAGE_LLP_CALCULATED_ID       as R_STAGE_LLP_CALCULATED_ID,
           STAGE_LLP_REASON_DESC         as R_STAGE_LLP_REASON_DESC,
           CREDIT_CONVERSION_FACTOR_RATE as R_CREDIT_CONVERSION_FACTOR_RATE,
           EAD_TOTAL_AMT                 as R_EAD_TOTAL_AMT,
           EXP_LIFETIME_LOSS_AMT         as R_EXP_LIFETIME_LOSS_AMT,
           EXP_LOSS_AMT                  as R_EXP_LOSS_AMT,
           LIFETIME_PROB_DEF_RATE        as R_LIFETIME_PROB_DEF_RATE,
           LOSS_GIVEN_DEFAULT_RATE       as R_LOSS_GIVEN_DEFAULT_RATE,
           ONE_YEAR_PROB_OF_DEFAULT_RATE as R_ONE_YEAR_PROB_OF_DEFAULT_RATE,
           WRITE_OFF_PROL_BV_LLP_AMT     as E_DIRECT_WRITE_OFF_AMT,
           IFRS_EFF_INTEREST_RATE        as R_IFRS_EFF_INTEREST_RATE
    from CBB.ZEB_POSITION_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
      and UPPER(PRJ_POSITION_DESC1) in ('LOAN', 'LIMIT')
),
-- Union
ZEB_UN as (
    select *
    from ZEB_NLB
    union all
    select *
    from ZEB_ANL
    union all
    select *
    from ZEB_CBB
),
-- Währungsumrechnung
ZEB_EUR as (
    select C.CUT_OFF_DATE,
           C.FACILITY_ID,
           C.POSITION_ID,
           C.POSITION_SUB_ID,
           C.R_ON_BALANCE_ID,
           case
               when C.R_CURRENCY_ID is not null
                   then 'EUR'
               end                                                  as CURRENCY,
           C.R_CURRENCY_ID                                          as CURRENCY_OC,
           C.R_LOAN_LOSS_PROVISION_AMT * CM.RATE_TARGET_TO_EUR      as R_LOAN_LOSS_PROVISION_AMT,
           C.R_LOAN_LOSS_PROVISION_PREV_AMT * CM.RATE_TARGET_TO_EUR as R_LOAN_LOSS_PROVISION_PREV_AMT,
           C.R_STAGE_LLP_CALCULATED_ID,
           C.R_STAGE_LLP_REASON_DESC,
           C.R_CREDIT_CONVERSION_FACTOR_RATE,
           C.R_EAD_TOTAL_AMT,
           C.R_EXP_LIFETIME_LOSS_AMT * CM.RATE_TARGET_TO_EUR        as R_EXP_LIFETIME_LOSS_AMT,
           C.R_EXP_LOSS_AMT * CM.RATE_TARGET_TO_EUR                 as R_EXP_LOSS_AMT,
           C.R_LIFETIME_PROB_DEF_RATE,
           C.R_LOSS_GIVEN_DEFAULT_RATE,
           C.R_ONE_YEAR_PROB_OF_DEFAULT_RATE,
           C.E_DIRECT_WRITE_OFF_AMT * CM.RATE_TARGET_TO_EUR         as E_DIRECT_WRITE_OFF_AMT,
           C.R_IFRS_EFF_INTEREST_RATE
    from ZEB_UN C
             left join IMAP.CURRENCY_MAP CM on (C.CUT_OFF_DATE, C.R_CURRENCY_ID) = (CM.CUT_OFF_DATE, CM.ZIEL_WHRG)
),
-- On Balance
ZEB_ON as (
    select CUT_OFF_DATE                    as CUT_OFF_DATE,
           FACILITY_ID                     as FACILITY_ID,
           POSITION_ID                     as POSITION_ID,
           POSITION_SUB_ID                 as POSITION_SUB_ID,
           CURRENCY                        as CURRENCY,
           CURRENCY_OC                     as CURRENCY_OC,
           R_LOAN_LOSS_PROVISION_AMT       as R_LOAN_LOSS_PROVISION_AMT_ONBALANCE,
           R_LOAN_LOSS_PROVISION_PREV_AMT  as R_LOAN_LOSS_PROVISION_PREV_AMT_ONBALANCE,
           R_STAGE_LLP_CALCULATED_ID       as R_STAGE_LLP_CALCULATED_ID_ONBALANCE,
           R_STAGE_LLP_REASON_DESC         as R_STAGE_LLP_REASON_DESC_ONBALANCE,
           R_CREDIT_CONVERSION_FACTOR_RATE as R_CREDIT_CONVERSION_FACTOR_RATE_ONBALANCE,
           R_EAD_TOTAL_AMT                 as R_EAD_TOTAL_AMT_ONBALANCE,
           R_EXP_LIFETIME_LOSS_AMT         as R_EXP_LIFETIME_LOSS_AMT_ONBALANCE,
           R_EXP_LOSS_AMT                  as R_EXP_LOSS_AMT_ONBALANCE,
           R_LIFETIME_PROB_DEF_RATE        as R_LIFETIME_PROB_DEF_RATE_ONBALANCE,
           R_LOSS_GIVEN_DEFAULT_RATE       as R_LOSS_GIVEN_DEFAULT_RATE_ONBALANCE,
           R_ONE_YEAR_PROB_OF_DEFAULT_RATE as R_ONE_YEAR_PROB_OF_DEFAULT_RATE_ONBALANCE,
           E_DIRECT_WRITE_OFF_AMT          as E_DIRECT_WRITE_OFF_AMT_ONBALANCE,
           R_IFRS_EFF_INTEREST_RATE        as R_IFRS_EFF_INTEREST_RATE_ONBALANCE
    from ZEB_EUR
    where UPPER(R_ON_BALANCE_ID) = 'ONBALANCE'
),
-- Off Balance
ZEB_OFF as (
    select CUT_OFF_DATE                    as CUT_OFF_DATE,
           case
               when RIGHT(FACILITY_ID, 3) in ('_KK', '_OL', '_AL')
                   -- Off Balance FACILITY_IDs hören oft mit '_KK', '_OL' oder '_AL' auf - aber nicht immer
                   -- Suffix Abschneiden
                   then LEFT(FACILITY_ID, LENGTH(FACILITY_ID) - 3)
               else FACILITY_ID
               end                         as FACILITY_ID,
           -- Unveränderte FACILITY_ID mitziehen für spätere Sonderfälle
           FACILITY_ID                     as FACILITY_ID_ORIG_OFFBALANCE,
           POSITION_ID                     as POSITION_ID,
           POSITION_SUB_ID                 as POSITION_SUB_ID,
           CURRENCY                        as CURRENCY,
           CURRENCY_OC                     as CURRENCY_OC,
           R_LOAN_LOSS_PROVISION_AMT       as R_LOAN_LOSS_PROVISION_AMT_OFFBALANCE,
           R_LOAN_LOSS_PROVISION_PREV_AMT  as R_LOAN_LOSS_PROVISION_PREV_AMT_OFFBALANCE,
           R_STAGE_LLP_CALCULATED_ID       as R_STAGE_LLP_CALCULATED_ID_OFFBALANCE,
           R_STAGE_LLP_REASON_DESC         as R_STAGE_LLP_REASON_DESC_OFFBALANCE,
           R_CREDIT_CONVERSION_FACTOR_RATE as R_CREDIT_CONVERSION_FACTOR_RATE_OFFBALANCE,
           R_EAD_TOTAL_AMT                 as R_EAD_TOTAL_AMT_OFFBALANCE,
           R_EXP_LIFETIME_LOSS_AMT         as R_EXP_LIFETIME_LOSS_AMT_OFFBALANCE,
           R_EXP_LOSS_AMT                  as R_EXP_LOSS_AMT_OFFBALANCE,
           R_LIFETIME_PROB_DEF_RATE        as R_LIFETIME_PROB_DEF_RATE_OFFBALANCE,
           R_LOSS_GIVEN_DEFAULT_RATE       as R_LOSS_GIVEN_DEFAULT_RATE_OFFBALANCE,
           R_ONE_YEAR_PROB_OF_DEFAULT_RATE as R_ONE_YEAR_PROB_OF_DEFAULT_RATE_OFFBALANCE,
           E_DIRECT_WRITE_OFF_AMT          as E_DIRECT_WRITE_OFF_AMT_OFFBALANCE,
           R_IFRS_EFF_INTEREST_RATE        as R_IFRS_EFF_INTEREST_RATE_OFFBALANCE
    from ZEB_EUR
    where UPPER(R_ON_BALANCE_ID) = 'OFFBALANCE'
),
-- On & Off in eine Zeile zusammenführen
ZEB_ON_OFF as (
    select NVL(ZON.CUT_OFF_DATE, ZOF.CUT_OFF_DATE)       as CUT_OFF_DATE,
           NVL(ZON.FACILITY_ID, ZOF.FACILITY_ID)         as FACILITY_ID,
           ZOF.FACILITY_ID_ORIG_OFFBALANCE,
           NVL(ZON.POSITION_ID, ZOF.POSITION_ID)         as POSITION_ID,
           NVL(ZON.POSITION_SUB_ID, ZOF.POSITION_SUB_ID) as POSITION_SUB_ID,
           NVL(ZON.CURRENCY, ZOF.CURRENCY)               as CURRENCY,
           NVL(ZON.CURRENCY_OC, ZOF.CURRENCY_OC)         as CURRENCY_OC,
           ZON.R_LOAN_LOSS_PROVISION_AMT_ONBALANCE,
           ZON.R_LOAN_LOSS_PROVISION_PREV_AMT_ONBALANCE,
           ZON.R_STAGE_LLP_CALCULATED_ID_ONBALANCE,
           ZON.R_STAGE_LLP_REASON_DESC_ONBALANCE,
           ZON.R_CREDIT_CONVERSION_FACTOR_RATE_ONBALANCE,
           ZON.R_EAD_TOTAL_AMT_ONBALANCE,
           ZON.R_EXP_LIFETIME_LOSS_AMT_ONBALANCE,
           ZON.R_EXP_LOSS_AMT_ONBALANCE,
           ZON.R_LIFETIME_PROB_DEF_RATE_ONBALANCE,
           ZON.R_LOSS_GIVEN_DEFAULT_RATE_ONBALANCE,
           ZON.R_ONE_YEAR_PROB_OF_DEFAULT_RATE_ONBALANCE,
           ZON.E_DIRECT_WRITE_OFF_AMT_ONBALANCE,
           ZON.R_IFRS_EFF_INTEREST_RATE_ONBALANCE,
           ZOF.R_LOAN_LOSS_PROVISION_AMT_OFFBALANCE,
           ZOF.R_LOAN_LOSS_PROVISION_PREV_AMT_OFFBALANCE,
           ZOF.R_STAGE_LLP_CALCULATED_ID_OFFBALANCE,
           ZOF.R_STAGE_LLP_REASON_DESC_OFFBALANCE,
           ZOF.R_CREDIT_CONVERSION_FACTOR_RATE_OFFBALANCE,
           ZOF.R_EAD_TOTAL_AMT_OFFBALANCE,
           ZOF.R_EXP_LIFETIME_LOSS_AMT_OFFBALANCE,
           ZOF.R_EXP_LOSS_AMT_OFFBALANCE,
           ZOF.R_LIFETIME_PROB_DEF_RATE_OFFBALANCE,
           ZOF.R_LOSS_GIVEN_DEFAULT_RATE_OFFBALANCE,
           ZOF.R_ONE_YEAR_PROB_OF_DEFAULT_RATE_OFFBALANCE,
           ZOF.E_DIRECT_WRITE_OFF_AMT_OFFBALANCE,
           ZOF.R_IFRS_EFF_INTEREST_RATE_OFFBALANCE
    from ZEB_ON ZON
             full outer join ZEB_OFF ZOF on ZON.FACILITY_ID = ZOF.FACILITY_ID
),
-- Sonderfälle bei offbalance behandeln
FINAL as (
    -- Doppelte Zeilen mit unterschiedlichen Werten, FACILITY_ID_ORIG_OFFBALANCE mal normal mal mit _AL-Suffix
    -- 3 Fälle:
    -- (negative) Summe nehmen
    -- Wert aus Zeile ohne Suffix nehmen (order by)
    -- Werte Komma-separiert auflisten
    select CUT_OFF_DATE,
           FACILITY_ID,
           CURRENCY,
           CURRENCY_OC,
           -SUM(R_LOAN_LOSS_PROVISION_AMT_ONBALANCE)                                                                                 as R_LOAN_LOSS_PROVISION_AMT_ONBALANCE,
           -SUM(R_LOAN_LOSS_PROVISION_PREV_AMT_ONBALANCE)                                                                            as R_LOAN_LOSS_PROVISION_PREV_AMT_ONBALANCE,
           LISTAGG(distinct R_STAGE_LLP_CALCULATED_ID_ONBALANCE, ', ') within group (order by R_STAGE_LLP_CALCULATED_ID_ONBALANCE)   as R_STAGE_LLP_CALCULATED_ID_ONBALANCE,
           LISTAGG(distinct R_STAGE_LLP_REASON_DESC_ONBALANCE, ', ') within group (order by R_STAGE_LLP_REASON_DESC_ONBALANCE)       as R_STAGE_LLP_REASON_DESC_ONBALANCE,
           R_CREDIT_CONVERSION_FACTOR_RATE_ONBALANCE,
           SUM(R_EAD_TOTAL_AMT_ONBALANCE)                                                                                            as R_EAD_TOTAL_AMT_ONBALANCE,
           -SUM(R_EXP_LIFETIME_LOSS_AMT_ONBALANCE)                                                                                   as R_EXP_LIFETIME_LOSS_AMT_ONBALANCE,
           -SUM(R_EXP_LOSS_AMT_ONBALANCE)                                                                                            as R_EXP_LOSS_AMT_ONBALANCE,
           R_LIFETIME_PROB_DEF_RATE_ONBALANCE,
           R_LOSS_GIVEN_DEFAULT_RATE_ONBALANCE,
           R_ONE_YEAR_PROB_OF_DEFAULT_RATE_ONBALANCE,
           SUM(E_DIRECT_WRITE_OFF_AMT_ONBALANCE)                                                                                     as E_DIRECT_WRITE_OFF_AMT_ONBALANCE,
           R_IFRS_EFF_INTEREST_RATE_ONBALANCE,
           -SUM(R_LOAN_LOSS_PROVISION_AMT_OFFBALANCE)                                                                                as R_LOAN_LOSS_PROVISION_AMT_OFFBALANCE,
           -SUM(R_LOAN_LOSS_PROVISION_PREV_AMT_OFFBALANCE)                                                                           as R_LOAN_LOSS_PROVISION_PREV_AMT_OFFBALANCE,
           LISTAGG(distinct R_STAGE_LLP_CALCULATED_ID_OFFBALANCE, ', ') within group (order by R_STAGE_LLP_CALCULATED_ID_OFFBALANCE) as R_STAGE_LLP_CALCULATED_ID_OFFBALANCE,
           LISTAGG(distinct R_STAGE_LLP_REASON_DESC_OFFBALANCE, ', ') within group (order by R_STAGE_LLP_REASON_DESC_OFFBALANCE)     as R_STAGE_LLP_REASON_DESC_OFFBALANCE,
           R_CREDIT_CONVERSION_FACTOR_RATE_OFFBALANCE,
           SUM(R_EAD_TOTAL_AMT_OFFBALANCE)                                                                                           as R_EAD_TOTAL_AMT_OFFBALANCE,
           -SUM(R_EXP_LIFETIME_LOSS_AMT_OFFBALANCE)                                                                                  as R_EXP_LIFETIME_LOSS_AMT_OFFBALANCE,
           -SUM(R_EXP_LOSS_AMT_OFFBALANCE)                                                                                           as R_EXP_LOSS_AMT_OFFBALANCE,
           R_LIFETIME_PROB_DEF_RATE_OFFBALANCE,
           R_LOSS_GIVEN_DEFAULT_RATE_OFFBALANCE,
           R_ONE_YEAR_PROB_OF_DEFAULT_RATE_OFFBALANCE,
           SUM(E_DIRECT_WRITE_OFF_AMT_OFFBALANCE)                                                                                    as E_DIRECT_WRITE_OFF_AMT_OFFBALANCE,
           R_IFRS_EFF_INTEREST_RATE_OFFBALANCE
    from (
             -- DB2 kann FIRST_VALUE nur mit partition by nicht group by, Fall "Wert aus Zeile ohne Suffix nehmen (order by)" vorberechnen
             select CUT_OFF_DATE,
                    FACILITY_ID,
                    FACILITY_ID_ORIG_OFFBALANCE,
                    CURRENCY,
                    CURRENCY_OC,
                    R_LOAN_LOSS_PROVISION_AMT_ONBALANCE,
                    R_LOAN_LOSS_PROVISION_PREV_AMT_ONBALANCE,
                    R_STAGE_LLP_CALCULATED_ID_ONBALANCE,
                    R_STAGE_LLP_REASON_DESC_ONBALANCE,
                    FIRST_VALUE(R_CREDIT_CONVERSION_FACTOR_RATE_ONBALANCE)
                                over (partition by FACILITY_ID order by FACILITY_ID_ORIG_OFFBALANCE) as R_CREDIT_CONVERSION_FACTOR_RATE_ONBALANCE,
                    R_EAD_TOTAL_AMT_ONBALANCE,
                    R_EXP_LIFETIME_LOSS_AMT_ONBALANCE,
                    R_EXP_LOSS_AMT_ONBALANCE,
                    FIRST_VALUE(R_LIFETIME_PROB_DEF_RATE_ONBALANCE)
                                over (partition by FACILITY_ID order by FACILITY_ID_ORIG_OFFBALANCE) as R_LIFETIME_PROB_DEF_RATE_ONBALANCE,
                    FIRST_VALUE(R_LOSS_GIVEN_DEFAULT_RATE_ONBALANCE)
                                over (partition by FACILITY_ID order by FACILITY_ID_ORIG_OFFBALANCE) as R_LOSS_GIVEN_DEFAULT_RATE_ONBALANCE,
                    FIRST_VALUE(R_ONE_YEAR_PROB_OF_DEFAULT_RATE_ONBALANCE)
                                over (partition by FACILITY_ID order by FACILITY_ID_ORIG_OFFBALANCE) as R_ONE_YEAR_PROB_OF_DEFAULT_RATE_ONBALANCE,
                    E_DIRECT_WRITE_OFF_AMT_ONBALANCE,
                    FIRST_VALUE(R_IFRS_EFF_INTEREST_RATE_ONBALANCE)
                                over (partition by FACILITY_ID order by FACILITY_ID_ORIG_OFFBALANCE) as R_IFRS_EFF_INTEREST_RATE_ONBALANCE,
                    R_LOAN_LOSS_PROVISION_AMT_OFFBALANCE,
                    R_LOAN_LOSS_PROVISION_PREV_AMT_OFFBALANCE,
                    R_STAGE_LLP_CALCULATED_ID_OFFBALANCE,
                    R_STAGE_LLP_REASON_DESC_OFFBALANCE,
                    FIRST_VALUE(R_CREDIT_CONVERSION_FACTOR_RATE_OFFBALANCE)
                                over (partition by FACILITY_ID order by FACILITY_ID_ORIG_OFFBALANCE) as R_CREDIT_CONVERSION_FACTOR_RATE_OFFBALANCE,
                    R_EAD_TOTAL_AMT_OFFBALANCE,
                    R_EXP_LIFETIME_LOSS_AMT_OFFBALANCE,
                    R_EXP_LOSS_AMT_OFFBALANCE,
                    FIRST_VALUE(R_LIFETIME_PROB_DEF_RATE_OFFBALANCE)
                                over (partition by FACILITY_ID order by FACILITY_ID_ORIG_OFFBALANCE) as R_LIFETIME_PROB_DEF_RATE_OFFBALANCE,
                    FIRST_VALUE(R_LOSS_GIVEN_DEFAULT_RATE_OFFBALANCE)
                                over (partition by FACILITY_ID order by FACILITY_ID_ORIG_OFFBALANCE) as R_LOSS_GIVEN_DEFAULT_RATE_OFFBALANCE,
                    FIRST_VALUE(R_ONE_YEAR_PROB_OF_DEFAULT_RATE_OFFBALANCE)
                                over (partition by FACILITY_ID order by FACILITY_ID_ORIG_OFFBALANCE) as R_ONE_YEAR_PROB_OF_DEFAULT_RATE_OFFBALANCE,
                    E_DIRECT_WRITE_OFF_AMT_OFFBALANCE,
                    FIRST_VALUE(R_IFRS_EFF_INTEREST_RATE_OFFBALANCE)
                                over (partition by FACILITY_ID order by FACILITY_ID_ORIG_OFFBALANCE) as R_IFRS_EFF_INTEREST_RATE_OFFBALANCE
             from ZEB_ON_OFF
         )
    group by CUT_OFF_DATE, FACILITY_ID, CURRENCY, CURRENCY_OC,
             -- Vorberechnete Spalten
             R_CREDIT_CONVERSION_FACTOR_RATE_ONBALANCE, R_LIFETIME_PROB_DEF_RATE_ONBALANCE, R_LOSS_GIVEN_DEFAULT_RATE_ONBALANCE, R_ONE_YEAR_PROB_OF_DEFAULT_RATE_ONBALANCE,
             R_IFRS_EFF_INTEREST_RATE_ONBALANCE, R_CREDIT_CONVERSION_FACTOR_RATE_OFFBALANCE, R_LIFETIME_PROB_DEF_RATE_OFFBALANCE, R_LOSS_GIVEN_DEFAULT_RATE_OFFBALANCE,
             R_ONE_YEAR_PROB_OF_DEFAULT_RATE_OFFBALANCE, R_IFRS_EFF_INTEREST_RATE_OFFBALANCE
),
-- Gefiltert nach noetigen Datenfeldern
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        FACILITY_ID,
        CURRENCY,
        CURRENCY_OC,
        R_LOAN_LOSS_PROVISION_AMT_ONBALANCE,
        R_LOAN_LOSS_PROVISION_PREV_AMT_ONBALANCE,
        R_STAGE_LLP_CALCULATED_ID_ONBALANCE,
        R_STAGE_LLP_REASON_DESC_ONBALANCE,
        R_CREDIT_CONVERSION_FACTOR_RATE_ONBALANCE,
        R_EAD_TOTAL_AMT_ONBALANCE,
        R_EXP_LIFETIME_LOSS_AMT_ONBALANCE,
        R_EXP_LOSS_AMT_ONBALANCE,
        R_LIFETIME_PROB_DEF_RATE_ONBALANCE,
        R_LOSS_GIVEN_DEFAULT_RATE_ONBALANCE,
        R_ONE_YEAR_PROB_OF_DEFAULT_RATE_ONBALANCE,
        E_DIRECT_WRITE_OFF_AMT_ONBALANCE,
        R_IFRS_EFF_INTEREST_RATE_ONBALANCE,
        R_LOAN_LOSS_PROVISION_AMT_OFFBALANCE,
        R_LOAN_LOSS_PROVISION_PREV_AMT_OFFBALANCE,
        R_STAGE_LLP_CALCULATED_ID_OFFBALANCE,
        R_STAGE_LLP_REASON_DESC_OFFBALANCE,
        R_CREDIT_CONVERSION_FACTOR_RATE_OFFBALANCE,
        R_EAD_TOTAL_AMT_OFFBALANCE,
        R_EXP_LIFETIME_LOSS_AMT_OFFBALANCE,
        R_EXP_LOSS_AMT_OFFBALANCE,
        R_LIFETIME_PROB_DEF_RATE_OFFBALANCE,
        R_LOSS_GIVEN_DEFAULT_RATE_OFFBALANCE,
        R_ONE_YEAR_PROB_OF_DEFAULT_RATE_OFFBALANCE,
        E_DIRECT_WRITE_OFF_AMT_OFFBALANCE,
        R_IFRS_EFF_INTEREST_RATE_OFFBALANCE,
        -- Defaults
        CURRENT_USER      as USER,
        CURRENT_TIMESTAMP as TIMESTAMP_LOAD
    from FINAL
)
select *
from FINAL_FILTERED;

-- CI START FOR ALL TAPES

-- Current-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_FACILITY_ZEB_EBA_CURRENT');
create table AMC.TABLE_FACILITY_ZEB_EBA_CURRENT like CALC.VIEW_FACILITY_ZEB_EBA distribute by hash (FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_ZEB_EBA_CURRENT_FACILITY_ID on AMC.TABLE_FACILITY_ZEB_EBA_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_FACILITY_ZEB_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_FACILITY_ZEB_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------


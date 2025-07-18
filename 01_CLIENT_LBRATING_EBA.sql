-- View erstellen
drop view CALC.VIEW_CLIENT_LBRATING_EBA;
create or replace view CALC.VIEW_CLIENT_LBRATING_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE from CALC.AUTO_TABLE_CUTOFFDATES where IS_ACTIVE
),
-- Quelldaten CRP
CRP as (
    select *, 'NLB_' || CUST_ID as GNI_KUNDE, 'CRP' as SOURCE
    from NLB.LBRATING_CRP_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- Quelldaten ICRE
ICRE as (
    select *, 'NLB_' || CUST_ID as GNI_KUNDE, 'ICRE' as SOURCE
    from NLB.LBRATING_ICRE_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- Quelldaten SIR
SIR as (
    select *, 'NLB_' || CUST_ID as GNI_KUNDE, 'SIR' as SOURCE
    from NLB.LBRATING_SIR_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- Union
FINAL as (
    select CUT_OFF_DATE,
           RAT_BUS_ID,
           GNI_KUNDE,
           SOURCE,
           PRESUM_STRAT_TXT,
           PRESUM_STRAT_STATE,
           NEG_DIV_TXT,
           NEG_DIV_STATE,
           COMP_EXPECT_TXT,
           EXPECT_STATE,
           BANK_EXPECT_TXT,
           INFLUENCE_TXT,
           INFLUENCE_STATE,
           SENSITIV_TXT,
           SENSITIV_STATE,
           INFO_TXT,
           INFO_STATE,
           DEPENDENCY_TXT,
           DEPENDENCY_STATE,
           CURRENCYRISK_TXT,
           CURRENCYRISK_STATE,
           ORIENTATION_TXT,
           ORIENTATION_STATE,
           null as IN_PROFESSIONALISM_TXT,
           null as DEBTOR_ASSETS_TXT,
           null as FINANCE_SITUATION_TXT,
           null as INVEST_ACTIVITY_TXT,
           null as LIQUID_SITUATION_TXT,
           null as SUPPORT_PROVIDED_TXT,
           null as DEBTOR_SUPPORT_TXT,
           null as CUST_QUAL_STATE,
           null as HQF_DAUKUNBEZ_695,
           null as WQF_ZUVERLAESSIGKEIT_2763_TXT,
           null as WQF_INFOBEREITSCH_2758_TXT,
           null as WQF_UNTERNEHMENTW_2748_TXT,
           null as WQF_MANAGEMENT_SIR_2743_TXT,
           null as HQF_VERKAUFSSTAND_2792_TXT,
           null as WQF_FINANZBEREICH_2778_TXT,
           null as WQF_VRTRBVRMRKTNG_2773_TXT,
           null as WQF_BAUQUALITAET_2768_TXT,
           null as WQF_LIQUIDITAET_5511_TXT
    from CRP
    union all
    select CUT_OFF_DATE,
           RAT_BUS_ID,
           GNI_KUNDE,
           SOURCE,
           null as PRESUM_STRAT_TXT,
           null as PRESUM_STRAT_STATE,
           null as NEG_DIV_TXT,
           null as NEG_DIV_STATE,
           null as COMP_EXPECT_TXT,
           null as EXPECT_STATE,
           null as BANK_EXPECT_TXT,
           null as INFLUENCE_TXT,
           null as INFLUENCE_STATE,
           null as SENSITIV_TXT,
           null as SENSITIV_STATE,
           null as INFO_TXT,
           null as INFO_STATE,
           null as DEPENDENCY_TXT,
           null as DEPENDENCY_STATE,
           null as CURRENCYRISK_TXT,
           null as CURRENCYRISK_STATE,
           null as ORIENTATION_TXT,
           null as ORIENTATION_STATE,
           IN_PROFESSIONALISM_TXT,
           DEBTOR_ASSETS_TXT,
           FINANCE_SITUATION_TXT,
           INVEST_ACTIVITY_TXT,
           LIQUID_SITUATION_TXT,
           SUPPORT_PROVIDED_TXT,
           DEBTOR_SUPPORT_TXT,
           CUST_QUAL_STATE,
           null as HQF_DAUKUNBEZ_695,
           null as WQF_ZUVERLAESSIGKEIT_2763_TXT,
           null as WQF_INFOBEREITSCH_2758_TXT,
           null as WQF_UNTERNEHMENTW_2748_TXT,
           null as WQF_MANAGEMENT_SIR_2743_TXT,
           null as HQF_VERKAUFSSTAND_2792_TXT,
           null as WQF_FINANZBEREICH_2778_TXT,
           null as WQF_VRTRBVRMRKTNG_2773_TXT,
           null as WQF_BAUQUALITAET_2768_TXT,
           null as WQF_LIQUIDITAET_5511_TXT
    from ICRE
    union all
    select CUT_OFF_DATE,
           RAT_BUS_ID,
           GNI_KUNDE,
           SOURCE,
           null as PRESUM_STRAT_TXT,
           null as PRESUM_STRAT_STATE,
           null as NEG_DIV_TXT,
           null as NEG_DIV_STATE,
           null as COMP_EXPECT_TXT,
           null as EXPECT_STATE,
           null as BANK_EXPECT_TXT,
           null as INFLUENCE_TXT,
           null as INFLUENCE_STATE,
           null as SENSITIV_TXT,
           null as SENSITIV_STATE,
           null as INFO_TXT,
           null as INFO_STATE,
           null as DEPENDENCY_TXT,
           null as DEPENDENCY_STATE,
           null as CURRENCYRISK_TXT,
           null as CURRENCYRISK_STATE,
           null as ORIENTATION_TXT,
           null as ORIENTATION_STATE,
           null as IN_PROFESSIONALISM_TXT,
           null as DEBTOR_ASSETS_TXT,
           null as FINANCE_SITUATION_TXT,
           null as INVEST_ACTIVITY_TXT,
           null as LIQUID_SITUATION_TXT,
           null as SUPPORT_PROVIDED_TXT,
           null as DEBTOR_SUPPORT_TXT,
           null as CUST_QUAL_STATE,
           HQF_DAUKUNBEZ_695,
           WQF_ZUVERLAESSIGKEIT_2763_TXT,
           WQF_INFOBEREITSCH_2758_TXT,
           WQF_UNTERNEHMENTW_2748_TXT,
           WQF_MANAGEMENT_SIR_2743_TXT,
           HQF_VERKAUFSSTAND_2792_TXT,
           WQF_FINANZBEREICH_2778_TXT,
           WQF_VRTRBVRMRKTNG_2773_TXT,
           WQF_BAUQUALITAET_2768_TXT,
           WQF_LIQUIDITAET_5511_TXT
    from SIR
),
-- Gefiltert nach noetigen Datenfeldern
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        RAT_BUS_ID,
        GNI_KUNDE,
        SOURCE,
        PRESUM_STRAT_TXT,
        PRESUM_STRAT_STATE,
        NEG_DIV_TXT,
        NEG_DIV_STATE,
        COMP_EXPECT_TXT,
        EXPECT_STATE,
        BANK_EXPECT_TXT,
        INFLUENCE_TXT,
        INFLUENCE_STATE,
        SENSITIV_TXT,
        SENSITIV_STATE,
        INFO_TXT,
        INFO_STATE,
        DEPENDENCY_TXT,
        DEPENDENCY_STATE,
        CURRENCYRISK_TXT,
        CURRENCYRISK_STATE,
        ORIENTATION_TXT,
        ORIENTATION_STATE,
        IN_PROFESSIONALISM_TXT,
        DEBTOR_ASSETS_TXT,
        FINANCE_SITUATION_TXT,
        INVEST_ACTIVITY_TXT,
        LIQUID_SITUATION_TXT,
        SUPPORT_PROVIDED_TXT,
        DEBTOR_SUPPORT_TXT,
        CUST_QUAL_STATE,
        HQF_DAUKUNBEZ_695,
        WQF_ZUVERLAESSIGKEIT_2763_TXT,
        WQF_INFOBEREITSCH_2758_TXT,
        WQF_UNTERNEHMENTW_2748_TXT,
        WQF_MANAGEMENT_SIR_2743_TXT,
        HQF_VERKAUFSSTAND_2792_TXT,
        WQF_FINANZBEREICH_2778_TXT,
        WQF_VRTRBVRMRKTNG_2773_TXT,
        WQF_BAUQUALITAET_2768_TXT,
        WQF_LIQUIDITAET_5511_TXT,
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
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_CLIENT_LBRATING_EBA_CURRENT');
create table AMC.TABLE_CLIENT_LBRATING_EBA_CURRENT like CALC.VIEW_CLIENT_LBRATING_EBA distribute by hash (GNI_KUNDE) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CLIENT_LBRATING_EBA_CURRENT_GNI_KUNDE on AMC.TABLE_CLIENT_LBRATING_EBA_CURRENT (GNI_KUNDE);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_CLIENT_LBRATING_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_CLIENT_LBRATING_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

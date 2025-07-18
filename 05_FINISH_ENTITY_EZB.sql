---------------------------------------
-- CLIENT/ENTITY TAPE EZB DICTIONARY --
---------------------------------------
-- CI START FOR ALL TAPES
-- Drop View
drop view AMC.TAPE_CLIENT_ENTITY_EZB;
-- View erstellen
create or replace view AMC.TAPE_CLIENT_ENTITY_EZB as
select distinct
    -- GENERAL
    OSI_ID as OSI_ID,
    coalesce(cast(COUNTRY_ALPHA2 as varchar(3)),'MISS') as CNTRY,
    varchar_format(BIRTH_DATE,'YYYY-MM-DD') as DT_BRTH,
    coalesce(varchar_format(DEFAULT_STATUS_DATE,'YYYY-MM-DD'),'0000-00-00') as DT_DFLT_STTS,
    coalesce(varchar_format(FINANCIAL_STATEMENTS_DATE,'YYYY-MM-DD'),'0000-00-00') as DT_FNNCL_STTMTS,
    coalesce(varchar_format(FINANCIAL_STATEMENTS_DATE_LAST_YEAR,'YYYY-MM-DD'),'0000-00-00') as DT_FNNCL_STTMTS_PRVS,
    coalesce(varchar_format(LEGAL_PROCEEDINGS_COUNTERPARTY_INITIATION_DATE,'YYYY-MM-DD'),'0000-00-00') as DT_INTTN_LGL_PRCDNGS_LE,
    coalesce(varchar_format(PERFORMING_STATUS_DATE,'YYYY-MM-DD'),'0000-00-00') as DT_PRFRMNG_STTS_LE,
    varchar_format(CUT_OFF_DATE,'YYYY-MM-DD') as DT_RFRNC,
    cast(CLIENT_ID as VARCHAR(255)) as ENTTY_ID,
    coalesce(cast(PARENT_ENTITY_ID as VARCHAR(255)),'MISS') as GCC_PRNT_ID,
    coalesce(cast(PARENT_ENTITY_NAME as VARCHAR(255)), 'MISS') as GCC_PRNT_NM,
    coalesce(cast(SEGMENT_CODE as VARCHAR(255)), 'MISS') as INTRNL_SGMNT,
    coalesce(cast(UNIT_CODE as VARCHAR(255)), 'MISS') as INTRNL_UNT,
    coalesce(cast(LEGAL_ID as VARCHAR(20)), 'MISS') as LEI,
    cast(NAME as VARCHAR(255)) as ENTTY_NM,
    coalesce(cast(RATING_AGENCY_NAME as VARCHAR(255)),'MISS') as EXTRNL_RTNG_NM,
    -- Classification
    coalesce(cast(ACCOUNTING_FRAMEWORK as VARCHAR(16)),'99999999999') as ACCNTNG_FRMWRK_SL,
    case when CURE_FLAG then 'Y' when CURE_FLAG is NULL then 'MISS' else 'N' end as CR_FLG,
    case when IS_DECEASED is null and LEGAL_ID is not null then 'N/A'
         when IS_DECEASED is null then 'MISS'
         when IS_DECEASED then 'Y'
    else 'N' end as DCSD,
    coalesce(cast(DEFAULT_STATUS as VARCHAR(16)),'99999999999') as DFLT_STTS,
    coalesce(varchar_format(RATING_EXTERNAL_DATE,'YYYY-MM-DD'),'0000-00-00') as DT_EXTRNL_RTNG,
    coalesce(varchar_format(RATING_INTERNAL_DATE,'YYYY-MM-DD'),'0000-00-00') as DT_INTRNL_RTNG,
    nullif(NACE_CODE, NULL) as ECNMC_ACTVTY,
    case when EMPLOYMENT_STATUS_INTERNAL is null and LEGAL_ID is not null then 'N/A'
         when EMPLOYMENT_STATUS_INTERNAL is null then 'MISS'
    else cast(EMPLOYMENT_STATUS_INTERNAL as VARCHAR(255)) end as EMPLYMNT_STTS_INTRNL,
    case when EMPLOYMENT_STATUS is null and LEGAL_ID is not null then '11111111111'
         else coalesce(cast(EMPLOYMENT_STATUS as VARCHAR(16)),'99999999999') end as EMPLYMNT_STTS,
    coalesce(cast(ENTERPRISE_SIZE as VARCHAR(16)),'99999999999') as ENTRPRS_SZ_LE,
    coalesce(cast(RATING_EXTERNAL as VARCHAR(16)),'99999999999') as EXTRNL_RTNG,
    coalesce(cast(RATING_EXTERNAL_LAST_YEAR as VARCHAR(16)),'99999999999') as EXTRNL_RTNG_PRVS,
    case when HAS_BANKRUPTCY_IN_GROUP then 'Y' when HAS_BANKRUPTCY_IN_GROUP is NULL then 'MISS' else 'N' end as FLG_BNKRPTCY_IN_GRP,
    case when FLG_HGH_CDS then 'Y' when FLG_HGH_CDS is NULL then 'MISS' else 'N' end as FLG_HGH_CDS,
    case when HAS_ISDA_CREDIT_EVENT then 'Y' when HAS_ISDA_CREDIT_EVENT is NULL then 'MISS' else 'N' end as FLG_ISDA_CRDT_EVNT,
    case when HAS_NON_ACCRUAL_STATUS then 'Y' when HAS_NON_ACCRUAL_STATUS is NULL then 'MISS' else 'N' end as FLG_NN_ACCRL,
    case when HAS_REQUESTED_BANKRUPTCY then 'Y' when HAS_REQUESTED_BANKRUPTCY is NULL then 'MISS' else 'N' end as FLG_RQST_BNKRPTCY,
    case when HAS_REQUESTED_CONCESSION then 'Y' when HAS_REQUESTED_CONCESSION is NULL then 'MISS' else 'N' end as FLG_RQST_DSTRSSD_RSTRCTRNG,
    case when HAS_REQUESTED_EMERGENCY_FUNDING then 'Y' when HAS_REQUESTED_EMERGENCY_FUNDING is NULL then 'MISS' else 'N' end as FLG_RQST_EMRGNCY_FNDNG,
    case when HAS_SOLD_WITH_LOSS then 'Y' when HAS_SOLD_WITH_LOSS is NULL then 'MISS' else 'N' end as FLG_SLL_WTH_LSS,
    NVL2(INCOME_SELF_CERTIFIED, case when INCOME_SELF_CERTIFIED then 'Y' else 'N' end, 'MISS') as INCM_SC,
    coalesce(cast(RATING_INTERNAL as VARCHAR(16)),'MISS') as INTRNL_RTNG,
    coalesce(cast(RATING_INTERNAL_LAST_YEAR as VARCHAR(16)),'MISS') as INTRNL_RTNG_PRVS,
    NVL2(LEGAL_PROCEEDINGS_STATUS,cast(LEGAL_PROCEEDINGS_STATUS as VARCHAR(16)), '1') as LGL_PRCDNG_STTS_LE,
    case when OWNED_BY_SPONSOR then 'Y' when OWNED_BY_SPONSOR is NULL then 'MISS' else 'N' end as OWND_BY_SPNSR,
    coalesce(cast(PERFORMANCE_STATUS as VARCHAR(16)),'99999999999') as PRFRMNG_STTS_LE,
    coalesce(cast(RATING_METHOD as VARCHAR(16)),'99999999999') as RTNG_MTHD,
    coalesce(cast(RATING_SCALE as VARCHAR(16)),'99999999999') as RTNG_SCL,
    case when IS_ON_WATCH_LIST then 'Y' when IS_ON_WATCH_LIST is NULL then 'MISS' else 'N' end as WTCH_LST,
    coalesce(cast(DEBTOR_SPV_TYPE as VARCHAR(16)),'99999999999') as SNGL_PRPS_VHCL,
    -- Financial Information
    stg.NUMBER2STRECB(EBITDA_GROUP ) as GRP_EBITDA,
    stg.NUMBER2STRECB(EQUITY_GROUP ) as GRP_EQTY,
    stg.NUMBER2STRECB(NET_DEBT_GROUP ) as GRP_NT_DBT,
    stg.NUMBER2STRECB(ANNUAL_TURNOVER ) as ANNL_TRNVR_LE,
    stg.NUMBER2STRECB(ANNUAL_TURNOVER_PREVIOUS ) as ANNL_TRNVR_PRVS,
    stg.NUMBER2STRECB(CAPITAL_EXPENDITURES ) as CAPEX,
    stg.NUMBER2STRECB(CAPITAL_EXPENDITURES_PREVIOUS ) as CAPEX_PRVS,
    stg.NUMBER2STRECB(COLLECTION_MODE ) as CLLCTN_MD,
    stg.NUMBER2STRECB(CASH ) as CSH,
    stg.NUMBER2STRECB(CASH_PREVIOUS ) as CSH_PRVS,
    stg.NUMBER2STRECB(EBITDA ) as EBITDA,
    stg.NUMBER2STRECB(EBITDA_PREVIOUS ) as EBITDA_PRVS,
    stg.NUMBER2STRECB(EQUITY ) as EQTY,
    stg.NUMBER2STRECB(EQUITY_PREVIOUS ) as EQTY_PRVS,
    '99999999999' as FR_CSH_FLW,
    '99999999999' as FR_CSH_FLW_T1,
    '99999999999' as FR_CSH_FLW_T2,
    '99999999999' as FR_CSH_FLW_T3,
    stg.NUMBER2STRECB(DEBT_GROUP_TOTAL ) as GRP_TTL_DBT,
    stg.NUMBER2STRECB(GOODWILL ) as GDWILL,
    stg.NUMBER2STRECB(GOODWILL_PREVIOUS ) as GDWILL_PRVS,
    case when LOAN_TO_INCOME is null and LEGAL_ID is not null then '11111111111'
        else stg.NUMBER2STRECB(LOAN_TO_INCOME ) end as LTI,
    stg.NUMBER2STRECB(LEVERAGE ) as LVRG,
    stg.NUMBER2STRECB(LEVERAGE_PREVIOUS ) as LVRG_PRVS,
    stg.NUMBER2STRECB(INCOME_OTHER_MONTHLY ) as MNTHL_INCM,
    case when INCOME_SALARY_MONTHLY is null and LEGAL_ID is not null then '11111111111'
        else stg.NUMBER2STRECB(INCOME_SALARY_MONTHLY ) end as MNTHL_INCM_SLR,
    stg.NUMBER2STRECB(TURNOVER_MONTHLY ) as MNTHL_TRNVR,
    stg.NUMBER2STRECB(NET_INCOME ) as NT_INCM,
    stg.NUMBER2STRECB(NET_INCOME_PREVIOUS ) as NT_INCM_PRVS,
    stg.NUMBER2STRECB(DEBT_TOTAL ) as TTL_DBT,
    stg.NUMBER2STRECB(DEBT_TOTAL_PREVIOUS ) as TTL_DBT_PRVS,
    stg.NUMBER2STRECB(INTEREST_PAID_TOTAL ) as TTL_INTRST_PD,
    stg.NUMBER2STRECB(LEVERAGE_RATIO_TOTAL ) as TTL_LVRG_RT,
    stg.NUMBER2STRECB(LEVERAGE_RATIO_TOTAL_PREVIOUS ) as TTL_LVRG_RT_PRVS,
    -- Indicators
    stg.NUMBER2STRECB(DEBT_REPAYMENT_CAPACITY_SENIOR ) as DBT_RPYMNT_CPCTY_SNR_DBT,
    stg.NUMBER2STRECB(DEBT_REPAYMENT_CAPACITY_TOTAL ) as DBT_RPYMNT_CPCTY_TTL,
    stg.NUMBER2STRECB(DEBT_SERVICE_COVERING_RATIO ) as DBT_SRVC_RT,
    stg.NUMBER2STRECB(DEBT_SERVICE_COVERING_RATIO_PREVIOUS ) as DBT_SRVC_RT_12M,
    stg.NUMBER2STRECB(PROBABILITY_OF_DEFAULT_CRR ) as PD_CRR_RD,
    stg.NUMBER2STRECB(PROBABILITY_OF_DEFAULT_IFRS9 ) as PD_IFRS9_12M_RD,
    stg.NUMBER2STRECB(PROBABILITY_OF_DEFAULT_IFRS9_LAST_YEAR ) as PD_IFRS9_12M_RD_T1,
    -- Optional
    NULL as ADD_NMRC1,
    NULL as ADD_NMRC2,
    NULL as ADD_NMRC3,
    NULL as ADD_NMRC4,
    NULL as ADD_DT1,
    NULL as ADD_DT2,
    NULL as ADD_DT3,
    NULL as ADD_TXT1, -- length max 255
    NULL as ADD_TXT2, -- length max 255
    NULL as ADD_TXT3  -- length max 255
from AMC.TABLE_CLIENT_ENTITY_CURRENT as TAPE
;
call stg.TEST_PROC_GRANT_PERMISSION_TO('AMC','TAPE_CLIENT_ENTITY_EZB');

-- CI END FOR ALL TAPES
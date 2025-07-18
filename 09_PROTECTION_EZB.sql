------------------------------------
-- PROTECTION TAPE EZB DICTIONARY --
------------------------------------
-- CI START FOR ALL TAPES
-- Drop View
drop view AMC.TAPE_COLLATERALIZATION_PROTECTION_EZB;
-- View erstellen
create or replace view AMC.TAPE_COLLATERALIZATION_PROTECTION_EZB as
select distinct
    -- General
    coalesce(varchar_format(MATURITY_DATE, 'YYYY-MM-DD'),'0000-00-00') as DT_MTRTY_PRTCTN,
    varchar_format(CUT_OFF_DATE, 'YYYY-MM-DD') as DT_RFRNC,
    case when NATIONAL_ID is null and PROTECTION_TYPE in (2,3,4,5,7,12,13,15,16,17,18) then 'N/A'
         else coalesce(cast(NATIONAL_ID as VARCHAR(255)), 'MISS') end as NTNL_ID,
    coalesce(cast(PROTECTION_ID as VARCHAR(60)), 'MISS') as PRTCTN_ID,
    cast(PROTECTION_PROVIDER_ID as VARCHAR(50)) as PRTCTN_PRVDR_ID,
    case when ADDRESS is null and PROTECTION_TYPE in (2,3,4,5,7,12,13,15,16,17,18) then 'N/A'
         else coalesce(cast(ADDRESS as VARCHAR(255)), 'MISS') end as RL_ESTT_ADDRSS,
    case when COLLATERAL_LOCATION is null and PROTECTION_TYPE in (2,3,4,5,7,12,13,15,16,17,18) then 'N/A'
         else coalesce(cast(COLLATERAL_LOCATION as VARCHAR(255)), 'MISS') end as RL_ESTT_CLLTRL_LCTN,
    case when ASSET_LOCATION is null and PROTECTION_TYPE in (2,3,4,5,7,12,13,15,16,17,18) then 'N/A'
         else coalesce(cast(ASSET_LOCATION as VARCHAR(255)), 'MISS') end as RL_ESTT_CLLTRL_LCTN_INT,
    case when CITY is null and PROTECTION_TYPE in (2,3,4,5,7,12,13,15,16,17,18) then 'N/A'
         else coalesce(cast(CITY as VARCHAR(255)), 'MISS') end as RL_ESTT_CTY,
    case when POST_CODE is null and PROTECTION_TYPE in (2,3,4,5,7,12,13,15,16,17,18) then 'N/A'
         else coalesce(cast(POST_CODE as VARCHAR(255)), 'MISS') end as RL_ESTT_PST_CD,
    -- Classification
    stg.NUMBER2STRECB(MARKET_VALUE_HAIRCUT) as HRCT_MV,
    case
        when PROTECTION_IS_CALLED then 'Y'
        when PROTECTION_IS_CALLED is NULL then 'MISS'
        else 'N' end as PRTCTN_CLLD,
    coalesce(cast(PROTECTION_TYPE as VARCHAR(16)),'99999999999') as TYP_PRTCTN,
    coalesce(cast(PROTECTION_TYPE_INTERNAL as VARCHAR(255)), 'MISS') as TYP_PRTCTN_INTRNL,
    coalesce(cast(PROTECTION_VALUE_TYPE as VARCHAR(16)),'99999999999') as TYP_PRTCTN_VL,
    -- Appraisal
    case when APPRAISAL_CURRENCY is null and PROTECTION_TYPE in (2,3,4,5,7,12,13,15,16,17,18) then 'N/A'
         else coalesce(cast(APPRAISAL_CURRENCY as VARCHAR(16)), 'MISS') end as APPRSL_CRRNCY,
    case when APPRAISER is null and PROTECTION_TYPE in (2,3,4,5,7,12,13,15,16,17,18) then 'N/A'
         else coalesce(cast(APPRAISER as VARCHAR(255)), 'MISS') end as APPRSR,
    case when LAST_FULL_APPRAISAL_DATE is null and PROTECTION_TYPE in (2,3,4,5,7,12,13,15,16,17,18) then '1111-11-11'
         else coalesce(varchar_format(LAST_FULL_APPRAISAL_DATE, 'YYYY-MM-DD'),'0000-00-00') end as DT_LST_FLL_APPRSL,
    coalesce(varchar_format(ORIGINAL_PROTECTION_VALUE_DATE, 'YYYY-MM-DD'),'0000-00-00') as DT_ORGNL_PRTCTN_VL,
    coalesce(varchar_format(PROTECTION_VALUE_DATE, 'YYYY-MM-DD'),'0000-00-00') as DT_PRTCTN_VL,
    stg.NUMBER2STRECB(ORIGINAL_PROTECTION_VALUE) as ORGNL_PRTCTN_VL,
    stg.NUMBER2STRECB(FORCED_SALE_VALUE) as PRTCTN_FRCD_SL_VL,
    stg.NUMBER2STRECB(APPRAISED_MARKET_VALUE) as PRTCTN_VL,
    stg.NUMBER2STRECB(APPRAISED_MARKET_VALUE_NONPERFORMING) as PRTCTN_VL_NPE,
    case when VALUATION_APPROACH is null and PROTECTION_TYPE in (2,3,4,5,7,12,13,15,16,17,18) then '11111111111'
         else coalesce(cast(VALUATION_APPROACH as VARCHAR(16)),'99999999999') end as PRTCTN_VLTN_APPRCH,
    case when APPRAISAL_DATE_PREVIOUS is null and PROTECTION_TYPE in (2,4,5,7,12,15,16,17,18) then '1111-11-11'
         else coalesce(varchar_format(APPRAISAL_DATE_PREVIOUS, 'YYYY-MM-DD'),'0000-00-00') end as DT_APPRSL_PRVS,
    stg.NUMBER2STRECB(APPRAISED_MARKET_VALUE_PREVIOUS) as PRTCTN_VL_PRVS,
    -- Collateral Features
    case when CONSTRUCTION_STATUS is null and PROTECTION_TYPE in (2,3,4,5,7,12,13,15,16,17,18) then '11111111111'
         else coalesce(cast(CONSTRUCTION_STATUS as VARCHAR(16)),'99999999999') end as CNSTRCTN_STTS,
    coalesce(varchar_format(CONSTRUCTION_STATUS_DATE, 'YYYY-MM-DD'),'0000-00-00') as DT_CNSTRCTN_STTS,
    case when FIRST_USAGE_DATE is null and PROTECTION_TYPE in (2,3,4,5,7,12,13,15,16,17,18) then '1111-11-11'
         else coalesce(varchar_format(FIRST_USAGE_DATE, 'YYYY-MM-DD'),'0000-00-00') end as DT_FRST_USG,
    case when DEVELOPMENT_STATUS is null and PROTECTION_TYPE in (2,4,5,7,12,13,15,16,17,18) then '11111111111'
         else coalesce(cast(DEVELOPMENT_STATUS as VARCHAR(16)),'99999999999') end as DVLPMNT_STTS,
    case when MAIN_PURPOSE is null and PROTECTION_TYPE in (2,4,5,12,13,15,16,17,18) then '11111111111'
         else coalesce(cast(MAIN_PURPOSE as VARCHAR(16)),'99999999999') end as MN_PRPS,
    case
        when IS_PRIME_LOCATION is null and PROTECTION_TYPE in (2,3,4,5,7,12,13,15,16,17,18) then 'N/A'
        when IS_PRIME_LOCATION is NULL then 'MISS'
        when IS_PRIME_LOCATION then 'Y'
        else 'N' end as PRM_LCTN,
    -- Financial Information
    case when INCOME_CURRENCY is null and PROTECTION_TYPE in (2,3,4,5,7,8,12,13,15,16,17,18) then '11111111111'
         else coalesce(cast(INCOME_CURRENCY as VARCHAR(16)),'99999999999') end as CRE_INCM_CRRNCY,
    case when OPERATING_EXPENSES_YEARLY is null and PROTECTION_TYPE in (2,3,4,5,7,8,12,13,15,16,17,18) then '11111111111'
         else stg.NUMBER2STRECB(OPERATING_EXPENSES_YEARLY) end as CRE_YRLY_EXPNSS,
    case when INCOME_YEARLY is null and PROTECTION_TYPE in (2,3,4,5,7,8,12,13,15,16,17,18) then '11111111111'
         else stg.NUMBER2STRECB(INCOME_YEARLY) end as CRE_YRLY_INCM,
    -- Covid 19
    --case
    --   when PRTCTN_TYP_PBLC_GRNT_SCHM_C19 then 'Y'
    --   when PRTCTN_TYP_PBLC_GRNT_SCHM_C19 is NULL then NULL
    --   else 'N' end as PRTCTN_TYP_PBLC_GRNT_SCHM_C19,
    -- Optional
    cast(ADD_NMRC1 as DOUBLE) as ADD_NMRC1,
    cast(ADD_NMRC2 as DOUBLE) as ADD_NMRC2,
    cast(ADD_NMRC3 as DOUBLE) as ADD_NMRC3,
    cast(ADD_NMRC4 as DOUBLE) as ADD_NMRC4,
    varchar_format(ADD_DT1, 'YYYY-MM-DD') as ADD_DT1,
    varchar_format(ADD_DT2, 'YYYY-MM-DD') as ADD_DT2,
    varchar_format(ADD_DT3, 'YYYY-MM-DD') as ADD_DT3,
    cast(ADD_TXT1 as VARCHAR(255)) as ADD_TXT1,
    cast(ADD_TXT2 as VARCHAR(255)) as ADD_TXT2,
    cast(ADD_TXT3 as VARCHAR(255)) as ADD_TXT3
from AMC.TABLE_COLLATERALIZATION_PROTECTION_CURRENT as TAPE
;
call stg.TEST_PROC_GRANT_PERMISSION_TO('AMC','TAPE_COLLATERALIZATION_PROTECTION_EZB');

-- CI END FOR ALL TAPES
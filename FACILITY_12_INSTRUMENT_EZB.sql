---------------------------------------------
-- FACILITY/INSTRUMENT TAPE EZB DICTIONARY --
---------------------------------------------
-- CI START FOR ALL TAPES
-- Drop View
drop view AMC.TAPE_FACILITY_INSTRUMENT_EZB;
-- View erstellen
create or replace view AMC.TAPE_FACILITY_INSTRUMENT_EZB as
select distinct
    -- General
    varchar_format(CUT_OFF_DATE, 'YYYY-MM-DD') as DT_RFRNC,
    cast(FACILITY_ID as VARCHAR(60)) as INSTRMNT_ID,
    cast(CONTRACT_ID as VARCHAR(60)) as CNTRCT_ID,
    cast(CURRENCY as VARCHAR(3)) as CRRNCY_DNMNTN,
    varchar_format(INCEPTION_DATE, 'YYYY-MM-DD') as DT_INCPTN,
    cast(OBSERVED_AGENT_ID as VARCHAR(50)) as OBSRVD_AGNT_ID,
    cast(OBSERVED_AGENT_NAME as VARCHAR(255)) as OBSRVD_AGNT_NM,
    coalesce(cast(PRODUCT as VARCHAR(255)), 'MISS') as PRDCT,
    -- Classification
    coalesce(cast(BREACHED_COVENANTS as VARCHAR(255)), 'MISS') as BRCHD_CVNNTS,
    coalesce(cast(ORIGINATION_CHANNEL as VARCHAR(16)), '99999999999') as CHNNL_ORGNTN,
    case
        when INCLUDES_CASH_SWEEP_OR_TRAP then 'Y'
        when INCLUDES_CASH_SWEEP_OR_TRAP is NULL then 'MISS'
        else 'N' end as CSH_SWP_TRP,
    coalesce(cast(COVENANT_STATUS as VARCHAR(16)), '99999999999') as CVNNT_STTS,
    coalesce(cast(COVENANT_TYPE as VARCHAR(16)), '99999999999') as CVNNT_TYP,
    coalesce(cast(DEFAULT_STATUS as VARCHAR(16)), '99999999999') as DFLT_STTS_INSTRMNT,
    coalesce(varchar_format(DEFAULT_STATUS_DATE, 'YYYY-MM-DD'),
             '0000-00-00') as DT_DFLT_STTS_INSTRMNT,
    coalesce(varchar_format(PRINCIPAL_GRACE_PERIOD_ENDDATE, 'YYYY-MM-DD'),
             '0000-00-00') as DT_END_GP_PPAL,
    case when INTEREST_ONLY_PERIOD_ENDDATE is null and (INSTRUMENT_TYPE in (51,71,1000)
                  or PAYMENT_FREQUENCY = 22) then '1111-11-11'
          else coalesce(varchar_format(INTEREST_ONLY_PERIOD_ENDDATE, 'YYYY-MM-DD'),
             '0000-00-00') end as DT_END_INTRST_ONLY,
    varchar_format(FORBEARANCE_STATUS_DATE, 'YYYY-MM-DD') as DT_FRBRNC_STTS,
    varchar_format(FORBEARANCE_STATUS_DATE_PREVIOUS, 'YYYY-MM-DD') as DT_FRBRNC_STTS_PRVS,
    case when INTERNAL_RATING_DATE is null and (INSTRUMENT_TYPE in (1000))
                then '1111-11-11'
         else coalesce(varchar_format(INTERNAL_RATING_DATE, 'YYYY-MM-DD'),
             '0000-00-00') end as DT_INTRNL_RTNG,
    varchar_format(PERFORMING_STATUS_DATE, 'YYYY-MM-DD') as DT_PRFRMNG_STTS,
    coalesce(varchar_format(PERFORMING_STATUS_DATE_PREVIOUS, 'YYYY-MM-DD'),
             '0000-00-00') as DT_PRFRMNG_STTS_PRVS,
    coalesce(varchar_format(INTEREST_ONLY_PERIOD_STARTDATE, 'YYYY-MM-DD'),
             '0000-00-00') as DT_STRT_INTRST_ONLY,
    coalesce(cast(EXPOSURE_IN_SCOPE as Varchar(5)), 'MISS') as EXPSR_IN_SCP,
    case
        when FAILED_SYNDICATION then 'Y'
        when FAILED_SYNDICATION is NULL then 'MISS'
        else 'N' end                                                                                               as FLD_SYNDCTN,
    case
        when LEVERAGE_BUYOUT_FLAG is NULL and INSTRUMENT_TYPE in (20,51,71,80,1000) then 'N/A'
        when LEVERAGE_BUYOUT_FLAG is NULL then 'MISS'
        when LEVERAGE_BUYOUT_FLAG then 'Y'
        else 'N' end as FLG_LBO,
    cast(FORBEARANCE_STATUS as VARCHAR(16)) as FRBRNC_STTS_INSTRMNT,
    case
        when IMPAIRMENT_STATUS is null and INSTRUMENT_TYPE in (71,1000) then '11111111111'
        else coalesce(cast(IMPAIRMENT_STATUS as VARCHAR(16)),'99999999999') end as IMPRMNT_STTS,
    coalesce(cast(IMPAIRMENT_STATUS_PREVIOUS as VARCHAR(16)),'99999999999') as IMPRMNT_STTS_PRVS,
    case
        when INTERNAL_RATING is null and INSTRUMENT_TYPE in (1000) then 'N/A'
        else coalesce(cast(INTERNAL_RATING as VARCHAR(16)),'MISS') end as INTRNL_RTNG,
    case
        when INTERNAL_RATING_AT_INCEPTION is null and INSTRUMENT_TYPE in (1000) then 'N/A'
        else coalesce(cast(INTERNAL_RATING_AT_INCEPTION as VARCHAR(16)),'MISS') end as INTRNL_RTNG_INCPTN,
    coalesce(cast(INTERNAL_SEGMENT_CODE as VARCHAR(255)), 'MISS') as INTRNL_SGMNT,
    coalesce(cast(INTERNAL_UNIT_CODE as VARCHAR(255)), 'MISS') as INTRNL_UNT,
    'N' as LCRE,
    coalesce(cast(LEGAL_PROCEEDINGS_STATUS as VARCHAR(16)), '99999999999') as LGL_PRCDNG_STTS,
    case
        when DEROGATED_FROM_LENDING_STANDARD then 'Y'
        when DEROGATED_FROM_LENDING_STANDARD is NULL then 'MISS'
        else 'N' end as LND_DRGTN,
    --case when IS_POCI then 'Y' when IS_POCI is NULL then NULL else 'N' end                                         as POCI,
    cast(PERFORMING_STATUS as VARCHAR(16)) as PRFRMNG_STTS,
    coalesce(cast(PERFORMING_STATUS_PREVIOUS as VARCHAR(16)), '99999999999') as PRFRMNG_STTS_PRVS,
    case when PROJECT_FINANCE_LOAN is null and INSTRUMENT_TYPE in (51,71,80,1000) then '11111111111'
         else coalesce(cast(PROJECT_FINANCE_LOAN as VARCHAR(16)), '99999999999') end as PRJCT_FNNC_LN,
    coalesce(cast(PURPOSE as VARCHAR(16)), '99999999999') as PRPS,
    case when IS_INTEREST_ONLY is NULL and (INSTRUMENT_TYPE in (51,71,1000) or PAYMENT_FREQUENCY = 22) then 'N/A'
         when IS_INTEREST_ONLY is NULL then 'MISS'
         when IS_INTEREST_ONLY then 'Y'
         else 'N' end                                                                                               as PYMNT_INTRST_ONLY,
    coalesce(cast(RECOURSE as VARCHAR(16)), '99999999999') as RCRS,
    case
        when FOR_REFINANCE_PURPOSE then 'Y'
        when FOR_REFINANCE_PURPOSE is NULL then 'MISS'
        else 'N' end as RFNNC_PRPS,
    case
        when FOR_SPECULATIVE_LAND_FINANCING then 'Y'
        when FOR_SPECULATIVE_LAND_FINANCING is NULL then 'MISS'
        else 'N' end as SPCLTV_LNDNG,
    coalesce(cast(UNDERWRITTEN_TRANSACTION_STATUS as VARCHAR(16)),'99999999999') as STTS_UNDRWRTTN_TRNSCTN,
    case when TRANCH is null and INSTRUMENT_TYPE in (20,51,71,80,1000) then '11111111111'
         else coalesce(cast(TRANCH as VARCHAR(16)), '99999999999') end as TRNCH,
    case when AMORTISATION_TYPE is null and INSTRUMENT_TYPE in (1000) then '11111111111'
         else coalesce(cast(AMORTISATION_TYPE as VARCHAR(16)), '99999999999') end as TYP_AMRTSTN,
    coalesce(cast(INSTRUMENT_TYPE as VARCHAR(16)), '99999999999') as TYP_INSTRMNT,
    case when AMORTISATION_TYPE is null and (INSTRUMENT_TYPE in (1000) or PAYMENT_FREQUENCY = 22) then '11111111111'
         else coalesce(cast(INTEREST_RATE_TYPE as VARCHAR(16)), '99999999999') end as TYP_INTRST_RT,
    case when MORTGAGE_TYPE is null and INSTRUMENT_TYPE in (20,51,71,80,1000,1003) then '11111111111'
         else coalesce(cast(MORTGAGE_TYPE as VARCHAR(16)), '99999999999') end as TYP_MRTGG,
    coalesce(cast(CRE_OPERATION_TYPE as VARCHAR(16)), '99999999999') as TYP_CRE_OPRTN,
    coalesce(varchar_format(PRINCIPAL_GRACE_PERIOD_START_DATE, 'YYYY-MM-DD'),
             '0000-00-00') as DT_STRT_GP_PPAL,
    -- Financial Information
    stg.NUMBER2STRECB(GROSS_CARRYING_AMOUNT) as GRSS_CRRYNG_AMNT_INSTRMNT,
    stg.NUMBER2STRECB(ACCUMULATED_CHANGES_FAIRVALUE_CREDITRISK,2) as ACCMLTD_CHNGS_FV_CR_INSTRMNT, -- sorgt für SQLSTATE 22018
    coalesce(cast(ACCOUNTING_CLASSIFICATION as VARCHAR(16)), '99999999999') as ACCNTNG_CLSSFCTN,
    case when ACCRUED_INTEREST is null and PAYMENT_FREQUENCY = 22 then '11111111111'
         else stg.NUMBER2STRECB(ACCRUED_INTEREST,2) end as ACCRD_INTRST_INSTRMNT,
    stg.NUMBER2STRECB(AMOUNT_DUE_AT_MATURITY) as AMNT_D_AT_MTRTY,
    case when CREDIT_CONVERSION_FACTOR is null and INSTRUMENT_TYPE in (1000) then '11111111111'
         else stg.NUMBER2STRECB(CREDIT_CONVERSION_FACTOR) end as CCF,
    stg.NUMBER2STRECB(COMMITMENT_AMOUNT_INCEPTION,2) as CMMTMNT_INCPTN_INSTRMNT,
    stg.NUMBER2STRECB(COMMITMENT_AMOUNT, 2) as CMMTMNT_INSTRMNT,
    stg.NUMBER2STRECB(CARRYING_AMOUNT, 2) as CRRYNG_AMNT_INSTRMNT,
    stg.NUMBER2STRECB(DEBT_YIELD) as DBT_YLD,
    case when FINAL_MATURITY_DATE is null and INSTRUMENT_TYPE in (1000,1001) then '1111-11-11'
         else coalesce(varchar_format(FINAL_MATURITY_DATE, 'YYYY-MM-DD'),
             '0000-00-00') end as DT_LGL_FNL_MTRTY,
    case when NEXT_INTEREST_RATE_RESET_DATE is null and PAYMENT_FREQUENCY = 22 then '1111-11-11'
         else coalesce(varchar_format(NEXT_INTEREST_RATE_RESET_DATE, 'YYYY-MM-DD'),
             '0000-00-00') end as DT_NXT_INTRST_RT_RST,
    case when ORIGINAL_MATURITY_DATE is null and INSTRUMENT_TYPE in (1000,1001) then '1111-11-11'
         else coalesce(varchar_format(ORIGINAL_MATURITY_DATE, 'YYYY-MM-DD'),
             '0000-00-00') end as DT_ORGNL_MTRTY,
    case when BEHAVIOURAL_MATURITY_IFRS9 is null and INSTRUMENT_TYPE in (1000,1001) then '11111111111'
         else coalesce(cast(BEHAVIOURAL_MATURITY_IFRS9 as VARCHAR(16)), '99999999999') end as IFRS9_BHVRL_MTRTY,
    case when EXPOSURE_AT_DEFAULT is null and INSTRUMENT_TYPE in (1000) then '11111111111'
         else stg.NUMBER2STRECB(EXPOSURE_AT_DEFAULT) end as EAD,
    case when CREDIT_CONVERSION_FACTOR_IFRS9 is null and INSTRUMENT_TYPE in (1000) then '11111111111'
         else stg.NUMBER2STRECB(CREDIT_CONVERSION_FACTOR_IFRS9) end as IFRS9_CCF,
    case when EXPOSURE_AT_DEFAULT_IFRS9 is null and INSTRUMENT_TYPE in (1000) then '11111111111'
         else stg.NUMBER2STRECB(EXPOSURE_AT_DEFAULT_IFRS9) end as IFRS9_EAD,
    stg.NUMBER2STRECB(INSTALMENT_PAYABLE) as INSTLMNT_PAY,
    case when OFF_BALANCE_SHEET_AMOUNT is null and INSTRUMENT_TYPE in (20,51,1000) then '11111111111'
              else stg.NUMBER2STRECB(OFF_BALANCE_SHEET_AMOUNT,2) end as OFF_BLNC_SHT_AMNT_INSTRMNT,
    case when OFF_BALANCE_SHEET_AMOUNT_PREVIOUS is null and INSTRUMENT_TYPE in (20,51,1000) then '11111111111'
              else stg.NUMBER2STRECB(OFF_BALANCE_SHEET_AMOUNT_PREVIOUS) end as OFF_BLNC_SHT_AMNT_INSTRMNT_PRVS,
    stg.NUMBER2STRECB(OUTSTANDING_NOMINAL_AMOUNT,2) as OTSTNDNG_NMNL_AMNT_INSTRMNT,
    stg.NUMBER2STRECB(OUTSTANDING_NOMINAL_AMOUNT_PREVIOUS) as OTSTNDNG_NMNL_AMNT_INSTRMNT_PRVS,
    stg.NUMBER2STRECB(OFF_BALANCE_SHEET_PROVISIONS) as PRVSNS_OFF_BLNC_SHT,
    case when PAYMENT_FREQUENCY is null and INSTRUMENT_TYPE in (1000) then '11111111111'
         else coalesce(cast(PAYMENT_FREQUENCY as VARCHAR(16)), '99999999999') end as PYMNT_FRQNCY,
    stg.NUMBER2STRECB(RETENTION_SHARE) as RTNTN_SHR,
    case when RWA is null and INSTRUMENT_TYPE in (1000) then '11111111111'
         else stg.NUMBER2STRECB(RWA) end as RWA,
    case when RWA_METHOD is null and INSTRUMENT_TYPE in (1000) then '11111111111'
         else coalesce(cast(RWA_METHOD as VARCHAR(16)), '99999999999') end as RWA_MTHD,
    coalesce(cast(SPONSOR_NAME as VARCHAR(255)),'MISS') as SPNSR_NM,
    -- Impairment
    case when ACCUMULATED_IMPAIRMENT is null and INSTRUMENT_TYPE in (71,1000) then '11111111111'
         else stg.NUMBER2STRECB(ACCUMULATED_IMPAIRMENT,2) end as ACCMLTD_IMPRMNT_INSTRMNT,
    case when ACCUMULATED_IMPAIRMENT_PREVIOUS is null and INSTRUMENT_TYPE in (71,1000) then '11111111111'
         else stg.NUMBER2STRECB(ACCUMULATED_IMPAIRMENT_PREVIOUS,2) end as ACCMLTD_IMPRMNT_INSTRMNT_PRVS,
    stg.NUMBER2STRECB(ACCUMULATED_WRITEOFFS,2) as ACCMLTD_WRTFFS_INSTRMNT,
    stg.NUMBER2STRECB(EXPOSURE_INARREAR,2) as ARRRS_INSTRMNT,
    stg.NUMBER2STRECB(EXPOSURE_INARREAR_HIGHEST_12M) as ARRRS_INSTRMNT_12M,
    stg.NUMBER2STRECB(CUMULATED_RECOVERIES_SINCE_DEFAULT) as CMLTV_RCVRS_SNC_DFLT_INSTRMNT,
    case when DAYS_PAST_DUE is null and INSTRUMENT_TYPE in (1000) then '11111111111'
         else coalesce(cast(DAYS_PAST_DUE as VARCHAR(16)), '99999999999') end as DPD,
    coalesce(cast(DAYS_PAST_DUE_HIGHEST_12M as VARCHAR(16)), '99999999999') as DPD_12M,
    coalesce(cast(DAYS_PAST_DUE_HIGHEST_12M_FORBEARANCE as VARCHAR(16)),
             '99999999999') as DPD_12M_FRBRNC_STTS,
    coalesce(cast(DAYS_PAST_DUE_HIGHEST_12M_PERFORMING as VARCHAR(16)),
             '99999999999') as DPD_12M_PRFRMNG_STTS,
    coalesce(cast(DAYS_PAST_DUE_HIGHEST_24M_FORBEARANCE as VARCHAR(16)),
             '99999999999')  as DPD_24M_FRBRNC_STTS,
    coalesce(cast(DAYS_PAST_DUE_HIGHEST_24M_PERFORMING as VARCHAR(16)),
             '99999999999')   as DPD_24M_PRFRMNG_STTS,
    coalesce(cast(DAYS_PAST_DUE_FORBEARANCE as VARCHAR(16)), '99999999999') as DPD_FRBRNC_STTS,
    coalesce(cast(DAYS_PAST_DUE_PERFORMING as VARCHAR(16)), '99999999999') as DPD_PRFRMNG_STTS,
    coalesce(varchar_format(IMPAIRMENT_STATUS_DATE, 'YYYY-MM-DD'),
             '0000-00-00') as DT_IMPRMNT_STTS,
    coalesce(varchar_format(IMPAIRMENT_STATUS_DATE_PREVIOUS, 'YYYY-MM-DD'),
             '0000-00-00') as DT_IMPRMNT_STTS_PRVS,
    coalesce(varchar_format(PAST_DUE_DATE, 'YYYY-MM-DD'), '0000-00-00') as DT_PST_D,
    case when IMPAIRMENT_ASSESSMENT_METHOD is null and INSTRUMENT_TYPE in (71,1000) then '11111111111'
         else coalesce(cast(IMPAIRMENT_ASSESSMENT_METHOD as VARCHAR(16)), '99999999999') end as IMPRMNT_ASSSSMNT_MTHD,
    coalesce(cast(IMPAIRMENT_CALCULATION_METHOD as VARCHAR(16)), '99999999999') as IMPRMNT_CLCLTN_MTHD,
    case when FORBEARANCE_NUMBER is null and INSTRUMENT_TYPE in (51,71,1000) then '11111111111'
         else coalesce(cast(FORBEARANCE_NUMBER as VARCHAR(16)), '99999999999') end as NMBR_FRBRNC_MSRS,
    -- Indicators
    case when CORRELATION_COEFFICIENT is null and INSTRUMENT_TYPE in (1000) then '11111111111'
         else stg.NUMBER2STRECB(CORRELATION_COEFFICIENT) end as CRRLTN_CFFCNT,
    case when LGD_IFRS9 is null and INSTRUMENT_TYPE in (1000) then '11111111111'
         else stg.NUMBER2STRECB(LGD_IFRS9) end as IFRS9_LGD,
    case when LGD is null and INSTRUMENT_TYPE in (1000) then '11111111111'
         else stg.NUMBER2STRECB(LGD) end as LGD,
    case when LTV is null and INSTRUMENT_TYPE in (51,1000) then '11111111111'
         else stg.NUMBER2STRECB(LGD) end as LTV,
    stg.NUMBER2STRECB(LTV_INCEPTION) as LTV_INCPTN,
    stg.NUMBER2STRECB(LTV_NONPERFORMING) as LTV_NPE,
    stg.NUMBER2STRECB(PROBABILITY_OF_DEFAULT_CRR_INCEPTION) as PD_CRR_INCPTN,
    case when PROBABILITY_OF_DEFAULT_CRR is null and INSTRUMENT_TYPE in (1000) then '11111111111'
         else stg.NUMBER2STRECB(PROBABILITY_OF_DEFAULT_CRR) end as PD_CRR_RD,
    case when PROBABILITY_OF_DEFAULT_CRR_PREV_YEAR is null and INSTRUMENT_TYPE in (1000) then '11111111111'
         else stg.NUMBER2STRECB(PROBABILITY_OF_DEFAULT_CRR_PREV_YEAR) end as PD_CRR_RD_T1,
    case when PROBABILITY_OF_DEFAULT_IFRS9_12M_INCEPTION is null and INSTRUMENT_TYPE in (1000) then '11111111111'
         else stg.NUMBER2STRECB(PROBABILITY_OF_DEFAULT_IFRS9_12M_INCEPTION) end as PD_IFRS9_12M_INCPTN,
    case when PROBABILITY_OF_DEFAULT_IFRS9_12M is null and INSTRUMENT_TYPE in (1000) then '11111111111'
         else stg.NUMBER2STRECB(PROBABILITY_OF_DEFAULT_IFRS9_12M) end as PD_IFRS9_12M_RD,
    stg.NUMBER2STRECB(PROBABILITY_OF_DEFAULT_IFRS9_12M_PREV_YEAR) as PD_IFRS9_12M_RD_T1,
    stg.NUMBER2STRECB(PROBABILITY_OF_DEFAULT_IFRS9_LIFETIME_INCEPTION) as PD_IFRS9_LFTM_INCPTN,
    stg.NUMBER2STRECB(PROBABILITY_OF_DEFAULT_IFRS9_RMNNG_LIFETIME_INCEPTION) as PD_IFRS9_RMNNG_LFTM_INCPTN,
    stg.NUMBER2STRECB(PROBABILITY_OF_DEFAULT_IFRS9_RMNNG_LIFETIME) as PD_IFRS9_RMNNG_LFTM_RD,
    case when RATING_METHOD is null and INSTRUMENT_TYPE in (1000) then '11111111111'
         else coalesce(cast(RATING_METHOD as VARCHAR(16)), '99999999999') end as RTNG_MTHD,
    case when RATING_SCALE is null and INSTRUMENT_TYPE in (1000) then '11111111111'
         else coalesce(cast(RATING_SCALE as VARCHAR(16)), '99999999999') end as RTNG_SCL,
    case when SIGNIFICANT_INCREASE_ASSESSMENT_METHOD is null and INSTRUMENT_TYPE in (1000) then '11111111111'
         else coalesce(cast(SIGNIFICANT_INCREASE_ASSESSMENT_METHOD as VARCHAR(16)), '99999999999') end as SICR_ASSSSMNT_MTHD,
    -- Interest Rates
    stg.NUMBER2STRECB(INTEREST_RATE,6) as ANNLSD_AGRD_RT,
    stg.NUMBER2STRECB(EFFECTIVE_INTEREST_RATE) as EIR,
    stg.NUMBER2STRECB(EFFECTIVE_INTEREST_RATE_INCEPTION) as EIR_INCPTN,
    case when INTEREST_RATE_RESET_FREQUENCY is null and PAYMENT_FREQUENCY = 22 then '11111111111'
         else coalesce(cast(INTEREST_RATE_RESET_FREQUENCY as VARCHAR(16)), '99999999999') end as INTRST_RT_RST_FRQNCY,
    -- Optional
    cast(ADD_NMRC1 as FLOAT) as ADD_NMRC1,
    cast(ADD_NMRC2 as FLOAT) as ADD_NMRC2,
    cast(ADD_NMRC3 as FLOAT) as ADD_NMRC3,
    cast(ADD_NMRC4 as FLOAT) as ADD_NMRC4,
    varchar_format(ADD_DT1, 'YYYY-MM-DD') as ADD_DT1,
    varchar_format(ADD_DT2, 'YYYY-MM-DD') as ADD_DT2,
    varchar_format(ADD_DT3, 'YYYY-MM-DD') as ADD_DT3,
    cast(ADD_TXT1 as VARCHAR(255)) as ADD_TXT1,
    cast(ADD_TXT2 as VARCHAR(255)) as ADD_TXT2,
    cast(ADD_TXT3 as VARCHAR(255)) as ADD_TXT3,
    -- Servicing
    case when RECEIVED_AMORTIZATION_12M is null and AMORTISATION_TYPE = 4 then '11111111111'
         else stg.NUMBER2STRECB(RECEIVED_AMORTIZATION_12M) end as RCVD_AMRTSTN_12M,
    case when RECEIVED_AMORTIZATION_24M is null and AMORTISATION_TYPE = 4 then '11111111111'
         else stg.NUMBER2STRECB(RECEIVED_AMORTIZATION_24M) end as RCVD_AMRTSTN_24M,
    case when RECEIVED_INTEREST_12M is null and PAYMENT_FREQUENCY = 22 then '11111111111'
         else stg.NUMBER2STRECB(RECEIVED_INTEREST_12M) end as RCVD_INTRST_12M,
    case when RECEIVED_INTEREST_24M is null and PAYMENT_FREQUENCY = 22 then '11111111111'
         else stg.NUMBER2STRECB(RECEIVED_INTEREST_24M) end as RCVD_INTRST_24M,
    -- Syndication
    case when SYNDICATE_LENDER_ROLE is null and INSTRUMENT_TYPE in (20,51,71,80,1000) then '11111111111'
         else coalesce(cast(SYNDICATE_LENDER_ROLE as VARCHAR(16)), '99999999999') end as SYNDCT_RL,
    case when SYNDICATE_AGENT_NAME is null and INSTRUMENT_TYPE in (20,51,71,80,1000) then 'N/A'
         else coalesce(cast(SYNDICATE_AGENT_NAME as VARCHAR(255)), 'MISS') end as SYNDCTD_AGNT,
    case when SYNDICATED_CONTRACT_ID is null and INSTRUMENT_TYPE in (20,51,71,80,1000) then 'N/A'
         else coalesce(cast(SYNDICATED_CONTRACT_ID as VARCHAR(60)), 'MISS') end as SYNDCTD_CNTRCT_ID,
    case when SYNDICATE_LENDERS_NAMES is null and INSTRUMENT_TYPE in (20,51,71,80,1000) then 'N/A'
         else coalesce(cast(SYNDICATE_LENDERS_NAMES as VARCHAR(255)), 'MISS') end as SYNDCTD_LNDRS,
    case when SYNDICATE_LENDERS_NAMES is null and INSTRUMENT_TYPE in (20,51,71,80,1000) then '11111111111'
         else stg.NUMBER2STRECB(SYNDICATE_SHARE) end as SYNDCTD_SHR,
    case when SYNDICATION_TYPE is null and INSTRUMENT_TYPE in (20,51,71,80,1000) then '11111111111'
         else coalesce(cast(SYNDICATION_TYPE as VARCHAR(16)), '99999999999') end as SYNDCTN_TYP
    -- COVID19 Kennzahlen wurden entfernt
    --     coalesce(cast(EBA_CMPLNT_MRTR_ST_C19 as BIGINT), 99999999999)                                                  as EBA_CMPLNT_MRTR_ST_C19,
    --     coalesce(varchar_format(DT_CMPLNT_MRTR_STTS_C19, 'YYYY-MM-DD'),
    --              '0000-00-00')                                                                                         as DT_CMPLNT_MRTR_STTS_C19,
    --     coalesce(varchar_format(DT_CMPLNT_MRTR_STTS_PRVS_C19, 'YYYY-MM-DD'),
    --              '0000-00-00')                                                                                         as DT_CMPLNT_MRTR_STTS_PRVS_C19,
    --     coalesce(cast(MTRTY_LTST_MRTR_C19 as INTEGER), 99999999999)                                                    as MTRTY_LTST_MRTR_C19,
    --     coalesce(cast(TYP_CMPLNT_MRTR_C19 as BIGINT), 99999999999)                                                     as TYP_CMPLNT_MRTR_C19,
    --     case
    --         when GRC_PRD_CPTL_INTRST_C19 then 'Y'
    --         when GRC_PRD_CPTL_INTRST_C19 is NULL then NULL
    --         else 'N' end                                                                                               as GRC_PRD_CPTL_INTRST_C19,
    --     cast(CMPLNT_MRTR_C19_NM as VARCHAR(255))                                                                       as CMPLNT_MRTR_C19_NM,
    --     coalesce(cast(FRBRNC_STTS_C19 as BIGINT), 99999999999)                                                         as FRBRNC_STTS_C19,
    --     coalesce(varchar_format(DT_FRBRNC_STTS_C19, 'YYYY-MM-DD'),
    --              '0000-00-00')                                                                                         as DT_FRBRNC_STTS_C19,
    --     coalesce(varchar_format(DT_FRBRNC_STTS_PRVS_C19, 'YYYY-MM-DD'),
    --              '0000-00-00')                                                                                         as DT_FRBRNC_STTS_PRVS_C19,
    --     coalesce(cast(MTRTY_LTST_FRBRNC_MSR_C19 as INTEGER), 99999999999)                                              as MTRTY_LTST_FRBRNC_MSR_C19,
    --     coalesce(varchar_format(DT_END_GP_PPAL_C19, 'YYYY-MM-DD'),
    --              '0000-00-00')                                                                                         as DT_END_GP_PPAL_C19,
    --     coalesce(varchar_format(DT_END_INTRST_ONLY_C19, 'YYYY-MM-DD'),
    --              '0000-00-00')                                                                                         as DT_END_INTRST_ONLY_C19,
    --     coalesce(cast(SBJCT_PBLC_GRNT_SCHM_C19 as BIGINT), 99999999999)                                                as SBJCT_PBLC_GRNT_SCHM_C19,
    --     cast(PBLC_GRNT_SCHM_C19_NM as VARCHAR(255))                                                                    as PBLC_GRNT_SCHM_C19_NM,
    --     coalesce(cast(PMNT_PBLC_GRNT_SCHM_C19 as FLOAT), 99999999999)                                                  as PMNT_PBLC_GRNT_SCHM_C19
from AMC.TABLE_FACILITY_INSTRUMENT_CURRENT as TAPE
;
call stg.TEST_PROC_GRANT_PERMISSION_TO('AMC','TAPE_FACILITY_INSTRUMENT_EZB');

-- CI END FOR ALL TAPES
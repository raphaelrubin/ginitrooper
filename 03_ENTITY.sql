------------------------
-- ENTITIES / CLIENTS --
------------------------
-- Modellierung für EZB-Dictionary

drop view CALC.VIEW_CLIENT_ENTITY;
create or replace view CALC.VIEW_CLIENT_ENTITY as
with PORTFOLIO as (
    select CUT_OFF_DATE,
           FACILITY_ID,
           CLIENT_NO,
           CLIENT_ID
           from CALC.SWITCH_PORTFOLIO_INSTRUMENT_TO_ENTITY_CURRENT as PORTFOLIO
),
ACCOUNTHOLDER_PRE_GRP as (
          select ACC.CUT_OFF_DATE,
                 ACC.KONZERN_ID,
                 sum(SAP_INANSPRUCHNAHME_SUMME) as GROUP_SAP_INANSPRUCHNAME_SUMME,
                 sum(SAP_FREILINIE_SUMME) as GROUP_SAP_FREIELINIE_SUMME
          from CALC.SWITCH_CLIENT_ACCOUNTHOLDER_CURRENT as ACC
          where ACC.KONZERN_ID is not null and ACC.KONZERN_ID <> 'NLB_0'
          group by ACC.CUT_OFF_DATE,ACC.KONZERN_ID
),
ACCOUNTHOLDER_PRE as (
          select ACC.CUT_OFF_DATE,
                 ACC.CLIENT_ID as ENTITY_ID,
                 ACC.KONZERN_ID,
                 ACC.CLIENT_NAME_ANONYMIZED as ENTITY_NM,
                 ACC.RATING_ID,
                 ACC.SAP_INANSPRUCHNAHME_SUMME,
                 ACC.SAP_FREILINIE_SUMME,
                 NVL(EA.DFL_STTS, case when ACC.RATING_ID is null then
                     case when ACC.RATING_ID not in (25,26,27,85,86) then 14
                          else 19 end
                 end) as DFL_STTS,
                 EA.DT_FAILURE
          from CALC.SWITCH_CLIENT_ACCOUNTHOLDER_CURRENT as ACC
          left join CALC.SWITCH_CLIENT_ABACUS_CURRENT EA on (ACC.CUT_OFF_DATE, ACC.CLIENT_ID) = (EA.CUT_OFF_DATE, EA.CLIENT_NO)
),
ABACUS_INSTRUMENT_PRE as (
    select P.CLIENT_NO,
           max(DFLT_STTS_INSTRMNT) as MAX_RATING,
           min(I.DT_INCPTN) as MIN_DT_INCPTN,
           min(I.DFLT_STTS_INSTRMNT) as MIN_DT_DFLT_STTS_INSTRMNT,
           min(I.DT_PRFRMNG_STTS) as MIN_DT_PRFRMNG_STTS_INSTRMNT,
           min(I.DT_FAILURE) as MIN_DT_FAILURE
    from CALC.SWITCH_FACILITY_ABACUS_INSTRUMENT_CURRENT as I
    inner join PORTFOLIO as P on (I.CUT_OFF_DATE, I.INSTRUMENT_ID) = (P.CUT_OFF_DATE, P.FACILITY_ID)
    group by P.CLIENT_NO
),
PRFRMNG_STTS_PRE as (
    select CUT_OFF_DATE,
           ENTITY_ID,
           case when DFL_STTS in (18,19,20) then 1
                when DFL_STTS = 14 then 11 end as PRFRMNG_STTS_LE
    from ACCOUNTHOLDER_PRE
),
STTS_ENTITY_PRE as (
    select ACP.CUT_OFF_DATE,
           ACP.ENTITY_ID,
           case when DFL_STTS in (18,19,20) then NVL2(ACP.DT_FAILURE,ACP.DT_FAILURE,IP.MIN_DT_FAILURE)
                else MIN_DT_INCPTN end as DT_DFLT_STTS,
           case when PRFS.PRFRMNG_STTS_LE = 11 then IP.MIN_DT_INCPTN
                when PRFS.PRFRMNG_STTS_LE = 1 then IP.MIN_DT_PRFRMNG_STTS_INSTRMNT
                end as DT_PRFRMNG_STTS_LE,
           PRFRMNG_STTS_LE,
           DFL_STTS
    from ACCOUNTHOLDER_PRE as ACP
    left join ABACUS_INSTRUMENT_PRE as IP on IP.CLIENT_NO = ACP.ENTITY_ID
    left join PRFRMNG_STTS_PRE PRFS on (ACP.CUT_OFF_DATE, ACP.ENTITY_ID) = (PRFS.CUT_OFF_DATE,PRFS.ENTITY_ID)
),
ACCOUNTHOLDER as (
          select NVL(APREG.CUT_OFF_DATE, APRE.CUT_OFF_DATE) as CUT_OFF_DATE,
                 APRE.ENTITY_ID,
                 APRE.ENTITY_NM,
                 RTNG.ECB_CODE as RTNG_SCL,
                 APRE.SAP_FREILINIE_SUMME + APRE.SAP_INANSPRUCHNAHME_SUMME as TTL_DBT,
                 APREG.GROUP_SAP_FREIELINIE_SUMME + APREG.GROUP_SAP_INANSPRUCHNAME_SUMME as GRP_TTL_DBT
          from ACCOUNTHOLDER_PRE_GRP APREG
          right join ACCOUNTHOLDER_PRE APRE on (APRE.CUT_OFF_DATE, APRE.KONZERN_ID) = (APREG.CUT_OFF_DATE, APREG.KONZERN_ID)
          left join SMAP.ECB_ENTITY_RATING_SCALE RTNG on APRE.RATING_ID = RTNG.NLB_VALUE
),
CLIENT_IWHS as (
    select distinct IWHS.CUT_OFF_DATE, BRANCH_BORROWER, BORROWER_NO, BORROWERNAME,
           COUNTRY, NACE, LEGALFORM, PERSONTYPE, ZUGRIFFSSCHUTZ,
           BIRTHDAY,DCSD, BERUFL_STELLUNG
    from (
             select CUTOFFDATE as CUT_OFF_DATE,
                    BRANCH     as BRANCH_BORROWER,
                    BORROWERID as BORROWER_NO,
                    BORROWERNAME,
                    COUNTRY,
                    NACE,
                    LEGALFORM,
                    PERSONTYPE,
                    ZUGRIFFSSCHUTZ,
                    BIRTHDAY,
                    DCSD,
                    BERUFL_STELLUNG
             from NLB.IWHS_KUNDE_CURRENT
             union all
             select CUTOFFDATE as CUT_OFF_DATE,
                    BRANCH     as BRANCH_BORROWER,
                    BORROWERID as BORROWER_NO,
                    BORROWERNAME,
                    COUNTRY,
                    NACE,
                    LEGALFORM,
                    PERSONTYPE,
                    ZUGRIFFSSCHUTZ,
                    BIRTHDAY,
                    DCSD,
                    BERUFL_STELLUNG
             from BLB.IWHS_KUNDE_CURRENT
             union all
             select CUTOFFDATE as CUT_OFF_DATE,
                    BRANCH     as BRANCH_BORROWER,
                    BORROWERID as BORROWER_NO,
                    BORROWERNAME,
                    COUNTRY,
                    NACE,
                    LEGALFORM,
                    PERSONTYPE,
                    ZUGRIFFSSCHUTZ,
                    BIRTHDAY,
                    DCSD,
                    BERUFL_STELLUNG
             from ANL.IWHS_KUNDE_CURRENT
         ) as IWHS
    inner join PORTFOLIO as P on (IWHS.CUT_OFF_DATE, IWHS.BRANCH_BORROWER || '_' || IWHS.BORROWER_NO ) = (P.CUT_OFF_DATE, P.CLIENT_ID)
),
IWHS_FINISH as (
    select IWHS.CUT_OFF_DATE,
           IWHS.BORROWER_NO as ENTITY_ID,
           IWHS.BORROWERNAME as ENTITY_NAME,
           case when IWHS.DCSD = '1' and IWHS.PERSONTYPE in ('N','P','G') then true
                when IWHS.PERSONTYPE in ('N','P','G') then false
           else null end as DCSD,
           EMPL_STTS.ECB_CODE as EMPLYMNT_STTS,
           EMPL_STTS.NLB_DESCRIPTION as EMPLYMNT_STTS_INTRNL,
           IWHS.BIRTHDAY as DT_BRTH,
           LA.COUNTRY_ISO_ALPHA_2 as COUNTRY_ALPHA2
    from CLIENT_IWHS IWHS
    left join SMAP.ECB_ENTITY_EMPLOYMENT_STATUS as EMPL_STTS on EMPL_STTS.NLB_VALUE = IWHS.BERUFL_STELLUNG
    left join SMAP.COUNTRY_CODE_MAP as LA on regexp_replace(UCASE(IWHS.COUNTRY), '.*\d\s', '') = LA.COUNTRY_NAME
),
BW_P80_EXT as (
    select BW_P80.CUT_OFF_DATE,
           BW_P80.FACILITY_ID,
           BW_P80.CLIENT_NO,
           BW_P80.SUMME_EAD as EAD,
           BW_P80.SUMME_RWAARM as RWAARM,
           BW_P80.Weighted_CCFWER as CCF,
           BW_P80.Weigthed_LGDWER as LGD,
           BW_P80.TRNCH,
           BW_P80.FLG_LBO,
           BW_P80.SUMME_JAHRESUMSATZ
    from CALC.SWITCH_FACILITY_BW_P80_EXTERNAL_CURRENT as BW_P80
),
ENTITY_BW_ENTRPRS_SZ as (
    select CUT_OFF_DATE,
           CLIENT_NO,
           max(case when SUMME_JAHRESUMSATZ <= 2000000 then 4 -- KLEINST UNTERNEHMEN
                when SUMME_JAHRESUMSATZ > 2000000 and SUMME_JAHRESUMSATZ <= 10000000 then 3 -- KLEINUNTERNEHMEN
                when SUMME_JAHRESUMSATZ > 10000000 and SUMME_JAHRESUMSATZ <= 50000000 then 2 -- MITTLERES UNTERNEHMEN
                when SUMME_JAHRESUMSATZ > 50000000 then 1 -- GROSSUNTERNEHMEN
           else null end) as BW_ENTRPRS_SZ_LE
    from BW_P80_EXT
    group by CUT_OFF_DATE,CLIENT_NO
),
ENTITY_KR as (
    select ZEB.CUT_OFF_DATE,
           ZEB.CLIENT_NO,
           sum(ZEB.PD_IFRS9_12M_RD * BW.EAD) / (case when sum(BW.EAD) <> 0 then sum(BW.EAD) else null end) as PD_IFRS9_12M_RD
    from CALC.SWITCH_FACILITY_KREDITRISIKO_KENNZAHLEN_ECB_CURRENT ZEB
    inner join BW_P80_EXT as BW on (ZEB.CUT_OFF_DATE, ZEB.FACILITY_ID) = (BW.CUT_OFF_DATE, BW.FACILITY_ID)
    group by ZEB.CUT_OFF_DATE, ZEB.CLIENT_NO
),
ENTITY_KR_LTI as (
    select ZEB.CUT_OFF_DATE,
           ZEB.CLIENT_NO,
           sum(ZEB.CMMTMNT_INSTRMNT) / (case when max(SPOT.MNTHL_INCM_SLR) <> 0 then max(SPOT.MNTHL_INCM_SLR) end) as LTI
    from CALC.SWITCH_FACILITY_KREDITRISIKO_KENNZAHLEN_ECB_CURRENT ZEB
    inner join CALC.SWITCH_CLIENT_SPOT_LOAN_CURRENT as SPOT on (ZEB.CUT_OFF_DATE, ZEB.CLIENT_NO) = (SPOT.CUT_OFF_DATE,SPOT.ENTITY_ID)
    group by ZEB.CUT_OFF_DATE, ZEB.CLIENT_NO
),
MAX_EAD_CLIENT as (
    select P.CLIENT_NO,
           max(BW_P80.SAP_EAD) as MAX_EAD
    from PORTFOLIO P
    left join CALC.SWITCH_FACILITY_BW_P80_AOER_CURRENT as BW_P80 on (P.CUT_OFF_DATE, P.FACILITY_ID) = (BW_P80.CUT_OFF_DATE, BW_P80.FACILITY_ID)
    group by P.CLIENT_NO
),
SEGMENT_PRE as (
    select P.CLIENT_NO,
           BW_P80.SAP_SEGMENT,
           SAP_EAD
    from PORTFOLIO P
    left join CALC.SWITCH_FACILITY_BW_P80_AOER_CURRENT as BW_P80 on (P.CUT_OFF_DATE, P.FACILITY_ID) = (BW_P80.CUT_OFF_DATE, BW_P80.FACILITY_ID)
),
SEGMENT_DIST as (
    select SP.CLIENT_NO,SP.SAP_SEGMENT from SEGMENT_PRE SP
    inner join MAX_EAD_CLIENT as MEAD on (SP.CLIENT_NO,SP.SAP_EAD) = (MEAD.CLIENT_NO, MEAD.MAX_EAD)
),
SEGMENT as (
    select distinct CLIENT_NO,
                    SST.NLB_DESCRIPTION as INTRNL_SGMNT
    from SEGMENT_DIST
    inner join SMAP.SAP_SEGMID_TXT SST on SEGMENT_DIST.SAP_SEGMENT = SST.NLB_CODE
),
-- fuer Berechnung NULL Rules
-- TYP_INSTRMNT_PRE as (
--     select P.CUT_OFF_DATE,
--            P.FACILITY_ID,
--            P.CLIENT_ID_ORIG as CLIENT_ID,
--            TYP_INSTR.ECB_CODE as TYP_INSTRMNT
--     from PORTFOLIO as P
--     left join CALC.SWITCH_FACILITY_CURRENT as F
--     on (P.CUT_OFF_DATE, P.FACILITY_ID) = (F.CUT_OFF_DATE, F.FACILITY_ID)
--     left join SMAP.ECB_INSTRUMENT_INSTRUMENT_TYPE TYP_INSTR on F.PRODUCTTYPE = TYP_INSTR.NLB_VALUE
-- ),
ENTITY_FINISH as (
    select distinct P.CUT_OFF_DATE,
                    P.CLIENT_NO as ENTITY_ID,
                    ACC.ENTITY_NM,
                    ACC.RTNG_SCL,
                    ACC.TTL_DBT,
                    ACC.GRP_TTL_DBT,
                    IWHS.DCSD,
                    IWHS.EMPLYMNT_STTS,
                    IWHS.EMPLYMNT_STTS_INTRNL,
                    IWHS.DT_BRTH,
                    IWHS.COUNTRY_ALPHA2,
                    SEGMENT.INTRNL_SGMNT,
                    EK.PD_IFRS9_12M_RD,
                    EK_LTI.LTI
    from PORTFOLIO P
    left join IWHS_FINISH IWHS on (IWHS.CUT_OFF_DATE, IWHS.ENTITY_ID) = (P.CUT_OFF_DATE, P.CLIENT_NO)
    left join ACCOUNTHOLDER ACC on (ACC.CUT_OFF_DATE,ACC.ENTITY_ID) = (P.CUT_OFF_DATE, P.CLIENT_NO)
    left join ENTITY_KR as EK on (EK.CUT_OFF_DATE, EK.CLIENT_NO) = (P.CUT_OFF_DATE, P.CLIENT_NO)
    left join ENTITY_KR_LTI as EK_LTI on (EK_LTI.CUT_OFF_DATE, EK_LTI.CLIENT_NO) = (P.CUT_OFF_DATE, P.CLIENT_NO)
    left join SEGMENT on IWHS.ENTITY_ID = SEGMENT.CLIENT_NO
),
data as (
    select distinct PORTFOLIO.CUT_OFF_DATE as CUT_OFF_DATE,                               -- DT_RFRNC
           PORTFOLIO.CLIENT_ID         as CLIENT_ID,                                      -- ENTTY_ID
           PORTFOLIO.CLIENT_NO         as CLIENT_NO,
           -- GENERAL
           NULL                        as OSI_ID,                                         -- OSI_ID
           ABACUS.CNTRY                as COUNTRY_ALPHA2,                                 -- CNTRY
           EF.DT_BRTH                  as BIRTH_DATE,                                     -- DT_BRTH
           ABACUS_CALC.DT_DFLT_STTS    as DEFAULT_STATUS_DATE,                            -- DT_DFLT_STTS
           NULL                        as FINANCIAL_STATEMENTS_DATE,                      -- DT_FNNCL_STTMTS
           NULL                        as FINANCIAL_STATEMENTS_DATE_LAST_YEAR,            -- DT_FNNCL_STTMTS_PRVS
           ABACUS.DT_INTTN_LGL_PRCDNGS_LE as LEGAL_PROCEEDINGS_COUNTERPARTY_INITIATION_DATE, -- DT_INTTN_LGL_PRCDNGS_LE
           ABACUS_CALC.DT_PRFRMNG_STTS_LE as PERFORMING_STATUS_DATE,                         -- DT_PRFRMNG_STTS_LE
           -- DT_RFRNC
           -- ENTTY_ID
           SPOT.GCC_PRNT_ID            as PARENT_ENTITY_ID,                               -- GCC_PRNT_ID
           SPOT.GCC_PRNT_NM            as PARENT_ENTITY_NAME,                             -- GCC_PRNT_NM
           EF.INTRNL_SGMNT             as SEGMENT,                                        -- INTRNL_SGMNT
           SPOT.INTRNL_UNT             as UNIT_CODE,                                      -- INTRNL_UNT
           ABACUS.LEI                  as LEGAL_ID,                                       -- LEI
           case when (EF.ENTITY_NM is null or length(EF.ENTITY_NM) = 64) and ABACUS.ENTTY_NM is not null
               then ABACUS.ENTTY_NM else EF.ENTITY_NM end as NAME,                        -- ENTTY_NM
           SPOT.EXTRNL_RTNG_NM         as RATING_AGENCY_NAME,                             -- EXTRNL_RTNG_NM
           -- Classification
           '1'                         as ACCOUNTING_FRAMEWORK,                           -- ACCNTNG_FRMWRK_SL
           SPOT.CR_FLG                 as CURE_FLAG,                                      -- CR_FLG
           EF.DCSD                     as IS_DECEASED,                                    -- DCSD
           ABACUS_CALC.DFL_STTS        as DEFAULT_STATUS,                                 -- DFLT_STTS
           SPOT.DT_EXTRNL_RTNG         as RATING_EXTERNAL_DATE,                           -- DT_EXTRNL_RTNG
           SPOT.DT_INTRNL_RTNG         as RATING_INTERNAL_DATE,                           -- DT_INTRNL_RTNG
           ABACUS.ECNMC_ACTVTY         as NACE_CODE,                                      -- ECNMC_ACTVTY
           EF.EMPLYMNT_STTS_INTRNL     as EMPLOYMENT_STATUS_INTERNAL,                     -- EMPLYMNT_STTS_INTRNL
           EF.EMPLYMNT_STTS            as EMPLOYMENT_STATUS,                              -- EMPLYMNT_STTS
           NVL(ABACUS.ENTRPRS_SZ_LE, BW_ENTRPRS_SZ.BW_ENTRPRS_SZ_LE)
               as ENTERPRISE_SIZE,                                                        -- ENTRPRS_SZ_LE
           SPOT.EXTRNL_RTNG            as RATING_EXTERNAL,                                -- EXTRNL_RTNG
           SPOT.EXTRNL_RTNG_PRVS       as RATING_EXTERNAL_LAST_YEAR,                      -- EXTRNL_RTNG_PRVS
           SPOT.FLG_BNKRPTCY_IN_GRP    as HAS_BANKRUPTCY_IN_GROUP,                        -- FLG_BNKRPTCY_IN_GRP
           NULL                        as FLG_HGH_CDS,                                    -- FLG_HGH_CDS
           NULL                        as HAS_ISDA_CREDIT_EVENT,                          -- FLG_ISDA_CRDT_EVNT
           SPOT.FLG_NN_ACCRL           as HAS_NON_ACCRUAL_STATUS,                         -- FLG_NN_ACCRL
           NULL                        as HAS_REQUESTED_BANKRUPTCY,                       -- FLG_RQST_BNKRPTCY
           SPOT.FLG_RQST_DSTRSSD_RSTRCTRNG as HAS_REQUESTED_CONCESSION,                   -- FLG_RQST_DSTRSSD_RSTRCTRNG
           NULL                        as HAS_REQUESTED_EMERGENCY_FUNDING,                -- FLG_RQST_EMRGNCY_FNDNG
           NULL                        as HAS_SOLD_WITH_LOSS,                             -- FLG_SLL_WTH_LSS
           NULL                        as INCOME_SELF_CERTIFIED,                          -- INCM_SC
           SPOT.INTRNL_RTNG            as RATING_INTERNAL,                                -- INTRNL_RTNG
           SPOT.INTRNL_RTNG_PRVS       as RATING_INTERNAL_LAST_YEAR,                      -- INTRNL_RTNG_PRVS
           ABACUS.LGL_PRCDNG_STTS_LE   as LEGAL_PROCEEDINGS_STATUS,                       -- LGL_PRCDNG_STTS_LE
           SPOT.OWND_BY_SPNSR          as OWNED_BY_SPONSOR,                               -- OWND_BY_SPNSR
           ABACUS_CALC.PRFRMNG_STTS_LE as PERFORMANCE_STATUS,                             -- PRFRMNG_STTS_LE
           SPOT.RTNG_MTHD              as RATING_METHOD,                                  -- RTNG_MTHD
           EF.RTNG_SCL                 as RATING_SCALE,                                   -- RTNG_SCL
           SPOT.WTCH_LST               as IS_ON_WATCH_LIST,                               -- WTCH_LST
           NULL                        as DEBTOR_SPV_TYPE,                                -- SNGL_PRPS_VHCL
           -- Financial Information
           EGF.GRP_EBITDA              as EBITDA_GROUP,                                   -- GRP_EBITDA
           EGF.GRP_EQTY                as EQUITY_GROUP,                                   -- GRP_EQTY
           EGF.GRP_NT_DBT              as NET_DEBT_GROUP,                                 -- GRP_NT_DBT
           NVL(EGF.ANNL_TRNVR_LE,ABACUS.ANNL_TRNVR_LE) as ANNUAL_TURNOVER,                -- ANNL_TRNVR_LE
           EGF.ANNL_TRNVR_PRVS         as ANNUAL_TURNOVER_PREVIOUS,                       -- ANNL_TRNVR_PRVS
           EGF.CAPEX                   as CAPITAL_EXPENDITURES,                           -- CAPEX
           EGF.CAPEX_PRVS              as CAPITAL_EXPENDITURES_PREVIOUS,                  -- CAPEX_PRVS
           NULL                        as COLLECTION_MODE,                                -- CLLCTN_MD
           EGF.CSH                     as CASH,                                           -- CSH
           EGF.CSH_PRVS                as CASH_PREVIOUS,                                  -- CSH_PRVS
           EGF.EBITDA                  as EBITDA,                                         -- EBITDA
           EGF.EBITDA_PRVS             as EBITDA_PREVIOUS,                                -- EBITDA_PREVIOUS
           EGF.EQTY                    as EQUITY,                                         -- EQTY
           EGF.EQTY_PRVS               as EQUITY_PREVIOUS,                                -- EQTY_PRVS
           EF.GRP_TTL_DBT              as DEBT_GROUP_TOTAL,                               -- GRP_TTL_DBT
           EGF.GDWILL                  as GOODWILL,                                       -- GDWILL
           EGF.GDWILL_PRVS             as GOODWILL_PREVIOUS,                              -- GDWILL_PRVS
           EF.LTI                      as LOAN_TO_INCOME,                                 -- LTI
           EGF.LVRG                    as LEVERAGE,                                       -- LVRG
           EGF.LVRG_PRVS               as LEVERAGE_PREVIOUS,                              -- LVRG_PRVS
           NULL                        as INCOME_OTHER_MONTHLY,                           -- MNTHL_INCM
           SPOT.MNTHL_INCM_SLR         as INCOME_SALARY_MONTHLY,                          -- MNTHL_INCM_SLR
           EGF.MNTHL_TRNVR             as TURNOVER_MONTHLY,                               -- MNTHL_TRNVR
           EGF.NT_INCM                 as NET_INCOME,                                     -- NT_INCM
           EGF.NT_INCM_PRVS            as NET_INCOME_PREVIOUS,                            -- NT_INCM_PRVS
           EF.TTL_DBT                  as DEBT_TOTAL,                                     -- TTL_DBT
           NULL                        as DEBT_TOTAL_PREVIOUS,                            -- TTL_DBT_PRVS
           EGF.TTL_INTRST_PD           as INTEREST_PAID_TOTAL,                            -- TTL_INTRST_PD
           SPOT.TTL_LVRG_RT            as LEVERAGE_RATIO_TOTAL,                           -- TTL_LVRG_RT
           SPOT.TTL_LVRG_RT_PRVS       as LEVERAGE_RATIO_TOTAL_PREVIOUS,                  -- TTL_LVRG_RT_PRVS
           -- Indicators
           NULL                        as DEBT_REPAYMENT_CAPACITY_SENIOR,                 -- DBT_RPYMNT_CPCTY_SNR_DBT
           NULL                        as DEBT_REPAYMENT_CAPACITY_TOTAL,                  -- DBT_RPYMNT_CPCTY_TTL
           EGF.DBT_SRVC_RT             as DEBT_SERVICE_COVERING_RATIO,                    -- DBT_SRVC_RT
           EGF.DBT_SRVC_RT_12M         as DEBT_SERVICE_COVERING_RATIO_PREVIOUS,           -- DBT_SRVC_RT_12M
           NVL2(SPOT.PD_CRR_RD,SPOT.PD_CRR_RD,ABACUS.PD_CRR_RD*100) as PROBABILITY_OF_DEFAULT_CRR,       -- PD_CRR_RD
           EF.PD_IFRS9_12M_RD          as PROBABILITY_OF_DEFAULT_IFRS9,                   -- PD_IFRS9_12M_RD
           NULL                        as PROBABILITY_OF_DEFAULT_IFRS9_LAST_YEAR         -- PD_IFRS9_12M_RD_T1
           --TIP.TYP_INSTRMNT            as TYP_INSTRMNT                                 -- TYP_INSTRMNT fuer NULL RULES
    from PORTFOLIO
    left join ENTITY_FINISH EF on (PORTFOLIO.CLIENT_NO, PORTFOLIO.CUT_OFF_DATE) =
                            (EF.ENTITY_ID, EF.CUT_OFF_DATE)
    left join CALC.SWITCH_CLIENT_EBIL_GLOBAL_FORMAT_CURRENT as EGF
                            on (PORTFOLIO.CLIENT_ID, PORTFOLIO.CUT_OFF_DATE) =
                            (EGF.CLIENT_ID, EGF.CUT_OFF_DATE)
    left join CALC.SWITCH_CLIENT_SPOT_LOAN_CURRENT as SPOT on (PORTFOLIO.CLIENT_NO, PORTFOLIO.CUT_OFF_DATE) = (SPOT.ENTITY_ID, SPOT.CUT_OFF_DATE)
    left join CALC.SWITCH_CLIENT_ABACUS_CURRENT as ABACUS on (PORTFOLIO.CLIENT_NO, PORTFOLIO.CUT_OFF_DATE) = (ABACUS.CLIENT_NO, ABACUS.CUT_OFF_DATE)
    left join STTS_ENTITY_PRE as ABACUS_CALC on (PORTFOLIO.CLIENT_NO, PORTFOLIO.CUT_OFF_DATE) = (ABACUS_CALC.ENTITY_ID, ABACUS_CALC.CUT_OFF_DATE)
    left join ENTITY_BW_ENTRPRS_SZ as BW_ENTRPRS_SZ on (PORTFOLIO.CLIENT_NO, PORTFOLIO.CUT_OFF_DATE) = (BW_ENTRPRS_SZ.CLIENT_NO, BW_ENTRPRS_SZ.CUT_OFF_DATE)
)
select DATE(CUT_OFF_DATE)                                                         as CUT_OFF_DATE,
       CLIENT_ID,
       BIGINT(CLIENT_NO)                                                          as CLIENT_NO,
       nullif(cast(OSI_ID as VARCHAR(255)), null)                                 as OSI_ID,
       cast(nullif(COUNTRY_ALPHA2, null) as VARCHAR(3))                           as COUNTRY_ALPHA2,
       DATE(nullif(BIRTH_DATE, null))                                             as BIRTH_DATE,
       nullif(cast(DEFAULT_STATUS_DATE as date), null)                            as DEFAULT_STATUS_DATE,
       nullif(cast(FINANCIAL_STATEMENTS_DATE as date), null)                      as FINANCIAL_STATEMENTS_DATE,
       nullif(cast(FINANCIAL_STATEMENTS_DATE_LAST_YEAR as date), null)            as FINANCIAL_STATEMENTS_DATE_LAST_YEAR,
       nullif(cast(LEGAL_PROCEEDINGS_COUNTERPARTY_INITIATION_DATE as date), null) as LEGAL_PROCEEDINGS_COUNTERPARTY_INITIATION_DATE,
       nullif(cast(PERFORMING_STATUS_DATE as date), null)                         as PERFORMING_STATUS_DATE,
       nullif(cast(PARENT_ENTITY_ID as VARCHAR(255)), null)                       as PARENT_ENTITY_ID,
       nullif(cast(PARENT_ENTITY_NAME as VARCHAR(255)), null)                     as PARENT_ENTITY_NAME,
       nullif(cast(SEGMENT as VARCHAR(255)), null)                                as SEGMENT_CODE,
       nullif(cast(UNIT_CODE as VARCHAR(255)), null)                              as UNIT_CODE,
       nullif(cast(LEGAL_ID as VARCHAR(20)), null)                                as LEGAL_ID,
       nullif(cast(NAME as VARCHAR(255)), null)                                   as NAME,
       nullif(cast(RATING_AGENCY_NAME as VARCHAR(255)), null)                     as RATING_AGENCY_NAME,
       nullif(cast(ACCOUNTING_FRAMEWORK as BIGINT), null)                        as ACCOUNTING_FRAMEWORK,
       nullif(cast(CURE_FLAG as boolean), null)                                   as CURE_FLAG,
       nullif(cast(IS_DECEASED as boolean), null)                                 as IS_DECEASED,
       nullif(cast(DEFAULT_STATUS as BIGINT), null)                              as DEFAULT_STATUS,
       nullif(cast(RATING_EXTERNAL_DATE as date), null)                           as RATING_EXTERNAL_DATE,
       nullif(cast(RATING_INTERNAL_DATE as date), null)                           as RATING_INTERNAL_DATE,
       nullif(cast(NACE_CODE as VARCHAR(8)), null)                                as NACE_CODE,
       nullif(cast(EMPLOYMENT_STATUS_INTERNAL as VARCHAR(255)), null)             as EMPLOYMENT_STATUS_INTERNAL,
       nullif(cast(EMPLOYMENT_STATUS as BIGINT), null)                           as EMPLOYMENT_STATUS,
       nullif(cast(ENTERPRISE_SIZE as BIGINT), null)                             as ENTERPRISE_SIZE,
       nullif(cast(RATING_EXTERNAL as BIGINT), null)                             as RATING_EXTERNAL,
       nullif(cast(RATING_EXTERNAL_LAST_YEAR as BIGINT), null)                   as RATING_EXTERNAL_LAST_YEAR,
       nullif(cast(HAS_BANKRUPTCY_IN_GROUP as boolean), null)                     as HAS_BANKRUPTCY_IN_GROUP,
       nullif(cast(FLG_HGH_CDS as boolean), null)                                 as FLG_HGH_CDS,
       nullif(cast(HAS_ISDA_CREDIT_EVENT as boolean), null)                       as HAS_ISDA_CREDIT_EVENT,
       nullif(cast(HAS_NON_ACCRUAL_STATUS as boolean), null)                      as HAS_NON_ACCRUAL_STATUS,
       nullif(cast(HAS_REQUESTED_BANKRUPTCY as boolean), null)                    as HAS_REQUESTED_BANKRUPTCY,
       nullif(cast(HAS_REQUESTED_CONCESSION as boolean), null)                    as HAS_REQUESTED_CONCESSION,
       nullif(cast(HAS_REQUESTED_EMERGENCY_FUNDING as boolean), null)             as HAS_REQUESTED_EMERGENCY_FUNDING,
       nullif(cast(HAS_SOLD_WITH_LOSS as boolean), null)                          as HAS_SOLD_WITH_LOSS,
       nullif(cast(INCOME_SELF_CERTIFIED as boolean), null)                       as INCOME_SELF_CERTIFIED,
       nullif(cast(RATING_INTERNAL as VARCHAR(4)), null)                          as RATING_INTERNAL,
       nullif(cast(RATING_INTERNAL_LAST_YEAR as VARCHAR(4)), null)                as RATING_INTERNAL_LAST_YEAR,
       nullif(cast(LEGAL_PROCEEDINGS_STATUS as BIGINT), null)                    as LEGAL_PROCEEDINGS_STATUS,
       nullif(cast(OWNED_BY_SPONSOR as boolean), null)                            as OWNED_BY_SPONSOR,
       nullif(cast(PERFORMANCE_STATUS as BIGINT), null)                          as PERFORMANCE_STATUS,
       nullif(cast(RATING_METHOD as VARCHAR(4)), null)                            as RATING_METHOD,
       nullif(cast(RATING_SCALE as BIGINT), null)                                as RATING_SCALE,
       nullif(cast(IS_ON_WATCH_LIST as boolean), null)                            as IS_ON_WATCH_LIST,
       nullif(cast(DEBTOR_SPV_TYPE as BIGINT), null)                             as DEBTOR_SPV_TYPE,
       nullif(cast(EBITDA_GROUP as double), null)                                 as EBITDA_GROUP,
       nullif(cast(EQUITY_GROUP as double), null)                                 as EQUITY_GROUP,
       nullif(cast(NET_DEBT_GROUP as double), null)                               as NET_DEBT_GROUP,
       nullif(cast(ANNUAL_TURNOVER as double), null)                              as ANNUAL_TURNOVER,
       nullif(cast(ANNUAL_TURNOVER_PREVIOUS as double), null)                     as ANNUAL_TURNOVER_PREVIOUS,
       nullif(cast(CAPITAL_EXPENDITURES as double), null)                         as CAPITAL_EXPENDITURES,
       nullif(cast(CAPITAL_EXPENDITURES_PREVIOUS as double), null)                as CAPITAL_EXPENDITURES_PREVIOUS,
       nullif(cast(COLLECTION_MODE as BIGINT), null)                             as COLLECTION_MODE,
       nullif(cast(CASH as double), null)                                         as CASH,
       nullif(cast(CASH_PREVIOUS as double), null)                                as CASH_PREVIOUS,
       nullif(cast(EBITDA as double), null)                                       as EBITDA,
       nullif(cast(EBITDA_PREVIOUS as double), null)                              as EBITDA_PREVIOUS,
       nullif(cast(EQUITY as double), null)                                       as EQUITY,
       nullif(cast(EQUITY_PREVIOUS as double), null)                              as EQUITY_PREVIOUS,
       nullif(cast(DEBT_GROUP_TOTAL as double), null)                             as DEBT_GROUP_TOTAL,
       nullif(cast(GOODWILL as double), null)                                     as GOODWILL,
       nullif(cast(GOODWILL_PREVIOUS as double), null)                            as GOODWILL_PREVIOUS,
       nullif(cast(LOAN_TO_INCOME as double), null)                               as LOAN_TO_INCOME,
       nullif(cast(LEVERAGE as double), null)                                     as LEVERAGE,
       nullif(cast(LEVERAGE_PREVIOUS as double), null)                            as LEVERAGE_PREVIOUS,
       nullif(cast(INCOME_OTHER_MONTHLY as double), null)                         as INCOME_OTHER_MONTHLY,
       nullif(cast(INCOME_SALARY_MONTHLY as double), null)                        as INCOME_SALARY_MONTHLY,
       nullif(cast(TURNOVER_MONTHLY as double), null)                             as TURNOVER_MONTHLY,
       nullif(cast(NET_INCOME as double), null)                                   as NET_INCOME,
       nullif(cast(NET_INCOME_PREVIOUS as double), null)                          as NET_INCOME_PREVIOUS,
       nullif(cast(DEBT_TOTAL as double), null)                                   as DEBT_TOTAL,
       nullif(cast(DEBT_TOTAL_PREVIOUS as double), null)                          as DEBT_TOTAL_PREVIOUS,
       nullif(cast(INTEREST_PAID_TOTAL as double), null)                          as INTEREST_PAID_TOTAL,
       nullif(cast(LEVERAGE_RATIO_TOTAL as double), null)                         as LEVERAGE_RATIO_TOTAL,
       nullif(cast(LEVERAGE_RATIO_TOTAL_PREVIOUS as double), null)                as LEVERAGE_RATIO_TOTAL_PREVIOUS,
       nullif(cast(DEBT_REPAYMENT_CAPACITY_SENIOR as double), null)               as DEBT_REPAYMENT_CAPACITY_SENIOR,
       nullif(cast(DEBT_REPAYMENT_CAPACITY_TOTAL as double), null)                as DEBT_REPAYMENT_CAPACITY_TOTAL,
       nullif(cast(DEBT_SERVICE_COVERING_RATIO as double), null)                  as DEBT_SERVICE_COVERING_RATIO,
       nullif(cast(DEBT_SERVICE_COVERING_RATIO_PREVIOUS as double), null)         as DEBT_SERVICE_COVERING_RATIO_PREVIOUS,
       nullif(cast(PROBABILITY_OF_DEFAULT_CRR as double), null)                   as PROBABILITY_OF_DEFAULT_CRR,
       nullif(cast(PROBABILITY_OF_DEFAULT_IFRS9 as double), null)                 as PROBABILITY_OF_DEFAULT_IFRS9,
       nullif(cast(PROBABILITY_OF_DEFAULT_IFRS9_LAST_YEAR as double), null)       as PROBABILITY_OF_DEFAULT_IFRS9_LAST_YEAR,
      -- nullif(cast(TYP_INSTRMNT as BIGINT), null)                                 as TYP_INSTRMNT,
       USER as CREATED_USER,
       CURRENT_TIMESTAMP as CREATED_TIMESTAMP
from data;
------------------------------------------------------------------------------------------------------------------------

-- CI START FOR ALL TAPES

-- Current-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_CLIENT_ENTITY_CURRENT');
create table AMC.TABLE_CLIENT_ENTITY_CURRENT like CALC.VIEW_CLIENT_ENTITY distribute by hash(CLIENT_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CLIENT_ENTITY_CURRENT_CLIENT_ID on AMC.TABLE_CLIENT_ENTITY_CURRENT (CLIENT_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_CLIENT_ENTITY_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- Archiv-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_CLIENT_ENTITY_ARCHIVE');
create table AMC.TABLE_CLIENT_ENTITY_ARCHIVE like CALC.VIEW_CLIENT_ENTITY distribute by hash(CLIENT_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CLIENT_ENTITY_ARCHIVE_CLIENT_ID on AMC.TABLE_CLIENT_ENTITY_ARCHIVE (CLIENT_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_CLIENT_ENTITY_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCHES erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_CLIENT_ENTITY_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_CLIENT_ENTITY_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

drop view CALC.VIEW_FACILITY_SPOT_LOAN;
create or replace view CALC.VIEW_FACILITY_SPOT_LOAN as
with
INSTRUMENTS_UNION as (
    select CUT_OFF_DATE, SAPFDB_ID from (
        select CUT_OFF_DATE,SAPFDB_ID
        from NLB.SPOT_LOANTAPE_INSTRUMENT_CURRENT
        union all
        select CUT_OFF_DATE,SAPFDB_ID
        from NLB.SPOT_LOANTAPE_CASHFLOW_CURRENT
        union all select CUT_OFF_DATE,SAPFDB_ID
        from NLB.SPOT_LOANTAPE_CLIENT_RATING_INSTRUMENT_CURRENT
    )
),
INSTRUMENTS_UNION_DIST as (
	SELECT *
    FROM ( SELECT INST.*,
                  ROWNUMBER() over (PARTITION BY SAPFDB_ID ORDER BY SAPFDB_ID desc) as RN
           FROM INSTRUMENTS_UNION INST) STATUS
    WHERE RN = 1
),
INSTRUMENTS_MAPPED as (
    select CUT_OFF_DATE,
           SAPFDB_ID,
           case when substr(SAPFDB_ID,5,4) = '-33-' or substr(SAPFDB_ID,5,4) = '-30-' then
                left(SAPFDB_ID,8) || Replace(Replace(Right(SAPFDB_ID,Length(SAPFDB_ID)-8),'-30-','-31-'),'-20-','-21-')
           else SAPFDB_ID
           end as MAPPED_ID
    from INSTRUMENTS_UNION_DIST
),
INSTRUMENTS_ALL as (
	SELECT *
    FROM ( SELECT INST.*, MAPPED_ID as INSTRMNT_ID,
                  ROWNUMBER() over (PARTITION BY MAPPED_ID ORDER BY SAPFDB_ID) as RN
           FROM INSTRUMENTS_MAPPED INST) STATUS
    WHERE RN = 1
),
LTI_MAPPED as (
    select LTI.*,
           IM.MAPPED_ID,
           case when LTI.SAPFDB_ID <> IM.MAPPED_ID then 1 else 0 end as CHANGED
    from INSTRUMENTS_MAPPED as IM
    inner join NLB.SPOT_LOANTAPE_INSTRUMENT_CURRENT as LTI
        on (LTI.CUT_OFF_DATE,LTI.SAPFDB_ID) = (IM.CUT_OFF_DATE,IM.SAPFDB_ID)
),
LTC_MAPPED as (
    select LTC.*,
           IM.MAPPED_ID,
           case when LTC.SAPFDB_ID <> IM.MAPPED_ID then 1 else 0 end as CHANGED
    from INSTRUMENTS_MAPPED as IM
    inner join NLB.SPOT_LOANTAPE_CASHFLOW_CURRENT as LTC
        on (LTC.CUT_OFF_DATE,LTC.SAPFDB_ID) = (IM.CUT_OFF_DATE,IM.SAPFDB_ID)
),
LTCRI_MAPPED as (
    select LTCRI.*,
           IM.MAPPED_ID,
           case when LTCRI.SAPFDB_ID <> IM.MAPPED_ID then 1 else 0 end as CHANGED
    from INSTRUMENTS_MAPPED as IM
    inner join NLB.SPOT_LOANTAPE_CLIENT_RATING_INSTRUMENT_CURRENT as LTCRI
        on (LTCRI.CUT_OFF_DATE,LTCRI.SAPFDB_ID) = (IM.CUT_OFF_DATE,IM.SAPFDB_ID)
),
--ALLE PROTECTIONS nehmen oder nur COLLATERALS??
P2P_PRE as (
         select CUT_OFF_DATE,
                POSITION_ID1 as FACILITY_ID,
                POSITION_ID2 as COLLATERAL_ID
         from NLB.ABACUS_POSITION_TO_POSITION_CURRENT
         where POSITION_ID2 like '0009-10%'
),
TYP_MRTGG_FACILITY as (
    select P2P.CUT_OFF_DATE,
           P2P.FACILITY_ID,
           MIN(IMT.ECB_CODE) as TMCODEMAPPED
    from P2P_PRE as P2P
    inner join NLB.SPOT_LOANTAPE_PROTECTION_CURRENT as LTP on (P2P.CUT_OFF_DATE, P2P.COLLATERAL_ID) = (LTP.CUT_OFF_DATE,LTP.SAPFDB_ID)
    inner join SMAP.ECB_INSTRUMENT_MORTGAGE_TYPE as IMT on LTP.TYP_MRTGG = IMT.ECB_DESCRIPTION
    group by P2P.CUT_OFF_DATE, P2P.FACILITY_ID
    having MIN(IMT.ECB_CODE)  is not null
),
INSTRUMENTS_PRE as (
    select INSTRUMENTS_ALL.CUT_OFF_DATE,
           INSTRUMENTS_ALL.INSTRMNT_ID,
           LTC.RCVD_AMRTSTN_12M,
           LTC.RCVD_INTRST_12M,
           LTC.RCVD_AMRTSTN_24M,
           LTC.RCVD_INTRST_24M,
           LTCRI.DT_INTRNL_RTNG,
           NVL(SAP.SAP_RATING_E,LTCRI.INTRNL_RTNG) as INTRNL_RTNG,
           LTCRI.INTRNL_RTNG_PRVS,
           LTCRI.INTRNL_RTNG_INCPTN,
           NVL(SAP.SAP_RATINGMODUL,RTM.NO) as RTNG_MTHD,
           LTI.ARRRS_INSTRMNT_12M,
           LTI.DT_FRBRNC_STTS,
           LTI.DT_FRBRNC_STTS_PRVS,
           NVL2(LTI.DT_ORGNL_MTRTY, LTI.DT_ORGNL_MTRTY, null) as DT_ORGNL_MTRTY,
           LTI.DT_PRFRMNG_STTS,
           case when LTI.FBE_STUFE = 0 then 8 else FSTTS.ECB_CODE end as FRBRNC_STTS_INSTRMNT,
           LTI.INSTLMNT_PAY,
           LTI.NMBR_FRBRNC_MSRS,
           LTI.PD_CRR_RD,
           LTI.PD_CRR_RD_T1,
           case when LTI.POCI = 'Y' then true
                when LTI.POCI = 'N' then false end as POCI,
           LTI.PRDCT,
           case when LTCRI.INTRNL_RTNG is null then
               case when SAP.SAP_RATING_E >=25 and SAP.SAP_RATING_E <=27 then 1
                    when SAP.SAP_RATING_E <25 then 11
               end
           else NVL2(LTI.FBE_STUFE,case when LTI.FBE_STUFE = 4 or LTI.FBE_STUFE = 5 then 1 else 11 end, null) end as PRFRMNG_STTS,
           case when LTI.PYMNT_INTRST_ONLY = 'Y' then true
                when LTI.PYMNT_INTRST_ONLY = 'N' then false end as PYMNT_INTRST_ONLY,
           case when LTI.FORB_AKT_MASSNAHME = 200 then true else false end as RFNNC_PRPS,
           NVL2(RTM2.TYPE,case when RTM2.TYPE = 'IRBA' then 1
                when RTM2.TYPE = 'KSA' then 2 end,LTI.RWA_MTHD) as RWA_MTHD,
           LTI.SICR_ASSSSMNT_MTHD,
           LTI.SYNDCTD_AGNT,
           LTI.SYNDCTD_LNDRS,
           LTI.FORB_AKT_MASSNAHME,
           TMF.TMCODEMAPPED as TYP_MRTGG
    from INSTRUMENTS_ALL
    inner join CALC.SWITCH_PORTFOLIO_CURRENT as P on
    (INSTRUMENTS_ALL.CUT_OFF_DATE,INSTRUMENTS_ALL.INSTRMNT_ID) = (P.CUT_OFF_DATE, P.FACILITY_ID)
	left join LTI_MAPPED as LTI on (INSTRUMENTS_ALL.CUT_OFF_DATE,INSTRUMENTS_ALL.INSTRMNT_ID) = (LTI.CUT_OFF_DATE,LTI.MAPPED_ID)
    left join LTC_MAPPED as LTC on (INSTRUMENTS_ALL.CUT_OFF_DATE,INSTRUMENTS_ALL.INSTRMNT_ID) = (LTC.CUT_OFF_DATE,LTC.MAPPED_ID)
    left join LTCRI_MAPPED as LTCRI on (INSTRUMENTS_ALL.CUT_OFF_DATE,INSTRUMENTS_ALL.INSTRMNT_ID) = (LTCRI.CUT_OFF_DATE,LTCRI.MAPPED_ID)
    left join CALC.SWITCH_FACILITY_BW_P80_AOER_CURRENT as SAP on (INSTRUMENTS_ALL.CUT_OFF_DATE,INSTRUMENTS_ALL.INSTRMNT_ID) = (SAP.CUT_OFF_DATE, SAP.FACILITY_ID)
    left join SMAP.RATING_MODULES RTM on RTM.DESCRIPTION = LTCRI.RTNG_MTHD
    left join SMAP.RATING_MODULES RTM2 on RTM2.NO = SAP.SAP_RATINGMODUL
    left join SMAP.ECB_INSTRUMENT_FORBEARANCE_STATUS FSTTS on LTI.FORB_AKT_MASSNAHME = FSTTS.NLB_VALUE
    left join TYP_MRTGG_FACILITY TMF on INSTRUMENTS_ALL.INSTRMNT_ID = TMF.FACILITY_ID
),
INSTRUMENTS_DUP as (
    select *
    from (select IF.*,
                 rownumber() over (partition by IF.INSTRMNT_ID order by IF.INSTRMNT_ID,IF.RTNG_MTHD desc nulls last) as RN
          from INSTRUMENTS_PRE as IF
         )
    where RN = 1
)
select CUT_OFF_DATE,
       INSTRMNT_ID,
       RCVD_AMRTSTN_12M,
       RCVD_INTRST_12M,
       RCVD_AMRTSTN_24M,
       RCVD_INTRST_24M,
       DT_INTRNL_RTNG,
       INTRNL_RTNG,
       INTRNL_RTNG_PRVS,
       INTRNL_RTNG_INCPTN,
       RTNG_MTHD,
       ARRRS_INSTRMNT_12M,
       DT_FRBRNC_STTS,
       DT_FRBRNC_STTS_PRVS,
       DT_ORGNL_MTRTY,
       DT_PRFRMNG_STTS,
       FRBRNC_STTS_INSTRMNT,
       INSTLMNT_PAY,
       NMBR_FRBRNC_MSRS,
       PD_CRR_RD,
       PD_CRR_RD_T1,
       POCI,
       PRDCT,
       PRFRMNG_STTS,
       PYMNT_INTRST_ONLY,
       RFNNC_PRPS,
       RWA_MTHD,
       SICR_ASSSSMNT_MTHD,
       SYNDCTD_AGNT,
       SYNDCTD_LNDRS,
       FORB_AKT_MASSNAHME,
       TYP_MRTGG,
       CURRENT_USER as USER,
       CURRENT_TIMESTAMP as TIMESTAMP_LOAD
from INSTRUMENTS_DUP;

-- CI START FOR ALL TAPES
-- Current-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_FACILITY_SPOT_LOAN_CURRENT');
create table AMC.TABLE_FACILITY_SPOT_LOAN_CURRENT like CALC.VIEW_FACILITY_SPOT_LOAN distribute by hash(INSTRMNT_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_TABLE_FACILITY_SPOT_LOAN_CURRENT_INSTRMNT_ID on AMC.TABLE_FACILITY_SPOT_LOAN_CURRENT (INSTRMNT_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_FACILITY_SPOT_LOAN_CURRENT');

-- CI END FOR ALL TAPES

-- SWITCHES erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_FACILITY_SPOT_LOAN_CURRENT');


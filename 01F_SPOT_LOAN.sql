--SPOT LOANTAPE DATA for ECB Dictionary
drop view CALC.VIEW_CLIENT_SPOT_LOAN;
create or replace view CALC.VIEW_CLIENT_SPOT_LOAN as
with PORTFOLIO as (
    select * from CALC.SWITCH_PORTFOLIO_CURRENT
),
INSTRUMENT_CLIENT_PREP as (
  select P.CUT_OFF_DATE,
         FI.INSTRMNT_ID,
         P.CLIENT_NO,
         NVL2(FI.FORB_AKT_MASSNAHME,1,0) as FORB_FLAG,
         FC.KUNDENBETREUER_OE_BEZEICHNUNG as UNIT,
         NVL2(FI.FORB_AKT_MASSNAHME,case when FI.FORB_AKT_MASSNAHME = 1 then 1 when FI.FORB_AKT_MASSNAHME > 99 then 0 end,null) as CR_FLAG,
         FI.DT_PRFRMNG_STTS as DT_PRFRMNG_STTS,
         case when FI.DT_FRBRNC_STTS > P.CUT_OFF_DATE then 1 else 0 end as FLAG_FUTURE_FRB,
         SAP.SAP_EAD*FI.PD_CRR_RD as EADTIMESPD,
         NVL2(FI.PD_CRR_RD,SAP.SAP_EAD,0) as EAD,
         FI.DT_INTRNL_RTNG,
         FI.INTRNL_RTNG,
         FI.INTRNL_RTNG_PRVS,
         FI.RTNG_MTHD
  from CALC.SWITCH_FACILITY_SPOT_LOAN_CURRENT as FI
  left join CALC.SWITCH_FACILITY_CORE_CURRENT as FC on (FC.CUT_OFF_DATE,FC.FACILITY_ID) = (FI.CUT_OFF_DATE,FI.INSTRMNT_ID)
  left join PORTFOLIO as P on (P.CUT_OFF_DATE,P.FACILITY_ID) = (FI.CUT_OFF_DATE,FI.INSTRMNT_ID)
  left join CALC.SWITCH_FACILITY_BW_P80_AOER_CURRENT as SAP on (FI.CUT_OFF_DATE,FI.INSTRMNT_ID) = (SAP.CUT_OFF_DATE,SAP.FACILITY_ID)
  where P.CLIENT_NO is not null
),
INSTRUMENT_CLIENT_GRP_PRE as (
  select ICP.CLIENT_NO,
         sum(ICP.FORB_FLAG) as SUM_FORB_FLAG,
         max(ICP.UNIT) as INTRNL_UNT, -- max statt first evtl. anpassen
         sum(ICP.CR_FLAG) as SUM_CR_FLAG,
         max(ICP.DT_PRFRMNG_STTS) as DT_PRFRMNG_STTS,
         sum(ICP.FLAG_FUTURE_FRB) as SUM_FLAG_FUTURE_FRB,
         sum(ICP.EAD) as SUM_EAD,
         sum(ICP.EADTIMESPD) as SUM_EADTIMESPD,
         max(ICP.DT_INTRNL_RTNG) as DT_INTRNL_RTNG,
         max(ICP.INTRNL_RTNG) as INTRNL_RTNG,
         max(ICP.INTRNL_RTNG_PRVS) as INTRNL_RTNG_PRVS,
         max(ICP.RTNG_MTHD) as RTNG_MTHD -- max statt first evtl. anpassen
  from INSTRUMENT_CLIENT_PREP as ICP
  group by ICP.CLIENT_NO
),
INSTRUMENT_CLIENT_GRP as (
  select ICG_PRE.*,
         NVL2(ICG_PRE.SUM_FORB_FLAG,case when ICG_PRE.SUM_FORB_FLAG > 0 then true else false end,null) as FLG_NN_ACCRL,
         NVL2(ICG_PRE.SUM_CR_FLAG,case when ICG_PRE.SUM_CR_FLAG > 0 then true else false end,null) as CR_FLG,
         NVL2(ICG_PRE.SUM_FLAG_FUTURE_FRB,case when ICG_PRE.SUM_FLAG_FUTURE_FRB > 0 then true else false end,null) as FLG_RQST_DSTRSSD_RSTRCTRNG,
         case when ICG_PRE.SUM_EAD = 0 then null else ICG_PRE.SUM_EADTIMESPD/ICG_PRE.SUM_EAD end as PD_CRR_RD
  from INSTRUMENT_CLIENT_GRP_PRE as ICG_PRE
),
CLIENT_GVK_PRE as (
    select LTCGVK.*,
           NVL2(LTCGVK.FLG_BNKRPTCY_IN_GRP,case when LTCGVK.FLG_BNKRPTCY_IN_GRP = 'Y' then 1 else 0 end,null) as NUM_FLAG
    from NLB.SPOT_LOANTAPE_CLIENT_GVK_CURRENT as LTCGVK
),
CLIENT_GVK_GRP as (
    select SAPFDB_ID,
           NVL2(sum(NUM_FLAG),case when sum(NUM_FLAG)>0 then true else false end,null) as FLG_BNKRPTCY_IN_GRP,
           max(GCC_PRNT_ID) as GCC_PRNT_ID, --max statt first
           max(GCC_PRNT_NM) as GCC_PRNT_NM --max statt first
    from CLIENT_GVK_PRE
    group by SAPFDB_ID
),
LTC_GP_PRE as (
    select LTC.*,
           LTRIM(GP_NR,'0') as GP_NR_TRIMED
    from NLB.SPOT_LOANTAPE_CLIENT_CURRENT as LTC
    inner join PORTFOLIO as P on (P.CUT_OFF_DATE, P.CLIENT_NO) = (LTC.CUT_OFF_DATE,LTC.GP_NR)
),
SPOT_ENTITY as (
    select LTC.CUT_OFF_DATE,
           LTC.GP_NR_TRIMED as ENTITY_ID,
           CGG.FLG_BNKRPTCY_IN_GRP,
           ICG.FLG_NN_ACCRL,
           CGG.GCC_PRNT_ID,
           CGG.GCC_PRNT_NM,
           ICG.INTRNL_UNT,
           LTC.MNTHL_INCM_SLR,
           LTC.WTCH_LST,
           LTCR.DT_EXTRNL_RTNG,
           LTCR.EXTRNL_RTNG,
           LTCR.EXTRNL_RTNG_PRVS,
           LTCR.EXTRNL_RTNG_NM,
           ICG.DT_INTRNL_RTNG,
           ICG.INTRNL_RTNG,
           ICG.INTRNL_RTNG_PRVS,
           ICG.RTNG_MTHD,
           ICG.CR_FLG,
           ICG.DT_PRFRMNG_STTS as DT_PRFRMNG_STTS_LE,
           ICG.FLG_RQST_DSTRSSD_RSTRCTRNG,
           ICG.PD_CRR_RD,
           NVL2(LTC.OWND_BY_SPNSR,true,false) as OWND_BY_SPNSR,
           LTC.TTL_LVRG_RT,
           LTC.TTL_LVRG_RT_PRVS
    from LTC_GP_PRE as LTC
    left join CLIENT_GVK_GRP as CGG on LTC.SAPFDB_ID = CGG.SAPFDB_ID
    left join INSTRUMENT_CLIENT_GRP as ICG on LTC.GP_NR_TRIMED = ICG.CLIENT_NO
    left join NLB.SPOT_LOANTAPE_CLIENT_RATING_CURRENT as LTCR on
        (LTCR.CUT_OFF_DATE, LTCR.SAPFDB_ID) = (LTC.CUT_OFF_DATE, LTC.SAPFDB_ID)
),
SPOT_ENTITY_DIST as (
    select *
    from (select SE.*,
                 rownumber() over (partition by SE.ENTITY_ID order by SE.MNTHL_INCM_SLR, SE.DT_INTRNL_RTNG,SE.DT_EXTRNL_RTNG desc nulls last) as RN
          from SPOT_ENTITY as SE
         )
    where RN = 1
)
select distinct CUT_OFF_DATE, ENTITY_ID, FLG_BNKRPTCY_IN_GRP, FLG_NN_ACCRL, GCC_PRNT_ID, GCC_PRNT_NM, INTRNL_UNT, MNTHL_INCM_SLR, WTCH_LST, DT_EXTRNL_RTNG, EXTRNL_RTNG, EXTRNL_RTNG_PRVS, EXTRNL_RTNG_NM, DT_INTRNL_RTNG, INTRNL_RTNG, INTRNL_RTNG_PRVS, RTNG_MTHD, CR_FLG, DT_PRFRMNG_STTS_LE, FLG_RQST_DSTRSSD_RSTRCTRNG, PD_CRR_RD, OWND_BY_SPNSR, TTL_LVRG_RT, TTL_LVRG_RT_PRVS,
                CURRENT_USER as USER,
                CURRENT_TIMESTAMP as TIMESTAMP_LOAD
from SPOT_ENTITY_DIST;

-- CI START FOR ALL TAPES

-- Current-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_CLIENT_SPOT_LOAN_CURRENT');
create table AMC.TABLE_CLIENT_SPOT_LOAN_CURRENT like CALC.VIEW_CLIENT_SPOT_LOAN distribute by hash(ENTITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CLIENT_SPOT_LOAN_CURRENT_KUNDENNR on AMC.TABLE_CLIENT_SPOT_LOAN_CURRENT (ENTITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_CLIENT_SPOT_LOAN_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCHES erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_CLIENT_SPOT_LOAN_CURRENT');
------------------------------------------------------------------------------------------------------------------------


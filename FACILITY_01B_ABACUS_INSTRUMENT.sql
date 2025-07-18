-- View erstellen
drop view CALC.VIEW_FACILITY_ABACUS_INSTRUMENT;
create or replace view CALC.VIEW_FACILITY_ABACUS_INSTRUMENT as
with
ABACUS_KONTEN_GG as (
    select * from CALC.SWITCH_FACILITY_ABACUS_KONTEN_GG_CURRENT
),
ABACUS_INSTRUMENT_POSITION as (
    select AK.CUT_OFF_DATE,
           case when NVL(AP.IDN202, IC.IDN302) is null or length(NVL(AP.IDN202, IC.IDN302))<= 10 then AK.FACILITY_ID
                else NVL(AP.IDN202, IC.IDN302) end as INSTRUMENT_ID_HIST,
           IC.INSTRUMENT_ID,
           IC.B270,
           IC.C207,
           IC.COL124,
           EIC.ECB_CODE as CUR007,
           IC.D518,
           IC.IDN302,
           IC.IDN356,
           IC.INS102,
           EIR.ECB_CODE as INS103,
           IAT.ECB_CODE as INS104,
           IPFL.ECB_CODE as INS106,
           IIRT.ECB_CODE as INT204,
           IRRF.ECB_CODE as MAT103,
           IPF.ECB_CODE as MAT105,
           IC.MAT506,
           IC.PARTNER_ID30 as INST_PARTNER_ID30,
           IP.ECB_CODE as PRD151,
           IC.Z006,
           IC.Z015,
           IC.PER256,
           IC.C208,
           IC.INT067,
           AP.POSITION_ID,
           AP.B020,
           AP.CRE101,
           AP.CRE102,
           AP.CRE103,
           IIS.ECB_CODE as CRI111,
           IAC.ECB_CODE as ACC111,
           case when AP.CRI112 like '(1)%' then 2
                when AP.CRI112 like '(2)%' then 1 end as CRI112,
           AP.B436,
           AP.C223,
           AP.COL120,
           AP.COL123,
           AP.COL214,
           AP.CRI116,
           EDS.ECB_CODE as CRI160,
           AP.CRI103,
           IIPS.ECB_CODE as CRI113,
           IFS.ECB_CODE as CRI114,
           AP.CRI115,
           AP.IDN202,
           AP.CRI159,
           AP.D554,
           AP.IDN203,
           AP.M012,
           AP.MAT106,
           AP.MAT126,
           AP.PARTNER_ID30 as POS_PARTNER_ID30,
           AP.VAD014,
           AP.VAD015,
           AP.VAD279,
           AP.VAL006,
           AP.VAL010,
           AP.VAL125,
           AP.VAL230,
           AP.COL001,
           AP.LTV001,
           AP.LTV002,
           AP.M002,
           CLIENT_INFO.LGL_PRCDNG_STTS_LE,
           CLIENT_INFO.PD_CRR_RD
    from ABACUS_KONTEN_GG AK
    left join NLB.ABACUS_INSTRUMENT_CURRENT as IC on (AK.CUT_OFF_DATE, AK.FACILITY_ID) = (IC.CUT_OFF_DATE, IC.INSTRUMENT_ID)
    left join NLB.ABACUS_POSITION_CURRENT as AP on (AK.CUT_OFF_DATE, AK.FACILITY_ID) = (AP.CUT_OFF_DATE, AP.POSITION_ID)
    left join CALC.SWITCH_CLIENT_ABACUS_CURRENT as CLIENT_INFO on (AK.CUT_OFF_DATE, AK.CLIENT_NO) = (CLIENT_INFO.CUT_OFF_DATE, CLIENT_INFO.CLIENT_NO)
    left join SMAP.ECB_INSTRUMENT_RECOURSE EIR on EIR.NLB_VALUE = (trim(regexp_replace(substr(IC.INS103,1,locate_in_string(IC.INS103,')')),'[()]','')))
    left join SMAP.ECB_INSTRUMENT_AMORTISATION_TYPE as IAT on IAT.NLB_VALUE = trim(regexp_replace(substr(IC.INS104,1,locate_in_string(IC.INS104,')')),'[()]',''))
    left join SMAP.ECB_INSTRUMENT_PROJECT_FINANCE_LOAN as IPFL on IPFL.NLB_VALUE = trim(regexp_replace(substr(IC.INS106,1,locate_in_string(IC.INS106,')')),'[()]',''))
    left join SMAP.ECB_INSTRUMENT_INTEREST_RATE_TYPE as IIRT on IIRT.NLB_VALUE = trim(regexp_replace(substr(IC.INT204,1,locate_in_string(IC.INT204,')')),'[()]',''))
    left join SMAP.ECB_INSTRUMENT_INTEREST_RATE_RESET_FREQUENCY as IRRF on IRRF.NLB_VALUE = trim(regexp_replace(substr(IC.MAT103,1,locate_in_string(IC.MAT103,')')),'[()]',''))
    left join SMAP.ECB_INSTRUMENT_PAYMENT_FREQUENCY as IPF on IPF.NLB_VALUE = trim(regexp_replace(substr(IC.MAT105,1,locate_in_string(IC.MAT105,')')),'[()]',''))
    left join SMAP.ECB_INSTRUMENT_PURPOSE as IP on IP.NLB_VALUE = trim(regexp_replace(substr(IC.PRD151,1,locate_in_string(IC.PRD151,')')),'[()]',''))
    left join SMAP.ECB_INSTRUMENT_IMPAIRMENT_STATUS as IIS on IIS.NLB_VALUE = trim(regexp_replace(substr(AP.CRI111,1,locate_in_string(AP.CRI111,')')),'[()]',''))
    left join SMAP.ECB_INSTRUMENT_ACCOUNTING_CLASSIFICATION as IAC on IAC.NLB_VALUE = trim(regexp_replace(substr(AP.ACC111,1,locate_in_string(AP.ACC111,')')),'[()]',''))
    left join SMAP.ECB_ENTITY_DEFAULT_STATUS as EDS on EDS.NLB_VALUE = trim(regexp_replace(substr(AP.CRI160,1,locate_in_string(AP.CRI160,')')),'[()]',''))
    left join SMAP.ECB_INSTRUMENT_PERFORMING_STATUS as IIPS on IIPS.NLB_VALUE = trim(regexp_replace(substr(AP.CRI113,1,locate_in_string(AP.CRI113,')')),'[()]',''))
    left join SMAP.ECB_INSTRUMENT_FORBEARANCE_STATUS as IFS on IFS.NLB_VALUE = trim(regexp_replace(substr(AP.CRI114,1,locate_in_string(AP.CRI114,')')),'[()]',''))
    left join SMAP.ECB_INSTRUMENT_CURRENCY as EIC on EIC.NLB_VALUE = trim(regexp_replace(substr(IC.CUR007,1,locate_in_string(IC.CUR007,')')),'[()]',''))
    where IC.INSTRUMENT_ID is not null and AP.POSITION_ID is not null
    and AK.FACILITY_ID NOT LIKE '%-33-%22-0000%'
    and AK.FACILITY_ID NOT LIKE '%-33-%20-0000%'
    and AK.FACILITY_ID NOT LIKE '%-33-%32-0000%'
    and AK.FACILITY_ID NOT LIKE '%-33-%30-0000%'
    and AK.FACILITY_ID NOT LIKE '%-30-%30-0000%'
),
-- POSITION_PREV Duplikate entfernen
POSITION_PREV as (
    select NVL(IDN202,POSITION_ID) as ID,
           max(VAD015) as VAD015,
           max(VAL010) as VAL010,
           max(VAL230) as VAL230
    from NLB.ABACUS_POSITION_PREV_CURRENT
    group by NVL(IDN202,POSITION_ID)
),
-- TODO: FACILITY INACTIVE?
INSTRUMENT_MAPPINGS as (
    select AIP.CUT_OFF_DATE,
           AIP.INSTRUMENT_ID,
           AIP.INSTRUMENT_ID as CNTRCT_ID,
           AIP.CUR007 as CRRNCY_DNMNTN,
           AIP.MAT106 as DT_INCPTN,
           AIP.CRI160 as DFLT_STTS_INSTRMNT,
           case when AIP.CRI160 = 14 then AIP.MAT106 else AIP.B436 end as DT_DFLT_STTS_INSTRMNT,
           AIP.B436 as DT_FAILURE,
           AIP.MAT506 as DT_END_INTRST_ONLY,
           AIP.CRI115 as DT_FRBRNC_STTS,
           AIP.CRI116 as DT_PRFRMNG_STTS,
           AIP.CRI114 as FRBRNC_STTS_INSTRMNT,
           AIP.CRI113 as PRFRMNG_STTS,
           AIP.PRD151 as PRPS,
           AIP.INS103 as RCRS,
           AIP.INS104 as TYP_AMRTSTN,
           AIP.INS106 as PRJCT_FNNC_LN,
           AIP.INT204 as TYP_INTRST_RT,
           AIP.ACC111 as ACCNTNG_CLSSFCTN,
           AIP.C223 as ACCRD_INTRST_INSTRMNT,
           AIP.D554 as CMMNTMNT_INCPTN_INSTRMNT,
           AIP.M012 as CRRYNG_AMNT_INSTRMNT,
           AIP.C207 as DT_LGL_FNL_MTRTY,
           AIP.D518 as DT_NXT_INTRST_RT_RST,
           AIP.VAL230 as OFF_BLNC_SHT_AMNT_INSTRMNT,
           AIP.VAL010 as OTSTNDNG_NMNL_AMNT_INSTRMNT,
           --PRODUCTTYPE_DETAIL
           AIP.VAD014 as PRVS_OFF_BLNC_SHT,
           AIP.MAT105 as PYMNT_FRQNCY,
           AIP.VAD015 as ACCMLTD_IMPRMNT_INSTRMNT,
           AIP.VAD279 as ACCMLTD_WRTFFS_INSTRMNT,
           NVL(AIP.CRE101,0) + NVL(AIP.CRE102,0) + NVL(AIP.CRE103,0) as ARRRS_INSTRMNT,
           AIP.VAL006 as CMLTV_RCVRS_SNC_DFLT_INTRMNT,
           AIP.CRI103 as DT_PST_D,
           AIP.Z006 as ANNLSD_AGRD_RT,
           AIP.MAT103 as INTRST_RT_RST_FRQNCY,
           AIP.IDN356 as SYNDCTD_CNTRCT_ID,
           AIP.CRI112 as IMPRMNT_ASSSSMNT_MTHD,
           AIP.CRI111 as IMPRMNT_STTS,
           --CLIENT_INFO
           AIP.LGL_PRCDNG_STTS_LE,
           AIP.PD_CRR_RD,
           PP.VAL010 as OTSTNDNG_NMNL_AMNT_INSTRMNT_PRVS,
           PP.VAL230 as OFF_BLNC_SHT_AMNT_INSTRMNT_PRVS,
           PP.VAD015 as ACCMLTD_IMPRMNT_INSTRMNT_PRVS
    from ABACUS_INSTRUMENT_POSITION as AIP
    left join POSITION_PREV as PP on AIP.INSTRUMENT_ID_HIST = PP.ID
)
select distinct *,
                CURRENT_USER as USER,
                CURRENT_TIMESTAMP as TIMESTAMP_LOAD
from INSTRUMENT_MAPPINGS;

-- CI START FOR ALL TAPES
-- Current-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_FACILITY_ABACUS_INSTRUMENT_CURRENT');
create table AMC.TABLE_FACILITY_ABACUS_INSTRUMENT_CURRENT like CALC.VIEW_FACILITY_ABACUS_INSTRUMENT distribute by hash(INSTRUMENT_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_TABLE_FACILITY_ABACUS_INSTRUMENT_CURRENT_FACILITY_ID on AMC.TABLE_FACILITY_ABACUS_INSTRUMENT_CURRENT (INSTRUMENT_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_FACILITY_ABACUS_INSTRUMENT_CURRENT');

-- CI END FOR ALL TAPES

-- SWITCH View erstellen
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_FACILITY_ABACUS_INSTRUMENT_CURRENT');



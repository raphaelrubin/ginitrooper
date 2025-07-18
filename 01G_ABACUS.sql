drop view CALC.VIEW_CLIENT_ABACUS;
create or replace view CALC.VIEW_CLIENT_ABACUS as
with PORTFOLIO_ABACUS as (
     select * from CALC.SWITCH_FACILITY_ABACUS_KONTEN_GG_CURRENT
),
TMP_ENTITY as (
    select Partner.*, S.SAP_KUNDE, S.CLIENT_NO
    from NLB.ABACUS_PARTNER_CURRENT as PARTNER
    inner join (select distinct P2I.PARTNER_ID1 as KUNDEN_ID, ASK.SAP_KUNDE, ASK.CLIENT_NO from NLB.ABACUS_PARTNER_TO_INSTRUMENT_CURRENT P2I
                inner join PORTFOLIO_ABACUS ASK ON (P2I.CUT_OFF_DATE, P2I.INSTRUMENT_ID1) = (ASK.CUT_OFF_DATE,ASK.FACILITY_ID)
                WHERE P2I.TYP350='(10) Kontrahent')  AS S
    ON PARTNER.PARTNER_ID = S.KUNDEN_ID
),
ENTITY_FINISH as (
    select distinct TMP.CUT_OFF_DATE,
           PRI188 as DT_INTTN_LGL_PRCDNGS_LE,
           B935 as LEI,
           P011 || ' ' || P021 as ENTTY_NM,
           EDS.ECB_CODE as DFL_STTS,
           ENC.ECB_CODE as ECNMC_ACTVTY,
           EES.ECB_CODE as ENTRPRS_SZ_LE,
           ILPS.ECB_CODE as LGL_PRCDNG_STTS_LE,
           VAL044 as ANNL_TRNVR_LE,
           ECA.ECB_CODE as CNTRY,
           POA015 as DT_BRTH,
           B020 as PD_CRR_RD,
           B436 as DT_FAILURE,
           TMP.SAP_KUNDE,
           TMP.CLIENT_NO
    from TMP_ENTITY TMP
    left join SMAP.ECB_ENTITY_NACE_CODE as ENC on ENC.NLB_VALUE = trim(regexp_replace(substr(SIE200,1,locate_in_string(SIE200,')')),'[()]',''))
    left join SMAP.ECB_INSTRUMENT_LEGAL_PROCEEDINGS_STATUS as ILPS on ILPS.NLB_VALUE = trim(regexp_replace(substr(PRI187,1,locate_in_string(PRI187,')')),'[()]',''))
    left join SMAP.ECB_ENTITY_COUNTRY_ALPHA2 as ECA on ECA.NLB_VALUE = trim(regexp_replace(substr(CTY010,1,locate_in_string(CTY010,')')),'[()]',''))
    left join SMAP.ECB_ENTITY_DEFAULT_STATUS as EDS on EDS.NLB_VALUE = trim(regexp_replace(substr(CRI160,1,locate_in_string(CRI160,')')),'[()]',''))
    left join SMAP.ECB_ENTITY_ENTERPRISE_SIZE as EES on EES.NLB_VALUE = trim(regexp_replace(substr(LCI047,1,locate_in_string(LCI047,')')),'[()]',''))
)
SELECT distinct *,
                CURRENT_USER as USER,
                CURRENT_TIMESTAMP as TIMESTAMP_LOAD
FROM ENTITY_FINISH;

-- CI START FOR ALL TAPES

-- Current-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_CLIENT_ABACUS_CURRENT');
create table AMC.TABLE_CLIENT_ABACUS_CURRENT like CALC.VIEW_CLIENT_ABACUS distribute by hash(CLIENT_NO) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CLIENT_ABACUS_CURRENT_CLIENT_ID_ORIG on AMC.TABLE_CLIENT_ABACUS_CURRENT (CLIENT_NO);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_CLIENT_ABACUS_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCHES erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_CLIENT_ABACUS_CURRENT');
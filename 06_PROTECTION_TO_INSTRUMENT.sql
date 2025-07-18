------------------------------
-- PROTECTION TO INSTRUMENT --
------------------------------
-- Modellierung für EZB-Dictionary

drop view CALC.VIEW_COLLATERALIZATION_PROTECTION_TO_INSTRUMENT;
create or replace view CALC.VIEW_COLLATERALIZATION_PROTECTION_TO_INSTRUMENT as
    with CURRENT_CUTOFFDATE as (
            select CUT_OFF_DATE
            from CALC.AUTO_TABLE_CUTOFFDATES
            where IS_ACTIVE
    ),
    C2_Facility_Abacus as (
         select C2FA.CUT_OFF_DATE,
                C2FA.FACILITY_ID,
                C2FA.SOURCE,
                C2FA.COLLATERAL_ID,
                C2FA.SAP_KUNDE
         from CALC.SWITCH_COLLATERAL_TO_FACILITY_ABACUS_CURRENT as C2FA
            inner join CURRENT_CUTOFFDATE as COD on COD.CUT_OFF_DATE = C2FA.CUT_OFF_DATE
     ),
     C2_Client_Abacus as (
         select C2CA.CUT_OFF_DATE,
                P.FACILITY_ID,
                SOURCE,
                C2CA.COLLATERAL_ID,
                C2CA.SAP_KUNDE
         from CALC.SWITCH_COLLATERAL_TO_CLIENT_ABACUS_CURRENT as C2CA
                  left join CALC.SWITCH_PORTFOLIO_INSTRUMENT_TO_ENTITY_CURRENT as P on P.CLIENT_NO = C2CA.CLIENT_NO
                  inner join CURRENT_CUTOFFDATE as COD on COD.CUT_OFF_DATE = C2CA.CUT_OFF_DATE
         -- fehler ezb, erstmal nicht implementiert wegen prio eba
         -- collaterals von client nur an facility mappen wenn collateral kein eigenes facility mapping hat
         -- where not exists(select 1 from C2_Facility_Abacus where COLLATERAL_ID = C2CA.COLLATERAL_ID)
     ),
     Union_Collaterals as (
         select *
         from C2_Facility_Abacus
         union all
         select * from C2_Client_Abacus
     ),
     Union_Collaterals_dist as (
         select CUT_OFF_DATE,FACILITY_ID,COLLATERAL_ID, SAP_KUNDE, SOURCE from
         ( select *,
                  ROWNUMBER() over (PARTITION BY FACILITY_ID, COLLATERAL_ID order by COLLATERAL_ID desc nulls last) as RN
           from Union_Collaterals
         ) where RN = 1
     ),
     A2C as (
         select CUT_OFF_DATE, COLLATERAL_ID, ASSET_ID, L003, SOURCE from CALC.SWITCH_ASSET_TO_COLLATERAL_ABACUS_CURRENT
     ),
     P2I_PRE as (
         select UC.CUT_OFF_DATE,
                UC.FACILITY_ID,
                A2C.L003,
                case when A2C.ASSET_ID is null then UC.COLLATERAL_ID -- Standalone COLL
                     else ASSET_ID
                end as PROTECTION_ID,
                case when A2C.ASSET_ID is NULL then 'COLLATERAL' else 'ASSET' end as TYPE,
                UC.SAP_KUNDE
         from Union_Collaterals_dist UC
         left join A2C
               on (A2C.COLLATERAL_ID = UC.COLLATERAL_ID) and
                 (UC.SOURCE = A2C.SOURCE)
    ),
    --N FACILITY zu N Protections distinct machen
    P2I as (
        select CUT_OFF_DATE,FACILITY_ID,L003,PROTECTION_ID,TYPE,SAP_KUNDE from (
                      select *,
                             ROWNUMBER() over ( PARTITION BY PROTECTION_ID,FACILITY_ID ORDER BY PROTECTION_ID desc nulls last) as RN
                      from P2I_PRE
        ) where RN =1
    ),
    TMP_DM_INSTR_PRTCN as (
         select distinct
         DIP.L003,
         DIP.B615,
         DIP.IDN203,
         AO.OBJECT_ID as PRTCTN_ID,
         AP.POSITION_ID as INSTRM_ID
         from NLB.ABACUS_DM_AC_INSTRMNT_PRTCTN_CURRENT as DIP
         left join NLB.ABACUS_OBJECT_CURRENT AO
             on (AO.CUT_OFF_DATE, AO.IDN203) = (DIP.CUT_OFF_DATE,DIP.IDN203)
         left join NLB.ABACUS_POSITION_CURRENT AP
             on (AP.CUT_OFF_DATE,AP.IDN202) = (DIP.CUT_OFF_DATE,DIP.IDN202)
     ),
     AGG_data as (
         select distinct
         P2I.CUT_OFF_DATE,
         P2I.FACILITY_ID,
         P2I.PROTECTION_ID,
         P2I.TYPE,
         P2I.SAP_KUNDE,
         NVL(DIP.L003, P2I.L003) as THIRD_PARTY_PRIORITY_CLAIMS,
         NVL(DIP.B615, JNT.CRI120) as PRTCTN_ALLCTD_VL
         from P2I
         left join TMP_DM_INSTR_PRTCN as DIP
            on (P2I.PROTECTION_ID, P2I.FACILITY_ID) = (DIP.PRTCTN_ID, DIP.INSTRM_ID)
         left join NLB.ABACUS_DM_AC_JNT_LBLTS_CURRENT JNT on (JNT.CUT_OFF_DATE, JNT.IDN202) = (P2I.CUT_OFF_DATE, P2I.FACILITY_ID)
     ),
     --- SPOT
     FACILITY_SAP as (
                 select CUT_OFF_DATE,
                        FACILITY_ID,
                        SAP_INANSPRUCHNAHME
                 from CALC.SWITCH_FACILITY_BW_P80_AOER_CURRENT
     ),
     FACILITY_CORE as (
                 select F.CUT_OFF_DATE,
                        F.FACILITY_ID,
                        PRICIPAL_OST_EUR_BW
                 from CALC.SWITCH_FACILITY_CORE_CURRENT as F
     ),
     INANSPRUCHNAME as (
          select FC.FACILITY_ID,
                 max(coalesce(FS.SAP_INANSPRUCHNAHME,
                         FC.PRICIPAL_OST_EUR_BW),0) as INSPNA
          from FACILITY_SAP as FS
          left join FACILITY_CORE FC on (FS.CUT_OFF_DATE, FS.FACILITY_ID) = (FC.CUT_OFF_DATE, FC.FACILITY_ID)
     ),
     P2P_PRE as (
         select CUT_OFF_DATE,
                POSITION_ID1 as FACILITY_ID,
                POSITION_ID2 as COLLATERAL_ID
         from NLB.ABACUS_POSITION_TO_POSITION_CURRENT
         where POSITION_ID2 like '0009-10%'
     ),
     INSTRMT_PRTCTN_DATA as (
         select LTI.SAPFDB_ID as INSTRMT_ID,
                LTP.SAPFDB_ID as PRTCTN_ID,
                max(LTP.PRTCTN_ALLCTD_VL) as PRTCTN_ALLCTD_VL,
                max(case when I.INSPNA < 0 then 0 else I.INSPNA end) as INSPNA
         from P2P_PRE P2P
                inner join NLB.SPOT_LOANTAPE_INSTRUMENT_CURRENT LTI
                on (P2P.CUT_OFF_DATE,P2P.FACILITY_ID) = (LTI.CUT_OFF_DATE,LTI.SAPFDB_ID)
                inner join NLB.SPOT_LOANTAPE_PROTECTION_CURRENT LTP on
                (P2P.CUT_OFF_DATE,P2P.COLLATERAL_ID) = (LTP.CUT_OFF_DATE,LTP.SAPFDB_ID)
                inner join INANSPRUCHNAME as I on I.FACILITY_ID = P2P.FACILITY_ID
         group by LTI.SAPFDB_ID, LTP.SAPFDB_ID
     ),
     INANSPRUCHNAME_SUM as (
         select IPD.PRTCTN_ID,
                sum(INSPNA) as INSPNA_SUM
         from INSTRMT_PRTCTN_DATA as IPD
         group by IPD.PRTCTN_ID
     ),
     INSTRMT_PROTECTION_SPOT as (
         select IPD.INSTRMT_ID,
                IPD.PRTCTN_ID,
                case when ISUM.INSPNA_SUM > 0 then
                    case when IPD.PRTCTN_ALLCTD_VL * IPD.INSPNA / ISUM.INSPNA_SUM > IPD.INSPNA then ROUND(INSPNA,2)
                    else ROUND(IPD.PRTCTN_ALLCTD_VL * IPD.INSPNA / ISUM.INSPNA_SUM,2) end
                else 0 end as PRTCTN_ALLCTD_VL
         from INSTRMT_PRTCTN_DATA as IPD
         left join INANSPRUCHNAME_SUM as ISUM on IPD.PRTCTN_ID = ISUM.PRTCTN_ID
     ),
     IWHS_COLL_PRE as (
         select C2F.FACILITY_ID,
                SM.SAPFDB_ID,
                C2F.MAX_RISK_VERT_JE_GW,
                C2F.DATA_SOURCE
         from CALC.SWITCH_COLLATERAL_TO_FACILITY_CURRENT C2F
         inner join NLB.SPOT_LOANTAPE_PROTECTION_ASSET_CURRENT as SM
         on (C2F.CUT_OFF_DATE,C2F.COLLATERAL_ID) = (SM.CUT_OFF_DATE,SM.SIRE_ID)
         where DATA_SOURCE = 'IWHS'
     ),
     CMS_COLL_PRE as (
         select C2F.FACILITY_ID,
                SM.SAPFDB_ID,
                C2F.MAX_RISK_VERT_JE_GW,
                C2F.DATA_SOURCE
         from CALC.SWITCH_COLLATERAL_TO_FACILITY_CURRENT C2F
         inner join NLB.SPOT_LOANTAPE_PROTECTION_ASSET_CURRENT as SM
         on (C2F.CUT_OFF_DATE,C2F.COLLATERAL_ID) = (SM.CUT_OFF_DATE,SM.CMS_ID)
         where DATA_SOURCE like '%CMS%'
     ),
     UNION_CMS_IWHS as (
         select distinct FACILITY_ID,SAPFDB_ID as COLLATERAL_ID, MAX_RISK_VERT_JE_GW as MAX_RISK_VERT, DATA_SOURCE as SOURCE from (
             select distinct FACILITY_ID,SAPFDB_ID, MAX_RISK_VERT_JE_GW, DATA_SOURCE from IWHS_COLL_PRE
             union all
             select distinct FACILITY_ID,SAPFDB_ID, MAX_RISK_VERT_JE_GW, DATA_SOURCE from CMS_COLL_PRE
         )
     ),
     data as (
         select AGG.CUT_OFF_DATE  as CUT_OFF_DATE,       --DT_RFRNC,
                AGG.FACILITY_ID   as FACILITY_ID,        --INSTRMNT_ID,
                AGG.PROTECTION_ID as PROTECTION_ID,      --PRTCTN_ID,
                AGG.TYPE,
                --AGG.SOURCE,
                AGG.SAP_KUNDE,
                AGG.PRTCTN_ALLCTD_VL as PRTCTN_ALLCTD_VL,  --PRTCTN_ALLCTD_VL, // ONLY ABACUS 06.05.24
                AGG.THIRD_PARTY_PRIORITY_CLAIMS as THIRD_PARTY_PRIORITY_CLAIMS, --THRD_PRTY_PRRTY_CLMS, // ABACUS.POSITION_TO_OBJECT.L003
                -- OPTIONAL
                null              as ADD_NMRC1,
                null              as ADD_NMRC2,
                null              as ADD_DT1,
                null              as ADD_TXT1,
                null              as ADD_TXT2
         from AGG_data AGG
         inner join NLB.SPOT_LOANTAPE_PROTECTION_ASSET_CURRENT SMS
             on (SMS.CUT_OFF_DATE,SMS.SAPFDB_ID) = (AGG.CUT_OFF_DATE,left(AGG.PROTECTION_ID,34))
         left join INSTRMT_PROTECTION_SPOT IPS
            on (AGG.FACILITY_ID) = (IPS.INSTRMT_ID)
         left join UNION_CMS_IWHS as CMS_IWHS on (AGG.FACILITY_ID) = (CMS_IWHS.FACILITY_ID)
    ),
    unique_data as (
         select CUT_OFF_DATE,
                FACILITY_ID,
                PROTECTION_ID,
                TYPE,
                max(SAP_KUNDE)                   as SAP_KUNDE,
                max(PRTCTN_ALLCTD_VL)            as PRTCTN_ALLCTD_VL,
                max(THIRD_PARTY_PRIORITY_CLAIMS) as THIRD_PARTY_PRIORITY_CLAIMS,
                null                             as ADD_NMRC1,
                null                             as ADD_NMRC2,
                null                             as ADD_DT1,
                null                             as ADD_TXT1,
                null                             as ADD_TXT2
            from data
            group by CUT_OFF_DATE,
                FACILITY_ID,
                PROTECTION_ID,
                TYPE,
                ADD_NMRC1,
                ADD_NMRC2,
                ADD_DT1,
                ADD_TXT1,
                ADD_TXT2
    )
select
   -- GENERAL
    cast(CUT_OFF_DATE as DATE)                                  as CUT_OFF_DATE,                --DT_RFRNC,
    cast(FACILITY_ID as VARCHAR(60))                            as FACILITY_ID,                 --INSTRMNT_ID,
    cast(PROTECTION_ID as VARCHAR(60))                          as PROTECTION_ID,               --PRTCTN_ID,
    cast(TYPE as VARCHAR(16))                                   as TYPE,
    cast(SAP_KUNDE as VARCHAR(20))                              as SAP_KUNDE,
    -- FINANCIAL INFORMATION
    nullif(cast(PRTCTN_ALLCTD_VL as DOUBLE), null)              as PROTECTION_ALLOCATED_VALUE,  --PRTCTN_ALLCTD_VL,
    nullif(cast(THIRD_PARTY_PRIORITY_CLAIMS as DOUBLE), null)   as THIRD_PARTY_PRIORITY_CLAIMS, --THRD_PRTY_PRRTY_CLMS,
    -- OPTIONAL
    nullif(cast(ADD_NMRC1 as DOUBLE), null)                     as ADD_NMRC1,
    nullif(cast(ADD_NMRC2 as DOUBLE), null)                     as ADD_NMRC2,
    nullif(cast(ADD_DT1 as DATE), null)                         as ADD_DT1,
    cast(ADD_TXT1 as VARCHAR(255))                              as ADD_TXT1,
    cast(ADD_TXT2 as VARCHAR(255))                              as ADD_TXT2,
    USER                                                        as CREATED_USER,
    CURRENT_TIMESTAMP                                           as CREATED_TIMESTAMP
from unique_data;
------------------------------------------------------------------------------------------------------------------------


-- CI START FOR ALL TAPES

-- Current-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_COLLATERALIZATION_PROTECTION_TO_INSTRUMENT_CURRENT');
create table AMC.TABLE_COLLATERALIZATION_PROTECTION_TO_INSTRUMENT_CURRENT like CALC.VIEW_COLLATERALIZATION_PROTECTION_TO_INSTRUMENT distribute by hash(FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_COLLATERALIZATION_PROTECTION_TO_INSTRUMENT_CURRENT_FACILITY_ID on AMC.TABLE_COLLATERALIZATION_PROTECTION_TO_INSTRUMENT_CURRENT (FACILITY_ID);
create index AMC.INDEX_COLLATERALIZATION_PROTECTION_TO_INSTRUMENT_CURRENT_PROTECTION_ID on AMC.TABLE_COLLATERALIZATION_PROTECTION_TO_INSTRUMENT_CURRENT (PROTECTION_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_COLLATERALIZATION_PROTECTION_TO_INSTRUMENT_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- Archiv-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_COLLATERALIZATION_PROTECTION_TO_INSTRUMENT_ARCHIVE');
create table AMC.TABLE_COLLATERALIZATION_PROTECTION_TO_INSTRUMENT_ARCHIVE like CALC.VIEW_COLLATERALIZATION_PROTECTION_TO_INSTRUMENT distribute by hash(FACILITY_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_COLLATERALIZATION_PROTECTION_TO_INSTRUMENT_ARCHIVE_FACILITY_ID on AMC.TABLE_COLLATERALIZATION_PROTECTION_TO_INSTRUMENT_ARCHIVE (FACILITY_ID);
create index AMC.INDEX_COLLATERALIZATION_PROTECTION_TO_INSTRUMENT_ARCHIVE_PROTECTION_ID on AMC.TABLE_COLLATERALIZATION_PROTECTION_TO_INSTRUMENT_ARCHIVE (PROTECTION_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_COLLATERALIZATION_PROTECTION_TO_INSTRUMENT_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCHES erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_COLLATERALIZATION_PROTECTION_TO_INSTRUMENT_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_COLLATERALIZATION_PROTECTION_TO_INSTRUMENT_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------
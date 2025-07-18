-- View erstellen
drop view CALC.VIEW_BW_KENNZAHLEN;
create or replace view CALC.VIEW_BW_KENNZAHLEN as
with ANL_PASSIV_BWKOMP as (
         select distinct ZM_CPICID,
                SUM(coalesce(CS_TRN_LC,0)/KURS) as BW_KOMP_PASSIV_LC,
                SUM(coalesce(CS_TRN_TC,0)) as BW_KOMP_PASSIV_TC
         from ANL.BW_ZBC_IFRS_CURRENT as ANL
         left join IMAP.CURRENCY_MAP as CURR  on ANL.CURKEY_LC=CURR.ZIEL_WHRG and ANL.CUTOFFDATE=CURR.CUT_OFF_DATE
            where ZM_CPICID is not null
            and left(ZM_CPICID,20) <> left(ZM_PRODID,20)
            and ZM_KFSEM in ('_KORELT')
            and left(CS_ITEM,1) = '2'
         group by ZM_CPICID
),ROHDATEN as (
    select * from CALC.SWITCH_NLB_IFRS_CURRENT
        union all
    select * from CALC.SWITCH_BLB_IFRS_CURRENT
        union all
    select --falsche BW_KOMPENSATION für ANL Syndizierte GEschäfte mit dem künstlichen ZM_KFSEM 'B_BWKOMP'
            PCOMPANY, BRANCH, COMPANY, ZM_BPKIND, ZM_BRANCH, ZM_CNTRY, ZM_FRKTYP, ZM_KLAS, ZM_KONSE, ZM_KUSTOE, ZM_KUSY, ZM_KUSY20, ZM_SEKGRP, ZM_AOCURR, ZM_EANLB, ZM_PRKEY, CO_AREA, ZM_EKFK, ZM_INARTN,
            ZM_IPOFLG, ZM_LOWCRA, ZM_EMBDKZ, ZM_PORTF, ZM_PORTID, ZM_CLSRGI, ZM_CRLENO, ZM_IMP09, ZM_BPKU, ZM_DSIKR, CS_CHART, CS_ITEM, CHRT_ACCTS, ZM_INTRAN, ZM_RLSTD, ZM_CONTY, ZM_HA_KA9,
            ZM_HEDCAT, ZM_EXTCON, ZM_PRODID, ANL.ZM_CPICID, 'B_BWKOMP', ZM_LIDRP, ZM_PRGART, ZM_STAKOR, CUTOFFDATE, CURKEY_LC, CURKEY_TC, UNIT, ZM_LBABUC, ZM_BCMID, ZM_CLACC, ZM_DEPOTK, ZM_ANVETA,
            ZM_NONPRF, ZM_DEALST, ZM_KR_CB, ZM_KR_CH, ZM_BUSMOD, ZM_FINST, ZM_FTRAN,
            coalesce(BW_KOMP_PASSIV_LC,CS_TRN_LC) as CS_TRN_LC,
            coalesce(BW_KOMP_PASSIV_TC,CS_TRN_TC) as CS_TRN_TC,
            QUANTITY, ZK_BWKUR5, ZK_FVKUR, ZK_ZAEHL, SOURSYSTEM, ZM_EXTNR, user_last_run_amc_ll, timestamp_last_run
    from CALC.SWITCH_ANL_IFRS_CURRENT as ANL
    inner join ANL_PASSIV_BWKOMP as BWKOMP on BWKOMP.ZM_CPICID=ZM_PRODID and ZM_KFSEM='A_BWKOMP'
    union all
    select
            PCOMPANY, BRANCH, COMPANY, ZM_BPKIND, ZM_BRANCH, ZM_CNTRY, ZM_FRKTYP, ZM_KLAS, ZM_KONSE, ZM_KUSTOE, ZM_KUSY, ZM_KUSY20, ZM_SEKGRP, ZM_AOCURR, ZM_EANLB, ZM_PRKEY, CO_AREA, ZM_EKFK, ZM_INARTN,
            ZM_IPOFLG, ZM_LOWCRA, ZM_EMBDKZ, ZM_PORTF, ZM_PORTID, ZM_CLSRGI, ZM_CRLENO, ZM_IMP09, ZM_BPKU, ZM_DSIKR, CS_CHART, CS_ITEM, CHRT_ACCTS, ZM_INTRAN, ZM_RLSTD, ZM_CONTY, ZM_HA_KA9,
            ZM_HEDCAT, ZM_EXTCON, ZM_PRODID, ANL.ZM_CPICID, ZM_KFSEM, ZM_LIDRP, ZM_PRGART, ZM_STAKOR, CUTOFFDATE, CURKEY_LC, CURKEY_TC, UNIT, ZM_LBABUC, ZM_BCMID, ZM_CLACC, ZM_DEPOTK, ZM_ANVETA,
            ZM_NONPRF, ZM_DEALST, ZM_KR_CB, ZM_KR_CH, ZM_BUSMOD, ZM_FINST, ZM_FTRAN,
            CS_TRN_LC as CS_TRN_LC,
            CS_TRN_TC as CS_TRN_TC,
            QUANTITY, ZK_BWKUR5, ZK_FVKUR, ZK_ZAEHL, SOURSYSTEM, ZM_EXTNR, user_last_run_amc_ll, timestamp_last_run
    from CALC.SWITCH_ANL_IFRS_CURRENT as ANL
)
,basis as (
    select distinct
           ZM_PRODID as FACILITY_ID
            ,ZM_EXTNR as KUNDENNUMMER
            ,ZM_PRKEY
            ,BRANCH
            ,case when substr(ZM_PRODID,6,2) = '15' then null else ZM_AOCURR end as WAEHRUNG
            ,ZM_ANVETA as DAYSOVERDUE
            ,trim(L '0' from replace(ZM_EXTCON,'CONTRACT_','')) as TRADE_ID
            ,CUTOFFDATE
    from ROHDATEN
)
,MARKETS_PROD_AM as (
    select distinct
           coalesce(ZM_PRODID,'XXXXXXXXXX') as FACILITYID
           ,coalesce(ZM_EXTNR,0) as BORROWERID
            ,SUM(coalesce(CS_TRN_LC,0)) as MARKETS_PRODUKTE_AMOUNT_EUR
            ,SUM(coalesce(CS_TRN_TC,0)) as MARKETS_PRODUKTE_AMOUNT_TC
            ,CUTOFFDATE
    from ROHDATEN
    where ZM_KFSEM='&55AMNOM'
    and substr(ZM_PRODID,6,2)='15' --or left(ZM_PRODID,4)='ISIN'
    and CS_ITEM in ('9011103004','9011104004','9011109004','9021003004','9021004004','9021009004')
    GROUP BY coalesce(ZM_PRODID,'XXXXXXXXXX'),CUTOFFDATE,coalesce(ZM_EXTNR,0)
)
,HALTEKATEGORIE as (
    select distinct
            FACILITYID
           , BORROWERID
            ,case when ZM_HA_KA9='01' then 'AAC'
                    when ZM_HA_KA9='03' then 'FVPL (HfT)'
                    when ZM_HA_KA9='04' then 'FVOCI'
                    when ZM_HA_KA9='06' then 'LAC'
                    when ZM_HA_KA9='07' then 'FVPLD'
                    when ZM_HA_KA9='10' then 'FVPLM'
                    when ZM_HA_KA9='12' then 'FVPLD (OCS OCI)'
                    when ZM_HA_KA9='98' then 'DE Kein FI nur Notes'
                else ZM_HA_KA9
                end     as HALTEKATEGORIE
            ,CUTOFFDATE
    from (
        select distinct A.*, row_number() over (Partition by FACILITYID,BORROWERID order by ZM_STAKOR asc nulls last) as NBR from
             (
                 select distinct coalesce(LL.ZM_PRODID, 'XXXXXXXXXX') as FACILITYID
                               , coalesce(ZM_EXTNR, 0)                as BORROWERID
                               , ZM_HA_KA9
                               , CUTOFFDATE
                               , ZM_STAKOR
                 from ROHDATEN as LL
                 where 1 = 1
                   and ZM_KFSEM in
                       ('_KOTFSR', 'A_KORTIL', 'A_KOSZNL', 'A_KORZNL', '_KORELT', 'A_BWKOMP', '_KOACIN', 'A_KAC100',
                        'A_KAC150', 'A_KAC191', 'A_KAC262', 'A_KAC671', 'A_KAC261')
             ) as A
         )
    where NBR = 1
        )
,OFFBALANCE as (
    select
           coalesce(LL.ZM_PRODID,'XXXXXXXXXX') as FACILITYID
           ,coalesce(ZM_EXTNR,0) as BORROWERID
            ,SUM(coalesce(CS_TRN_LC,0)) as OFFBALANCE_EUR
            ,SUM(coalesce(CS_TRN_TC,0)) as OFFBALANCE_TC
            ,LL.CUTOFFDATE
    from ROHDATEN as LL
    where 1=1
        and ZM_KFSEM in ('A_RKRZEN','A_ROBEN')
        and substr(CS_ITEM, 1, 8) in ('96100005','96200005','96300005')
    GROUP BY coalesce(LL.ZM_PRODID,'XXXXXXXXXX'),LL.CUTOFFDATE,coalesce(ZM_EXTNR,0)
    )
,ACCRUED_INTEREST as (
    select
           coalesce(LL.ZM_PRODID,'XXXXXXXXXX') as FACILITYID
           ,coalesce(ZM_EXTNR,0) as BORROWERID
            ,SUM(coalesce(CS_TRN_LC,0)) as ACCRUED_INTEREST_EUR
            ,SUM(coalesce(CS_TRN_TC,0)) as ACCRUED_INTEREST_TC
            ,LL.CUTOFFDATE
    from ROHDATEN as LL
    where 1=1
        and ZM_KFSEM in ('_KOACIN','A_KAC100','A_KAC150','A_KAC191','A_KAC262','A_KAC671','A_KAC261')
        and (
                LEFT(CS_ITEM,6) IN('112410','114410','115411','115412','112420','114420','115421','115422','111420','181240','181540')
                or LEFT(CS_ITEM,5) in ('21551','21552','21554')
            )
    GROUP BY coalesce(LL.ZM_PRODID,'XXXXXXXXXX'),LL.CUTOFFDATE,coalesce(ZM_EXTNR,0)
    )
,PRICIPAL_OUTSTANDING as (
    select
           coalesce(LL.ZM_PRODID,'XXXXXXXXXX') as FACILITYID
           ,coalesce(ZM_EXTNR,0) as BORROWERID
            ,SUM(coalesce(CS_TRN_LC,0)) as PRINCIPAL_OUTSTANDING_EUR
            ,SUM(coalesce(CS_TRN_TC,0)) as PRINCIPAL_OUTSTANDING_TC
            ,LL.CUTOFFDATE
    from ROHDATEN as LL
    where (ZM_KFSEM = case when SUBSTR(LL.ZM_PRODID, 6, 2) in ('69', '70', '71', '73') then 'B_BWKOMP' else 'A_BWKOMP' end
            or ZM_KFSEM = '_KORELT'
        )
        and (
                LEFT(CS_ITEM,6) IN('112410','114410','115411','115412','112420','114420','115421','115422','111420','181240','181540')
                or LEFT(CS_ITEM,5) in ('21551','21552','21554')
            )
    GROUP BY coalesce(LL.ZM_PRODID,'XXXXXXXXXX'),LL.CUTOFFDATE,coalesce(ZM_EXTNR,0)
)
,FVA as (
    select
           coalesce(LL.ZM_PRODID,'XXXXXXXXXX') as FACILITYID
           ,coalesce(ZM_EXTNR,0) as BORROWERID
            ,SUM(coalesce(CS_TRN_LC,0)) as FVA_EUR
            ,SUM(coalesce(CS_TRN_TC,0)) as FVA_TC
            ,LL.CUTOFFDATE
    from ROHDATEN as LL
    where 1=1
            and ZM_KFSEM in ('A_KAVAFV','A_KAFVVJ','_KAVAFV'  )
            and (
                LEFT(CS_ITEM,6) IN('112410','114410','115411','115412','112420','114420','115421','115422','111420','181240','181540')
                or LEFT(CS_ITEM,5) in ('21551','21552','21554')
            )
    GROUP BY coalesce(LL.ZM_PRODID,'XXXXXXXXXX'),LL.CUTOFFDATE,coalesce(ZM_EXTNR,0)
)
,INT_ARREARS as (
    select
           coalesce(LL.ZM_PRODID,'XXXXXXXXXX') as FACILITYID
           ,coalesce(ZM_EXTNR,0) as BORROWERID
            ,SUM(coalesce(CS_TRN_LC,0)) as INTEREST_IN_ARREARS_EUR
            ,SUM(coalesce(CS_TRN_TC,0)) as INTEREST_IN_ARREARS_TC
            ,LL.CUTOFFDATE
    from ROHDATEN as LL
    where 1=1
            and ZM_KFSEM in ('A_KOSZNL','A_KORZNL' )
            and LEFT(CS_ITEM,6) IN('112410','114410','115411','115412','112420','114420','115421','115422','111420','181240','181540' )

    GROUP BY coalesce(LL.ZM_PRODID,'XXXXXXXXXX'),LL.CUTOFFDATE,coalesce(ZM_EXTNR,0)
)
,AMO_ARREARS as (
    select
           coalesce(LL.ZM_PRODID,'XXXXXXXXXX') as FACILITYID
           ,coalesce(ZM_EXTNR,0) as BORROWERID
            ,SUM(coalesce(CS_TRN_LC,0)) as AMORTIZATION_IN_ARREARS_EUR
            ,SUM(coalesce(CS_TRN_TC,0)) as AMORTIZATION_IN_ARREARS_TC
            ,LL.CUTOFFDATE
    from ROHDATEN as LL
    where 1=1
            and ZM_KFSEM in ('_KOTFSR','A_KORTIL' )
            and LEFT(CS_ITEM,6) IN('112410','114410','115411','115412','112420','114420','115421','115422','111420','181240','181540' )

    GROUP BY coalesce(LL.ZM_PRODID,'XXXXXXXXXX'),LL.CUTOFFDATE,coalesce(ZM_EXTNR,0)
)
,HGB as (
    select
           coalesce(LL.ZM_PRODID,'XXXXXXXXXX') as FACILITYID
           ,coalesce(ZM_EXTNR,0) as BORROWERID
            ,SUM(coalesce(CS_TRN_LC,0)) as HGB_EUR
            ,SUM(coalesce(CS_TRN_TC,0)) as HGB_TC
            ,LL.CUTOFFDATE
    from ROHDATEN as LL
    where 1=1
            and ZM_KFSEM in ('_KOTFSR','A_KORTIL','A_KOSZNL','A_KORZNL','_KORELT','A_BWKOMP', '_KOACIN','A_KAC100','A_KAC150','A_KAC191','A_KAC262','A_KAC671','A_KAC261')
            and (
                LEFT(CS_ITEM,6) IN('112410','114410','115411','115412','112420','114420','115421','115422','111420','181240','181540')
                or LEFT(CS_ITEM,5) in ('21551','21552','21554')
            )
    GROUP BY coalesce(LL.ZM_PRODID,'XXXXXXXXXX'),LL.CUTOFFDATE,coalesce(ZM_EXTNR,0)
),
BILANZTEILE_REIN_AUS_BW as (
    select distinct
        coalesce(LL.ZM_PRODID, 'XXXXXXXXXX') as FACILITYID,
        coalesce(ZM_EXTNR, 0)                as BORROWERID,
        SUM(LL.CS_TRN_LC)                    as Bilanzteile_BW_EUR,
        SUM(LL.CS_TRN_TC)                    as Bilanzteile_BW_TC,
        LL.CUTOFFDATE
    from ROHDATEN as LL
    where 1 = 1
      and (
            LEFT(CS_ITEM, 6) in
            ('112420', '114420', '111420', '181240', '115421', '115422', '181540', '111111', '111131', '161250',
             '211111', '211131')
            or LEFT(CS_ITEM, 5) in ('21551', '21552', '21554')
        )
      and not ZM_KFSEM in
              ('_KOTFSR', 'A_KORTIL', 'A_KOSZNL', 'A_KORZNL', '_KORELT', 'A_BWKOMP', '_KOACIN', 'A_KAC100', 'A_KAC150',
               'A_KAC191', 'A_KAC262', 'A_KAC671', 'A_KAC261')
    GROUP BY coalesce(LL.ZM_PRODID, 'XXXXXXXXXX'), LL.CUTOFFDATE, coalesce(ZM_EXTNR, 0)
),
BILANZWERT_IFRS as (
    select distinct
        coalesce(LL.ZM_PRODID, 'XXXXXXXXXX')                                          as FACILITYID,
        coalesce(ZM_EXTNR, 0)                                                         as BORROWERID,
        SUM(LL.CS_TRN_LC)                                                             as Bilanzwert_IFRS9_EUR,
        case
            when substr(ZM_PRODID, 6, 2) = '15' then null
            else SUM(LL.CS_TRN_TC) end                                                as Bilanzwert_IFRS9_TC,
        LL.CUTOFFDATE
    from ROHDATEN as LL
    where 1 = 1
      and (
            LEFT(CS_ITEM, 6) in
            ('112420', '114420', '111420', '181240', '115421', '115422', '181540', '111111', '111131', '161250',
             '211111', '211131')
            or LEFT(CS_ITEM, 5) in ('21551', '21552', '21554')
        )
      and ZM_KFSEM not in ('B_BWKOMP')
    GROUP BY coalesce(LL.ZM_PRODID, 'XXXXXXXXXX'), LL.CUTOFFDATE, coalesce(ZM_EXTNR, 0), substr(ZM_PRODID, 6, 2)
),
BILANZWERT_BRUTTO as (
    select
       coalesce(LL.ZM_PRODID, 'XXXXXXXXXX')                                          as FACILITYID,
       coalesce(ZM_EXTNR, 0)                                                         as BORROWERID,
       SUM(LL.CS_TRN_LC)                                                             as BILANZWERT_BRUTTO_EUR,
       case when substr(ZM_PRODID, 6, 2) = '15' then null else SUM(LL.CS_TRN_TC) end as BILANZWERT_BRUTTO_TC,
       LL.CUTOFFDATE
    from ROHDATEN as LL
    where 1 = 1
      and (
            LEFT(CS_ITEM, 6) IN
            ('112410', '114410', '115411', '115412', '112420', '114420', '115421', '115422', '111420', '181240',
             '181540')
            or LEFT(CS_ITEM, 5) in ('21551', '21552', '21554')
        )
      and not CS_ITEM IN (
                          '1153291000', '1154119100', '1154229100', '1154219100', --STAGE 1 on
                          '1154129200', '1154229200',--STAGE 2 on
                          '1154219300', '1154229300', --Stage 3 on
                          '1154229400' --POCI
        )
      and ZM_KFSEM not in ('B_BWKOMP', 'A_RIVO')
    GROUP BY coalesce(LL.ZM_PRODID, 'XXXXXXXXXX'), LL.CUTOFFDATE, coalesce(ZM_EXTNR, 0), substr(ZM_PRODID, 6, 2)
),
Manuelle_umgebuchte_RISK_PROVISION as (
    select distinct
        REL_FAC.*
        ,case
            when CS_ITEM in ('1153291000','1154119100','1154229100','1154219100') then '1'
            when CS_ITEM in ('1154129200','1154229200') then '2'
            when CS_ITEM in ('1154219300','1154229300') then '3'
            when CS_ITEM in ('1154229400') then 'POCI'
        end as STAGE
    from ROHDATEN as LL
    inner join (
        select
            coalesce(LL.ZM_PRODID,'XXXXXXXXXX') as FACILITYID
            ,coalesce(ZM_EXTNR,0) as BORROWERID
            ,SUM(LL.CS_TRN_LC) as RISK_PROVISION_EUR
            ,SUM(LL.CS_TRN_TC) as RISK_PROVISION_TC
            ,LL.CUTOFFDATE
        from ROHDATEN as LL
        where 1=1
        and LEFT(CS_ITEM,6) IN('181240','181540') and ZM_KFSEM in ('A_RIVO')
        GROUP BY coalesce(LL.ZM_PRODID,'XXXXXXXXXX'),LL.CUTOFFDATE,coalesce(ZM_EXTNR,0)
    ) as REL_FAC on REL_FAC.FACILITYID=LL.ZM_PRODID and REL_FAC.CUTOFFDATE=LL.CUTOFFDATE
     where 1=1
    and CS_ITEM IN('1153291000','1154119100','1154229100','1154219100', --STAGE 1 on
                   '1154129200','1154229200',--STAGE 2 on
                   '1154219300','1154229300', --Stage 3 on
                   '1154229400' --POCI on
                   /*
                   ,'2315110000','2315210000','2315310000', --STAGE 1 off
                    '2315120000','2315220000','2315320000', -- STAGE 2 off
                   '2315130000','2315230000','2315330000', --STAGE 3 off
                   '2942430200','2942441200','2942442200' --OCI
                   */
                  )
),
RISK_PROVISION as (
    select FACILITYID
         , BORROWERID
         , SUM(RISK_PROVISION_EUR) as RISK_PROVISION_EUR
         , SUM(RISK_PROVISION_TC)  as RISK_PROVISION_TC
         , CUTOFFDATE
    from (
        select
            coalesce(LL.ZM_PRODID, 'XXXXXXXXXX') as FACILITYID,
            coalesce(ZM_EXTNR, 0)                as BORROWERID,
            SUM(LL.CS_TRN_LC)                    as RISK_PROVISION_EUR,
            SUM(LL.CS_TRN_TC)                    as RISK_PROVISION_TC,
            LL.CUTOFFDATE
        from ROHDATEN as LL
        where CS_ITEM IN ('1153291000', '1154119100', '1154229100', '1154219100', --STAGE 1 on
                           '1154129200', '1154229200',--STAGE 2 on
                           '1154219300', '1154229300', --Stage 3 on
                           '1154229400' --POCI on
                 /*
                       ,'2315110000','2315210000','2315310000', --STAGE 1 off
                        '2315120000','2315220000','2315320000', -- STAGE 2 off
                       '2315130000','2315230000','2315330000', --STAGE 3 off
                       '2942430200','2942441200','2942442200' --OCI
                       */
                 )
        group by coalesce(LL.ZM_PRODID, 'XXXXXXXXXX'), LL.CUTOFFDATE, coalesce(ZM_EXTNR, 0)
        union all
        select FACILITYID, BORROWERID, RISK_PROVISION_EUR, RISK_PROVISION_TC, CUTOFFDATE
        from Manuelle_umgebuchte_RISK_PROVISION
        where 1 = 1 --alle auf die Position 181* umgebuchten RIVO mitnehmen (Es handelt sich dabei um zum Verlauf vorgesehene Geschäfte)
    )
    group by FACILITYID, CUTOFFDATE, BORROWERID
),
RIVO_STAGE as (
    select
        FACILITYID
        ,BORROWERID
        ,MAX(RIVO_STAGE) as RIVO_STAGE
        ,CUTOFFDATE
    from (
        select  distinct
                coalesce(LL.ZM_PRODID,'XXXXXXXXXX') as FACILITYID
                ,coalesce(ZM_EXTNR,0) as BORROWERID
                ,max(case when CS_ITEM in ('1153291000','1154119100','1154229100','1154219100','2315110000','2315210000','2315310000') then '1'
                    when CS_ITEM in ('1154129200','1154229200','2315120000','2315220000','2315320000') then '2'
                    when CS_ITEM in ('1154219300','1154229300', '2315130000','2315230000','2315330000') then '3'
                    when CS_ITEM in ('1154229400','2942430200','2942441200','2942442200' ) then 'POCI' end) as RIVO_STAGE
                ,LL.CUTOFFDATE
        from ROHDATEN as LL
        where 1=1
        and CS_ITEM IN('1153291000','1154119100','1154229100','1154219100', --STAGE 1 on
                       '1154129200','1154229200',--STAGE 2 on
                       '1154219300','1154229300', --Stage 3 on
                       '1154229400' --POCI on
                       /*
                       ,'2315110000','2315210000','2315310000', --STAGE 1 off
                        '2315120000','2315220000','2315320000', -- STAGE 2 off
                       '2315130000','2315230000','2315330000', --STAGE 3 off
                       '2942430200','2942441200','2942442200' --OCI
                       */
                       )
        GROUP BY coalesce(LL.ZM_PRODID,'XXXXXXXXXX'),LL.CUTOFFDATE,coalesce(ZM_EXTNR,0)
            union
        select
               FACILITYID
             ,BORROWERID
             ,STAGE
             ,CUTOFFDATE
        from Manuelle_umgebuchte_RISK_PROVISION where 1=1 --alle auf die Position 181* umgebuchten RIVO mitnehmen (Es handelt sich dabei um zum Verlauf vorgesehene Geschäfte)
    ) group by FACILITYID,BORROWERID,CUTOFFDATE
),
RIVO_STAGE_1 as (
    select FACILITYID
         , BORROWERID
         , SUM(RIVO_STAGE_1_LC) as RIVO_STAGE_1_LC
         , SUM(RIVO_STAGE_1_TC) as RIVO_STAGE_1_TC
         , CUTOFFDATE
    from (
             select distinct coalesce(LL.ZM_PRODID, 'XXXXXXXXXX') as FACILITYID
                           , coalesce(ZM_EXTNR, 0)                as BORROWERID
                           , sum(CS_TRN_LC)                       as RIVO_STAGE_1_LC
                           , sum(CS_TRN_TC)                       as RIVO_STAGE_1_TC
                           , LL.CUTOFFDATE
             from ROHDATEN as LL
             where 1 = 1
               and CS_ITEM IN ('1153291000', '1154119100', '1154229100', '1154219100'
                 --,'2315110000','2315210000','2315310000'
                 )
             GROUP BY coalesce(LL.ZM_PRODID, 'XXXXXXXXXX'), LL.CUTOFFDATE, coalesce(ZM_EXTNR, 0)
             union all
             select FACILITYID, BORROWERID, RISK_PROVISION_EUR, RISK_PROVISION_TC, CUTOFFDATE
             from Manuelle_umgebuchte_RISK_PROVISION
             where 1 = 1
               and STAGE = '1'--alle auf die Position 181* umgebuchten RIVO mitnehmen die von einer Stage 1 Position kommen (Es handelt sich dabei um zum Verlauf vorgesehene Geschäfte)
         )
    group by FACILITYID, BORROWERID, CUTOFFDATE
),
RIVO_STAGE_2 as (
        select
            FACILITYID
            ,BORROWERID
            ,SUM(RIVO_STAGE_2_LC) as RIVO_STAGE_2_LC
            ,SUM(RIVO_STAGE_2_TC) as RIVO_STAGE_2_TC
            ,CUTOFFDATE
        from (
            select  distinct
                    coalesce(LL.ZM_PRODID,'XXXXXXXXXX') as FACILITYID
                    ,coalesce(ZM_EXTNR,0) as BORROWERID
                    ,sum(CS_TRN_LC) as RIVO_STAGE_2_LC
                    ,sum(CS_TRN_TC) as RIVO_STAGE_2_TC
                    ,LL.CUTOFFDATE
            from ROHDATEN as LL
            where 1=1
            and CS_ITEM IN('1154129200','1154229200'
                            --,'2315120000','2315220000','2315320000'
                           )

            GROUP BY coalesce(LL.ZM_PRODID,'XXXXXXXXXX'),LL.CUTOFFDATE,coalesce(ZM_EXTNR,0)
                    union all
            select FACILITYID,BORROWERID,RISK_PROVISION_EUR,RISK_PROVISION_TC,CUTOFFDATE from Manuelle_umgebuchte_RISK_PROVISION
                where 1=1
                    and STAGE = '2'--alle auf die Position 181* umgebuchten RIVO mitnehmen die von einer Stage 2 Position kommen (Es handelt sich dabei um zum Verlauf vorgesehene Geschäfte)
            ) group by FACILITYID, BORROWERID, CUTOFFDATE
),
RIVO_STAGE_3 as (
        select
                FACILITYID
                ,BORROWERID
                ,SUM(RIVO_STAGE_3_LC) as RIVO_STAGE_3_LC
                ,SUM(RIVO_STAGE_3_TC) as RIVO_STAGE_3_TC
                ,CUTOFFDATE
        from (
            select  distinct
                    coalesce(LL.ZM_PRODID,'XXXXXXXXXX') as FACILITYID
                    ,coalesce(ZM_EXTNR,0) as BORROWERID
                    ,sum(CS_TRN_LC) as RIVO_STAGE_3_LC
                    ,sum(CS_TRN_TC) as RIVO_STAGE_3_TC
                    ,LL.CUTOFFDATE
            from ROHDATEN as LL
            where 1=1
            and CS_ITEM IN(
                          '1154219300','1154229300'
                           --,'2315130000','2315230000','2315330000'
                           )

            GROUP BY coalesce(LL.ZM_PRODID,'XXXXXXXXXX'),LL.CUTOFFDATE,coalesce(ZM_EXTNR,0)
                    union all
            select FACILITYID,BORROWERID,RISK_PROVISION_EUR,RISK_PROVISION_TC,CUTOFFDATE from Manuelle_umgebuchte_RISK_PROVISION
                where 1=1
                    and STAGE = '3'--alle auf die Position 181* umgebuchten RIVO mitnehmen die von einer Stage 3 Position kommen (Es handelt sich dabei um zum Verlauf vorgesehene Geschäfte)
        ) group by FACILITYID, BORROWERID, CUTOFFDATE
),
RIVO_STAGE_POCI as (
        select
                    FACILITYID
                    ,BORROWERID
                    ,SUM(RIVO_STAGE_POCI_LC) as RIVO_STAGE_POCI_LC
                    ,SUM(RIVO_STAGE_POCI_TC) as RIVO_STAGE_POCI_TC
                    ,CUTOFFDATE
        from (
            select  distinct
                    coalesce(LL.ZM_PRODID,'XXXXXXXXXX') as FACILITYID
                    ,coalesce(ZM_EXTNR,0) as BORROWERID
                    ,sum(CS_TRN_LC) as RIVO_STAGE_POCI_LC
                    ,sum(CS_TRN_TC) as RIVO_STAGE_POCI_TC
                    ,LL.CUTOFFDATE
            from ROHDATEN as LL
            where 1=1
            and CS_ITEM IN(
                           '1154229400'
                           --,'2942430200','2942441200','2942442200' --OCI
                           )

            GROUP BY coalesce(LL.ZM_PRODID,'XXXXXXXXXX'),LL.CUTOFFDATE,coalesce(ZM_EXTNR,0)
                    union all
            select FACILITYID,BORROWERID,RISK_PROVISION_EUR,RISK_PROVISION_TC,CUTOFFDATE from Manuelle_umgebuchte_RISK_PROVISION
                where 1=1
                    and STAGE = 'POCI'--alle auf die Position 181* umgebuchten RIVO mitnehmen die von einer Stage POCI Position kommen (Es handelt sich dabei um zum Verlauf vorgesehene Geschäfte)
        ) group by FACILITYID, BORROWERID, CUTOFFDATE
),
IMPAIRED as (
  select distinct
      LL.CUTOFFDATE CUTOFFDATE
      ,coalesce(LL.ZM_PRODID,'XXXXXXXXXX') as FACILITYID
      ,'1' as IS_IMPAIRED
  from ROHDATEN as LL
      where 1=1
      and CS_ITEM in ('1154219300','1154229300','1154229400','2315130000','2315230000','2315330000','2942430200','2942430200','2942430200','2942441200','2942442200')
  --left join NLB.LENDING_RIVO_FINREP as OO on OO.FACILITYID = LL.ZM_PRODID and LL.CUTOFFDATE=OO.CUTOFFDATE
  group by LL.CUTOFFDATE,LL.ZM_PRODID
),
RESULT as (
    select
        BB.FACILITY_ID as FACILITY_ID -- LL, Funding, Derivate, Lending
        ,BB.BRANCH as BRANCH -- LL
        ,BB.KUNDENNUMMER as ZM_IDNUM -- LL, Kundennummer
        ,BB.ZM_PRKEY as ZM_PRKEY -- LL, Produktschlüssel
        ,BB.WAEHRUNG as ZM_AOCURR -- LL, Objektwährung
        ,BB.DAYSOVERDUE as ZM_ANVETA -- LL, Days overdue
        ,BB.TRADE_ID as TRADE_ID
        ,HK.HALTEKATEGORIE as HALTEKATEGORIE
        ,OFFB.OFFBALANCE_EUR as OFFBALANCE_EUR
        ,OFFB.OFFBALANCE_TC as OFFBALANCE_TC
        ,ACI.ACCRUED_INTEREST_EUR as ACCRUED_INTEREST_EUR -- Lending
        ,ACI.ACCRUED_INTEREST_TC as ACCRUED_INTEREST_TC -- Lending
        ,HGB.HGB_EUR as HGB_EUR -- Lending  (zsm-gebaut)
        ,HGB.HGB_TC as HGB_TC -- Lending  (zsm-gebaut)
        ,BIL.BILANZWERT_BRUTTO_EUR as BILANZWERT_BRUTTO_EUR -- Lending (zsm-gebaut)
        ,BIL.BILANZWERT_BRUTTO_TC as BILANZWERT_BRUTTO_TC -- Lending (zsm-gebaut)
        ,IFRS.Bilanzwert_IFRS9_EUR as Bilanzwert_IFRS9_EUR -- Lending  (zsm-gebaut) = Fair Value Dirty bei Derivate
        ,IFRS.Bilanzwert_IFRS9_TC as Bilanzwert_IFRS9_TC -- Lending  (zsm-gebaut) = Fair Value Dirty bei Derivate
        ,IMP.IS_IMPAIRED as IS_IMPAIRED -- Lending (inkl left join)
        ,case
                when IMP.IS_IMPAIRED = '1' then 'Impaired'
                when coalesce(AA.AMORTIZATION_IN_ARREARS_EUR,0)+coalesce(IA.INTEREST_IN_ARREARS_EUR,0) <> 0 then 'non performing'
                when coalesce(AA.AMORTIZATION_IN_ARREARS_EUR,0)+coalesce(IA.INTEREST_IN_ARREARS_EUR,0) = 0 then 'performing'
                else null
            end as IFRS_STAGE -- Lending  (zsm-gebaut)
        ,RS.RIVO_STAGE as RIVO_STAGE
        ,RS1.RIVO_STAGE_1_LC as RIVO_STAGE_1_EUR
        ,RS1.RIVO_STAGE_1_TC as RIVO_STAGE_1_TC
        ,RS2.RIVO_STAGE_2_LC as RIVO_STAGE_2_EUR
        ,RS2.RIVO_STAGE_2_TC as RIVO_STAGE_2_TC
        ,RS3.RIVO_STAGE_3_LC as RIVO_STAGE_3_EUR
        ,RS3.RIVO_STAGE_3_TC as RIVO_STAGE_3_TC
        ,RSP.RIVO_STAGE_POCI_LC as RIVO_STAGE_POCI_EUR
        ,RSP.RIVO_STAGE_POCI_TC as RIVO_STAGE_POCI_TC
        ,RP.RISK_PROVISION_EUR as RISK_PROVISION_EUR -- Lending  (zsm-gebaut)
        ,RP.RISK_PROVISION_TC as RISK_PROVISION_TC -- Lending  (zsm-gebaut)
        ,PO.PRINCIPAL_OUTSTANDING_EUR as PRINCIPAL_OUTSTANDING_EUR -- Funding, Lending
        ,PO.PRINCIPAL_OUTSTANDING_TC as PRINCIPAL_OUTSTANDING_TC -- Funding, Lending
        ,AA.AMORTIZATION_IN_ARREARS_EUR as AMORTIZATION_IN_ARREARS_EUR -- Lending
        ,AA.AMORTIZATION_IN_ARREARS_TC as AMORTIZATION_IN_ARREARS_TC -- Lending
        ,IA.INTEREST_IN_ARREARS_EUR as INTEREST_IN_ARREARS_EUR -- Lending
        ,IA.INTEREST_IN_ARREARS_TC as INTEREST_IN_ARREARS_TC -- Lending
        ,FVA.FVA_EUR as FVA_EUR -- Funding, Lending
        ,FVA.FVA_TC as FVA_TC -- Funding, Lending
        ,REINBW.Bilanzteile_BW_EUR as Bilanzteile_BW_EUR
        ,REINBW.Bilanzteile_BW_TC as Bilanzteile_BW_TC
        ,MP.MARKETS_PRODUKTE_AMOUNT_EUR as MARKETS_PRODUKTE_AMOUNT_EUR
        ,MP.MARKETS_PRODUKTE_AMOUNT_TC as MARKETS_PRODUKTE_AMOUNT_TC
        ,BB.CUTOFFDATE as CUT_OFF_DATE -- LL, Funding, Derivate, Lending
        ,CURRENT_USER as CREATED_USER
        ,CURRENT_TIMESTAMP as CREATED_TIMESTAMP
    from basis                          as BB
    left join ACCRUED_INTEREST          as ACI on ACI.CUTOFFDATE=BB.CUTOFFDATE and ACI.FACILITYID=BB.FACILITY_ID and ACI.BORROWERID=BB.KUNDENNUMMER
    left join PRICIPAL_OUTSTANDING      as PO on PO.CUTOFFDATE=BB.CUTOFFDATE and PO.FACILITYID=BB.FACILITY_ID  and PO.BORROWERID=BB.KUNDENNUMMER
    left join FVA                       as FVA on FVA.CUTOFFDATE=BB.CUTOFFDATE and FVA.FACILITYID=BB.FACILITY_ID  and FVA.BORROWERID=BB.KUNDENNUMMER
    left join INT_ARREARS               as IA on IA.CUTOFFDATE=BB.CUTOFFDATE and IA.FACILITYID=BB.FACILITY_ID  and IA.BORROWERID=BB.KUNDENNUMMER
    left join AMO_ARREARS               as AA on AA.CUTOFFDATE=BB.CUTOFFDATE and AA.FACILITYID=BB.FACILITY_ID  and AA.BORROWERID=BB.KUNDENNUMMER
    left join BILANZWERT_BRUTTO         as BIL on BIL.CUTOFFDATE=BB.CUTOFFDATE and BIL.FACILITYID=BB.FACILITY_ID  and BIL.BORROWERID=BB.KUNDENNUMMER
    left join BILANZWERT_IFRS           as IFRS on IFRS.CUTOFFDATE=BB.CUTOFFDATE and IFRS.FACILITYID=BB.FACILITY_ID and IFRS.BORROWERID=BB.KUNDENNUMMER
    left join RISK_PROVISION            as RP on RP.CUTOFFDATE=BB.CUTOFFDATE and RP.FACILITYID=BB.FACILITY_ID and RP.BORROWERID=BB.KUNDENNUMMER
    left join IMPAIRED                  as IMP on IMP.CUTOFFDATE=BB.CUTOFFDATE and IMP.FACILITYID=BB.FACILITY_ID --and IMP.ORIGINALCURRENCY=BB.WAEHRUNG and IMP.BORROWERID=BB.KUNDENNUMMER
    left join HGB                       as HGB on HGB.CUTOFFDATE=BB.CUTOFFDATE and HGB.FACILITYID=BB.FACILITY_ID  and HGB.BORROWERID=BB.KUNDENNUMMER
    left join RIVO_STAGE                as RS on RS.CUTOFFDATE=BB.CUTOFFDATE and RS.FACILITYID=BB.FACILITY_ID and RS.BORROWERID=BB.KUNDENNUMMER
    left join RIVO_STAGE_1              as RS1 on RS1.CUTOFFDATE=BB.CUTOFFDATE and RS1.FACILITYID=BB.FACILITY_ID and RS1.BORROWERID=BB.KUNDENNUMMER
    left join RIVO_STAGE_2              as RS2 on RS2.CUTOFFDATE=BB.CUTOFFDATE and RS2.FACILITYID=BB.FACILITY_ID and RS2.BORROWERID=BB.KUNDENNUMMER
    left join RIVO_STAGE_3              as RS3 on RS3.CUTOFFDATE=BB.CUTOFFDATE and RS3.FACILITYID=BB.FACILITY_ID and RS3.BORROWERID=BB.KUNDENNUMMER
    left join RIVO_STAGE_POCI           as RSP on RSP.CUTOFFDATE=BB.CUTOFFDATE and RSP.FACILITYID=BB.FACILITY_ID and RSP.BORROWERID=BB.KUNDENNUMMER
    left join BILANZTEILE_REIN_AUS_BW   as REINBW on REINBW.CUTOFFDATE=BB.CUTOFFDATE and REINBW.FACILITYID=BB.FACILITY_ID and REINBW.BORROWERID=BB.KUNDENNUMMER
    left join OFFBALANCE                as OFFB on OFFB.CUTOFFDATE=BB.CUTOFFDATE and OFFB.FACILITYID=BB.FACILITY_ID and OFFB.BORROWERID=BB.KUNDENNUMMER
    left join HALTEKATEGORIE            as HK on HK.CUTOFFDATE=BB.CUTOFFDATE and HK.FACILITYID=BB.FACILITY_ID and HK.BORROWERID=BB.KUNDENNUMMER
    left join MARKETS_PROD_AM           as MP on MP.CUTOFFDATE=BB.CUTOFFDATE and MP.FACILITYID=BB.FACILITY_ID and MP.BORROWERID=BB.KUNDENNUMMER
)
select * from RESULT
;

-- CI START FOR ALL TAPES
-- Current-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_BW_KENNZAHLEN_CURRENT');
create table AMC.TABLE_BW_KENNZAHLEN_CURRENT like CALC.VIEW_BW_KENNZAHLEN distribute by hash(FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_BW_KENNZAHLEN_CURRENT_FACILITY_ID on AMC.TABLE_BW_KENNZAHLEN_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_BW_KENNZAHLEN_CURRENT');
-- Archiv-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_BW_KENNZAHLEN_ARCHIVE');
create table AMC.TABLE_BW_KENNZAHLEN_ARCHIVE like AMC.TABLE_BW_KENNZAHLEN_CURRENT distribute by hash(FACILITY_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_BW_KENNZAHLEN_ARCHIVE_FACILITY_ID on AMC.TABLE_BW_KENNZAHLEN_ARCHIVE (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_BW_KENNZAHLEN_ARCHIVE');
-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_BW_KENNZAHLEN_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_BW_KENNZAHLEN_ARCHIVE');

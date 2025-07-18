------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_PRE_GUARANTOR_BLB;
create or replace view CALC.VIEW_PRE_GUARANTOR_BLB as
with
    GF as (
    select * from (
        select *, row_number() over (partition by KUNDENNUMMER order by BILANZSTICHTAG desc) as NBR from BLB.GLOBAL_FORMAT_KUNDENDATEN
                  ) where NBR = 1

    ), ab_03_2019 as (
    select distinct
        GP_A.Branch || '_' ||GP_A.PARTNER_ID     as Kreditnehmer
        ,NULL                                    as PORTFOLIO
        ,NULL                                    as Borrower_NAME
        ,NULL                                    as RECOURCE
        ,NULL                                    as REASON
        , GP_B.PARTNER_ID                        as Buerge
        ,GF.WAEHRUNG                             as BILANZWAEHRUNG_GARANT
        ,GF.EBITDA_8200                          as EBITDA_GARANT
        ,GF.UMSATZERLOESE_4000_1                 as GESAMTUMSATZ_GARANT
        ,BILANZSTICHTAG                          as BILANZSTICHTAG_GARANT
        ,GEZEICHNETES_KAPITAL_VORZUGSAKTIEN_2420 as STAMMKAPITAL
        ,KK.COUNTRY                              as COUNTRY_GARANT
        ,SV_ART                                  as Kommentar
        --,B.CMS_ID
        --,B.CMS_SYS
        --,SV.SV_ART
        --,SV_BESCHREIBUNG
        ,GP_A.CUTOFFDATE
        ,SV.TIMESTAMP_LOAD
        ,NULL as ETL_NR
        ,GP_A.QUELLE
        ,GP_A.BRANCH
    from BLB.CMS_GP_CURRENT as GP_A
    inner join BLB.CMS_GP_CURRENT as GP_B on GP_A.CUTOFFDATE= GP_B.CUTOFFDATE and GP_A.CMS_ID = GP_B.CMS_ID
    inner join BLB.CMS_SV_CURRENT as SV on SV.CUTOFFDATE = GP_A.CUTOFFDATE and GP_B.CMS_ID=Sv.SV_ID
    inner join CALC.SWITCH_PORTFOLIO_CURRENT as V2 on V2.CUT_OFF_DATE = GP_A.CUTOFFDATE and left(V2.CLIENT_NO,10) = left(GP_A.PARTNER_ID,10) and V2.BRANCH_SYSTEM = 'BLB'
    left join GF on GF.KUNDENNUMMER= GP_B.PARTNER_ID
    left join BLB.IWHS_KUNDE_CURRENT as KK on KK.BORROWERID= GP_B.PARTNER_ID and GP_B.CUTOFFDATE=KK.CUTOFFDATE
    where 1=1
        --and A.PARTNER_ID  in (select distinct substr(KUNDENNUMMER,5) from STG.BLB_MI_GUARANTOR_INFORMATION)
        and GP_A.PARTNER_FKT = 'Kreditnehmer'
        and GP_B.PARTNER_FKT = 'Bürge/Garant'
        and SV.SV_STATUS = 'Rechtlich aktiv'
        and GP_A.CUTOFFDATE  > '31.12.2018'
)
select * from BLB.MI_GUARANTOR_INFORMATION where CUTOFFDATE <= '01.01.2019'
   union all
select * from ab_03_2019
;

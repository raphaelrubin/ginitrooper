-- View erstellen
drop view CALC.VIEW_ASSET_RENTAL_TENANT_ZEBRA_EBA;
-- Satellitentabelle Asset EBA
create or replace view CALC.VIEW_ASSET_RENTAL_TENANT_ZEBRA_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
---- Rental Tenant
-- Alle an CMS mappbare Real Estates
REST_CMS as (
    select *
    from (select C.VO_ID,
                 R.*,
                 -- Selten gibt es mehrere VO_IDs für die selbe REXID, einfach größte nehmen
                 ROW_NUMBER() over (partition by C.VO_REX_NUMMER order by C.VO_ID desc, R.REALESTATEENTRIES_ID desc) as RN
          from NLB.CMS_VO_CURRENT C
                   -- inner join für Filter
                   inner join NLB.ZEBRA_REAL_ESTATE_ENTRIES_CURRENT R
                              on (C.CUTOFFDATE, C.VO_REX_NUMMER) = (R.CUT_OFF_DATE, R.REALESTATEENTRIES_REXID)
          where UPPER(C.VO_STATUS) = 'RECHTLICH AKTIV'
            and C.CUTOFFDATE = (select CUT_OFF_DATE from COD)
            and R.CUT_OFF_DATE = (select CUT_OFF_DATE from COD))
    where RN = 1
),
-- Rental Tenant zusammenstellen + Filter nach an CMS mappbare Real Estates
RNTLTN_CMS as (
    select RE.CUT_OFF_DATE,
           RE.REALESTATEENTRIES_ID,
           RE.REALESTATEENTRIES_REXID        as REXID,
           RE.VO_ID,
           RA.RENTALAGREEMENTENTRIES_ID,
           R.RENTENTRIES_ID,
           T.TENANTENTRIES_ID,
           RE.REALESTATEENTRIES_CURRENCYCODE as CURRENCYCODE,
           R.RENTENTRIES_NETCOLDRENT         as NETCOLDRENT,
           R.RENTENTRIES_RENTVALIDFROM       as RENTVALIDFROM,
           R.RENTENTRIES_RENTVALIDUNTIL      as RENTVALIDUNTIL,
           T.TENANTENTRIES_FOCSGPNO          as FOCSGPNO,
           T.TENANTENTRIES_TENANTNAME        as TENANTNAME,
           T.TENANTENTRIES_MAGNETTENANT      as MAGNETTENAT
    from REST_CMS RE
             -- inner join für Filter
             inner join NLB.ZEBRA_RENTAL_AGREEMENT_ENTRIES_CURRENT RA
                        on (RE.CUT_OFF_DATE, RE.REALESTATEENTRIES_ID) = (RA.CUT_OFF_DATE, RA.RENTALAGREEMENTENTRIES_REALESTATEID)
             left join NLB.ZEBRA_RENT_ENTRIES_CURRENT R
                       on (RA.CUT_OFF_DATE, RA.RENTALAGREEMENTENTRIES_ID) = (R.CUT_OFF_DATE, R.RENTENTRIES_RENTALAGREEMENTID)
             left join NLB.ZEBRA_TENANT_ENTRIES_CURRENT T
                       on (RA.CUT_OFF_DATE, RA.RENTALAGREEMENTENTRIES_TENANTID) = (T.CUT_OFF_DATE, T.TENANTENTRIES_ID)
    where
      -- Keep RENTVALIDUNTIL = null rows
        NVL(R.RENTENTRIES_RENTVALIDUNTIL, R.CUT_OFF_DATE + 1 days) > R.CUT_OFF_DATE
      -- Keep CONTRACTTERMINATED = null rows
      and not NVL(RA.RENTALAGREEMENTENTRIES_CONTRACTTERMINATED, false)
      and RA.CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
      and R.CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
      and T.CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- Für jeden Tenant NETCOLDRENT in EUR aufsummieren
TN_RNT_SUM_EUR as (
    select R.CUT_OFF_DATE,
           R.TENANTENTRIES_ID,
           sum(NETCOLDRENT * CM.RATE_TARGET_TO_EUR) as NETCOLDRENT_SUM,
           'EUR'                                    as CURRENCY,
           case
               when count(distinct CURRENCYCODE) > 1
                   then 'UNEINDEUTIG'
               else max(CURRENCYCODE)
               end                                  as NETCOLDRENT_SUM_CURRENCY_OC
    from RNTLTN_CMS R
             left join IMAP.CURRENCY_MAP CM on (R.CUT_OFF_DATE, R.CURRENCYCODE) = (CM.CUT_OFF_DATE, CM.ZIEL_WHRG)
    group by R.CUT_OFF_DATE, R.TENANTENTRIES_ID
),
RNTLTN as (
    select RT.CUT_OFF_DATE,
           RT.TENANTENTRIES_ID              as ZEBRA_TENANTID,
           RT.REALESTATEENTRIES_ID          as ZEBRA_REALESTATEID,
           RT.REXID                         as ZEBRA_REXID,
           RT.VO_ID                         as ZEBRA_CMSID,
           RT.FOCSGPNO                      as ZEBRA_FOCSGPNO,
           RT.TENANTNAME                    as ZEBRA_TENANTNAME,
           RT.MAGNETTENAT                   as ZEBRA_MAGNETTENAT,
           RT.RENTVALIDFROM                 as ZEBRA_RENTVALIDFROM,
           RT.RENTVALIDUNTIL                as ZEBRA_RENTVALIDUNTIL,
           TSUM.NETCOLDRENT_SUM             as ZEBRA_NETCOLDRENT_SUM,
           TSUM.NETCOLDRENT_SUM_CURRENCY_OC as ZEBRA_NETCOLDRENT_SUM_CURRENCY_OC,
           TSUM.CURRENCY                    as ZEBRA_CURRENCY
    from RNTLTN_CMS RT
             left join TN_RNT_SUM_EUR TSUM on (RT.CUT_OFF_DATE, RT.TENANTENTRIES_ID) = (TSUM.CUT_OFF_DATE, TSUM.TENANTENTRIES_ID)
),
---- Filter auf ASSET_EBA mit Vermeidung zyklischer Abhängigkeiten
PWC_ASSET as (
    select *
    from CALC.SWITCH_ASSET_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
CMS_ASSET as (
    select *
    from CALC.SWITCH_ASSET_CMS_EBA_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- Alle VO_REX_NUMMERn aus ASSET_EBA
ASSET_EBA as (
    select distinct VO_REX_NUMMER
    from PWC_ASSET PWC
             left join CMS_ASSET CMS on PWC.SOURCE = 'CMS' and PWC.ASSET_ID = CMS.ASSET_ID
),
-- Einschränken auf ASSET_EBA
FINAL as (
    select RT.*
    from RNTLTN RT
             inner join ASSET_EBA ASSET on ASSET.VO_REX_NUMMER = RT.ZEBRA_REXID
),
-- Gefiltert nach noetigen Datenfeldern
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        ZEBRA_REXID,
        ZEBRA_REALESTATEID,
        ZEBRA_TENANTID,
        ZEBRA_TENANTNAME,
        ZEBRA_MAGNETTENAT,
        ZEBRA_RENTVALIDFROM,
        ZEBRA_RENTVALIDUNTIL,
        ZEBRA_NETCOLDRENT_SUM,
        ZEBRA_NETCOLDRENT_SUM_CURRENCY_OC,
        ZEBRA_CURRENCY,
        -- Defaults
        CURRENT_USER      as USER,
        CURRENT_TIMESTAMP as TIMESTAMP_LOAD
    from FINAL
)
select *
from FINAL_FILTERED;

-- CI START FOR ALL TAPES

-- Current-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_ASSET_RENTAL_TENANT_ZEBRA_EBA_CURRENT');
create table AMC.TABLE_ASSET_RENTAL_TENANT_ZEBRA_EBA_CURRENT like CALC.VIEW_ASSET_RENTAL_TENANT_ZEBRA_EBA distribute by hash (ZEBRA_REXID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_ASSET_RENTAL_TENANT_ZEBRA_EBA_CURRENT_ZEBRA_REXID on AMC.TABLE_ASSET_RENTAL_TENANT_ZEBRA_EBA_CURRENT (ZEBRA_REXID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_ASSET_RENTAL_TENANT_ZEBRA_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- Archiv-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_ASSET_RENTAL_TENANT_ZEBRA_EBA_ARCHIVE');
create table AMC.TABLE_ASSET_RENTAL_TENANT_ZEBRA_EBA_ARCHIVE like CALC.VIEW_ASSET_RENTAL_TENANT_ZEBRA_EBA distribute by hash (ZEBRA_REXID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_ASSET_RENTAL_TENANT_ZEBRA_EBA_ARCHIVE_ZEBRA_REXID on AMC.TABLE_ASSET_RENTAL_TENANT_ZEBRA_EBA_ARCHIVE (ZEBRA_REXID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_ASSET_RENTAL_TENANT_ZEBRA_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_ASSET_RENTAL_TENANT_ZEBRA_EBA_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_ASSET_RENTAL_TENANT_ZEBRA_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------


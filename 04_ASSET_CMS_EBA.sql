-- View erstellen
drop view CALC.VIEW_ASSET_CMS_EBA;
create or replace view CALC.VIEW_ASSET_CMS_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
-- Quelldaten
CMS_VO as (
    select CUTOFFDATE                as CUT_OFF_DATE,
           VO_ID                     as ASSET_ID,
           VO_ART,
           VO_GEBAEUDE_KZ,
           VO_REX_NUMMER,
           VO_TYP,
           VO_NUTZUNG_OBJEKT,
           VO_NUTZUNGSART,
           VO_FESTSETZ_DATUM,
           VO_GEWERB_NUTZUNG_P / 100 as VO_GEWERB_NUTZUNG_P,
           VO_LETZT_NACHWEIS_DATUM,
           VO_ANWEND_RECHT,
           VO_NOMINAL_WERT,
           VO_NOMINAL_WERT_WAEHR,
           VO_ANZUS_WERT,
           VO_ANZUS_WERT_WAEHR,
           VO_CALC_LENDING_VALUE,
           VO_CALC_LENDING_LIMIT,
           VO_CALC_CURRENCY,
           case
               when VO_CALC_LENDING_VALUE != 0
                   then VO_CALC_LENDING_LIMIT / VO_CALC_LENDING_VALUE
               when VO_CALC_LENDING_LIMIT is not null and VO_CALC_LENDING_VALUE is not null
                   then 0
               end                   as VO_BELEIHUNGSGRENZE_PROZ,
           VO_BELEIHSATZ1_P / 100    as VO_BELEIHSATZ1_P,
           VO_URSPRUNGSWERT,
           VO_URSPRUNGSWERT_WAEHR,
           VO_CRR_PROPERTY_VALUE,
           VO_CRR_PROPERTY_VALUE_CURR,
           VO_STRASSE,
           VO_HAUS_NR,
           VO_PLZ,
           VO_ORT,
           VO_REGION,
           VO_LAND
    from NLB.CMS_VO_CURRENT
    where CUTOFFDATE = (select CUT_OFF_DATE from COD)
),
CMS_GP as (
    select CUTOFFDATE as CUT_OFF_DATE,
           CMS_ID,
           PARTNER_ID,
           PARTNER_FKT
    from NLB.CMS_GP_CURRENT
    where CUTOFFDATE = (select CUT_OFF_DATE from COD)
      and UPPER(CMS_SYS) = 'VO'
),
CMS_C2A as (
    select distinct ASSET_ID
    from CALC.SWITCH_COLLATERAL_TO_ASSET_CMS_EBA_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- Assets filtern auf vorhanden in C2A
CMS_VO_FILTERED as (
    select VO.*
    from CMS_VO VO
             inner join CMS_C2A C2A on VO.ASSET_ID = C2A.ASSET_ID
),
-- Währungsumrechnung
CMS_VO_EUR as (
    select C.CUT_OFF_DATE,
           ASSET_ID,
           VO_ART,
           VO_GEBAEUDE_KZ,
           VO_REX_NUMMER,
           VO_TYP,
           VO_NUTZUNG_OBJEKT,
           VO_NUTZUNGSART,
           VO_FESTSETZ_DATUM,
           VO_GEWERB_NUTZUNG_P,
           VO_LETZT_NACHWEIS_DATUM,
           VO_ANWEND_RECHT,
           case
               when CMN.ZIEL_WHRG is not null
                   then VO_NOMINAL_WERT * CMN.RATE_TARGET_TO_EUR
               else VO_NOMINAL_WERT
               end                    as VO_NOMINAL_WERT,
           case
               when CMN.ZIEL_WHRG is not null
                   then 'EUR'
               else VO_NOMINAL_WERT_WAEHR
               end                    as VO_NOMINAL_WERT_CURRENCY,
           VO_NOMINAL_WERT_WAEHR      as VO_NOMINAL_WERT_CURRENCY_OC,
           case
               when CMA.ZIEL_WHRG is not null
                   then VO_ANZUS_WERT * CMA.RATE_TARGET_TO_EUR
               else VO_ANZUS_WERT
               end                    as VO_ANZUS_WERT,
           case
               when CMA.ZIEL_WHRG is not null
                   then 'EUR'
               else VO_ANZUS_WERT_WAEHR
               end                    as VO_ANZUS_WERT_CURRENCY,
           VO_ANZUS_WERT_WAEHR        as VO_ANZUS_WERT_CURRENCY_OC,
           case
               when CMC.ZIEL_WHRG is not null
                   then VO_CALC_LENDING_VALUE * CMC.RATE_TARGET_TO_EUR
               else VO_CALC_LENDING_VALUE
               end                    as VO_CALC_LENDING_VALUE,
           case
               when CMC.ZIEL_WHRG is not null
                   then VO_CALC_LENDING_LIMIT * CMC.RATE_TARGET_TO_EUR
               else VO_CALC_LENDING_LIMIT
               end                    as VO_CALC_LENDING_LIMIT,
           case
               when CMC.ZIEL_WHRG is not null
                   then 'EUR'
               else VO_CALC_CURRENCY
               end                    as VO_CALC_CURRENCY,
           VO_CALC_CURRENCY           as VO_CALC_CURRENCY_OC,
           VO_BELEIHUNGSGRENZE_PROZ,
           VO_BELEIHSATZ1_P,
           case
               when CMU.ZIEL_WHRG is not null
                   then VO_URSPRUNGSWERT * CMU.RATE_TARGET_TO_EUR
               else VO_URSPRUNGSWERT
               end                    as VO_URSPRUNGSWERT,
           case
               when CMU.ZIEL_WHRG is not null
                   then 'EUR'
               else VO_URSPRUNGSWERT_WAEHR
               end                    as VO_URSPRUNGSWERT_CURRENCY,
           VO_URSPRUNGSWERT_WAEHR     as VO_URSPRUNGSWERT_CURRENCY_OC,
           case
               when CMP.ZIEL_WHRG is not null
                   then VO_CRR_PROPERTY_VALUE * CMP.RATE_TARGET_TO_EUR
               else VO_CRR_PROPERTY_VALUE
               end                    as VO_CRR_PROPERTY_VALUE,
           case
               when CMP.ZIEL_WHRG is not null
                   then 'EUR'
               else VO_CRR_PROPERTY_VALUE_CURR
               end                    as VO_CRR_PROPERTY_VALUE_CURRENCY,
           VO_CRR_PROPERTY_VALUE_CURR as VO_CRR_PROPERTY_VALUE_CURRENCY_OC,
           VO_STRASSE,
           VO_HAUS_NR,
           VO_PLZ,
           VO_ORT,
           VO_REGION,
           VO_LAND
    from CMS_VO_FILTERED C
             left join IMAP.CURRENCY_MAP CMN on (C.CUT_OFF_DATE, C.VO_NOMINAL_WERT_WAEHR) = (CMN.CUT_OFF_DATE, CMN.ZIEL_WHRG)
             left join IMAP.CURRENCY_MAP CMA on (C.CUT_OFF_DATE, C.VO_ANZUS_WERT_WAEHR) = (CMA.CUT_OFF_DATE, CMA.ZIEL_WHRG)
             left join IMAP.CURRENCY_MAP CMU on (C.CUT_OFF_DATE, C.VO_URSPRUNGSWERT_WAEHR) = (CMU.CUT_OFF_DATE, CMU.ZIEL_WHRG)
             left join IMAP.CURRENCY_MAP CMC on (C.CUT_OFF_DATE, C.VO_CALC_CURRENCY) = (CMC.CUT_OFF_DATE, CMC.ZIEL_WHRG)
             left join IMAP.CURRENCY_MAP CMP on (C.CUT_OFF_DATE, C.VO_CRR_PROPERTY_VALUE_CURR) = (CMP.CUT_OFF_DATE, CMP.ZIEL_WHRG)
),
-- PARTNER_ID aggregieren
CMS_GP_AGG as (
    select CUT_OFF_DATE,
           CMS_ID,
           LISTAGG(PARTNER_ID, ', ') within group (order by PARTNER_ID) as VO_OWNERS
    from CMS_GP
    where UPPER(PARTNER_FKT) in ('EIGENTÜMER', 'EIGENTÜMER / KONTOINHABER')
    group by CUT_OFF_DATE, CMS_ID
),
-- Alles zusammenführen
FINAL as (
    select VO.CUT_OFF_DATE,
           ASSET_ID,
           VO_ART,
           VO_GEBAEUDE_KZ,
           VO_REX_NUMMER,
           VO_TYP,
           VO_NUTZUNG_OBJEKT,
           VO_NUTZUNGSART,
           VO_FESTSETZ_DATUM,
           VO_GEWERB_NUTZUNG_P,
           VO_LETZT_NACHWEIS_DATUM,
           VO_ANWEND_RECHT,
           VO_NOMINAL_WERT,
           VO_NOMINAL_WERT_CURRENCY,
           VO_NOMINAL_WERT_CURRENCY_OC,
           VO_ANZUS_WERT,
           VO_ANZUS_WERT_CURRENCY,
           VO_ANZUS_WERT_CURRENCY_OC,
           VO_CALC_LENDING_VALUE,
           VO_CALC_LENDING_LIMIT,
           VO_CALC_CURRENCY,
           VO_CALC_CURRENCY_OC,
           VO_BELEIHUNGSGRENZE_PROZ,
           VO_BELEIHSATZ1_P,
           VO_URSPRUNGSWERT,
           VO_URSPRUNGSWERT_CURRENCY,
           VO_URSPRUNGSWERT_CURRENCY_OC,
           VO_CRR_PROPERTY_VALUE,
           VO_CRR_PROPERTY_VALUE_CURRENCY,
           VO_CRR_PROPERTY_VALUE_CURRENCY_OC,
           VO_STRASSE,
           VO_HAUS_NR,
           VO_PLZ,
           VO_ORT,
           VO_REGION,
           VO_LAND,
           VO_OWNERS
    from CMS_VO_EUR VO
             left join CMS_GP_AGG GP on VO.ASSET_ID = GP.CMS_ID
),
-- Gefiltert nach noetigen Datenfeldern
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        ASSET_ID,
        VO_ART,
        VO_GEBAEUDE_KZ,
        VO_REX_NUMMER,
        VO_TYP,
        VO_NUTZUNG_OBJEKT,
        VO_NUTZUNGSART,
        VO_FESTSETZ_DATUM,
        VO_GEWERB_NUTZUNG_P,
        VO_LETZT_NACHWEIS_DATUM,
        VO_ANWEND_RECHT,
        VO_NOMINAL_WERT,
        VO_NOMINAL_WERT_CURRENCY,
        VO_NOMINAL_WERT_CURRENCY_OC,
        VO_ANZUS_WERT,
        VO_ANZUS_WERT_CURRENCY,
        VO_ANZUS_WERT_CURRENCY_OC,
        VO_CALC_LENDING_VALUE,
        VO_CALC_LENDING_LIMIT,
        VO_CALC_CURRENCY,
        VO_CALC_CURRENCY_OC,
        VO_BELEIHUNGSGRENZE_PROZ,
        VO_BELEIHSATZ1_P,
        VO_URSPRUNGSWERT,
        VO_URSPRUNGSWERT_CURRENCY,
        VO_URSPRUNGSWERT_CURRENCY_OC,
        VO_CRR_PROPERTY_VALUE,
        VO_CRR_PROPERTY_VALUE_CURRENCY,
        VO_CRR_PROPERTY_VALUE_CURRENCY_OC,
        VO_STRASSE,
        VO_HAUS_NR,
        VO_PLZ,
        VO_ORT,
        VO_REGION,
        VO_LAND,
        VO_OWNERS,
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
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_ASSET_CMS_EBA_CURRENT');
create table AMC.TABLE_ASSET_CMS_EBA_CURRENT like CALC.VIEW_ASSET_CMS_EBA distribute by hash (ASSET_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_ASSET_CMS_EBA_CURRENT_ASSET_ID on AMC.TABLE_ASSET_CMS_EBA_CURRENT (ASSET_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_ASSET_CMS_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_ASSET_CMS_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------


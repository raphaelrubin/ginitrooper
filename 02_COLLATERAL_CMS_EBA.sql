-- View erstellen
drop view CALC.VIEW_COLLATERAL_CMS_EBA;
create or replace view CALC.VIEW_COLLATERAL_CMS_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
-- Quelldaten
CMS_SV as (
    select CUTOFFDATE                     as CUT_OFF_DATE,
           SV_ID                          as COLLATERAL_ID,
           SV_ART,
           SV_TYP,
           SV_NOMINALWERT,
           SV_NOMINALWERT_WAEHR,
           SV_ANZUSETZ_WERT,
           SV_ANZUSETZ_WERT_WAEHR,
           SV_ANWENDBARES_RECHT,
           SV_AUSFBUERGSCHAFT,
           SV_AUSFALLBUERG_PROZ / 100     as SV_AUSFALLBUERG_PROZ,
           SV_BUERG_BELEIHSATZ_PROZ / 100 as SV_BUERG_BELEIHSATZ_PROZ,
           SV_GUELTIG_VON,
           SV_GUELTIG_BIS,
           SV_HOECHSTBETRBUERG,
           SV_VERBUERGUNGSSATZ_PROZ / 100 as SV_VERBUERGUNGSSATZ_PROZ
    from NLB.CMS_SV_CURRENT
    where CUTOFFDATE = (select CUT_OFF_DATE from COD)
),
CMS_GP as (
    select CUTOFFDATE as CUT_OFF_DATE,
           CMS_ID,
           PARTNER_ID,
           PARTNER_FKT
    from NLB.CMS_GP_CURRENT
    where CUTOFFDATE = (select CUT_OFF_DATE from COD)
      and UPPER(CMS_SYS) = 'SV'
),
CMS_F2C as (
    select distinct COLLATERAL_ID
    from CALC.SWITCH_FACILITY_TO_COLLATERAL_CMS_EBA_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- Collaterals filtern auf vorhanden in F2C
CMS_SV_FILTERED as (
    select SV.*
    from CMS_SV SV
             inner join CMS_F2C F2C on SV.COLLATERAL_ID = F2C.COLLATERAL_ID
),
-- Währungsumrechnung
CMS_SV_EUR as (
    select C.CUT_OFF_DATE,
           COLLATERAL_ID,
           SV_ART,
           SV_TYP,
           case
               when CMN.ZIEL_WHRG is not null
                   then SV_NOMINALWERT * CMN.RATE_TARGET_TO_EUR
               else SV_NOMINALWERT
               end                as SV_NOMINALWERT,
           case
               when CMN.ZIEL_WHRG is not null
                   then 'EUR'
               else SV_NOMINALWERT_WAEHR
               end                as SV_NOMINALWERT_CURRENCY,
           SV_NOMINALWERT_WAEHR   as SV_NOMINALWERT_CURRENCY_OC,
           case
               when CMA.ZIEL_WHRG is not null
                   then SV_ANZUSETZ_WERT * CMA.RATE_TARGET_TO_EUR
               else SV_ANZUSETZ_WERT
               end                as SV_ANZUSETZ_WERT,
           case
               when CMA.ZIEL_WHRG is not null
                   then 'EUR'
               else SV_ANZUSETZ_WERT_WAEHR
               end                as SV_ANZUSETZ_WERT_CURRENCY,
           SV_ANZUSETZ_WERT_WAEHR as SV_ANZUSETZ_WERT_CURRENCY_OC,
           SV_ANWENDBARES_RECHT,
           SV_AUSFBUERGSCHAFT,
           SV_AUSFALLBUERG_PROZ,
           SV_BUERG_BELEIHSATZ_PROZ,
           SV_GUELTIG_VON,
           SV_GUELTIG_BIS,
           SV_HOECHSTBETRBUERG,
           SV_VERBUERGUNGSSATZ_PROZ
    from CMS_SV_FILTERED C
             left join IMAP.CURRENCY_MAP CMN on (C.CUT_OFF_DATE, C.SV_NOMINALWERT_WAEHR) = (CMN.CUT_OFF_DATE, CMN.ZIEL_WHRG)
             left join IMAP.CURRENCY_MAP CMA on (C.CUT_OFF_DATE, C.SV_ANZUSETZ_WERT_WAEHR) = (CMA.CUT_OFF_DATE, CMA.ZIEL_WHRG)
),
-- PARTNER_ID aggregieren
CMS_GP_AGG as (
    select CUT_OFF_DATE,
           CMS_ID,
           LISTAGG(PARTNER_ID, ', ') as SV_GUARANTORS
    from CMS_GP
    where UPPER(PARTNER_FKT) in ('SICHERHEITENGEBER', 'BÜRGE/GARANT', 'SICHERHEITENGEBER/GARANT')
    group by CUT_OFF_DATE, CMS_ID
),
-- Alles zusammenführen
FINAL as (
    select SV.CUT_OFF_DATE,
           COLLATERAL_ID,
           SV_ART,
           SV_TYP,
           SV_NOMINALWERT,
           SV_NOMINALWERT_CURRENCY,
           SV_NOMINALWERT_CURRENCY_OC,
           SV_ANZUSETZ_WERT,
           SV_ANZUSETZ_WERT_CURRENCY,
           SV_ANZUSETZ_WERT_CURRENCY_OC,
           SV_ANWENDBARES_RECHT,
           SV_AUSFBUERGSCHAFT,
           SV_AUSFALLBUERG_PROZ,
           SV_BUERG_BELEIHSATZ_PROZ,
           SV_GUELTIG_VON,
           SV_GUELTIG_BIS,
           SV_HOECHSTBETRBUERG,
           SV_VERBUERGUNGSSATZ_PROZ,
           SV_GUARANTORS
    from CMS_SV_EUR SV
             left join CMS_GP_AGG GP on SV.COLLATERAL_ID = GP.CMS_ID
),
-- Gefiltert nach noetigen Datenfeldern
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        COLLATERAL_ID,
        SV_ART,
        SV_TYP,
        SV_NOMINALWERT,
        SV_NOMINALWERT_CURRENCY,
        SV_NOMINALWERT_CURRENCY_OC,
        SV_ANZUSETZ_WERT,
        SV_ANZUSETZ_WERT_CURRENCY,
        SV_ANZUSETZ_WERT_CURRENCY_OC,
        SV_ANWENDBARES_RECHT,
        SV_AUSFBUERGSCHAFT,
        SV_AUSFALLBUERG_PROZ,
        SV_BUERG_BELEIHSATZ_PROZ,
        SV_GUELTIG_VON,
        SV_GUELTIG_BIS,
        SV_HOECHSTBETRBUERG,
        SV_VERBUERGUNGSSATZ_PROZ,
        SV_GUARANTORS,
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
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_COLLATERAL_CMS_EBA_CURRENT');
create table AMC.TABLE_COLLATERAL_CMS_EBA_CURRENT like CALC.VIEW_COLLATERAL_CMS_EBA distribute by hash (COLLATERAL_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_COLLATERAL_CMS_EBA_CURRENT_COLLATERAL_ID on AMC.TABLE_COLLATERAL_CMS_EBA_CURRENT (COLLATERAL_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_COLLATERAL_CMS_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_COLLATERAL_CMS_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------


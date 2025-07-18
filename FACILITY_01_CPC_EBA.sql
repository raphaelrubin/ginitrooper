-- View erstellen
drop view CALC.VIEW_FACILITY_CPC_EBA;
create or replace view CALC.VIEW_FACILITY_CPC_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
---- Output besteht aus gesamtem CPC, Current + Archiv
-- Quelldaten Current
CPC_C as (
    select *, CUT_OFF_DATE as CURR_COD, CUT_OFF_DATE as OWN_COD
    from NLB.CPC_FACILITY_CURRENT
    where KONTONUMMER is not null
      and CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- Quelldaten Archiv
CPC_A as (
    -- CURR_COD hinzufügen um später einfach auf aktuelles CUT_OFF_DATE zu setzen
    select *, (select CUT_OFF_DATE from COD) as CURR_COD, CUT_OFF_DATE as OWN_COD
    from NLB.CPC_FACILITY
    where KONTONUMMER is not null
      -- Nur Daten vor Stichtag
      and CUT_OFF_DATE < (select CUT_OFF_DATE from COD)
),
-- Union
CPC_UNION as (
    select *
    from CPC_C
    union all
    select *
    from CPC_A
),
-- PWC Facility
PWC_FAC as (
    select FACILITY_ID,
           -- Nur Mittelteil der Facility ID (Kontonummer)
           KONTONUMMER_LEADING,
           case
               when LENGTH(RTRIM(TRANSLATE(KONTONUMMER_LEADING, '', ' 0123456789'))) = 0
                   -- Ist Zahl, führende Nullen entfernen
                   then cast(cast(KONTONUMMER_LEADING as BIGINT) as VARCHAR(64))
               else KONTONUMMER_LEADING
               end                                                              as KONTONUMMER,
           LENGTH(RTRIM(TRANSLATE(KONTONUMMER_LEADING, '', ' 0123456789'))) = 0 as KONTONUMMER_IS_INT,
           -- Nur hinterer Teil der Facility ID (Unterkontonummer)
           UNTERKONTONUMMER_LEADING,
           UNTERKONTONUMMER,
           UNTERKONTONUMMER_IS_INT,
           GNI_KUNDE
    from (
             select FACILITY_ID,
                    -- Alles vor Kontonummer abschneiden
                    SUBSTR(KONTONUMMER_TEMP, INSTR(KONTONUMMER_TEMP, '-', -1) + 1)            as KONTONUMMER_LEADING,
                    UNTERKONTONUMMER_LEADING,
                    case
                        when LENGTH(RTRIM(TRANSLATE(UNTERKONTONUMMER_LEADING, '', ' 0123456789'))) = 0
                            -- Ist Zahl, führende Nullen entfernen
                            then cast(cast(UNTERKONTONUMMER_LEADING as BIGINT) as VARCHAR(64))
                        else UNTERKONTONUMMER_LEADING
                        end                                                                   as UNTERKONTONUMMER,
                    LENGTH(RTRIM(TRANSLATE(UNTERKONTONUMMER_LEADING, '', ' 0123456789'))) = 0 as UNTERKONTONUMMER_IS_INT,
                    GNI_KUNDE
             from (
                      select FACILITY_ID,
                             -- Alles hinter Kontonummer abschneiden
                             LEFT(FACILITY_ID, INSTR(FACILITY_ID, '-', 1, 3) - 1)   as KONTONUMMER_TEMP,
                             -- Alles vor Unterkontonummer abschneiden
                             SUBSTR(FACILITY_ID, INSTR(FACILITY_ID, '-', 1, 4) + 1) as UNTERKONTONUMMER_LEADING,
                             CLIENT_ID                                              as GNI_KUNDE
                      from CALC.SWITCH_FACILITY_CURRENT
                      where INSTR(FACILITY_ID, '-', 1, 3) > 0
                        and CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
                  )
         )
),
-- Duplikate entfernen: gleiche Kontonummer -> aktuellster Stichtag & davon höchste Vorgangsnummer nehmen
CPC_UNIQUE as (
    select *
    from (select *, ROW_NUMBER() over (partition by KONTONUMMER order by OWN_COD desc, VORGANGSNUMMER desc) as RN
          from CPC_UNION)
    where RN = 1
),
-- Nötige Werte umrechnen
CPC_CALC as (
    select CURR_COD                                             as CUT_OFF_DATE,
           KONTONUMMER,
           VORGANGSNUMMER,
           CPC_DB_3_N_RISIKO_IN_EUR                             as CPC_DB_3_N_RISIKO,
           CPC_DB_3_V_RISIKO_IN_EUR                             as CPC_DB_3_V_RISIKO,
           DURCHSCHN_INANSPR_IN_EUR                             as DURCHSCHN_INANSPR,
           EINMALZAHLUNG_IN_EUR                                 as EINMALZAHLUNG,
           EK_KOSTEN_PROZ / 100                                 as EK_KOSTEN,
           KREDITPROVISION_IN_PROZENT / 100                     as KREDITPROVISION,
           KUNDENMARGE_NETTO_IN_PROZENT / 100                   as KUNDENMARGE_NETTO,
           OH_KOSTEN_PROZ / 100                                 as OH_KOSTEN,
           PROFC_KOSTEN_PROZ / 100                              as PROFC_KOSTEN,
           RISIKOPRAEMIE_IN_PROZENT / 100                       as RISIKOPRAEMIE,
           CAST(CPC_RWA_PRODUKTIVITAET_IN_BP as DOUBLE) / 10000 as CPC_RWA_PRODUKTIVITAET,
           RORAC_PROZENT / 100                                  as RORAC,
           SCS_KOSTEN_PROZ / 100                                as SCS_KOSTEN,
           STATUS,
           ULTIMOMONAT,
           UTILITY_FEE_IN_PROZENT / 100                         as UTILITY_FEE,
           case
               when WAEHRUNGSCODE is not null
                   then 'EUR'
               end                                              as CURRENCY,
           WAEHRUNGSCODE                                        as CURRENCY_OC
    from CPC_UNIQUE
),
-- Facility ID via PWC mappen
FINAL as (
    select CUT_OFF_DATE,
           NVL(PWC_K.FACILITY_ID, PWC_U.FACILITY_ID) as FACILITY_ID,
           CPC.KONTONUMMER,
           VORGANGSNUMMER,
           CPC_DB_3_N_RISIKO,
           CPC_DB_3_V_RISIKO,
           DURCHSCHN_INANSPR,
           EINMALZAHLUNG,
           EK_KOSTEN,
           KREDITPROVISION,
           KUNDENMARGE_NETTO,
           OH_KOSTEN,
           PROFC_KOSTEN,
           RISIKOPRAEMIE,
           CPC_RWA_PRODUKTIVITAET,
           RORAC,
           SCS_KOSTEN,
           STATUS,
           ULTIMOMONAT,
           UTILITY_FEE,
           CURRENCY,
           CURRENCY_OC
    from CPC_CALC CPC
             left join PWC_FAC PWC_K on PWC_K.KONTONUMMER_IS_INT and PWC_K.KONTONUMMER = CPC.KONTONUMMER
             left join PWC_FAC PWC_U on PWC_U.UNTERKONTONUMMER_IS_INT and PWC_U.UNTERKONTONUMMER = CPC.KONTONUMMER
),
-- Gefiltert nach noetigen Datenfeldern + nullable
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        NULLIF(ULTIMOMONAT, null)            as ULTIMOMONAT,
        NULLIF(FACILITY_ID, null)            as FACILITY_ID,
        NULLIF(KONTONUMMER, null)            as KONTONUMMER,
        NULLIF(VORGANGSNUMMER, null)         as VORGANGSNUMMER,
        NULLIF(CURRENCY_OC, null)            as CURRENCY_OC,
        NULLIF(CURRENCY, null)               as CURRENCY,
        NULLIF(DURCHSCHN_INANSPR, null)      as DURCHSCHN_INANSPR,
        NULLIF(SCS_KOSTEN, null)             as SCS_KOSTEN,
        NULLIF(PROFC_KOSTEN, null)           as PROFC_KOSTEN,
        NULLIF(OH_KOSTEN, null)              as OH_KOSTEN,
        NULLIF(KUNDENMARGE_NETTO, null)      as KUNDENMARGE_NETTO,
        NULLIF(KREDITPROVISION, null)        as KREDITPROVISION,
        NULLIF(UTILITY_FEE, null)            as UTILITY_FEE,
        NULLIF(EINMALZAHLUNG, null)          as EINMALZAHLUNG,
        NULLIF(CPC_DB_3_V_RISIKO, null)      as CPC_DB_3_V_RISIKO,
        NULLIF(CPC_DB_3_N_RISIKO, null)      as CPC_DB_3_N_RISIKO,
        NULLIF(EK_KOSTEN, null)              as EK_KOSTEN,
        NULLIF(RISIKOPRAEMIE, null)          as RISIKOPRAEMIE,
        NULLIF(CPC_RWA_PRODUKTIVITAET, null) as CPC_RWA_PRODUKTIVITAET,
        NULLIF(RORAC, null)                  as RORAC,
        -- Defaults
        CURRENT_USER                         as USER,
        CURRENT_TIMESTAMP                    as TIMESTAMP_LOAD
    from FINAL
)
select *
from FINAL_FILTERED;

-- CI START FOR ALL TAPES

-- Current-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_FACILITY_CPC_EBA_CURRENT');
create table AMC.TABLE_FACILITY_CPC_EBA_CURRENT like CALC.VIEW_FACILITY_CPC_EBA distribute by hash (FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_CPC_EBA_CURRENT_FACILITY_ID on AMC.TABLE_FACILITY_CPC_EBA_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_FACILITY_CPC_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_FACILITY_CPC_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------


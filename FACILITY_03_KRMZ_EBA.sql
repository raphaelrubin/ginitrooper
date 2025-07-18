-- View erstellen
drop view CALC.VIEW_FACILITY_KRMZ_EBA;
-- Satellitentabelle Facility EBA
create or replace view CALC.VIEW_FACILITY_KRMZ_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
---- Quelldaten
-- Past Due
LIQ_PD as (
    select distinct CUTOFFDATE as CUT_OFF_DATE,
                    DEAL,
                    FACILITY,
                    OUTSTANDING
    from NLB.LIQ_PAST_DUE
    where CUTOFFDATE = (select CUT_OFF_DATE from COD)
),
-- Stammdaten
SCRM_STM as (
    select *,
           'NLB_' || GP_NUMMER as GNI_KUNDE,
           case
               when NACHNAME___NAME1 is null and VORNAME___NAME2 is null
                   then null
               else NVL(NACHNAME___NAME1, '') || NVL(VORNAME___NAME2, '')
               end             as KUNDE_NAME
    from NLB.SAP_CRM_STAMMDATEN_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- KWG Beziehungen
SCRM_KWG_B as (
    select *,
           'NLB_' || GP_NUMMER_1 as GNI_KUNDE1,
           'NLB_' || GP_NUMMER_2 as GNI_KUNDE2
    from NLB.SAP_CRM_KWG_BEZIEHUNGEN_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- KWG Stamm
SCRM_KWG_S as (
    select *,
           'NLB_' || GP_NUMMER as GNI_KUNDE,
           case
               when NAME1 is null and NAME2 is null
                   then null
               else NVL(NAME1, '') || NVL(NAME2, '')
               end             as KUNDE_NAME
    from NLB.SAP_CRM_KWG_STAMM_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- KRMZ
KRMZ as (
    select CUT_OFF_DATE,
           KUNDENNUMMER,
           'NLB_' || KUNDENNUMMER              as GNI_KUNDE,
           SUMMARY_TECHNISCHE_ID,
           STATUS,
           ASSETKLASSEN,
           NVL(SM.S_VALUE, RISKINDIKATOR_NAME) as RISKINDIKATOR_NAME,
           RISKINDIKATOR_TECHNISCHE_ID,
           RISKINDIKATOR_BESCHREIBUNG,
           RISKINDIKATOR_EINZELPRUEFUNG,
           RISKINDIKATOR_ASSETID,
           RISKINDIKATOR_IST_WERT,
           RISKINDIKATOR_EINHEIT,
           RISKINDIKATOR_FORMAT,
           RISKINDIKATOR_COMPARATOR,
           RISKINDIKATOR_SCHWELLENWERT_IK,
           RISKINDIKATOR_SCHWELLENWERT_UTP,
           RISKINDIKATOR_IK_SCHWELLENWERT_UEBERSCHRITTEN,
           RISKINDIKATOR_UTP_SCHWELLENWERT_UEBERSCHREITUNG,
           RISKINDIKATOR_STATUS,
           RISKINDIKATOR_ERSTELLT_AM,
           case
               when UPPER(RISKINDIKATOR_UTP_SCHWELLENWERT_UEBERSCHREITUNG) = 'JA'
                   -- Cast as decfloat for nice format
                   then RISKINDIKATOR_NAME || ' ' || RISKINDIKATOR_COMPARATOR || ROUND(DECFLOAT(RISKINDIKATOR_SCHWELLENWERT_UTP), 2)
               end                             as UTP_TRIGGER_UEBERSCHRITTEN,
           case
               when UPPER(RISKINDIKATOR_IK_SCHWELLENWERT_UEBERSCHRITTEN) = 'JA'
                   -- Cast as decfloat for nice format
                   then RISKINDIKATOR_NAME || ' ' || RISKINDIKATOR_COMPARATOR || ROUND(DECFLOAT(RISKINDIKATOR_SCHWELLENWERT_IK), 2)
               end                             as IK_TRIGGER_UEBERSCHRITTEN
    from NLB.KRMZ_RISK_INDICATOR_CURRENT K
             left join SMAP.KRMZ_RISKINDIKATOR_NAME SM on K.RISKINDIKATOR_NAME = SM.S_KEY
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- Filtern auf relevante Werte
KRMZ_FILTERED as (
    select *
    from KRMZ
    where UPPER(RISKINDIKATOR_STATUS) = 'FREIGEGEBEN'
      and UPPER(RISKINDIKATOR_NAME) in
          ('BAUKOSTENÜBERSCHREITUNG', 'BAUSTILLSTAND', 'DSCR', 'ICR', 'LTV', 'DEBT YIELD', 'VERZUG BAUBEGINN', 'VERZUG BAUFERTIGSTELLUNG')
),
-- Unique
KRMZ_UNQ as (
    select *
    from (
             select *,
                    ROW_NUMBER() over
                        (partition by KUNDENNUMMER, RISKINDIKATOR_ASSETID, RISKINDIKATOR_ERSTELLT_AM, RISKINDIKATOR_NAME) as RN,
                    DENSE_RANK() over
                        (partition by KUNDENNUMMER, RISKINDIKATOR_ASSETID, RISKINDIKATOR_ERSTELLT_AM, RISKINDIKATOR_NAME order by RISKINDIKATOR_IST_WERT asc)
                        +
                    DENSE_RANK() over
                        (partition by KUNDENNUMMER, RISKINDIKATOR_ASSETID, RISKINDIKATOR_ERSTELLT_AM, RISKINDIKATOR_NAME order by RISKINDIKATOR_IST_WERT desc)
                        - 1                                                                                               as COUNT_DISTINCT
             from KRMZ_FILTERED
         )
    where RN = 1
      and COUNT_DISTINCT = 1
      -- Order to aggregate consistently to Risk Indicator column order
    order by (
                 case
                     when UPPER(RISKINDIKATOR_NAME) = 'BAUKOSTENÜBERSCHREITUNG' then 0
                     when UPPER(RISKINDIKATOR_NAME) = 'BAUSTILLSTAND' then 1
                     when UPPER(RISKINDIKATOR_NAME) = 'DSCR' then 2
                     when UPPER(RISKINDIKATOR_NAME) = 'ICR' then 3
                     when UPPER(RISKINDIKATOR_NAME) = 'LTV' then 4
                     when UPPER(RISKINDIKATOR_NAME) = 'DEBT YIELD' then 5
                     when UPPER(RISKINDIKATOR_NAME) = 'VERZUG BAUBEGINN' then 6
                     when UPPER(RISKINDIKATOR_NAME) = 'VERZUG BAUFERTIGSTELLUNG' then 7
                     else 99
                     end
                 )
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
---- Logik
-- Transponieren
KRMZ_AGG as (
    select CUT_OFF_DATE,
           KUNDENNUMMER,
           GNI_KUNDE,
           RISKINDIKATOR_ASSETID,
           SUM(case when UPPER(RISKINDIKATOR_NAME) = 'BAUKOSTENÜBERSCHREITUNG' then RISKINDIKATOR_IST_WERT end)  as BAUKOSTENUEBERSCHREITUNG,
           SUM(case when UPPER(RISKINDIKATOR_NAME) = 'BAUSTILLSTAND' then RISKINDIKATOR_IST_WERT end)            as BAUSTILLSTAND,
           SUM(case when UPPER(RISKINDIKATOR_NAME) = 'DSCR' then RISKINDIKATOR_IST_WERT end)                     as DSCR,
           SUM(case when UPPER(RISKINDIKATOR_NAME) = 'ICR' then RISKINDIKATOR_IST_WERT end)                      as ICR,
           SUM(case when UPPER(RISKINDIKATOR_NAME) = 'LTV' then RISKINDIKATOR_IST_WERT end)                      as LTV,
           SUM(case when UPPER(RISKINDIKATOR_NAME) = 'DEBT YIELD' then RISKINDIKATOR_IST_WERT end)               as DEBT_YIELD,
           SUM(case when UPPER(RISKINDIKATOR_NAME) = 'VERZUG BAUBEGINN' then RISKINDIKATOR_IST_WERT end)         as VERZUG_BAUBEGINN,
           SUM(case when UPPER(RISKINDIKATOR_NAME) = 'VERZUG BAUFERTIGSTELLUNG' then RISKINDIKATOR_IST_WERT end) as VERZUG_BAUFERTIGSTELLUNG,
           LISTAGG(UTP_TRIGGER_UEBERSCHRITTEN, ', ')                                                             as UTP_TRIGGER_UEBERSCHRITTEN,
           LISTAGG(IK_TRIGGER_UEBERSCHRITTEN, ', ')                                                              as IK_TRIGGER_UEBERSCHRITTEN,
           LISTAGG(RISKINDIKATOR_NAME, ', ')                                                                     as RISKINDIKATOR_NAME,
           LISTAGG(RISKINDIKATOR_EINHEIT, ', ')                                                                  as RISKINDIKATOR_EINHEIT,
           LISTAGG(RISKINDIKATOR_COMPARATOR, ', ')                                                               as RISKINDIKATOR_COMPARATOR,
           -- Cast as decfloat for nice format
           LISTAGG(cast(ROUND(DECFLOAT(RISKINDIKATOR_SCHWELLENWERT_IK), 2) as VARCHAR(500)), ', ')               as RISKINDIKATOR_SCHWELLENWERT_IK,
           LISTAGG(cast(ROUND(DECFLOAT(RISKINDIKATOR_SCHWELLENWERT_UTP), 2) as VARCHAR(500)), ', ')              as RISKINDIKATOR_SCHWELLENWERT_UTP,
           LISTAGG(RISKINDIKATOR_UTP_SCHWELLENWERT_UEBERSCHREITUNG, ', ')                                        as RISKINDIKATOR_UTP_SCHWELLENWERT_UEBERSCHREITUNG,
           LISTAGG(RISKINDIKATOR_IK_SCHWELLENWERT_UEBERSCHRITTEN, ', ')                                          as RISKINDIKATOR_IK_SCHWELLENWERT_UEBERSCHRITTEN,
           LISTAGG(ASSETKLASSEN, ', ')                                                                           as ASSETKLASSEN
    from KRMZ_UNQ
    group by CUT_OFF_DATE, KUNDENNUMMER, GNI_KUNDE, RISKINDIKATOR_ASSETID
),
-- Alles zusammenführen
FULL_FAC as (
    select distinct A.CUT_OFF_DATE,
                    A.KUNDENNUMMER,
                    NVL(G.KUNDE_NAME, E.KUNDE_NAME)                   as SAPCRM_PARTNER_NAME,
                    case
                        when A.KUNDENNUMMER like '%K%' and B.GP_NUMMER_2 is null and D.GP_NUMMER_2 is null
                            then null
                        when B.GP_NUMMER_2 is not null and D.GP_NUMMER_2 is null
                            then NVL(B.GNI_KUNDE2, A.GNI_KUNDE)
                        when D.GP_NUMMER_2 is not null and B.GP_NUMMER_2 is null
                            then NVL(D.GNI_KUNDE2, A.GNI_KUNDE)
                        else A.GNI_KUNDE
                        end                                           as GNI_KUNDE,
                    H.KUNDE_NAME                                      as SAPCRM_KUNDE_NAME,
                    D.GP_NUMMER_1                                     as SAPCRM_KREDITNEHMER_GVK,
                    I.KUNDE_NAME                                      as SAPCRM_KREDITNEHMER_GVK_NAME,
                    case
                        when (B.HAUPTZUORDNUNG = 'X' or D.HAUPTZUORDNUNG = 'X') and A.KUNDENNUMMER like '%K%'
                            then true
                        when (B.HAUPTZUORDNUNG is null and D.HAUPTZUORDNUNG is null) and A.KUNDENNUMMER like '%K%'
                            then false
                        end                                           as SAPCRM_HAUPTZUORDNUNG_KREDITNEHMER_ZU_KUNDE,
                    A.RISKINDIKATOR_ASSETID,
                    J.FACILITY_ID,
                    A.ASSETKLASSEN,
                    A.BAUKOSTENUEBERSCHREITUNG,
                    A.BAUSTILLSTAND,
                    A.DSCR,
                    A.ICR,
                    A.LTV,
                    A.DEBT_YIELD,
                    A.VERZUG_BAUBEGINN,
                    A.VERZUG_BAUFERTIGSTELLUNG,
                    A.UTP_TRIGGER_UEBERSCHRITTEN,
                    A.IK_TRIGGER_UEBERSCHRITTEN,
                    A.RISKINDIKATOR_NAME,
                    A.RISKINDIKATOR_UTP_SCHWELLENWERT_UEBERSCHREITUNG as RISKINDIKATOR_UTP_SCHWELLENWERT_UEBERSCHRITTEN,
                    A.RISKINDIKATOR_IK_SCHWELLENWERT_UEBERSCHRITTEN,
                    A.RISKINDIKATOR_EINHEIT,
                    A.RISKINDIKATOR_COMPARATOR,
                    A.RISKINDIKATOR_SCHWELLENWERT_UTP,
                    A.RISKINDIKATOR_SCHWELLENWERT_IK
    from KRMZ_AGG A
             --
             left join
         (select GP_NUMMER_1,
                 GP_NUMMER_2,
                 GNI_KUNDE1,
                 GNI_KUNDE2,
                 HAUPTZUORDNUNG
          from SCRM_KWG_B
          where GRUPPENTYP_1 = 'K'
            and GRUPPENTYP_2 = 'C'
         ) B on A.GNI_KUNDE = B.GNI_KUNDE1
             --
             left join
         (select GP_NUMMER_1,
                 GP_NUMMER_2,
                 GNI_KUNDE1,
                 GNI_KUNDE2,
                 HAUPTZUORDNUNG
          from SCRM_KWG_B
          where GRUPPENTYP_1 = 'E'
         ) C on A.GNI_KUNDE = C.GNI_KUNDE1
             --
             left join
         (select GP_NUMMER_1,
                 GP_NUMMER_2,
                 GNI_KUNDE1,
                 GNI_KUNDE2,
                 HAUPTZUORDNUNG
          from SCRM_KWG_B
          where GRUPPENTYP_1 = 'K'
            and GRUPPENTYP_2 = 'C'
         ) D on C.GNI_KUNDE2 = D.GNI_KUNDE1
             --
             left join
         SCRM_KWG_S G on A.GNI_KUNDE = G.GNI_KUNDE
             --
             left join
         SCRM_STM E on A.GNI_KUNDE = E.GNI_KUNDE
             --
             left join
         SCRM_STM H on B.GNI_KUNDE2 = H.GNI_KUNDE or D.GNI_KUNDE2 = H.GNI_KUNDE
             --
             left join
         SCRM_KWG_S I on D.GNI_KUNDE1 = I.GNI_KUNDE
             --
             left join
         LIQ_PD F on A.RISKINDIKATOR_ASSETID = F.DEAL
             --
             left join
         PWC_FAC J on F.FACILITY = J.KONTONUMMER or F.OUTSTANDING = J.KONTONUMMER or A.RISKINDIKATOR_ASSETID = J.KONTONUMMER
),
-- Für Kunden für die in keiner Zeile eine RISKINDIKATOR_ASSETID existiert, an alle Facility IDs des Kunden in PWC mappen
ZUORDN as (
    select distinct A.CUT_OFF_DATE,
                    A.KUNDENNUMMER                                   as KRMZ_KUNDENNUMMER,
                    A.SAPCRM_PARTNER_NAME                            as KRMZ_SAPCRM_PARTNER_NAME,
                    A.GNI_KUNDE                                      as KRMZ_GNI_KUNDE,
                    A.SAPCRM_KUNDE_NAME                              as KRMZ_SAPCRM_KUNDE_NAME,
                    A.SAPCRM_KREDITNEHMER_GVK                        as KRMZ_SAPCRM_KREDITNEHMER_GVK,
                    A.SAPCRM_KREDITNEHMER_GVK_NAME                   as KRMZ_SAPCRM_KREDITNEHMER_GVK_NAME,
                    case
                        -- SAPCRM_HAUPTZUORDNUNG_KREDITNEHMER_ZU_KUNDE extra Bedingung
                        when A.KUNDENNUMMER is not null and A.GNI_KUNDE is not null
                            then A.SAPCRM_HAUPTZUORDNUNG_KREDITNEHMER_ZU_KUNDE
                        end                                          as KRMZ_SAPCRM_HAUPTZUORDNUNG_KREDITNEHMER_ZU_KUNDE,
                    A.RISKINDIKATOR_ASSETID                          as KRMZ_RISKINDIKATOR_ASSETID,
                    case
                        when A.RISKINDIKATOR_ASSETID is null
                            and not EXISTS(select 1 from FULL_FAC A2 where A.GNI_KUNDE = A2.GNI_KUNDE and A2.RISKINDIKATOR_ASSETID is not null)
                            -- Kunde hat insgesamt keine Asset ID
                            then J.FACILITY_ID
                        else A.FACILITY_ID
                        end                                          as KRMZ_FACILITY_ID,
                    A.ASSETKLASSEN                                   as KRMZ_ASSETKLASSEN,
                    A.BAUKOSTENUEBERSCHREITUNG                       as KRMZ_BAUKOSTENUEBERSCHREITUNG,
                    A.BAUSTILLSTAND                                  as KRMZ_BAUSTILLSTAND,
                    A.DSCR                                           as KRMZ_DSCR,
                    A.ICR                                            as KRMZ_ICR,
                    A.LTV                                            as KRMZ_LTV,
                    A.DEBT_YIELD                                     as KRMZ_DEBT_YIELD,
                    A.VERZUG_BAUBEGINN                               as KRMZ_VERZUG_BAUBEGINN,
                    A.VERZUG_BAUFERTIGSTELLUNG                       as KRMZ_VERZUG_BAUFERTIGSTELLUNG,
                    A.UTP_TRIGGER_UEBERSCHRITTEN                     as KRMZ_UTP_TRIGGER_UEBERSCHRITTEN,
                    A.IK_TRIGGER_UEBERSCHRITTEN                      as KRMZ_IK_TRIGGER_UEBERSCHRITTEN,
                    A.RISKINDIKATOR_NAME                             as KRMZ_RISKINDIKATOR_NAME,
                    A.RISKINDIKATOR_UTP_SCHWELLENWERT_UEBERSCHRITTEN as KRMZ_RISKINDIKATOR_UTP_SCHWELLENWERT_UEBERSCHRITTEN,
                    A.RISKINDIKATOR_IK_SCHWELLENWERT_UEBERSCHRITTEN  as KRMZ_RISKINDIKATOR_IK_SCHWELLENWERT_UEBERSCHRITTEN,
                    A.RISKINDIKATOR_EINHEIT                          as KRMZ_RISKINDIKATOR_EINHEIT,
                    A.RISKINDIKATOR_COMPARATOR                       as KRMZ_RISKINDIKATOR_COMPARATOR,
                    A.RISKINDIKATOR_SCHWELLENWERT_UTP                as KRMZ_RISKINDIKATOR_SCHWELLENWERT_UTP,
                    A.RISKINDIKATOR_SCHWELLENWERT_IK                 as KRMZ_RISKINDIKATOR_SCHWELLENWERT_IK
    from FULL_FAC A
             left join PWC_FAC J on A.GNI_KUNDE = J.GNI_KUNDE
),
-- Zum Schluss alle Zeilen raus, in denen FACILITY_ID = null aber eine Zeile mit selber RISKINDIKATOR_ASSETID existiert wo FACILITY_ID != null
FINAL as (
    select *
    from ZUORDN Z
    where KRMZ_FACILITY_ID is not null
       -- Wenn FACILITY_ID = null -> gibt es überhaupt eine Zeile mit FACILITY_ID != null
       or not EXISTS(select 1
                     from ZUORDN Z2
                     where Z.KRMZ_RISKINDIKATOR_ASSETID = Z2.KRMZ_RISKINDIKATOR_ASSETID
                       and Z2.KRMZ_FACILITY_ID is not null)
),
-- Gefiltert nach noetigen Datenfeldern + nullable
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        NULLIF(KRMZ_KUNDENNUMMER, null)                                   as KRMZ_KUNDENNUMMER,
        NULLIF(KRMZ_SAPCRM_PARTNER_NAME, null)                            as KRMZ_SAPCRM_PARTNER_NAME,
        NULLIF(KRMZ_GNI_KUNDE, null)                                      as KRMZ_GNI_KUNDE,
        NULLIF(KRMZ_SAPCRM_KUNDE_NAME, null)                              as KRMZ_SAPCRM_KUNDE_NAME,
        NULLIF(KRMZ_SAPCRM_KREDITNEHMER_GVK, null)                        as KRMZ_SAPCRM_KREDITNEHMER_GVK,
        NULLIF(KRMZ_SAPCRM_KREDITNEHMER_GVK_NAME, null)                   as KRMZ_SAPCRM_KREDITNEHMER_GVK_NAME,
        NULLIF(KRMZ_SAPCRM_HAUPTZUORDNUNG_KREDITNEHMER_ZU_KUNDE, null)    as KRMZ_SAPCRM_HAUPTZUORDNUNG_KREDITNEHMER_ZU_KUNDE,
        NULLIF(KRMZ_RISKINDIKATOR_ASSETID, null)                          as KRMZ_RISKINDIKATOR_ASSETID,
        NULLIF(KRMZ_FACILITY_ID, null)                                    as KRMZ_FACILITY_ID,
        NULLIF(KRMZ_ASSETKLASSEN, null)                                   as KRMZ_ASSETKLASSEN,
        NULLIF(KRMZ_BAUKOSTENUEBERSCHREITUNG, null)                       as KRMZ_BAUKOSTENUEBERSCHREITUNG,
        NULLIF(KRMZ_BAUSTILLSTAND, null)                                  as KRMZ_BAUSTILLSTAND,
        NULLIF(KRMZ_DSCR, null)                                           as KRMZ_DSCR,
        NULLIF(KRMZ_ICR, null)                                            as KRMZ_ICR,
        NULLIF(KRMZ_LTV, null)                                            as KRMZ_LTV,
        NULLIF(KRMZ_DEBT_YIELD, null)                                     as KRMZ_DEBT_YIELD,
        NULLIF(KRMZ_VERZUG_BAUBEGINN, null)                               as KRMZ_VERZUG_BAUBEGINN,
        NULLIF(KRMZ_VERZUG_BAUFERTIGSTELLUNG, null)                       as KRMZ_VERZUG_BAUFERTIGSTELLUNG,
        NULLIF(KRMZ_UTP_TRIGGER_UEBERSCHRITTEN, null)                     as KRMZ_UTP_TRIGGER_UEBERSCHRITTEN,
        NULLIF(KRMZ_IK_TRIGGER_UEBERSCHRITTEN, null)                      as KRMZ_IK_TRIGGER_UEBERSCHRITTEN,
        NULLIF(KRMZ_RISKINDIKATOR_NAME, null)                             as KRMZ_RISKINDIKATOR_NAME,
        NULLIF(KRMZ_RISKINDIKATOR_UTP_SCHWELLENWERT_UEBERSCHRITTEN, null) as KRMZ_RISKINDIKATOR_UTP_SCHWELLENWERT_UEBERSCHRITTEN,
        NULLIF(KRMZ_RISKINDIKATOR_IK_SCHWELLENWERT_UEBERSCHRITTEN, null)  as KRMZ_RISKINDIKATOR_IK_SCHWELLENWERT_UEBERSCHRITTEN,
        NULLIF(KRMZ_RISKINDIKATOR_EINHEIT, null)                          as KRMZ_RISKINDIKATOR_EINHEIT,
        NULLIF(KRMZ_RISKINDIKATOR_COMPARATOR, null)                       as KRMZ_RISKINDIKATOR_COMPARATOR,
        NULLIF(KRMZ_RISKINDIKATOR_SCHWELLENWERT_UTP, null)                as KRMZ_RISKINDIKATOR_SCHWELLENWERT_UTP,
        NULLIF(KRMZ_RISKINDIKATOR_SCHWELLENWERT_IK, null)                 as KRMZ_RISKINDIKATOR_SCHWELLENWERT_IK,
        -- Defaults
        CURRENT_USER                                                      as USER,
        CURRENT_TIMESTAMP                                                 as TIMESTAMP_LOAD
    from FINAL
)
select *
from FINAL_FILTERED;

-- CI START FOR ALL TAPES

-- Current-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_FACILITY_KRMZ_EBA_CURRENT');
create table AMC.TABLE_FACILITY_KRMZ_EBA_CURRENT like CALC.VIEW_FACILITY_KRMZ_EBA distribute by hash (KRMZ_FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_KRMZ_EBA_CURRENT_KRMZ_FACILITY_ID on AMC.TABLE_FACILITY_KRMZ_EBA_CURRENT (KRMZ_FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_FACILITY_KRMZ_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- Archiv-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_FACILITY_KRMZ_EBA_ARCHIVE');
create table AMC.TABLE_FACILITY_KRMZ_EBA_ARCHIVE like CALC.VIEW_FACILITY_KRMZ_EBA distribute by hash (KRMZ_FACILITY_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_KRMZ_EBA_ARCHIVE_KRMZ_FACILITY_ID on AMC.TABLE_FACILITY_KRMZ_EBA_ARCHIVE (KRMZ_FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_FACILITY_KRMZ_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_FACILITY_KRMZ_EBA_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_FACILITY_KRMZ_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------


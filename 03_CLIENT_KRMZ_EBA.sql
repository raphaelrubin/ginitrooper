-- View erstellen
drop view CALC.VIEW_CLIENT_KRMZ_EBA;
-- Satellitentabelle Customer EBA
create or replace view CALC.VIEW_CLIENT_KRMZ_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
---- Quelldaten
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
          ('BETRIEBSWIRTSCHAFTLICHE EIGENKAPITALQUOTE II', 'RATING BLSK/PI', 'FORBEARANCE', 'EK-QUOTE', 'AUSFALLQUOTE II', 'MERTON PD', 'BETRIEBSERGEBNISRENTABILITÄT',
           'CASH FLOW KENNZAHL 1', 'SONSTIGE IK-GRÜNDE', 'SCHULDENTILGUNGSDAUER', 'LLCR', 'LEVERAGE', 'VERZUGSTAGE', 'KAPITALDIENSTAUSLASTUNG')
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
                     when UPPER(RISKINDIKATOR_NAME) = 'BETRIEBSWIRTSCHAFTLICHE EIGENKAPITALQUOTE II' then 0
                     when UPPER(RISKINDIKATOR_NAME) = 'RATING BLSK/PI' then 1
                     when UPPER(RISKINDIKATOR_NAME) = 'FORBEARANCE' then 2
                     when UPPER(RISKINDIKATOR_NAME) = 'EK-QUOTE' then 3
                     when UPPER(RISKINDIKATOR_NAME) = 'AUSFALLQUOTE II' then 4
                     when UPPER(RISKINDIKATOR_NAME) = 'MERTON PD' then 5
                     when UPPER(RISKINDIKATOR_NAME) = 'BETRIEBSERGEBNISRENTABILITÄT' then 6
                     when UPPER(RISKINDIKATOR_NAME) = 'CASH FLOW KENNZAHL 1' then 7
                     when UPPER(RISKINDIKATOR_NAME) = 'SONSTIGE IK-GRÜNDE' then 8
                     when UPPER(RISKINDIKATOR_NAME) = 'SCHULDENTILGUNGSDAUER' then 9
                     when UPPER(RISKINDIKATOR_NAME) = 'LLCR' then 10
                     when UPPER(RISKINDIKATOR_NAME) = 'LEVERAGE' then 11
                     when UPPER(RISKINDIKATOR_NAME) = 'VERZUGSTAGE' then 12
                     when UPPER(RISKINDIKATOR_NAME) = 'KAPITALDIENSTAUSLASTUNG' then 13
                     else 99
                     end
                 )
),
---- Logik
-- Transponieren
KRMZ_AGG as (
    select CUT_OFF_DATE,
           KUNDENNUMMER,
           GNI_KUNDE,
           RISKINDIKATOR_ASSETID,
           SUM(case when UPPER(RISKINDIKATOR_NAME) = 'BETRIEBSWIRTSCHAFTLICHE EIGENKAPITALQUOTE II' then RISKINDIKATOR_IST_WERT end) as BETRIEBSWIRTSCHAFTLICHE_EK_QUOTE_II,
           SUM(case when UPPER(RISKINDIKATOR_NAME) = 'RATING BLSK/PI' then RISKINDIKATOR_IST_WERT end)                               as RATING_BLSK_PI,
           SUM(case when UPPER(RISKINDIKATOR_NAME) = 'FORBEARANCE' then RISKINDIKATOR_IST_WERT end)                                  as FORBEARANCE,
           SUM(case when UPPER(RISKINDIKATOR_NAME) = 'EK-QUOTE' then RISKINDIKATOR_IST_WERT end)                                     as EK_QUOTE,
           SUM(case when UPPER(RISKINDIKATOR_NAME) = 'AUSFALLQUOTE II' then RISKINDIKATOR_IST_WERT end)                              as AUSFALLQUOTE_II,
           SUM(case when UPPER(RISKINDIKATOR_NAME) = 'MERTON PD' then RISKINDIKATOR_IST_WERT end)                                    as MERTON_PD,
           SUM(case when UPPER(RISKINDIKATOR_NAME) = 'BETRIEBSERGEBNISRENTABILITÄT' then RISKINDIKATOR_IST_WERT end)                 as BETRIEBSERGEBNISRENTABILITAET,
           SUM(case when UPPER(RISKINDIKATOR_NAME) = 'CASH FLOW KENNZAHL 1' then RISKINDIKATOR_IST_WERT end)                         as CASH_FLOW_KENNZAHL_1,
           SUM(case when UPPER(RISKINDIKATOR_NAME) = 'SONSTIGE IK-GRÜNDE' then RISKINDIKATOR_IST_WERT end)                           as SONSTIGE_IK_GRUENDE,
           SUM(case when UPPER(RISKINDIKATOR_NAME) = 'SCHULDENTILGUNGSDAUER' then RISKINDIKATOR_IST_WERT end)                        as SCHULDENTILGUNGSDAUER,
           SUM(case when UPPER(RISKINDIKATOR_NAME) = 'LLCR' then RISKINDIKATOR_IST_WERT end)                                         as LLCR,
           SUM(case when UPPER(RISKINDIKATOR_NAME) = 'LEVERAGE' then RISKINDIKATOR_IST_WERT end)                                     as LEVERAGE,
           SUM(case when UPPER(RISKINDIKATOR_NAME) = 'VERZUGSTAGE' then RISKINDIKATOR_IST_WERT end)                                  as VERZUGSTAGE,
           SUM(case when UPPER(RISKINDIKATOR_NAME) = 'KAPITALDIENSTAUSLASTUNG' then RISKINDIKATOR_IST_WERT end)                      as KAPITALDIENSTAUSLASTUNG,
           LISTAGG(UTP_TRIGGER_UEBERSCHRITTEN, ', ')                                                                                 as UTP_TRIGGER_UEBERSCHRITTEN,
           LISTAGG(IK_TRIGGER_UEBERSCHRITTEN, ', ')                                                                                  as IK_TRIGGER_UEBERSCHRITTEN,
           LISTAGG(RISKINDIKATOR_NAME, ', ')                                                                                         as RISKINDIKATOR_NAME,
           LISTAGG(RISKINDIKATOR_EINHEIT, ', ')                                                                                      as RISKINDIKATOR_EINHEIT,
           LISTAGG(RISKINDIKATOR_COMPARATOR, ', ')                                                                                   as RISKINDIKATOR_COMPARATOR,
           LISTAGG(cast(ROUND(DECFLOAT(RISKINDIKATOR_SCHWELLENWERT_IK), 2) as VARCHAR(500)), ', ')                                   as RISKINDIKATOR_SCHWELLENWERT_IK,
           LISTAGG(cast(ROUND(DECFLOAT(RISKINDIKATOR_SCHWELLENWERT_UTP), 2) as VARCHAR(500)), ', ')                                  as RISKINDIKATOR_SCHWELLENWERT_UTP,
           LISTAGG(RISKINDIKATOR_UTP_SCHWELLENWERT_UEBERSCHREITUNG, ', ')                                                            as RISKINDIKATOR_UTP_SCHWELLENWERT_UEBERSCHREITUNG,
           LISTAGG(RISKINDIKATOR_IK_SCHWELLENWERT_UEBERSCHRITTEN, ', ')                                                              as RISKINDIKATOR_IK_SCHWELLENWERT_UEBERSCHRITTEN,
           LISTAGG(ASSETKLASSEN, ', ')                                                                                               as ASSETKLASSEN
    from KRMZ_UNQ
    group by CUT_OFF_DATE, KUNDENNUMMER, GNI_KUNDE, RISKINDIKATOR_ASSETID
),
-- Alles zusammenführen
LOGIC as (
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
                    A.ASSETKLASSEN,
                    A.BETRIEBSWIRTSCHAFTLICHE_EK_QUOTE_II,
                    A.RATING_BLSK_PI,
                    A.FORBEARANCE,
                    A.EK_QUOTE,
                    A.AUSFALLQUOTE_II,
                    A.MERTON_PD,
                    A.CASH_FLOW_KENNZAHL_1,
                    A.SONSTIGE_IK_GRUENDE,
                    A.SCHULDENTILGUNGSDAUER,
                    A.LLCR,
                    A.LEVERAGE,
                    A.VERZUGSTAGE,
                    A.KAPITALDIENSTAUSLASTUNG,
                    A.BETRIEBSERGEBNISRENTABILITAET,
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
),
-- SAPCRM_HAUPTZUORDNUNG_KREDITNEHMER_ZU_KUNDE extra Bedingung
ZUORDN as (
    select CUT_OFF_DATE,
           KUNDENNUMMER                                   as KRMZ_KUNDENNUMMER,
           SAPCRM_PARTNER_NAME                            as KRMZ_SAPCRM_PARTNER_NAME,
           GNI_KUNDE                                      as KRMZ_GNI_KUNDE,
           SAPCRM_KUNDE_NAME                              as KRMZ_SAPCRM_KUNDE_NAME,
           SAPCRM_KREDITNEHMER_GVK                        as KRMZ_SAPCRM_KREDITNEHMER_GVK,
           SAPCRM_KREDITNEHMER_GVK_NAME                   as KRMZ_SAPCRM_KREDITNEHMER_GVK_NAME,
           case
               when KUNDENNUMMER is not null and GNI_KUNDE is not null
                   then SAPCRM_HAUPTZUORDNUNG_KREDITNEHMER_ZU_KUNDE
               end                                        as KRMZ_SAPCRM_HAUPTZUORDNUNG_KREDITNEHMER_ZU_KUNDE,
           RISKINDIKATOR_ASSETID                          as KRMZ_RISKINDIKATOR_ASSETID,
           ASSETKLASSEN                                   as KRMZ_ASSETKLASSEN,
           BETRIEBSWIRTSCHAFTLICHE_EK_QUOTE_II            as KRMZ_BETRIEBSWIRTSCHAFTLICHE_EK_QUOTE_II,
           RATING_BLSK_PI                                 as KRMZ_RATING_BLSK_PI,
           FORBEARANCE                                    as KRMZ_FORBEARANCE,
           EK_QUOTE                                       as KRMZ_EK_QUOTE,
           AUSFALLQUOTE_II                                as KRMZ_AUSFALLQUOTE_II,
           MERTON_PD                                      as KRMZ_MERTON_PD,
           BETRIEBSERGEBNISRENTABILITAET                  as KRMZ_BETRIEBSERGEBNISRENTABILITAET,
           CASH_FLOW_KENNZAHL_1                           as KRMZ_CASH_FLOW_KENNZAHL_1,
           SONSTIGE_IK_GRUENDE                            as KRMZ_SONSTIGE_IK_GRUENDE,
           SCHULDENTILGUNGSDAUER                          as KRMZ_SCHULDENTILGUNGSDAUER,
           LLCR                                           as KRMZ_LLCR,
           LEVERAGE                                       as KRMZ_LEVERAGE,
           VERZUGSTAGE                                    as KRMZ_VERZUGSTAGE,
           KAPITALDIENSTAUSLASTUNG                        as KRMZ_KAPITALDIENSTAUSLASTUNG,
           UTP_TRIGGER_UEBERSCHRITTEN                     as KRMZ_UTP_TRIGGER_UEBERSCHRITTEN,
           IK_TRIGGER_UEBERSCHRITTEN                      as KRMZ_IK_TRIGGER_UEBERSCHRITTEN,
           RISKINDIKATOR_NAME                             as KRMZ_RISKINDIKATOR_NAME,
           RISKINDIKATOR_UTP_SCHWELLENWERT_UEBERSCHRITTEN as KRMZ_RISKINDIKATOR_UTP_SCHWELLENWERT_UEBERSCHRITTEN,
           RISKINDIKATOR_IK_SCHWELLENWERT_UEBERSCHRITTEN  as KRMZ_RISKINDIKATOR_IK_SCHWELLENWERT_UEBERSCHRITTEN,
           RISKINDIKATOR_EINHEIT                          as KRMZ_RISKINDIKATOR_EINHEIT,
           RISKINDIKATOR_COMPARATOR                       as KRMZ_RISKINDIKATOR_COMPARATOR,
           RISKINDIKATOR_SCHWELLENWERT_UTP                as KRMZ_RISKINDIKATOR_SCHWELLENWERT_UTP,
           RISKINDIKATOR_SCHWELLENWERT_IK                 as KRMZ_RISKINDIKATOR_SCHWELLENWERT_IK
    from LOGIC
),
---- Filter auf CUSTOMER_EBA mit Vermeidung zyklischer Abhängigkeiten
PWC_CUST as (
    select distinct CLIENT_ID_TXT as GNI_KUNDE
    from CALC.SWITCH_CLIENT_ACCOUNTHOLDER_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- Einschränken auf CUSTOMER_EBA
FINAL as (
    select A.*
    from ZUORDN A
             inner join PWC_CUST PWC on PWC.GNI_KUNDE = A.KRMZ_GNI_KUNDE
),
-- Gefiltert nach noetigen Datenfeldern
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        KRMZ_KUNDENNUMMER,
        KRMZ_SAPCRM_PARTNER_NAME,
        KRMZ_GNI_KUNDE,
        KRMZ_SAPCRM_KUNDE_NAME,
        KRMZ_SAPCRM_KREDITNEHMER_GVK,
        KRMZ_SAPCRM_KREDITNEHMER_GVK_NAME,
        KRMZ_SAPCRM_HAUPTZUORDNUNG_KREDITNEHMER_ZU_KUNDE,
        KRMZ_RISKINDIKATOR_ASSETID,
        KRMZ_ASSETKLASSEN,
        KRMZ_BETRIEBSWIRTSCHAFTLICHE_EK_QUOTE_II,
        KRMZ_RATING_BLSK_PI,
        KRMZ_FORBEARANCE,
        KRMZ_EK_QUOTE,
        KRMZ_AUSFALLQUOTE_II,
        KRMZ_MERTON_PD,
        KRMZ_BETRIEBSERGEBNISRENTABILITAET,
        KRMZ_CASH_FLOW_KENNZAHL_1,
        KRMZ_SONSTIGE_IK_GRUENDE,
        KRMZ_SCHULDENTILGUNGSDAUER,
        KRMZ_LLCR,
        KRMZ_LEVERAGE,
        KRMZ_VERZUGSTAGE,
        KRMZ_KAPITALDIENSTAUSLASTUNG,
        KRMZ_UTP_TRIGGER_UEBERSCHRITTEN,
        KRMZ_IK_TRIGGER_UEBERSCHRITTEN,
        KRMZ_RISKINDIKATOR_NAME,
        KRMZ_RISKINDIKATOR_UTP_SCHWELLENWERT_UEBERSCHRITTEN,
        KRMZ_RISKINDIKATOR_IK_SCHWELLENWERT_UEBERSCHRITTEN,
        KRMZ_RISKINDIKATOR_EINHEIT,
        KRMZ_RISKINDIKATOR_COMPARATOR,
        KRMZ_RISKINDIKATOR_SCHWELLENWERT_UTP,
        KRMZ_RISKINDIKATOR_SCHWELLENWERT_IK,
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
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_CLIENT_KRMZ_EBA_CURRENT');
create table AMC.TABLE_CLIENT_KRMZ_EBA_CURRENT like CALC.VIEW_CLIENT_KRMZ_EBA distribute by hash (KRMZ_GNI_KUNDE) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CLIENT_KRMZ_EBA_CURRENT_KRMZ_GNI_KUNDE on AMC.TABLE_CLIENT_KRMZ_EBA_CURRENT (KRMZ_GNI_KUNDE);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_CLIENT_KRMZ_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- Archiv-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_CLIENT_KRMZ_EBA_ARCHIVE');
create table AMC.TABLE_CLIENT_KRMZ_EBA_ARCHIVE like CALC.VIEW_CLIENT_KRMZ_EBA distribute by hash (KRMZ_GNI_KUNDE) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CLIENT_KRMZ_EBA_ARCHIVE_KRMZ_GNI_KUNDE on AMC.TABLE_CLIENT_KRMZ_EBA_ARCHIVE (KRMZ_GNI_KUNDE);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_CLIENT_KRMZ_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_CLIENT_KRMZ_EBA_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_CLIENT_KRMZ_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------


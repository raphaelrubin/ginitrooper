-- View erstellen
drop view CALC.VIEW_CLIENT_ELWISS_EBA;
-- Satellitentabelle Customer EBA
create or replace view CALC.VIEW_CLIENT_ELWISS_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
---- Quelldaten
ELWI as (
    select *,
           'NLB_' || BUSINESS_PARTNER_NUMBER as GNI_KUNDE
    from NLB.ELWISS_SIGNAL_MESSAGES_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
      and UPPER(INDICATOR) = 'TRUE'
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
-- Alles zusammenführen
LOGIC as (
    select A.CUT_OFF_DATE,
           A.BUSINESS_PARTNER_NUMBER,
           A.BUSINESS_PARTNER_NAME,
           case
               when A.BUSINESS_PARTNER_NUMBER like '%K%' and B.GP_NUMMER_2 is null and E.GP_NUMMER_2 is null
                   then null
               else NVL(B.GNI_KUNDE2, E.GNI_KUNDE2, A.GNI_KUNDE)
               end                         as GNI_KUNDE,
           NVL(C.KUNDE_NAME, G.KUNDE_NAME) as SAPCRM_KUNDE_NAME,
           D.GP_NUMMER_2                   as SAPCRM_KREDITNEHMER_GVK,
           F.KUNDE_NAME                    as SAPCRM_KREDITNEHMER_GVK_NAME,
           case
               when (B.HAUPTZUORDNUNG = 'X' or E.HAUPTZUORDNUNG = 'X') and A.BUSINESS_PARTNER_NUMBER like '%K%'
                   then true
               when (B.HAUPTZUORDNUNG is null and E.HAUPTZUORDNUNG is null) and A.BUSINESS_PARTNER_NUMBER like '%K%'
                   then false
               end                         as SAPCRM_HAUPTZUORDNUNG_KREDITNEHMER_ZU_KUNDE,
           A.TYPE,
           A.CREATED_ON,
           A.HANDLING_ACTION_DE,
           A.HANDLING_ACTION_EN,
           A.HANDLING_ACTION_PERFORMED_ON,
           A.INDICATOR,
           A.INDICATOR_DE,
           A.INDICATOR_DESCRIPTION_DE,
           A.INDICATOR_EN,
           A.INDICATOR_DESCRIPTION_EN
    from ELWI A
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
         SCRM_STM C on B.GNI_KUNDE2 = C.GNI_KUNDE
             --
             left join
         (select GP_NUMMER_1,
                 GP_NUMMER_2,
                 GNI_KUNDE1,
                 GNI_KUNDE2,
                 HAUPTZUORDNUNG
          from SCRM_KWG_B
          where GRUPPENTYP_1 = 'E'
         ) D on A.GNI_KUNDE = D.GNI_KUNDE1
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
         ) E
         on D.GNI_KUNDE2 = E.GNI_KUNDE1
             --
             left join
         SCRM_KWG_S F on E.GNI_KUNDE1 = F.GNI_KUNDE
             --
             left join
         SCRM_STM G on E.GNI_KUNDE2 = G.GNI_KUNDE
),
-- SAPCRM_HAUPTZUORDNUNG_KREDITNEHMER_ZU_KUNDE extra Bedingung
ZUORDN as (
    select CUT_OFF_DATE,
           BUSINESS_PARTNER_NUMBER      as ELWISS_BUSINESS_PARTNER_NUMBER,
           BUSINESS_PARTNER_NAME        as ELWISS_BUSINESS_PARTNER_NAME,
           GNI_KUNDE                    as ELWISS_GNI_KUNDE,
           SAPCRM_KUNDE_NAME            as ELWISS_SAPCRM_KUNDE_NAME,
           SAPCRM_KREDITNEHMER_GVK      as ELWISS_SAPCRM_KREDITNEHMER_GVK,
           SAPCRM_KREDITNEHMER_GVK_NAME as ELWISS_SAPCRM_KREDITNEHMER_GVK_NAME,
           case
               when BUSINESS_PARTNER_NUMBER is not null and GNI_KUNDE is not null
                   then SAPCRM_HAUPTZUORDNUNG_KREDITNEHMER_ZU_KUNDE
               end                      as ELWISS_SAPCRM_HAUPTZUORDNUNG_KREDITNEHMER_ZU_KUNDE,
           TYPE                         as ELWISS_TYPE,
           CREATED_ON                   as ELWISS_CREATED_ON,
           INDICATOR                    as ELWISS_INDICATOR,
           INDICATOR_DE                 as ELWISS_INDICATOR_DE,
           INDICATOR_DESCRIPTION_DE     as ELWISS_INDICATOR_DESCRIPTION_DE,
           INDICATOR_EN                 as ELWISS_INDICATOR_EN,
           INDICATOR_DESCRIPTION_EN     as ELWISS_INDICATOR_DESCRIPTION_EN,
           HANDLING_ACTION_DE           as ELWISS_HANDLING_ACTION_DE,
           HANDLING_ACTION_EN           as ELWISS_HANDLING_ACTION_EN,
           HANDLING_ACTION_PERFORMED_ON as ELWISS_HANDLING_ACTION_PERFORMED_ON
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
             inner join PWC_CUST PWC on PWC.GNI_KUNDE = A.ELWISS_GNI_KUNDE
),
-- Gefiltert nach noetigen Datenfeldern
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        ELWISS_BUSINESS_PARTNER_NUMBER,
        ELWISS_BUSINESS_PARTNER_NAME,
        ELWISS_GNI_KUNDE,
        ELWISS_SAPCRM_KUNDE_NAME,
        ELWISS_SAPCRM_KREDITNEHMER_GVK,
        ELWISS_SAPCRM_KREDITNEHMER_GVK_NAME,
        ELWISS_SAPCRM_HAUPTZUORDNUNG_KREDITNEHMER_ZU_KUNDE,
        ELWISS_TYPE,
        ELWISS_CREATED_ON,
        ELWISS_INDICATOR,
        ELWISS_INDICATOR_DE,
        ELWISS_INDICATOR_DESCRIPTION_DE,
        ELWISS_INDICATOR_EN,
        ELWISS_INDICATOR_DESCRIPTION_EN,
        ELWISS_HANDLING_ACTION_DE,
        ELWISS_HANDLING_ACTION_EN,
        ELWISS_HANDLING_ACTION_PERFORMED_ON,
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
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_CLIENT_ELWISS_EBA_CURRENT');
create table AMC.TABLE_CLIENT_ELWISS_EBA_CURRENT like CALC.VIEW_CLIENT_ELWISS_EBA distribute by hash (ELWISS_GNI_KUNDE) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CLIENT_ELWISS_EBA_CURRENT_ELWISS_GNI_KUNDE on AMC.TABLE_CLIENT_ELWISS_EBA_CURRENT (ELWISS_GNI_KUNDE);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_CLIENT_ELWISS_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- Archiv-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_CLIENT_ELWISS_EBA_ARCHIVE');
create table AMC.TABLE_CLIENT_ELWISS_EBA_ARCHIVE like CALC.VIEW_CLIENT_ELWISS_EBA distribute by hash (ELWISS_GNI_KUNDE) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CLIENT_ELWISS_EBA_ARCHIVE_ELWISS_GNI_KUNDE on AMC.TABLE_CLIENT_ELWISS_EBA_ARCHIVE (ELWISS_GNI_KUNDE);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_CLIENT_ELWISS_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_CLIENT_ELWISS_EBA_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_CLIENT_ELWISS_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------


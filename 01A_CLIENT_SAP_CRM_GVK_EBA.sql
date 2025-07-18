-- View erstellen
drop view CALC.VIEW_CLIENT_SAP_CRM_GVK_EBA;
-- Satellitentabelle Customer EBA (nicht eingeschränkt um gesamte GVK abzubilden)
create or replace view CALC.VIEW_CLIENT_SAP_CRM_GVK_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
-- Stammdaten
SCRM_STM as (
    select CUT_OFF_DATE,
           GP_NUMMER,
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
    select CUT_OFF_DATE,
           GP_NUMMER_1,
           'NLB_' || GP_NUMMER_1 as GNI_KUNDE1,
           GRUPPENTYP_1,
           GRUPPENTYP_2,
           GP_NUMMER_2,
           'NLB_' || GP_NUMMER_2 as GNI_KUNDE2,
           BEZIEHUNGSTYP,
           BEZIEHUNGSART,
           HAUPTZUORDNUNG,
           REFERENZSCHULDNER,
           REFERENZCODE
    from NLB.SAP_CRM_KWG_BEZIEHUNGEN_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- KWG Stamm
SCRM_KWG_S as (
    select *,
           case
               when NAME1 is null and NAME2 is null
                   then null
               else NVL(NAME1, '') || NVL(NAME2, '')
               end as KUNDE_NAME
    from NLB.SAP_CRM_KWG_STAMM_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- Daten zusammenführen
FINAL as (
    select A.CUT_OFF_DATE,
           E.GNI_KUNDE2                as SAP_CRM_GNI_KUNDE,
           G.KUNDE_NAME                as SAP_CRM_KUNDE_NAME,
           A.GP_NUMMER_1               as SAP_CRM_GVK,
           B.NAME1 || NVL(B.NAME2, '') as SAP_CRM_GVK_NAME,
           C.GP_NUMMER_2               as SAP_CRM_GVK_SPITZE,
           D.NAME1 || NVL(D.NAME2, '') as SAP_CRM_GVK_SPITZE_NAME,
           A.GP_NUMMER_2               as SAP_CRM_GVK_KREDITNEHMER,
           F.KUNDE_NAME                as SAP_CRM_GVK_KREDITNEHMER_NAME,
           case
               when E.HAUPTZUORDNUNG = 'X'
                   then true
               else false
               end                     as SAP_CRM_HAUPTZUORDNUNG_GVK_KREDITNEHMER_ZU_KUNDE,
           case
               when C.GP_NUMMER_2 = A.GP_NUMMER_2
                   then true
               else false
               end                     as SAP_CRM_GVK_SPITZE_FLAG,
           A.REFERENZSCHULDNER         as SAP_CRM_GVK_KREDITNEHMER_REFERENZSCHULDNER,
           H.KUNDE_NAME                as SAP_CRM_GVK_KREDITNEHMER_REFERENZSCHULDNER_NAME,
           SM_RC.S_VALUE               as SAP_CRM_GVK_REFERENZCODE
    from (select CUT_OFF_DATE,
                 GP_NUMMER_1,
                 GP_NUMMER_2,
                 REFERENZSCHULDNER,
                 REFERENZCODE
          from SCRM_KWG_B
          where GRUPPENTYP_1 = 'E'
         ) A
             --
             left join
         (select NAME1,
                 NAME2,
                 GP_NUMMER
          from SCRM_KWG_S
         ) B on A.GP_NUMMER_1 = B.GP_NUMMER
             --
             left join
         (select GP_NUMMER_1,
                 GP_NUMMER_2
          from SCRM_KWG_B
          where BEZIEHUNGSTYP = 'ZGP047'
            and BEZIEHUNGSART = '0098'
         ) C on A.GP_NUMMER_1 = C.GP_NUMMER_1
             --
             left join
         (select NAME1,
                 NAME2,
                 GP_NUMMER
          from SCRM_KWG_S
         ) D on C.GP_NUMMER_2 = D.GP_NUMMER
             --
             left join
         (select GP_NUMMER_1,
                 GP_NUMMER_2,
                 GNI_KUNDE2,
                 HAUPTZUORDNUNG
          from SCRM_KWG_B
          where GRUPPENTYP_1 = 'K'
            and GRUPPENTYP_2 = 'C'
         ) E on A.GP_NUMMER_2 = E.GP_NUMMER_1
             --
             left join
         SCRM_KWG_S F on A.GP_NUMMER_2 = F.GP_NUMMER
             --
             left join
         SCRM_STM G on E.GNI_KUNDE2 = G.GNI_KUNDE
             --
             left join
         SCRM_KWG_S H on A.REFERENZSCHULDNER = H.GP_NUMMER
             -- SMAPs
             left join
         SMAP.SAP_CRM_REFERENZCODE SM_RC on A.REFERENZCODE = SM_RC.S_KEY
),
-- Gefiltert nach noetigen Datenfeldern
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        SAP_CRM_GNI_KUNDE,
        SAP_CRM_KUNDE_NAME,
        SAP_CRM_GVK,
        SAP_CRM_GVK_NAME,
        SAP_CRM_GVK_SPITZE,
        SAP_CRM_GVK_SPITZE_NAME,
        SAP_CRM_GVK_KREDITNEHMER,
        SAP_CRM_GVK_KREDITNEHMER_NAME,
        SAP_CRM_HAUPTZUORDNUNG_GVK_KREDITNEHMER_ZU_KUNDE,
        SAP_CRM_GVK_SPITZE_FLAG,
        SAP_CRM_GVK_KREDITNEHMER_REFERENZSCHULDNER,
        SAP_CRM_GVK_KREDITNEHMER_REFERENZSCHULDNER_NAME,
        SAP_CRM_GVK_REFERENZCODE,
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
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_CLIENT_SAP_CRM_GVK_EBA_CURRENT');
create table AMC.TABLE_CLIENT_SAP_CRM_GVK_EBA_CURRENT like CALC.VIEW_CLIENT_SAP_CRM_GVK_EBA distribute by hash (SAP_CRM_GNI_KUNDE) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CLIENT_SAP_CRM_GVK_EBA_CURRENT_SAP_CRM_GNI_KUNDE on AMC.TABLE_CLIENT_SAP_CRM_GVK_EBA_CURRENT (SAP_CRM_GNI_KUNDE);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_CLIENT_SAP_CRM_GVK_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- Archiv-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_CLIENT_SAP_CRM_GVK_EBA_ARCHIVE');
create table AMC.TABLE_CLIENT_SAP_CRM_GVK_EBA_ARCHIVE like CALC.VIEW_CLIENT_SAP_CRM_GVK_EBA distribute by hash (SAP_CRM_GNI_KUNDE) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CLIENT_SAP_CRM_GVK_EBA_ARCHIVE_SAP_CRM_GNI_KUNDE on AMC.TABLE_CLIENT_SAP_CRM_GVK_EBA_ARCHIVE (SAP_CRM_GNI_KUNDE);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_CLIENT_SAP_CRM_GVK_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_CLIENT_SAP_CRM_GVK_EBA_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_CLIENT_SAP_CRM_GVK_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------


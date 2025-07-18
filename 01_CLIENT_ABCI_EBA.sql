-- View erstellen
drop view CALC.VIEW_CLIENT_ABCI_EBA;
-- Satellitentabelle Customer EBA
create or replace view CALC.VIEW_CLIENT_ABCI_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
-- Quelltabelle, nur relevante Felder aus sehr großer Tabelle
ABCI as (
    select CUT_OFF_DATE,
           INVENTORYABCI_PARTNERNO,
           INVENTORYABCI_ID,
           INVENTORYABCI_CREATIONDATE,
           INVENTORYABCI_MODIFICATIONDATE,
           ABCI_ID,
           ABCI_SUBMISSIONID,
           ABCI_TYPE,
           ABCI_TOBEFULFILLEDUNTIL,
           ABCI_SUBMISSIONAFTER,
           ABCI_STATUS,
           ABCI_SOURCE,
           ABCI_SCHEDULE,
           ABCI_SANCTIONOPTIONS,
           ABCI_REASONSTATUS,
           ABCI_POSTPONEDUNTIL,
           ABCI_CONFIRMATIONBY,
           ABCI_CATEGORY,
           ABCI_MODIFICATIONDATE,
           ABCI_CREATIONDATE,
           'NLB_' || INVENTORYABCI_PARTNERNO as GNI_KUNDE
    from NLB.ABCI_CLIENT_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
      and UPPER(ABCI_STATUS) = 'ACTIVE'
),
---- SAP CRM
SCRM_KWG_B as (
    select CUT_OFF_DATE,
           GP_NUMMER_1,
           GP_NUMMER_2,
           HAUPTZUORDNUNG,
           'NLB_' || GP_NUMMER_1 as GNI_KUNDE_1,
           'NLB_' || GP_NUMMER_2 as GNI_KUNDE_2
    from NLB.SAP_CRM_KWG_BEZIEHUNGEN_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
      and GRUPPENTYP_1 = 'K'
      and GRUPPENTYP_2 = 'C'
),
SCRM_KWG_S as (
    select *,
           'NLB_' || GP_NUMMER as GNI_KUNDE
    from NLB.SAP_CRM_KWG_STAMM_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
SCRM_S as (
    select *,
           'NLB_' || GP_NUMMER as GNI_KUNDE,
           case
               when NACHNAME___NAME1 is null and VORNAME___NAME2 is null then null
               else NVL(NACHNAME___NAME1, '') || NVL(VORNAME___NAME2, '')
               end             as KUNDE_NAME
    from NLB.SAP_CRM_STAMMDATEN_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- Daten zusammenführen
LOGIC as (
    select A.CUT_OFF_DATE,
           A.INVENTORYABCI_PARTNERNO                      as ABCI_PARTNERNO,
           NVL(D.NAME1 || NVL(D.NAME2, ''), E.KUNDE_NAME) as SAPCRM_PARTNER_NAME,
           case
               when A.INVENTORYABCI_PARTNERNO like '%K%' and B.GP_NUMMER_2 is null
                   then null
               else NVL(B.GNI_KUNDE_2, A.GNI_KUNDE)
               end                                        as GNI_KUNDE,
           C.KUNDE_NAME                                   as SAPCRM_KUNDE_NAME,
           case
               when A.INVENTORYABCI_PARTNERNO like '%K%' then
                   case
                       when B.HAUPTZUORDNUNG = 'X'
                           then True
                       else False
                       end
               end                                        as SAPCRM_HAUPTZUORDNUNG_KREDITNEHMER_ZU_KUNDE,
           A.INVENTORYABCI_ID,
           A.INVENTORYABCI_CREATIONDATE,
           A.INVENTORYABCI_MODIFICATIONDATE,
           A.ABCI_ID                                      as ID,
           A.ABCI_SUBMISSIONID                            as SUBMISSIONID,
           A.ABCI_CATEGORY                                as CATEGORY,
           A.ABCI_CONFIRMATIONBY                          as CONFIRMATIONBY,
           A.ABCI_POSTPONEDUNTIL                          as POSTPONEDUNTIL,
           A.ABCI_REASONSTATUS                            as REASONSTATUS,
           A.ABCI_SANCTIONOPTIONS                         as SANCTIONOPTIONS,
           A.ABCI_SCHEDULE                                as SCHEDULE,
           A.ABCI_SOURCE                                  as SOURCE,
           A.ABCI_STATUS                                  as STATUS,
           A.ABCI_SUBMISSIONAFTER                         as SUBMISSIONAFTER,
           A.ABCI_TOBEFULFILLEDUNTIL                      as TOBEFULFILLEDUNTIL,
           A.ABCI_TYPE                                    as TYPE,
           A.ABCI_CREATIONDATE                            as CREATIONDATE,
           A.ABCI_MODIFICATIONDATE                        as MODIFICATIONDATE
    from ABCI A
             left join SCRM_KWG_B B on (A.CUT_OFF_DATE, A.GNI_KUNDE) = (B.CUT_OFF_DATE, B.GNI_KUNDE_1)
             left join SCRM_S C on (B.CUT_OFF_DATE, B.GNI_KUNDE_2) = (C.CUT_OFF_DATE, C.GNI_KUNDE)
             left join SCRM_KWG_S D on (A.CUT_OFF_DATE, A.GNI_KUNDE) = (D.CUT_OFF_DATE, D.GNI_KUNDE)
             left join SCRM_S E on (A.CUT_OFF_DATE, A.GNI_KUNDE) = (E.CUT_OFF_DATE, E.GNI_KUNDE)
),
-- SAPCRM_HAUPTZUORDNUNG_KREDITNEHMER_ZU_KUNDE extra Bedingung
ZUORDN as (
    select CUT_OFF_DATE,
           ABCI_PARTNERNO                 as ABCI_PARTNERNO,
           SAPCRM_PARTNER_NAME            as ABCI_SAPCRM_PARTNER_NAME,
           GNI_KUNDE                      as ABCI_GNI_KUNDE,
           SAPCRM_KUNDE_NAME              as ABCI_SAPCRM_KUNDE_NAME,
           case
               when ABCI_PARTNERNO is not null and GNI_KUNDE is not null
                   then SAPCRM_HAUPTZUORDNUNG_KREDITNEHMER_ZU_KUNDE
               end                        as ABCI_SAPCRM_HAUPTZUORDNUNG_KREDITNEHMER_ZU_KUNDE,
           INVENTORYABCI_ID               as ABCI_INVENTORYABCI_ID,
           INVENTORYABCI_CREATIONDATE     as ABCI_INVENTORYABCI_CREATIONDATE,
           INVENTORYABCI_MODIFICATIONDATE as ABCI_INVENTORYABCI_MODIFICATIONDATE,
           ID                             as ABCI_ID,
           SUBMISSIONID                   as ABCI_SUBMISSIONID,
           CATEGORY                       as ABCI_CATEGORY,
           CONFIRMATIONBY                 as ABCI_CONFIRMATIONBY,
           POSTPONEDUNTIL                 as ABCI_POSTPONEDUNTIL,
           REASONSTATUS                   as ABCI_REASONSTATUS,
           SANCTIONOPTIONS                as ABCI_SANCTIONOPTIONS,
           SCHEDULE                       as ABCI_SCHEDULE,
           SOURCE                         as ABCI_SOURCE,
           STATUS                         as ABCI_STATUS,
           SUBMISSIONAFTER                as ABCI_SUBMISSIONAFTER,
           TOBEFULFILLEDUNTIL             as ABCI_TOBEFULFILLEDUNTIL,
           TYPE                           as ABCI_TYPE,
           CREATIONDATE                   as ABCI_CREATIONDATE,
           MODIFICATIONDATE               as ABCI_MODIFICATIONDATE
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
             inner join PWC_CUST PWC on PWC.GNI_KUNDE = A.ABCI_GNI_KUNDE
),
-- Gefiltert nach noetigen Datenfeldern
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        ABCI_PARTNERNO,
        ABCI_SAPCRM_PARTNER_NAME,
        ABCI_GNI_KUNDE,
        ABCI_SAPCRM_KUNDE_NAME,
        ABCI_SAPCRM_HAUPTZUORDNUNG_KREDITNEHMER_ZU_KUNDE,
        ABCI_INVENTORYABCI_ID,
        ABCI_INVENTORYABCI_CREATIONDATE,
        ABCI_INVENTORYABCI_MODIFICATIONDATE,
        ABCI_ID,
        ABCI_SUBMISSIONID,
        ABCI_CATEGORY,
        ABCI_CONFIRMATIONBY,
        ABCI_POSTPONEDUNTIL,
        ABCI_REASONSTATUS,
        ABCI_SANCTIONOPTIONS,
        ABCI_SCHEDULE,
        ABCI_SOURCE,
        ABCI_STATUS,
        ABCI_SUBMISSIONAFTER,
        ABCI_TOBEFULFILLEDUNTIL,
        ABCI_TYPE,
        ABCI_CREATIONDATE,
        ABCI_MODIFICATIONDATE,
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
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_CLIENT_ABCI_EBA_CURRENT');
create table AMC.TABLE_CLIENT_ABCI_EBA_CURRENT like CALC.VIEW_CLIENT_ABCI_EBA distribute by hash (ABCI_GNI_KUNDE) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CLIENT_ABCI_EBA_CURRENT_ABCI_GNI_KUNDE on AMC.TABLE_CLIENT_ABCI_EBA_CURRENT (ABCI_GNI_KUNDE);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_CLIENT_ABCI_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- Archiv-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_CLIENT_ABCI_EBA_ARCHIVE');
create table AMC.TABLE_CLIENT_ABCI_EBA_ARCHIVE like CALC.VIEW_CLIENT_ABCI_EBA distribute by hash (ABCI_GNI_KUNDE) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CLIENT_ABCI_EBA_ARCHIVE_ABCI_GNI_KUNDE on AMC.TABLE_CLIENT_ABCI_EBA_ARCHIVE (ABCI_GNI_KUNDE);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_CLIENT_ABCI_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_CLIENT_ABCI_EBA_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_CLIENT_ABCI_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------


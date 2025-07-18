-- View erstellen
drop view CALC.VIEW_CLIENT_SAP_CRM_CUSTOMER_EBA;
create or replace view CALC.VIEW_CLIENT_SAP_CRM_CUSTOMER_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
-- Stammdaten in Euro
SCRM_STM_EUR as (
    select S.CUT_OFF_DATE,
           GP_NUMMER,
           'NLB_' || S.GP_NUMMER                as GNI_KUNDE,
           GUID_EINES_GESCHAEFTSPARTNERS,
           NACHNAME___NAME1,
           VORNAME___NAME2,
           PARTNERTYP,
           PARTNERART,
           case
               when NACHNAME___NAME1 is null and VORNAME___NAME2 is null
                   then null
               else NVL(NACHNAME___NAME1, '') || NVL(VORNAME___NAME2, '')
               end                              as KUNDE_NAME,
           NAME_KWG_24,
           LTA___RATIO / 100                    as LTA___RATIO,
           LTA___BEGRUENDUNG,
           LTA___CONDITIONS_NOT_FULFILLED,
           LTA___ERMITTLUNGSDATUM,
           LTA___RELEVANZ,
           RECHTSFORM_SCHLUESSEL,
           LAND_DER_RECHTSFORM,
           BUBA_WIRTSCHAFTSZWEIG,
           KONSOLIDIERUNGSEINHEIT,
           BILANZTYP,
           QUELLE_ORIG,
           ENDE_GESCHAEFTSJAHR,
           MITARBEITERANZAHL,
           BILANZSUMME * CM.RATE_TARGET_TO_EUR  as BILANZSUMME,
           JAHRESUMSATZ * CM.RATE_TARGET_TO_EUR as JAHRESUMSATZ,
           BILANZWAEHRUNG                       as CURRENCY_OC,
           case
               when BILANZWAEHRUNG is not null
                   then 'EUR'
               end                              as CURRENCY
    from NLB.SAP_CRM_STAMMDATEN_CURRENT S
             left join IMAP.CURRENCY_MAP CM on (CM.CUT_OFF_DATE, CM.ZIEL_WHRG) = (S.CUT_OFF_DATE, S.BILANZWAEHRUNG)
    where S.CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- LTA
SCRM_LTA as (
    select CUT_OFF_DATE,
           "CLIENT",
           RECORD_ID,
           PARENT_ID,
           OBJECT_ID,
           'NLB_' || ZZ_LTA_BP AS GNI_KUNDE,
           ZZ_DETERM_DATE,
           ZZ_BUSINESS_YEAR,
           ZZ_FC_CAP_EXPLIM,
           ZZ_INC_STYLE_COV,
           ZZ_RESULT_TYPE,
           ZZ_FC_DEBTSERVCR,
           ZZ_FC_INT_COVER,
           ZZ_FC_LEVE_RATIO
    from NLB.SAP_CRM_LTA_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- GvK
SCRM_GVK as (
    select *, SAP_CRM_GNI_KUNDE as GNI_KUNDE, SAP_CRM_GVK as GVK
    from CALC.SWITCH_CLIENT_SAP_CRM_GVK_EBA_CURRENT
),
-- Daten zusammenführen
FINAL as (
    select CUT_OFF_DATE,
           GNI_KUNDE,
           GUID_EINES_GESCHAEFTSPARTNERS,
           SM_PT.S_VALUE                  as PARTNERTYP,
           SM_PA.S_VALUE                  as PARTNERART,
           KUNDE_NAME,
           NAME_KWG_24                    as KUNDE_NAME_KWG_PARAGRAPH24,
           LTA___RATIO                    as LTA_RATIO,
           SM_LB.S_VALUE                  as LTA_BEGRUENDUNG,
           LTA___CONDITIONS_NOT_FULFILLED as LTA_CONDITIONS_NOT_FULFILLED,
           LTA___ERMITTLUNGSDATUM         as LTA_ERMITTLUNGSDATUM,
           LTA___RELEVANZ                 as LTA_RELEVANZ,
           SM_RS.S_VALUE_LONG             as RECHTSFORM_SCHLUESSEL,
           LAND_DER_RECHTSFORM,
           BUBA_WIRTSCHAFTSZWEIG,
           SM_KE.S_VALUE                  as KONSOLIDIERUNGSEINHEIT,
           SM_BT.S_VALUE                  as BILANZTYP,
           SM_QU.S_VALUE                  as QUELLE,
           ENDE_GESCHAEFTSJAHR,
           MITARBEITERANZAHL,
           BILANZSUMME,
           JAHRESUMSATZ,
           CURRENCY_OC,
           CURRENCY,
           "CLIENT",
           RECORD_ID,
           PARENT_ID,
           OBJECT_ID,
           ZZ_FC_CAP_EXPLIM               as LTA_FC_CAP_EXPLIM,
           ZZ_INC_STYLE_COV               as LTA_INC_STYLE_COV,
           ZZ_RESULT_TYPE                 as LTA_RESULT_TYPE,
           ZZ_FC_DEBTSERVCR               as LTA_FC_DEBTSERVCR,
           ZZ_FC_INT_COVER                as LTA_FC_INT_COVER,
           ZZ_FC_LEVE_RATIO               as LTA_FC_LEVE_RATIO,
           GVK_FLAG,
           GVKS                           as GVK
    from (
             select B.CUT_OFF_DATE,
                    B.GNI_KUNDE,
                    B.GUID_EINES_GESCHAEFTSPARTNERS,
                    B.PARTNERTYP,
                    B.PARTNERART,
                    B.KUNDE_NAME,
                    B.NAME_KWG_24,
                    B.LTA___RATIO,
                    B.LTA___BEGRUENDUNG,
                    B.LTA___CONDITIONS_NOT_FULFILLED,
                    B.LTA___ERMITTLUNGSDATUM,
                    B.LTA___RELEVANZ,
                    B.RECHTSFORM_SCHLUESSEL,
                    B.LAND_DER_RECHTSFORM,
                    B.BUBA_WIRTSCHAFTSZWEIG,
                    B.KONSOLIDIERUNGSEINHEIT,
                    B.BILANZTYP,
                    B.QUELLE_ORIG,
                    B.ENDE_GESCHAEFTSJAHR,
                    B.MITARBEITERANZAHL,
                    B.BILANZSUMME,
                    B.JAHRESUMSATZ,
                    B.CURRENCY_OC,
                    B.CURRENCY,
                    C.CLIENT,
                    C.RECORD_ID,
                    C.PARENT_ID,
                    C.OBJECT_ID,
                    C.ZZ_FC_CAP_EXPLIM,
                    C.ZZ_INC_STYLE_COV,
                    C.ZZ_RESULT_TYPE,
                    C.ZZ_FC_DEBTSERVCR,
                    C.ZZ_FC_INT_COVER,
                    C.ZZ_FC_LEVE_RATIO,
                    case
                        when D.GNI_KUNDE is not null
                            then true
                        else false
                        end                                                                       as GVK_FLAG,
                    E.GVKS,
                    ROW_NUMBER() over (partition by B.GNI_KUNDE order by C.ZZ_BUSINESS_YEAR desc) as CUSTOMER_COUNT
             from SCRM_STM_EUR B
                      --
                      left join
                  SCRM_LTA C on B.GNI_KUNDE = C.GNI_KUNDE and C.ZZ_DETERM_DATE = B.LTA___ERMITTLUNGSDATUM
                      --
                      left join
                  (select distinct GNI_KUNDE
                   from SCRM_GVK
                  ) D on B.GNI_KUNDE = D.GNI_KUNDE
                      --
                      left join
                  (select GNI_KUNDE,
                          LISTAGG(GVK, ',') as GVKS
                   from SCRM_GVK
                   group by GNI_KUNDE
                  ) E on B.GNI_KUNDE = E.GNI_KUNDE
         )
             -- SMAPs
             left join SMAP.SAP_CRM_PARTNERTYP SM_PT on PARTNERTYP = SM_PT.S_KEY
             left join SMAP.SAP_CRM_PARTNERART SM_PA on PARTNERART = SM_PA.S_KEY
             left join SMAP.SAP_CRM_RECHTSFORM_SCHLUESSEL SM_RS on RECHTSFORM_SCHLUESSEL = SM_RS.S_KEY
             left join SMAP.SAP_CRM_KONSOLIDIERUNGSEINHEIT SM_KE on KONSOLIDIERUNGSEINHEIT = SM_KE.S_KEY
             left join SMAP.SAP_CRM_BILANZTYP SM_BT on BILANZTYP = SM_BT.S_KEY
             left join SMAP.SAP_CRM_QUELLE SM_QU on QUELLE_ORIG = SM_QU.S_KEY
             left join SMAP.SAP_CRM_LTA_BEGRUENDUNG SM_LB on LTA___BEGRUENDUNG = SM_LB.S_KEY
    where CUSTOMER_COUNT = 1
),
-- Gefiltert nach noetigen Datenfeldern
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        GNI_KUNDE,
        GUID_EINES_GESCHAEFTSPARTNERS,
        PARTNERTYP,
        PARTNERART,
        KUNDE_NAME,
        KUNDE_NAME_KWG_PARAGRAPH24,
        LAND_DER_RECHTSFORM,
        RECHTSFORM_SCHLUESSEL,
        BUBA_WIRTSCHAFTSZWEIG,
        KONSOLIDIERUNGSEINHEIT,
        BILANZTYP,
        QUELLE,
        ENDE_GESCHAEFTSJAHR,
        MITARBEITERANZAHL,
        BILANZSUMME,
        JAHRESUMSATZ,
        CURRENCY_OC,
        CURRENCY,
        LTA_RELEVANZ,
        LTA_BEGRUENDUNG,
        LTA_ERMITTLUNGSDATUM,
        LTA_RATIO,
        LTA_CONDITIONS_NOT_FULFILLED,
        LTA_RESULT_TYPE,
        LTA_FC_LEVE_RATIO,
        LTA_FC_INT_COVER,
        LTA_FC_DEBTSERVCR,
        LTA_FC_CAP_EXPLIM,
        LTA_INC_STYLE_COV,
        GVK_FLAG,
        GVK,
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
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_CLIENT_SAP_CRM_CUSTOMER_EBA_CURRENT');
create table AMC.TABLE_CLIENT_SAP_CRM_CUSTOMER_EBA_CURRENT like CALC.VIEW_CLIENT_SAP_CRM_CUSTOMER_EBA distribute by hash (GNI_KUNDE) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CLIENT_SAP_CRM_CUSTOMER_EBA_CURRENT_GNI_KUNDE on AMC.TABLE_CLIENT_SAP_CRM_CUSTOMER_EBA_CURRENT (GNI_KUNDE);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_CLIENT_SAP_CRM_CUSTOMER_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_CLIENT_SAP_CRM_CUSTOMER_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------



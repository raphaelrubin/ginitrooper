-- View erstellen
drop view CALC.VIEW_FACILITY_BW_P80_AOER;
create or replace view CALC.VIEW_FACILITY_BW_P80_AOER as
with
 RDL_Q08 as (
    select *, ROW_NUMBER() over (partition by BA1_C11EXTCON order by BIC_XB_IRNARM DESC NULLS LAST, BIC_XB_RTMOD DESC NULLS LAST, BIC_XB_SEGMID DESC NULLS LAST) as WORST_RATING_ORDER
    from NLB.BW_IFRS_INTERNAL_CURRENT
    union all
    select *, ROW_NUMBER() over (partition by BA1_C11EXTCON order by BIC_XB_IRNARM DESC NULLS LAST, BIC_XB_RTMOD DESC NULLS LAST, BIC_XB_SEGMID DESC NULLS LAST) as WORST_RATING_ORDER
    from ANL.BW_IFRS_INTERNAL_CURRENT
 ),
 RDL_BLANKO_PRE as (
     select
            case when ROW_NUMBER() over (partition by BA1_C11EXTCON order by WORST_RATING_ORDER) = 1 then 1 else 0 end as LEADING_ENTRY,
            RDL_Q08.CUT_OFF_DATE,
            RDL_Q08.BA1_C11EXTCON,
            BIC_E_INSPNA,
            BIC_XB_IRNARM,
            BIC_XB_RTMOD,
            BIC_XB_SEGMID,
            BA1_C20BPART
     from RDL_Q08
     where RDL_Q08.BIC_XB_ASSTID Is Null
       and RDL_Q08.BIC_XB_PIDSIV Is Null
 ),
 RDL_BLANKO as (
     select RDL_Q08.CUT_OFF_DATE,
            RDL_Q08.BA1_C11EXTCON,
            sum(RDL_Q08.BIC_E_INSPNA)                                                                   AS SAP_Summe_Blanko,
            max(RDL_Q08.BIC_XB_IRNARM * LEADING_ENTRY)                                                  AS SAP_RATING,
            max(RDL_Q08.BIC_XB_RTMOD * LEADING_ENTRY)                                                   AS SAP_RATINGMODUL,
            listagg(distinct MODULES.GROUP, ', ') within group (order by MODULES.GROUP)                 AS SAP_MODULNAME,
            listagg(distinct MODULES.NAME, ', ') within group (order by MODULES.NAME)                   AS SAP_SUBMODUL,
            listagg(distinct MODULES.DESCRIPTION, ', ') within group (order by MODULES.DESCRIPTION)     AS SAP_MODULBESCHREIBUNG,
            listagg(distinct MODULES.TYPE, '/') within group (order by MODULES.TYPE)                    AS SAP_IRBA_KSA,
            max(RDL_Q08.BIC_XB_SEGMID * LEADING_ENTRY)                                                  AS SAP_SEGMENT,
            listagg(distinct RDL_Q08.BA1_C20BPART, ', ') within group (order by RDL_Q08.BA1_C20BPART)   AS SAP_KUNDE
     from RDL_BLANKO_PRE as RDL_Q08
     left join SMAP.RATING_MODULES as MODULES on RDL_Q08.BIC_XB_RTMOD = MODULES.NO
     group by RDL_Q08.BA1_C11EXTCON, RDL_Q08.CUT_OFF_DATE
 ),
 RDL_EXT as (
     select RDL_Q08.*,
            first_value(RDL_Q08.BIC_XB_IRNARM) over (partition by RDL_Q08.BA1_C11EXTCON, CUT_OFF_DATE order by WORST_RATING_ORDER)  AS SAP_RATING_E,
            first_value(RDL_Q08.BIC_XB_RTMOD) over (partition by RDL_Q08.BA1_C11EXTCON, CUT_OFF_DATE order by WORST_RATING_ORDER)   AS SAP_RATINGMODUL_E,
            first_value(RDL_Q08.BIC_XB_SEGMID) over (partition by RDL_Q08.BA1_C11EXTCON, CUT_OFF_DATE order by WORST_RATING_ORDER)  AS SAP_SEGMENT_E,
            first_value(RDL_Q08.BA1_C20BPART) over (partition by RDL_Q08.BA1_C11EXTCON, CUT_OFF_DATE order by RDL_Q08.BA1_C20BPART) AS SAP_KUNDE_E,
            first_value(RDL_Q08.BIC_XX_MK_FLG) over (partition by RDL_Q08.BA1_C11EXTCON, CUT_OFF_DATE order by RDL_Q08.BA1_C20BPART) AS SAP_HEDGING_FLAG,
            RDL_Q08.BIC_E_ANAKZI                                                     AS SAP_STUECKZINSEN,
            coalesce(BIC_B_PDWERT * BIC_E_EADANT, 0)                                 AS TMP_PD_VOL_PROD,
            coalesce(BIC_B_LGDWER * BIC_E_EADANT, 0)                                 AS TMP_LGD_VOL_PROD,
            coalesce(BIC_B_CCFWER * BIC_E_FRELIN, 0)                                 AS TMP_CCF_FREI_PROD,
            NVL2(BIC_B_PDWERT, coalesce(BIC_E_EADANT, 0), 0)                         AS TMP_PD_EADMOD,
            NVL2(BIC_B_LGDWER, coalesce(BIC_E_EADANT, 0), 0)                         AS TMP_LGD_EADMOD,
            NVL2(BIC_B_CCFWER, coalesce(BIC_E_FRELIN, 0), 0)                         AS TMP_CCF_FREIMOD,
            NVL2(BIC_B_PDWERT, 1, 0)                                                 AS TMP_PD_FLAG,
            NVL2(BIC_B_LGDWER, 1, 0)                                                 AS TMP_LGD_FLAG,
            NVL2(BIC_B_CCFWER, 1, 0)                                                 AS TMP_CCF_FLAG
     from RDL_Q08
 ),
 EXTRACT_SAP as (
     select RDL_EXT.CUT_OFF_DATE,
            SAP_RATING_E                        AS SAP_RATING_E,
            RDL_EXT.BA_LZZKNZAUS                AS SAP_AUSFALL,
            Sum(coalesce(BIC_E_INSPNA, 0))      AS SAP_INANSPRUCHNAHME,
            case
                when Sum(RDL_EXT.TMP_PD_FLAG) = 0 then
                    Null
                else
                    Sum(coalesce(BIC_B_PDWERT, 0)) / Sum(RDL_EXT.TMP_PD_FLAG)
                end                             AS TMP_PD_MW,
            Sum(coalesce(TMP_PD_VOL_PROD, 0))   AS TMP_PD_VOL,
            SAP_RATINGMODUL_E                   AS SAP_RATINGMODUL_E,
            RDL_EXT.BIC_XX_PRKEY                AS SAP_PRODUKT,
            RDL_EXT.SAP_HEDGING_FLAG            AS SAP_HEDGING_FLAG,
            Sum(coalesce(SAP_STUECKZINSEN,0))   AS SAP_STUECKZINSEN,
            RDL_EXT.BIC_XS_CONTCU               AS SAP_WAEHRUNG,
            Sum(coalesce(BIC_E_FRELIN, 0))      AS SAP_FREIELINIE,
            Sum(coalesce(BIC_E_EADANT, 0))      AS SAP_EAD,
            case
                when Sum(RDL_EXT.TMP_LGD_FLAG) = 0 then
                    Null
                else
                    Sum(coalesce(BIC_B_LGDWER, 0)) / Sum(RDL_EXT.TMP_LGD_FLAG)
                end                             AS TMP_LGD_MW,
            Sum(coalesce(TMP_LGD_VOL_PROD, 0))  AS TMP_LGD_VOL,
            Sum(coalesce(BIC_E_EWBTES, 0))      AS SAP_EWBTES,
            RDL_EXT.BA1_C11EXTCON               AS FACILITY_ID,
            RDL_EXT.BIC_XX_KUSY                 AS SAP_KUSY,
            SAP_SEGMENT_E                       AS SAP_SEGMENT_E,
            SAP_KUNDE_E                         AS SAP_KUNDE_E,
            Sum(coalesce(TMP_CCF_FREI_PROD, 0)) AS TMP_CCF_FREI,
            case
                when Sum(RDL_EXT.TMP_CCF_FLAG) = 0 then
                    Null
                else
                    Sum(coalesce(BIC_B_CCFWER, 0)) / Sum(RDL_EXT.TMP_CCF_FLAG)
                end                             AS TMP_CCF_MW,
            Sum(coalesce(BIC_E_BEEXLO, 0))      AS SAP_EL,
            Sum(RDL_EXT.TMP_PD_EADMOD)          AS TMP_PD_EADMOD_SUM,
            Sum(RDL_EXT.TMP_LGD_EADMOD)         AS TMP_LGD_EADMOD_SUM,
            Sum(RDL_EXT.TMP_CCF_FREIMOD)        AS TMP_CCF_FREIMOD_SUM,
            Sum(RDL_EXT.TMP_PD_FLAG)            AS TMP_PD_FLAG_SUM,
            Sum(RDL_EXT.TMP_LGD_FLAG)           AS TMP_LGD_FLAG_SUM,
            Sum(RDL_EXT.TMP_CCF_FLAG)           AS TMP_CCF_FLAG_SUM
     from RDL_EXT
     group by RDL_EXT.BA_LZZKNZAUS, RDL_EXT.BIC_XX_PRKEY, RDL_EXT.BIC_XS_CONTCU, RDL_EXT.BA1_C11EXTCON,
              RDL_EXT.BIC_XX_KUSY,
              SAP_RATING_E, SAP_RATINGMODUL_E, SAP_SEGMENT_E, SAP_KUNDE_E, CUT_OFF_DATE, SAP_HEDGING_FLAG
 ),
 basis as (
     select distinct EXTRACT_SAP.CUT_OFF_DATE,
                     Extract_SAP.FACILITY_ID,
                     'SAP'                                                                                      AS SAP,
                     Extract_SAP.SAP_KUNDE_E,
                     Extract_SAP.SAP_RATING_E,
                     Extract_SAP.SAP_KUSY,
                     Extract_SAP.SAP_SEGMENT_E,
                     Extract_SAP.SAP_AUSFALL as DEFAULT,
                     Extract_SAP.SAP_INANSPRUCHNAHME,
                     case
                         when TMP_PD_EADMOD_SUM > 0 then
                             TMP_PD_VOL / TMP_PD_EADMOD_SUM
                         else TMP_PD_MW end                                                                     AS PROBABILITY_OF_DEFAULT_RATE,
                     Extract_SAP.SAP_RATINGMODUL_E,
                     Extract_SAP.SAP_PRODUKT,
                     Extract_SAP.SAP_WAEHRUNG,
                     Extract_SAP.SAP_FREIELINIE,
                     Extract_SAP.SAP_EAD,
                     case
                         when TMP_LGD_EADMOD_SUM > 0 then TMP_LGD_VOL / TMP_LGD_EADMOD_SUM
                         else TMP_LGD_MW end                                                                    AS LOSS_GIVEN_DEFAULT_RATE,
                     case
                         when TMP_CCF_FREIMOD_SUM > 0 then TMP_CCF_FREI / TMP_CCF_FREIMOD_SUM
                         else TMP_CCF_MW end                                                                    AS CREDIT_CONVERSION_FACTOR,
                     Extract_SAP.SAP_EWBTES,
                     Extract_SAP.SAP_EL,
                     Extract_SAP.SAP_HEDGING_FLAG,
                     Extract_SAP.SAP_STUECKZINSEN,
                     RDL_BLANKO.SAP_Summe_Blanko,
                     RDL_BLANKO.SAP_RATING,
                     RDL_BLANKO.SAP_RATINGMODUL,
                     RDL_BLANKO.SAP_MODULNAME,
                     RDL_BLANKO.SAP_SUBMODUL,
                     RDL_BLANKO.SAP_MODULBESCHREIBUNG,
                     RDL_BLANKO.SAP_IRBA_KSA,
                     RDL_BLANKO.SAP_SEGMENT,
                     RDL_BLANKO.SAP_KUNDE
     from Extract_SAP
     left join RDL_BLANKO on (Extract_SAP.FACILITY_ID,Extract_SAP.CUT_OFF_DATE) = (RDL_BLANKO.BA1_C11EXTCON,RDL_BLANKO.CUT_OFF_DATE)
     --GROUP BY Extract_SAP.FACILITY_ID, Extract_SAP.SAP_KUNDE_E, Extract_SAP.SAP_RATING_E, Extract_SAP.SAP_KUSY,
     --         Extract_SAP.SAP_SEGMENT_E, Extract_SAP.SAP_AUSFALL, Extract_SAP.SAP_INANSPRUCHNAHME,
     --         IIf([TMP_PD_EADMOD_SUM]>0,[TMP_PD_VOL]/[TMP_PD_EADMOD_SUM],[TMP_PD_MW]), Extract_SAP.SAP_RATINGMODUL_E, Extract_SAP.SAP_PRODUKT, Extract_SAP.SAP_WAEHRUNG, Extract_SAP.SAP_FREIELINIE, Extract_SAP.SAP_EAD, IIf([TMP_LGD_EADMOD_SUM]>0,[TMP_LGD_VOL]/[TMP_LGD_EADMOD_SUM],[TMP_LGD_MW]), IIf([TMP_CCF_FREIMOD_SUM]>0,[TMP_CCF_FREI]/[TMP_CCF_FREIMOD_SUM],[TMP_CCF_MW]), Extract_SAP.SAP_EWBTES, Extract_SAP.SAP_EL
 ),
 DATA as (
     select *,
          CURRENT_USER      as CREATED_USER,
          CURRENT_TIMESTAMP as CREATED_TIMESTAMP
     from basis as BB
 )
select *
from DATA
;

-- CI START FOR ALL TAPES
-- Current-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_FACILITY_BW_P80_AOER_CURRENT');
create table AMC.TABLE_FACILITY_BW_P80_AOER_CURRENT like CALC.VIEW_FACILITY_BW_P80_AOER distribute by hash (FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_BW_P80_AOER_CURRENT_FACILITY_ID on AMC.TABLE_FACILITY_BW_P80_AOER_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_FACILITY_BW_P80_AOER_CURRENT');
-- Archiv-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_FACILITY_BW_P80_AOER_ARCHIVE');
create table AMC.TABLE_FACILITY_BW_P80_AOER_ARCHIVE like AMC.TABLE_FACILITY_BW_P80_AOER_CURRENT distribute by hash (FACILITY_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_BW_P80_AOER_ARCHIVE_FACILITY_ID on AMC.TABLE_FACILITY_BW_P80_AOER_ARCHIVE (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_FACILITY_BW_P80_AOER_ARCHIVE');
-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_FACILITY_BW_P80_AOER_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_FACILITY_BW_P80_AOER_ARCHIVE');

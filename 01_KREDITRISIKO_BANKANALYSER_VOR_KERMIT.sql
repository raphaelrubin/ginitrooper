-- View erstellen
drop view CALC.VIEW_KREDITRISIKO_BANKANALYSER_VOR_KERMIT;
create or replace view CALC.VIEW_KREDITRISIKO_BANKANALYSER_VOR_KERMIT as
with BASE as (
        select BA.*,PORTFOLIO_EY_FACILITY as PORTFOLIO,CLIENT_NO from NLB.DLD_DR_IFRS_KERMIT_CURRENT as BA
        inner join CALC.SWITCH_PORTFOLIO_CURRENT as PORT on PORT.FACILITY_ID_NLB=BA.BA1_C11EXTCON and port.CUT_OFF_DATE=BA.CUT_OFF_DATE
        where PORT.FACILITY_ID_NLB is not NULL
    union all
        select BA.*,PORTFOLIO_EY_FACILITY as PORTFOLIO,CLIENT_NO from BLB.DLD_DR_IFRS_KERMIT_CURRENT as BA
        inner join CALC.SWITCH_PORTFOLIO_CURRENT as PORT on PORT.FACILITY_ID_BLB=BA.BA1_C11EXTCON and port.CUT_OFF_DATE=BA.CUT_OFF_DATE
        where PORT.FACILITY_ID_BLB is not NULL
    union all
        select BA.*,PORTFOLIO_EY_FACILITY as PORTFOLIO,CLIENT_NO from ANL.DLD_DR_IFRS_KERMIT_CURRENT as BA
        inner join CALC.SWITCH_PORTFOLIO_CURRENT as PORT on PORT.FACILITY_ID_NLB=BA.BA1_C11EXTCON and port.CUT_OFF_DATE=BA.CUT_OFF_DATE
        where PORT.FACILITY_ID_NLB is not NULL
),AGGREGATE as (
    SELECT
                    CUT_OFF_DATE,
                    DLD_DR.BIC_XS_IDNUM AS CLIENT_ID_KR,
                    PORTFOLIO,CLIENT_NO,
                    DLD_DR.BA1_C11EXTCON AS FACILITY_ID,
                    DLD_DR.BIC_XB_VBNR AS DBE,
                    DLD_DR.BIC_XS_CONTCU AS ORIGINAL_CURRENCY,
                    Sum(DLD_DR.BIC_E_FRELIN) AS FREIE_LINIE,
                    Sum(DLD_DR.BIC_E_INSPNA) AS PRINCIPAL_OUTSTANDING,
                    ----------------------------------------------------------------------------------------------------
                    case
                        when Sum(DLD_DR.BIC_E_FRELIN)>0 then Min(DLD_DR.BIC_B_CCFWER)
                        else Null
                    end AS CREDIT_CONVERSION_FACTOR,
                    ----------------------------------------------------------------------------------------------------
                    Sum(DLD_DR.BIC_E_EADANT) AS EAD_NON_SECURITIZED_EUR,
                    Sum(DLD_DR.BIC_E_EADAUS) AS EAD_SECURITIZED,
                    Sum(DLD_DR.BIC_E_EADANT)+Sum(DLD_DR.BIC_E_EADAUS) AS EAD_TOTAL_EUR,
                    Sum(DLD_DR.KSA_EXPOSURE) AS KSA_EXPOSURE_EUR,
                    Sum(DLD_DR.IRBA_EXPOSURE) AS IRBA_EXPOSURE_EUR,
                    Sum(DLD_DR.BIC_E_RWAAUS) AS RWA_SECURITIZED_EUR,
                    Sum(DLD_DR.BIC_E_BERANB) AS RWA_NON_SECURITIZED_EUR,
                    Sum(DLD_DR.BIC_E_BERANB)+Sum(DLD_DR.BIC_E_RWAAUS) AS RWA_TOTAL_EUR,
                    ----------------------------------------------------------------------------------------------------
                    case
                        when Sum(DLD_DR.BIC_E_EADANT)=0 then Max(DLD_DR.BIC_B_RWARM)
                        else Sum(DLD_DR.BIC_E_BERANB)/Sum(DLD_DR.BIC_E_EADANT)
                    end  AS RW_Non_Securitized,
                    ----------------------------------------------------------------------------------------------------
                    case
                        when (Min(DLD_DR.BA_LCEAPPRL2)<3 And Max(DLD_DR.BA_LCEAPPRL2)<3) OR ( Sum(DLD_DR.KSA_EXPOSURE) >0 AND Sum(DLD_DR.IRBA_EXPOSURE) =0) then 'KSA / leeres IRBA Exposure'
                        when Max(DLD_DR.BA_LCEAPPRL2)>=3 AND Sum(DLD_DR.KSA_EXPOSURE) =0 AND Sum(DLD_DR.IRBA_EXPOSURE) >0 then 'IRBA / leeres KSA Exposure'
                        else 'Mischfall'
                    end  AS ANSATZ,
                    ----------------------------------------------------------------------------------------------------
                    case
                        when Min(DLD_DR.BA_LCEAPPRL2)<3 And Max(DLD_DR.BA_LCEAPPRL2)<3 then Null
                        else Max(DLD_DR.BIC_B_PDWERT)
                    end AS PD_MAX,
                    ----------------------------------------------------------------------------------------------------
                    case
                        when Min(DLD_DR.BA_LCEAPPRL2)<3 And Max(DLD_DR.BA_LCEAPPRL2)<3 then Null
                        else Sum(DLD_DR.BIC_E_EADANT*DLD_DR.BIC_B_PDWERT)
                    end AS EAD_X_PD,
                    ----------------------------------------------------------------------------------------------------
                    case
                        when Min(DLD_DR.BA_LCEAPPRL2)<3 And Max(DLD_DR.BA_LCEAPPRL2)<3 then Null
                        when Sum(DLD_DR.BIC_E_EADANT)=0 then Max(DLD_DR.BIC_B_PDWERT)
                        else Sum(DLD_DR.BIC_E_EADANT*DLD_DR.BIC_B_PDWERT)/Sum(DLD_DR.BIC_E_EADANT)
                    end AS PD_WEIGHTED,
                    ----------------------------------------------------------------------------------------------------
                    case
                        when Max(DLD_DR.BA_LZBBEWARM)>=91 then Null
                        else Max(DLD_DR.BA_LZBBEWARM)
                    end AS MAX_RATING,
                    ----------------------------------------------------------------------------------------------------
                    DLD_DR.BIC_XB_DAUSKZ AS SECURITISATION_FLAG,
                    DLD_DR.BIC_XX_PRKEY AS PRODUCT_TYPE_DETAIL
                    --Kunden.TransferPortfolio,
                    --Kunden.BorrowerID
    FROM
         (
        SELECT A.*,
         case when A.BA_LCEAPPRL2<=2 then A.BIC_E_EADANT else  0 end as KSA_EXPOSURE,
         case when A.BA_LCEAPPRL2>2 then A.BIC_E_EADANT else  0 end as IRBA_EXPOSURE
         from BASE as A
         ) AS DLD_DR
    GROUP BY CUT_OFF_DATE,
    DLD_DR.BIC_XS_IDNUM,PORTFOLIO,CLIENT_NO,
    DLD_DR.BA1_C11EXTCON,
    DLD_DR.BIC_XB_VBNR, DLD_DR.BIC_XS_CONTCU,
    DLD_DR.BIC_XB_DAUSKZ, DLD_DR.BIC_XX_PRKEY
)
select distinct
    B.*
    ,C.ZM_PRODNR_TXT AS PRODUCT_TYPE_DETAIL_TXT
    ,C.ZM_PRODNR_CATEGORY AS PRODUCT_TYPE
    ,C.ZM_PRODNR_CATEGORY_TXT AS PRODUCT_TYPE_TXT
    ,D.Ausplatzierung
     ----------------------------------------------------------------------------------------------------
    ,case
        when ANSATZ='KSA / leeres IRBA Exposure' then Null
        else E.ALP_RATING
    end  AS RATINGKLASSE_IRBA
     ----------------------------------------------------------------------------------------------------
    ,case
        when ANSATZ='KSA / leeres IRBA Exposure' then Null
        else E.NUM_RATING
    end  AS RATINGSTUFE_IRBA
     ----------------------------------------------------------------------------------------------------
    ,case
        when ANSATZ='KSA / leeres IRBA Exposure' then RW.RATINGSTUFE
        else null
    end  AS RATINGSTUFE_KSA
     ----------------------------------------------------------------------------------------------------
    ,case
        when ANSATZ='KSA / leeres IRBA Exposure' then RW.RATINGKLASSE
        else null
    end  AS RATINGKLASSE_KSA
     ----------------------------------------------------------------------------------------------------
    ,case
        when PD_WEIGHTED >0.95 and MAX_RATING = 25 then '16'
        when PD_WEIGHTED >0.95 and MAX_RATING = 26 then '17'
        when PD_WEIGHTED >0.95 and MAX_RATING = 27 then '18'
        when ANSATZ='KSA / leeres IRBA Exposure' then RW.RATINGKLASSE
        else E.ALP_RATING
    end  AS INTERNAL_RATINGKLASSE
     ----------------------------------------------------------------------------------------------------
    ,case
            when PD_WEIGHTED>0.95 then  MAX_RATING
            when  /*PD_WEIGHTED<=0.95 and*/ ANSATZ='KSA / leeres IRBA Exposure' then RW.RATINGSTUFE
            else E.NUM_RATING
     end AS INTERNAL_RATINGSTUFE
    ----------------------------------------------------------------------------------------------------
FROM AGGREGATE as B
LEFT JOIN  SMAP.KR_PRODUKTE_MAP as C ON B.PRODUCT_TYPE_DETAIL = C.ZM_PRODNR
LEFT JOIN SMAP.AUSPLATZIERUNG_MAP as D  ON B.SECURITISATION_FLAG =D.BIC_XB_DAUSKZ
LEFT JOIN SMAP.RATING_MAP as E ON (B.PD_WEIGHTED < E.PD_UBOUND) AND (B.PD_WEIGHTED >= E.PD_LBOUND)
LEFT JOIN SMAP.KR_RW_MAP as RW ON (B.RW_Non_Securitized >= RW.RW_LBOUND) AND (B.RW_Non_Securitized < RW.RW_UBOUND)
;

-- CI START FOR ALL TAPES
-- Current-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_KREDITRISIKO_BANKANALYSER_VOR_KERMIT_CURRENT');
create table AMC.TABLE_KREDITRISIKO_BANKANALYSER_VOR_KERMIT_CURRENT like CALC.VIEW_KREDITRISIKO_BANKANALYSER_VOR_KERMIT distribute by hash(FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_KREDITRISIKO_BANKANALYSER_VOR_KERMIT_CURRENT_FACILITY_ID on AMC.TABLE_KREDITRISIKO_BANKANALYSER_VOR_KERMIT_CURRENT (FACILITY_ID);
create index AMC.INDEX_KREDITRISIKO_BANKANALYSER_VOR_KERMIT_CURRENT_CLIENT_NO   on AMC.TABLE_KREDITRISIKO_BANKANALYSER_VOR_KERMIT_CURRENT (CLIENT_NO);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_KREDITRISIKO_BANKANALYSER_VOR_KERMIT_CURRENT');
-- Archiv-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_KREDITRISIKO_BANKANALYSER_VOR_KERMIT_ARCHIVE');
create table AMC.TABLE_KREDITRISIKO_BANKANALYSER_VOR_KERMIT_ARCHIVE like CALC.VIEW_KREDITRISIKO_BANKANALYSER_VOR_KERMIT distribute by hash(FACILITY_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2025' EVERY 1 MONTH) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_KREDITRISIKO_BANKANALYSER_VOR_KERMIT_ARCHIVE_FACILITY_ID on AMC.TABLE_KREDITRISIKO_BANKANALYSER_VOR_KERMIT_ARCHIVE (FACILITY_ID);
create index AMC.INDEX_KREDITRISIKO_BANKANALYSER_VOR_KERMIT_ARCHIVE_CLIENT_NO   on AMC.TABLE_KREDITRISIKO_BANKANALYSER_VOR_KERMIT_ARCHIVE (CLIENT_NO);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_KREDITRISIKO_BANKANALYSER_VOR_KERMIT_ARCHIVE');
-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_KREDITRISIKO_BANKANALYSER_VOR_KERMIT_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_KREDITRISIKO_BANKANALYSER_VOR_KERMIT_ARCHIVE');
-- View erstellen
drop view CALC.VIEW_KREDITRISIKO_BANKANALYSER;
create or replace view CALC.VIEW_KREDITRISIKO_BANKANALYSER as
with BASE as (
        select BA.*,PORTFOLIO_EY_FACILITY as PORTFOLIO,CLIENT_NO from NLB.DLD_DR_IFRS_CURRENT as BA
        inner join CALC.SWITCH_PORTFOLIO_CURRENT as PORT on PORT.FACILITY_ID=BA.BA1_C11EXTCON and port.CUT_OFF_DATE=BA.CUT_OFF_DATE
        where PORT.FACILITY_ID is not NULL
    union all
        select BA.*,PORTFOLIO_EY_FACILITY as PORTFOLIO,CLIENT_NO from BLB.DLD_DR_IFRS_CURRENT as BA
        inner join CALC.SWITCH_PORTFOLIO_CURRENT as PORT on PORT.FACILITY_ID=BA.BA1_C11EXTCON and port.CUT_OFF_DATE=BA.CUT_OFF_DATE
        where PORT.FACILITY_ID is not NULL
    union all
        select BA.*,PORTFOLIO_EY_FACILITY as PORTFOLIO,CLIENT_NO from ANL.DLD_DR_IFRS_CURRENT as BA
        inner join CALC.SWITCH_PORTFOLIO_CURRENT as PORT on PORT.FACILITY_ID=BA.BA1_C11EXTCON and port.CUT_OFF_DATE=BA.CUT_OFF_DATE
        where PORT.FACILITY_ID is not NULL
),AGGREGATE as (
    SELECT
                    CUT_OFF_DATE,
                    cast(DLD_DR.BIC_XS_IDNUM as VARCHAR(32)) AS CLIENT_ID_KR,
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
                    MAX(DLD_DR.BIC_B_RWARM) AS BIC_B_RWARM_MAX,
                    MIN(DLD_DR.BA_LCEAPPRL2) AS ANSATZ_ARM_LEVEL2_MIN,
                    MAX(DLD_DR.BA_LCEAPPRL2) AS ANSATZ_ARM_LEVEL2_MAX,
                    MAX(DLD_DR.BA_LZBBEWARM) as INTERNE_RATING_NOTE_ARM_MAX,
                    MAX(DLD_DR.BIC_B_PDWERT) as PDWERT_MAX,
                    SUM(DLD_DR.BIC_E_EADANT*DLD_DR.BIC_B_PDWERT) as RWA,
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
),AGGREGATE_UNIQUE_FACILITIES as (
    SELECT CUT_OFF_DATE,
            listagg(distinct CLIENT_ID_KR, ', ') within group ( order by CLIENT_ID_KR) as CLIENT_ID_KR,
            PORTFOLIO,
            CLIENT_NO,
            FACILITY_ID,
            listagg(distinct DBE, ', ') within group ( order by DBE) as DBE,
            ORIGINAL_CURRENCY,
            sum(FREIE_LINIE) as FREIE_LINIE,
            sum(PRINCIPAL_OUTSTANDING) as PRINCIPAL_OUTSTANDING,
            MIN(CREDIT_CONVERSION_FACTOR) as CREDIT_CONVERSION_FACTOR,
            sum(EAD_NON_SECURITIZED_EUR) as EAD_NON_SECURITIZED_EUR,
            sum(EAD_SECURITIZED) as EAD_SECURITIZED,
            sum(EAD_TOTAL_EUR) as EAD_TOTAL_EUR,
            sum(KSA_EXPOSURE_EUR) as KSA_EXPOSURE_EUR,
            sum(IRBA_EXPOSURE_EUR) as IRBA_EXPOSURE_EUR,
            sum(RWA_SECURITIZED_EUR) as RWA_SECURITIZED_EUR,
            sum(RWA_NON_SECURITIZED_EUR) as RWA_NON_SECURITIZED_EUR,
            sum(RWA_TOTAL_EUR) as RWA_TOTAL_EUR,
            case
                when Sum(EAD_NON_SECURITIZED_EUR)=0 then MAX(BIC_B_RWARM_MAX)
                else Sum(RWA_NON_SECURITIZED_EUR)/Sum(EAD_NON_SECURITIZED_EUR)
            end AS RW_Non_Securitized,
            case
                when (Min(ANSATZ_ARM_LEVEL2_MIN)<3 And Max(ANSATZ_ARM_LEVEL2_MAX)<3) OR ( Sum(KSA_EXPOSURE_EUR) >0 AND Sum(IRBA_EXPOSURE_EUR) =0) then 'KSA / leeres IRBA Exposure'
                when Max(ANSATZ_ARM_LEVEL2_MAX)>=3 AND Sum(KSA_EXPOSURE_EUR) =0 AND Sum(IRBA_EXPOSURE_EUR) >0 then 'IRBA / leeres KSA Exposure'
                else 'Mischfall'
            end AS ANSATZ,
            case
                when Min(ANSATZ_ARM_LEVEL2_MIN)<3 And Max(ANSATZ_ARM_LEVEL2_MAX)<3 then Null
                else Max(PDWERT_MAX)
                end AS PD_MAX,
            case
                when Min(ANSATZ_ARM_LEVEL2_MIN)<3 And Max(ANSATZ_ARM_LEVEL2_MAX)<3 then Null
                    else Sum(RWA)
                end AS EAD_X_PD,
            case
                when Min(ANSATZ_ARM_LEVEL2_MIN)<3 And Max(ANSATZ_ARM_LEVEL2_MAX)<3 then Null
                when Sum(EAD_NON_SECURITIZED_EUR)=0 then Max(PDWERT_MAX)
                else Sum(RWA)/Sum(EAD_NON_SECURITIZED_EUR)
            end AS PD_WEIGHTED,
            case
                when Max(INTERNE_RATING_NOTE_ARM_MAX)>=91 then Null
                else Max(INTERNE_RATING_NOTE_ARM_MAX)
            end AS MAX_RATING,
           listagg(distinct SECURITISATION_FLAG, ', ') within group ( order by SECURITISATION_FLAG) as SECURITISATION_FLAG,
           listagg(distinct PRODUCT_TYPE_DETAIL, ', ') within group ( order by PRODUCT_TYPE_DETAIL) as PRODUCT_TYPE_DETAIL
    from AGGREGATE
    GROUP BY FACILITY_ID, CUT_OFF_DATE, PORTFOLIO, CLIENT_NO, ORIGINAL_CURRENCY
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
            when /*PD_WEIGHTED<=0.95 and*/ ANSATZ='KSA / leeres IRBA Exposure' then RW.RATINGSTUFE
            else E.NUM_RATING
     end AS INTERNAL_RATINGSTUFE
    ----------------------------------------------------------------------------------------------------
FROM AGGREGATE_UNIQUE_FACILITIES as B
LEFT JOIN  SMAP.KR_PRODUKTE_MAP as C ON B.PRODUCT_TYPE_DETAIL = C.ZM_PRODNR
LEFT JOIN SMAP.AUSPLATZIERUNG_MAP as D  ON B.SECURITISATION_FLAG =D.BIC_XB_DAUSKZ
LEFT JOIN SMAP.RATING_MAP as E ON (B.PD_WEIGHTED < E.PD_UBOUND) AND (B.PD_WEIGHTED >= E.PD_LBOUND)
LEFT JOIN SMAP.KR_RW_MAP as RW ON (B.RW_Non_Securitized >= RW.RW_LBOUND) AND (B.RW_Non_Securitized < RW.RW_UBOUND)
;

-- CI START FOR ALL TAPES
-- Current-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_KREDITRISIKO_BANKANALYSER_CURRENT');
create table AMC.TABLE_KREDITRISIKO_BANKANALYSER_CURRENT like CALC.VIEW_KREDITRISIKO_BANKANALYSER distribute by hash(FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_KREDITRISIKO_BANKANALYSER_CURRENT_FACILITY_ID on AMC.TABLE_KREDITRISIKO_BANKANALYSER_CURRENT (FACILITY_ID);
create index AMC.INDEX_KREDITRISIKO_BANKANALYSER_CURRENT_CLIENT_NO   on AMC.TABLE_KREDITRISIKO_BANKANALYSER_CURRENT (CLIENT_NO);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_KREDITRISIKO_BANKANALYSER_CURRENT');
-- Archiv-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_KREDITRISIKO_BANKANALYSER_ARCHIVE');
create table AMC.TABLE_KREDITRISIKO_BANKANALYSER_ARCHIVE like CALC.VIEW_KREDITRISIKO_BANKANALYSER distribute by hash(FACILITY_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2025' EVERY 1 MONTH) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_KREDITRISIKO_BANKANALYSER_ARCHIVE_FACILITY_ID on AMC.TABLE_KREDITRISIKO_BANKANALYSER_ARCHIVE (FACILITY_ID);
create index AMC.INDEX_KREDITRISIKO_BANKANALYSER_ARCHIVE_CLIENT_NO   on AMC.TABLE_KREDITRISIKO_BANKANALYSER_ARCHIVE (CLIENT_NO);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_KREDITRISIKO_BANKANALYSER_ARCHIVE');
-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_KREDITRISIKO_BANKANALYSER_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_KREDITRISIKO_BANKANALYSER_ARCHIVE');

--select * from AMC.TABLE_KREDITRISIKO_BANKANALYSER_CURRENT;

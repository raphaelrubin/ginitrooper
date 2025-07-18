-- View erstellen
drop view CALC.VIEW_PRE_FACILITY_DERIVATE;
create or replace view  CALC.VIEW_PRE_FACILITY_DERIVATE AS
    with raw AS (
        select A.*,DERIVATE_TD.TRADE_DATE AS TRADE_DATE_2,case when TRADECURRENCY = 'EUR' then 'XXXX' else TRADECURRENCY end AS ADD_CURR from NLB.BW_DERIVATE AS A
        left join SMAP.DERIVATE_TRADE_DATE_201812 AS DERIVATE_TD on DERIVATE_TD.FACILITY_ID = A.FACILITYID_SAP_ID
        union all
        select A.*,DERIVATE_TD.TRADE_DATE AS TRADE_DATE_2,case when TRADECURRENCY = 'EUR' then 'XXXX' else TRADECURRENCY end AS ADD_CURR from BLB.BW_DERIVATE AS A
        left join SMAP.DERIVATE_TRADE_DATE_201812 AS DERIVATE_TD on DERIVATE_TD.FACILITY_ID = A.FACILITYID_SAP_ID
        union all
        select A.*,DERIVATE_TD.TRADE_DATE AS TRADE_DATE_2,case when TRADECURRENCY = 'EUR' then 'XXXX' else TRADECURRENCY end AS ADD_CURR from ANL.BW_DERIVATE AS A
        left join SMAP.DERIVATE_TRADE_DATE_201812 AS DERIVATE_TD on DERIVATE_TD.FACILITY_ID = A.FACILITYID_SAP_ID
    ),
    DERIVATE_2018 as(
        select R.*, first_value(ADD_CURR) over (partition by FACILITYID_SAP_ID,CUTOFFDATE order by ADD_CURR desc NULLS lAST ) AS FIN_CURR
        from RAW     AS R
        inner join CALC.SWITCH_PORTFOLIO_CURRENT as C on R.FACILITYID_SAP_ID = C.FACILITY_ID and R.CUTOFFDATE=C.CUT_OFF_DATE
    ),
    BW_DERIVATE_BASIS as (
        select distinct CS_TRN_LC,CS_TRN_TC,CS_ITEM,ZM_KFSEM,ZM_AOCURR,A.CUTOFFDATE,FACILITY_ID,trim(L '0' from replace(ZM_EXTCON,'CONTRACT_','')) as TRADE_ID
        from NLB.BW_ZBC_IFRS_CURRENT as A
        inner join CALC.SWITCH_PORTFOLIO_CURRENT as C on A.ZM_PRODID = C.FACILITY_ID and A.CUTOFFDATE=C.CUT_OFF_DATE
        left join DERIVATE_2018 as D on D.CUTOFFDATE= A.CUTOFFDATE
        where SUBSTR(FACILITY_ID,6,2)= '15'
            and D.CUTOFFDATE is null
    ),
    no_TC as (
        select FACILITY_ID,CUTOFFDATE,ZM_AOCURR from (
            select FACILITY_ID,CUTOFFDATE,ZM_AOCURR,ROW_NUMBER() over (partition by FACILITY_ID,CUTOFFDATE order by REPLACE(ZM_AOCURR,'EUR','XXXX') desc) as NBR from (
                select distinct FACILITY_ID,CUTOFFDATE,ZM_AOCURR from BW_DERIVATE_BASIS
            )
                                           ) where NBR > 1
    ),
    DATA as (
        select * from (
            select A.CUTOFFDATE ,A.FACILITY_ID,SUM(CS_TRN_LC) AS FAIRVALUE_DIRTY_EUR,SUM(CS_TRN_TC) as FAIRVALUE_DIRTY_TC,TRADE_ID from
            BW_DERIVATE_BASIS as A
            where 1=1
                 and left(CS_ITEM,1)in ('1','2')
            group by CUTOFFDATE,FACILITY_ID,TRADE_ID
                      )
    ),
    -- Alle Derivate (Spot, Hüsken, Anthes)
     DERIVATE_PRE as (
        select distinct
               CUT_OFF_DATE,
               FACILITY_ID,
               TRADE_ID,
               BORROWERID
         from NLB.SPOT_DERIVATE_CURRENT
        where LOANSTATE='AKTIV'
        union
         select distinct
                CUT_OFF_DATE,
                FACILITY_ID,
                TRADE_ID,
                KUNDENNUMMER as BORROWERID
         from NLB.DERIVATE_TEMP_CURRENT
         union
         select distinct
                MUR.CUT_OFF_DATE,
                MAP.FACILITY_ID,
                TRADE_ID,
                MUR.KUNDENNUMMER as BORROWERID
         from NLB.DERIVATE_MUREX_CURRENT as MUR
         left join NLB.DERIVATE_FACILITY_ID_MUREX_ID_MAPPING_CURRENT as MAP on MAP.MUREX_ID=MUR.TRADE_ID and MAP.CUT_OFF_DATE=MUR.CUT_OFF_DATE
    ),
    prefianl as (
    ----------------------------------------------------------------------------------------------------------------------------------------
    --alle Daten vor 2019
    select
        A.CUTOFFDATE                        as CUT_OFF_DATE
        ,FACILITYID_SAP_ID
         ,NULL                                                                         AS ORIGINAL_CURRENCY
        ,SUM(FAIRVALUE_DIRTY_EUR)           AS FAIRVALUE_DIRTY_EUR
        --,coalesce(SUM(FAIRVALUE_DIRTY_TC),SUM(FAIRVALUE_DIRTY_EUR) * KURS) AS FAIRVALUE_DIRTY_TC --achtung eventuell ein Fehler, je nachdem was hanno entscheidet bleibt das Feld für OTC leer
        ,SUM(FAIRVALUE_DIRTY_TC)            AS FAIRVALUE_DIRTY_TC
        ,MATURITYDATE
        ,coalesce(Trade_DATE,TRADE_DATE_2)  AS Trade_DATE
        ,NULL                               as TRADE_ID
        ,NULL                               as INITIAL_TRADE_ID
        ,NULL                               as TI_MAN
        ,NULL                               as LOANSTATE
        ,FIN_CURR,
        NULL                                AS FAIR_VALUE_EUR,
        NULL                                AS CVA_EUR,
        NULL                                AS DVA_EUR,
        NULL                                AS FBA_EUR,
        NULL                                AS FCA_EUR,
        NULL                                AS DERIVATE_PO_EUR,
        NULL                                AS DERIVATE_PO_TC,
        NULL                                AS PORTFOLIO,
        Current_USER                        AS CREATED_USER,      -- Letzter Nutzer, der diese Tabelle gebaut hat.
        Current_TIMESTAMP                   AS CREATED_TIMESTAMP  -- Neuester Zeitstempel, wann diese Tabelle zuletzt gebaut wurde.
    from DERIVATE_2018 AS A
    left join IMAP.CURRENCY_MAP AS CURR on CURR.ZIEL_WHRG=FIN_CURR and CURR.CUT_OFF_DATE=A.CUTOFFDATE
    GROUP BY A.CUTOFFDATE,FACILITYID_SAP_ID,MATURITYDATE,coalesce(Trade_DATE,TRADE_DATE_2),FIN_CURR,KURS
    ----------------------------------------------------------------------------------------------------------------------------------------
        union all
    ----------------------------------------------------------------------------------------------------------------------------------------
    --alle diejenigen derivate die wir nicht aus dem SPOT/MUREX haben
    select  distinct  A.CUTOFFDATE                                                          as CUT_OFF_DATE,
            A.FACILITY_ID                                                                   as FACILITYID_SAP_ID,
            NULL                                                                            AS ORIGINAL_CURRENCY,
            A.FAIRVALUE_DIRTY_EUR                                                           AS FAIRVALUE_DIRTY_EUR,
            case when B.FACILITY_ID is not null then Null else A.FAIRVALUE_DIRTY_TC end     as FAIRVALUE_DIRTY_TC,
            HELP.CURRENT_CONTRACTUAL_MATURITY_DATE                                          AS MATURITYDATE,
            HELP.ORIGINATION_DATE                                                           AS Trade_DATE,
            A.TRADE_ID                                                                      as TRADE_ID,
            NULL                                                                            as INITIAL_TRADE_ID,
            HELP.TRADE_ID                                                                   as TI_MAN,
            NULL                                                                            as LOANSTATE,
            COALESCE(ZM_AOCURR,'EUR')                                                       AS FIN_CURR,
            NULL                                                                            as FAIR_VALUE_EUR,
            NULL                                                                            as CVA_EUR,
            NULL                                                                            as DVA_EUR,
            NULL                                                                            as FBA_EUR,
            NULL                                                                            as FCA_EUR,
            NULL                                                                            as DERIVATE_PO_EUR,
            NULL                                                                            as DERIVATE_PO_TC,
            NULL                                AS PORTFOLIO,
                     Current_USER                                                                    as CREATED_USER,      -- Letzter Nutzer, der diese Tabelle gebaut hat.
            Current_TIMESTAMP                                                               as CREATED_TIMESTAMP  -- Neuester Zeitstempel, wann diese Tabelle zuletzt gebaut wurde.
    from DATA as A
    left join no_TC as B on A.FACILITY_ID = B.FACILITY_ID and A.CUTOFFDATE = B.CUTOFFDATE
    left join SMAP.DERIVATRE_DATES_201906 as HELP on HELP.CUT_OFF_DATE=A.CUTOFFDATE and HELP.FACILITY_ID=A.FACILITY_ID
    left join DERIVATE_PRE as DER on DER.CUT_OFF_DATE=A.CUTOFFDATE AND DER.FACILITY_ID=A.FACILITY_ID
    where DER.FACILITY_ID is null
----------------------------------------------------------------------------------------------------------------------------------------
        union all
----------------------------------------------------------------------------------------------------------------------------------------
    --alle Daten aus dem SPOT/MUREX die ein FLAG haben oder im AVIATION Portfolio sind
    --Murex überschreibt SPOT. -> da SPOT immer Currency, die nicht EUR ist.
    select distinct
            DERIV.CUT_OFF_DATE,
            DERIV.FACILITY_ID                                                           AS FACILITYID_SAP_ID,
            coalesce(MUR.P_AND_L_CURRENCY,SPOT.ORIGINALCURRENCY)                        AS ORIGINAL_CURRENCY,
            SPOT.FAIR_VALUE_EUR                                                         AS FAIRVALUE_DIRTY_EUR,
            NULL                                                                        AS FAIRVALUE_DIRTY_TC,
            coalesce(MUR.MATURITY_DATE, HUS.MATURITY_DATE,SPOT.MATURITYINFORMATION)     AS MATURITYDATE,
            coalesce(MUR.ORIGINATIONDATE, HUS.ORIGINATION_DATE,SPOT.ORIGINATIONDATE)    AS TRADE_DATE,
            coalesce(MUR.TRADE_ID, HUS.TRADE_ID,SPOT.TRADE_ID)                          AS TRADE_ID,
            SPOT.INITIAL_TRADE_ID                                                       AS INITIAL_TRADE_ID,
            NULL                                                                        AS TI_MAN,
            coalesce(MUR.LOANSTATE, HUS.LOAN_STATE,SPOT.LOANSTATE)                      AS LOANSTATE,
            coalesce(MUR.P_AND_L_CURRENCY, HUS.WAEHRUNG,SPOT.ORIGINALCURRENCY)          AS FIN_CURR,
            coalesce(NULL,SPOT.FAIR_VALUE_EUR)                                          AS FAIR_VALUE_EUR,
            coalesce(NULL,SPOT.CVA_EUR)                                                 AS CVA_EUR,
            coalesce(NULL,SPOT.DVA_EUR)                                                 AS DVA_EUR,
            coalesce(NULL,SPOT.FBA_EUR)                                                 AS FBA_EUR,
            coalesce(NULL,SPOT.FCA_EUR)                                                 AS FBC_EUR,
            coalesce(NULL,SPOT.PRINCIPALOUTSTANDING_EUR)                                AS DERIVATE_PO_EUR,
            coalesce(NULL,SPOT.PRINCIPALOUTSTANDING_TC)                                 AS DERIVATE_PO_TC,
            MUR.PORTFOLIO                                                                AS PORTFOLIO,
            Current_USER                                                                AS CREATED_USER,      -- Letzter Nutzer, der diese Tabelle gebaut hat.
            Current_TIMESTAMP                                                           AS CREATED_TIMESTAMP  -- Neuester Zeitstempel, wann diese Tabelle zuletzt gebaut wurde.
    from DERIVATE_PRE as DERIV
                  left join NLB.DERIVATE_TEMP_CURRENT as HUS
                            on HUS.CUT_OFF_DATE=DERIV.CUT_OFF_DATE and HUS.FACILITY_ID=DERIV.FACILITY_ID
                  left join NLB.SPOT_DERIVATE_CURRENT as SPOT
                            on SPOT.CUT_OFF_DATE=DERIV.CUT_OFF_DATE and SPOT.FACILITY_ID=DERIV.FACILITY_ID and SPOT.LOANSTATE='AKTIV'
                  left join NLB.DERIVATE_MUREX_CURRENT as MUR
                            on MUR.CUT_OFF_DATE=DERIV.CUT_OFF_DATE and MUR.TRADE_ID=DERIV.TRADE_ID
                  left join NLB.DERIVATE_FACILITY_ID_MUREX_ID_MAPPING_CURRENT as MAP
                            on MAP.MUREX_ID=MUR.TRADE_ID and MAP.CUT_OFF_DATE=MUR.CUT_OFF_DATE
    ),final as (
    select distinct
        CUT_OFF_DATE
         ,FACILITYID_SAP_ID
         ,ORIGINAL_CURRENCY
         ,FAIRVALUE_DIRTY_EUR
         ,FAIRVALUE_DIRTY_TC
         ,first_value(MATURITYDATE) over (partition by FACILITYID_SAP_ID order by TRADE_ID,CUT_OFF_DATE desc) as MATURITYDATE
         ,first_value(Trade_DATE) over (partition by FACILITYID_SAP_ID order by TRADE_ID,CUT_OFF_DATE desc) as Trade_DATE
         ,first_value(TRADE_ID) over (partition by FACILITYID_SAP_ID order by TRADE_ID,CUT_OFF_DATE desc) as TRADE_ID
         ,INITIAL_TRADE_ID
         ,TI_MAN
         ,LOANSTATE --first_value(LOANSTATE) over (partition by FACILITYID_SAP_ID order by TRADE_ID,CUT_OFF_DATE desc) as LOANSTATE
         ,FIN_CURR
         ,FAIR_VALUE_EUR as FAIR_VALUE_EUR
         ,CVA_EUR
         ,DVA_EUR
         ,FBA_EUR
         ,FCA_EUR
         ,DERIVATE_PO_EUR
         ,DERIVATE_PO_TC
        ,PORTFOLIO
         ,CREATED_USER
         ,CREATED_TIMESTAMP
    from prefianl
    )
    ,duplikate_check as (select * from (
        select
          amc.*
          ,COUNT(*) over (partition by FACILITYID_SAP_ID,CUT_OFF_DATE) AS nbr
        from final AS amc
        ) AS amc
        where nbr>1
    )
    select * from final
;

-- CI START FOR ALL TAPES
-- Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_PRE_FACILITY_DERIVATE_CURRENT');
create table AMC.TABLE_PRE_FACILITY_DERIVATE_CURRENT like CALC.VIEW_PRE_FACILITY_DERIVATE distribute by hash(FACILITYID_SAP_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_PRE_FACILITY_DERIVATE_CURRENT_FACILITYID_SAP_ID on AMC.TABLE_PRE_FACILITY_DERIVATE_CURRENT (FACILITYID_SAP_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_PRE_FACILITY_DERIVATE_CURRENT');
-- CI END FOR ALL TAPES

-- SWITCH View erstellen
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_PRE_FACILITY_DERIVATE_CURRENT');
-- Vergangene Umsätze der AOER (NLB, BLB, ANL)

-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_CASH_FLOW_PAST_AOER;
create or replace view CALC.VIEW_CASH_FLOW_PAST_AOER as
    with
    CUTOFFDATES as (
        select COD_ALL.CUT_OFF_DATE as CUTOFFDATE, row_number() over (order by COD_ALL.CUT_OFF_DATE desc) as NBR
        from CALC.AUTO_TABLE_CUTOFFDATES as COD_ALL
        full outer join CALC.AUTO_TABLE_CUTOFFDATES as COD_CURRENT on COD_ALL.CUT_OFF_DATE <= COD_CURRENT.CUT_OFF_DATE
        where COD_CURRENT.IS_ACTIVE
    ),
    CBB_STAMMDATEN as (
        select
            PORTFOLIO.FACILITY_ID_CBB,
            coalesce(LENDING.OWN_SYNDICATE_QUOTA,100)   as OWN_SYNDICATE_QUOTA,
            PORTFOLIO.CUT_OFF_DATE
        from CALC.SWITCH_PORTFOLIO_CURRENT    as PORTFOLIO
        left join CBB.LENDING_CURRENT       as LENDING      on  PORTFOLIO.CUT_OFF_DATE= LENDING.CUT_OFF_DATE and 'K028-' || LENDING.IDENTITY = left(PORTFOLIO.FACILITY_ID_CBB,12)
        where PORTFOLIO.FACILITY_ID_CBB is not NULL
    ),
    PORTFOLIO_EXTENDED as (
        --select * from AMC.AMC_FACILITY_DETAILS_FINISH
        select distinct
            PORTFOLIO.CUT_OFF_DATE, DATA_CUT_OFF_DATE,
            BRANCH_SYSTEM,
            BRANCH_CLIENT, CLIENT_NO, CLIENT_ID_ORIG,
            BRANCH_FACILITY,
            case
                when SUBSTR(PORTFOLIO.FACILITY_ID,6,2) = '33' then
                    replace(PORTFOLIO.FACILITY_ID,'-31-','-30-') -- Laut Telefonat mit C. Schücke ist GEVO immer Netto daher 31 Satzart, wird in Umsätze aber als 30 deklariert.
                else
                    PORTFOLIO.FACILITY_ID
            end as FACILITY_ID,
            PORTFOLIO.FACILITY_ID_CBB, CURRENCY,
            case
                when SUBSTR(PORTFOLIO.FACILITY_ID,6,2) in ('11','15')
                    then 100.0
                else coalesce(CBB_STAMMDATEN.OWN_SYNDICATE_QUOTA,SPOT_STAMMDATEN.OWNSYNDICATEQUOTA,100.0 )
            end                                                                                                                    AS OWN_SYNDICATE_QUOTA,
            SPOT_STAMMDATEN.PRINCIPALOUTSTANDING_EUR                                                                               AS PRICIPAL_OST_EUR_SPOT
        from CALC.SWITCH_PORTFOLIO_ARCHIVE            as PORTFOLIO
        left join CALC.SWITCH_FACILITY_PRE_SPOT_STAMMDATEN_AOER_CURRENT as SPOT_STAMMDATEN  on SPOT_STAMMDATEN.FACILITY_ID = PORTFOLIO.FACILITY_ID and SPOT_STAMMDATEN.CUT_OFF_DATE=PORTFOLIO.CUT_OFF_DATE -- FACILITY_ID, CUTOFFDATE, PRINCIPALOUTSTANDING_EUR
        left join CBB_STAMMDATEN                    as CBB_STAMMDATEN   on PORTFOLIO.CUT_OFF_DATE = CBB_STAMMDATEN.CUT_OFF_DATE and PORTFOLIO.FACILITY_ID_CBB=CBB_STAMMDATEN.FACILITY_ID_CBB -- FACILITY_ID_CBB, CUT_OFF_DATE, OWN_SYNDICATE_QUOTA
        left join CUTOFFDATES                       as CUTOFFDATENR     on CUTOFFDATENR.CUTOFFDATE = PORTFOLIO.CUT_OFF_DATE
        where CUTOFFDATENR.NBR <= 2 -- Nehme die letzten 2 Cut-Off Dates
    ),
    SPOT_PRE as (
        select NLB.CUTOFFDATE, CLIENT_ID, FACILITY_ID, OWNSYNDICATEQUOTA, PRINCIPALOUTSTANDING_EUR
        from NLB.SPOT_STAMMDATEN as NLB
        left join CUTOFFDATES  as CUTOFFDATENR     on CUTOFFDATENR.CUTOFFDATE = NLB.CUTOFFDATE
        where CUTOFFDATENR.NBR = 2
            union all
        select BLB.CUTOFFDATE, CLIENT_ID, FACILITY_ID, OWNSYNDICATEQUOTA, PRINCIPALOUTSTANDING_EUR
        from BLB.SPOT_STAMMDATEN as BLB
        left join CUTOFFDATES  as CUTOFFDATENR     on CUTOFFDATENR.CUTOFFDATE = BLB.CUTOFFDATE
        where CUTOFFDATENR.NBR = 2
            union all
        select ANL.CUTOFFDATE, CLIENT_ID, FACILITY_ID, OWNSYNDICATEQUOTA, PRINCIPALOUTSTANDING_EUR
        from ANL.SPOT_STAMMDATEN as ANL
        left join CUTOFFDATES  as CUTOFFDATENR     on CUTOFFDATENR.CUTOFFDATE = ANL.CUTOFFDATE
        where CUTOFFDATENR.NBR = 2
    ),
    SYND_CORRECTION as (
        select CUT_OFF_DATE, DATA_CUT_OFF_DATE, BRANCH_SYSTEM as BRANCH, CLIENT_NO, CLIENT_ID_ORIG, CURR.FACILITY_ID,
               case when OWN_SYNDICATE_QUOTA='0' and PRICIPAL_OST_EUR_SPOT is null then ARCH.OWNSYNDICATEQUOTA
                    when OWN_SYNDICATE_QUOTA='0' and PRICIPAL_OST_EUR_SPOT='0' then ARCH.OWNSYNDICATEQUOTA
                    else CURR.OWN_SYNDICATE_QUOTA end as OWN_SYNDICATE_QUOTA
        from PORTFOLIO_EXTENDED as CURR
            left join SPOT_PRE as ARCH on ARCH.FACILITY_ID=CURR.FACILITY_ID
    ),
    DATA as (
    --------------------------
    -- NLB Buchungen
        select distinct
            case
                --when left(SAP_ID,7) = '0009-33' then '0009-33-00'|| SUBSTR(SAP_ID,11,10) || '-31-0000000000'
                when left(SAP_ID,7) = '0009-33' then replace(SAP_ID,'-30-','-31-') -- GEVO Umsätze sind immer Netto, daher Satzart 31 statt 30 wie in der Quelltabelle (Telefonat C. Schücke 8.12.20)
                when left(SAP_ID,7) = '0009-30' then replace(SAP_ID,'-30-0000000000','-31-0000000000') -- Darlehens Umsätze sind immer Netto, daher Satzart 31 statt 30 wie in der Quelltabelle LW
                else SAP_ID
            end  as FACILITY_ID
            ,CASH_FLOW_PAST_NLB.UMSATZ_ART_GEVO_1 as UMSATZ_ART
            ,case
                when left(SAP_ID,7) = '0009-33' then
                    sign(NOMINAL_WERT_WHRG) -- Vorzeichen des Nominalwertes für LoanIQ
                else
                    1 -- Vorzeichen andernfalls schon im TW vorhanden
            end  * TRANSAKTION_WERT_WHRG * coalesce(CBB_STAMMDATEN.OWN_SYNDICATE_QUOTA,100) /100 as TRANSAKTION_WERT_WHRG
            ,TRANSAKTION_WHRG_SCHL,
            VALUTA_DATUM,
            BUCHUNG_DATUM as BUCHUNGS_DATUM
            ,ERFOLGSART,
            SYSTEM_ID_BUCHUNG as SOURCE_SYSTEM,
            case when SYSTEM_ID_BUCHUNG = 'LOANIQ' then LEFT(UMSATZ_ART_3,8) end as PAST_DUE_ALIAS,
            CUTOFFDATE as CUT_OFF_DATE, replace(BUCHUNG_ID,';',',') as BUCHUNGS_ID
            ,STORNO_BUCHUNG_ID as STORNO_BUCHUNGS_ID,
            case
                when GEGEN_KONTO_NR in (21874015000,21874019000,25874150000,29810970033,29860970029,29860970035,21879410000,21979410000,21975000000) then
                    TRUE
                when CASH_FLOW_PAST_NLB.UMSATZ_ART_GEVO_1 like '%ABSCHREIBUNG%' then
                    TRUE
                else NULL
            end as IS_BAD_DEBT_LOSS, -- Handelt es sich um eine Abschreibung? (Diese werden von bestimmten Konten gebucht, mit Ausnahme von Gruppenbuchungen)
            'NLB Buchung'  as COMMENT
        from NLB.SPOT_UMSATZ_CURRENT          as CASH_FLOW_PAST_NLB
        left join CALC.SWITCH_PORTFOLIO_CURRENT as PORTFOLIO      on PORTFOLIO.CUT_OFF_DATE=CASH_FLOW_PAST_NLB.CUTOFFDATE and PORTFOLIO.FACILITY_ID = CASH_FLOW_PAST_NLB.SAP_ID
        left join CBB_STAMMDATEN           as CBB_STAMMDATEN on CBB_STAMMDATEN.CUT_OFF_DATE = PORTFOLIO.CUT_OFF_DATE and PORTFOLIO.FACILITY_ID_CBB=CBB_STAMMDATEN.FACILITY_ID_CBB
        where
            1=1
            and CASH_FLOW_PAST_NLB.UMSATZ_ART_GEVO_1 in (/*'GP_DARL_AUFBAU_RS_TILGUNG_A','DARL_AUFBAU_RS_TILGUNG_A',*/'DARL_KAPITALUMBUCHUNG_EMPF','DARL_ZAHLUNG_RS_TILGUNG_A','DARL_KAPITALUMBUCHUNG_SEND','DARL_AUFBAU_RS_ZINSEN_A','DARL_ABG_GEBU_ERFOLG_A','DARL_AUFBAU_RS_TILGUNG_A','GP_EINZAHL','GP_AUSZAHL','EINZAHL','AUSZAHL','LEND_ABGRZINS_AIPD_A','DARL_TILGUNG_A_W','DARL_AUSZAHLUNG_A_W','DARL_ABG_ZINS_ZAHLUNG_A','DARL_AUSZAHLUNG_A','DARL_GEBUEHREN_A','DARL_TILGUNG_A','DARL_SONDERTILGUNG_A','DARL_SONDERTILGUNG_B_A','DARL_DIREKTABSCHREIBUNG_A','DARL_SONDERTILGUNG_K_A','DARL_SHARED_ADJ_AUSZ','DARL_SHARED_ADJ_TILG','DARL_BW_AMO_GEB_A'/*,'DARL_ZAHLUNG_RS_NEBENLEIST_A','DARL_ZAHLUNG_RS_TILGUNG_A','DARL_ZAHLUNG_RS_ZINSEN_A'*/,'DARL_ZINSEN_A'/*,'GP_DARL_ZAHLUNG_RS_ZINSEN_A','DARL_ZAHLUNG_RS_ZINSEN_A'*/)
            and nullif(UMSATZ_ART_GEVO_2,'DARL_BISTA_VERKAUF') is NULL
            and TRANSAKTION_WERT_WHRG <> 0
            and VALUTA_DATUM > '01.12.2018'
    --------------------------
    union all
    --------------------------
    -- ANL normale Buchungen
        select distinct
            CASH_FLOW_PAST_ANL.SAP_ID                                                                    as FACILITY_ID,
            coalesce(CASH_FLOW_PAST_ANL.UMSATZ_ART_GEVO_1,CASH_FLOW_PAST_ANL.UMSATZ_ART_GEVO_2)                   as UMSATZ_ART,
            CASH_FLOW_PAST_ANL.TRANSAKTION_WERT_WHRG * coalesce(CORR.OWN_SYNDICATE_QUOTA,100) / 100      as TRANSAKTION_WERT_WHRG,
            CASH_FLOW_PAST_ANL.TRANSAKTION_WHRG_SCHL,
            CASH_FLOW_PAST_ANL.VALUTA_DATUM,
            CASH_FLOW_PAST_ANL.BUCHUNG_DATUM                                                             as BUCHUNGS_DATUM,
            CASH_FLOW_PAST_ANL.ERFOLGSART,
            SYSTEM_ID_BUCHUNG as SOURCE_SYSTEM,
            case when SYSTEM_ID_BUCHUNG = 'LOANIQ' then LEFT(UMSATZ_ART_3,8) end as PAST_DUE_ALIAS,
            CASH_FLOW_PAST_ANL.CUTOFFDATE                                                                as CUT_OFF_DATE,
            CASH_FLOW_PAST_ANL.BUCHUNG_ID                                                                as BUCHUNGS_ID,
            CASH_FLOW_PAST_ANL.STORNO_BUCHUNG_ID                                                         as STORNO_BUCHUNGS_ID,
            NULL as IS_BAD_DEBT_LOSS, -- Handelt es sich um eine Abschreibung? (Diese werden von bestimmten Konten gebucht)
            'ANL normale Buchung'                                                               as COMMENT
        from ANL.SPOT_UMSATZ_CURRENT    as CASH_FLOW_PAST_ANL
        left join PORTFOLIO_EXTENDED    as PORTFOLIO    on PORTFOLIO.CUT_OFF_DATE=CASH_FLOW_PAST_ANL.CUTOFFDATE and PORTFOLIO.FACILITY_ID = CASH_FLOW_PAST_ANL.SAP_ID
        left join SYND_CORRECTION       as CORR         on CORR.CUT_OFF_DATE=CASH_FLOW_PAST_ANL.CUTOFFDATE and CORR.FACILITY_ID=CASH_FLOW_PAST_ANL.SAP_ID
        where
            1=1
            and coalesce(CASH_FLOW_PAST_ANL.UMSATZ_ART_GEVO_1,CASH_FLOW_PAST_ANL.UMSATZ_ART_GEVO_2) in ('DARL_AUFL_ABGRZINS_KORR_A_W','DARL_AUFL_ABGRZINS_A_W','GP_EINZAHL','GP_DARL_ZINSEN_A','GP_DARL_AUSZAHLUNG_A_W','GP_AUSZAHL','GIRO_EINZAHLUNG','GIRO_AUSZAHLUNG','EINZAHL','AUSZAHL','GP_DARL_TILGUNG_A_W','DARL_TILGUNG_A_W','DARL_AUSZAHLUNG_A_W','DARL_ABG_ZINS_ZAHLUNG_A','DARL_AUSZAHLUNG_A','DARL_GEBUEHREN_A','DARL_TILGUNG_A','DARL_SONDERTILGUNG_A','DARL_SONDERTILGUNG_B_A','DARL_DIREKTABSCHREIBUNG_A','DARL_SONDERTILGUNG_K_A','DARL_ZAHLUNG_RS_NEBENLEIST_A','DARL_ZAHLUNG_RS_TILGUNG_A','DARL_ZAHLUNG_RS_ZINSEN_A','DARL_ZINSEN_A','GP_DARL_ZAHLUNG_RS_ZINSEN_A')
            and nullif(nullif(CASH_FLOW_PAST_ANL.UMSATZ_ART_GEVO_2,'DARL_AUFL_ABGRZINS_KORR_A_W'),'DARL_AUFL_ABGRZINS_A_W') is NULL
            and CASH_FLOW_PAST_ANL.TRANSAKTION_WERT_WHRG <> 0
            and CASH_FLOW_PAST_ANL.BUCHUNG_DATUM <= CASH_FLOW_PAST_ANL.CUTOFFDATE - case when dayofweek(CASH_FLOW_PAST_ANL.CUTOFFDATE)=1 Then 2 when dayofweek(CASH_FLOW_PAST_ANL.CUTOFFDATE)=7 then 1 else 0 end days
    --------------------------
    union all
    --------------------------
    -- ANL Ultimo Buchungen
        select distinct
            SAP_ID                          as FACILITY_ID,
            coalesce(CASH_FLOW.UMSATZ_ART_GEVO_1,CASH_FLOW.UMSATZ_ART_GEVO_2) as UMSATZ_ART,
            TRANSAKTION_WERT_WHRG * coalesce(CORR.OWN_SYNDICATE_QUOTA,100) / 100,
            TRANSAKTION_WHRG_SCHL,
            VALUTA_DATUM,
            BUCHUNG_DATUM,
            ERFOLGSART,
            SYSTEM_ID_BUCHUNG as SOURCE_SYSTEM,
            case when SYSTEM_ID_BUCHUNG = 'LOANIQ' then LEFT(UMSATZ_ART_3,8) end as PAST_DUE_ALIAS,
            NEXT_CUTOFFDATE.CUTOFFDATE      as CUT_OFF_DATE,
            BUCHUNG_ID                      as BUCHUNGS_ID,
            STORNO_BUCHUNG_ID               as STORNO_BUCHUNGS_ID,
            NULL as IS_BAD_DEBT_LOSS, -- Handelt es sich um eine Abschreibung? (Diese werden von bestimmten Konten gebucht)
            'ANL Ultimo Buchung'            as COMMENT
        from ANL.SPOT_UMSATZ            as CASH_FLOW -- kann hier nicht current nehmen, da die Daten des vorherigen CoDs gebraucht werden.
        inner join CALC.SWITCH_PORTFOLIO_CURRENT as CUR on CUR.FACILITY_ID = Cash_FLOW.SAP_ID and CASH_FLOW.CUTOFFDATE=CUR.CUT_OFF_DATE
        left join CUTOFFDATES           as DATA_CUTOFFDATE      on DATA_CUTOFFDATE.CUTOFFDATE=CASH_FLOW.CUTOFFDATE
        left join CUTOFFDATES           as NEXT_CUTOFFDATE      on NEXT_CUTOFFDATE.NBR = DATA_CUTOFFDATE.NBR -1
        left join PORTFOLIO_EXTENDED    as PORTFOLIO            on PORTFOLIO.CUT_OFF_DATE=NEXT_CUTOFFDATE.CUTOFFDATE and PORTFOLIO.FACILITY_ID = CASH_FLOW.SAP_ID
        left join SYND_CORRECTION       as CORR                 on CORR.CUT_OFF_DATE=CASH_FLOW.CUTOFFDATE and CORR.FACILITY_ID=CASH_FLOW.SAP_ID
        where
            1=1
            --and CASH_FLOW.CUTOFFDATE = '30.09.2019'
            and coalesce(UMSATZ_ART_GEVO_1,UMSATZ_ART_GEVO_2) in ('DARL_AUFL_ABGRZINS_KORR_A_W','DARL_AUFL_ABGRZINS_A_W','GP_EINZAHL','GP_DARL_ZINSEN_A','GP_DARL_AUSZAHLUNG_A_W','GP_AUSZAHL','GIRO_EINZAHLUNG','GIRO_AUSZAHLUNG','EINZAHL','AUSZAHL','DARL_TILGUNG_A_W','DARL_AUSZAHLUNG_A_W','DARL_ABG_ZINS_ZAHLUNG_A','DARL_AUSZAHLUNG_A','DARL_GEBUEHREN_A','DARL_TILGUNG_A','DARL_SONDERTILGUNG_A','DARL_SONDERTILGUNG_B_A','DARL_DIREKTABSCHREIBUNG_A','DARL_SONDERTILGUNG_K_A','DARL_ZAHLUNG_RS_NEBENLEIST_A','DARL_ZAHLUNG_RS_TILGUNG_A','DARL_ZAHLUNG_RS_ZINSEN_A','DARL_ZINSEN_A','GP_DARL_ZAHLUNG_RS_ZINSEN_A')
            and nullif(nullif(UMSATZ_ART_GEVO_2,'DARL_AUFL_ABGRZINS_KORR_A_W'),'DARL_AUFL_ABGRZINS_A_W') is NULL
            and TRANSAKTION_WERT_WHRG <> 0
            and BUCHUNG_DATUM > CASH_FLOW.CUTOFFDATE - case when dayofweek(CASH_FLOW.CUTOFFDATE)=1 Then 2 when dayofweek(CASH_FLOW.CUTOFFDATE)=7 then 1 else 0 end days
            and NEXT_CUTOFFDATE.CUTOFFDATE is not NULL
    --------------------------
    union all
    --------------------------
    -- ANL AUsbuchen der INITIALEN KONSORTIALANTEILE DER KONTEN nach der AVALOC Migration
        select distinct
            PORTFOLIO_A.FACILITY_ID
            ,'KORREKTUR AUSBUCHUNG KONSORTIALANTEIL MIDAS AVALOC MIGRATION' as UMSATZ_ART
            ,-1 * (100-PORTFOLIO_B.OWN_SYNDICATE_QUOTA)/100 * PORTFOLIO_A.PRICIPAL_OST_EUR_SPOT * CURRENCY_EXCHANGE.KURS as TRANSAKTION_WERT_WHRG
            ,PORTFOLIO_A.CURRENCY          as TRANSAKTION_WHRG_SCHL
            ,PORTFOLIO_A.DATA_CUT_OFF_DATE as VALUTA_DATUM
            ,PORTFOLIO_A.DATA_CUT_OFF_DATE as BUCHUNG_DATUM
            ,NULL as ERFOLGSART,
            NULL as SOURCE_SYSTEM,
            NULL as PAST_DUE_ALIAS,
            PORTFOLIO_B.CUT_OFF_DATE as CUT_OFF_DATE
            ,NULL as BUCHUNGS_ID
            ,NULL STORNO_BUCHUNGS_ID,
            NULL as IS_BAD_DEBT_LOSS, -- Handelt es sich um eine Abschreibung? (Diese werden von bestimmten Konten gebucht) --TODO: sollen diese Abschreibungen mit aufgenommen werden???
            'ANL Ausbuchen der INITIALEN KONSORTIALANTEILE DER KONTEN nach der AVALOC Migration'  as COMMENT
        from PORTFOLIO_EXTENDED as PORTFOLIO_A
        left join PORTFOLIO_EXTENDED as PORTFOLIO_B on PORTFOLIO_A.FACILITY_ID = PORTFOLIO_B.FACILITY_ID and coalesce(PORTFOLIO_A.OWN_SYNDICATE_QUOTA,100) <> COALESCE(PORTFOLIO_B.OWN_SYNDICATE_QUOTA,100)
        left join IMAP.CURRENCY_MAP as CURRENCY_EXCHANGE on CURRENCY_EXCHANGE.CUT_OFF_DATE = PORTFOLIO_A.DATA_CUT_OFF_DATE and CURRENCY_EXCHANGE.ZIEL_WHRG=PORTFOLIO_A.CURRENCY
        where 1=1
            and SUBSTR(PORTFOLIO_A.FACILITY_ID,6,2) in ('69','70','71','73')
            and PORTFOLIO_B.CUT_OFF_DATE = '30.09.2019'
            and PORTFOLIO_A.DATA_CUT_OFF_DATE = '30.06.2019'
            and 100-PORTFOLIO_B.OWN_SYNDICATE_QUOTA <> 0
    --------------------------
    union all
    --------------------------
    -- BLB Buchungen
        select distinct
            case
                when left(SAP_ID,7) = '0004-30' then replace(SAP_ID,'-30-0000000000','-31-0000000000') -- Darlehens Umsätze sind immer Netto, daher Satzart 31 statt 30 wie in der Quelltabelle LW
                else SAP_ID
            end  as FACILITY_ID,
            CASH_FLOW_PAST_BLB.UMSATZ_ART_GEVO_1 as UMSATZ_ART,
            TRANSAKTION_WERT_WHRG,
            TRANSAKTION_WHRG_SCHL,
            VALUTA_DATUM,
            BUCHUNG_DATUM,
            ERFOLGSART,
            SYSTEM_ID_BUCHUNG as SOURCE_SYSTEM,
            case when SYSTEM_ID_BUCHUNG = 'LOANIQ' then LEFT(UMSATZ_ART_3,8) end as PAST_DUE_ALIAS,
            CUTOFFDATE as CUT_OFF_DATE,
            BUCHUNG_ID as BUCHUNGS_ID,
            STORNO_BUCHUNG_ID as STORNO_BUCHUNGS_ID,
            case when GEGEN_KONTO_NR in (9830972512,9830970123,9830971677) then TRUE else NULL end as IS_BAD_DEBT_LOSS, -- Handelt es sich um eine Abschreibung? (Diese werden von bestimmten Konten gebucht)
            'BLB Buchung'  as COMMENT
        from BLB.SPOT_UMSATZ_CURRENT as CASH_FLOW_PAST_BLB
        where
            1=1
            and UMSATZ_ART_GEVO_1 in ('GP_EINZAHL','GP_AUSZAHL','EINZAHL','AUSZAHL') --anforderung Hierke 21.08.2019 17:59
            and UMSATZ_ART_GEVO_2 is NULL
            and TRANSAKTION_WERT_WHRG <> 0
            and GESCHAEFT_ART <> 'AVAL'
    --------------------------
    ),
result as (
select
    CUT_OFF_DATE            as CUT_OFF_DATE,
    DATA.FACILITY_ID        as FACILITY_ID,
    UMSATZ_ART              as CASH_FLOW_TYPE,
    TRANSAKTION_WERT_WHRG   as TRANSACTION_VALUE_TRADECURRENCY,
    TRANSAKTION_WHRG_SCHL   as TRANSACTION_TRADECURRENCY_ISO,
    VALUTA_DATUM            as VALUTA_DATE,
    BUCHUNGS_DATUM          as PAYMENT_DATE,
    ERFOLGSART              as ERFOLGSART, -- SPÄTER ÜBER MAPPING
    SOURCE_SYSTEM           as SOURCE_SYSTEM, -- System aus dem der SPOT DIe Daten hat
    PAST_DUE_ALIAS          as PAST_DUE_ALIAS, -- Loan IQ Past Due Alias analog zu Loan IQ Daten von Tassler? (TBC)
    BUCHUNGS_ID             as TRANSACTION_ID,
    STORNO_BUCHUNGS_ID      as CANCELLATION_TRANSACTION_ID,
    IS_BAD_DEBT_LOSS        as IS_BAD_DEBT_LOSS, -- handelt es sich hierbei um eine Abschreibung? (siehe Blossom #541)
    COMMENT                 as COMMENT,
    Current USER            as CREATED_USER,          -- Letzter Nutzer, der dieses View gebaut hat.
    Current TIMESTAMP       as CREATED_TIMESTAMP      -- Neuester Zeitstempel, wann diese View zuletzt gebaut wurde.
from DATA
)
select * from result --where FACILITY_ID='0009-73-004533008770-10-0000000000'

;
------------------------------------------------------------------------------------------------------------------------

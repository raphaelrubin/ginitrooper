-- View erstellen
-- TODO: Umbenennung der View erfordert auch Umbenennung der Tabellen in CASH_FLOW!!!
drop view CALC.VIEW_FACILITY_PRE_SPOT_STAMMDATEN_AOER;
create or replace view CALC.VIEW_FACILITY_PRE_SPOT_STAMMDATEN_AOER as
with
    LIQ_PAST_DUE_KONTEN_SPOT_PRINCIPAL_KORREKTUR_PRE as (
        select
            CASH_FLOW_PAST.CUTOFFDATE,CASH_FLOW_PAST.SAP_ID,CASH_FLOW_PAST.TRANSAKTION_WHRG_SCHL,TRANSAKTION_WERT_WHRG,
            ROW_NUMBER() over (PARTITION BY SAP_ID,CASH_FLOW_PAST.CUTOFFDATE,BUCHUNG_DATUM,TRANSAKTION_WERT_WHRG order by case when UMSATZ_ART_GEVO_1 = 'DARL_TILGUNG_A_W' then 'DARL_STORNO_TILGUNG_A' else UMSATZ_ART_GEVO_1 end) as NBR
        from NLB.SPOT_UMSATZ_CURRENT as CASH_FLOW_PAST
        where 1=1
            and SYSTEM_ID_BUCHUNG = 'LOANIQ'
            and BUCHUNG_DATUM = CASH_FLOW_PAST.CUTOFFDATE - case when dayofweek(CASH_FLOW_PAST.CUTOFFDATE)=1 Then 2 when dayofweek(CASH_FLOW_PAST.CUTOFFDATE)=7 then 1 else 0 end days
            and UMSATZ_ART_GEVO_1 in ('DARL_AUFBAU_RS_TILGUNG_A','DARL_TILGUNG_A','DARL_TILGUNG_A_W')
            and Month(VALUTA_DATUM)=MONTH(BUCHUNG_DATUM) and YEAR(VALUTA_DATUM)=YEAR(BUCHUNG_DATUM)
        order by SAP_ID,CUTOFFDATE,BUCHUNG_DATUM
    ),
    LIQ_PAST_DUE_KONTEN_SPOT_PRINCIPAL_KORREKTUR as (
        select distinct
            replace(SAP_ID,'-30-','-31-') as SAP_ID,
            TRANSAKTION_WHRG_SCHL,
            TRANSAKTION_WERT_WHRG,
            CUTOFFDATE
        from LIQ_PAST_DUE_KONTEN_SPOT_PRINCIPAL_KORREKTUR_PRE
        where NBR = 2
    ),
    ANL_CF_BASIS  as (
        select *,row_number() over (PARTITION BY FACILITYID, CUTOFFDATE order by VALUTA_DATUM desc) as NBR
        from ANL.DARLEHEN_CASH_FLOW_CURRENT
        where ZAHLUNGSSTROM_TYP = 'TILGUNGSRATE'
    ),
    ANL_IRF_S1 as (
        select
            A.FACILITYID,
            A.CUTOFFDATE,
            TIMESTAMPDIFF(16,TIMESTAMP(B.VALUTA_DATUM)-TIMESTAMP(A.VALUTA_DATUM)) as AMO_Rate_FREQUENCY_DAYS
        from ANL_CF_BASIS as A
        left join ANL_CF_BASIS as B on A.CUTOFFDATE =B.CUTOFFDATE and A.FACILITYID=B.FACILITYID and A.NBR = B.NBR+1
        where TIMESTAMPDIFF(16,TIMESTAMP(B.VALUTA_DATUM)-TIMESTAMP(A.VALUTA_DATUM)) is not null
    ),
    ANL_IRF_S2 as (
        select
            FACILITYID,
            CUTOFFDATE,
            case
                when AMO_Rate_FREQUENCY_DAYS between 20 and 36 then 30
                when AMO_Rate_FREQUENCY_DAYS between 50 and 65 then 60
                when AMO_Rate_FREQUENCY_DAYS between 70 and 99 then 90
                when AMO_Rate_FREQUENCY_DAYS between 110 and 125 then 120
                when AMO_Rate_FREQUENCY_DAYS between 170 and 185 then 180
                when AMO_Rate_FREQUENCY_DAYS between 350 and 365 then 360
                else AMO_Rate_FREQUENCY_DAYS
            end as AMO_Rate_FREQUENCY_DAYS
        from ANL_IRF_S1
    ),
    ANL_IRF_S3 as (
        select distinct
        *,
        row_number() over (partition by FACILITYID,CUTOFFDATE order by count(FACILITYID) over (partition by FACILITYID,CUTOFFDATE,AMO_Rate_FREQUENCY_DAYS) desc) as REL_DATSET
        from ANL_IRF_S2
    ),
    ANL_IRF_S4 as (
        select FACILITYID,CUTOFFDATE,AMO_Rate_FREQUENCY_DAYS from ANL_IRF_S3 where REL_DATSET = 1
    ),
     SPOT_STAMMDATEN_PRE_NLB as (
       select STAMMDATEN.facility_id, client_id, account_currency
            , loanstate, loantype, mittelgeber1, mittelgeber2, interestfrequency, amortization_type, amortization_rate, amortization_frequency, maturityinformation, maturitydate, isacceptedbycentralbank, syndicationrole, ownsyndicatequota, originationdate, originalmaturitydate, currentcontractualmaturitydate, nextprincipalpaymentdate, nextinterestpaymentdate, interestratetype, interestrate, fixedinterestrate, fixedinterestrateenddate, interestrateindex, interestratemargin, interestratecap, interestratefloor, amortizationamount_eur, iscreditline, issuance_date, unpaidamortization_eur, amortizationinarrears_eur, unpaidinterest_eur, interestinarrears_eur, unpaidzerointerest_eur, zerointerestinarrears_eur, unpaidfees_eur, feesinarrears_eur, unpaidothercosts_eur, othercostsinarrears_eur
            , case when CUTOFFDATE < '31.05.2020' and substr(STAMMDATEN.FACILITY_ID,6,2) = '49' then  principaloutstanding_eur/KURS else principaloutstanding_eur end as principaloutstanding_eur
            , overpayment_eur, contingenciescommissionrate, contingenciescommissionrateenddate, commitmentfeenextpaymentdate, commitmentfeerate, commitmentfeefrequency, commitmentfeerateenddate, ZUSAGE_UNWIDERR_JN, AUSZAHLUNGSPLICHT_EUR, FACILITY_SAP_ID,cutoffdate, STAMMDATEN.timestamp_load, STAMMDATEN.etl_nr, STAMMDATEN.quelle, STAMMDATEN.branch, user as USer
       from NLB.SPOT_STAMMDATEN_CURRENT as STAMMDATEN
        left join IMAP.CURRENCY_MAP                             as PORTFOLIO_CURRENCY_EXCHANGE  on STAMMDATEN.ACCOUNT_CURRENCY= PORTFOLIO_CURRENCY_EXCHANGE.ZIEL_WHRG and PORTFOLIO_CURRENCY_EXCHANGE.CUT_OFF_DATE=STAMMDATEN.CUTOFFDATE
        inner join CALC.SWITCH_PORTFOLIO_CURRENT                as PORTFOLIO                    on PORTFOLIO.FACILITY_ID_NLB=STAMMDATEN.FACILITY_ID and PORTFOLIO.CUT_OFF_DATE = STAMMDATEN.CUTOFFDATE
     ),
    SPOT_STAMMDATEN_NLB as (
        select
            STAMMDATEN.FACILITY_ID, STAMMDATEN.CLIENT_ID, ACCOUNT_CURRENCY,PORTFOLIO_CURRENCY_EXCHANGE.KURS, LOANSTATE, LOANTYPE, MITTELGEBER1, MITTELGEBER2, INTERESTFREQUENCY, AMORTIZATION_TYPE, AMORTIZATION_RATE, AMORTIZATION_FREQUENCY, MATURITYINFORMATION, MATURITYDATE, ISACCEPTEDBYCENTRALBANK, SYNDICATIONROLE as SYNDICATION_ROLE
            ,case when LOANTYPE = 'GIRO' and OWNSYNDICATEQUOTA = 0 then  100 else OWNSYNDICATEQUOTA end as OWNSYNDICATEQUOTA
            ,ORIGINATIONDATE,ORIGINALMATURITYDATE, CURRENTCONTRACTUALMATURITYDATE, NEXTPRINCIPALPAYMENTDATE, NEXTINTERESTPAYMENTDATE, nullif(INTERESTRATETYPE,'-') as INTERESTRATETYPE, INTERESTRATE, FIXEDINTERESTRATE, FIXEDINTERESTRATEENDDATE, INTERESTRATEINDEX, INTERESTRATEMARGIN, INTERESTRATECAP, INTERESTRATEFLOOR, AMORTIZATIONAMOUNT_EUR
            ,ISCREDITLINE, ISSUANCE_DATE, UNPAIDZEROINTEREST_EUR, ZEROINTERESTINARREARS_EUR, UNPAIDFEES_EUR,
            FEESINARREARS_EUR                                                                                                                                                                                                                                           as FEESINARREARS_EUR,
            FEESINARREARS_EUR        * PORTFOLIO_CURRENCY_EXCHANGE.KURS                                                                                                                                                                                                 as FEESINARREARS_TC,
            UNPAIDOTHERCOSTS_EUR, OTHERCOSTSINARREARS_EUR,
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
            case when (STAMMDATEN.PRINCIPALOUTSTANDING_EUR is null and PRINCIPAL_KORREKTUR.TRANSAKTION_WERT_WHRG is null) then null
                else (coalesce(STAMMDATEN.PRINCIPALOUTSTANDING_EUR,0)* PORTFOLIO_CURRENCY_EXCHANGE.KURS + Coalesce(PRINCIPAL_KORREKTUR.TRANSAKTION_WERT_WHRG,0))/ PORTFOLIO_CURRENCY_EXCHANGE.KURS end                                                                  as PRINCIPALOUTSTANDING_EUR,
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
            case when (STAMMDATEN.PRINCIPALOUTSTANDING_EUR is null and PRINCIPAL_KORREKTUR.TRANSAKTION_WERT_WHRG is null) then null
                else coalesce(STAMMDATEN.PRINCIPALOUTSTANDING_EUR,0)* PORTFOLIO_CURRENCY_EXCHANGE.KURS + Coalesce(TRANSAKTION_WERT_WHRG,0)  end                                                                                                                         as PRINCIPALOUTSTANDING_TC,
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        -- Anpassung, damit für DARKA Konten die brutto Werte ausgegeben werden
            case
                when SUBSTR(STAMMDATEN.FACILITY_ID, 6, 2) in ('30', '31') and OWNSYNDICATEQUOTA <> 0
                    then UNPAIDAMORTIZATION_EUR * 100/OWNSYNDICATEQUOTA
                else UNPAIDAMORTIZATION_EUR end                                       as UNPAIDAMORTIZATION_EUR,
                --Division mit 0 sollte ausgeschlossen sein, da, wenn NordLB Anteil 0% ist, auch das anteilige UNPAIDAMORTIZATION 0 ist. Von 0 kann man nicht auf den vollen Wert schließen. 
            case
                when SUBSTR(STAMMDATEN.FACILITY_ID, 6, 2) in ('30', '31') and OWNSYNDICATEQUOTA <> 0
                    then UNPAIDAMORTIZATION_EUR * 100/OWNSYNDICATEQUOTA * PORTFOLIO_CURRENCY_EXCHANGE.KURS
                else UNPAIDAMORTIZATION_EUR * PORTFOLIO_CURRENCY_EXCHANGE.KURS end    as UNPAIDAMORTIZATION_TC,
            case
                when SUBSTR(STAMMDATEN.FACILITY_ID, 6, 2) in ('30', '31') and OWNSYNDICATEQUOTA <> 0
                    then AMORTIZATIONINARREARS_EUR * 100/OWNSYNDICATEQUOTA
                else AMORTIZATIONINARREARS_EUR end                                    as AMORTIZATIONINARREARS_EUR,
                --Division mit 0 sollte ausgeschlossen sein, da, wenn NordLB Anteil 0% ist, auch das anteilige AMORTIZATIONINARREARS 0 ist. Von 0 kann man nicht auf den vollen Wert schließen.
            case
                when SUBSTR(STAMMDATEN.FACILITY_ID, 6, 2) in ('30', '31') and OWNSYNDICATEQUOTA <> 0
                    then AMORTIZATIONINARREARS_EUR * 100/OWNSYNDICATEQUOTA * PORTFOLIO_CURRENCY_EXCHANGE.KURS
                else AMORTIZATIONINARREARS_EUR * PORTFOLIO_CURRENCY_EXCHANGE.KURS end as AMORTIZATIONINARREARS_TC,
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
            UNPAIDINTEREST_EUR                                                        as UNPAIDINTEREST_EUR,
            UNPAIDINTEREST_EUR * PORTFOLIO_CURRENCY_EXCHANGE.KURS                     as UNPAIDINTEREST_TC,
            INTERESTINARREARS_EUR                                                     as INTEREST_INNARREARS_EUR,
            INTERESTINARREARS_EUR * PORTFOLIO_CURRENCY_EXCHANGE.KURS                  as INTEREST_INNARREARS_TC,
            OVERPAYMENT_EUR, CONTINGENCIESCOMMISSIONRATE, CONTINGENCIESCOMMISSIONRATEENDDATE, COMMITMENTFEENEXTPAYMENTDATE, COMMITMENTFEERATE, COMMITMENTFEEFREQUENCY, COMMITMENTFEERATEENDDATE, ZUSAGE_UNWIDERR_JN, AUSZAHLUNGSPLICHT_EUR, FACILITY_SAP_ID,STAMMDATEN.CUTOFFDATE                                                  as CUT_OFF_DATE
        from SPOT_STAMMDATEN_PRE_NLB                                as STAMMDATEN  -- Korrektur der Principals für Cut_Off_Date < 31.05.2020, da aus dem SPOT in der EUR Spalte TC angeliefert wurde
        inner join CALC.SWITCH_PORTFOLIO_CURRENT                    as PORTFOLIO                    on PORTFOLIO.FACILITY_ID_NLB=STAMMDATEN.FACILITY_ID and PORTFOLIO.CUT_OFF_DATE = STAMMDATEN.CUTOFFDATE
        left join LIQ_PAST_DUE_KONTEN_SPOT_PRINCIPAL_KORREKTUR      as PRINCIPAL_KORREKTUR          on PRINCIPAL_KORREKTUR.CUTOFFDATE=STAMMDATEN.CUTOFFDATE and PRINCIPAL_KORREKTUR.SAP_ID=STAMMDATEN.FACILITY_ID
        left join IMAP.CURRENCY_MAP                                 as PORTFOLIO_CURRENCY_EXCHANGE  on coalesce(STAMMDATEN.ACCOUNT_CURRENCY,PORTFOLIO.CURRENCY)= PORTFOLIO_CURRENCY_EXCHANGE.ZIEL_WHRG and PORTFOLIO_CURRENCY_EXCHANGE.CUT_OFF_DATE=PORTFOLIO.CUT_OFF_DATE
        where PORTFOLIO.FACILITY_ID_NLB is not NULL
    ),
     SPOT_STAMMDATEN_PRE_BLB as (
       select STAMMDATEN.facility_id, client_id, account_currency
            , loanstate, loantype, mittelgeber1, mittelgeber2, interestfrequency, amortization_type, amortization_rate, amortization_frequency, maturityinformation, maturitydate, isacceptedbycentralbank, syndicationrole, ownsyndicatequota, originationdate, originalmaturitydate, currentcontractualmaturitydate, nextprincipalpaymentdate, nextinterestpaymentdate, interestratetype, interestrate, fixedinterestrate, fixedinterestrateenddate, interestrateindex, interestratemargin, interestratecap, interestratefloor, amortizationamount_eur, iscreditline, issuance_date, unpaidamortization_eur, amortizationinarrears_eur, unpaidinterest_eur, interestinarrears_eur, unpaidzerointerest_eur, zerointerestinarrears_eur, unpaidfees_eur, feesinarrears_eur, unpaidothercosts_eur, othercostsinarrears_eur
            , case when CUTOFFDATE < '31.05.2020' and substr(STAMMDATEN.FACILITY_ID,6,2) = '49' then  principaloutstanding_eur/KURS else principaloutstanding_eur end as principaloutstanding_eur
            , overpayment_eur, contingenciescommissionrate, contingenciescommissionrateenddate, commitmentfeenextpaymentdate, commitmentfeerate, commitmentfeefrequency, commitmentfeerateenddate, ZUSAGE_UNWIDERR_JN, AUSZAHLUNGSPLICHT_EUR, FACILITY_SAP_ID,cutoffdate, STAMMDATEN.timestamp_load, STAMMDATEN.etl_nr, STAMMDATEN.quelle, STAMMDATEN.branch, user as USer
       from BLB.SPOT_STAMMDATEN_CURRENT as STAMMDATEN
        left join IMAP.CURRENCY_MAP                             as PORTFOLIO_CURRENCY_EXCHANGE  on STAMMDATEN.ACCOUNT_CURRENCY= PORTFOLIO_CURRENCY_EXCHANGE.ZIEL_WHRG and PORTFOLIO_CURRENCY_EXCHANGE.CUT_OFF_DATE=STAMMDATEN.CUTOFFDATE
        inner join CALC.SWITCH_PORTFOLIO_CURRENT                as PORTFOLIO                    on PORTFOLIO.FACILITY_ID_BLB=STAMMDATEN.FACILITY_ID and PORTFOLIO.CUT_OFF_DATE = STAMMDATEN.CUTOFFDATE
     ),
    SPOT_STAMMDATEN_BLB as (
        select
            STAMMDATEN.FACILITY_ID, STAMMDATEN.CLIENT_ID, ACCOUNT_CURRENCY,PORTFOLIO_CURRENCY_EXCHANGE.KURS, LOANSTATE, LOANTYPE, MITTELGEBER1, MITTELGEBER2, INTERESTFREQUENCY, AMORTIZATION_TYPE, AMORTIZATION_RATE, AMORTIZATION_FREQUENCY, MATURITYINFORMATION, MATURITYDATE, ISACCEPTEDBYCENTRALBANK, SYNDICATIONROLE as SYNDICATION_ROLE
            ,case when LOANTYPE = 'GIRO' and OWNSYNDICATEQUOTA = 0 then  100 else OWNSYNDICATEQUOTA end as OWNSYNDICATEQUOTA
            ,ORIGINATIONDATE,ORIGINALMATURITYDATE, CURRENTCONTRACTUALMATURITYDATE, NEXTPRINCIPALPAYMENTDATE, NEXTINTERESTPAYMENTDATE, nullif(INTERESTRATETYPE,'-') as INTERESTRATETYPE, INTERESTRATE, FIXEDINTERESTRATE, FIXEDINTERESTRATEENDDATE, INTERESTRATEINDEX, INTERESTRATEMARGIN, INTERESTRATECAP, INTERESTRATEFLOOR, AMORTIZATIONAMOUNT_EUR
            , ISCREDITLINE, ISSUANCE_DATE, UNPAIDZEROINTEREST_EUR, ZEROINTERESTINARREARS_EUR, UNPAIDFEES_EUR,
            FEESINARREARS_EUR                                              as FEESINARREARS_EUR,
            FEESINARREARS_EUR        * PORTFOLIO_CURRENCY_EXCHANGE.KURS    as FEESINARREARS_TC,
            UNPAIDOTHERCOSTS_EUR, OTHERCOSTSINARREARS_EUR,
            PRINCIPALOUTSTANDING_EUR                                        as PRINCIPALOUTSTANDING_EUR,
            PRINCIPALOUTSTANDING_EUR  * PORTFOLIO_CURRENCY_EXCHANGE.KURS    as PRINCIPALOUTSTANDING_TC,
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        -- Anpassung, damit für DARKA Konten die brutto Werte ausgegeben werden
            case
                when SUBSTR(STAMMDATEN.FACILITY_ID, 6, 2) in ('30', '31') and OWNSYNDICATEQUOTA <> 0
                    then UNPAIDAMORTIZATION_EUR * 100/OWNSYNDICATEQUOTA
                else UNPAIDAMORTIZATION_EUR end                                       as UNPAIDAMORTIZATION_EUR,
                --Division mit 0 sollte ausgeschlossen sein, da, wenn NordLB Anteil 0% ist, auch das anteilige UNPAIDAMORTIZATION 0 ist. Von 0 kann man nicht auf den vollen Wert schließen. 
            case
                when SUBSTR(STAMMDATEN.FACILITY_ID, 6, 2) in ('30', '31') and OWNSYNDICATEQUOTA <> 0
                    then UNPAIDAMORTIZATION_EUR * 100/OWNSYNDICATEQUOTA * PORTFOLIO_CURRENCY_EXCHANGE.KURS
                else UNPAIDAMORTIZATION_EUR * PORTFOLIO_CURRENCY_EXCHANGE.KURS end    as UNPAIDAMORTIZATION_TC,
            case
                when SUBSTR(STAMMDATEN.FACILITY_ID, 6, 2) in ('30', '31') and OWNSYNDICATEQUOTA <> 0
                    then AMORTIZATIONINARREARS_EUR * 100/OWNSYNDICATEQUOTA
                else AMORTIZATIONINARREARS_EUR end                                    as AMORTIZATIONINARREARS_EUR,
                --Division mit 0 sollte ausgeschlossen sein, da, wenn NordLB Anteil 0% ist, auch das anteilige AMORTIZATIONINARREARS 0 ist. Von 0 kann man nicht auf den vollen Wert schließen.
            case
                when SUBSTR(STAMMDATEN.FACILITY_ID, 6, 2) in ('30', '31') and OWNSYNDICATEQUOTA <> 0
                    then AMORTIZATIONINARREARS_EUR * 100/OWNSYNDICATEQUOTA * PORTFOLIO_CURRENCY_EXCHANGE.KURS
                else AMORTIZATIONINARREARS_EUR * PORTFOLIO_CURRENCY_EXCHANGE.KURS end as AMORTIZATIONINARREARS_TC,
        ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
            UNPAIDINTEREST_EUR                                              as UNPAIDINTEREST_EUR,
            UNPAIDINTEREST_EUR        * PORTFOLIO_CURRENCY_EXCHANGE.KURS    as UNPAIDINTEREST_TC,
            INTERESTINARREARS_EUR                                           as INTEREST_INNARREARS_EUR,
            INTERESTINARREARS_EUR     * PORTFOLIO_CURRENCY_EXCHANGE.KURS    as INTEREST_INNARREARS_TC,
            OVERPAYMENT_EUR, CONTINGENCIESCOMMISSIONRATE, CONTINGENCIESCOMMISSIONRATEENDDATE, COMMITMENTFEENEXTPAYMENTDATE, COMMITMENTFEERATE, COMMITMENTFEEFREQUENCY, COMMITMENTFEERATEENDDATE, ZUSAGE_UNWIDERR_JN, AUSZAHLUNGSPLICHT_EUR, FACILITY_SAP_ID, STAMMDATEN.CUTOFFDATE as CUT_OFF_DATE
        from SPOT_STAMMDATEN_PRE_BLB                as STAMMDATEN -- Korrektur der Principals für Cut_Off_Date < 31.05.2020, da aus dem SPOT in der EUR Spalte TC angeliefert wurde
        inner join CALC.SWITCH_PORTFOLIO_CURRENT    as PORTFOLIO                    on PORTFOLIO.FACILITY_ID_BLB=STAMMDATEN.FACILITY_ID and PORTFOLIO.CUT_OFF_DATE = STAMMDATEN.CUTOFFDATE
        left join IMAP.CURRENCY_MAP                 as PORTFOLIO_CURRENCY_EXCHANGE  on coalesce(STAMMDATEN.ACCOUNT_CURRENCY,PORTFOLIO.CURRENCY)=PORTFOLIO_CURRENCY_EXCHANGE.ZIEL_WHRG and PORTFOLIO_CURRENCY_EXCHANGE.CUT_OFF_DATE=PORTFOLIO.CUT_OFF_DATE
        where PORTFOLIO.FACILITY_ID_BLB is not NULL
    ),
     SPOT_STAMMDATEN_PRE_ANL as (
       select STAMMDATEN.facility_id, client_id, account_currency
            , loanstate, loantype, mittelgeber1, mittelgeber2, interestfrequency, amortization_type, amortization_rate, amortization_frequency, maturityinformation, maturitydate, isacceptedbycentralbank, syndicationrole, ownsyndicatequota, originationdate, originalmaturitydate, currentcontractualmaturitydate, nextprincipalpaymentdate, nextinterestpaymentdate, interestratetype, interestrate, fixedinterestrate, fixedinterestrateenddate, interestrateindex, interestratemargin, interestratecap, interestratefloor, amortizationamount_eur, iscreditline, issuance_date, unpaidamortization_eur, amortizationinarrears_eur, unpaidinterest_eur, interestinarrears_eur, unpaidzerointerest_eur, zerointerestinarrears_eur, unpaidfees_eur, feesinarrears_eur, unpaidothercosts_eur, othercostsinarrears_eur
            , case when CUTOFFDATE < '31.05.2020' and LOANTYPE in ('GIRO','AVAL') then  principaloutstanding_eur/KURS else principaloutstanding_eur end as principaloutstanding_eur
            , overpayment_eur, contingenciescommissionrate, contingenciescommissionrateenddate, commitmentfeenextpaymentdate, commitmentfeerate, commitmentfeefrequency, commitmentfeerateenddate, ZUSAGE_UNWIDERR_JN, AUSZAHLUNGSPLICHT_EUR, FACILITY_SAP_ID, cutoffdate, STAMMDATEN.timestamp_load, STAMMDATEN.etl_nr, STAMMDATEN.quelle, STAMMDATEN.branch, user as USer
       from ANL.SPOT_STAMMDATEN_CURRENT as STAMMDATEN
        left join IMAP.CURRENCY_MAP                             as PORTFOLIO_CURRENCY_EXCHANGE  on STAMMDATEN.ACCOUNT_CURRENCY= PORTFOLIO_CURRENCY_EXCHANGE.ZIEL_WHRG and PORTFOLIO_CURRENCY_EXCHANGE.CUT_OFF_DATE=STAMMDATEN.CUTOFFDATE
        inner join CALC.SWITCH_PORTFOLIO_CURRENT                as PORTFOLIO                    on PORTFOLIO.FACILITY_ID_NLB=STAMMDATEN.FACILITY_ID and PORTFOLIO.CUT_OFF_DATE = STAMMDATEN.CUTOFFDATE
     ),
    SPOT_STAMMDATEN_ANL as (
        select
            STAMMDATEN.FACILITY_ID, STAMMDATEN.CLIENT_ID, ACCOUNT_CURRENCY,PORTFOLIO_CURRENCY_EXCHANGE.KURS, LOANSTATE, LOANTYPE, MITTELGEBER1, MITTELGEBER2, INTERESTFREQUENCY, AMORTIZATION_TYPE, AMORTIZATION_RATE, coalesce(AMORTIZATION_FREQUENCY,AMO_Rate_FREQUENCY_DAYS) as AMORTIZATION_FREQUENCY, MATURITYINFORMATION, MATURITYDATE,
            ISACCEPTEDBYCENTRALBANK, SYNDICATIONROLE as SYNDICATION_ROLE, coalesce(OWNSYNDICATEQUOTA,100) as OWNSYNDICATEQUOTA, ORIGINATIONDATE, ORIGINALMATURITYDATE, CURRENTCONTRACTUALMATURITYDATE, NEXTPRINCIPALPAYMENTDATE, NEXTINTERESTPAYMENTDATE, nullif(INTERESTRATETYPE,'-') as INTERESTRATETYPE, INTERESTRATE, FIXEDINTERESTRATE,
            FIXEDINTERESTRATEENDDATE, INTERESTRATEINDEX, INTERESTRATEMARGIN, INTERESTRATECAP, INTERESTRATEFLOOR, AMORTIZATIONAMOUNT_EUR, ISCREDITLINE, ISSUANCE_DATE, UNPAIDZEROINTEREST_EUR, ZEROINTERESTINARREARS_EUR, UNPAIDFEES_EUR,
            FEESINARREARS_EUR                                              as FEESINARREARS_EUR,
            FEESINARREARS_EUR        * PORTFOLIO_CURRENCY_EXCHANGE.KURS    as FEESINARREARS_TC,
            UNPAIDOTHERCOSTS_EUR, OTHERCOSTSINARREARS_EUR,
            PRINCIPALOUTSTANDING_EUR                                        as PRINCIPALOUTSTANDING_EUR,
            PRINCIPALOUTSTANDING_EUR  * PORTFOLIO_CURRENCY_EXCHANGE.KURS    as PRINCIPALOUTSTANDING_TC,
            ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
            -- Anpassung, damit für DARKA Konten die brutto Werte ausgegeben werden
            case
                when SUBSTR(STAMMDATEN.FACILITY_ID, 6, 2) in ('30', '31') and OWNSYNDICATEQUOTA <> 0
                    then UNPAIDAMORTIZATION_EUR * 100/OWNSYNDICATEQUOTA
                else UNPAIDAMORTIZATION_EUR end                                       as UNPAIDAMORTIZATION_EUR,
                --Division mit 0 sollte ausgeschlossen sein, da, wenn NordLB Anteil 0% ist, auch das anteilige UNPAIDAMORTIZATION 0 ist. Von 0 kann man nicht auf den vollen Wert schließen. 
            case
                when SUBSTR(STAMMDATEN.FACILITY_ID, 6, 2) in ('30', '31') and OWNSYNDICATEQUOTA <> 0
                    then UNPAIDAMORTIZATION_EUR * 100/OWNSYNDICATEQUOTA * PORTFOLIO_CURRENCY_EXCHANGE.KURS
                else UNPAIDAMORTIZATION_EUR * PORTFOLIO_CURRENCY_EXCHANGE.KURS end    as UNPAIDAMORTIZATION_TC,
            case
                when SUBSTR(STAMMDATEN.FACILITY_ID, 6, 2) in ('30', '31') and OWNSYNDICATEQUOTA <> 0
                    then AMORTIZATIONINARREARS_EUR * 100/OWNSYNDICATEQUOTA
                else AMORTIZATIONINARREARS_EUR end                                    as AMORTIZATIONINARREARS_EUR,
                --Division mit 0 sollte ausgeschlossen sein, da, wenn NordLB Anteil 0% ist, auch das anteilige AMORTIZATIONINARREARS 0 ist. Von 0 kann man nicht auf den vollen Wert schließen.
            case
                when SUBSTR(STAMMDATEN.FACILITY_ID, 6, 2) in ('30', '31') and OWNSYNDICATEQUOTA <> 0
                    then AMORTIZATIONINARREARS_EUR * 100/OWNSYNDICATEQUOTA * PORTFOLIO_CURRENCY_EXCHANGE.KURS
                else AMORTIZATIONINARREARS_EUR * PORTFOLIO_CURRENCY_EXCHANGE.KURS end as AMORTIZATIONINARREARS_TC,
            ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
            UNPAIDINTEREST_EUR                                              as UNPAIDINTEREST_EUR,
            UNPAIDINTEREST_EUR        * PORTFOLIO_CURRENCY_EXCHANGE.KURS    as UNPAIDINTEREST_TC,
            INTERESTINARREARS_EUR                                           as INTEREST_INNARREARS_EUR,
            INTERESTINARREARS_EUR     * PORTFOLIO_CURRENCY_EXCHANGE.KURS    as INTEREST_INNARREARS_TC,
            OVERPAYMENT_EUR, CONTINGENCIESCOMMISSIONRATE, CONTINGENCIESCOMMISSIONRATEENDDATE, COMMITMENTFEENEXTPAYMENTDATE, COMMITMENTFEERATE, COMMITMENTFEEFREQUENCY, COMMITMENTFEERATEENDDATE, ZUSAGE_UNWIDERR_JN, AUSZAHLUNGSPLICHT_EUR, FACILITY_SAP_ID, STAMMDATEN.CUTOFFDATE as CUT_OFF_DATE
        from SPOT_STAMMDATEN_PRE_ANL                as STAMMDATEN -- Korrektur der Principals für Cut_Off_Date < 31.05.2020, da aus dem SPOT in der EUR Spalte TC angeliefert wurde
        inner join CALC.SWITCH_PORTFOLIO_CURRENT    as PORTFOLIO                    on PORTFOLIO.FACILITY_ID_NLB=STAMMDATEN.FACILITY_ID and PORTFOLIO.CUT_OFF_DATE = STAMMDATEN.CUTOFFDATE
        left join IMAP.CURRENCY_MAP                 as PORTFOLIO_CURRENCY_EXCHANGE  on coalesce(STAMMDATEN.ACCOUNT_CURRENCY,PORTFOLIO.CURRENCY)=PORTFOLIO_CURRENCY_EXCHANGE.ZIEL_WHRG and PORTFOLIO_CURRENCY_EXCHANGE.CUT_OFF_DATE=PORTFOLIO.CUT_OFF_DATE
        left join ANL_IRF_S4                        as S4                           on S4.CUTOFFDATE=STAMMDATEN.CUTOFFDATE and S4.FACILITYID=STAMMDATEN.FACILITY_ID
        where PORTFOLIO.FACILITY_ID_NLB is not NULL
    ),
    data as (
        select
            A.*
        from (
            select * from SPOT_STAMMDATEN_NLB
                union
            select * from SPOT_STAMMDATEN_BLB
                union
            select * from SPOT_STAMMDATEN_ANL
        ) AS A
    )
select
      *,
    Current_USER        as CREATED_USER,      -- Letzter Nutzer, der diese Tabelle gebaut hat.
    Current_TIMESTAMP   as CREATED_TIMESTAMP  -- Neuester Zeitstempel, wann diese Tabelle zuletzt gebaut wurde.
from data
;

-- CI START FOR ALL TAPES
-- Current-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_FACILITY_PRE_SPOT_STAMMDATEN_AOER_CURRENT');
create table AMC.TABLE_FACILITY_PRE_SPOT_STAMMDATEN_AOER_CURRENT like CALC.VIEW_FACILITY_PRE_SPOT_STAMMDATEN_AOER distribute by hash(FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_PRE_SPOT_STAMMDATEN_AOER_CURRENT_FACILITY_ID on AMC.TABLE_FACILITY_PRE_SPOT_STAMMDATEN_AOER_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_FACILITY_PRE_SPOT_STAMMDATEN_AOER_CURRENT');
-- Archiv-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_FACILITY_PRE_SPOT_STAMMDATEN_AOER_ARCHIVE');
create table AMC.TABLE_FACILITY_PRE_SPOT_STAMMDATEN_AOER_ARCHIVE like AMC.TABLE_FACILITY_PRE_SPOT_STAMMDATEN_AOER_CURRENT distribute by hash(FACILITY_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_PRE_SPOT_STAMMDATEN_AOER_ARCHIVE_FACILITY_ID on AMC.TABLE_FACILITY_PRE_SPOT_STAMMDATEN_AOER_ARCHIVE (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_FACILITY_PRE_SPOT_STAMMDATEN_AOER_ARCHIVE');
-- CI END FOR ALL TAPES

-- SWITCH View erstellen
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_FACILITY_PRE_SPOT_STAMMDATEN_AOER_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_FACILITY_PRE_SPOT_STAMMDATEN_AOER_ARCHIVE');
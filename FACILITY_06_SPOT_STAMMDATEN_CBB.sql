-- View erstellen
drop view  CALC.VIEW_FACILITY_PRE_SPOT_STAMMDATEN_CBB;
create or replace view CALC.VIEW_FACILITY_PRE_SPOT_STAMMDATEN_CBB as
    select distinct
        PORTFOLIO.FACILITY_ID_CBB                                                               as FACILITY_ID_CBB,
        coalesce(LENDING.IDENTITY,SPOT_STAMMDATEN.KKTOAVA+1)                                    as FACILITY_ID,
        coalesce(left(SPOT_STAMMDATEN.KRKUND,10),LENDING.CLIENT_ID)                             as KUNDENNUMMER,
        EFFECTIVE_COVERAMOUNT_EUR,
        ELIGIBILITY_FOR_COVERSTOCK,
        coalesce(LENDING.OWN_SYNDICATE_QUOTA,100)                                               as OWN_SYNDICATE_QUOTA,
        case
                when SPOT_STAMMDATEN.KDKOM is null  then 'Alleinkredit'
                when SPOT_STAMMDATEN.KDKOM = 4      then 'active_participation'
                else  SYNDICATION_ROLE
        end                                                                                     as SYNDICATION_ROLE,
        ELIGIBLE_COVER_AMOUNT_EUR,
        COVERSTOCK_NAME,
        COMMITMENT_FEE_RATE_END_DATE,
        COMMITMENT_FEE_NEXT_PAYMENT_DATE,
        COMMITMENT_FEE_FREQUENCY,
        COMMITMENT_FEE_RATE,
        INTEREST_IN_ARREARS_EUR,
        AMORTIZATION_IN_ARREARS_EUR,
        INTEREST_RATE_INDEX,
        FIXED_INTEREST_RATE,
        FIXED_INTEREST_RATE_END_DATE,
        INTEREST_RATE_FREQUENCY_DAYS,
        coalesce(INTEREST_RATE,keffzs)                                                          as INTEREST_RATE,
        case
            when krzm = 99 then 'FIX'
            when krzm = 0 then 'FIX'
            when KRZM not in (0,99) then 'FLOAT'
            else INTEREST_RATE_TYPE
        end                                                                                     as INTEREST_RATE_TYPE,
        coalesce(INTEREST_RATE_MARGIN,KDMA)                                                     as INTEREST_RATE_MARGIN,
        NEXT_INTEREST_PAYMENT_DATE,
        coalesce(AMORTIZATION_AMOUNT_EUR, KTILRAT / (KRBSAL / nullif(KRWAEB,0)))                as AMORTIZATION_AMOUNT_EUR,
        AMORTIZATION_FREQUENCY_DAYS,
        coalesce(AMORTIZATION_TYPE,
            case
                when KROTI = 3 then 'Bullet'
                when KROTI = 2 and coalesce(KRKOLE,99) = 0 and coalesce(krzl,99) = 0 then 'Installments'
            when KROTI = 2 and coalesce(KRKOLE,99) <> 0 then 'Installments'
            when KROTI = 2 and coalesce(KRKOLE,99) = 0 and coalesce(krzl,99) <> 0 then 'Annuity'
                else NULL
            end) as AMORTIZATION_TYPE,
        coalesce(CURRENT_CONTRACTUAL_MATURITY_DATE,KRENDE)                                      as CURRENT_CONTRACTUAL_MATURITY_DATE,
        coalesce(ORIGINATION_DATE,KROPEN)                                                       as ORIGINATION_DATE,
        coalesce(LENDING.ORIGINAL_CURRENCY,KRISO)                                               as ORIGINAL_CURRENCY,

        case when SSART = '20' then 'Limit' else coalesce(LENDING.PRODUCT_CATEGORY,CAT.PRODUCT_CATEGORY) end            as PRODUCT_CATEGORY,
        coalesce(LENDING.PRODUCT_TYPE,KAT.PRODUCT_DESCRIPTION,left(KRPRODP,4))                          as PRODUCT_TYPE,

        ON_BALANCE_SHEET_LOANS_AND_ADVANCES_TO_BANKS_EUR,
        ON_BALANCE_SHEET_FAIR_VALUE_LOANS_AND_ADVANCES_TO_BANKS_EUR,
        ON_BALANCE_SHEET_FAIR_VALUE_LOANS_AND_ADVANCES_TO_CUSTOMERS_EUR,
        ON_BALANCE_SHEET_LOANS_AND_ADVANCES_TO_CUSTOMERS_EUR,
        ON_BALANCE_SHEET_LLP_STAGE_1_EUR,
        ON_BALANCE_SHEET_LLP_STAGE_2_EUR,
        ON_BALANCE_SHEET_LLP_STAGE_3_EUR,
        case
            when LENDING.ON_BALANCE_SHEET_LOANS_AND_ADVANCES_TO_BANKS_EUR is null
                and LENDING.ON_BALANCE_SHEET_FAIR_VALUE_LOANS_AND_ADVANCES_TO_BANKS_EUR is null
                and LENDING.ON_BALANCE_SHEET_FAIR_VALUE_LOANS_AND_ADVANCES_TO_CUSTOMERS_EUR is null
                and LENDING.ON_BALANCE_SHEET_LOANS_AND_ADVANCES_TO_CUSTOMERS_EUR is null
                and (LENDING.ON_BALANCE_SHEET_LLP_STAGE_1_EUR is null or LENDING.ON_BALANCE_SHEET_LLP_STAGE_2_EUR is null or LENDING.ON_BALANCE_SHEET_LLP_STAGE_3_EUR is null) --In der vorherigen Berechnung wurde das Ergebnis auch null sobald einer dieser Werte Null war -> uebernommen
                then NULL
            else
            coalesce(LENDING.ON_BALANCE_SHEET_LOANS_AND_ADVANCES_TO_BANKS_EUR,0)
              + coalesce(LENDING.ON_BALANCE_SHEET_FAIR_VALUE_LOANS_AND_ADVANCES_TO_BANKS_EUR,0)
              + coalesce(LENDING.ON_BALANCE_SHEET_FAIR_VALUE_LOANS_AND_ADVANCES_TO_CUSTOMERS_EUR,0)
              + coalesce(LENDING.ON_BALANCE_SHEET_LOANS_AND_ADVANCES_TO_CUSTOMERS_EUR,0)
              - LENDING.ON_BALANCE_SHEET_LLP_STAGE_1_EUR
              - LENDING.ON_BALANCE_SHEET_LLP_STAGE_2_EUR
              - LENDING.ON_BALANCE_SHEET_LLP_STAGE_3_EUR
            end                                                                                       as BRUTTO_BUCHWERT_LC,
        nullif(
        case
            when LENDING.BRUTTO_BUCHWERT_TC is not null then
                LENDING.BRUTTO_BUCHWERT_TC
            when LENDING.ON_BALANCE_SHEET_LOANS_AND_ADVANCES_TO_BANKS_EUR is null
             and LENDING.ON_BALANCE_SHEET_FAIR_VALUE_LOANS_AND_ADVANCES_TO_BANKS_EUR is null
             and LENDING.ON_BALANCE_SHEET_FAIR_VALUE_LOANS_AND_ADVANCES_TO_CUSTOMERS_EUR is null
             and LENDING.ON_BALANCE_SHEET_LOANS_AND_ADVANCES_TO_CUSTOMERS_EUR is null
             and (LENDING.ON_BALANCE_SHEET_LLP_STAGE_1_EUR is null or LENDING.ON_BALANCE_SHEET_LLP_STAGE_2_EUR is null or LENDING.ON_BALANCE_SHEET_LLP_STAGE_3_EUR is null) --In der vorherigen Berechnung wurde das Ergebnis auch null sobald einer dieser Werte Null war -> uebernommen
            then
                NULL
            else
                (coalesce(LENDING.ON_BALANCE_SHEET_LOANS_AND_ADVANCES_TO_BANKS_EUR,0)
                  + coalesce(LENDING.ON_BALANCE_SHEET_FAIR_VALUE_LOANS_AND_ADVANCES_TO_BANKS_EUR,0)
                  + coalesce(LENDING.ON_BALANCE_SHEET_FAIR_VALUE_LOANS_AND_ADVANCES_TO_CUSTOMERS_EUR,0)
                  + coalesce(LENDING.ON_BALANCE_SHEET_LOANS_AND_ADVANCES_TO_CUSTOMERS_EUR,0)
                  - LENDING.ON_BALANCE_SHEET_LLP_STAGE_1_EUR
                  - LENDING.ON_BALANCE_SHEET_LLP_STAGE_2_EUR
                  - LENDING.ON_BALANCE_SHEET_LLP_STAGE_3_EUR
                )* LENDING_CURRENCY_EXCHANGE.RATE_EUR_TO_TARGET --eur nach FW => EUR_WERT * Kurs
            end,NULL)                                                                                  as BRUTTO_BUCHWERT_TC,
        coalesce(KRAANTZ,ACCRUED_INTEREST_EUR )                                       as ACCRUED_INTEREST_EUR,
        coalesce(KRAANTZ * Kurs,ACCRUED_INTEREST_EUR * Kurs )                                          as ACCRUED_INTEREST_TC,
        case
            when LENDING.ON_BALANCE_SHEET_LOANS_AND_ADVANCES_TO_BANKS_EUR is null
                and LENDING.ON_BALANCE_SHEET_FAIR_VALUE_LOANS_AND_ADVANCES_TO_BANKS_EUR is null
                and LENDING.ON_BALANCE_SHEET_FAIR_VALUE_LOANS_AND_ADVANCES_TO_CUSTOMERS_EUR is null
                and LENDING.ON_BALANCE_SHEET_LOANS_AND_ADVANCES_TO_CUSTOMERS_EUR is null
                then NULL
            else
            coalesce(LENDING.ON_BALANCE_SHEET_LOANS_AND_ADVANCES_TO_BANKS_EUR,0)
              + coalesce(LENDING.ON_BALANCE_SHEET_FAIR_VALUE_LOANS_AND_ADVANCES_TO_BANKS_EUR,0)
              + coalesce(LENDING.ON_BALANCE_SHEET_FAIR_VALUE_LOANS_AND_ADVANCES_TO_CUSTOMERS_EUR,0)
              + coalesce(LENDING.ON_BALANCE_SHEET_LOANS_AND_ADVANCES_TO_CUSTOMERS_EUR,0)
                end                                                                                     as NETTO_BUCHWERT_LC,
       case
            when LENDING.NETTO_BUCHWERT_TC is not null then  LENDING.NETTO_BUCHWERT_TC
            when LENDING.ON_BALANCE_SHEET_LOANS_AND_ADVANCES_TO_BANKS_EUR is null
                and LENDING.ON_BALANCE_SHEET_FAIR_VALUE_LOANS_AND_ADVANCES_TO_BANKS_EUR is null
                and LENDING.ON_BALANCE_SHEET_FAIR_VALUE_LOANS_AND_ADVANCES_TO_CUSTOMERS_EUR is null
                and LENDING.ON_BALANCE_SHEET_LOANS_AND_ADVANCES_TO_CUSTOMERS_EUR is null
                then NULL
            else
            (coalesce(LENDING.ON_BALANCE_SHEET_LOANS_AND_ADVANCES_TO_BANKS_EUR,0)
              + coalesce(LENDING.ON_BALANCE_SHEET_FAIR_VALUE_LOANS_AND_ADVANCES_TO_BANKS_EUR,0)
              + coalesce(LENDING.ON_BALANCE_SHEET_FAIR_VALUE_LOANS_AND_ADVANCES_TO_CUSTOMERS_EUR,0)
              + coalesce(LENDING.ON_BALANCE_SHEET_LOANS_AND_ADVANCES_TO_CUSTOMERS_EUR,0)
        )* LENDING_CURRENCY_EXCHANGE.KURS
                end                                                                                     as NETTO_BUCHWERT_TC,
        coalesce(
            RIVO_TC
            ,(ON_BALANCE_SHEET_LLP_STAGE_1_EUR
            +ON_BALANCE_SHEET_LLP_STAGE_2_EUR
            +ON_BALANCE_SHEET_LLP_STAGE_3_EUR)*Kurs
        )                                                                                       as RIVO_TC,
        coalesce(
            LENDING.RIVO_TC
            ,(LENDING.ON_BALANCE_SHEET_LLP_STAGE_1_EUR
            +LENDING.ON_BALANCE_SHEET_LLP_STAGE_2_EUR
            +LENDING.ON_BALANCE_SHEET_LLP_STAGE_3_EUR)
        )                                                                                       as RIVO_LC,
        case when SSART = '20' then '0'
             else coalesce(PRINCIPAL_OUTSTANDING_EUR,-1 * KRBSAL) end                           as PRINCIPAL_OUTSTANDING_EUR,
        case when SSART = '20' then '0'
             else coalesce(PRINCIPAL_OST_TC,-1 * KRWAEB)      end                               as PRINCIPAL_OST_TC,
        case when SSART = '20' and right(PORTFOLIO.FACILITY_ID_CBB,4)='4200' then coalesce(PRINCIPAL_OUTSTANDING_EUR,-1 * KRBSAL)
             else NULL end                                                                      as OFFBALANCESHEET_EXPOSURE_EUR,
        case when SSART = '20' and right(PORTFOLIO.FACILITY_ID_CBB,4)='4200' then coalesce(PRINCIPAL_OST_TC,-1 * KRWAEB)
             else  NULL  end                                                                    as OFFBALANCESHEET_EXPOSURE_TC,
        UNPAID_AMORTIZATION_EUR,
        UNPAID_FEES_EUR,
        UNPAID_INTEREST_EUR,
        UNPAID_OTHER_COSTS_EUR,
        AMORTIZATION_IN_ARREAS_TC,
        INTERETST_IN_ARREAS_TC,
        PORTFOLIO.CUT_OFF_DATE,
        Current_USER                                                                            as CREATED_USER,      -- Letzter Nutzer, der diese Tabelle gebaut hat.
        Current_TIMESTAMP                                                                       as CREATED_TIMESTAMP  -- Neuester Zeitstempel, wann diese Tabelle zuletzt gebaut wurde.
    from CALC.SWITCH_PORTFOLIO_CURRENT      as PORTFOLIO
    -- Kommentar zur Verwendung von CBB-Lending mit letzter Lieferung zum 30.09.2019 (Stand 22.12.2020)
    -- Um im Bedarfsfall historische Daten produzieren zu können, bleibt das Mapping mit den Spalten aus CBB-Lending erhalten, auch wenn die aktuellen Informationen aus dem Spot geliefert werden. (Siehe auch Issue #611)
    left join CBB.LENDING_CURRENT           as LENDING                      on PORTFOLIO.CUT_OFF_DATE= LENDING.CUT_OFF_DATE and 'K028-' || LENDING.IDENTITY = left(PORTFOLIO.FACILITY_ID_CBB,12)
    left join CBB.SPOT_STAMMDATEN_CURRENT   as SPOT_STAMMDATEN              on PORTFOLIO.CUT_OFF_DATE = SPOT_STAMMDATEN.CUTOFFDATE and left(PORTFOLIO.FACILITY_ID_CBB,12) = 'K028-'|| (SPOT_STAMMDATEN.KKTOAVA + case when FACILITY_ID_CBB = 'K028-2588653_1020' then 3 else 1 end )
    left join IMAP.CURRENCY_MAP             as LENDING_CURRENCY_EXCHANGE    on LENDING_CURRENCY_EXCHANGE.CUT_OFF_DATE = PORTFOLIO.CUT_OFF_DATE and LENDING_CURRENCY_EXCHANGE.ZIEL_WHRG=coalesce(LENDING.ORIGINAL_CURRENCY,SPOT_STAMMDATEN.KRISO )
    left join IMAP.PRODUKTKATALOG            as KAT                          on KAT.PRODUCT_KEY = SPOT_STAMMDATEN.KRPRODP
    left join SMAP.LENDING_PRODUCT_CATEGORY as CAT                          on CAT.PG_KEY = left(lpad(SPOT_STAMMDATEN.KRPRODP,4,'0'),2)
    where PORTFOLIO.FACILITY_ID_CBB is not NULL
;

-- CI START FOR ALL TAPES
-- Current-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_FACILITY_PRE_SPOT_STAMMDATEN_CBB_CURRENT');
create table AMC.TABLE_FACILITY_PRE_SPOT_STAMMDATEN_CBB_CURRENT like CALC.VIEW_FACILITY_PRE_SPOT_STAMMDATEN_CBB distribute by hash(FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_PRE_SPOT_STAMMDATEN_CBB_CURRENT_FACILITY_ID on AMC.TABLE_FACILITY_PRE_SPOT_STAMMDATEN_CBB_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_FACILITY_PRE_SPOT_STAMMDATEN_CBB_CURRENT');
-- Archiv-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_FACILITY_PRE_SPOT_STAMMDATEN_CBB_ARCHIVE');
create table AMC.TABLE_FACILITY_PRE_SPOT_STAMMDATEN_CBB_ARCHIVE like AMC.TABLE_FACILITY_PRE_SPOT_STAMMDATEN_CBB_CURRENT distribute by hash(FACILITY_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_PRE_SPOT_STAMMDATEN_CBB_ARCHIVE_FACILITY_ID on AMC.TABLE_FACILITY_PRE_SPOT_STAMMDATEN_CBB_ARCHIVE (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_FACILITY_PRE_SPOT_STAMMDATEN_CBB_ARCHIVE');
-- CI END FOR ALL TAPES

-- SWITCH View erstellen
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_FACILITY_PRE_SPOT_STAMMDATEN_CBB_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_FACILITY_PRE_SPOT_STAMMDATEN_CBB_ARCHIVE');
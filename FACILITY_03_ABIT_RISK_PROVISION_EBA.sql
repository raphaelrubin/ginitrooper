-- ABIT Risikovorsorge Daten

-- View erstellen
drop view CALC.VIEW_FACILITY_ABIT_RISK_PROVISION_EBA;
create or replace view CALC.VIEW_FACILITY_ABIT_RISK_PROVISION_EBA as
with
-- Vereinigung der Quelltabellen
ABIT_ALL as (
    select CUT_OFF_DATE,
           KUNDENNUMMER,
           'NLB_' || KUNDENNUMMER as CLIENT_ID,
           case
               when SUBSTR(IDEXTERN, 6, 2) = '13' and SUBSTR(IDEXTERN, 22, 2) = '10'
                   then LEFT(IDEXTERN, 20) || '-20-' || SUBSTR(IDEXTERN, 25, 10)
               else IDEXTERN end  as IDEXTERN,
           WAEHRUNG,
           KENNZHK,
           BESTANDEWB,
           DATUMERSTEEWB,
           NIEDERLASSUNG,
           QUELLE,
           BRANCH,
           IFRSMETHODE,
           IFRSMETHODEVJ,
           EWBVORJAHR,
           EWBVORMONAT,
           EWBVORQUARTAL,
           EWBZUFUEHRUNGYTDGESAMT,
           EWBZUFUEHRUNGYTDSALDO,
           EWBZUFUEHRUNGYTDSONST,
           EWBZUFUEHRUNGMTMGESAMT,
           EWBZUFUEHRUNGMTMSALDO,
           EWBZUFUEHRUNGMTMSONST,
           EWBAUFLOESUNGYTDGESAMT,
           EWBAUFLOESUNGYTDSALDO,
           EWBAUFLOESUNGYTDSONST,
           EWBAUFLOESUNGMTMGESAMT,
           EWBAUFLOESUNGMTMSALDO,
           EWBAUFLOESUNGMTMSONST,
           EWBAUSBUCHUNGYTD,
           EWBAUSBUCHUNGMTM,
           UNWINDINGYTD,
           UNWINDINGMTM,
           MANUELLEWB,
           ABSCHREIBVOLLGUVYTD,
           ABSCHREIBVOLLGUVMTM,
           ABSCHREIBTEILGUVYTD,
           ABSCHREIBTEILGUVMTM,
           ABSCHREIBDATUMVOLL,
           ABSCHREIBDATUMTEIL,
           POCIKONTO,
           POCINOMINALBETRURSPR,
           POCINOMINALBETRADJ,
           POCINEUBILDUNG,
           POCIAUFLOESUNG,
           POCIVERBRAUCH
    from NLB.ABIT_RIVO_CURRENT
    union all
    select CUT_OFF_DATE,
           KUNDENNUMMER,
           'ANL_' || KUNDENNUMMER as CLIENT_ID,
           IDEXTERN,
           WAEHRUNG,
           KENNZHK,
           BESTANDEWB,
           DATUMERSTEEWB,
           NIEDERLASSUNG,
           QUELLE,
           BRANCH,
           IFRSMETHODE,
           IFRSMETHODEVJ,
           EWBVORJAHR,
           EWBVORMONAT,
           EWBVORQUARTAL,
           EWBZUFUEHRUNGYTDGESAMT,
           EWBZUFUEHRUNGYTDSALDO,
           EWBZUFUEHRUNGYTDSONST,
           EWBZUFUEHRUNGMTMGESAMT,
           EWBZUFUEHRUNGMTMSALDO,
           EWBZUFUEHRUNGMTMSONST,
           EWBAUFLOESUNGYTDGESAMT,
           EWBAUFLOESUNGYTDSALDO,
           EWBAUFLOESUNGYTDSONST,
           EWBAUFLOESUNGMTMGESAMT,
           EWBAUFLOESUNGMTMSALDO,
           EWBAUFLOESUNGMTMSONST,
           EWBAUSBUCHUNGYTD,
           EWBAUSBUCHUNGMTM,
           UNWINDINGYTD,
           UNWINDINGMTM,
           MANUELLEWB,
           ABSCHREIBVOLLGUVYTD,
           ABSCHREIBVOLLGUVMTM,
           ABSCHREIBTEILGUVYTD,
           ABSCHREIBTEILGUVMTM,
           ABSCHREIBDATUMVOLL,
           ABSCHREIBDATUMTEIL,
           POCIKONTO,
           POCINOMINALBETRURSPR,
           POCINOMINALBETRADJ,
           POCINEUBILDUNG,
           POCIAUFLOESUNG,
           POCIVERBRAUCH
    from ANL.ABIT_RIVO_CURRENT
),
ABIT_RIVO as (
    select ABIT.CUT_OFF_DATE,
           ABIT.CLIENT_ID,
           ABIT.IDEXTERN                                             as FACILITY_ID,
           ABIT.WAEHRUNG                                             as CURRENCY_OC,
           case
               when ABIT.WAEHRUNG is not null
                   then 'EUR'
               end                                                   as CURRENCY,
           EXCHANGE.RATE_EUR_TO_TARGET                               as EXCHANGE_RATE_EUR2OC,
           ABIT.KENNZHK,
           ABIT.BESTANDEWB                                           as AMOUNT_OC,
           ABIT.BESTANDEWB * EXCHANGE.RATE_TARGET_TO_EUR             as AMOUNT_EUR,
           ABIT.DATUMERSTEEWB                                        as DATE_CREATED,
           ABIT.BRANCH,
           ABIT.QUELLE                                               as SOURCE,
           -- Neu hinzugefügt seit EBA
           ABIT.IFRSMETHODE                                          as IFRSMETHOD,
           ABIT.IFRSMETHODEVJ                                        as IFRSMETHOD_PREV_YEAR,
           ABIT.EWBVORJAHR                                           as AMOUNT_PREV_YEAR_OC,
           ABIT.EWBVORJAHR * EXCHANGE.RATE_TARGET_TO_EUR             as AMOUNT_PREV_YEAR_EUR,
           ABIT.EWBVORMONAT                                          as AMOUNT_PREV_MONTH_OC,
           ABIT.EWBVORMONAT * EXCHANGE.RATE_TARGET_TO_EUR            as AMOUNT_PREV_MONTH_EUR,
           ABIT.EWBVORQUARTAL                                        as AMOUNT_PREV_QUARTER_OC,
           ABIT.EWBVORQUARTAL * EXCHANGE.RATE_TARGET_TO_EUR          as AMOUNT_PREV_QUARTER_EUR,
           ABIT.EWBZUFUEHRUNGYTDGESAMT                               as SUPPLY_FULL_YTD_OC,
           ABIT.EWBZUFUEHRUNGYTDGESAMT * EXCHANGE.RATE_TARGET_TO_EUR as SUPPLY_FULL_YTD_EUR,
           ABIT.EWBZUFUEHRUNGYTDSALDO                                as SUPPLY_BAL_YTD_OC,
           ABIT.EWBZUFUEHRUNGYTDSALDO * EXCHANGE.RATE_TARGET_TO_EUR  as SUPPLY_BAL_YTD_EUR,
           ABIT.EWBZUFUEHRUNGYTDSONST                                as SUPPLY_ELSE_YTD_OC,
           ABIT.EWBZUFUEHRUNGYTDSONST * EXCHANGE.RATE_TARGET_TO_EUR  as SUPPLY_ELSE_YTD_EUR,
           ABIT.EWBZUFUEHRUNGMTMGESAMT                               as SUPPLY_FULL_MTM_OC,
           ABIT.EWBZUFUEHRUNGMTMGESAMT * EXCHANGE.RATE_TARGET_TO_EUR as SUPPLY_FULL_MTM_EUR,
           ABIT.EWBZUFUEHRUNGMTMSALDO                                as SUPPLY_BAL_MTM_OC,
           ABIT.EWBZUFUEHRUNGMTMSALDO * EXCHANGE.RATE_TARGET_TO_EUR  as SUPPLY_BAL_MTM_EUR,
           ABIT.EWBZUFUEHRUNGMTMSONST                                as SUPPLY_ELSE_MTM_OC,
           ABIT.EWBZUFUEHRUNGMTMSONST * EXCHANGE.RATE_TARGET_TO_EUR  as SUPPLY_ELSE_MTM_EUR,
           ABIT.EWBAUFLOESUNGYTDGESAMT                               as LIQUIDATION_FULL_YTD_OC,
           ABIT.EWBAUFLOESUNGYTDGESAMT * EXCHANGE.RATE_TARGET_TO_EUR as LIQUIDATION_FULL_YTD_EUR,
           ABIT.EWBAUFLOESUNGYTDSALDO                                as LIQUIDATION_BAL_YTD_OC,
           ABIT.EWBAUFLOESUNGYTDSALDO * EXCHANGE.RATE_TARGET_TO_EUR  as LIQUIDATION_BAL_YTD_EUR,
           ABIT.EWBAUFLOESUNGYTDSONST                                as LIQUIDATION_ELSE_YTD_OC,
           ABIT.EWBAUFLOESUNGYTDSONST * EXCHANGE.RATE_TARGET_TO_EUR  as LIQUIDATION_ELSE_YTD_EUR,
           ABIT.EWBAUFLOESUNGMTMGESAMT                               as LIQUIDATION_FULL_MTM_OC,
           ABIT.EWBAUFLOESUNGMTMGESAMT * EXCHANGE.RATE_TARGET_TO_EUR as LIQUIDATION_FULL_MTM_EUR,
           ABIT.EWBAUFLOESUNGMTMSALDO                                as LIQUIDATION_BAL_MTM_OC,
           ABIT.EWBAUFLOESUNGMTMSALDO * EXCHANGE.RATE_TARGET_TO_EUR  as LIQUIDATION_BAL_MTM_EUR,
           ABIT.EWBAUFLOESUNGMTMSONST                                as LIQUIDATION_ELSE_MTM_OC,
           ABIT.EWBAUFLOESUNGMTMSONST * EXCHANGE.RATE_TARGET_TO_EUR  as LIQUIDATION_ELSE_MTM_EUR,
           ABIT.EWBAUSBUCHUNGYTD                                     as DEBIT_YTD_OC,
           ABIT.EWBAUSBUCHUNGYTD * EXCHANGE.RATE_TARGET_TO_EUR       as DEBIT_YTD_EUR,
           ABIT.EWBAUSBUCHUNGMTM                                     as DEBIT_MTM_OC,
           ABIT.EWBAUSBUCHUNGMTM * EXCHANGE.RATE_TARGET_TO_EUR       as DEBIT_MTM_EUR,
           ABIT.UNWINDINGYTD                                         as UNWINDING_YTD_OC,
           ABIT.UNWINDINGYTD * EXCHANGE.RATE_TARGET_TO_EUR           as UNWINDING_YTD_EUR,
           ABIT.UNWINDINGMTM                                         as UNWINDING_MTM_OC,
           ABIT.UNWINDINGMTM * EXCHANGE.RATE_TARGET_TO_EUR           as UNWINDING_MTM_EUR,
           ABIT.MANUELLEWB                                           as MANUAL_AMOUNT_OC,
           ABIT.MANUELLEWB * EXCHANGE.RATE_TARGET_TO_EUR             as MANUAL_AMOUNT_EUR,
           ABIT.ABSCHREIBVOLLGUVYTD                                  as WRITE_OFF_FULL_GUV_YTD_OC,
           ABIT.ABSCHREIBVOLLGUVYTD * EXCHANGE.RATE_TARGET_TO_EUR    as WRITE_OFF_FULL_GUV_YTD_EUR,
           ABIT.ABSCHREIBVOLLGUVMTM                                  as WRITE_OFF_FULL_GUV_MTM_OC,
           ABIT.ABSCHREIBVOLLGUVMTM * EXCHANGE.RATE_TARGET_TO_EUR    as WRITE_OFF_FULL_GUV_MTM_EUR,
           ABIT.ABSCHREIBTEILGUVYTD                                  as WRITE_OFF_PART_GUV_YTD_OC,
           ABIT.ABSCHREIBTEILGUVYTD * EXCHANGE.RATE_TARGET_TO_EUR    as WRITE_OFF_PART_GUV_YTD_EUR,
           ABIT.ABSCHREIBTEILGUVMTM                                  as WRITE_OFF_PART_GUV_MTM_OC,
           ABIT.ABSCHREIBTEILGUVMTM * EXCHANGE.RATE_TARGET_TO_EUR    as WRITE_OFF_PART_GUV_MTM_EUR,
           ABIT.ABSCHREIBDATUMVOLL                                   as WRITE_OFF_FULL_DATE,
           ABIT.ABSCHREIBDATUMTEIL                                   as WRITE_OFF_PART_DATE,
           ABIT.POCIKONTO                                            as POCI_ACCOUNT,
           ABIT.POCINOMINALBETRURSPR                                 as POCI_NOMINAL_AMOUNT_ORIG_OC,
           ABIT.POCINOMINALBETRURSPR * EXCHANGE.RATE_TARGET_TO_EUR   as POCI_NOMINAL_AMOUNT_ORIG_EUR,
           ABIT.POCINOMINALBETRADJ                                   as POCI_NOMINAL_AMOUNT_ADJ_OC,
           ABIT.POCINOMINALBETRADJ * EXCHANGE.RATE_TARGET_TO_EUR     as POCI_NOMINAL_AMOUNT_ADJ_EUR,
           ABIT.POCINEUBILDUNG                                       as POCI_REGEN_OC,
           ABIT.POCINEUBILDUNG * EXCHANGE.RATE_TARGET_TO_EUR         as POCI_REGEN_EUR,
           ABIT.POCIAUFLOESUNG                                       as POCI_LIQUIDATION_OC,
           ABIT.POCIAUFLOESUNG * EXCHANGE.RATE_TARGET_TO_EUR         as POCI_LIQUIDATION_EUR,
           ABIT.POCIVERBRAUCH                                        as POCI_CONSUMPTION_OC,
           ABIT.POCIVERBRAUCH * EXCHANGE.RATE_TARGET_TO_EUR          as POCI_CONSUMPTION_EUR
    from ABIT_ALL as ABIT
             left join IMAP.CURRENCY_MAP as EXCHANGE
                       on (ABIT.WAEHRUNG, ABIT.CUT_OFF_DATE) = (EXCHANGE.ZIEL_WHRG, EXCHANGE.CUT_OFF_DATE)
),
-- Einzelwertberichtigung / Bilanziell (onbalance)
ABIT_ON as (
    select CUT_OFF_DATE,
           CLIENT_ID,
           FACILITY_ID,
           AMOUNT_OC                    as AMOUNT_OC_ONBALANCE,
           AMOUNT_EUR                   as AMOUNT_EUR_ONBALANCE,
           DATE_CREATED                 as DATE_CREATED_ONBALANCE,
           AMOUNT_PREV_YEAR_OC          as AMOUNT_PREV_YEAR_OC_ONBALANCE,
           AMOUNT_PREV_YEAR_EUR         as AMOUNT_PREV_YEAR_EUR_ONBALANCE,
           AMOUNT_PREV_MONTH_OC         as AMOUNT_PREV_MONTH_OC_ONBALANCE,
           AMOUNT_PREV_MONTH_EUR        as AMOUNT_PREV_MONTH_EUR_ONBALANCE,
           AMOUNT_PREV_QUARTER_OC       as AMOUNT_PREV_QUARTER_OC_ONBALANCE,
           SUPPLY_FULL_YTD_OC           as SUPPLY_FULL_YTD_OC_ONBALANCE,
           SUPPLY_FULL_YTD_EUR          as SUPPLY_FULL_YTD_EUR_ONBALANCE,
           SUPPLY_BAL_YTD_OC            as SUPPLY_BAL_YTD_OC_ONBALANCE,
           SUPPLY_BAL_YTD_EUR           as SUPPLY_BAL_YTD_EUR_ONBALANCE,
           SUPPLY_ELSE_YTD_OC           as SUPPLY_ELSE_YTD_OC_ONBALANCE,
           SUPPLY_ELSE_YTD_EUR          as SUPPLY_ELSE_YTD_EUR_ONBALANCE,
           SUPPLY_FULL_MTM_OC           as SUPPLY_FULL_MTM_OC_ONBALANCE,
           SUPPLY_FULL_MTM_EUR          as SUPPLY_FULL_MTM_EUR_ONBALANCE,
           SUPPLY_BAL_MTM_OC            as SUPPLY_BAL_MTM_OC_ONBALANCE,
           SUPPLY_BAL_MTM_EUR           as SUPPLY_BAL_MTM_EUR_ONBALANCE,
           SUPPLY_ELSE_MTM_OC           as SUPPLY_ELSE_MTM_OC_ONBALANCE,
           SUPPLY_ELSE_MTM_EUR          as SUPPLY_ELSE_MTM_EUR_ONBALANCE,
           LIQUIDATION_FULL_YTD_OC      as LIQUIDATION_FULL_YTD_OC_ONBALANCE,
           LIQUIDATION_FULL_YTD_EUR     as LIQUIDATION_FULL_YTD_EUR_ONBALANCE,
           LIQUIDATION_BAL_YTD_OC       as LIQUIDATION_BAL_YTD_OC_ONBALANCE,
           LIQUIDATION_BAL_YTD_EUR      as LIQUIDATION_BAL_YTD_EUR_ONBALANCE,
           LIQUIDATION_ELSE_YTD_OC      as LIQUIDATION_ELSE_YTD_OC_ONBALANCE,
           LIQUIDATION_ELSE_YTD_EUR     as LIQUIDATION_ELSE_YTD_EUR_ONBALANCE,
           LIQUIDATION_FULL_MTM_OC      as LIQUIDATION_FULL_MTM_OC_ONBALANCE,
           LIQUIDATION_FULL_MTM_EUR     as LIQUIDATION_FULL_MTM_EUR_ONBALANCE,
           LIQUIDATION_BAL_MTM_OC       as LIQUIDATION_BAL_MTM_OC_ONBALANCE,
           LIQUIDATION_BAL_MTM_EUR      as LIQUIDATION_BAL_MTM_EUR_ONBALANCE,
           LIQUIDATION_ELSE_MTM_OC      as LIQUIDATION_ELSE_MTM_OC_ONBALANCE,
           LIQUIDATION_ELSE_MTM_EUR     as LIQUIDATION_ELSE_MTM_EUR_ONBALANCE,
           DEBIT_YTD_OC                 as DEBIT_YTD_OC_ONBALANCE,
           DEBIT_YTD_EUR                as DEBIT_YTD_EUR_ONBALANCE,
           DEBIT_MTM_OC                 as DEBIT_MTM_OC_ONBALANCE,
           DEBIT_MTM_EUR                as DEBIT_MTM_EUR_ONBALANCE,
           UNWINDING_YTD_OC             as UNWINDING_YTD_OC_ONBALANCE,
           UNWINDING_YTD_EUR            as UNWINDING_YTD_EUR_ONBALANCE,
           UNWINDING_MTM_OC             as UNWINDING_MTM_OC_ONBALANCE,
           UNWINDING_MTM_EUR            as UNWINDING_MTM_EUR_ONBALANCE,
           MANUAL_AMOUNT_OC             as MANUAL_AMOUNT_OC_ONBALANCE,
           MANUAL_AMOUNT_EUR            as MANUAL_AMOUNT_EUR_ONBALANCE,
           WRITE_OFF_FULL_GUV_YTD_OC    as WRITE_OFF_FULL_GUV_YTD_OC_ONBALANCE,
           WRITE_OFF_FULL_GUV_YTD_EUR   as WRITE_OFF_FULL_GUV_YTD_EUR_ONBALANCE,
           WRITE_OFF_FULL_GUV_MTM_OC    as WRITE_OFF_FULL_GUV_MTM_OC_ONBALANCE,
           WRITE_OFF_FULL_GUV_MTM_EUR   as WRITE_OFF_FULL_GUV_MTM_EUR_ONBALANCE,
           WRITE_OFF_PART_GUV_YTD_OC    as WRITE_OFF_PART_GUV_YTD_OC_ONBALANCE,
           WRITE_OFF_PART_GUV_YTD_EUR   as WRITE_OFF_PART_GUV_YTD_EUR_ONBALANCE,
           WRITE_OFF_PART_GUV_MTM_OC    as WRITE_OFF_PART_GUV_MTM_OC_ONBALANCE,
           WRITE_OFF_PART_GUV_MTM_EUR   as WRITE_OFF_PART_GUV_MTM_EUR_ONBALANCE,
           WRITE_OFF_FULL_DATE          as WRITE_OFF_FULL_DATE_ONBALANCE,
           WRITE_OFF_PART_DATE          as WRITE_OFF_PART_DATE_ONBALANCE,
           POCI_NOMINAL_AMOUNT_ORIG_OC  as POCI_NOMINAL_AMOUNT_ORIG_OC_ONBALANCE,
           POCI_NOMINAL_AMOUNT_ORIG_EUR as POCI_NOMINAL_AMOUNT_ORIG_EUR_ONBALANCE,
           POCI_NOMINAL_AMOUNT_ADJ_OC   as POCI_NOMINAL_AMOUNT_ADJ_OC_ONBALANCE,
           POCI_NOMINAL_AMOUNT_ADJ_EUR  as POCI_NOMINAL_AMOUNT_ADJ_EUR_ONBALANCE,
           POCI_REGEN_OC                as POCI_REGEN_OC_ONBALANCE,
           POCI_REGEN_EUR               as POCI_REGEN_EUR_ONBALANCE,
           POCI_LIQUIDATION_OC          as POCI_LIQUIDATION_OC_ONBALANCE,
           POCI_LIQUIDATION_EUR         as POCI_LIQUIDATION_EUR_ONBALANCE,
           POCI_CONSUMPTION_OC          as POCI_CONSUMPTION_OC_ONBALANCE,
           POCI_CONSUMPTION_EUR         as POCI_CONSUMPTION_EUR_ONBALANCE
    from ABIT_RIVO
    where KENNZHK = 'E'
),
-- Rückstellung/ Außerbilanziell (offbalance)
ABIT_OFF as (
    select CUT_OFF_DATE,
           CLIENT_ID,
           FACILITY_ID,
           AMOUNT_OC                    as AMOUNT_OC_OFFBALANCE,
           AMOUNT_EUR                   as AMOUNT_EUR_OFFBALANCE,
           DATE_CREATED                 as DATE_CREATED_OFFBALANCE,
           AMOUNT_PREV_YEAR_OC          as AMOUNT_PREV_YEAR_OC_OFFBALANCE,
           AMOUNT_PREV_YEAR_EUR         as AMOUNT_PREV_YEAR_EUR_OFFBALANCE,
           AMOUNT_PREV_MONTH_OC         as AMOUNT_PREV_MONTH_OC_OFFBALANCE,
           AMOUNT_PREV_MONTH_EUR        as AMOUNT_PREV_MONTH_EUR_OFFBALANCE,
           AMOUNT_PREV_QUARTER_OC       as AMOUNT_PREV_QUARTER_OC_OFFBALANCE,
           SUPPLY_FULL_YTD_OC           as SUPPLY_FULL_YTD_OC_OFFBALANCE,
           SUPPLY_FULL_YTD_EUR          as SUPPLY_FULL_YTD_EUR_OFFBALANCE,
           SUPPLY_BAL_YTD_OC            as SUPPLY_BAL_YTD_OC_OFFBALANCE,
           SUPPLY_BAL_YTD_EUR           as SUPPLY_BAL_YTD_EUR_OFFBALANCE,
           SUPPLY_ELSE_YTD_OC           as SUPPLY_ELSE_YTD_OC_OFFBALANCE,
           SUPPLY_ELSE_YTD_EUR          as SUPPLY_ELSE_YTD_EUR_OFFBALANCE,
           SUPPLY_FULL_MTM_OC           as SUPPLY_FULL_MTM_OC_OFFBALANCE,
           SUPPLY_FULL_MTM_EUR          as SUPPLY_FULL_MTM_EUR_OFFBALANCE,
           SUPPLY_BAL_MTM_OC            as SUPPLY_BAL_MTM_OC_OFFBALANCE,
           SUPPLY_BAL_MTM_EUR           as SUPPLY_BAL_MTM_EUR_OFFBALANCE,
           SUPPLY_ELSE_MTM_OC           as SUPPLY_ELSE_MTM_OC_OFFBALANCE,
           SUPPLY_ELSE_MTM_EUR          as SUPPLY_ELSE_MTM_EUR_OFFBALANCE,
           LIQUIDATION_FULL_YTD_OC      as LIQUIDATION_FULL_YTD_OC_OFFBALANCE,
           LIQUIDATION_FULL_YTD_EUR     as LIQUIDATION_FULL_YTD_EUR_OFFBALANCE,
           LIQUIDATION_BAL_YTD_OC       as LIQUIDATION_BAL_YTD_OC_OFFBALANCE,
           LIQUIDATION_BAL_YTD_EUR      as LIQUIDATION_BAL_YTD_EUR_OFFBALANCE,
           LIQUIDATION_ELSE_YTD_OC      as LIQUIDATION_ELSE_YTD_OC_OFFBALANCE,
           LIQUIDATION_ELSE_YTD_EUR     as LIQUIDATION_ELSE_YTD_EUR_OFFBALANCE,
           LIQUIDATION_FULL_MTM_OC      as LIQUIDATION_FULL_MTM_OC_OFFBALANCE,
           LIQUIDATION_FULL_MTM_EUR     as LIQUIDATION_FULL_MTM_EUR_OFFBALANCE,
           LIQUIDATION_BAL_MTM_OC       as LIQUIDATION_BAL_MTM_OC_OFFBALANCE,
           LIQUIDATION_BAL_MTM_EUR      as LIQUIDATION_BAL_MTM_EUR_OFFBALANCE,
           LIQUIDATION_ELSE_MTM_OC      as LIQUIDATION_ELSE_MTM_OC_OFFBALANCE,
           LIQUIDATION_ELSE_MTM_EUR     as LIQUIDATION_ELSE_MTM_EUR_OFFBALANCE,
           DEBIT_YTD_OC                 as DEBIT_YTD_OC_OFFBALANCE,
           DEBIT_YTD_EUR                as DEBIT_YTD_EUR_OFFBALANCE,
           DEBIT_MTM_OC                 as DEBIT_MTM_OC_OFFBALANCE,
           DEBIT_MTM_EUR                as DEBIT_MTM_EUR_OFFBALANCE,
           UNWINDING_YTD_OC             as UNWINDING_YTD_OC_OFFBALANCE,
           UNWINDING_YTD_EUR            as UNWINDING_YTD_EUR_OFFBALANCE,
           UNWINDING_MTM_OC             as UNWINDING_MTM_OC_OFFBALANCE,
           UNWINDING_MTM_EUR            as UNWINDING_MTM_EUR_OFFBALANCE,
           MANUAL_AMOUNT_OC             as MANUAL_AMOUNT_OC_OFFBALANCE,
           MANUAL_AMOUNT_EUR            as MANUAL_AMOUNT_EUR_OFFBALANCE,
           WRITE_OFF_FULL_GUV_YTD_OC    as WRITE_OFF_FULL_GUV_YTD_OC_OFFBALANCE,
           WRITE_OFF_FULL_GUV_YTD_EUR   as WRITE_OFF_FULL_GUV_YTD_EUR_OFFBALANCE,
           WRITE_OFF_FULL_GUV_MTM_OC    as WRITE_OFF_FULL_GUV_MTM_OC_OFFBALANCE,
           WRITE_OFF_FULL_GUV_MTM_EUR   as WRITE_OFF_FULL_GUV_MTM_EUR_OFFBALANCE,
           WRITE_OFF_PART_GUV_YTD_OC    as WRITE_OFF_PART_GUV_YTD_OC_OFFBALANCE,
           WRITE_OFF_PART_GUV_YTD_EUR   as WRITE_OFF_PART_GUV_YTD_EUR_OFFBALANCE,
           WRITE_OFF_PART_GUV_MTM_OC    as WRITE_OFF_PART_GUV_MTM_OC_OFFBALANCE,
           WRITE_OFF_PART_GUV_MTM_EUR   as WRITE_OFF_PART_GUV_MTM_EUR_OFFBALANCE,
           WRITE_OFF_FULL_DATE          as WRITE_OFF_FULL_DATE_OFFBALANCE,
           WRITE_OFF_PART_DATE          as WRITE_OFF_PART_DATE_OFFBALANCE,
           POCI_NOMINAL_AMOUNT_ORIG_OC  as POCI_NOMINAL_AMOUNT_ORIG_OC_OFFBALANCE,
           POCI_NOMINAL_AMOUNT_ORIG_EUR as POCI_NOMINAL_AMOUNT_ORIG_EUR_OFFBALANCE,
           POCI_NOMINAL_AMOUNT_ADJ_OC   as POCI_NOMINAL_AMOUNT_ADJ_OC_OFFBALANCE,
           POCI_NOMINAL_AMOUNT_ADJ_EUR  as POCI_NOMINAL_AMOUNT_ADJ_EUR_OFFBALANCE,
           POCI_REGEN_OC                as POCI_REGEN_OC_OFFBALANCE,
           POCI_REGEN_EUR               as POCI_REGEN_EUR_OFFBALANCE,
           POCI_LIQUIDATION_OC          as POCI_LIQUIDATION_OC_OFFBALANCE,
           POCI_LIQUIDATION_EUR         as POCI_LIQUIDATION_EUR_OFFBALANCE,
           POCI_CONSUMPTION_OC          as POCI_CONSUMPTION_OC_OFFBALANCE,
           POCI_CONSUMPTION_EUR         as POCI_CONSUMPTION_EUR_OFFBALANCE
    from ABIT_RIVO
    where KENNZHK = 'R'
),
-- Alles in eine Zeile
FINAL as (
    select distinct ABIT_RIVO.CUT_OFF_DATE,
                    ABIT_RIVO.CLIENT_ID,
                    ABIT_RIVO.FACILITY_ID,
                    ABIT_RIVO.CURRENCY_OC,
                    ABIT_RIVO.CURRENCY,
                    ABIT_RIVO.EXCHANGE_RATE_EUR2OC,
                    ABIT_RIVO.IFRSMETHOD,
                    ABIT_RIVO.IFRSMETHOD_PREV_YEAR,
                    ABIT_RIVO.POCI_ACCOUNT,
                    -- On
                    ABIT_ON.AMOUNT_EUR_ONBALANCE,
                    ABIT_ON.AMOUNT_OC_ONBALANCE,
                    ABIT_ON.DATE_CREATED_ONBALANCE,
                    ABIT_ON.AMOUNT_PREV_YEAR_OC_ONBALANCE,
                    ABIT_ON.AMOUNT_PREV_YEAR_EUR_ONBALANCE,
                    ABIT_ON.AMOUNT_PREV_MONTH_OC_ONBALANCE,
                    ABIT_ON.AMOUNT_PREV_MONTH_EUR_ONBALANCE,
                    ABIT_ON.AMOUNT_PREV_QUARTER_OC_ONBALANCE,
                    ABIT_ON.SUPPLY_FULL_YTD_OC_ONBALANCE,
                    ABIT_ON.SUPPLY_FULL_YTD_EUR_ONBALANCE,
                    ABIT_ON.SUPPLY_BAL_YTD_OC_ONBALANCE,
                    ABIT_ON.SUPPLY_BAL_YTD_EUR_ONBALANCE,
                    ABIT_ON.SUPPLY_ELSE_YTD_OC_ONBALANCE,
                    ABIT_ON.SUPPLY_ELSE_YTD_EUR_ONBALANCE,
                    ABIT_ON.SUPPLY_FULL_MTM_OC_ONBALANCE,
                    ABIT_ON.SUPPLY_FULL_MTM_EUR_ONBALANCE,
                    ABIT_ON.SUPPLY_BAL_MTM_OC_ONBALANCE,
                    ABIT_ON.SUPPLY_BAL_MTM_EUR_ONBALANCE,
                    ABIT_ON.SUPPLY_ELSE_MTM_OC_ONBALANCE,
                    ABIT_ON.SUPPLY_ELSE_MTM_EUR_ONBALANCE,
                    ABIT_ON.LIQUIDATION_FULL_YTD_OC_ONBALANCE,
                    ABIT_ON.LIQUIDATION_FULL_YTD_EUR_ONBALANCE,
                    ABIT_ON.LIQUIDATION_BAL_YTD_OC_ONBALANCE,
                    ABIT_ON.LIQUIDATION_BAL_YTD_EUR_ONBALANCE,
                    ABIT_ON.LIQUIDATION_ELSE_YTD_OC_ONBALANCE,
                    ABIT_ON.LIQUIDATION_ELSE_YTD_EUR_ONBALANCE,
                    ABIT_ON.LIQUIDATION_FULL_MTM_OC_ONBALANCE,
                    ABIT_ON.LIQUIDATION_FULL_MTM_EUR_ONBALANCE,
                    ABIT_ON.LIQUIDATION_BAL_MTM_OC_ONBALANCE,
                    ABIT_ON.LIQUIDATION_BAL_MTM_EUR_ONBALANCE,
                    ABIT_ON.LIQUIDATION_ELSE_MTM_OC_ONBALANCE,
                    ABIT_ON.LIQUIDATION_ELSE_MTM_EUR_ONBALANCE,
                    ABIT_ON.DEBIT_YTD_OC_ONBALANCE,
                    ABIT_ON.DEBIT_YTD_EUR_ONBALANCE,
                    ABIT_ON.DEBIT_MTM_OC_ONBALANCE,
                    ABIT_ON.DEBIT_MTM_EUR_ONBALANCE,
                    ABIT_ON.UNWINDING_YTD_OC_ONBALANCE,
                    ABIT_ON.UNWINDING_YTD_EUR_ONBALANCE,
                    ABIT_ON.UNWINDING_MTM_OC_ONBALANCE,
                    ABIT_ON.UNWINDING_MTM_EUR_ONBALANCE,
                    ABIT_ON.MANUAL_AMOUNT_OC_ONBALANCE,
                    ABIT_ON.MANUAL_AMOUNT_EUR_ONBALANCE,
                    ABIT_ON.WRITE_OFF_FULL_GUV_YTD_OC_ONBALANCE,
                    ABIT_ON.WRITE_OFF_FULL_GUV_YTD_EUR_ONBALANCE,
                    ABIT_ON.WRITE_OFF_FULL_GUV_MTM_OC_ONBALANCE,
                    ABIT_ON.WRITE_OFF_FULL_GUV_MTM_EUR_ONBALANCE,
                    ABIT_ON.WRITE_OFF_PART_GUV_YTD_OC_ONBALANCE,
                    ABIT_ON.WRITE_OFF_PART_GUV_YTD_EUR_ONBALANCE,
                    ABIT_ON.WRITE_OFF_PART_GUV_MTM_OC_ONBALANCE,
                    ABIT_ON.WRITE_OFF_PART_GUV_MTM_EUR_ONBALANCE,
                    ABIT_ON.WRITE_OFF_FULL_DATE_ONBALANCE,
                    ABIT_ON.WRITE_OFF_PART_DATE_ONBALANCE,
                    ABIT_ON.POCI_NOMINAL_AMOUNT_ORIG_OC_ONBALANCE,
                    ABIT_ON.POCI_NOMINAL_AMOUNT_ORIG_EUR_ONBALANCE,
                    ABIT_ON.POCI_NOMINAL_AMOUNT_ADJ_OC_ONBALANCE,
                    ABIT_ON.POCI_NOMINAL_AMOUNT_ADJ_EUR_ONBALANCE,
                    ABIT_ON.POCI_REGEN_OC_ONBALANCE,
                    ABIT_ON.POCI_REGEN_EUR_ONBALANCE,
                    ABIT_ON.POCI_LIQUIDATION_OC_ONBALANCE,
                    ABIT_ON.POCI_LIQUIDATION_EUR_ONBALANCE,
                    ABIT_ON.POCI_CONSUMPTION_OC_ONBALANCE,
                    ABIT_ON.POCI_CONSUMPTION_EUR_ONBALANCE,
                    -- Off
                    ABIT_OFF.AMOUNT_EUR_OFFBALANCE,
                    ABIT_OFF.AMOUNT_OC_OFFBALANCE,
                    ABIT_OFF.DATE_CREATED_OFFBALANCE,
                    ABIT_OFF.AMOUNT_PREV_YEAR_OC_OFFBALANCE,
                    ABIT_OFF.AMOUNT_PREV_YEAR_EUR_OFFBALANCE,
                    ABIT_OFF.AMOUNT_PREV_MONTH_OC_OFFBALANCE,
                    ABIT_OFF.AMOUNT_PREV_MONTH_EUR_OFFBALANCE,
                    ABIT_OFF.AMOUNT_PREV_QUARTER_OC_OFFBALANCE,
                    ABIT_OFF.SUPPLY_FULL_YTD_OC_OFFBALANCE,
                    ABIT_OFF.SUPPLY_FULL_YTD_EUR_OFFBALANCE,
                    ABIT_OFF.SUPPLY_BAL_YTD_OC_OFFBALANCE,
                    ABIT_OFF.SUPPLY_BAL_YTD_EUR_OFFBALANCE,
                    ABIT_OFF.SUPPLY_ELSE_YTD_OC_OFFBALANCE,
                    ABIT_OFF.SUPPLY_ELSE_YTD_EUR_OFFBALANCE,
                    ABIT_OFF.SUPPLY_FULL_MTM_OC_OFFBALANCE,
                    ABIT_OFF.SUPPLY_FULL_MTM_EUR_OFFBALANCE,
                    ABIT_OFF.SUPPLY_BAL_MTM_OC_OFFBALANCE,
                    ABIT_OFF.SUPPLY_BAL_MTM_EUR_OFFBALANCE,
                    ABIT_OFF.SUPPLY_ELSE_MTM_OC_OFFBALANCE,
                    ABIT_OFF.SUPPLY_ELSE_MTM_EUR_OFFBALANCE,
                    ABIT_OFF.LIQUIDATION_FULL_YTD_OC_OFFBALANCE,
                    ABIT_OFF.LIQUIDATION_FULL_YTD_EUR_OFFBALANCE,
                    ABIT_OFF.LIQUIDATION_BAL_YTD_OC_OFFBALANCE,
                    ABIT_OFF.LIQUIDATION_BAL_YTD_EUR_OFFBALANCE,
                    ABIT_OFF.LIQUIDATION_ELSE_YTD_OC_OFFBALANCE,
                    ABIT_OFF.LIQUIDATION_ELSE_YTD_EUR_OFFBALANCE,
                    ABIT_OFF.LIQUIDATION_FULL_MTM_OC_OFFBALANCE,
                    ABIT_OFF.LIQUIDATION_FULL_MTM_EUR_OFFBALANCE,
                    ABIT_OFF.LIQUIDATION_BAL_MTM_OC_OFFBALANCE,
                    ABIT_OFF.LIQUIDATION_BAL_MTM_EUR_OFFBALANCE,
                    ABIT_OFF.LIQUIDATION_ELSE_MTM_OC_OFFBALANCE,
                    ABIT_OFF.LIQUIDATION_ELSE_MTM_EUR_OFFBALANCE,
                    ABIT_OFF.DEBIT_YTD_OC_OFFBALANCE,
                    ABIT_OFF.DEBIT_YTD_EUR_OFFBALANCE,
                    ABIT_OFF.DEBIT_MTM_OC_OFFBALANCE,
                    ABIT_OFF.DEBIT_MTM_EUR_OFFBALANCE,
                    ABIT_OFF.UNWINDING_YTD_OC_OFFBALANCE,
                    ABIT_OFF.UNWINDING_YTD_EUR_OFFBALANCE,
                    ABIT_OFF.UNWINDING_MTM_OC_OFFBALANCE,
                    ABIT_OFF.UNWINDING_MTM_EUR_OFFBALANCE,
                    ABIT_OFF.MANUAL_AMOUNT_OC_OFFBALANCE,
                    ABIT_OFF.MANUAL_AMOUNT_EUR_OFFBALANCE,
                    ABIT_OFF.WRITE_OFF_FULL_GUV_YTD_OC_OFFBALANCE,
                    ABIT_OFF.WRITE_OFF_FULL_GUV_YTD_EUR_OFFBALANCE,
                    ABIT_OFF.WRITE_OFF_FULL_GUV_MTM_OC_OFFBALANCE,
                    ABIT_OFF.WRITE_OFF_FULL_GUV_MTM_EUR_OFFBALANCE,
                    ABIT_OFF.WRITE_OFF_PART_GUV_YTD_OC_OFFBALANCE,
                    ABIT_OFF.WRITE_OFF_PART_GUV_YTD_EUR_OFFBALANCE,
                    ABIT_OFF.WRITE_OFF_PART_GUV_MTM_OC_OFFBALANCE,
                    ABIT_OFF.WRITE_OFF_PART_GUV_MTM_EUR_OFFBALANCE,
                    ABIT_OFF.WRITE_OFF_FULL_DATE_OFFBALANCE,
                    ABIT_OFF.WRITE_OFF_PART_DATE_OFFBALANCE,
                    ABIT_OFF.POCI_NOMINAL_AMOUNT_ORIG_OC_OFFBALANCE,
                    ABIT_OFF.POCI_NOMINAL_AMOUNT_ORIG_EUR_OFFBALANCE,
                    ABIT_OFF.POCI_NOMINAL_AMOUNT_ADJ_OC_OFFBALANCE,
                    ABIT_OFF.POCI_NOMINAL_AMOUNT_ADJ_EUR_OFFBALANCE,
                    ABIT_OFF.POCI_REGEN_OC_OFFBALANCE,
                    ABIT_OFF.POCI_REGEN_EUR_OFFBALANCE,
                    ABIT_OFF.POCI_LIQUIDATION_OC_OFFBALANCE,
                    ABIT_OFF.POCI_LIQUIDATION_EUR_OFFBALANCE,
                    ABIT_OFF.POCI_CONSUMPTION_OC_OFFBALANCE,
                    ABIT_OFF.POCI_CONSUMPTION_EUR_OFFBALANCE
    from ABIT_RIVO
             left join ABIT_ON on (ABIT_ON.FACILITY_ID, ABIT_ON.CUT_OFF_DATE) =
                                  (ABIT_RIVO.FACILITY_ID, ABIT_RIVO.CUT_OFF_DATE)
             left join ABIT_OFF on (ABIT_OFF.FACILITY_ID, ABIT_OFF.CUT_OFF_DATE) =
                                   (ABIT_RIVO.FACILITY_ID, ABIT_RIVO.CUT_OFF_DATE)
),
-- Gefiltert nach noetigen Datenfeldern
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        CLIENT_ID,
        FACILITY_ID,
        CURRENCY,
        CURRENCY_OC,
        EXCHANGE_RATE_EUR2OC,
        IFRSMETHOD,
        IFRSMETHOD_PREV_YEAR,
        POCI_ACCOUNT,
        -- On
        AMOUNT_OC_ONBALANCE,
        AMOUNT_EUR_ONBALANCE,
        AMOUNT_PREV_YEAR_OC_ONBALANCE,
        AMOUNT_PREV_YEAR_EUR_ONBALANCE,
        DATE_CREATED_ONBALANCE,
        SUPPLY_FULL_YTD_OC_ONBALANCE,
        SUPPLY_FULL_YTD_EUR_ONBALANCE,
        LIQUIDATION_FULL_YTD_OC_ONBALANCE,
        LIQUIDATION_FULL_YTD_EUR_ONBALANCE,
        LIQUIDATION_BAL_YTD_OC_ONBALANCE,
        LIQUIDATION_BAL_YTD_EUR_ONBALANCE,
        DEBIT_YTD_OC_ONBALANCE,
        DEBIT_YTD_EUR_ONBALANCE,
        UNWINDING_YTD_OC_ONBALANCE,
        UNWINDING_YTD_EUR_ONBALANCE,
        WRITE_OFF_FULL_GUV_YTD_OC_ONBALANCE,
        WRITE_OFF_FULL_GUV_YTD_EUR_ONBALANCE,
        WRITE_OFF_FULL_DATE_ONBALANCE,
        POCI_NOMINAL_AMOUNT_ORIG_OC_ONBALANCE,
        POCI_NOMINAL_AMOUNT_ORIG_EUR_ONBALANCE,
        POCI_NOMINAL_AMOUNT_ADJ_OC_ONBALANCE,
        POCI_NOMINAL_AMOUNT_ADJ_EUR_ONBALANCE,
        POCI_REGEN_OC_ONBALANCE,
        POCI_REGEN_EUR_ONBALANCE,
        POCI_LIQUIDATION_OC_ONBALANCE,
        POCI_LIQUIDATION_EUR_ONBALANCE,
        POCI_CONSUMPTION_OC_ONBALANCE,
        POCI_CONSUMPTION_EUR_ONBALANCE,
        -- Off
        AMOUNT_OC_OFFBALANCE,
        AMOUNT_EUR_OFFBALANCE,
        AMOUNT_PREV_YEAR_OC_OFFBALANCE,
        AMOUNT_PREV_YEAR_EUR_OFFBALANCE,
        DATE_CREATED_OFFBALANCE,
        SUPPLY_FULL_YTD_OC_OFFBALANCE,
        SUPPLY_FULL_YTD_EUR_OFFBALANCE,
        LIQUIDATION_FULL_YTD_OC_OFFBALANCE,
        LIQUIDATION_FULL_YTD_EUR_OFFBALANCE,
        LIQUIDATION_BAL_YTD_OC_OFFBALANCE,
        LIQUIDATION_BAL_YTD_EUR_OFFBALANCE,
        DEBIT_YTD_OC_OFFBALANCE,
        DEBIT_YTD_EUR_OFFBALANCE,
        UNWINDING_YTD_OC_OFFBALANCE,
        UNWINDING_YTD_EUR_OFFBALANCE,
        WRITE_OFF_FULL_GUV_YTD_OC_OFFBALANCE,
        WRITE_OFF_FULL_GUV_YTD_EUR_OFFBALANCE,
        WRITE_OFF_FULL_DATE_OFFBALANCE,
        POCI_NOMINAL_AMOUNT_ORIG_OC_OFFBALANCE,
        POCI_NOMINAL_AMOUNT_ORIG_EUR_OFFBALANCE,
        POCI_NOMINAL_AMOUNT_ADJ_OC_OFFBALANCE,
        POCI_NOMINAL_AMOUNT_ADJ_EUR_OFFBALANCE,
        POCI_REGEN_OC_OFFBALANCE,
        POCI_REGEN_EUR_OFFBALANCE,
        POCI_LIQUIDATION_OC_OFFBALANCE,
        POCI_LIQUIDATION_EUR_OFFBALANCE,
        POCI_CONSUMPTION_OC_OFFBALANCE,
        POCI_CONSUMPTION_EUR_OFFBALANCE,
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
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_FACILITY_ABIT_RISK_PROVISION_EBA_CURRENT');
create table AMC.TABLE_FACILITY_ABIT_RISK_PROVISION_EBA_CURRENT like CALC.VIEW_FACILITY_ABIT_RISK_PROVISION_EBA distribute by hash (FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_ABIT_RISK_PROVISION_EBA_CURRENT_FACILITY_ID on AMC.TABLE_FACILITY_ABIT_RISK_PROVISION_EBA_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_FACILITY_ABIT_RISK_PROVISION_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_FACILITY_ABIT_RISK_PROVISION_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------


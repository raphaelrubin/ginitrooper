-- View erstellen
drop view CALC.VIEW_FACILITY_EBA;
-- Haupttabelle Facility EBA
create or replace view CALC.VIEW_FACILITY_EBA as
with
-- CUT_OFF_DATE
COD as (
    select CUT_OFF_DATE
    from CALC.AUTO_TABLE_CUTOFFDATES
    where IS_ACTIVE
),
---- Quelldaten
PWC_FAC as (
    select *
    from CALC.SWITCH_FACILITY_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
LIQ_FAC as (
    select *
    from CALC.SWITCH_FACILITY_LIQ_EBA_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
IWHS_AZ6_FAC as (
    select *
    from CALC.SWITCH_FACILITY_IWHS_AZ6_EBA_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
FSD_FAC as (
    select *
    from CALC.SWITCH_FACILITY_FINSTABDEV_EBA_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
ZEB_FAC as (
    select *
    from CALC.SWITCH_FACILITY_ZEB_EBA_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
ABIT_FAC as (
    select *
    from CALC.SWITCH_FACILITY_ABIT_RISK_PROVISION_EBA_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
CPC_FAC as (
    select *
    from CALC.SWITCH_FACILITY_CPC_EBA_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
DIVERS_FAC as (
    select *
    from CALC.SWITCH_FACILITY_DIVERS_EBA_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
CMS_FAC as (
    select *
    from CALC.SWITCH_FACILITY_CMS_EBA_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
IWHS_KNZL_FAC as (
    select *
    from CALC.SWITCH_FACILITY_IWHS_KENNZAHLEN_EBA_CURRENT
    where CUT_OFF_DATE = (select CUT_OFF_DATE from COD)
),
-- Alles zusammenführen
FINAL as (
    select distinct PWC.CUT_OFF_DATE,
                    PWC.FACILITY_ID,
                    NVL(LIQ.FACILITY_ID, LIQ_LUX.FACILITY_ID)                                               as LIQ_FACILITY_ID,
                    NVL(LIQ.PARENTFACILITY, LIQ_LUX.PARENTFACILITY)                                         as LIQ_PARENTFACILITY,
                    NVL(LIQ.DEAL_ID, LIQ_LUX.DEAL_ID)                                                       as LIQ_DEAL_ID,
                    NVL(LIQ.KREDITNEHMER_GP_NR, LIQ_LUX.KREDITNEHMER_GP_NR)                                 as LIQ_KREDITNEHMER_GP_NR,
                    NVL(LIQ.KREDITNEHMER_GP_NAME, LIQ_LUX.KREDITNEHMER_GP_NAME)                             as LIQ_KREDITNEHMER_GP_NAME,
                    NVL(LIQ.STATUS, LIQ_LUX.STATUS)                                                         as LIQ_STATUS,
                    NVL(LIQ.CURRENCY, LIQ_LUX.CURRENCY)                                                     as LIQ_CURRENCY,
                    NVL(LIQ.CURRENCY_OC, LIQ_LUX.CURRENCY_OC)                                               as LIQ_CURRENCY_OC,
                    NVL(LIQ.AUSZAHLUNG_BEGINN_DATUM, LIQ_LUX.AUSZAHLUNG_BEGINN_DATUM)                       as LIQ_AUSZAHLUNG_BEGINN_DATUM,
                    NVL(LIQ.PRODUKT_SCHLUESSEL, LIQ_LUX.PRODUKT_SCHLUESSEL)                                 as LIQ_PRODUKT_SCHLUESSEL,
                    NVL(LIQ.PRODUKT_SCHLUESSEL_BESCHREIBUNG, LIQ_LUX.PRODUKT_SCHLUESSEL_BESCHREIBUNG)       as LIQ_PRODUKT_SCHLUESSEL_BESCHREIBUNG,
                    NVL(LIQ.IOPC_ID, LIQ_LUX.IOPC_ID)                                                       as LIQ_IOPC_ID,
                    NVL(LIQ.FINANZIERUNG_VORHABEN, LIQ_LUX.FINANZIERUNG_VORHABEN)                           as LIQ_FINANZIERUNG_VORHABEN,
                    NVL(LIQ.FINANZIERUNG_VORHABEN_BESCHREIBUNG, LIQ_LUX.FINANZIERUNG_VORHABEN_BESCHREIBUNG) as LIQ_FINANZIERUNG_VORHABEN_BESCHREIBUNG,
                    NVL(LIQ.AUSZAHLUNGSVERPFLICHTUNG_BTR, LIQ_LUX.AUSZAHLUNGSVERPFLICHTUNG_BTR)             as LIQ_AUSZAHLUNGSVERPFLICHTUNG_BTR,
                    NVL(LIQ.KREDITZUSAGE_ENDE_DATUM, LIQ_LUX.KREDITZUSAGE_ENDE_DATUM)                       as LIQ_KREDITZUSAGE_ENDE_DATUM,
                    NVL(LIQ.VERZUG_BEGINN_DATUM, LIQ_LUX.VERZUG_BEGINN_DATUM)                               as LIQ_VERZUG_BEGINN_DATUM,
                    NVL(LIQ.SUMME_VERZUGSTAGE, LIQ_LUX.SUMME_VERZUGSTAGE)                                   as LIQ_SUMME_VERZUGSTAGE,
                    NVL(LIQ.VERZUG_BTR_SUM, LIQ_LUX.VERZUG_BTR_SUM)                                         as LIQ_VERZUG_BTR_SUM,
                    NVL(LIQ.RUECKST_GEBUEHR_BTR, LIQ_LUX.RUECKST_GEBUEHR_BTR)                               as LIQ_RUECKST_GEBUEHR_BTR,
                    NVL(LIQ.RUECKST_TILGUNG_BTR, LIQ_LUX.RUECKST_TILGUNG_BTR)                               as LIQ_RUECKST_TILGUNG_BTR,
                    NVL(LIQ.RUECKST_ZINSEN_BTR, LIQ_LUX.RUECKST_ZINSEN_BTR)                                 as LIQ_RUECKST_ZINSEN_BTR,
                    NVL(LIQ.EINSTANDSATZ_PRZ, LIQ_LUX.EINSTANDSATZ_PRZ)                                     as LIQ_EINSTANDSATZ_PRZ,
                    NVL(LIQ.STUNDUNG_SALDO, LIQ_LUX.STUNDUNG_SALDO)                                         as LIQ_STUNDUNG_SALDO,
                    NVL(LIQ.RESTKAPITAL_BTR_BRUTTO, LIQ_LUX.RESTKAPITAL_BTR_BRUTTO)                         as LIQ_RESTKAPITAL_BTR_BRUTTO,
                    NVL(LIQ.RESTKAPITAL_BTR_NETTO, LIQ_LUX.RESTKAPITAL_BTR_NETTO)                           as LIQ_RESTKAPITAL_BTR_NETTO,
                    NVL(LIQ.RESTKAPITAL_BTR_KONSORTEN, LIQ_LUX.RESTKAPITAL_BTR_KONSORTEN)                   as LIQ_RESTKAPITAL_BTR_KONSORTEN,
                    NVL(LIQ.URSPRUNGSKAPITAL_BTR_BRUTTO, LIQ_LUX.URSPRUNGSKAPITAL_BTR_BRUTTO)               as LIQ_URSPRUNGSKAPITAL_BTR_BRUTTO,
                    NVL(LIQ.URSPRUNGSKAPITAL_BTR_NETTO, LIQ_LUX.URSPRUNGSKAPITAL_BTR_NETTO)                 as LIQ_URSPRUNGSKAPITAL_BTR_NETTO,
                    NVL(LIQ.URSPRUNGSKAPITAL_BTR_KONSORTEN, LIQ_LUX.URSPRUNGSKAPITAL_BTR_KONSORTEN)         as LIQ_URSPRUNGSKAPITAL_BTR_KONSORTEN,
                    NVL(LIQ.TILGUNG_ART_MM, LIQ_LUX.TILGUNG_ART_MM)                                         as LIQ_TILGUNG_ART_MM,
                    NVL(LIQ.TILGUNG_ENDE_DATUM, LIQ_LUX.TILGUNG_ENDE_DATUM)                                 as LIQ_TILGUNG_ENDE_DATUM,
                    NVL(LIQ.ZINS_TYP, LIQ_LUX.ZINS_TYP)                                                     as LIQ_ZINS_TYP,
                    NVL(LIQ.SOLL_ZINSSATZ, LIQ_LUX.SOLL_ZINSSATZ)                                           as LIQ_SOLL_ZINSSATZ,
                    NVL(LIQ.ZINSBINDUNG_ENDE_DATUM, LIQ_LUX.ZINSBINDUNG_ENDE_DATUM)                         as LIQ_ZINSBINDUNG_ENDE_DATUM,
                    NVL(LIQ.VERTRAG_ENDE_DATUM, LIQ_LUX.VERTRAG_ENDE_DATUM)                                 as LIQ_VERTRAG_ENDE_DATUM,
                    AZ6.CURRENCY                                                                            as AZ6_CURRENCY,
                    AZ6.CURRENCY_OC                                                                         as AZ6_CURRENCY_OC,
                    AZ6.DARLEHENSART                                                                        as AZ6_DARLEHENSART,
                    AZ6.BEFRISTUNG_ZUSAGE                                                                   as AZ6_BEFRISTUNG_ZUSAGE,
                    AZ6.PRODUKTSCHLUESSEL                                                                   as AZ6_PRODUKTSCHLUESSEL,
                    AZ6.VERWENDUNGSZWECK                                                                    as AZ6_VERWENDUNGSZWECK,
                    AZ6.SOLLZINSSATZ                                                                        as AZ6_SOLLZINSSATZ,
                    AZ6.AKTUELLE_ENDE_DATUM                                                                 as AZ6_AKTUELLE_ENDE_DATUM,
                    AZ6.DATUM_ERSTE_VALUTIERUNG                                                             as AZ6_DATUM_ERSTE_VALUTIERUNG,
                    AZ6.STUNDUNGSSALDO                                                                      as AZ6_STUNDUNGSSALDO,
                    AZ6.BETRAG                                                                              as AZ6_BETRAG,
                    AZ6.TILGUNGSFORM_DARLEHENSART                                                           as AZ6_TILGUNGSFORM_DARLEHENSART,
                    AZ6.KZ_MITHAFTUNG_MITTELGEBER                                                           as AZ6_KZ_MITHAFTUNG_MITTELGEBER,
                    AZ6.RISIKO_FREMD_KI                                                                     as AZ6_RISIKO_FREMD_KI,
                    AZ6.KONTOSALDO                                                                          as AZ6_KONTOSALDO,
                    AZ6.ENTGELTVERZUG                                                                       as AZ6_ENTGELTVERZUG,
                    AZ6.GESAMTVERZUG                                                                        as AZ6_GESAMTVERZUG,
                    AZ6.UNVERZINSLICHER_VERZUG                                                              as AZ6_UNVERZINSLICHER_VERZUG,
                    AZ6.VERZINSLICHER_VERZUG_BIS_31_DEZ                                                     as AZ6_VERZINSLICHER_VERZUG_BIS_31_DEZ,
                    AZ6.SONDERTILGUNG_MAXIMALBETRAG                                                         as AZ6_SONDERTILGUNG_MAXIMALBETRAG,
                    AZ6.SONDERTILGUNG_MINDESTBETRAG                                                         as AZ6_SONDERTILGUNG_MINDESTBETRAG,
                    AZ6.LEISTUNGSSTOERUNGSBETRAG_SONDERTILGUNG                                              as AZ6_LEISTUNGSSTOERUNGSBETRAG_SONDERTILGUNG,
                    AZ6.NICHT_PLANMAESSIGE_AENDERUNG_VERZINSUNGSSALDO                                       as AZ6_NICHT_PLANMAESSIGE_AENDERUNG_VERZINSUNGSSALDO,
                    AZ6.LEISTUNGSSTOERUNGSBETRAG_SONDERTILGUNG_WG_PROLONGATION                              as AZ6_LEISTUNGSSTOERUNGSBETRAG_SONDERTILGUNG_WG_PROLONGATION,
                    AZ6.OWNSYNDICATEQUOTA                                                                   as AZ6_OWNSYNDICATEQUOTA,
                    AZ6.LOANSTATE                                                                           as AZ6_LOANSTATE,
                    FSD.MELDESTICHTAG_NEUGESCHAEFT                                                          as FINSTABDEV_MELDESTICHTAG_NEUGESCHAEFT,
                    FSD.OBJECT_ID                                                                           as FINSTABDEV_OBJECT_ID,
                    FSD.DSTI                                                                                as FINSTABDEV_DSTI,
                    FSD.DTI                                                                                 as FINSTABDEV_DTI,
                    FSD.VERHAELTNIS_DARLEHENSVOLUMEN_BELEIHUNGSWERT                                         as FINSTABDEV_VERHAELTNIS_DARLEHENSVOLUMEN_BELEIHUNGSWERT,
                    FSD.LTV                                                                                 as FINSTABDEV_LTV,
                    FSD.RELEVANZ_WIFSTA                                                                     as FINSTABDEV_RELEVANZ_WIFSTA,
                    ZEB.CURRENCY                                                                            as ZEB_CURRENCY,
                    ZEB.CURRENCY_OC                                                                         as ZEB_CURRENCY_OC,
                    ZEB.R_LOAN_LOSS_PROVISION_AMT_ONBALANCE                                                 as ZEB_R_LOAN_LOSS_PROVISION_AMT_ONBALANCE,
                    ZEB.R_LOAN_LOSS_PROVISION_PREV_AMT_ONBALANCE                                            as ZEB_R_LOAN_LOSS_PROVISION_PREV_AMT_ONBALANCE,
                    ZEB.R_STAGE_LLP_CALCULATED_ID_ONBALANCE                                                 as ZEB_R_STAGE_LLP_CALCULATED_ID_ONBALANCE,
                    ZEB.R_STAGE_LLP_REASON_DESC_ONBALANCE                                                   as ZEB_R_STAGE_LLP_REASON_DESC_ONBALANCE,
                    ZEB.R_CREDIT_CONVERSION_FACTOR_RATE_ONBALANCE                                           as ZEB_R_CREDIT_CONVERSION_FACTOR_RATE_ONBALANCE,
                    ZEB.R_EAD_TOTAL_AMT_ONBALANCE                                                           as ZEB_R_EAD_TOTAL_AMT_ONBALANCE,
                    ZEB.R_EXP_LIFETIME_LOSS_AMT_ONBALANCE                                                   as ZEB_R_EXP_LIFETIME_LOSS_AMT_ONBALANCE,
                    ZEB.R_EXP_LOSS_AMT_ONBALANCE                                                            as ZEB_R_EXP_LOSS_AMT_ONBALANCE,
                    ZEB.R_LIFETIME_PROB_DEF_RATE_ONBALANCE                                                  as ZEB_R_LIFETIME_PROB_DEF_RATE_ONBALANCE,
                    ZEB.R_LOSS_GIVEN_DEFAULT_RATE_ONBALANCE                                                 as ZEB_R_LOSS_GIVEN_DEFAULT_RATE_ONBALANCE,
                    ZEB.R_ONE_YEAR_PROB_OF_DEFAULT_RATE_ONBALANCE                                           as ZEB_R_ONE_YEAR_PROB_OF_DEFAULT_RATE_ONBALANCE,
                    ZEB.E_DIRECT_WRITE_OFF_AMT_ONBALANCE                                                    as ZEB_E_DIRECT_WRITE_OFF_AMT_ONBALANCE,
                    ZEB.R_IFRS_EFF_INTEREST_RATE_ONBALANCE                                                  as ZEB_R_IFRS_EFF_INTEREST_RATE_ONBALANCE,
                    ZEB.R_LOAN_LOSS_PROVISION_AMT_OFFBALANCE                                                as ZEB_R_LOAN_LOSS_PROVISION_AMT_OFFBALANCE,
                    ZEB.R_LOAN_LOSS_PROVISION_PREV_AMT_OFFBALANCE                                           as ZEB_R_LOAN_LOSS_PROVISION_PREV_AMT_OFFBALANCE,
                    ZEB.R_STAGE_LLP_CALCULATED_ID_OFFBALANCE                                                as ZEB_R_STAGE_LLP_CALCULATED_ID_OFFBALANCE,
                    ZEB.R_STAGE_LLP_REASON_DESC_OFFBALANCE                                                  as ZEB_R_STAGE_LLP_REASON_DESC_OFFBALANCE,
                    ZEB.R_CREDIT_CONVERSION_FACTOR_RATE_OFFBALANCE                                          as ZEB_R_CREDIT_CONVERSION_FACTOR_RATE_OFFBALANCE,
                    ZEB.R_EAD_TOTAL_AMT_OFFBALANCE                                                          as ZEB_R_EAD_TOTAL_AMT_OFFBALANCE,
                    ZEB.R_EXP_LIFETIME_LOSS_AMT_OFFBALANCE                                                  as ZEB_R_EXP_LIFETIME_LOSS_AMT_OFFBALANCE,
                    ZEB.R_EXP_LOSS_AMT_OFFBALANCE                                                           as ZEB_R_EXP_LOSS_AMT_OFFBALANCE,
                    ZEB.R_LIFETIME_PROB_DEF_RATE_OFFBALANCE                                                 as ZEB_R_LIFETIME_PROB_DEF_RATE_OFFBALANCE,
                    ZEB.R_LOSS_GIVEN_DEFAULT_RATE_OFFBALANCE                                                as ZEB_R_LOSS_GIVEN_DEFAULT_RATE_OFFBALANCE,
                    ZEB.R_ONE_YEAR_PROB_OF_DEFAULT_RATE_OFFBALANCE                                          as ZEB_R_ONE_YEAR_PROB_OF_DEFAULT_RATE_OFFBALANCE,
                    ZEB.E_DIRECT_WRITE_OFF_AMT_OFFBALANCE                                                   as ZEB_E_DIRECT_WRITE_OFF_AMT_OFFBALANCE,
                    ZEB.R_IFRS_EFF_INTEREST_RATE_OFFBALANCE                                                 as ZEB_R_IFRS_EFF_INTEREST_RATE_OFFBALANCE,
                    ABIT.CURRENCY                                                                           as ABIT_CURRENCY,
                    ABIT.CURRENCY_OC                                                                        as ABIT_CURRENCY_OC,
                    ABIT.EXCHANGE_RATE_EUR2OC                                                               as ABIT_EXCHANGE_RATE_EUR2OC,
                    ABIT.IFRSMETHOD                                                                         as ABIT_IFRSMETHOD,
                    ABIT.IFRSMETHOD_PREV_YEAR                                                               as ABIT_IFRSMETHOD_PREV_YEAR,
                    ABIT.POCI_ACCOUNT                                                                       as ABIT_POCI_ACCOUNT,
                    ABIT.AMOUNT_OC_ONBALANCE                                                                as ABIT_AMOUNT_OC_ONBALANCE,
                    ABIT.AMOUNT_EUR_ONBALANCE                                                               as ABIT_AMOUNT_EUR_ONBALANCE,
                    ABIT.AMOUNT_PREV_YEAR_OC_ONBALANCE                                                      as ABIT_AMOUNT_PREV_YEAR_OC_ONBALANCE,
                    ABIT.AMOUNT_PREV_YEAR_EUR_ONBALANCE                                                     as ABIT_AMOUNT_PREV_YEAR_EUR_ONBALANCE,
                    ABIT.DATE_CREATED_ONBALANCE                                                             as ABIT_DATE_CREATED_ONBALANCE,
                    ABIT.SUPPLY_FULL_YTD_OC_ONBALANCE                                                       as ABIT_SUPPLY_FULL_YTD_OC_ONBALANCE,
                    ABIT.SUPPLY_FULL_YTD_EUR_ONBALANCE                                                      as ABIT_SUPPLY_FULL_YTD_EUR_ONBALANCE,
                    ABIT.LIQUIDATION_FULL_YTD_OC_ONBALANCE                                                  as ABIT_LIQUIDATION_FULL_YTD_OC_ONBALANCE,
                    ABIT.LIQUIDATION_FULL_YTD_EUR_ONBALANCE                                                 as ABIT_LIQUIDATION_FULL_YTD_EUR_ONBALANCE,
                    ABIT.LIQUIDATION_BAL_YTD_OC_ONBALANCE                                                   as ABIT_LIQUIDATION_BAL_YTD_OC_ONBALANCE,
                    ABIT.LIQUIDATION_BAL_YTD_EUR_ONBALANCE                                                  as ABIT_LIQUIDATION_BAL_YTD_EUR_ONBALANCE,
                    ABIT.DEBIT_YTD_OC_ONBALANCE                                                             as ABIT_DEBIT_YTD_OC_ONBALANCE,
                    ABIT.DEBIT_YTD_EUR_ONBALANCE                                                            as ABIT_DEBIT_YTD_EUR_ONBALANCE,
                    ABIT.UNWINDING_YTD_OC_ONBALANCE                                                         as ABIT_UNWINDING_YTD_OC_ONBALANCE,
                    ABIT.UNWINDING_YTD_EUR_ONBALANCE                                                        as ABIT_UNWINDING_YTD_EUR_ONBALANCE,
                    ABIT.WRITE_OFF_FULL_GUV_YTD_OC_ONBALANCE                                                as ABIT_WRITE_OFF_FULL_GUV_YTD_OC_ONBALANCE,
                    ABIT.WRITE_OFF_FULL_GUV_YTD_EUR_ONBALANCE                                               as ABIT_WRITE_OFF_FULL_GUV_YTD_EUR_ONBALANCE,
                    ABIT.WRITE_OFF_FULL_DATE_ONBALANCE                                                      as ABIT_WRITE_OFF_FULL_DATE_ONBALANCE,
                    ABIT.POCI_NOMINAL_AMOUNT_ORIG_OC_ONBALANCE                                              as ABIT_POCI_NOMINAL_AMOUNT_ORIG_OC_ONBALANCE,
                    ABIT.POCI_NOMINAL_AMOUNT_ORIG_EUR_ONBALANCE                                             as ABIT_POCI_NOMINAL_AMOUNT_ORIG_EUR_ONBALANCE,
                    ABIT.POCI_NOMINAL_AMOUNT_ADJ_OC_ONBALANCE                                               as ABIT_POCI_NOMINAL_AMOUNT_ADJ_OC_ONBALANCE,
                    ABIT.POCI_NOMINAL_AMOUNT_ADJ_EUR_ONBALANCE                                              as ABIT_POCI_NOMINAL_AMOUNT_ADJ_EUR_ONBALANCE,
                    ABIT.POCI_REGEN_OC_ONBALANCE                                                            as ABIT_POCI_REGEN_OC_ONBALANCE,
                    ABIT.POCI_REGEN_EUR_ONBALANCE                                                           as ABIT_POCI_REGEN_EUR_ONBALANCE,
                    ABIT.POCI_LIQUIDATION_OC_ONBALANCE                                                      as ABIT_POCI_LIQUIDATION_OC_ONBALANCE,
                    ABIT.POCI_LIQUIDATION_EUR_ONBALANCE                                                     as ABIT_POCI_LIQUIDATION_EUR_ONBALANCE,
                    ABIT.POCI_CONSUMPTION_OC_ONBALANCE                                                      as ABIT_POCI_CONSUMPTION_OC_ONBALANCE,
                    ABIT.POCI_CONSUMPTION_EUR_ONBALANCE                                                     as ABIT_POCI_CONSUMPTION_EUR_ONBALANCE,
                    ABIT.AMOUNT_OC_OFFBALANCE                                                               as ABIT_AMOUNT_OC_OFFBALANCE,
                    ABIT.AMOUNT_EUR_OFFBALANCE                                                              as ABIT_AMOUNT_EUR_OFFBALANCE,
                    ABIT.AMOUNT_PREV_YEAR_OC_OFFBALANCE                                                     as ABIT_AMOUNT_PREV_YEAR_OC_OFFBALANCE,
                    ABIT.AMOUNT_PREV_YEAR_EUR_OFFBALANCE                                                    as ABIT_AMOUNT_PREV_YEAR_EUR_OFFBALANCE,
                    ABIT.DATE_CREATED_OFFBALANCE                                                            as ABIT_DATE_CREATED_OFFBALANCE,
                    ABIT.SUPPLY_FULL_YTD_OC_OFFBALANCE                                                      as ABIT_SUPPLY_FULL_YTD_OC_OFFBALANCE,
                    ABIT.SUPPLY_FULL_YTD_EUR_OFFBALANCE                                                     as ABIT_SUPPLY_FULL_YTD_EUR_OFFBALANCE,
                    ABIT.LIQUIDATION_FULL_YTD_OC_OFFBALANCE                                                 as ABIT_LIQUIDATION_FULL_YTD_OC_OFFBALANCE,
                    ABIT.LIQUIDATION_FULL_YTD_EUR_OFFBALANCE                                                as ABIT_LIQUIDATION_FULL_YTD_EUR_OFFBALANCE,
                    ABIT.LIQUIDATION_BAL_YTD_OC_OFFBALANCE                                                  as ABIT_LIQUIDATION_BAL_YTD_OC_OFFBALANCE,
                    ABIT.LIQUIDATION_BAL_YTD_EUR_OFFBALANCE                                                 as ABIT_LIQUIDATION_BAL_YTD_EUR_OFFBALANCE,
                    ABIT.DEBIT_YTD_OC_OFFBALANCE                                                            as ABIT_DEBIT_YTD_OC_OFFBALANCE,
                    ABIT.DEBIT_YTD_EUR_OFFBALANCE                                                           as ABIT_DEBIT_YTD_EUR_OFFBALANCE,
                    ABIT.UNWINDING_YTD_OC_OFFBALANCE                                                        as ABIT_UNWINDING_YTD_OC_OFFBALANCE,
                    ABIT.UNWINDING_YTD_EUR_OFFBALANCE                                                       as ABIT_UNWINDING_YTD_EUR_OFFBALANCE,
                    ABIT.WRITE_OFF_FULL_GUV_YTD_OC_OFFBALANCE                                               as ABIT_WRITE_OFF_FULL_GUV_YTD_OC_OFFBALANCE,
                    ABIT.WRITE_OFF_FULL_GUV_YTD_EUR_OFFBALANCE                                              as ABIT_WRITE_OFF_FULL_GUV_YTD_EUR_OFFBALANCE,
                    ABIT.WRITE_OFF_FULL_DATE_OFFBALANCE                                                     as ABIT_WRITE_OFF_FULL_DATE_OFFBALANCE,
                    ABIT.POCI_NOMINAL_AMOUNT_ORIG_OC_OFFBALANCE                                             as ABIT_POCI_NOMINAL_AMOUNT_ORIG_OC_OFFBALANCE,
                    ABIT.POCI_NOMINAL_AMOUNT_ORIG_EUR_OFFBALANCE                                            as ABIT_POCI_NOMINAL_AMOUNT_ORIG_EUR_OFFBALANCE,
                    ABIT.POCI_NOMINAL_AMOUNT_ADJ_OC_OFFBALANCE                                              as ABIT_POCI_NOMINAL_AMOUNT_ADJ_OC_OFFBALANCE,
                    ABIT.POCI_NOMINAL_AMOUNT_ADJ_EUR_OFFBALANCE                                             as ABIT_POCI_NOMINAL_AMOUNT_ADJ_EUR_OFFBALANCE,
                    ABIT.POCI_REGEN_OC_OFFBALANCE                                                           as ABIT_POCI_REGEN_OC_OFFBALANCE,
                    ABIT.POCI_REGEN_EUR_OFFBALANCE                                                          as ABIT_POCI_REGEN_EUR_OFFBALANCE,
                    ABIT.POCI_LIQUIDATION_OC_OFFBALANCE                                                     as ABIT_POCI_LIQUIDATION_OC_OFFBALANCE,
                    ABIT.POCI_LIQUIDATION_EUR_OFFBALANCE                                                    as ABIT_POCI_LIQUIDATION_EUR_OFFBALANCE,
                    ABIT.POCI_CONSUMPTION_OC_OFFBALANCE                                                     as ABIT_POCI_CONSUMPTION_OC_OFFBALANCE,
                    ABIT.POCI_CONSUMPTION_EUR_OFFBALANCE                                                    as ABIT_POCI_CONSUMPTION_EUR_OFFBALANCE,
                    CPC.ULTIMOMONAT                                                                         as CPC_ULTIMOMONAT,
                    CPC.KONTONUMMER                                                                         as CPC_KONTONUMMER,
                    CPC.VORGANGSNUMMER                                                                      as CPC_VORGANGSNUMMER,
                    CPC.CURRENCY_OC                                                                         as CPC_CURRENCY_OC,
                    CPC.CURRENCY                                                                            as CPC_CURRENCY,
                    CPC.DURCHSCHN_INANSPR                                                                   as CPC_DURCHSCHN_INANSPR,
                    CPC.SCS_KOSTEN                                                                          as CPC_SCS_KOSTEN,
                    CPC.PROFC_KOSTEN                                                                        as CPC_PROFC_KOSTEN,
                    CPC.OH_KOSTEN                                                                           as CPC_OH_KOSTEN,
                    CPC.KUNDENMARGE_NETTO                                                                   as CPC_KUNDENMARGE_NETTO,
                    CPC.KREDITPROVISION                                                                     as CPC_KREDITPROVISION,
                    CPC.UTILITY_FEE                                                                         as CPC_UTILITY_FEE,
                    CPC.EINMALZAHLUNG                                                                       as CPC_EINMALZAHLUNG,
                    CPC.CPC_DB_3_V_RISIKO                                                                   as CPC_DB_3_V_RISIKO,
                    CPC.CPC_DB_3_N_RISIKO                                                                   as CPC_DB_3_N_RISIKO,
                    CPC.EK_KOSTEN                                                                           as CPC_EK_KOSTEN,
                    CPC.RISIKOPRAEMIE                                                                       as CPC_RISIKOPRAEMIE,
                    CPC.CPC_RWA_PRODUKTIVITAET                                                              as CPC_RWA_PRODUKTIVITAET,
                    CPC.RORAC                                                                               as CPC_RORAC,
                    DVRS.DT_INTRNL_RTNG                                                                     as SPOT_DT_INTRNL_RTNG,
                    DVRS.INTRNL_RTNG                                                                        as SPOT_INTRNL_RTNG,
                    DVRS.LGD_REGULATORISCH                                                                  as SAP_P80extern_LGD_REGULATORISCH,
                    DVRS.EAD_REGULATORISCH                                                                  as SAP_P80extern_EAD_REGULATORISCH,
                    DVRS.CURRENCY_OC                                                                        as SAP_P80extern_CURRENCY_OC,
                    DVRS.CURRENCY                                                                           as SAP_P80extern_CURRENCY,
                    DVRS.PD_CRR_RD                                                                          as SPOT_PD_CRR_RD,
                    DVRS.FBE_STUFE                                                                          as SPOT_FBE_STUFE,
                    DVRS.CRI114_STUNDUNGS_U_NEUVERHANDLUNGSSTATUS                                           as ANACREDIT_CRI114_STUNDUNGS_U_NEUVERHANDLUNGSSTATUS,
                    CMS.ALLOCATED_COLLATERAL_VALUE                                                          as CMS_ALLOCATED_COLLATERAL_VALUE,
                    CMS.ALLOCATED_COLLATERAL_VALUE_CURRENCY                                                 as CMS_ALLOCATED_COLLATERAL_VALUE_CURRENCY,
                    CMS.ALLOCATED_COLLATERAL_VALUE_CURRENCY_OC                                              as CMS_ALLOCATED_COLLATERAL_VALUE_CURRENCY_OC,
                    KNZL.PERSONEN_NR                                                                        as IWHS_KENNZAHLEN_PERSONEN_NR,
                    KNZL.GSPR_VGNG_NR                                                                       as IWHS_KENNZAHLEN_GSPR_VGNG_NR,
                    KNZL.LVTV                                                                               as IWHS_KENNZAHLEN_LVTV,
                    KNZL.LSTI                                                                               as IWHS_KENNZAHLEN_LSTI,
                    KNZL.LTI                                                                                as IWHS_KENNZAHLEN_LTI,
                    KNZL.DSCR                                                                               as IWHS_KENNZAHLEN_DSCR,
                    KNZL.PERS_EIGN_SCHD_DNST                                                                as IWHS_KENNZAHLEN_PERS_EIGN_SCHD_DNST,
                    KNZL.PERS_FRMD_SCHD_DNST                                                                as IWHS_KENNZAHLEN_PERS_FRMD_SCHD_DNST,
                    KNZL.FINANZIERUNGSBAUSTEIN                                                              as IWHS_KENNZAHLEN_FINANZIERUNGSBAUSTEIN,
                    KNZL.VORHABENART                                                                        as IWHS_KENNZAHLEN_VORHABENART
    from PWC_FAC PWC
             left join LIQ_FAC LIQ on not LIQ.IS_LUX and PWC.FACILITY_ID = LIQ.FACILITY_ID
             left join LIQ_FAC LIQ_LUX on LIQ_LUX.IS_LUX and PWC.FACILITY_ID = LIQ_LUX.FACILITY_ID_LUX
             left join IWHS_AZ6_FAC AZ6 on PWC.FACILITY_ID = AZ6.FACILITY_ID
             left join FSD_FAC FSD on PWC.FACILITY_ID = FSD.FACILITY_ID
             left join ZEB_FAC ZEB on PWC.FACILITY_ID = ZEB.FACILITY_ID
             left join ABIT_FAC ABIT on PWC.FACILITY_ID = ABIT.FACILITY_ID
             left join CPC_FAC CPC on PWC.FACILITY_ID = CPC.FACILITY_ID
             left join DIVERS_FAC DVRS on PWC.FACILITY_ID = DVRS.FACILITY_ID
             left join CMS_FAC CMS on PWC.FACILITY_ID = CMS.FACILITY_ID
             left join IWHS_KNZL_FAC KNZL on PWC.FACILITY_ID = KNZL.FACILITY_ID
),
-- Gefiltert nach noetigen Datenfeldern + nullable
FINAL_FILTERED as (
    select
        -- Defaults
        CUT_OFF_DATE,
        -- Columns
        NULLIF(FACILITY_ID, null)                                                as FACILITY_ID,
        NULLIF(LIQ_FACILITY_ID, null)                                            as LIQ_FACILITY_ID,
        NULLIF(LIQ_PARENTFACILITY, null)                                         as LIQ_PARENTFACILITY,
        NULLIF(LIQ_DEAL_ID, null)                                                as LIQ_DEAL_ID,
        NULLIF(LIQ_KREDITNEHMER_GP_NR, null)                                     as LIQ_KREDITNEHMER_GP_NR,
        NULLIF(LIQ_KREDITNEHMER_GP_NAME, null)                                   as LIQ_KREDITNEHMER_GP_NAME,
        NULLIF(LIQ_STATUS, null)                                                 as LIQ_STATUS,
        NULLIF(LIQ_CURRENCY, null)                                               as LIQ_CURRENCY,
        NULLIF(LIQ_CURRENCY_OC, null)                                            as LIQ_CURRENCY_OC,
        NULLIF(LIQ_AUSZAHLUNG_BEGINN_DATUM, null)                                as LIQ_AUSZAHLUNG_BEGINN_DATUM,
        NULLIF(LIQ_PRODUKT_SCHLUESSEL, null)                                     as LIQ_PRODUKT_SCHLUESSEL,
        NULLIF(LIQ_PRODUKT_SCHLUESSEL_BESCHREIBUNG, null)                        as LIQ_PRODUKT_SCHLUESSEL_BESCHREIBUNG,
        NULLIF(LIQ_IOPC_ID, null)                                                as LIQ_IOPC_ID,
        NULLIF(LIQ_FINANZIERUNG_VORHABEN, null)                                  as LIQ_FINANZIERUNG_VORHABEN,
        NULLIF(LIQ_FINANZIERUNG_VORHABEN_BESCHREIBUNG, null)                     as LIQ_FINANZIERUNG_VORHABEN_BESCHREIBUNG,
        NULLIF(LIQ_AUSZAHLUNGSVERPFLICHTUNG_BTR, null)                           as LIQ_AUSZAHLUNGSVERPFLICHTUNG_BTR,
        NULLIF(LIQ_KREDITZUSAGE_ENDE_DATUM, null)                                as LIQ_KREDITZUSAGE_ENDE_DATUM,
        NULLIF(LIQ_VERZUG_BEGINN_DATUM, null)                                    as LIQ_VERZUG_BEGINN_DATUM,
        NULLIF(LIQ_SUMME_VERZUGSTAGE, null)                                      as LIQ_SUMME_VERZUGSTAGE,
        NULLIF(LIQ_VERZUG_BTR_SUM, null)                                         as LIQ_VERZUG_BTR_SUM,
        NULLIF(LIQ_RUECKST_GEBUEHR_BTR, null)                                    as LIQ_RUECKST_GEBUEHR_BTR,
        NULLIF(LIQ_RUECKST_TILGUNG_BTR, null)                                    as LIQ_RUECKST_TILGUNG_BTR,
        NULLIF(LIQ_RUECKST_ZINSEN_BTR, null)                                     as LIQ_RUECKST_ZINSEN_BTR,
        NULLIF(LIQ_EINSTANDSATZ_PRZ, null)                                       as LIQ_EINSTANDSATZ_PRZ,
        NULLIF(LIQ_STUNDUNG_SALDO, null)                                         as LIQ_STUNDUNG_SALDO,
        NULLIF(LIQ_RESTKAPITAL_BTR_BRUTTO, null)                                 as LIQ_RESTKAPITAL_BTR_BRUTTO,
        NULLIF(LIQ_RESTKAPITAL_BTR_NETTO, null)                                  as LIQ_RESTKAPITAL_BTR_NETTO,
        NULLIF(LIQ_RESTKAPITAL_BTR_KONSORTEN, null)                              as LIQ_RESTKAPITAL_BTR_KONSORTEN,
        NULLIF(LIQ_URSPRUNGSKAPITAL_BTR_BRUTTO, null)                            as LIQ_URSPRUNGSKAPITAL_BTR_BRUTTO,
        NULLIF(LIQ_URSPRUNGSKAPITAL_BTR_NETTO, null)                             as LIQ_URSPRUNGSKAPITAL_BTR_NETTO,
        NULLIF(LIQ_URSPRUNGSKAPITAL_BTR_KONSORTEN, null)                         as LIQ_URSPRUNGSKAPITAL_BTR_KONSORTEN,
        NULLIF(LIQ_TILGUNG_ART_MM, null)                                         as LIQ_TILGUNG_ART_MM,
        NULLIF(LIQ_TILGUNG_ENDE_DATUM, null)                                     as LIQ_TILGUNG_ENDE_DATUM,
        NULLIF(LIQ_ZINS_TYP, null)                                               as LIQ_ZINS_TYP,
        NULLIF(LIQ_SOLL_ZINSSATZ, null)                                          as LIQ_SOLL_ZINSSATZ,
        NULLIF(LIQ_ZINSBINDUNG_ENDE_DATUM, null)                                 as LIQ_ZINSBINDUNG_ENDE_DATUM,
        NULLIF(LIQ_VERTRAG_ENDE_DATUM, null)                                     as LIQ_VERTRAG_ENDE_DATUM,
        NULLIF(AZ6_CURRENCY, null)                                               as AZ6_CURRENCY,
        NULLIF(AZ6_CURRENCY_OC, null)                                            as AZ6_CURRENCY_OC,
        NULLIF(AZ6_DARLEHENSART, null)                                           as AZ6_DARLEHENSART,
        NULLIF(AZ6_BEFRISTUNG_ZUSAGE, null)                                      as AZ6_BEFRISTUNG_ZUSAGE,
        NULLIF(AZ6_PRODUKTSCHLUESSEL, null)                                      as AZ6_PRODUKTSCHLUESSEL,
        NULLIF(AZ6_VERWENDUNGSZWECK, null)                                       as AZ6_VERWENDUNGSZWECK,
        NULLIF(AZ6_SOLLZINSSATZ, null)                                           as AZ6_SOLLZINSSATZ,
        NULLIF(AZ6_AKTUELLE_ENDE_DATUM, null)                                    as AZ6_AKTUELLE_ENDE_DATUM,
        NULLIF(AZ6_DATUM_ERSTE_VALUTIERUNG, null)                                as AZ6_DATUM_ERSTE_VALUTIERUNG,
        NULLIF(AZ6_STUNDUNGSSALDO, null)                                         as AZ6_STUNDUNGSSALDO,
        NULLIF(AZ6_BETRAG, null)                                                 as AZ6_BETRAG,
        NULLIF(AZ6_TILGUNGSFORM_DARLEHENSART, null)                              as AZ6_TILGUNGSFORM_DARLEHENSART,
        NULLIF(AZ6_KZ_MITHAFTUNG_MITTELGEBER, null)                              as AZ6_KZ_MITHAFTUNG_MITTELGEBER,
        NULLIF(AZ6_RISIKO_FREMD_KI, null)                                        as AZ6_RISIKO_FREMD_KI,
        NULLIF(AZ6_KONTOSALDO, null)                                             as AZ6_KONTOSALDO,
        NULLIF(AZ6_ENTGELTVERZUG, null)                                          as AZ6_ENTGELTVERZUG,
        NULLIF(AZ6_GESAMTVERZUG, null)                                           as AZ6_GESAMTVERZUG,
        NULLIF(AZ6_UNVERZINSLICHER_VERZUG, null)                                 as AZ6_UNVERZINSLICHER_VERZUG,
        NULLIF(AZ6_VERZINSLICHER_VERZUG_BIS_31_DEZ, null)                        as AZ6_VERZINSLICHER_VERZUG_BIS_31_DEZ,
        NULLIF(AZ6_SONDERTILGUNG_MAXIMALBETRAG, null)                            as AZ6_SONDERTILGUNG_MAXIMALBETRAG,
        NULLIF(AZ6_SONDERTILGUNG_MINDESTBETRAG, null)                            as AZ6_SONDERTILGUNG_MINDESTBETRAG,
        NULLIF(AZ6_LEISTUNGSSTOERUNGSBETRAG_SONDERTILGUNG, null)                 as AZ6_LEISTUNGSSTOERUNGSBETRAG_SONDERTILGUNG,
        NULLIF(AZ6_NICHT_PLANMAESSIGE_AENDERUNG_VERZINSUNGSSALDO, null)          as AZ6_NICHT_PLANMAESSIGE_AENDERUNG_VERZINSUNGSSALDO,
        NULLIF(AZ6_LEISTUNGSSTOERUNGSBETRAG_SONDERTILGUNG_WG_PROLONGATION, null) as AZ6_LEISTUNGSSTOERUNGSBETRAG_SONDERTILGUNG_WG_PROLONGATION,
        NULLIF(AZ6_OWNSYNDICATEQUOTA, null)                                      as AZ6_OWNSYNDICATEQUOTA,
        NULLIF(AZ6_LOANSTATE, null)                                              as AZ6_LOANSTATE,
        NULLIF(FINSTABDEV_MELDESTICHTAG_NEUGESCHAEFT, null)                      as FINSTABDEV_MELDESTICHTAG_NEUGESCHAEFT,
        NULLIF(FINSTABDEV_OBJECT_ID, null)                                       as FINSTABDEV_OBJECT_ID,
        NULLIF(FINSTABDEV_DSTI, null)                                            as FINSTABDEV_DSTI,
        NULLIF(FINSTABDEV_DTI, null)                                             as FINSTABDEV_DTI,
        NULLIF(FINSTABDEV_VERHAELTNIS_DARLEHENSVOLUMEN_BELEIHUNGSWERT, null)     as FINSTABDEV_VERHAELTNIS_DARLEHENSVOLUMEN_BELEIHUNGSWERT,
        NULLIF(FINSTABDEV_LTV, null)                                             as FINSTABDEV_LTV,
        NULLIF(FINSTABDEV_RELEVANZ_WIFSTA, null)                                 as FINSTABDEV_RELEVANZ_WIFSTA,
        NULLIF(ZEB_CURRENCY, null)                                               as ZEB_CURRENCY,
        NULLIF(ZEB_CURRENCY_OC, null)                                            as ZEB_CURRENCY_OC,
        NULLIF(ZEB_R_LOAN_LOSS_PROVISION_AMT_ONBALANCE, null)                    as ZEB_R_LOAN_LOSS_PROVISION_AMT_ONBALANCE,
        NULLIF(ZEB_R_LOAN_LOSS_PROVISION_PREV_AMT_ONBALANCE, null)               as ZEB_R_LOAN_LOSS_PROVISION_PREV_AMT_ONBALANCE,
        NULLIF(ZEB_R_STAGE_LLP_CALCULATED_ID_ONBALANCE, null)                    as ZEB_R_STAGE_LLP_CALCULATED_ID_ONBALANCE,
        NULLIF(ZEB_R_STAGE_LLP_REASON_DESC_ONBALANCE, null)                      as ZEB_R_STAGE_LLP_REASON_DESC_ONBALANCE,
        NULLIF(ZEB_R_CREDIT_CONVERSION_FACTOR_RATE_ONBALANCE, null)              as ZEB_R_CREDIT_CONVERSION_FACTOR_RATE_ONBALANCE,
        NULLIF(ZEB_R_EAD_TOTAL_AMT_ONBALANCE, null)                              as ZEB_R_EAD_TOTAL_AMT_ONBALANCE,
        NULLIF(ZEB_R_EXP_LIFETIME_LOSS_AMT_ONBALANCE, null)                      as ZEB_R_EXP_LIFETIME_LOSS_AMT_ONBALANCE,
        NULLIF(ZEB_R_EXP_LOSS_AMT_ONBALANCE, null)                               as ZEB_R_EXP_LOSS_AMT_ONBALANCE,
        NULLIF(ZEB_R_LIFETIME_PROB_DEF_RATE_ONBALANCE, null)                     as ZEB_R_LIFETIME_PROB_DEF_RATE_ONBALANCE,
        NULLIF(ZEB_R_LOSS_GIVEN_DEFAULT_RATE_ONBALANCE, null)                    as ZEB_R_LOSS_GIVEN_DEFAULT_RATE_ONBALANCE,
        NULLIF(ZEB_R_ONE_YEAR_PROB_OF_DEFAULT_RATE_ONBALANCE, null)              as ZEB_R_ONE_YEAR_PROB_OF_DEFAULT_RATE_ONBALANCE,
        NULLIF(ZEB_E_DIRECT_WRITE_OFF_AMT_ONBALANCE, null)                       as ZEB_E_DIRECT_WRITE_OFF_AMT_ONBALANCE,
        NULLIF(ZEB_R_IFRS_EFF_INTEREST_RATE_ONBALANCE, null)                     as ZEB_R_IFRS_EFF_INTEREST_RATE_ONBALANCE,
        NULLIF(ZEB_R_LOAN_LOSS_PROVISION_AMT_OFFBALANCE, null)                   as ZEB_R_LOAN_LOSS_PROVISION_AMT_OFFBALANCE,
        NULLIF(ZEB_R_LOAN_LOSS_PROVISION_PREV_AMT_OFFBALANCE, null)              as ZEB_R_LOAN_LOSS_PROVISION_PREV_AMT_OFFBALANCE,
        NULLIF(ZEB_R_STAGE_LLP_CALCULATED_ID_OFFBALANCE, null)                   as ZEB_R_STAGE_LLP_CALCULATED_ID_OFFBALANCE,
        NULLIF(ZEB_R_STAGE_LLP_REASON_DESC_OFFBALANCE, null)                     as ZEB_R_STAGE_LLP_REASON_DESC_OFFBALANCE,
        NULLIF(ZEB_R_CREDIT_CONVERSION_FACTOR_RATE_OFFBALANCE, null)             as ZEB_R_CREDIT_CONVERSION_FACTOR_RATE_OFFBALANCE,
        NULLIF(ZEB_R_EAD_TOTAL_AMT_OFFBALANCE, null)                             as ZEB_R_EAD_TOTAL_AMT_OFFBALANCE,
        NULLIF(ZEB_R_EXP_LIFETIME_LOSS_AMT_OFFBALANCE, null)                     as ZEB_R_EXP_LIFETIME_LOSS_AMT_OFFBALANCE,
        NULLIF(ZEB_R_EXP_LOSS_AMT_OFFBALANCE, null)                              as ZEB_R_EXP_LOSS_AMT_OFFBALANCE,
        NULLIF(ZEB_R_LIFETIME_PROB_DEF_RATE_OFFBALANCE, null)                    as ZEB_R_LIFETIME_PROB_DEF_RATE_OFFBALANCE,
        NULLIF(ZEB_R_LOSS_GIVEN_DEFAULT_RATE_OFFBALANCE, null)                   as ZEB_R_LOSS_GIVEN_DEFAULT_RATE_OFFBALANCE,
        NULLIF(ZEB_R_ONE_YEAR_PROB_OF_DEFAULT_RATE_OFFBALANCE, null)             as ZEB_R_ONE_YEAR_PROB_OF_DEFAULT_RATE_OFFBALANCE,
        NULLIF(ZEB_E_DIRECT_WRITE_OFF_AMT_OFFBALANCE, null)                      as ZEB_E_DIRECT_WRITE_OFF_AMT_OFFBALANCE,
        NULLIF(ZEB_R_IFRS_EFF_INTEREST_RATE_OFFBALANCE, null)                    as ZEB_R_IFRS_EFF_INTEREST_RATE_OFFBALANCE,
        NULLIF(ABIT_CURRENCY, null)                                              as ABIT_CURRENCY,
        NULLIF(ABIT_CURRENCY_OC, null)                                           as ABIT_CURRENCY_OC,
        NULLIF(ABIT_EXCHANGE_RATE_EUR2OC, null)                                  as ABIT_EXCHANGE_RATE_EUR2OC,
        NULLIF(ABIT_IFRSMETHOD, null)                                            as ABIT_IFRSMETHOD,
        NULLIF(ABIT_IFRSMETHOD_PREV_YEAR, null)                                  as ABIT_IFRSMETHOD_PREV_YEAR,
        NULLIF(ABIT_POCI_ACCOUNT, null)                                          as ABIT_POCI_ACCOUNT,
        NULLIF(ABIT_AMOUNT_OC_ONBALANCE, null)                                   as ABIT_AMOUNT_OC_ONBALANCE,
        NULLIF(ABIT_AMOUNT_EUR_ONBALANCE, null)                                  as ABIT_AMOUNT_EUR_ONBALANCE,
        NULLIF(ABIT_AMOUNT_PREV_YEAR_OC_ONBALANCE, null)                         as ABIT_AMOUNT_PREV_YEAR_OC_ONBALANCE,
        NULLIF(ABIT_AMOUNT_PREV_YEAR_EUR_ONBALANCE, null)                        as ABIT_AMOUNT_PREV_YEAR_EUR_ONBALANCE,
        NULLIF(ABIT_DATE_CREATED_ONBALANCE, null)                                as ABIT_DATE_CREATED_ONBALANCE,
        NULLIF(ABIT_SUPPLY_FULL_YTD_OC_ONBALANCE, null)                          as ABIT_SUPPLY_FULL_YTD_OC_ONBALANCE,
        NULLIF(ABIT_SUPPLY_FULL_YTD_EUR_ONBALANCE, null)                         as ABIT_SUPPLY_FULL_YTD_EUR_ONBALANCE,
        NULLIF(ABIT_LIQUIDATION_FULL_YTD_OC_ONBALANCE, null)                     as ABIT_LIQUIDATION_FULL_YTD_OC_ONBALANCE,
        NULLIF(ABIT_LIQUIDATION_FULL_YTD_EUR_ONBALANCE, null)                    as ABIT_LIQUIDATION_FULL_YTD_EUR_ONBALANCE,
        NULLIF(ABIT_LIQUIDATION_BAL_YTD_OC_ONBALANCE, null)                      as ABIT_LIQUIDATION_BAL_YTD_OC_ONBALANCE,
        NULLIF(ABIT_LIQUIDATION_BAL_YTD_EUR_ONBALANCE, null)                     as ABIT_LIQUIDATION_BAL_YTD_EUR_ONBALANCE,
        NULLIF(ABIT_DEBIT_YTD_OC_ONBALANCE, null)                                as ABIT_DEBIT_YTD_OC_ONBALANCE,
        NULLIF(ABIT_DEBIT_YTD_EUR_ONBALANCE, null)                               as ABIT_DEBIT_YTD_EUR_ONBALANCE,
        NULLIF(ABIT_UNWINDING_YTD_OC_ONBALANCE, null)                            as ABIT_UNWINDING_YTD_OC_ONBALANCE,
        NULLIF(ABIT_UNWINDING_YTD_EUR_ONBALANCE, null)                           as ABIT_UNWINDING_YTD_EUR_ONBALANCE,
        NULLIF(ABIT_WRITE_OFF_FULL_GUV_YTD_OC_ONBALANCE, null)                   as ABIT_WRITE_OFF_FULL_GUV_YTD_OC_ONBALANCE,
        NULLIF(ABIT_WRITE_OFF_FULL_GUV_YTD_EUR_ONBALANCE, null)                  as ABIT_WRITE_OFF_FULL_GUV_YTD_EUR_ONBALANCE,
        NULLIF(ABIT_WRITE_OFF_FULL_DATE_ONBALANCE, null)                         as ABIT_WRITE_OFF_FULL_DATE_ONBALANCE,
        NULLIF(ABIT_POCI_NOMINAL_AMOUNT_ORIG_OC_ONBALANCE, null)                 as ABIT_POCI_NOMINAL_AMOUNT_ORIG_OC_ONBALANCE,
        NULLIF(ABIT_POCI_NOMINAL_AMOUNT_ORIG_EUR_ONBALANCE, null)                as ABIT_POCI_NOMINAL_AMOUNT_ORIG_EUR_ONBALANCE,
        NULLIF(ABIT_POCI_NOMINAL_AMOUNT_ADJ_OC_ONBALANCE, null)                  as ABIT_POCI_NOMINAL_AMOUNT_ADJ_OC_ONBALANCE,
        NULLIF(ABIT_POCI_NOMINAL_AMOUNT_ADJ_EUR_ONBALANCE, null)                 as ABIT_POCI_NOMINAL_AMOUNT_ADJ_EUR_ONBALANCE,
        NULLIF(ABIT_POCI_REGEN_OC_ONBALANCE, null)                               as ABIT_POCI_REGEN_OC_ONBALANCE,
        NULLIF(ABIT_POCI_REGEN_EUR_ONBALANCE, null)                              as ABIT_POCI_REGEN_EUR_ONBALANCE,
        NULLIF(ABIT_POCI_LIQUIDATION_OC_ONBALANCE, null)                         as ABIT_POCI_LIQUIDATION_OC_ONBALANCE,
        NULLIF(ABIT_POCI_LIQUIDATION_EUR_ONBALANCE, null)                        as ABIT_POCI_LIQUIDATION_EUR_ONBALANCE,
        NULLIF(ABIT_POCI_CONSUMPTION_OC_ONBALANCE, null)                         as ABIT_POCI_CONSUMPTION_OC_ONBALANCE,
        NULLIF(ABIT_POCI_CONSUMPTION_EUR_ONBALANCE, null)                        as ABIT_POCI_CONSUMPTION_EUR_ONBALANCE,
        NULLIF(ABIT_AMOUNT_OC_OFFBALANCE, null)                                  as ABIT_AMOUNT_OC_OFFBALANCE,
        NULLIF(ABIT_AMOUNT_EUR_OFFBALANCE, null)                                 as ABIT_AMOUNT_EUR_OFFBALANCE,
        NULLIF(ABIT_AMOUNT_PREV_YEAR_OC_OFFBALANCE, null)                        as ABIT_AMOUNT_PREV_YEAR_OC_OFFBALANCE,
        NULLIF(ABIT_AMOUNT_PREV_YEAR_EUR_OFFBALANCE, null)                       as ABIT_AMOUNT_PREV_YEAR_EUR_OFFBALANCE,
        NULLIF(ABIT_DATE_CREATED_OFFBALANCE, null)                               as ABIT_DATE_CREATED_OFFBALANCE,
        NULLIF(ABIT_SUPPLY_FULL_YTD_OC_OFFBALANCE, null)                         as ABIT_SUPPLY_FULL_YTD_OC_OFFBALANCE,
        NULLIF(ABIT_SUPPLY_FULL_YTD_EUR_OFFBALANCE, null)                        as ABIT_SUPPLY_FULL_YTD_EUR_OFFBALANCE,
        NULLIF(ABIT_LIQUIDATION_FULL_YTD_OC_OFFBALANCE, null)                    as ABIT_LIQUIDATION_FULL_YTD_OC_OFFBALANCE,
        NULLIF(ABIT_LIQUIDATION_FULL_YTD_EUR_OFFBALANCE, null)                   as ABIT_LIQUIDATION_FULL_YTD_EUR_OFFBALANCE,
        NULLIF(ABIT_LIQUIDATION_BAL_YTD_OC_OFFBALANCE, null)                     as ABIT_LIQUIDATION_BAL_YTD_OC_OFFBALANCE,
        NULLIF(ABIT_LIQUIDATION_BAL_YTD_EUR_OFFBALANCE, null)                    as ABIT_LIQUIDATION_BAL_YTD_EUR_OFFBALANCE,
        NULLIF(ABIT_DEBIT_YTD_OC_OFFBALANCE, null)                               as ABIT_DEBIT_YTD_OC_OFFBALANCE,
        NULLIF(ABIT_DEBIT_YTD_EUR_OFFBALANCE, null)                              as ABIT_DEBIT_YTD_EUR_OFFBALANCE,
        NULLIF(ABIT_UNWINDING_YTD_OC_OFFBALANCE, null)                           as ABIT_UNWINDING_YTD_OC_OFFBALANCE,
        NULLIF(ABIT_UNWINDING_YTD_EUR_OFFBALANCE, null)                          as ABIT_UNWINDING_YTD_EUR_OFFBALANCE,
        NULLIF(ABIT_WRITE_OFF_FULL_GUV_YTD_OC_OFFBALANCE, null)                  as ABIT_WRITE_OFF_FULL_GUV_YTD_OC_OFFBALANCE,
        NULLIF(ABIT_WRITE_OFF_FULL_GUV_YTD_EUR_OFFBALANCE, null)                 as ABIT_WRITE_OFF_FULL_GUV_YTD_EUR_OFFBALANCE,
        NULLIF(ABIT_WRITE_OFF_FULL_DATE_OFFBALANCE, null)                        as ABIT_WRITE_OFF_FULL_DATE_OFFBALANCE,
        NULLIF(ABIT_POCI_NOMINAL_AMOUNT_ORIG_OC_OFFBALANCE, null)                as ABIT_POCI_NOMINAL_AMOUNT_ORIG_OC_OFFBALANCE,
        NULLIF(ABIT_POCI_NOMINAL_AMOUNT_ORIG_EUR_OFFBALANCE, null)               as ABIT_POCI_NOMINAL_AMOUNT_ORIG_EUR_OFFBALANCE,
        NULLIF(ABIT_POCI_NOMINAL_AMOUNT_ADJ_OC_OFFBALANCE, null)                 as ABIT_POCI_NOMINAL_AMOUNT_ADJ_OC_OFFBALANCE,
        NULLIF(ABIT_POCI_NOMINAL_AMOUNT_ADJ_EUR_OFFBALANCE, null)                as ABIT_POCI_NOMINAL_AMOUNT_ADJ_EUR_OFFBALANCE,
        NULLIF(ABIT_POCI_REGEN_OC_OFFBALANCE, null)                              as ABIT_POCI_REGEN_OC_OFFBALANCE,
        NULLIF(ABIT_POCI_REGEN_EUR_OFFBALANCE, null)                             as ABIT_POCI_REGEN_EUR_OFFBALANCE,
        NULLIF(ABIT_POCI_LIQUIDATION_OC_OFFBALANCE, null)                        as ABIT_POCI_LIQUIDATION_OC_OFFBALANCE,
        NULLIF(ABIT_POCI_LIQUIDATION_EUR_OFFBALANCE, null)                       as ABIT_POCI_LIQUIDATION_EUR_OFFBALANCE,
        NULLIF(ABIT_POCI_CONSUMPTION_OC_OFFBALANCE, null)                        as ABIT_POCI_CONSUMPTION_OC_OFFBALANCE,
        NULLIF(ABIT_POCI_CONSUMPTION_EUR_OFFBALANCE, null)                       as ABIT_POCI_CONSUMPTION_EUR_OFFBALANCE,
        NULLIF(CPC_ULTIMOMONAT, null)                                            as CPC_ULTIMOMONAT,
        NULLIF(CPC_KONTONUMMER, null)                                            as CPC_KONTONUMMER,
        NULLIF(CPC_VORGANGSNUMMER, null)                                         as CPC_VORGANGSNUMMER,
        NULLIF(CPC_CURRENCY_OC, null)                                            as CPC_CURRENCY_OC,
        NULLIF(CPC_CURRENCY, null)                                               as CPC_CURRENCY,
        NULLIF(CPC_DURCHSCHN_INANSPR, null)                                      as CPC_DURCHSCHN_INANSPR,
        NULLIF(CPC_SCS_KOSTEN, null)                                             as CPC_SCS_KOSTEN,
        NULLIF(CPC_PROFC_KOSTEN, null)                                           as CPC_PROFC_KOSTEN,
        NULLIF(CPC_OH_KOSTEN, null)                                              as CPC_OH_KOSTEN,
        NULLIF(CPC_KUNDENMARGE_NETTO, null)                                      as CPC_KUNDENMARGE_NETTO,
        NULLIF(CPC_KREDITPROVISION, null)                                        as CPC_KREDITPROVISION,
        NULLIF(CPC_UTILITY_FEE, null)                                            as CPC_UTILITY_FEE,
        NULLIF(CPC_EINMALZAHLUNG, null)                                          as CPC_EINMALZAHLUNG,
        NULLIF(CPC_DB_3_V_RISIKO, null)                                          as CPC_DB_3_V_RISIKO,
        NULLIF(CPC_DB_3_N_RISIKO, null)                                          as CPC_DB_3_N_RISIKO,
        NULLIF(CPC_EK_KOSTEN, null)                                              as CPC_EK_KOSTEN,
        NULLIF(CPC_RISIKOPRAEMIE, null)                                          as CPC_RISIKOPRAEMIE,
        NULLIF(CPC_RWA_PRODUKTIVITAET, null)                                     as CPC_RWA_PRODUKTIVITAET,
        NULLIF(CPC_RORAC, null)                                                  as CPC_RORAC,
        NULLIF(SPOT_DT_INTRNL_RTNG, null)                                        as SPOT_DT_INTRNL_RTNG,
        NULLIF(SPOT_INTRNL_RTNG, null)                                           as SPOT_INTRNL_RTNG,
        NULLIF(SAP_P80EXTERN_LGD_REGULATORISCH, null)                            as SAP_P80EXTERN_LGD_REGULATORISCH,
        NULLIF(SAP_P80EXTERN_EAD_REGULATORISCH, null)                            as SAP_P80EXTERN_EAD_REGULATORISCH,
        NULLIF(SAP_P80EXTERN_CURRENCY_OC, null)                                  as SAP_P80EXTERN_CURRENCY_OC,
        NULLIF(SAP_P80EXTERN_CURRENCY, null)                                     as SAP_P80EXTERN_CURRENCY,
        NULLIF(SPOT_PD_CRR_RD, null)                                             as SPOT_PD_CRR_RD,
        NULLIF(SPOT_FBE_STUFE, null)                                             as SPOT_FBE_STUFE,
        NULLIF(ANACREDIT_CRI114_STUNDUNGS_U_NEUVERHANDLUNGSSTATUS, null)         as ANACREDIT_CRI114_STUNDUNGS_U_NEUVERHANDLUNGSSTATUS,
        NULLIF(CMS_ALLOCATED_COLLATERAL_VALUE, null)                             as CMS_ALLOCATED_COLLATERAL_VALUE,
        NULLIF(CMS_ALLOCATED_COLLATERAL_VALUE_CURRENCY, null)                    as CMS_ALLOCATED_COLLATERAL_VALUE_CURRENCY,
        NULLIF(CMS_ALLOCATED_COLLATERAL_VALUE_CURRENCY_OC, null)                 as CMS_ALLOCATED_COLLATERAL_VALUE_CURRENCY_OC,
        NULLIF(IWHS_KENNZAHLEN_PERSONEN_NR, null)                                as IWHS_KENNZAHLEN_PERSONEN_NR,
        NULLIF(IWHS_KENNZAHLEN_GSPR_VGNG_NR, null)                               as IWHS_KENNZAHLEN_GSPR_VGNG_NR,
        NULLIF(IWHS_KENNZAHLEN_LVTV, null)                                       as IWHS_KENNZAHLEN_LVTV,
        NULLIF(IWHS_KENNZAHLEN_LSTI, null)                                       as IWHS_KENNZAHLEN_LSTI,
        NULLIF(IWHS_KENNZAHLEN_LTI, null)                                        as IWHS_KENNZAHLEN_LTI,
        NULLIF(IWHS_KENNZAHLEN_DSCR, null)                                       as IWHS_KENNZAHLEN_DSCR,
        NULLIF(IWHS_KENNZAHLEN_PERS_EIGN_SCHD_DNST, null)                        as IWHS_KENNZAHLEN_PERS_EIGN_SCHD_DNST,
        NULLIF(IWHS_KENNZAHLEN_PERS_FRMD_SCHD_DNST, null)                        as IWHS_KENNZAHLEN_PERS_FRMD_SCHD_DNST,
        NULLIF(IWHS_KENNZAHLEN_FINANZIERUNGSBAUSTEIN, null)                      as IWHS_KENNZAHLEN_FINANZIERUNGSBAUSTEIN,
        NULLIF(IWHS_KENNZAHLEN_VORHABENART, null)                                as IWHS_KENNZAHLEN_VORHABENART,
        -- Defaults
        CURRENT_USER                                                             as USER,
        CURRENT_TIMESTAMP                                                        as TIMESTAMP_LOAD
    from FINAL
)
select *
from FINAL_FILTERED;

-- CI START FOR ALL TAPES

-- Current-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_FACILITY_EBA_CURRENT');
create table AMC.TABLE_FACILITY_EBA_CURRENT like CALC.VIEW_FACILITY_EBA distribute by hash (FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_EBA_CURRENT_FACILITY_ID on AMC.TABLE_FACILITY_EBA_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_FACILITY_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- Archiv-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_FACILITY_EBA_ARCHIVE');
create table AMC.TABLE_FACILITY_EBA_ARCHIVE like CALC.VIEW_FACILITY_EBA distribute by hash (FACILITY_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_EBA_ARCHIVE_FACILITY_ID on AMC.TABLE_FACILITY_EBA_ARCHIVE (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_FACILITY_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_FACILITY_EBA_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_FACILITY_EBA_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------



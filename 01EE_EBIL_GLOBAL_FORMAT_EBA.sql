drop view CALC.VIEW_CLIENT_EBIL_GLOBAL_FORMAT_EBA;
create or replace view CALC.VIEW_CLIENT_EBIL_GLOBAL_FORMAT_EBA as
with
-- EBIL Quelle
EBIL as (
    SELECT CUT_OFF_DATE,
           INSTITUTSNUMMER,
           FIRMATYP,
           FIRMARECHTSFORM,
           RECHTSGRUNDLAGE,
           ERFASSUNGSSCHEMA,
           BILANZART,
           GROESSENKLASSE,
           GROESSENKLASSE_2,
           STICHTAG,
           FIRMENKENNNUMMER,
           OSPPERSONENNUMMER,
           FIRMENNAME,
           BRADIWZ2008,
           ERFASSUNGSDATUM,
           F51300,
           F51200,
           F52070,
           F20100,
           F40200,
           F40210,
           F40230,
           F40300,
           F40400,
           F40500,
           F40600,
           F40650,
           F25500,
           F25510,
           F20410,
           F25910,
           F20420,
           F25700,
           F42800,
           F25999,
           EBITDA,
           HAFTENDESEKBRUTTO,
           NETTOFINANZVERBINDLICHKEITEN,
           F26100,
           GESAMTSCHULDENDIENSTDECKUNGSQUOTE,
           F63200,
           Betriebsergebnis,
           F49999,
           F59999,
           CashFlowKennzahl1,
           BetriebsmittelDeckungsquote,
           DynamischerVerschuldungsgradJahre,
           EbitdaLeverageJahre,
           EkWirtschaftlichQuote,
           EkRentabilitaet,
           F62200,
           CashFlowErfolgswirksErweitert,
           F52330,
           Finanzverbindlichkeiten,
           Gesamtkapitalrentabilitaet,
           SensitiviertGesamtschuldendienstDeckungsquote,
           F64000,
           KapitaldienstgrenzeVorErsatzinvest,
           Testatart,
           Rechtsform,
           ER.EBIL_DESCRIPTION                as Rechtsform_Description,
           ReturnOnCapitalEmployed,
           Nettoumsatzentwicklung,
           Umsatzrentabilitaet,
           VerschuldungsgradGearing,
           Zinsdeckungsquote,
           QUELLE,
           BRANCH,
           BRANCH || '_' || OSPPERSONENNUMMER as CLIENT_ID,
           case
               when BILANZART = 2
                   then 'EB'
               when BILANZART = 12 or BILANZART = 31
                   then 'KB'
               else 'N/A'
               end                            as BILANZART_FLAG
    FROM NLB.EBIL_CLIENTS_BALANCE_CURRENT ECC
             left join SMAP.EBIL_RECHTSFORM ER on ER.EBIL_CODE = ECC.RECHTSFORM
),
-- KEY bilden
EBIL_DUP as (
    SELECT *,
           STICHTAG || CLIENT_ID || BILANZART_FLAG as KEY
    FROM EBIL
),
-- Duplikate entfernen
EBIL_VALID as (
    SELECT *
    FROM (SELECT ED.*,
                 ROWNUMBER() over (PARTITION BY ED.KEY ORDER BY ED.ERFASSUNGSDATUM,ED.FIRMARECHTSFORM desc) as RN
          FROM EBIL_DUP ED) STATUS
    WHERE RN = 1
),
-- GF Quelle
GF as (
    SELECT CUT_OFF_DATE,
           GPNUMBER,
           CUSTOMERNAME,
           STAEDTE,
           LAENDERSCHLUESSEL,
           BRANCHENSCHLUESSEL,
           RECHTSFORMID,
           GFR.GLOBAL_FORMAT_DESCRIPTION as Rechtsform_Description,
           KUST_OE,
           CONSUNITNO,
           CURRENCYISOCODE,
           NACECODES_KONSOLIDIERUNGSEINHEIT,
           STATEMENTDATE,
           STATUS,
           STATEMENTTYPE,
           ACCTSTANDARD,
           NACECODES_BILANZ,
           BRUTTO_HAFTKAPITAL,
           NETTO_FINANZSCHULDEN,
           UMSATZERLOESE,
           KONZESSIONEN_RECHTE_LIZENZEN,
           SACHANLAGEN,
           ABSCHREIBUNGEN_SACHANLAGEN,
           ABSCHREIBUNGEN_IMMAT_VERMOEGENSWERTE,
           ERTRAG_ANLAGENABGANG,
           VERLUST_ANLAGENABGANG,
           ZUSCHREIBUNGEN_SACHANLAGEN,
           A_O_ABSCHREIBUNGEN_SACHANLAGEN,
           A_O_ABSCHREIBUNGEN_IMMAT_VERMOEGENSWERTE,
           FLUESSIGE_MITTEL,
           EBITDA,
           GOODWILL,
           NETTO_FINANZSCHULDEN_EBITDA,
           JAHRESUEBERSCHUSS_FEHLBETRAG,
           ZINSAUFWAND,
           DSCR,
           UPDATEDAT,
           Anlagevermoegen_BruttoHaftkapital,
           Belegungsrate,
           DSCR_Gewerbeimmobilien,
           Deckungsquote,
           Dynamischer_Verschuldungsgrad,
           Geldumschlagsdauer_Tage,
           Schuldendienst,
           Schuldenrendite,
           Anzahl_Mitarbeiter,
           Dividenden_Entnahmen,
           Betriebsergebnis,
           Bilanzsumme,
           BruttoVerschuldungsgrad,
           EBIT,
           Leverage_Ratio,
           Haftende_Eigenkapital_Quote_Brutto,
           Eigenkapitalrendite_vor_Steuern,
           Summe_Eventualverb_finanzielle_Verpflicht,
           GesamtFinanzschulden,
           Gesamtkapitalrendite_vor_Steuern,
           Summe_Goodwill,
           Sachanlagevermoegen_Umsatz,
           Wertpapiere,
           Netto_Haftkapital_Quote,
           Nettomarge,
           Netto_Verschuldungsgrad,
           Summe_mfr_lfr_Fremdkapital,
           Veraenderung_Umsatz_ggue_Vorjahr,
           Zinsdeckungsquote,
           B_Anzahl_Mitarbeiter,
           B_Betriebsergebnis_nach_Rivo,
           B_Betriebsergebnis_vor_Rivo,
           B_Bilanzsumme,
           B_Total_Capital,
           B_Eigenkapital,
           B_Gesamte_Betriebsertraege,
           V_HGB_Anzahl_Mitarbeiter,
           V_HGB_Jahresueberschuss,
           V_Underwriting_Result,
           V_Total_Assets,
           V_HGB_Haftende_Eigenmittel,
           V_Surplus,
           V_Goodwill,
           V_Gross_Premium_Written_NonLife,
           V_Gross_Premium_Written_Life,
           V_Gross_Premium_Written_Gesamt,
           V_HGB_Bruttopraemienwachstum,
           V_Int_Anzahl_Mitarbeiter,
           V_Int_Haftende_Eigenmittel,
           V_Int_Erfassung_Goodwill,
           V_Int_Bruttopraemienwachstum,
           L_Anzahl_Mitarbeiter,
           L_Ausschuettung,
           L_Leasingergebnis,
           L_Bilanzsumme,
           L_Brutto_Haftkapital,
           L_Summe_Eventualverb_finanz_Verpfl,
           L_Finanzverbindlichkeiten,
           L_Goodwill_Firmenwerte,
           L_Goodwill_Geschaefts_Firmenwert,
           L_Gesamtleistung,
           L_Netto_Haftkapital_Quote,
           L_Sachanlagen,
           L_Zinsaufwendungen,
           PARENTCUSTOMERKEY,
           PARENTCUSTOMERRELEVANT,
           CUSTOMERKEY,
           QUELLE,
           BRANCH
    FROM NLB.GLOBAL_FORMAT_CLIENTS_BALANCE_CURRENT GFC
             left join SMAP.GLOBAL_FORMAT_RECHTSFORM GFR on GFC.RECHTSFORMID = GFR.GLOBAL_FORMAT_CODE
),
-- Currency
GF_EXCHANGE as (
    SELECT GDP.CUT_OFF_DATE,
           GPNUMBER,
           CUSTOMERNAME,
           CONSUNITNO,
           STATUS,
           STATEMENTTYPE,
           ACCTSTANDARD,
           STATEMENTDATE,
           CURRENCYISOCODE,
           PARENTCUSTOMERKEY,
           PARENTCUSTOMERRELEVANT,
           CUSTOMERKEY,
           Rechtsform_Description,
           GDP.QUELLE,
           BRANCH,
           GDP.BRUTTO_HAFTKAPITAL * CM.RATE_TARGET_TO_EUR                        AS BRUTTO_HAFTKAPITAL,
           GDP.NETTO_FINANZSCHULDEN * CM.RATE_TARGET_TO_EUR                      AS NETTO_FINANZSCHULDEN,
           GDP.UMSATZERLOESE * CM.RATE_TARGET_TO_EUR                             AS UMSATZERLOESE,
           GDP.KONZESSIONEN_RECHTE_LIZENZEN * CM.RATE_TARGET_TO_EUR              AS KONZESSIONEN_RECHTE_LIZENZEN,
           GDP.SACHANLAGEN * CM.RATE_TARGET_TO_EUR                               AS SACHANLAGEN,
           GDP.ABSCHREIBUNGEN_SACHANLAGEN * CM.RATE_TARGET_TO_EUR                AS ABSCHREIBUNGEN_SACHANLAGEN,
           GDP.ABSCHREIBUNGEN_IMMAT_VERMOEGENSWERTE * CM.RATE_TARGET_TO_EUR      AS ABSCHREIBUNGEN_IMMAT_VERMOEGENSWERTE,
           GDP.ERTRAG_ANLAGENABGANG * CM.RATE_TARGET_TO_EUR                      AS ERTRAG_ANLAGENABGANG,
           GDP.VERLUST_ANLAGENABGANG * CM.RATE_TARGET_TO_EUR                     AS VERLUST_ANLAGENABGANG,
           GDP.ZUSCHREIBUNGEN_SACHANLAGEN * CM.RATE_TARGET_TO_EUR                AS ZUSCHREIBUNGEN_SACHANLAGEN,
           GDP.A_O_ABSCHREIBUNGEN_SACHANLAGEN * CM.RATE_TARGET_TO_EUR            AS A_O_ABSCHREIBUNGEN_SACHANLAGEN,
           GDP.A_O_ABSCHREIBUNGEN_IMMAT_VERMOEGENSWERTE * CM.RATE_TARGET_TO_EUR  AS A_O_ABSCHREIBUNGEN_IMMAT_VERMOEGENSWERTE,
           GDP.FLUESSIGE_MITTEL * CM.RATE_TARGET_TO_EUR                          AS FLUESSIGE_MITTEL,
           GDP.EBITDA * CM.RATE_TARGET_TO_EUR                                    AS EBITDA,
           GDP.GOODWILL * CM.RATE_TARGET_TO_EUR                                  AS GOODWILL,
           GDP.NETTO_FINANZSCHULDEN_EBITDA,
           GDP.JAHRESUEBERSCHUSS_FEHLBETRAG * CM.RATE_TARGET_TO_EUR              AS JAHRESUEBERSCHUSS_FEHLBETRAG,
           GDP.ZINSAUFWAND * CM.RATE_TARGET_TO_EUR                               AS ZINSAUFWAND,
           GDP.DSCR,
           GDP.UPDATEDAT,
           -- NEU
           GDP.Anlagevermoegen_BruttoHaftkapital                                 AS Anlagevermoegen_BruttoHaftkapital,
           GDP.Belegungsrate,
           GDP.DSCR_Gewerbeimmobilien,
           GDP.Deckungsquote,
           GDP.Dynamischer_Verschuldungsgrad,
           GDP.Geldumschlagsdauer_Tage,
           GDP.Schuldendienst * CM.RATE_TARGET_TO_EUR                            AS Schuldendienst,
           GDP.Schuldenrendite                                                   AS Schuldenrendite,
           GDP.Anzahl_Mitarbeiter,
           GDP.Dividenden_Entnahmen * CM.RATE_TARGET_TO_EUR                      AS Dividenden_Entnahmen,
           GDP.Betriebsergebnis * CM.RATE_TARGET_TO_EUR                          AS Betriebsergebnis,
           GDP.Bilanzsumme * CM.RATE_TARGET_TO_EUR                               AS Bilanzsumme,
           GDP.BruttoVerschuldungsgrad,
           GDP.EBIT * CM.RATE_TARGET_TO_EUR                                      AS EBIT,
           GDP.Leverage_Ratio,
           GDP.Haftende_Eigenkapital_Quote_Brutto,
           GDP.Eigenkapitalrendite_vor_Steuern,
           GDP.Summe_Eventualverb_finanzielle_Verpflicht * CM.RATE_TARGET_TO_EUR AS Summe_Eventualverb_finanzielle_Verpflicht,
           GDP.GesamtFinanzschulden * CM.RATE_TARGET_TO_EUR                      AS GesamtFinanzschulden,
           GDP.Gesamtkapitalrendite_vor_Steuern,
           GDP.Summe_Goodwill * CM.RATE_TARGET_TO_EUR                            AS Summe_Goodwill,
           GDP.Sachanlagevermoegen_Umsatz                                        AS Sachanlagevermoegen_Umsatz,
           GDP.Wertpapiere * CM.RATE_TARGET_TO_EUR                               AS Wertpapiere,
           GDP.Netto_Haftkapital_Quote,
           GDP.Nettomarge,
           GDP.Netto_Verschuldungsgrad,
           GDP.Summe_mfr_lfr_Fremdkapital * CM.RATE_TARGET_TO_EUR                AS Summe_mfr_lfr_Fremdkapital,
           GDP.Veraenderung_Umsatz_ggue_Vorjahr,
           GDP.Zinsdeckungsquote,
           GDP.B_Anzahl_Mitarbeiter,
           GDP.B_Betriebsergebnis_nach_Rivo * CM.RATE_TARGET_TO_EUR              AS B_Betriebsergebnis_nach_Rivo,
           GDP.B_Betriebsergebnis_vor_Rivo * CM.RATE_TARGET_TO_EUR               AS B_Betriebsergebnis_vor_Rivo,
           GDP.B_Bilanzsumme * CM.RATE_TARGET_TO_EUR                             AS B_Bilanzsumme,
           GDP.B_Total_Capital * CM.RATE_TARGET_TO_EUR                           AS B_Total_Capital,
           GDP.B_Eigenkapital * CM.RATE_TARGET_TO_EUR                            AS B_Eigenkapital,
           GDP.B_Gesamte_Betriebsertraege * CM.RATE_TARGET_TO_EUR                AS B_Gesamte_Betriebsertraege,
           GDP.V_HGB_Anzahl_Mitarbeiter,
           GDP.V_HGB_Jahresueberschuss * CM.RATE_TARGET_TO_EUR                   AS V_HGB_Jahresueberschuss,
           GDP.V_Underwriting_Result * CM.RATE_TARGET_TO_EUR                     AS V_Underwriting_Result,
           GDP.V_Total_Assets * CM.RATE_TARGET_TO_EUR                            AS V_Total_Assets,
           GDP.V_HGB_Haftende_Eigenmittel * CM.RATE_TARGET_TO_EUR                AS V_HGB_Haftende_Eigenmittel,
           GDP.V_Surplus * CM.RATE_TARGET_TO_EUR                                 AS V_Surplus,
           GDP.V_Goodwill * CM.RATE_TARGET_TO_EUR                                AS V_Goodwill,
           GDP.V_Gross_Premium_Written_NonLife * CM.RATE_TARGET_TO_EUR           AS V_Gross_Premium_Written_NonLife,
           GDP.V_Gross_Premium_Written_Life * CM.RATE_TARGET_TO_EUR              AS V_Gross_Premium_Written_Life,
           GDP.V_Gross_Premium_Written_Gesamt * CM.RATE_TARGET_TO_EUR            AS V_Gross_Premium_Written_Gesamt,
           GDP.V_HGB_Bruttopraemienwachstum,
           GDP.V_Int_Anzahl_Mitarbeiter,
           GDP.V_Int_Haftende_Eigenmittel * CM.RATE_TARGET_TO_EUR                AS V_Int_Haftende_Eigenmittel,
           GDP.V_Int_Erfassung_Goodwill * CM.RATE_TARGET_TO_EUR                  AS V_Int_Erfassung_Goodwill,
           GDP.V_Int_Bruttopraemienwachstum,
           GDP.L_Anzahl_Mitarbeiter,
           GDP.L_Ausschuettung,
           GDP.L_Leasingergebnis * CM.RATE_TARGET_TO_EUR                         AS L_Leasingergebnis,
           GDP.L_Bilanzsumme * CM.RATE_TARGET_TO_EUR                             AS L_Bilanzsumme,
           GDP.L_Brutto_Haftkapital * CM.RATE_TARGET_TO_EUR                      AS L_Brutto_Haftkapital,
           GDP.L_Summe_Eventualverb_finanz_Verpfl * CM.RATE_TARGET_TO_EUR        AS L_Summe_Eventualverb_finanz_Verpfl,
           GDP.L_Finanzverbindlichkeiten * CM.RATE_TARGET_TO_EUR                 AS L_Finanzverbindlichkeiten,
           GDP.L_Goodwill_Firmenwerte * CM.RATE_TARGET_TO_EUR                    AS L_Goodwill_Firmenwerte,
           GDP.L_Goodwill_Geschaefts_Firmenwert * CM.RATE_TARGET_TO_EUR          AS L_Goodwill_Geschaefts_Firmenwert,
           GDP.L_Gesamtleistung * CM.RATE_TARGET_TO_EUR                          AS L_Gesamtleistung,
           GDP.L_Netto_Haftkapital_Quote,
           GDP.L_Sachanlagen * CM.RATE_TARGET_TO_EUR                             AS L_Sachanlagen,
           GDP.L_Zinsaufwendungen * CM.RATE_TARGET_TO_EUR                        AS L_Zinsaufwendungen,
           CM.ZIEL_WHRG,
           CM.RATE_TARGET_TO_EUR
    FROM GF as GDP
             left join IMAP.CURRENCY_MAP AS CM on GDP.CURRENCYISOCODE = CM.ZIEL_WHRG
    where (((exists(SELECT 1 From IMAP.CURRENCY_MAP as CM2 where CM.ZIEL_WHRG = CM2.ZIEL_WHRG AND CM.CUT_OFF_DATE < CM2.CUT_OFF_DATE)) = FALSE))
),
-- Hinzufuegen von Konzernbilanzen an Tochter falls nicht selbst vorhanden (enthält nur die hinzugefügten KBs)
GF_MD_KB as (
    select GFD.CUT_OFF_DATE,
           GFD.GPNUMBER,
           GFD.CUSTOMERNAME,
           GFM.CONSUNITNO,
           GFM.STATUS,
           GFM.STATEMENTTYPE,
           GFM.ACCTSTANDARD,
           GFM.STATEMENTDATE,
           GFM.CURRENCYISOCODE,
           GFD.PARENTCUSTOMERKEY,
           GFD.PARENTCUSTOMERRELEVANT,
           GFD.CUSTOMERKEY,
           GFD.Rechtsform_Description,
           GFM.QUELLE,
           GFM.BRANCH,
           GFM.BRUTTO_HAFTKAPITAL,
           GFM.NETTO_FINANZSCHULDEN,
           GFM.UMSATZERLOESE,
           GFM.KONZESSIONEN_RECHTE_LIZENZEN,
           GFM.SACHANLAGEN,
           GFM.ABSCHREIBUNGEN_SACHANLAGEN,
           GFM.ABSCHREIBUNGEN_IMMAT_VERMOEGENSWERTE,
           GFM.ERTRAG_ANLAGENABGANG,
           GFM.VERLUST_ANLAGENABGANG,
           GFM.ZUSCHREIBUNGEN_SACHANLAGEN,
           GFM.A_O_ABSCHREIBUNGEN_SACHANLAGEN,
           GFM.A_O_ABSCHREIBUNGEN_IMMAT_VERMOEGENSWERTE,
           GFM.FLUESSIGE_MITTEL,
           GFM.EBITDA,
           GFM.GOODWILL,
           GFM.NETTO_FINANZSCHULDEN_EBITDA,
           GFM.JAHRESUEBERSCHUSS_FEHLBETRAG,
           GFM.ZINSAUFWAND,
           GFM.DSCR,
           GFM.UPDATEDAT,
           GFM.Anlagevermoegen_BruttoHaftkapital,
           GFM.Belegungsrate,
           GFM.DSCR_Gewerbeimmobilien,
           GFM.Deckungsquote,
           GFM.Dynamischer_Verschuldungsgrad,
           GFM.Geldumschlagsdauer_Tage,
           GFM.Schuldendienst,
           GFM.Schuldenrendite,
           GFM.Anzahl_Mitarbeiter,
           GFM.Dividenden_Entnahmen,
           GFM.Betriebsergebnis,
           GFM.Bilanzsumme,
           GFM.BruttoVerschuldungsgrad,
           GFM.EBIT,
           GFM.Leverage_Ratio,
           GFM.Haftende_Eigenkapital_Quote_Brutto,
           GFM.Eigenkapitalrendite_vor_Steuern,
           GFM.Summe_Eventualverb_finanzielle_Verpflicht,
           GFM.GesamtFinanzschulden,
           GFM.Gesamtkapitalrendite_vor_Steuern,
           GFM.Summe_Goodwill,
           GFM.Sachanlagevermoegen_Umsatz,
           GFM.Wertpapiere,
           GFM.Netto_Haftkapital_Quote,
           GFM.Nettomarge,
           GFM.Netto_Verschuldungsgrad,
           GFM.Summe_mfr_lfr_Fremdkapital,
           GFM.Veraenderung_Umsatz_ggue_Vorjahr,
           GFM.Zinsdeckungsquote,
           GFM.B_Anzahl_Mitarbeiter,
           GFM.B_Betriebsergebnis_nach_Rivo,
           GFM.B_Betriebsergebnis_vor_Rivo,
           GFM.B_Bilanzsumme,
           GFM.B_Total_Capital,
           GFM.B_Eigenkapital,
           GFM.B_Gesamte_Betriebsertraege,
           GFM.V_HGB_Anzahl_Mitarbeiter,
           GFM.V_HGB_Jahresueberschuss,
           GFM.V_Underwriting_Result,
           GFM.V_Total_Assets,
           GFM.V_HGB_Haftende_Eigenmittel,
           GFM.V_Surplus,
           GFM.V_Goodwill,
           GFM.V_Gross_Premium_Written_NonLife,
           GFM.V_Gross_Premium_Written_Life,
           GFM.V_Gross_Premium_Written_Gesamt,
           GFM.V_HGB_Bruttopraemienwachstum,
           GFM.V_Int_Anzahl_Mitarbeiter,
           GFM.V_Int_Haftende_Eigenmittel,
           GFM.V_Int_Erfassung_Goodwill,
           GFM.V_Int_Bruttopraemienwachstum,
           GFM.L_Anzahl_Mitarbeiter,
           GFM.L_Ausschuettung,
           GFM.L_Leasingergebnis,
           GFM.L_Bilanzsumme,
           GFM.L_Brutto_Haftkapital,
           GFM.L_Summe_Eventualverb_finanz_Verpfl,
           GFM.L_Finanzverbindlichkeiten,
           GFM.L_Goodwill_Firmenwerte,
           GFM.L_Goodwill_Geschaefts_Firmenwert,
           GFM.L_Gesamtleistung,
           GFM.L_Netto_Haftkapital_Quote,
           GFM.L_Sachanlagen,
           GFM.L_Zinsaufwendungen,
           GFM.ZIEL_WHRG,
           GFM.RATE_TARGET_TO_EUR
    from GF_EXCHANGE GFD
             -- Mutter mit Konzernbilanz
             left join GF_EXCHANGE GFM on GFD.PARENTCUSTOMERKEY = GFM.CUSTOMERKEY
        and GFD.STATEMENTDATE <= GFM.STATEMENTDATE
        and GFM.CONSUNITNO = 1
    where
      -- Ist Tochter
        GFD.PARENTCUSTOMERKEY is not NULL
      -- Keine Konzernbilanz
      and GFD.CONSUNITNO != 1
      -- Tochter hat keine eigene Konzernbilanz angegeben oder Mutter hat aktuellere
      and not EXISTS(select 1
                     from GF_EXCHANGE GFD2
                     where GFD.CUSTOMERKEY = GFD2.CUSTOMERKEY
                       and GFD2.CONSUNITNO = 1
                       and not EXISTS(select 1
                                      from GF_EXCHANGE GFM2
                                      where GFM.CUSTOMERKEY = GFM2.CUSTOMERKEY
                                        and GFM2.CONSUNITNO = 1
                                        and GFD2.STATEMENTDATE < GFM2.STATEMENTDATE))
      -- Aktuellste Konzernbilanz von Mutter nehmen
      and GFM.STATEMENTDATE = (select MAX(GFM2.STATEMENTDATE)
                               from GF_EXCHANGE GFM2
                               where GFM.CUSTOMERKEY = GFM2.CUSTOMERKEY
                                 and GFM2.CONSUNITNO = 1
                               group by GFM2.CUSTOMERKEY)
),
-- Vereinigung GF + Mutter-Tochter-KBs
GF_ALL as (
    select *, false as KB_VON_PARENTCUSTOMER
    from GF_EXCHANGE
    union all
    select *, true as KB_VON_PARENTCUSTOMER
    from GF_MD_KB
),
-- KEY bilden
GF_DUP as (
    SELECT DISTINCT *,
                    BRANCH || '_' || GPNUMBER                                as CLIENT_ID,
                    STATEMENTDATE || BRANCH || '_' || GPNUMBER || CONSUNITNO as KEY
    FROM GF_ALL
),
-- Duplikate entfernen
GF_VALID as (
    SELECT *
    FROM (SELECT GF.*,
                 ROWNUMBER() over (PARTITION BY GF.KEY ORDER BY GF.UPDATEDAT,GF.ACCTSTANDARD desc) as RN
          FROM GF_DUP GF) STATUS
    WHERE RN = 1
),
EBIL_FINISH as (
    SELECT EV1.CUT_OFF_DATE,
           EV1.BRANCH,
           EV1.FIRMENKENNNUMMER,
           EV1.FIRMATYP,
           EV1.FIRMARECHTSFORM,
           EV1.RECHTSGRUNDLAGE,
           EV1.ERFASSUNGSSCHEMA,
           EV1.BILANZART,
           EV1.GROESSENKLASSE,
           EV1.GROESSENKLASSE_2,
           EV1.STICHTAG,
           EV1.OSPPERSONENNUMMER,
           EV1.FIRMENNAME,
           EV1.BRADIWZ2008,
           EV1.ERFASSUNGSDATUM,
           EV1.F51300,
           EV1.F51200,
           EV1.F52070,
           EV1.F20100,
           EV1.F40200,
           EV1.F40210,
           EV1.F40230,
           EV1.F40300,
           EV1.F40400,
           EV1.F40500,
           EV1.F40600,
           EV1.F40650,
           EV1.F25500,
           EV1.F25510,
           EV1.F20410,
           EV1.F25910,
           EV1.F20420,
           EV1.F25700,
           EV1.F42800,
           EV1.F25999,
           EV1.EBITDA,
           EV1.HAFTENDESEKBRUTTO,
           EV1.NETTOFINANZVERBINDLICHKEITEN,
           EV1.F26100,
           EV1.GESAMTSCHULDENDIENSTDECKUNGSQUOTE,
           EV1.F63200,
           EV1.Betriebsergebnis,
           EV1.F49999,
           EV1.F59999,
           EV1.CashFlowKennzahl1 / 100                                          as CashFlowKennzahl1,
           EV1.BetriebsmittelDeckungsquote,
           EV1.DynamischerVerschuldungsgradJahre,
           EV1.EbitdaLeverageJahre,
           EV1.EkWirtschaftlichQuote,
           EV1.EkRentabilitaet,
           EV1.F62200,
           EV1.CashFlowErfolgswirksErweitert,
           EV1.F52330,
           EV1.Finanzverbindlichkeiten,
           EV1.Gesamtkapitalrentabilitaet,
           EV1.SensitiviertGesamtschuldendienstDeckungsquote,
           EV1.F64000,
           EV1.KapitaldienstgrenzeVorErsatzinvest,
           EV1.Testatart,
           EV1.Rechtsform_Description,
           EV1.ReturnOnCapitalEmployed / 100                                    as ReturnOnCapitalEmployed,
           EV1.Nettoumsatzentwicklung / 100                                     as Nettoumsatzentwicklung,
           EV1.Umsatzrentabilitaet / 100                                        as Umsatzrentabilitaet,
           EV1.VerschuldungsgradGearing,
           EV1.Zinsdeckungsquote,
           EV1.QUELLE,
           COUNT(*)                                                             as RANG,
           EV1.CLIENT_ID,
           EV1.BILANZART_FLAG,
           COUNT(*) || EV1.CLIENT_ID || EV1.BILANZART_FLAG                      as HEUTE,
           cast(COUNT(*) - 1 as VARCHAR) || EV1.CLIENT_ID || EV1.BILANZART_FLAG as VORHER
    FROM EBIL_VALID EV1
             INNER JOIN EBIL_VALID EV2 ON (EV1.OSPPERSONENNUMMER = EV2.OSPPERSONENNUMMER) AND (EV1.STICHTAG <= EV2.STICHTAG)
        AND ((EV1.BILANZART = 2 AND EV2.BILANZART = 2) OR (EV1.BILANZART in (12, 31) AND EV2.BILANZART in (12, 31)))
    GROUP BY EV1.CUT_OFF_DATE, EV1.BRANCH, EV1.FIRMENKENNNUMMER, EV1.FIRMATYP, EV1.FIRMARECHTSFORM, EV1.RECHTSGRUNDLAGE, EV1.ERFASSUNGSSCHEMA,
             EV1.BILANZART, EV1.GROESSENKLASSE, EV1.GROESSENKLASSE_2, EV1.STICHTAG, EV1.OSPPERSONENNUMMER,
             EV1.FIRMENNAME, EV1.BRADIWZ2008, EV1.ERFASSUNGSDATUM, EV1.F51300, EV1.F51200, EV1.F52070, EV1.F20100,
             EV1.F40200, EV1.F40210, EV1.F40230, EV1.F40300, EV1.F40400, EV1.F40500, EV1.F40600, EV1.F40650,
             EV1.F25500, EV1.F25510, EV1.F20410, EV1.F25910, EV1.F20420, EV1.F25700, EV1.F42800, EV1.F25999, EV1.EBITDA,
             EV1.HAFTENDESEKBRUTTO, EV1.NETTOFINANZVERBINDLICHKEITEN, EV1.GESAMTSCHULDENDIENSTDECKUNGSQUOTE,
             EV1.F63200, EV1.Betriebsergebnis,
             EV1.F49999,
             EV1.F59999,
             EV1.CashFlowKennzahl1,
             EV1.BetriebsmittelDeckungsquote,
             EV1.DynamischerVerschuldungsgradJahre,
             EV1.EbitdaLeverageJahre,
             EV1.EkWirtschaftlichQuote,
             EV1.EkRentabilitaet,
             EV1.F62200,
             EV1.CashFlowErfolgswirksErweitert,
             EV1.F52330,
             EV1.Finanzverbindlichkeiten,
             EV1.Gesamtkapitalrentabilitaet,
             EV1.SensitiviertGesamtschuldendienstDeckungsquote,
             EV1.F64000,
             EV1.KapitaldienstgrenzeVorErsatzinvest,
             EV1.Testatart,
             EV1.Rechtsform_Description,
             EV1.ReturnOnCapitalEmployed,
             EV1.Nettoumsatzentwicklung,
             EV1.Umsatzrentabilitaet,
             EV1.VerschuldungsgradGearing,
             EV1.Zinsdeckungsquote,
             EV1.QUELLE, EV1.F26100, EV1.CLIENT_ID, EV1.BILANZART_FLAG
),
GF_FINISH as (
    SELECT GFV1.CUT_OFF_DATE,
           GFV1.BRANCH,
           GFV1.GPNUMBER,
           GFV1.CUSTOMERNAME,
           GFV1.CONSUNITNO,
           GFV1.STATUS,
           GFV1.STATEMENTTYPE,
           GFV1.STATEMENTDATE,
           GFV1.CURRENCYISOCODE,
           GFV1.BRUTTO_HAFTKAPITAL,
           GFV1.NETTO_FINANZSCHULDEN,
           GFV1.UMSATZERLOESE,
           GFV1.KONZESSIONEN_RECHTE_LIZENZEN,
           GFV1.SACHANLAGEN,
           GFV1.ABSCHREIBUNGEN_SACHANLAGEN,
           GFV1.ABSCHREIBUNGEN_IMMAT_VERMOEGENSWERTE,
           GFV1.ERTRAG_ANLAGENABGANG,
           GFV1.VERLUST_ANLAGENABGANG,
           GFV1.ZUSCHREIBUNGEN_SACHANLAGEN,
           GFV1.A_O_ABSCHREIBUNGEN_SACHANLAGEN,
           GFV1.A_O_ABSCHREIBUNGEN_IMMAT_VERMOEGENSWERTE,
           GFV1.FLUESSIGE_MITTEL,
           GFV1.EBITDA,
           GFV1.GOODWILL,
           GFV1.NETTO_FINANZSCHULDEN_EBITDA,
           GFV1.JAHRESUEBERSCHUSS_FEHLBETRAG,
           GFV1.ZINSAUFWAND,
           GFV1.DSCR,
           GFV1.UPDATEDAT,
           -- NEU
           GFV1.KB_VON_PARENTCUSTOMER,
           GFV1.Anlagevermoegen_BruttoHaftkapital,
           GFV1.Belegungsrate,
           GFV1.DSCR_Gewerbeimmobilien,
           GFV1.Deckungsquote,
           GFV1.Dynamischer_Verschuldungsgrad,
           GFV1.Geldumschlagsdauer_Tage,
           GFV1.Schuldendienst,
           GFV1.Schuldenrendite,
           GFV1.Anzahl_Mitarbeiter,
           GFV1.Dividenden_Entnahmen,
           GFV1.Betriebsergebnis,
           GFV1.Bilanzsumme,
           GFV1.BruttoVerschuldungsgrad,
           GFV1.EBIT,
           GFV1.Leverage_Ratio,
           GFV1.Haftende_Eigenkapital_Quote_Brutto,
           GFV1.Eigenkapitalrendite_vor_Steuern,
           GFV1.Summe_Eventualverb_finanzielle_Verpflicht,
           GFV1.GesamtFinanzschulden,
           GFV1.Gesamtkapitalrendite_vor_Steuern,
           GFV1.Summe_Goodwill,
           GFV1.Sachanlagevermoegen_Umsatz,
           GFV1.Wertpapiere,
           GFV1.Netto_Haftkapital_Quote,
           GFV1.Nettomarge,
           GFV1.Netto_Verschuldungsgrad,
           GFV1.Summe_mfr_lfr_Fremdkapital,
           GFV1.Veraenderung_Umsatz_ggue_Vorjahr,
           GFV1.Zinsdeckungsquote,
           GFV1.B_Anzahl_Mitarbeiter,
           GFV1.B_Betriebsergebnis_nach_Rivo,
           GFV1.B_Betriebsergebnis_vor_Rivo,
           GFV1.B_Bilanzsumme,
           GFV1.B_Total_Capital,
           GFV1.B_Eigenkapital,
           GFV1.B_Gesamte_Betriebsertraege,
           GFV1.V_HGB_Anzahl_Mitarbeiter,
           GFV1.V_HGB_Jahresueberschuss,
           GFV1.V_Underwriting_Result,
           GFV1.V_Total_Assets,
           GFV1.V_HGB_Haftende_Eigenmittel,
           GFV1.V_Surplus,
           GFV1.V_Goodwill,
           GFV1.V_Gross_Premium_Written_NonLife,
           GFV1.V_Gross_Premium_Written_Life,
           GFV1.V_Gross_Premium_Written_Gesamt,
           GFV1.V_HGB_Bruttopraemienwachstum,
           GFV1.V_Int_Anzahl_Mitarbeiter,
           GFV1.V_Int_Haftende_Eigenmittel,
           GFV1.V_Int_Erfassung_Goodwill,
           GFV1.V_Int_Bruttopraemienwachstum,
           GFV1.L_Anzahl_Mitarbeiter,
           GFV1.L_Ausschuettung,
           GFV1.L_Leasingergebnis,
           GFV1.L_Bilanzsumme,
           GFV1.L_Brutto_Haftkapital,
           GFV1.L_Summe_Eventualverb_finanz_Verpfl,
           GFV1.L_Finanzverbindlichkeiten,
           GFV1.L_Goodwill_Firmenwerte,
           GFV1.L_Goodwill_Geschaefts_Firmenwert,
           GFV1.L_Gesamtleistung,
           GFV1.L_Netto_Haftkapital_Quote,
           GFV1.L_Sachanlagen,
           GFV1.L_Zinsaufwendungen,
           GFV1.PARENTCUSTOMERKEY,
           GFV1.PARENTCUSTOMERRELEVANT,
           GFV1.CUSTOMERKEY,
           GFV1.Rechtsform_Description,
           GFV1.QUELLE,
           COUNT(*)                                                           AS Rang,
           GFV1.CLIENT_ID,
           COUNT(*) || GFV1.CLIENT_ID || GFV1.CONSUNITNO                      AS HEUTE,
           cast(COUNT(*) - 1 as VARCHAR) || GFV1.CLIENT_ID || GFV1.CONSUNITNO AS VORHER
    FROM GF_VALID AS GFV1
             INNER JOIN GF_VALID AS GFV2
                        ON (GFV1.CONSUNITNO = GFV2.CONSUNITNO) AND (GFV1.STATEMENTDATE <= GFV2.STATEMENTDATE) AND
                           (GFV1.GPNUMBER = GFV2.GPNUMBER)
    GROUP BY GFV1.CUT_OFF_DATE, GFV1.BRANCH, GFV1.GPNUMBER, GFV1.CUSTOMERNAME, GFV1.CONSUNITNO, GFV1.STATUS,
             GFV1.STATEMENTTYPE, GFV1.STATEMENTDATE,
             GFV1.CURRENCYISOCODE, GFV1.BRUTTO_HAFTKAPITAL, GFV1.NETTO_FINANZSCHULDEN, GFV1.UMSATZERLOESE,
             GFV1.KONZESSIONEN_RECHTE_LIZENZEN, GFV1.SACHANLAGEN, GFV1.ABSCHREIBUNGEN_SACHANLAGEN,
             GFV1.ABSCHREIBUNGEN_IMMAT_VERMOEGENSWERTE, GFV1.ERTRAG_ANLAGENABGANG, GFV1.VERLUST_ANLAGENABGANG,
             GFV1.ZUSCHREIBUNGEN_SACHANLAGEN, GFV1.A_O_ABSCHREIBUNGEN_SACHANLAGEN,
             GFV1.A_O_ABSCHREIBUNGEN_IMMAT_VERMOEGENSWERTE, GFV1.FLUESSIGE_MITTEL, GFV1.EBITDA, GFV1.GOODWILL,
             GFV1.NETTO_FINANZSCHULDEN_EBITDA, GFV1.JAHRESUEBERSCHUSS_FEHLBETRAG, GFV1.ZINSAUFWAND, GFV1.DSCR,
             GFV1.UPDATEDAT,
             GFV1.Anlagevermoegen_BruttoHaftkapital,
             GFV1.Belegungsrate,
             GFV1.DSCR_Gewerbeimmobilien,
             GFV1.Deckungsquote,
             GFV1.Dynamischer_Verschuldungsgrad,
             GFV1.Geldumschlagsdauer_Tage,
             GFV1.Schuldendienst,
             GFV1.Schuldenrendite,
             GFV1.Anzahl_Mitarbeiter,
             GFV1.Dividenden_Entnahmen,
             GFV1.Betriebsergebnis,
             GFV1.Bilanzsumme,
             GFV1.BruttoVerschuldungsgrad,
             GFV1.EBIT,
             GFV1.Leverage_Ratio,
             GFV1.Haftende_Eigenkapital_Quote_Brutto,
             GFV1.Eigenkapitalrendite_vor_Steuern,
             GFV1.Summe_Eventualverb_finanzielle_Verpflicht,
             GFV1.GesamtFinanzschulden,
             GFV1.Gesamtkapitalrendite_vor_Steuern,
             GFV1.Summe_Goodwill,
             GFV1.Sachanlagevermoegen_Umsatz,
             GFV1.Wertpapiere,
             GFV1.Netto_Haftkapital_Quote,
             GFV1.Nettomarge,
             GFV1.Netto_Verschuldungsgrad,
             GFV1.Summe_mfr_lfr_Fremdkapital,
             GFV1.Veraenderung_Umsatz_ggue_Vorjahr,
             GFV1.Zinsdeckungsquote,
             GFV1.B_Anzahl_Mitarbeiter,
             GFV1.B_Betriebsergebnis_nach_Rivo,
             GFV1.B_Betriebsergebnis_vor_Rivo,
             GFV1.B_Bilanzsumme,
             GFV1.B_Total_Capital,
             GFV1.B_Eigenkapital,
             GFV1.B_Gesamte_Betriebsertraege,
             GFV1.V_HGB_Anzahl_Mitarbeiter,
             GFV1.V_HGB_Jahresueberschuss,
             GFV1.V_Underwriting_Result,
             GFV1.V_Total_Assets,
             GFV1.V_HGB_Haftende_Eigenmittel,
             GFV1.V_Surplus,
             GFV1.V_Goodwill,
             GFV1.V_Gross_Premium_Written_NonLife,
             GFV1.V_Gross_Premium_Written_Life,
             GFV1.V_Gross_Premium_Written_Gesamt,
             GFV1.V_HGB_Bruttopraemienwachstum,
             GFV1.V_Int_Anzahl_Mitarbeiter,
             GFV1.V_Int_Haftende_Eigenmittel,
             GFV1.V_Int_Erfassung_Goodwill,
             GFV1.V_Int_Bruttopraemienwachstum,
             GFV1.L_Anzahl_Mitarbeiter,
             GFV1.L_Ausschuettung,
             GFV1.L_Leasingergebnis,
             GFV1.L_Bilanzsumme,
             GFV1.L_Brutto_Haftkapital,
             GFV1.L_Summe_Eventualverb_finanz_Verpfl,
             GFV1.L_Finanzverbindlichkeiten,
             GFV1.L_Goodwill_Firmenwerte,
             GFV1.L_Goodwill_Geschaefts_Firmenwert,
             GFV1.L_Gesamtleistung,
             GFV1.L_Netto_Haftkapital_Quote,
             GFV1.L_Sachanlagen,
             GFV1.L_Zinsaufwendungen,
             GFV1.PARENTCUSTOMERKEY,
             GFV1.PARENTCUSTOMERRELEVANT,
             GFV1.CUSTOMERKEY,
             GFV1.Rechtsform_Description, GFV1.KB_VON_PARENTCUSTOMER,
             GFV1.QUELLE, GFV1.CLIENT_ID
),
-- Abstand der Daten berechnen
EBIL_DATE_DIF as (
    SELECT EF1.*,
           case
               when EF1.RANG = 1 and (DAYS(EF1.CUT_OFF_DATE) - DAYS(EF1.STICHTAG)) > 730 then FALSE -- Abstand Tage 365*2
               when EF1.RANG = 2 and (DAYS(EF2.STICHTAG) - DAYS(EF1.STICHTAG)) > 367 OR (DAYS(EF1.CUT_OFF_DATE) - DAYS(EF1.STICHTAG)) > 1095 then FALSE -- 365*3
               when EF1.RANG = 3 and (DAYS(EF2.STICHTAG) - DAYS(EF1.STICHTAG)) > 367 OR (DAYS(EF1.CUT_OFF_DATE) - DAYS(EF1.STICHTAG)) > 1460 then FALSE -- 365*4
               else TRUE end                                                                                                          as ABSTAND_DATEN_FLAG,
           case when EF1.RANG = 1 then (DAYS(EF1.CUT_OFF_DATE) - DAYS(EF1.STICHTAG)) else DAYS(EF2.STICHTAG) - DAYS(EF1.STICHTAG) end as ABSTAND_IN_TAGEN
    FROM EBIL_FINISH EF1
             LEFT JOIN EBIL_FINISH AS EF2 ON EF1.VORHER = EF2.HEUTE
    WHERE EF1.OSPPERSONENNUMMER is not null
      and EF1.RANG < 7
),
-- Abstand der Daten berechnen
GF_DATE_DIF as (
    SELECT GF1.*,
           case
               when GF1.RANG = 1 and (DAYS(GF1.CUT_OFF_DATE) - DAYS(GF1.STATEMENTDATE)) > 730 then FALSE -- Abstand Tage 365*2
               when GF1.RANG = 2 and (DAYS(GF2.STATEMENTDATE) - DAYS(GF1.STATEMENTDATE)) > 367 OR (DAYS(GF1.CUT_OFF_DATE) - DAYS(GF1.STATEMENTDATE)) > 1095 then FALSE -- 365*3
               when GF1.RANG = 3 and (DAYS(GF2.STATEMENTDATE) - DAYS(GF1.STATEMENTDATE)) > 367 OR (DAYS(GF1.CUT_OFF_DATE) - DAYS(GF1.STATEMENTDATE)) > 1460 then FALSE -- 365*4
               else TRUE end                                                                                                                         as ABSTAND_DATEN_FLAG,
           case when GF1.RANG = 1 then (DAYS(GF1.CUT_OFF_DATE) - DAYS(GF1.STATEMENTDATE)) else DAYS(GF2.STATEMENTDATE) - DAYS(GF1.STATEMENTDATE) end as ABSTAND_IN_TAGEN
    FROM GF_FINISH GF1
             LEFT JOIN GF_FINISH AS GF2 ON GF1.VORHER = GF2.HEUTE
    WHERE GF1.RANG < 7
),
UNION_KUNDENNR as (
    SELECT DISTINCT SQ.CUT_OFF_DATE,
                    SQ.CLIENT_ID,
                    SQ.BRANCH
    FROM (SELECT CUT_OFF_DATE, CLIENT_ID, BRANCH
          FROM GF_FINISH
          WHERE GPNUMBER is not null
          UNION ALL
          SELECT CUT_OFF_DATE, CLIENT_ID, BRANCH
          FROM EBIL_FINISH
          WHERE OSPPERSONENNUMMER is not null) as SQ
),
-- EBIL/GF zusammenführen
EBIL_GF_CUST as (
    SELECT SQ.*
    FROM (SELECT NVL(E.CLIENT_ID, G.CLIENT_ID) as CLIENT_ID,
                 E.MaxStichtag                 as Stichtag,
                 E.MaxErfassungsdatum          as Erfassungsdatum,
                 G.MaxStatementDate            as STATEMENTDATE,
                 G.MaxUpdatedat                as UPDATEDAT,
                 case
                     when E.CLIENT_ID is null then 'GF'
                     else (case
                               when G.CLIENT_ID is null then 'EBIL'
                               else (case
                                         when NVL(E.MaxStichtag, date('1900-01-01')) > NVL(G.MaxStatementDate, date('1900-01-01')) OR
                                              (NVL(E.MaxStichtag, date('1900-01-01')) = NVL(G.MaxStatementDate, date('1900-01-01')) AND
                                               NVL(E.MaxErfassungsdatum, date('1900-01-01')) > NVL(G.MaxUpdatedat, date('1900-01-01')))
                                             then 'EBIL'
                                         else 'GF' end)
                         end)
                     end                       as FLAG_GF_EBIL
          FROM (SELECT CLIENT_ID,
                       max(STICHTAG)        as MaxStichtag,
                       max(ERFASSUNGSDATUM) as MaxErfassungsdatum
                FROM EBIL_FINISH
                GROUP BY CLIENT_ID) as E
                   LEFT JOIN (
              SELECT CLIENT_ID,
                     max(STATEMENTDATE) as MaxStatementDate,
                     max(UPDATEDAT)     as MaxUpdatedat
              from GF_FINISH
              GROUP BY CLIENT_ID) as G
                             on E.CLIENT_ID = G.CLIENT_ID
          UNION
          SELECT NVL(G.CLIENT_ID, E.CLIENT_ID) as CLIENT_ID,
                 E.MaxStichtag                 as Stichtag,
                 E.MaxErfassungsdatum          as Erfassungsdatum,
                 G.MaxStatementDate            as STATEMENTDATE,
                 G.MaxUpdateDat                as UPDATEDAT,
                 case
                     when G.CLIENT_ID is null then 'EBIL'
                     else (case
                               when E.CLIENT_ID is null then 'GF'
                               else (case
                                         when NVL(G.MaxStatementDate, date('1900-01-01')) > NVL(E.MaxStichtag, date('1900-01-01')) OR
                                              (NVL(G.MaxStatementDate, date('1900-01-01')) = NVL(E.MaxStichtag, date('1900-01-01')) AND
                                               NVL(G.MaxUpdatedat, date('1900-01-01')) > NVL(E.MaxErfassungsdatum, date('1900-01-01')))
                                             then 'GF'
                                         else 'EBIL' end)
                         end)
                     end                       as FLAG_GF_EBIL
          FROM (SELECT CLIENT_ID,
                       max(STATEMENTDATE) as MaxStatementDate,
                       max(UPDATEDAT)     as MaxUpdatedat
                from GF_FINISH
                GROUP BY CLIENT_ID) as G
                   LEFT JOIN (
              SELECT CLIENT_ID,
                     max(STICHTAG)        as MaxStichtag,
                     max(ERFASSUNGSDATUM) as MaxErfassungsdatum
              FROM EBIL_FINISH
              GROUP BY CLIENT_ID) as E
                             on G.CLIENT_ID = E.CLIENT_ID
         ) as SQ
),
-- Finale Berechnungen + aufsplitten nach Einzelbilanz/Konzernbilanz (BILANZART_FLAG = 'EB'/'KB' oder CONSUNITNO = 0/1)
ALL_FIELDS as (
    SELECT UKNR.CUT_OFF_DATE,
           UKNR.CLIENT_ID   as GNI_KUNDE,
           UKNR.BRANCH,
           max(
                   case
                       when GFCF.RANG = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.KB_VON_PARENTCUSTOMER
                       when EBCF.RANG = 1 and EGC.FLAG_GF_EBIL = 'EBIL'
                           then false
                       end
               )            as KB_VON_PARENTCUSTOMER,
           max(
                   case
                       when GFCF.RANG = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then 'EUR'
                       when EBCF.RANG = 1 and EGC.FLAG_GF_EBIL = 'EBIL'
                           then 'EUR'
                       end
               )            as CURRENCY,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.CURRENCYISOCODE
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then 'EUR'
                       end
               )            as CURRENCY_OC_KB,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.CURRENCYISOCODE
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then 'EUR'
                       end
               )            as CURRENCY_OC_EB,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then NVL(GFCF.BRUTTO_HAFTKAPITAL, GFCF.B_Eigenkapital, GFCF.V_HGB_Haftende_Eigenmittel, GFCF.V_Int_Haftende_Eigenmittel, GFCF.L_Brutto_Haftkapital)
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.HAFTENDESEKBRUTTO
                       end
               )            as BRUTTO_HAFTKAPITAL,
           max(case
                   when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                       then NVL(GFCF.BRUTTO_HAFTKAPITAL, GFCF.B_Total_Capital, GFCF.V_Surplus, GFCF.L_Brutto_Haftkapital)
                   when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                       then EBCF.HAFTENDESEKBRUTTO
               end
               )            as GRP_BRUTTO_HAFTKAPITAL,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then NVL(GFCF.BRUTTO_HAFTKAPITAL, GFCF.B_Eigenkapital, GFCF.V_Surplus, GFCF.L_Brutto_Haftkapital)
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.HAFTENDESEKBRUTTO
                       end
               )            as EIGENKAPITAL,
           max(case
                   when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                       then NVL(GFCF.BRUTTO_HAFTKAPITAL, GFCF.B_Eigenkapital, GFCF.V_Surplus, GFCF.L_Brutto_Haftkapital)
                   when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                       then EBCF.HAFTENDESEKBRUTTO
               end
               )            as GRP_EIGENKAPITAL,
           max(case
                   when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                       then NVL(GFCF.UMSATZERLOESE, GFCF.B_Gesamte_Betriebsertraege, GFCF.V_Gross_Premium_Written_Gesamt, GFCF.L_Gesamtleistung)
                   when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                       then EBCF.F20100
               end
               )            as JAHRESUMSATZ,
           max(case
                   when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                       then NVL(GFCF.UMSATZERLOESE, GFCF.B_Gesamte_Betriebsertraege, GFCF.V_Gross_Premium_Written_Gesamt, GFCF.L_Gesamtleistung)
                   when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                       then EBCF.F20100
               end
               )            as GRP_JAHRESUMSATZ,
           max(case
                   when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                       then GFCF.Rechtsform_Description
                   when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                       then EBCF.Rechtsform_Description
               end
               )            as Rechtsform,
           max(case
                   when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                       then GFCF.Rechtsform_Description
                   when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                       then EBCF.Rechtsform_Description
               end
               )            as GRP_Rechtsform,
           max(case
                   when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                       then NVL(GFCF.SACHANLAGEN, GFCF.L_Sachanlagen)
               end
               )            as SACHANLAGEN,
           max(case
                   when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                       then NVL(GFCF.SACHANLAGEN, GFCF.L_Sachanlagen)
               end
               )            as GRP_SACHANLAGEN,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.EBITDA
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.EBITDA
                       end
               )            as EBITDA,
           max(case
                   when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                       then GFCF.EBITDA
                   when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                       then EBCF.EBITDA
               end
               )            as GRP_EBITDA,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then NVL(GFCF.GOODWILL, GFCF.V_Goodwill, GFCF.L_Goodwill_Geschaefts_Firmenwert)
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.F40210
                       end
               )            as GOODWILL,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then NVL(GFCF.GOODWILL, GFCF.V_Goodwill, GFCF.L_Goodwill_Geschaefts_Firmenwert)
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.F40210
                       end
               )            as GRP_GOODWILL,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.NETTO_FINANZSCHULDEN_EBITDA
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then case
                                    when EBCF.EBITDA <> 0
                                        then NVL(EBCF.NETTOFINANZVERBINDLICHKEITEN, 0) / EBCF.EBITDA
                           end
                       end
               )            as NETTO_FINANZSCHULDEN_EBITDA,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.NETTO_FINANZSCHULDEN_EBITDA
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then case
                                    when EBCF.EBITDA <> 0
                                        then NVL(EBCF.NETTOFINANZVERBINDLICHKEITEN, 0) / EBCF.EBITDA
                           end
                       end
               )            as GRP_NETTO_FINANZSCHULDEN_EBITDA,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then NVL(GFCF.ZINSAUFWAND, GFCF.L_Zinsaufwendungen)
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.F26100
                       end
               )            as ZINSAUFWAND,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then NVL(GFCF.ZINSAUFWAND, GFCF.L_Zinsaufwendungen)
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.F26100
                       end
               )            as GRP_ZINSAUFWAND,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.DSCR
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.GESAMTSCHULDENDIENSTDECKUNGSQUOTE / 100
                       end
               )            as DSCR,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.DSCR
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.GESAMTSCHULDENDIENSTDECKUNGSQUOTE / 100
                       end
               )            as GRP_DSCR,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.Anlagevermoegen_BruttoHaftkapital
                       end
               )            as Anlagevermoegen_BruttoHaftkapital,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.Anlagevermoegen_BruttoHaftkapital
                       end
               )            as GRP_Anlagevermoegen_BruttoHaftkapital,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.BELEGUNGSRATE
                       end
               )            as BELEGUNGSRATE,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.BELEGUNGSRATE
                       end
               )            as GRP_BELEGUNGSRATE,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.DSCR_GEWERBEIMMOBILIEN
                       end
               )            as DSCR_GEWERBEIMMOBILIEN,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.DSCR_GEWERBEIMMOBILIEN
                       end
               )            as GRP_DSCR_GEWERBEIMMOBILIEN,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.DECKUNGSQUOTE
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.BETRIEBSMITTELDECKUNGSQUOTE / 100
                       end
               )            as DECKUNGSQUOTE,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.DECKUNGSQUOTE
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.BETRIEBSMITTELDECKUNGSQUOTE / 100
                       end
               )            as GRP_DECKUNGSQUOTE,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.DYNAMISCHER_VERSCHULDUNGSGRAD
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.DYNAMISCHERVERSCHULDUNGSGRADJAHRE / 100
                       end
               )            as DYNAMISCHER_VERSCHULDUNGSGRAD,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.DYNAMISCHER_VERSCHULDUNGSGRAD
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.DYNAMISCHERVERSCHULDUNGSGRADJAHRE / 100
                       end
               )            as GRP_DYNAMISCHER_VERSCHULDUNGSGRAD,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.GELDUMSCHLAGSDAUER_TAGE
                       end
               )            as GELDUMSCHLAGSDAUER_TAGE,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.GELDUMSCHLAGSDAUER_TAGE
                       end
               )            as GRP_GELDUMSCHLAGSDAUER_TAGE,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.Schuldendienst
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.F64000
                       end
               )            as KAPITALDIENST,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.Schuldendienst
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.F64000
                       end
               )            as GRP_KAPITALDIENST,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.SCHULDENRENDITE
                       end
               )            as SCHULDENRENDITE,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.SCHULDENRENDITE
                       end
               )            as GRP_SCHULDENRENDITE,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then NVL(GFCF.ANZAHL_MITARBEITER, GFCF.B_ANZAHL_MITARBEITER, GFCF.L_ANZAHL_MITARBEITER, GFCF.V_INT_ANZAHL_MITARBEITER, GFCF.V_HGB_ANZAHL_MITARBEITER)
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.F63200
                       end
               )            as ANZAHL_MITARBEITER,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then NVL(GFCF.ANZAHL_MITARBEITER, GFCF.B_ANZAHL_MITARBEITER, GFCF.L_ANZAHL_MITARBEITER, GFCF.V_INT_ANZAHL_MITARBEITER, GFCF.V_HGB_ANZAHL_MITARBEITER)
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.F63200
                       end
               )            as GRP_ANZAHL_MITARBEITER,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then NVL(GFCF.Dividenden_Entnahmen, GFCF.L_Ausschuettung, GFCF.V_HGB_Jahresueberschuss)
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.F62200
                       end
               )            as AUSSCHUETTUNG,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then NVL(GFCF.Dividenden_Entnahmen, GFCF.L_Ausschuettung, GFCF.V_HGB_Jahresueberschuss)
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.F62200
                       end
               )            as GRP_AUSSCHUETTUNG,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then NVL(GFCF.BILANZSUMME, GFCF.V_Total_Assets, GFCF.L_Bilanzsumme, GFCF.B_Bilanzsumme)
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.F49999
                       end
               )            as BILANZSUMME,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then NVL(GFCF.BILANZSUMME, GFCF.V_Total_Assets, GFCF.L_Bilanzsumme, GFCF.B_Bilanzsumme)
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.F49999
                       end
               )            as GRP_BILANZSUMME,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.BRUTTOVERSCHULDUNGSGRAD
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.VERSCHULDUNGSGRADGEARING
                       end
               )            as BRUTTOVERSCHULDUNGSGRAD,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.BRUTTOVERSCHULDUNGSGRAD
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.VERSCHULDUNGSGRADGEARING
                       end
               )            as GRP_BRUTTOVERSCHULDUNGSGRAD,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.EBIT
                       end
               )            as EBIT,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.EBIT
                       end
               )            as GRP_EBIT,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.LEVERAGE_RATIO
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.EBITDALEVERAGEJAHRE / 100
                       end
               )            as LEVERAGE_RATIO,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.LEVERAGE_RATIO
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.EBITDALEVERAGEJAHRE / 100
                       end
               )            as GRP_LEVERAGE_RATIO,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.HAFTENDE_EIGENKAPITAL_QUOTE_BRUTTO
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.EKWIRTSCHAFTLICHQUOTE / 100
                       end
               )            as EIGENKAPITAL_QUOTE,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.HAFTENDE_EIGENKAPITAL_QUOTE_BRUTTO
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.EKWIRTSCHAFTLICHQUOTE / 100
                       end
               )            as GRP_EIGENKAPITAL_QUOTE,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.EIGENKAPITALRENDITE_VOR_STEUERN
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.EKRENTABILITAET / 100
                       end
               )            as EKRENTABILITAET,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.EIGENKAPITALRENDITE_VOR_STEUERN
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.EKRENTABILITAET / 100
                       end
               )            as GRP_EKRENTABILITAET,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then NVL(GFCF.Summe_Eventualverb_finanzielle_Verpflicht, GFCF.L_Summe_Eventualverb_finanz_Verpfl)
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.F52330
                       end
               )            as EVENTUALVERBINDLICHKEITEN,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then NVL(GFCF.Summe_Eventualverb_finanzielle_Verpflicht, GFCF.L_Summe_Eventualverb_finanz_Verpfl)
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.F52330
                       end
               )            as GRP_EVENTUALVERBINDLICHKEITEN,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then NVL(GFCF.GesamtFinanzschulden, GFCF.L_Finanzverbindlichkeiten)
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.FINANZVERBINDLICHKEITEN
                       end
               )            as GESAMTFINANZSCHULDEN,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then NVL(GFCF.GesamtFinanzschulden, GFCF.L_Finanzverbindlichkeiten)
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.FINANZVERBINDLICHKEITEN
                       end
               )            as GRP_GESAMTFINANZSCHULDEN,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.GESAMTKAPITALRENDITE_VOR_STEUERN
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.GESAMTKAPITALRENTABILITAET / 100
                       end
               )            as GESAMTKAPITALRENDITE_VOR_STEUERN,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.GESAMTKAPITALRENDITE_VOR_STEUERN
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.GESAMTKAPITALRENTABILITAET / 100
                       end
               )            as GRP_GESAMTKAPITALRENDITE_VOR_STEUERN,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.Sachanlagevermoegen_Umsatz
                       end
               )            as Sachanlagevermoegen_Umsatz,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.Sachanlagevermoegen_Umsatz
                       end
               )            as GRP_Sachanlagevermoegen_Umsatz,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then NVL(GFCF.NETTO_HAFTKAPITAL_QUOTE, GFCF.L_NETTO_HAFTKAPITAL_QUOTE)
                       end
               )            as NETTO_HAFTKAPITAL_QUOTE,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then NVL(GFCF.NETTO_HAFTKAPITAL_QUOTE, GFCF.L_NETTO_HAFTKAPITAL_QUOTE)
                       end
               )            as GRP_NETTO_HAFTKAPITAL_QUOTE,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.NETTOMARGE
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.UMSATZRENTABILITAET
                       end
               )            as UMSATZRENTABILITAET,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.NETTOMARGE
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.UMSATZRENTABILITAET
                       end
               )            as GRP_UMSATZRENTABILITAET,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.NETTO_VERSCHULDUNGSGRAD
                       end
               )            as NETTO_VERSCHULDUNGSGRAD,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.NETTO_VERSCHULDUNGSGRAD
                       end
               )            as GRP_NETTO_VERSCHULDUNGSGRAD,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.Summe_mfr_lfr_Fremdkapital
                       end
               )            as Summe_mfr_lfr_Fremdkapital,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.Summe_mfr_lfr_Fremdkapital
                       end
               )            as GRP_Summe_mfr_lfr_Fremdkapital,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then NVL(GFCF.VERAENDERUNG_UMSATZ_GGUE_VORJAHR, GFCF.V_HGB_BRUTTOPRAEMIENWACHSTUM, GFCF.V_INT_BRUTTOPRAEMIENWACHSTUM)
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.NETTOUMSATZENTWICKLUNG
                       end
               )            as UMSATZENTWICKLUNG,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then NVL(GFCF.VERAENDERUNG_UMSATZ_GGUE_VORJAHR, GFCF.V_HGB_BRUTTOPRAEMIENWACHSTUM, GFCF.V_INT_BRUTTOPRAEMIENWACHSTUM)
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.NETTOUMSATZENTWICKLUNG
                       end
               )            as GRP_UMSATZENTWICKLUNG,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.ZINSDECKUNGSQUOTE
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.ZINSDECKUNGSQUOTE / 100
                       end
               )            as ZINSDECKUNGSQUOTE,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.ZINSDECKUNGSQUOTE
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.ZINSDECKUNGSQUOTE / 100
                       end
               )            as GRP_ZINSDECKUNGSQUOTE,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then NVL(GFCF.B_Betriebsergebnis_vor_Rivo, GFCF.Betriebsergebnis, GFCF.L_Leasingergebnis, GFCF.V_Underwriting_Result)
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.Betriebsergebnis
                       end
               )            as Betriebsergebnis,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then NVL(GFCF.B_Betriebsergebnis_vor_Rivo, GFCF.Betriebsergebnis, GFCF.L_Leasingergebnis, GFCF.V_Underwriting_Result)
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.Betriebsergebnis
                       end
               )            as GRP_Betriebsergebnis,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.B_Betriebsergebnis_nach_Rivo
                       end
               )            as B_Betriebsergebnis_nach_Rivo,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.B_Betriebsergebnis_nach_Rivo
                       end
               )            as GRP_B_Betriebsergebnis_nach_Rivo,
           max(case
                   when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                       then GFCF.NETTO_FINANZSCHULDEN
                   when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                       and NVL(EBCF.F51300, EBCF.F51200, EBCF.F52070) is not null
                       then NVL(EBCF.F51300, 0) + NVL(EBCF.F51200, 0) + NVL(EBCF.F52070, 0)
               end
               )            as NETTO_FINANZSCHULDEN,
           max(case
                   when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                       then GFCF.NETTO_FINANZSCHULDEN
                   when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                       and NVL(EBCF.F51300, EBCF.F51200, EBCF.F52070) is not null
                       then NVL(EBCF.F51300, 0) + NVL(EBCF.F51200, 0) + NVL(EBCF.F52070, 0)
               end
               )            as GRP_NETTO_FINANZSCHULDEN,
           max(case
                   when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                       then EBCF.CASHFLOWKENNZAHL1
               end
               )            as CASHFLOWKENNZAHL1,
           max(case
                   when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                       then EBCF.CASHFLOWKENNZAHL1
               end
               )            as GRP_CASHFLOWKENNZAHL1,
           max(case
                   when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                       then EBCF.CASHFLOWERFOLGSWIRKSERWEITERT
               end
               )            as CASHFLOWERFOLGSWIRKSERWEITERT,
           max(case
                   when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                       then EBCF.CASHFLOWERFOLGSWIRKSERWEITERT
               end
               )            as GRP_CASHFLOWERFOLGSWIRKSERWEITERT,
           max(case
                   when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                       then EBCF.SENSITIVIERTGESAMTSCHULDENDIENSTDECKUNGSQUOTE
               end
               )            as SENSITIVIERTGESAMTSCHULDENDIENSTDECKUNGSQUOTE,
           max(case
                   when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                       then EBCF.SENSITIVIERTGESAMTSCHULDENDIENSTDECKUNGSQUOTE
               end
               )            as GRP_SENSITIVIERTGESAMTSCHULDENDIENSTDECKUNGSQUOTE,
           max(case
                   when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                       then EBCF.KAPITALDIENSTGRENZEVORERSATZINVEST
               end
               )            as KAPITALDIENSTGRENZEVORERSATZINVEST,
           max(case
                   when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                       then EBCF.KAPITALDIENSTGRENZEVORERSATZINVEST
               end
               )            as GRP_KAPITALDIENSTGRENZEVORERSATZINVEST,
           max(case
                   when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                       then EBCF.TESTATART
               end
               )            as TESTATART,
           max(case
                   when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                       then EBCF.TESTATART
               end
               )            as GRP_TESTATART,
           max(case
                   when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                       then EBCF.RETURNONCAPITALEMPLOYED
               end
               )            as RETURNONCAPITALEMPLOYED,
           max(case
                   when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                       then EBCF.RETURNONCAPITALEMPLOYED
               end
               )            as GRP_RETURNONCAPITALEMPLOYED,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.STATEMENTDATE
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.STICHTAG
                       end
               )            as AKTUELLER_STICHTAG_KB,
           max(
                   case
                       when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                           then GFCF.STATEMENTDATE
                       when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                           then EBCF.STICHTAG
                       end
               )            as AKTUELLER_STICHTAG_EB,
           EGC.FLAG_GF_EBIL as SOURCE
    FROM (UNION_KUNDENNR as UKNR
        LEFT JOIN GF_DATE_DIF as GFCF ON UKNR.CLIENT_ID = GFCF.CLIENT_ID and GFCF.ABSTAND_DATEN_FLAG)
             LEFT JOIN EBIL_DATE_DIF as EBCF ON UKNR.CLIENT_ID = EBCF.CLIENT_ID and EBCF.ABSTAND_DATEN_FLAG
             LEFT JOIN EBIL_GF_CUST as EGC ON UKNR.CLIENT_ID = EGC.CLIENT_ID
    WHERE (GFCF.ABSTAND_DATEN_FLAG OR EBCF.ABSTAND_DATEN_FLAG)
    GROUP BY UKNR.CUT_OFF_DATE, UKNR.CLIENT_ID, UKNR.BRANCH, EGC.FLAG_GF_EBIL
)
SELECT CUT_OFF_DATE,
       GNI_KUNDE,
       BRANCH,
       AKTUELLER_STICHTAG_KB,
       AKTUELLER_STICHTAG_EB,
       SOURCE,
       KB_VON_PARENTCUSTOMER,
       CURRENCY_OC_KB,
       CURRENCY_OC_EB,
       CURRENCY,
       BRUTTO_HAFTKAPITAL,
       GRP_BRUTTO_HAFTKAPITAL,
       EIGENKAPITAL,
       GRP_EIGENKAPITAL,
       JAHRESUMSATZ,
       GRP_JAHRESUMSATZ,
       RECHTSFORM,
       GRP_RECHTSFORM,
       SACHANLAGEN,
       GRP_SACHANLAGEN,
       EBITDA,
       GRP_EBITDA,
       GOODWILL,
       GRP_GOODWILL,
       NETTO_FINANZSCHULDEN_EBITDA,
       GRP_NETTO_FINANZSCHULDEN_EBITDA,
       ZINSAUFWAND,
       GRP_ZINSAUFWAND,
       DSCR,
       GRP_DSCR,
       ANLAGEVERMOEGEN_BRUTTOHAFTKAPITAL,
       GRP_ANLAGEVERMOEGEN_BRUTTOHAFTKAPITAL,
       BELEGUNGSRATE,
       GRP_BELEGUNGSRATE,
       DSCR_GEWERBEIMMOBILIEN,
       GRP_DSCR_GEWERBEIMMOBILIEN,
       DECKUNGSQUOTE,
       GRP_DECKUNGSQUOTE,
       DYNAMISCHER_VERSCHULDUNGSGRAD,
       GRP_DYNAMISCHER_VERSCHULDUNGSGRAD,
       GELDUMSCHLAGSDAUER_TAGE,
       GRP_GELDUMSCHLAGSDAUER_TAGE,
       KAPITALDIENST,
       GRP_KAPITALDIENST,
       SCHULDENRENDITE,
       GRP_SCHULDENRENDITE,
       ANZAHL_MITARBEITER,
       GRP_ANZAHL_MITARBEITER,
       BETRIEBSERGEBNIS,
       GRP_BETRIEBSERGEBNIS,
       BILANZSUMME,
       GRP_BILANZSUMME,
       BRUTTOVERSCHULDUNGSGRAD,
       GRP_BRUTTOVERSCHULDUNGSGRAD,
       EBIT,
       GRP_EBIT,
       LEVERAGE_RATIO,
       GRP_LEVERAGE_RATIO,
       EIGENKAPITAL_QUOTE,
       GRP_EIGENKAPITAL_QUOTE,
       EKRENTABILITAET,
       GRP_EKRENTABILITAET,
       EVENTUALVERBINDLICHKEITEN,
       GRP_EVENTUALVERBINDLICHKEITEN,
       GESAMTFINANZSCHULDEN,
       GRP_GESAMTFINANZSCHULDEN,
       GESAMTKAPITALRENDITE_VOR_STEUERN,
       GRP_GESAMTKAPITALRENDITE_VOR_STEUERN,
       SACHANLAGEVERMOEGEN_UMSATZ,
       GRP_SACHANLAGEVERMOEGEN_UMSATZ,
       NETTO_HAFTKAPITAL_QUOTE,
       GRP_NETTO_HAFTKAPITAL_QUOTE,
       UMSATZRENTABILITAET,
       GRP_UMSATZRENTABILITAET,
       NETTO_VERSCHULDUNGSGRAD,
       GRP_NETTO_VERSCHULDUNGSGRAD,
       SUMME_MFR_LFR_FREMDKAPITAL,
       GRP_SUMME_MFR_LFR_FREMDKAPITAL,
       UMSATZENTWICKLUNG,
       GRP_UMSATZENTWICKLUNG,
       ZINSDECKUNGSQUOTE,
       GRP_ZINSDECKUNGSQUOTE,
       AUSSCHUETTUNG,
       GRP_AUSSCHUETTUNG,
       NETTO_FINANZSCHULDEN,
       GRP_NETTO_FINANZSCHULDEN,
       CASHFLOWKENNZAHL1,
       GRP_CASHFLOWKENNZAHL1,
       CASHFLOWERFOLGSWIRKSERWEITERT,
       GRP_CASHFLOWERFOLGSWIRKSERWEITERT,
       SENSITIVIERTGESAMTSCHULDENDIENSTDECKUNGSQUOTE,
       GRP_SENSITIVIERTGESAMTSCHULDENDIENSTDECKUNGSQUOTE,
       KAPITALDIENSTGRENZEVORERSATZINVEST,
       GRP_KAPITALDIENSTGRENZEVORERSATZINVEST,
       TESTATART,
       GRP_TESTATART,
       RETURNONCAPITALEMPLOYED,
       GRP_RETURNONCAPITALEMPLOYED,
       CURRENT_USER      as USER,
       CURRENT_TIMESTAMP as TIMESTAMP
FROM ALL_FIELDS
;

-- CI START FOR ALL TAPES

-- Current-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_CLIENT_EBIL_GLOBAL_FORMAT_EBA_CURRENT');
create table AMC.TABLE_CLIENT_EBIL_GLOBAL_FORMAT_EBA_CURRENT like CALC.VIEW_CLIENT_EBIL_GLOBAL_FORMAT_EBA distribute by hash (GNI_KUNDE) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CLIENT_EBIL_GLOBAL_FORMAT_EBA_CURRENT_GNI_KUNDE on AMC.TABLE_CLIENT_EBIL_GLOBAL_FORMAT_EBA_CURRENT (GNI_KUNDE);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_CLIENT_EBIL_GLOBAL_FORMAT_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCHES erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_CLIENT_EBIL_GLOBAL_FORMAT_EBA_CURRENT');
------------------------------------------------------------------------------------------------------------------------



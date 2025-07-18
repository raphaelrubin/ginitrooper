drop view CALC.VIEW_CLIENT_EBIL_GLOBAL_FORMAT;
create or replace view CALC.VIEW_CLIENT_EBIL_GLOBAL_FORMAT as
with EBIL as (
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
           BRANCH,
           BRANCH || '_' || NVL(OSPPERSONENNUMMER, case when FIRMENKENNNUMMER >0 then FIRMENKENNNUMMER end) as CLIENT_ID,
           case when BILANZART = 2 then 'EB'
              when BILANZART = 12 or BILANZART = 31 then 'KB'
              else 'N/A' end as BILANZART_FLAG
    FROM NLB.EBIL_CLIENTS_BALANCE_CURRENT
),
EBIL_DUP as (
    SELECT *,
           STICHTAG || CLIENT_ID || BILANZART_FLAG as KEY
    FROM EBIL
),
EBIL_VALID as (
    SELECT *
    FROM ( SELECT ED.*,
                  ROWNUMBER() over (PARTITION BY ED.KEY ORDER BY ED.ERFASSUNGSDATUM,ED.FIRMARECHTSFORM desc) as RN
           FROM EBIL_DUP ED) STATUS
    WHERE RN = 1
),
GF as (
   SELECT CUT_OFF_DATE,
          GPNUMBER,
          CUSTOMERNAME,
          STAEDTE,
          LAENDERSCHLUESSEL,
          BRANCHENSCHLUESSEL,
          RECHTSFORMID,
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
          BRANCH,
          PARENTCUSTOMERKEY,
          PARENTCUSTOMERRELEVANT,
          CUSTOMERKEY
   FROM NLB.GLOBAL_FORMAT_CLIENTS_BALANCE_CURRENT
),
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
           BRANCH,
           GDP.BRUTTO_HAFTKAPITAL*CM.RATE_TARGET_TO_EUR AS BRUTTO_HAFTKAPITAL,
           GDP.NETTO_FINANZSCHULDEN*CM.RATE_TARGET_TO_EUR AS NETTO_FINANZSCHULDEN,
           GDP.UMSATZERLOESE*CM.RATE_TARGET_TO_EUR AS UMSATZERLOESE,
           GDP.KONZESSIONEN_RECHTE_LIZENZEN*CM.RATE_TARGET_TO_EUR AS KONZESSIONEN_RECHTE_LIZENZEN,
           GDP.SACHANLAGEN*CM.RATE_TARGET_TO_EUR AS SACHANLAGEN,
           GDP.ABSCHREIBUNGEN_SACHANLAGEN*CM.RATE_TARGET_TO_EUR AS ABSCHREIBUNGEN_SACHANLAGEN,
           GDP.ABSCHREIBUNGEN_IMMAT_VERMOEGENSWERTE*CM.RATE_TARGET_TO_EUR AS ABSCHREIBUNGEN_IMMAT_VERMOEGENSWERTE,
           GDP.ERTRAG_ANLAGENABGANG*CM.RATE_TARGET_TO_EUR AS ERTRAG_ANLAGENABGANG,
           GDP.VERLUST_ANLAGENABGANG*CM.RATE_TARGET_TO_EUR AS VERLUST_ANLAGENABGANG,
           GDP.ZUSCHREIBUNGEN_SACHANLAGEN*CM.RATE_TARGET_TO_EUR AS ZUSCHREIBUNGEN_SACHANLAGEN,
           GDP.A_O_ABSCHREIBUNGEN_SACHANLAGEN*CM.RATE_TARGET_TO_EUR AS A_O_ABSCHREIBUNGEN_SACHANLAGEN,
           GDP.A_O_ABSCHREIBUNGEN_IMMAT_VERMOEGENSWERTE*CM.RATE_TARGET_TO_EUR AS A_O_ABSCHREIBUNGEN_IMMAT_VERMOEGENSWERTE,
           GDP.FLUESSIGE_MITTEL*CM.RATE_TARGET_TO_EUR AS FLUESSIGE_MITTEL,
           GDP.EBITDA*CM.RATE_TARGET_TO_EUR AS EBITDA,
           GDP.GOODWILL*CM.RATE_TARGET_TO_EUR AS GOODWILL,
           GDP.NETTO_FINANZSCHULDEN_EBITDA*CM.RATE_TARGET_TO_EUR AS NETTO_FINANZSCHULDEN_EBITDA,
           GDP.JAHRESUEBERSCHUSS_FEHLBETRAG *CM.RATE_TARGET_TO_EUR AS JAHRESUEBERSCHUSS_FEHLBETRAG,
           GDP.ZINSAUFWAND*CM.RATE_TARGET_TO_EUR AS ZINSAUFWAND,
           GDP.DSCR,
           GDP.UPDATEDAT,
           CM.ZIEL_WHRG,
           CM.RATE_TARGET_TO_EUR
    FROM GF as GDP
    left join IMAP.CURRENCY_MAP AS CM on GDP.CURRENCYISOCODE = CM.ZIEL_WHRG
    where (((exists(SELECT 1 From IMAP.CURRENCY_MAP as CM2 where CM.ZIEL_WHRG = CM2.ZIEL_WHRG AND CM.CUT_OFF_DATE < CM2.CUT_OFF_DATE))=FALSE))
),
-- TODO: Hinzufuegen von Konzernbilanzen an Tochter falls nicht selbst vorhanden + currency + ABSTAND_DATEN_FLAG
GF_DUP as (
    SELECT DISTINCT *,
                    BRANCH || '_' || GPNUMBER                                as CLIENT_ID,
                    STATEMENTDATE || BRANCH || '_' || GPNUMBER || CONSUNITNO as KEY
    FROM GF_EXCHANGE
),
GF_VALID as (
    SELECT *
    FROM ( SELECT GF.*,
                  ROWNUMBER() over (PARTITION BY GF.KEY ORDER BY GF.UPDATEDAT,GF.ACCTSTANDARD desc) as RN
           FROM GF_DUP GF) STATUS
    WHERE RN = 1
),
-- Filtern ueber Metadaten ergaenzen (Feld "Update" soll noch geliefert werden)
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
         COUNT(*)                                            as RANG,
         EV1.CLIENT_ID,
         EV1.BILANZART_FLAG,
         COUNT(*) || EV1.CLIENT_ID || EV1.BILANZART_FLAG     as HEUTE,
         cast(COUNT(*) - 1 as VARCHAR) || EV1.CLIENT_ID || EV1.BILANZART_FLAG as VORHER
  FROM EBIL_VALID EV1
    INNER JOIN EBIL_VALID EV2 ON (EV1.OSPPERSONENNUMMER = EV2.OSPPERSONENNUMMER) AND (EV1.STICHTAG <= EV2.STICHTAG)
    AND ((EV1.BILANZART = 2 AND EV2.BILANZART = 2) OR (EV1.BILANZART in (12, 31) AND EV2.BILANZART in (12,31)))
    GROUP BY EV1.CUT_OFF_DATE, EV1.BRANCH, EV1.FIRMENKENNNUMMER, EV1.FIRMATYP, EV1.FIRMARECHTSFORM, EV1.RECHTSGRUNDLAGE, EV1.ERFASSUNGSSCHEMA,
             EV1.BILANZART, EV1.GROESSENKLASSE, EV1.GROESSENKLASSE_2, EV1.STICHTAG, EV1.OSPPERSONENNUMMER,
             EV1.FIRMENNAME, EV1.BRADIWZ2008, EV1.ERFASSUNGSDATUM, EV1.F51300, EV1.F51200, EV1.F52070, EV1.F20100,
             EV1.F40200, EV1.F40210, EV1.F40230, EV1.F40300, EV1.F40400, EV1.F40500, EV1.F40600, EV1.F40650,
             EV1.F25500, EV1.F25510, EV1.F20410, EV1.F25910, EV1.F20420, EV1.F25700, EV1.F42800, EV1.F25999, EV1.EBITDA,
             EV1.HAFTENDESEKBRUTTO, EV1.NETTOFINANZVERBINDLICHKEITEN, EV1.GESAMTSCHULDENDIENSTDECKUNGSQUOTE, EV1.F26100, EV1.CLIENT_ID, EV1.BILANZART_FLAG
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
           COUNT(*)                                                 AS Rang,
           GFV1.CLIENT_ID,
           COUNT(*) || GFV1.CLIENT_ID || GFV1.CONSUNITNO     AS HEUTE,
           cast(COUNT(*) - 1 as VARCHAR) || GFV1.CLIENT_ID || GFV1.CONSUNITNO AS VORHER
    FROM GF_VALID AS GFV1
             INNER JOIN GF_VALID AS GFV2
                        ON (GFV1.CONSUNITNO = GFV2.CONSUNITNO) AND (GFV1.STATEMENTDATE <= GFV2.STATEMENTDATE) AND
                           (GFV1.GPNUMBER = GFV2.GPNUMBER)
    GROUP BY GFV1.CUT_OFF_DATE, GFV1.BRANCH, GFV1.GPNUMBER, GFV1.CUSTOMERNAME, GFV1.CONSUNITNO, GFV1.STATUS, GFV1.STATEMENTTYPE, GFV1.STATEMENTDATE,
             GFV1.CURRENCYISOCODE, GFV1.BRUTTO_HAFTKAPITAL, GFV1.NETTO_FINANZSCHULDEN, GFV1.UMSATZERLOESE,
             GFV1.KONZESSIONEN_RECHTE_LIZENZEN, GFV1.SACHANLAGEN, GFV1.ABSCHREIBUNGEN_SACHANLAGEN,
             GFV1.ABSCHREIBUNGEN_IMMAT_VERMOEGENSWERTE, GFV1.ERTRAG_ANLAGENABGANG, GFV1.VERLUST_ANLAGENABGANG,
             GFV1.ZUSCHREIBUNGEN_SACHANLAGEN, GFV1.A_O_ABSCHREIBUNGEN_SACHANLAGEN,
             GFV1.A_O_ABSCHREIBUNGEN_IMMAT_VERMOEGENSWERTE, GFV1.FLUESSIGE_MITTEL, GFV1.EBITDA, GFV1.GOODWILL,
             GFV1.NETTO_FINANZSCHULDEN_EBITDA, GFV1.JAHRESUEBERSCHUSS_FEHLBETRAG, GFV1.ZINSAUFWAND, GFV1.DSCR, GFV1.UPDATEDAT, GFV1.CLIENT_ID
),
EBIL_DATE_DIF as (
    SELECT EF1.*,
           case when EF1.RANG = 1 and (DAYS(EF1.CUT_OFF_DATE) - DAYS(EF1.STICHTAG)) > 730 then FALSE -- Abstand Tage 365*2
               when EF1.RANG = 2 and (DAYS(EF2.STICHTAG) - DAYS(EF1.STICHTAG)) > 367 OR (DAYS(EF1.CUT_OFF_DATE) - DAYS(EF1.STICHTAG)) > 1095 then FALSE -- 365*3
               when EF1.RANG = 3 and (DAYS(EF2.STICHTAG) - DAYS(EF1.STICHTAG)) > 367 OR (DAYS(EF1.CUT_OFF_DATE) - DAYS(EF1.STICHTAG)) > 1460 then FALSE -- 365*4
               else TRUE end as ABSTAND_DATEN_FLAG,
           case when EF1.RANG = 1 then (DAYS(EF1.CUT_OFF_DATE) - DAYS(EF1.STICHTAG)) else DAYS(EF2.STICHTAG) - DAYS(EF1.STICHTAG) end as ABSTAND_IN_TAGEN
    FROM EBIL_FINISH EF1
    LEFT JOIN EBIL_FINISH AS EF2 ON EF1.VORHER = EF2.HEUTE
    WHERE EF1.OSPPERSONENNUMMER is not null and EF1.RANG < 7
),
GF_DATE_DIF as (
    SELECT GF1.*,
           case when GF1.RANG = 1 and (DAYS(GF1.CUT_OFF_DATE) - DAYS(GF1.STATEMENTDATE)) > 730 then FALSE -- Abstand Tage 365*2
               when GF1.RANG = 2 and (DAYS(GF2.STATEMENTDATE) - DAYS(GF1.STATEMENTDATE)) > 367 OR (DAYS(GF1.CUT_OFF_DATE) - DAYS(GF1.STATEMENTDATE)) > 1095 then FALSE -- 365*3
               when GF1.RANG = 3 and (DAYS(GF2.STATEMENTDATE) - DAYS(GF1.STATEMENTDATE)) > 367 OR (DAYS(GF1.CUT_OFF_DATE) - DAYS(GF1.STATEMENTDATE)) > 1460 then FALSE -- 365*4
               else TRUE end as ABSTAND_DATEN_FLAG,
           case when GF1.RANG = 1 then (DAYS(GF1.CUT_OFF_DATE) - DAYS(GF1.STATEMENTDATE)) else DAYS(GF2.STATEMENTDATE) - DAYS(GF1.STATEMENTDATE) end as ABSTAND_IN_TAGEN
    FROM GF_FINISH GF1
    LEFT JOIN GF_FINISH AS GF2 ON GF1.VORHER = GF2.HEUTE
    WHERE GF1.RANG < 7
),
EBIL_CAPEX_FLG as (
    SELECT *,
        case when BILANZART_FLAG = 'EB'
            and (F40200 is null or F40200 = 0)
            and (F40210 is null or F40210 = 0)
            and (F40230 is null or F40230 = 0)
            and (F40300 is null or F40300 = 0)
            and (F40400 is null or F40400 = 0)
            and (F40500 is null or F40500 = 0)
            and (F40600 is null or F40600 = 0)
            and (F40650 is null or F40650 = 0)
            and (F25500 is null or F25500 = 0)
            and (F25510 is null or F25510 = 0)
            and (F20410 is null or F20410 = 0)
            and (F25910 is null or F25910 = 0)
            and (F20420 is null or F20420 = 0)
            and (F25700 is null or F25700 = 0) then FALSE
             else TRUE end as CAPEX_FLAG,
        case
            when F40200 is null and F40230 is null and F40300 is null and F40400 is null and F40500 is null and
                 F40600 is null and F40650 is null and F25500 is null and F25510 is null and F20410 is null and
                 F25910 is null and F20420 is null and F25700 is null and F51300 is null and F51200 is null and
                 F52070 is null and F20100 is null and F25700 is null and F42800 is null and F25999 is null and
                 EBITDA is null and HAFTENDESEKBRUTTO is null and NETTOFINANZVERBINDLICHKEITEN is null and
                 F26100 is null and GESAMTSCHULDENDIENSTDECKUNGSQUOTE is null
            then FALSE
              else TRUE end as EMPTY_FLAG
    FROM EBIL_DATE_DIF
    WHERE ABSTAND_DATEN_FLAG
),
GF_CAPEX_FLG as (
    SELECT *,
           case
               when CONSUNITNO = 0
                   and (KONZESSIONEN_RECHTE_LIZENZEN is null OR KONZESSIONEN_RECHTE_LIZENZEN = 0)
                   and (SACHANLAGEN is null OR SACHANLAGEN = 0)
                   and (ABSCHREIBUNGEN_SACHANLAGEN is null OR ABSCHREIBUNGEN_SACHANLAGEN = 0)
                   and (ABSCHREIBUNGEN_IMMAT_VERMOEGENSWERTE is null OR ABSCHREIBUNGEN_IMMAT_VERMOEGENSWERTE = 0)
                   and (ERTRAG_ANLAGENABGANG is null OR ERTRAG_ANLAGENABGANG = 0)
                   and (VERLUST_ANLAGENABGANG is null OR VERLUST_ANLAGENABGANG = 0)
                   and (ZUSCHREIBUNGEN_SACHANLAGEN is null OR ZUSCHREIBUNGEN_SACHANLAGEN = 0)
                   and (A_O_ABSCHREIBUNGEN_SACHANLAGEN is null OR A_O_ABSCHREIBUNGEN_SACHANLAGEN = 0)
                   and (A_O_ABSCHREIBUNGEN_IMMAT_VERMOEGENSWERTE is null OR A_O_ABSCHREIBUNGEN_IMMAT_VERMOEGENSWERTE = 0)
                   then FALSE
               else TRUE end as CAPEX_FLAG,
           case
               when KONZESSIONEN_RECHTE_LIZENZEN is null and
                    SACHANLAGEN is null and
                    ABSCHREIBUNGEN_SACHANLAGEN is null and
                    ABSCHREIBUNGEN_IMMAT_VERMOEGENSWERTE is null and
                    ERTRAG_ANLAGENABGANG is null and
                    VERLUST_ANLAGENABGANG is null and
                    ZUSCHREIBUNGEN_SACHANLAGEN is null and
                    A_O_ABSCHREIBUNGEN_SACHANLAGEN is null and
                    A_O_ABSCHREIBUNGEN_IMMAT_VERMOEGENSWERTE is null and
                    BRUTTO_HAFTKAPITAL is null and
                    NETTO_FINANZSCHULDEN is null and
                    UMSATZERLOESE is null and
                    FLUESSIGE_MITTEL is null and
                    EBITDA is null and
                    GOODWILL is null and
                    NETTO_FINANZSCHULDEN_EBITDA is null and
                    JAHRESUEBERSCHUSS_FEHLBETRAG is null and
                    ZINSAUFWAND is null and
                    DSCR is null
                    then FALSE
               else TRUE end as EMPTY_FLAG
    FROM GF_DATE_DIF
    WHERE ABSTAND_DATEN_FLAG
),
UNION_KUNDENNR as (
    SELECT DISTINCT SQ.CUT_OFF_DATE,
                    SQ.CLIENT_ID,
                    SQ.BRANCH
    FROM (SELECT CUT_OFF_DATE,CLIENT_ID, BRANCH
          FROM GF_FINISH
          WHERE GPNUMBER is not null
          UNION ALL
          SELECT CUT_OFF_DATE,CLIENT_ID, BRANCH
          FROM EBIL_FINISH
          WHERE OSPPERSONENNUMMER is not null) as SQ
),
EBIL_GF_CUST as (
    SELECT SQ.*
    FROM (SELECT NVL(E.CLIENT_ID, G.CLIENT_ID) as CLIENT_ID,
                 E.MaxStichtag as Stichtag,
                 E.MaxErfassungsdatum as Erfassungsdatum,
                 G.MaxStatementDate as STATEMENTDATE,
                 G.MaxUpdatedat as UPDATEDAT,
                 case when E.CLIENT_ID is null then 'GF'
                 else (case when G.CLIENT_ID is null then 'EBIL'
                       else (case when NVL(E.MaxStichtag, date('1900-01-01')) > NVL(G.MaxStatementDate, date('1900-01-01')) OR
                                      (NVL(E.MaxStichtag, date('1900-01-01')) = NVL(G.MaxStatementDate, date('1900-01-01')) AND
                                       NVL(E.MaxErfassungsdatum, date('1900-01-01')) > NVL(G.MaxUpdatedat, date('1900-01-01')))
                             then 'EBIL'
                             else 'GF' end)
                       end)
                 end as FLAG_GF_EBIL
          FROM (SELECT CLIENT_ID,
                       max(STICHTAG) as MaxStichtag,
                       max(ERFASSUNGSDATUM) as MaxErfassungsdatum
                FROM EBIL_FINISH
                GROUP BY CLIENT_ID) as E
          LEFT JOIN (
              SELECT CLIENT_ID,
                     max(STATEMENTDATE) as MaxStatementDate,
                     max(UPDATEDAT) as MaxUpdatedat
              from GF_FINISH
              GROUP BY CLIENT_ID) as G
          on E.CLIENT_ID = G.CLIENT_ID
          UNION
          SELECT NVL(G.CLIENT_ID, E.CLIENT_ID) as CLIENT_ID,
                 E.MaxStichtag as Stichtag,
                 E.MaxErfassungsdatum as Erfassungsdatum,
                 G.MaxStatementDate as STATEMENTDATE,
                 G.MaxUpdateDat as UPDATEDAT,
                 case when G.CLIENT_ID is null then 'EBIL'
                 else (case when E.CLIENT_ID is null then 'GF'
                       else (case when NVL(G.MaxStatementDate, date('1900-01-01')) > NVL(E.MaxStichtag, date('1900-01-01')) OR
                                      (NVL(G.MaxStatementDate, date('1900-01-01')) = NVL(E.MaxStichtag, date('1900-01-01')) AND
                                       NVL(G.MaxUpdatedat, date('1900-01-01')) > NVL(E.MaxErfassungsdatum, date('1900-01-01')))
                             then 'GF'
                             else 'EBIL' end)
                       end)
                 end as FLAG_GF_EBIL
          FROM (SELECT CLIENT_ID,
                     max(STATEMENTDATE) as MaxStatementDate,
                     max(UPDATEDAT) as MaxUpdatedat
              from GF_FINISH
              GROUP BY CLIENT_ID) as G
          LEFT JOIN (
                SELECT CLIENT_ID,
                       max(STICHTAG) as MaxStichtag,
                       max(ERFASSUNGSDATUM) as MaxErfassungsdatum
                FROM EBIL_FINISH
                GROUP BY CLIENT_ID) as E
        on G.CLIENT_ID = E.CLIENT_ID
        ) as SQ
),
EZB_FIELDS as (
    SELECT
    UKNR.CUT_OFF_DATE,
    UKNR.CLIENT_ID,
    UKNR.BRANCH,
    max(case when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                then GFCF.EBITDA
             when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                then EBCF.EBITDA
        end
    ) as GRP_EBITDA,
    max(case when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                then GFCF.BRUTTO_HAFTKAPITAL
             when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                then EBCF.HAFTENDESEKBRUTTO
        end
    ) as GRP_EQTY,
    max(case when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1 and EGC.FLAG_GF_EBIL = 'GF'
                then GFCF.NETTO_FINANZSCHULDEN
             when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB' and EGC.FLAG_GF_EBIL = 'EBIL'
                 and NVL(EBCF.F51300,EBCF.F51200,EBCF.F52070) is not null
                then NVL(EBCF.F51300, 0)+ NVL(EBCF.F51200, 0)+NVL(EBCF.F52070, 0)
        end
    ) as GRP_NT_DBT,
    max(case when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                then GFCF.UMSATZERLOESE
             when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                then EBCF.F20100
        end
    ) as ANNL_TRNVR_LE,
    max(case when GFCF.RANG = 2 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                then GFCF.UMSATZERLOESE
             when EBCF.RANG = 2 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                 then EBCF.F20100
        end
    ) as ANNL_TRNVR_PRVS,
    max(case when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                then GFCF.UMSATZERLOESE/12
             when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                then EBCF.F20100/12
        end
    ) as MNTHL_TRNVR,
    max(
        case when (GFCF.RANG = 2 and GFCF.ABSTAND_DATEN_FLAG = FALSE) OR (EBCF.RANG = 2 and EBCF.ABSTAND_DATEN_FLAG = FALSE) then null
            when GFCF.RANG = 2 and GFCF.CONSUNITNO = 0 and GFCF.CAPEX_FLAG and EGC.FLAG_GF_EBIL = 'GF'
                then NVL(GFCF.KONZESSIONEN_RECHTE_LIZENZEN,0) + NVL(GFCF.SACHANLAGEN,0)
            when EBCF.RANG = 2 and BILANZART_FLAG = 'EB' and EBCF.CAPEX_FLAG and EGC.FLAG_GF_EBIL = 'EBIL'
                then NVL(EBCF.F40200,0)-NVL(EBCF.F40210,0)-NVL(EBCF.F40230,0) + NVL(EBCF.F40300,0)
                 + NVL(EBCF.F40400,0) + NVL(EBCF.F40500,0) + NVL(EBCF.F40600,0) + NVL(EBCF.F40650,0)
        else null
        end
    ) -
    max(
        case when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and GFCF.CAPEX_FLAG and EGC.FLAG_GF_EBIL = 'GF'
                then NVL(GFCF.KONZESSIONEN_RECHTE_LIZENZEN,0) + NVL(GFCF.SACHANLAGEN,0)
                + NVL(GFCF.ABSCHREIBUNGEN_SACHANLAGEN,0) + NVL(GFCF.ABSCHREIBUNGEN_IMMAT_VERMOEGENSWERTE,0)
                - NVL(GFCF.ERTRAG_ANLAGENABGANG,0) + NVL(GFCF.VERLUST_ANLAGENABGANG,0)
                - NVL(GFCF.ZUSCHREIBUNGEN_SACHANLAGEN,0) + NVL(A_O_ABSCHREIBUNGEN_SACHANLAGEN,0)
                + NVL(GFCF.A_O_ABSCHREIBUNGEN_IMMAT_VERMOEGENSWERTE,0)
                when EBCF.RANG = 1 and BILANZART_FLAG = 'EB' and EBCF.CAPEX_FLAG and EGC.FLAG_GF_EBIL = 'EBIL'
                then NVL(EBCF.F40200,0)-NVL(EBCF.F40210,0)-NVL(EBCF.F40230,0) + NVL(EBCF.F40300,0)
                + NVL(EBCF.F40400,0) + NVL(EBCF.F40500,0) + NVL(EBCF.F40600,0) + NVL(EBCF.F40650,0)
                + NVL(EBCF.F25500,0) - NVL(EBCF.F25510,0) - NVL(EBCF.F20410,0) + NVL(EBCF.F25910,0)
                - NVL(EBCF.F20420,0) + NVL(EBCF.F25700,0)
        else null
        end
    ) as CAPEX,
    max(
        case when (GFCF.RANG = 3 and GFCF.ABSTAND_DATEN_FLAG = FALSE) OR (EBCF.RANG = 3 and EBCF.ABSTAND_DATEN_FLAG = FALSE)
                then null
            when GFCF.RANG = 3 and GFCF.CONSUNITNO = 0 and GFCF.CAPEX_FLAG and EGC.FLAG_GF_EBIL = 'GF'
                then NVL(GFCF.KONZESSIONEN_RECHTE_LIZENZEN,0) + NVL(GFCF.SACHANLAGEN,0)
            when EBCF.RANG = 3 and BILANZART_FLAG = 'EB' and EBCF.CAPEX_FLAG and EGC.FLAG_GF_EBIL = 'EBIL'
                then NVL(EBCF.F40200,0)-NVL(EBCF.F40210,0)-NVL(EBCF.F40230,0) + NVL(EBCF.F40300,0)
                + NVL(EBCF.F40400,0) + NVL(EBCF.F40500,0) + NVL(EBCF.F40600,0) + NVL(EBCF.F40650,0)
        else null
        end
    ) -
    max(
        case when GFCF.RANG = 2 and GFCF.CONSUNITNO = 0 and GFCF.CAPEX_FLAG and EGC.FLAG_GF_EBIL = 'GF'
                then NVL(GFCF.KONZESSIONEN_RECHTE_LIZENZEN,0) + NVL(GFCF.SACHANLAGEN,0)
                + NVL(GFCF.ABSCHREIBUNGEN_SACHANLAGEN,0) + NVL(GFCF.ABSCHREIBUNGEN_IMMAT_VERMOEGENSWERTE,0)
                - NVL(GFCF.ERTRAG_ANLAGENABGANG,0) + NVL(GFCF.VERLUST_ANLAGENABGANG,0)
                - NVL(GFCF.ZUSCHREIBUNGEN_SACHANLAGEN,0) + NVL(A_O_ABSCHREIBUNGEN_SACHANLAGEN,0)
                + NVL(GFCF.A_O_ABSCHREIBUNGEN_IMMAT_VERMOEGENSWERTE,0)
             when EBCF.RANG = 2 and BILANZART_FLAG = 'EB' and EBCF.CAPEX_FLAG and EGC.FLAG_GF_EBIL = 'EBIL'
                then NVL(EBCF.F40200,0)-NVL(EBCF.F40210,0)-NVL(EBCF.F40230,0) + NVL(EBCF.F40300,0)
                + NVL(EBCF.F40400,0) + NVL(EBCF.F40500,0) + NVL(EBCF.F40600,0) + NVL(EBCF.F40650,0)
                + NVL(EBCF.F25500,0) - NVL(EBCF.F25510,0) - NVL(EBCF.F20410,0) + NVL(EBCF.F25910,0)
                - NVL(EBCF.F20420,0) + NVL(EBCF.F25700,0)
        else null
        end
    ) as CAPEX_PRVS,
    max (
        case when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                then GFCF.FLUESSIGE_MITTEL
             when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                 then EBCF.F42800
        end
    ) as CSH,
    max (
        case when GFCF.RANG = 2 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                then GFCF.FLUESSIGE_MITTEL
             when EBCF.RANG = 2 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                 then EBCF.F42800
        end
    ) as CSH_PRVS,
    max (
        case when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                then GFCF.EBITDA
             when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                then EBCF.EBITDA
        end
    ) as EBITDA,
    max (
        case when GFCF.RANG = 2 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                then GFCF.EBITDA
             when EBCF.RANG = 2 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                then EBCF.EBITDA
        end
    ) as EBITDA_PRVS,
    max (
        case when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                then GFCF.BRUTTO_HAFTKAPITAL
             when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                then EBCF.HAFTENDESEKBRUTTO
        end
    ) as EQTY,
    max (
        case when GFCF.RANG = 2 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                then GFCF.BRUTTO_HAFTKAPITAL
             when EBCF.RANG = 2 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                 then EBCF.HAFTENDESEKBRUTTO
        end
    ) as EQTY_PRVS,
    max (
        case when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                then GFCF.GOODWILL
             when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                 then EBCF.F40210
        end
    ) as GDWILL,
    max (
        case when GFCF.RANG = 2 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                then GFCF.GOODWILL
             when EBCF.RANG = 2 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                then EBCF.F40210
        end
    ) as GDWILL_PRVS,
    max (
        case when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                then GFCF.NETTO_FINANZSCHULDEN_EBITDA
             when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                 then case when EBCF.EBITDA<>0
                        then NVL(EBCF.NETTOFINANZVERBINDLICHKEITEN,0)/EBCF.EBITDA
                      end
        end
    ) as LVRG,
    max (
        case when GFCF.RANG = 2 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                then GFCF.NETTO_FINANZSCHULDEN_EBITDA
             when EBCF.RANG = 2 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                 then case when EBCF.EBITDA<>0
                        then NVL(EBCF.NETTOFINANZVERBINDLICHKEITEN,0)/EBCF.EBITDA
                      end
        end
    ) as LVRG_PRVS,
    max (
        case when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                then GFCF.JAHRESUEBERSCHUSS_FEHLBETRAG
             when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                 then EBCF.F25999
        end
    ) as NT_INCM,
    max (
        case when GFCF.RANG = 2 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                then GFCF.JAHRESUEBERSCHUSS_FEHLBETRAG
             when EBCF.RANG = 2 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                 then EBCF.F25999
        end
    ) as NT_INCM_PRVS,
    max (
        case when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                then GFCF.DSCR
             when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                then (EBCF.GESAMTSCHULDENDIENSTDECKUNGSQUOTE/100)
        end
    ) as DBT_SRVC_RT,
    max (
        case when GFCF.RANG = 2 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                then GFCF.DSCR
             when EBCF.RANG = 2 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                then (EBCF.GESAMTSCHULDENDIENSTDECKUNGSQUOTE/100)
        end
    ) as DBT_SRVC_RT_12M,
    max (
        case when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0 and EGC.FLAG_GF_EBIL = 'GF'
                then GFCF.ZINSAUFWAND
             when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB' and EGC.FLAG_GF_EBIL = 'EBIL'
                then EBCF.F26100
        end
    ) as TTL_INTRST_PD,
    max (
        case when GFCF.RANG = 1 and GFCF.CONSUNITNO = 1
                then GFCF.STATEMENTDATE
             when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'KB'
                then EBCF.STICHTAG
        end
    ) as AKTUELLER_STICHTAG_KB,
    max (
        case when GFCF.RANG = 1 and GFCF.CONSUNITNO = 0
                then GFCF.STATEMENTDATE
             when EBCF.RANG = 1 and EBCF.BILANZART_FLAG = 'EB'
                then EBCF.STICHTAG
        end
    ) as AKTUELLER_STICHTAG_EB,
    max (
        case when GFCF.RANG = 2 and GFCF.CONSUNITNO = 1
                then GFCF.STATEMENTDATE
             when EBCF.RANG = 2 and EBCF.BILANZART_FLAG = 'KB' then EBCF.STICHTAG
        end
    ) as PRVS_STICHTAG_KB,
    max (
        case when GFCF.RANG = 2 and GFCF.CONSUNITNO = 0
                then GFCF.STATEMENTDATE
             when EBCF.RANG = 2 and EBCF.BILANZART_FLAG = 'EB'
                then EBCF.STICHTAG
        end
    ) as PRVS_STICHTAG_EB
    FROM (UNION_KUNDENNR as UKNR
        LEFT JOIN GF_CAPEX_FLG as GFCF ON UKNR.CLIENT_ID = GFCF.CLIENT_ID)
        LEFT JOIN EBIL_CAPEX_FLG as EBCF ON UKNR.CLIENT_ID = EBCF.CLIENT_ID
        LEFT JOIN EBIL_GF_CUST as EGC ON UKNR.CLIENT_ID = EGC.CLIENT_ID
    WHERE (GFCF.ABSTAND_DATEN_FLAG  OR EBCF.ABSTAND_DATEN_FLAG )
        AND (GFCF.EMPTY_FLAG  OR EBCF.EMPTY_FLAG )
    GROUP BY UKNR.CUT_OFF_DATE, UKNR.CLIENT_ID, UKNR.BRANCH
)
SELECT CUT_OFF_DATE,
       BRANCH,
       CLIENT_ID,
       GRP_EBITDA,
       GRP_EQTY,
       GRP_NT_DBT,
       ANNL_TRNVR_LE,
       ANNL_TRNVR_PRVS,
       MNTHL_TRNVR,
       CAPEX,
       CAPEX_PRVS,
       CSH,
       CSH_PRVS,
       EBITDA,
       EBITDA_PRVS,
       EQTY,
       EQTY_PRVS,
       GDWILL,
       GDWILL_PRVS,
       LVRG,
       LVRG_PRVS,
       NT_INCM,
       NT_INCM_PRVS,
       DBT_SRVC_RT,
       DBT_SRVC_RT_12M,
       TTL_INTRST_PD,
       AKTUELLER_STICHTAG_KB,
       AKTUELLER_STICHTAG_EB,
       PRVS_STICHTAG_KB,
       PRVS_STICHTAG_EB,
       CURRENT_USER as USER,
       CURRENT_TIMESTAMP as TIMESTAMP_LOAD
FROM EZB_FIELDS;

-- CI START FOR ALL TAPES

-- Current-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_CLIENT_EBIL_GLOBAL_FORMAT_CURRENT');
create table AMC.TABLE_CLIENT_EBIL_GLOBAL_FORMAT_CURRENT like CALC.VIEW_CLIENT_EBIL_GLOBAL_FORMAT distribute by hash(CLIENT_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CLIENT_EBIL_GLOBAL_FORMAT_CURRENT_KUNDENNR on AMC.TABLE_CLIENT_EBIL_GLOBAL_FORMAT_CURRENT (CLIENT_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_CLIENT_EBIL_GLOBAL_FORMAT_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCHES erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_CLIENT_EBIL_GLOBAL_FORMAT_CURRENT');
------------------------------------------------------------------------------------------------------------------------

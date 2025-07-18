
-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_GUARANTORS;
create or replace view CALC.VIEW_GUARANTORS as
with
    -- Garantorinformationen (roh)
    GUARANTORS_RAW as (
        select GUARANTOR_INFORMATION.*,row_number() over (PARTITION BY KUNDENNUMMER,CUTOFFDATE) as NBR
        from CALC.VIEW_PRE_GUARANTOR_NLB as GUARANTOR_INFORMATION
        inner join CALC.SWITCH_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_CURRENT as CLIENT_TO_PARTNER on (CLIENT_TO_PARTNER.BRANCH_NOBORROWER,
                                                                                            CLIENT_TO_PARTNER.CLIENT_ID_NOBORROWER,
                                                                                            CLIENT_TO_PARTNER.CUT_OFF_DATE) = (GUARANTOR_INFORMATION.BRANCH, GUARANTOR_INFORMATION.KUNDENNUMMER_GARANT, GUARANTOR_INFORMATION.CUTOFFDATE)
            union all
        select GUARANTOR_INFORMATION.*,row_number() over (PARTITION BY KUNDENNUMMER,CUTOFFDATE) as NBR
        from CALC.VIEW_PRE_GUARANTOR_BLB as GUARANTOR_INFORMATION
        inner join CALC.SWITCH_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_CURRENT as CLIENT_TO_PARTNER on (CLIENT_TO_PARTNER.BRANCH_NOBORROWER,CLIENT_TO_PARTNER.CLIENT_ID_NOBORROWER,CLIENT_TO_PARTNER.CUT_OFF_DATE) = (GUARANTOR_INFORMATION.BRANCH, GUARANTOR_INFORMATION.KUNDENNUMMER_GARANT, GUARANTOR_INFORMATION.CUTOFFDATE)
    ),
    -- fix für unterschiedliche Länderbezeichnungen (gemischt ALPHA2 und KNK+TXT => ALPHA2)
    GUARANTORS_PRE as (
        select GUARANTORS_RAW.*, COALESCE(LAENDERMAP.COUNTRY_APLHA2,COUNTRY_GARANT) AS COUNTRY_APLHA2
        from GUARANTORS_RAW
        left join IMAP.ISO_LAENDER AS LAENDERMAP on LEFT(GUARANTORS_RAW.COUNTRY_GARANT,3) = LPAD(LAENDERMAP.LNDKNK,3,'0')
    ),
    -- Distincte Garantoren + Informationen
    GUARANTORS as (
        select distinct
            CUTOFFDATE                              AS CUT_OFF_DATE,
            BRANCH                                  AS BRANCH,
            KUNDENNUMMER_GARANT                     AS CLIENT_NO,
            BILANZWAEHRUNG_GARANT                   AS GUARANTOR_BALANCESHEET_CURRENCY_ISO,
            EBITDA_GARANT                           AS GUARANTOR_BALANCESHEET_EBITDA,
            BILANZSTICHTAG_GARANT                   AS GUARANTOR_BALANCESHEET_DATE,
            GESAMTUMSATZ_GARANT                     AS GUARANTOR_BALANCESHEET_TURNOVER_TOTAL,
            COUNTRY_APLHA2                          AS GUARANTOR_BALANCESHEET_COUNTRY_ALPHA2,
            STAMMKAPITAL_GARANT                     AS GUARANTOR_BALANCESHEET_CAPITAL_SHARE,
            CASE
                when lower(RECOURSE) = 'ja' then 1
                when lower(RECOURSE) = 'nein' then 0
                else RECOURSE
            end                                     AS RECOURSE,               -- Risikorückbehalt?
            REASON                                  AS RECOURSE_REASON,        -- Grund für Risikorückbehalt?
            NBR                                     AS ORDER_NUMBER,           -- Nummer um Garantoren (nach Wichtigkeit?) zu sortieren
            'GUARANTOR'                             AS ROLE,
            KOMMENTAR                               AS COMMENT                 -- Kommentarspalte
        from GUARANTORS_PRE
    )
select * from GUARANTORS
    ;
------------------------------------------------------------------------------------------------------------------------

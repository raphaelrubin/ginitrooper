-- VIEW erstellen
drop view CALC.VIEW_AVALOQ_PAST_DUE;
create or replace view CALC.VIEW_AVALOQ_PAST_DUE as
with
    AVALOQ_PAST_DUE as (
        select distinct * from ANL.AVALOQ_PAST_DUE
    ),
    AVALOQ_PAST_DUE_FACILITIES as (
        select distinct HO_ACC_NUMBER, CUT_OFF_DATE, BU_CCY from ANL.AVALOQ_PAST_DUE
    ),
    TILGUNG as (
        select distinct HO_ACC_NUMBER                   as FACILITY_ID,
                        -sum(RDMPT_OUTSTANDING_BU_CCY)  as PAST_DUE_AMOUNT_EUR,
                        -sum(RDMPT_OUTSTANDING_POS_CCY) as PAST_DUE_AMOUNT_TC,
                        rtrim(ZINSSATZ, '%')            as PAST_DUE_ALL_IN_RATE,
                        BEGIN_DATE                      as PAST_DUE_SINCE,
                        --POS_LK                                          as  GEBUCHT_AUF, -- seit Septemberlieferung 2020 nicht mehr enthalten
                        CUT_OFF_DATE
        from AVALOQ_PAST_DUE
        where RDMPT_OUTSTANDING_BU_CCY is not null
        group by HO_ACC_NUMBER, BEGIN_DATE, CUT_OFF_DATE, ZINSSATZ
    ),
    ZINSEN as (
        select distinct HO_ACC_NUMBER                  as FACILITY_ID,
                        -sum(INTR_OUTSTANDING_BU_CCY)  as PAST_DUE_AMOUNT_EUR,
                        -sum(INTR_OUTSTANDING_POS_CCY) as PAST_DUE_AMOUNT_TC,
                        rtrim(ZINSSATZ, '%')           as PAST_DUE_ALL_IN_RATE,
                        BEGIN_DATE                     as PAST_DUE_SINCE,
                        --POS_LK                                          as  GEBUCHT_AUF, -- seit Septemberlieferung 2020 nicht mehr enthalten
                        CUT_OFF_DATE
        from AVALOQ_PAST_DUE
        where INTR_OUTSTANDING_BU_CCY is not null
        group by HO_ACC_NUMBER, BEGIN_DATE, CUT_OFF_DATE, ZINSSATZ
    ),
    FEES as (
        select distinct HO_ACC_NUMBER                 as FACILITY_ID,
                        -sum(FEE_OUTSTANDING_BU_CCY)  as PAST_DUE_AMOUNT_EUR,
                        -sum(FEE_OUTSTANDING_POS_CCY) as PAST_DUE_AMOUNT_TC,
                        rtrim(ZINSSATZ, '%')          as PAST_DUE_ALL_IN_RATE,
                        BEGIN_DATE                    as PAST_DUE_SINCE,
                        --POS_LK                                          as  GEBUCHT_AUF, -- seit Septemberlieferung 2020 nicht mehr enthalten
                        CUT_OFF_DATE
        from AVALOQ_PAST_DUE
        where FEE_OUTSTANDING_BU_CCY is not null
        group by HO_ACC_NUMBER, BEGIN_DATE, CUT_OFF_DATE, ZINSSATZ
    )
select distinct FAC.HO_ACC_NUMBER            as FACILITY_ID,
                FAC.BU_CCY                   as CURRENCY,
                TILGUNG.PAST_DUE_SINCE       as PAST_DUE_AMORTIZATION_SINCE,
                TILGUNG.PAST_DUE_AMOUNT_EUR  as PAST_DUE_AMORTIZATION_AMOUNT_EUR,
                TILGUNG.PAST_DUE_AMOUNT_TC   as PAST_DUE_AMORTIZATION_AMOUNT_TC,
                TILGUNG.PAST_DUE_ALL_IN_RATE as PAST_DUE_AMORTIZATION_ALL_IN_RATE,
                --TILGUNG.GEBUCHT_AUF                                     as PAST_DUE_AMORTIZATION_GEBUCHT_AUF, -- seit Septemberlieferung 2020 nicht mehr enthalten
                ZINSEN.PAST_DUE_SINCE        as PAST_DUE_INTEREST_SINCE,
                ZINSEN.PAST_DUE_AMOUNT_EUR   as PAST_DUE_INTEREST_AMOUNT_EUR,
                ZINSEN.PAST_DUE_AMOUNT_TC    as PAST_DUE_INTEREST_AMOUNT_TC,
                ZINSEN.PAST_DUE_ALL_IN_RATE  as PAST_DUE_INTEREST_ALL_IN_RATE,
                --ZINSEN.GEBUCHT_AUF              as PAST_DUE_INTEREST_GEBUCHT_AUF, -- seit Septemberlieferung 2020 nicht mehr enthalten
                FEES.PAST_DUE_SINCE          as PAST_DUE_FEES_SINCE,
                FEES.PAST_DUE_AMOUNT_EUR     as PAST_DUE_FEES_AMOUNT_EUR,
                FEES.PAST_DUE_AMOUNT_TC      as PAST_DUE_FEES_AMOUNT_TC,
                FEES.PAST_DUE_ALL_IN_RATE    as PAST_DUE_FEES_ALL_IN_RATE,
                FAC.CUT_OFF_DATE,
                Current_USER                 as CREATED_USER,     -- Letzter Nutzer, der diese Tabelle gebaut hat.
                Current_TIMESTAMP            as CREATED_TIMESTAMP -- Neuester Zeitstempel, wann diese Tabelle zuletzt gebaut wurde.
from AVALOQ_PAST_DUE_FACILITIES FAC
         left join TILGUNG on FAC.HO_ACC_NUMBER = TILGUNG.FACILITY_ID and FAC.CUT_OFF_DATE = TILGUNG.CUT_OFF_DATE
         left join ZINSEN on FAC.HO_ACC_NUMBER = ZINSEN.FACILITY_ID and FAC.CUT_OFF_DATE = ZINSEN.CUT_OFF_DATE
         left join FEES on FAC.HO_ACC_NUMBER = FEES.FACILITY_ID and FAC.CUT_OFF_DATE = FEES.CUT_OFF_DATE
;


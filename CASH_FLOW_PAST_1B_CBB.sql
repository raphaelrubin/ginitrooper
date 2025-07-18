-- Vergangenge Umsätze der Luxemburg Covered Bond Bank

-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_CASH_FLOW_PAST_CBB;
create or replace view CALC.VIEW_CASH_FLOW_PAST_CBB(CUT_OFF_DATE, FACILITY_ID,CASH_FLOW_TYPE,TRANSACTION_VALUE_TRADECURRENCY,TRANSACTION_TRADECURRENCY_ISO,VALUTA_DATE,PAYMENT_DATE,ERFOLGSART,SOURCE_SYSTEM,PAST_DUE_ALIAS,TRANSACTION_ID,CANCELLATION_TRANSACTION_ID,IS_BAD_DEBT_LOSS,COMMENT,CREATED_USER,CREATED_TIMESTAMP) as
    with
    CBB_STAMMDATEN as (
        select
            PORTFOLIO.FACILITY_ID_CBB,
            coalesce(LENDING.IDENTITY,SPOT_STAMMDATEN.KKTOAVA+1) as KONTONUMMER,
            --coalesce(LENDING.OWN_SYNDICATE_QUOTA,100)   as OWN_SYNDICATE_QUOTA,
            PORTFOLIO.CUT_OFF_DATE
        from CALC.SWITCH_PORTFOLIO_CURRENT        as PORTFOLIO
        left join CBB.LENDING_CURRENT           as LENDING          on PORTFOLIO.CUT_OFF_DATE= LENDING.CUT_OFF_DATE
                                                                        and 'K028-' || LENDING.IDENTITY = left(PORTFOLIO.FACILITY_ID_CBB,instr(PORTFOLIO.FACILITY_ID_CBB,'_')-1)
        left join CBB.SPOT_STAMMDATEN_CURRENT   as SPOT_STAMMDATEN  on PORTFOLIO.CUT_OFF_DATE = SPOT_STAMMDATEN.CUTOFFDATE
                                                                        and left(PORTFOLIO.FACILITY_ID_CBB,instr(PORTFOLIO.FACILITY_ID_CBB,'_')-1) = 'K028-'|| (SPOT_STAMMDATEN.KKTOAVA + case when FACILITY_ID_CBB = 'K028-2588653_1020' then 3 else 1 end)
        where PORTFOLIO.FACILITY_ID_CBB is not NULL
    ),
    data  as (
    --------------------------
    -- CBB Buchungen
        select distinct
            CBB_STAMMDATEN.FACILITY_ID_CBB as FACILITY_ID
            ,case
                when GVKKL = 'D004' then 'Auszahlung'
                when GVKKL = 'D056' then 'Zinszahlung (aktiv)'
                when GVKKL = 'D556' then 'Zinszahlung (passiv/Storno)'
                when GVKKL = 'D063' then 'Tilgung Kapitalbuchung (aktiv)'
                when GVKKL = 'D563' then 'Tilgung Kapitalbuchung (Ertrag)'
                else GVKKL
            end as UMSATZ_ART
            ,case
                when GVKKL = 'D004' then -1
                when GVKKL = 'D556' then -1
                when GVKKL = 'D563' then -1
                else 1
            end * GVPNBET as TRANSAKTION_WERT_WHRG
            ,GVPNWI as TRANSAKTION_WHRG_SCHL
            ,GVKBUDE as VALUTA_DATUM
            ,VBUDAT as BUCHUNGS_DATUM
            ,CASH_FLOW.CUTOFFDATE as CUT_OFF_DATE
            ,TRIM(left(CASH_FLOW.GVKID,20))|| '-' || trim(left(CASH_FLOW.SKTO,20)) as BUCHUNGS_ID -- BUCHUNGS_ID ohne Leerzeichen
        from CBB.SPOT_UMSATZ_CURRENT            as CASH_FLOW
        inner join CBB.SPOT_STAMMDATEN_CURRENT  as SPOT_STAMMDATEN on SPOT_STAMMDATEN.CUTOFFDATE=CASH_FLOW.CUTOFFDATE               and CASH_FLOW.SKTO=SPOT_STAMMDATEN.SKTO
        inner join CBB_STAMMDATEN               as CBB_STAMMDATEN  on CBB_STAMMDATEN.CUT_OFF_DATE = SPOT_STAMMDATEN.CUTOFFDATE  and
                                                                      CBB_STAMMDATEN.KONTONUMMER = (SPOT_STAMMDATEN.KKTOAVA + case when FACILITY_ID_CBB = 'K028-2588653_1020' then 3 else 1 end )
        where GVKBUDE <= CASH_FLOW.CUTOFFDATE - case when dayofweek(CASH_FLOW.CUTOFFDATE)=1 Then 2 when dayofweek(CASH_FLOW.CUTOFFDATE)=7 then 1 else 0 end days
    --------------------------
    )
select
    CUT_OFF_DATE            as CUT_OFF_DATE,
    FACILITY_ID             as FACILITY_ID,
    UMSATZ_ART              as CASH_FLOW_TYPE,
    TRANSAKTION_WERT_WHRG   as TRANSACTION_VALUE_TRADECURRENCY,
    TRANSAKTION_WHRG_SCHL   as TRANSACTION_TRADECURRENCY_ISO,
    VALUTA_DATUM            as VALUTA_DATE,
    BUCHUNGS_DATUM          as PAYMENT_DATE,
    NULL                    as ERFOLGSART, -- SPÄTER ÜBER MAPPING
    'CBB'                   as SOURCE_SYSTEM,
    NULL                    as PAST_DUE_ALIAS,
    BUCHUNGS_ID             as TRANSACTION_ID,
    NULL                    as CANCELLATION_TRANSACTION_ID,
    cast(NULL as BOOLEAN)   as IS_BAD_DEBT_LOSS, -- Handelt es sich um eine Abschreibung?  (siehe Blossom #541)
    'CBB Buchung'           as COMMENT,
    Current USER            as CREATED_USER,          -- Letzter Nutzer, der dieses View gebaut hat.
    Current TIMESTAMP       as CREATED_TIMESTAMP      -- Neuester Zeitstempel, wann diese View zuletzt gebaut wurde.
from (
        select *, row_number() over (partition by FACILITY_ID,UMSATZ_ART,VALUTA_DATUM,BUCHUNGS_DATUM,BUCHUNGS_ID order by CUT_OFF_DATE asc) as NBR from data
       )
where NBR =1
;
------------------------------------------------------------------------------------------------------------------------

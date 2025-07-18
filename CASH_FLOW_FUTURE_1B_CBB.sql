-- Zukünftige Umsätze aus Luxemburg (CBB)

-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_CASH_FLOW_FUTURE_CBB;
create or replace view CALC.VIEW_CASH_FLOW_FUTURE_CBB as
with
    CBB_CASH_FLOW as (
        select distinct
            CASH_FLOWS.CUTOFFDATE as CUT_OFF_DATE,
            PORTFOLIO.FACILITY_ID_CBB as FACILITY_ID,
            case
                when CASH_FLOWS.A4art = '11' then 'TILGUNGSRATE'
                when CASH_FLOWS.A4ART = '21' then 'ZINSZAHLUNG'
                else left(CASH_FLOWS.A4ART, 10)
            end                 as CASH_FLOW_TYPE,
            CASH_FLOWS.A4DATWE             as VALUTA_DATE,
            CASH_FLOWS.A4DATBU             as PAYMENT_DATE,
            CASH_FLOWS.A4WERT              as CASH_FLOW_VALUE_CURRENCY,
            CASH_FLOWS.A4iso               as CASH_FLOW_VALUE_CURRENCY_ISO
        from CBB.SPOT_CASH_FLOW                 as CASH_FLOWS
        inner join CBB.SPOT_STAMMDATEN_CURRENT  as STAMMDATEN on STAMMDATEN.CUTOFFDATE = CASH_FLOWS.CUTOFFDATE and CASH_FLOWS.S4KTO = STAMMDATEN.SKTO
        inner join CALC.SWITCH_PORTFOLIO_CURRENT  as PORTFOLIO on PORTFOLIO.CUT_OFF_DATE = STAMMDATEN.CUTOFFDATE
                                                         and left(PORTFOLIO.FACILITY_ID_CBB, instr(PORTFOLIO.FACILITY_ID_CBB, '_') - 1) = 'K028-' || (STAMMDATEN.KKTOAVA + case when FACILITY_ID_CBB = 'K028-2588653_1020' then 3 else 1 end) --berücksichtigt auch 6-stellige Kontonummern
    ),
    CBB_STAMMDATEN as (
        select
            STA.CUTOFFDATE as CUT_OFF_DATE,
            'K028-' || (STA.KKTOAVA + case when FACILITY_ID_CBB = 'K028-2588653_1020' then 3 else 1 end) || '_1020'
                                as FACILITY_ID,
            'TILGUNGSRATE'      as CASH_FLOW_TYPE,
            KRENDE              as VALUTA_DATUM,
            KRENDE              as PAYMENT_DATE,
            -1 * KRWAEB         as ZAHLUNGSSTROM_BTR,
            kriso               as ZAHLUNGSSTROM_WHRG
        from CBB.SPOT_STAMMDATEN                    as STA
        inner join CALC.SWITCH_PORTFOLIO_CURRENT  as FD on FD.CUT_OFF_DATE = STA.CUTOFFDATE
                                                                 and left(FD.FACILITY_ID_CBB, instr(FD.FACILITY_ID_CBB, '_') - 1) = 'K028-' || (STA.KKTOAVA + case when FACILITY_ID_CBB = 'K028-2588653_1020' then 3 else 1 end) --berücksichtigt auch 6-stellige kontonummern
        where KROTI = 3
          and KRWAEB <> 0
    )
select * from CBB_CASH_FLOW
/* es ist unklar, was dieser Teil von Code tut (außer ein Duplikat erzeugen...)
union all

select * from CBB_STAMMDATEN */
;
------------------------------------------------------------------------------------------------------------------------

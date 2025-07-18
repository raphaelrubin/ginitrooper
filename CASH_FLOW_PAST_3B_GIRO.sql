
-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_CASH_FLOW_PAST_GIRO;
create or replace view CALC.VIEW_CASH_FLOW_PAST_GIRO as
    select
        FACILITY_ID,                                                    -- Kontonummer
        CASH_FLOW_TYPE                  as UMSATZ_ART,                  -- Beschreibung der Buchungsart
        round(TRANSACTION_VALUE_TRADECURRENCY,2) as TRANSAKTION_WERT_WHRG,       -- Transaktionswert in der Handelswährung
        TRANSACTION_TRADECURRENCY_ISO   as TRANSAKTION_WHRG_SCHL,       -- Transaktionswährung
        VALUTA_DATE                     as VALUTA_DATUM,                -- Datum an dem die Buchung Wertgeschrieben wurde (das relevante Datum)
        PAYMENT_DATE                    as BUCHUNGS_DATUM,              -- Datum an dem die Buchung erfolgt ist (sollte immer gleich dem Valuta Datum sein, es sei denn das Valuta Datum wurde aus Kulanz oder w.g. Feiertagen angepasst)
        coalesce(ERFOLGSSMAP.KATEGORIE,'') || ': ' || coalesce(ERFOLGSSMAP.ERFOLGSART,CASH_FLOW.ERFOLGSART,'')
                                        as ERFOLGSART,                  -- Erfolgsart oder Erfolgsschlüssel
        CUT_OFF_DATE,                                                   -- Stichtag zu dem die Daten eingeholt wurden
        TRANSACTION_ID                  as BUCHUNGS_ID,                 -- System ID der Buchung
        CANCELLATION_TRANSACTION_ID     as STORNO_BUCHUNGS_ID,          -- System ID der Buchung, welche durch diese Buchung storniert wurde (sonst NULL)
        IS_BAD_DEBT_LOSS                as IS_BAD_DEBT_LOSS,            -- Handelt es sich um eine Ausbuchung?
        Current USER                    as TAPE_CREATED_USER,           -- Letzter Nutzer, der dieses Tape gebaut hat.
        Current TIMESTAMP               as TAPE_CREATED_TIMESTAMP       -- Neuester Zeitstempel, wann dieses Tape zuletzt gebaut wurde.
    from CALC.SWITCH_CASH_FLOW_PAST_PRE_CURRENT   as CASH_FLOW
    left join SMAP.ERFOLGSARTEN as ERFOLGSSMAP on ERFOLGSSMAP.ERFOLGSSCHLUSSEL = CASH_FLOW.ERFOLGSART
    where 1=1
      and left(FACILITY_ID,7)<> '0009-33' --anforderung Hierke 21.08.2019 17:59
      and not left(TRANSACTION_ID,8) = 'SWB_KORR'
;
------------------------------------------------------------------------------------------------------------------------

-- CI START FOR ALL TAPES

-- CURRENT TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_CASH_FLOW_PAST_GIRO_CURRENT');
create table AMC.TABLE_CASH_FLOW_PAST_GIRO_CURRENT like CALC.VIEW_CASH_FLOW_PAST_GIRO distribute by hash(FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CASH_FLOW_PAST_GIRO_CURRENT_FACILITY_ID on AMC.TABLE_CASH_FLOW_PAST_GIRO_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_CASH_FLOW_PAST_GIRO_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- ARCHIVE TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_CASH_FLOW_PAST_GIRO_ARCHIVE');
create table AMC.TABLE_CASH_FLOW_PAST_GIRO_ARCHIVE like CALC.VIEW_CASH_FLOW_PAST_GIRO distribute by hash(FACILITY_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CASH_FLOW_PAST_GIRO_ARCHIVE_FACILITY_ID on AMC.TABLE_CASH_FLOW_PAST_GIRO_ARCHIVE (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_CASH_FLOW_PAST_GIRO_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCHES erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_CASH_FLOW_PAST_GIRO_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_CASH_FLOW_PAST_GIRO_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

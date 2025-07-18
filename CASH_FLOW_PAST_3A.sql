
-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_CASH_FLOW_PAST;
create or replace view CALC.VIEW_CASH_FLOW_PAST as
    select
        FACILITY_ID,                                                    -- Kontonummer
        CASH_FLOW_TYPE                  as UMSATZ_ART,                  -- Beschreibung der Buchungsart
        case
            when IS_BAD_DEBT_LOSS then
                'Bad Debt Loss'
            when upper(CASH_FLOW_TYPE) like '%ABSCHREIBUNG%' then
                'Bad Debt Loss'
            when SOURCE_SYSTEM = 'FWV' then
                'Interest'
            when upper(CASH_FLOW_TYPE) like '%ABG_ZINS_ZAHLUNG%' then
                'Past Due'
            when upper(CASH_FLOW_TYPE) like '%ZINS%' then
                'Interest'
            when upper(CASH_FLOW_TYPE) like '%TILGUNG%' then
                'Redemption'
            when upper(CASH_FLOW_TYPE) like '%AUSZAHL%' then
                'Disbursement'
            when upper(CASH_FLOW_TYPE) like '%EINZAHL%' then
                'Redemption'
            when upper(CASH_FLOW_TYPE) like '%GEB%' then
                'Fee'
            else NULL
        end as CASH_FLOW_TYPE_GROUP,                                    -- Einordnung der CFS für NET_COLLECTION Analyse
        TRANSACTION_VALUE_TRADECURRENCY as TRANSAKTION_WERT_WHRG,       -- Transaktionswert in der Handelswährung
        TRANSACTION_TRADECURRENCY_ISO   as TRANSAKTION_WHRG_SCHL,       -- Transaktionswährung
        VALUTA_DATE                     as VALUTA_DATUM,                -- Datum an dem die Buchung Wertgeschrieben wurde (das relevante Datum)
        PAYMENT_DATE                    as BUCHUNGS_DATUM,              -- Datum an dem die Buchung erfolgt ist (sollte immer gleich dem Valuta Datum sein, es sei denn das Valuta Datum wurde aus Kulanz oder w.g. Feiertagen angepasst)
        nullif(trim(BOTH ':' FROM (trim((coalesce(ERFOLGSSMAP.KATEGORIE,'') || ': ' || coalesce(ERFOLGSSMAP.ERFOLGSART,CASH_FLOW.ERFOLGSART,''))))),'')
                                        as ERFOLGSART,                  -- Erfolgsart oder Erfolgsschlüssel
        CUT_OFF_DATE,                                                   -- Stichtag zu dem die Daten eingeholt wurden
        TRANSACTION_ID                  as BUCHUNGS_ID,                 -- System ID der Buchung
        nullif(CANCELLATION_TRANSACTION_ID,NULL)     as STORNO_BUCHUNGS_ID,          -- System ID der Buchung, welche durch diese Buchung storniert wurde (sonst NULL)
        nullif(PAST_DUE_ALIAS,NULL)                  as PAST_DUE_ALIAS_LOANIQ,
        SOURCE_SYSTEM                   as SOURCE_SYSTEM,               -- Quellsystem (vor SPOT)
        Current USER                    as TAPE_CREATED_USER,           -- Letzter Nutzer, der dieses Tape gebaut hat.
        Current TIMESTAMP               as TAPE_CREATED_TIMESTAMP       -- Neuester Zeitstempel, wann dieses Tape zuletzt gebaut wurde.
    from CALC.SWITCH_CASH_FLOW_PAST_PRE_CURRENT   as CASH_FLOW
    left join SMAP.ERFOLGSARTEN as ERFOLGSSMAP on ERFOLGSSMAP.ERFOLGSSCHLUSSEL = CASH_FLOW.ERFOLGSART
;
------------------------------------------------------------------------------------------------------------------------

-- CI START FOR ALL TAPES

-- CURRENT TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_CASH_FLOW_PAST_CURRENT');
create table AMC.TABLE_CASH_FLOW_PAST_CURRENT like CALC.VIEW_CASH_FLOW_PAST distribute by hash(FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CASH_FLOW_PAST_CURRENT_FACILITY_ID on AMC.TABLE_CASH_FLOW_PAST_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_CASH_FLOW_PAST_CURRENT');

------------------------------------------------------------------------------------------------------------------------

-- ARCHIVE TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_CASH_FLOW_PAST_ARCHIVE');
create table AMC.TABLE_CASH_FLOW_PAST_ARCHIVE like CALC.VIEW_CASH_FLOW_PAST distribute by hash(FACILITY_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CASH_FLOW_PAST_ARCHIVE_FACILITY_ID on AMC.TABLE_CASH_FLOW_PAST_ARCHIVE (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_CASH_FLOW_PAST_ARCHIVE');

------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCHES erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_CASH_FLOW_PAST_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_CASH_FLOW_PAST_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

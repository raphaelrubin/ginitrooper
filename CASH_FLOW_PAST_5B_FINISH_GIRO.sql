-------------------------
-- CASH_FLOW_PAST_GIRO --
-------------------------
-- CI START FOR ALL TAPES
-- Drop View
drop view AMC.TAPE_CASH_FLOW_PAST_GIRO_FINISH;
-- View erstellen
create or replace view AMC.TAPE_CASH_FLOW_PAST_GIRO_FINISH as
select CUT_OFF_DATE, BUCHUNGS_DATUM, VALUTA_DATUM, FACILITY_ID, BUCHUNGS_ID, STORNO_BUCHUNGS_ID, TRANSAKTION_WERT_WHRG,
       TRANSAKTION_WHRG_SCHL, UMSATZ_ART, ERFOLGSART, IS_BAD_DEBT_LOSS, TAPE_CREATED_USER, TAPE_CREATED_TIMESTAMP
from AMC.TABLE_CASH_FLOW_PAST_GIRO_CURRENT as CASH_FLOW;
-- CI END FOR ALL TAPES
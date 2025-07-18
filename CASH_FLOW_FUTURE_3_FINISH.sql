----------------------
-- CASH_FLOW_FUTURE --
----------------------
-- CI START FOR ALL TAPES
-- Drop View
drop view AMC.TAPE_CASH_FLOW_FUTURE_FINISH;
-- View erstellen
create or replace view AMC.TAPE_CASH_FLOW_FUTURE_FINISH as select * from AMC.TABLE_CASH_FLOW_FUTURE_CURRENT;
-- CI END FOR ALL TAPES
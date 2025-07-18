--------------------
-- CASH_FLOW_PAST --
--------------------
-- CI START FOR ALL TAPES
-- Drop View
drop view AMC.TAPE_CASH_FLOW_PAST_FINISH;
-- View erstellen
create or replace view AMC.TAPE_CASH_FLOW_PAST_FINISH as select * from AMC.TABLE_CASH_FLOW_PAST_CURRENT;
-- CI END FOR ALL TAPES
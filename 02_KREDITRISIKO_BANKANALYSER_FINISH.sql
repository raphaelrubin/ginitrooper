------------------------------
-- KREDITRISIO_BANKANALYSER --
------------------------------
-- CI START FOR ALL TAPES
-- Drop View
drop view AMC.TAPE_KREDITRISIKO_BANKANALYSER_FINISH;
-- View erstellen
create or replace view AMC.TAPE_KREDITRISIKO_BANKANALYSER_FINISH AS select * from AMC.TABLE_KREDITRISIKO_BANKANALYSER_CURRENT;
-- CI END FOR ALL TAPES
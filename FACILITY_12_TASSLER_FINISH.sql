----------------------
-- FACILITY_TASSLER --
----------------------
-- CI START FOR ALL TAPES
-- Drop View
drop view AMC.TAPE_FACILITY_TASSLER_FINISH;
-- View erstellen
create or replace view AMC.TAPE_FACILITY_TASSLER_FINISH as select * from AMC.TABLE_FACILITY_TASSLER_CURRENT;
-- CI END FOR ALL TAPES
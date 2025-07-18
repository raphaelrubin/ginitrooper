-------------------
-- GENERAL_ASSET --
-------------------
-- CI START FOR ALL TAPES
-- Drop View
drop view AMC.TAPE_GENERAL_ASSET_FINISH;
-- View erstellen
create or replace view AMC.TAPE_GENERAL_ASSET_FINISH as select * from AMC.TABLE_GENERAL_ASSET_CURRENT;
-- CI END FOR ALL TAPES
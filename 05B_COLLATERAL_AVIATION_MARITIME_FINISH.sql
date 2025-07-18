----------------------
-- COLLATERAL_AV_MA --
----------------------
-- CI START FOR ALL TAPES
-- Drop View
drop view AMC.TAPE_COLLATERAL_AV_MA_FINISH;
-- View erstellen
create or replace view AMC.TAPE_COLLATERAL_AV_MA_FINISH as select * from AMC.TABLE_COLLATERAL_AV_MA_CURRENT;
-- CI END FOR ALL TAPES
-------------------------
-- ASSET_TO_COLLATERAL --
-------------------------
-- CI START FOR ALL TAPES
-- Drop View
drop view AMC.TAPE_ASSET_TO_COLLATERAL_PWC;
-- View erstellen
create or replace view AMC.TAPE_ASSET_TO_COLLATERAL_PWC as
select  CUT_OFF_DATE,
        COLLATERAL_ID,
        ASSET_ID,
        BRANCH as GNI_NIEDERLASSUNG,
        SOURCE as GNI_QUELLE,
        CREATED_USER,
        CREATED_TIMESTAMP
from AMC.TABLE_ASSET_TO_COLLATERAL_CURRENT;
-- CI END FOR ALL TAPES
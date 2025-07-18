----------------------------
-- COLLATERAL_TO_FACILITY --
----------------------------
-- CI START FOR ALL TAPES
-- Drop View
drop view AMC.TAPE_COLLATERAL_TO_CLIENT_FINISH;
-- View erstellen
create or replace view AMC.TAPE_COLLATERAL_TO_CLIENT_FINISH as
    select
        *
    from AMC.TABLE_COLLATERAL_TO_CLIENT_CURRENT;
-- CI END FOR ALL TAPES
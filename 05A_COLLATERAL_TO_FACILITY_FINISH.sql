----------------------------
-- COLLATERAL_TO_FACILITY --
----------------------------
-- CI START FOR ALL TAPES
-- Drop View
drop view AMC.TAPE_COLLATERAL_TO_FACILITY_FINISH;
-- View erstellen
create or replace view AMC.TAPE_COLLATERAL_TO_FACILITY_FINISH as
    select
        CUT_OFF_DATE,
        FACILITY_ID,
        CLIENT_ID,
        COLLATERAL_ID,
        MAX_RISK_VERT_JE_GW,
        BRANCH,
        DATA_SOURCE,
        CREATED_USER,
        CREATED_TIMESTAMP
    from AMC.TABLE_COLLATERAL_TO_FACILITY_CURRENT;
-- CI END FOR ALL TAPES
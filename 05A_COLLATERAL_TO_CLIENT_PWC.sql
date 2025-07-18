----------------------------
-- COLLATERAL_TO_FACILITY --
----------------------------
-- CI START FOR ALL TAPES
-- Drop View
drop view AMC.TAPE_COLLATERAL_TO_CLIENT_PWC;
-- View erstellen
create or replace view AMC.TAPE_COLLATERAL_TO_CLIENT_PWC as
select  CUT_OFF_DATE,
        CLIENT_ID as GNI_KUNDE,
        COLLATERAL_ID,
        MAX_RISK_VERT_JE_GW as GNI_MAXRISKVERT,
        BRANCH as GNI_NIEDERLASSUNG,
        SOURCE as GNI_QUELLE,
        CREATED_USER,
        CREATED_TIMESTAMP
    from AMC.TABLE_COLLATERAL_TO_CLIENT_CURRENT;
-- CI END FOR ALL TAPES
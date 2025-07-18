--TABELLEN FUER DIE CI ERSTELLEN, DA DIESE IN FACILITY_11_INSTRUMENT GEBRAUCHT WERDEN, ABER ERST IN 07_COLLATERALIZATION angelegt
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_COLLATERAL_TO_FACILITY_CURRENT');
create table AMC.TABLE_COLLATERAL_TO_FACILITY_CURRENT
(
    CUT_OFF_DATE DATE,
    CLIENT_ID VARCHAR(32),
    FACILITY_ID VARCHAR(64),
    COLLATERAL_ID VARCHAR(32),
    MAX_RISK_VERT_JE_GW DOUBLE,
    BRANCH VARCHAR(50),
    DATA_SOURCE VARCHAR(4),
    CREATED_USER VARCHAR(128) NOT NULL,
    CREATED_TIMESTAMP TIMESTAMP NOT NULL
);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_COLLATERAL_TO_FACILITY_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- SWITCH erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_COLLATERAL_TO_FACILITY_CURRENT');
------------------------------------------------------------------------------------------------------------------------






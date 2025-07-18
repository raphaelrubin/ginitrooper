--TABELLEN FUER DIE CI ERSTELLEN, DA DIESE IN FACILITY_11_INSTRUMENT GEBRAUCHT WERDEN, ABER ERST IN 07_COLLATERALIZATION angelegt
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_ASSET_TO_COLLATERAL_CURRENT');
create table AMC.TABLE_ASSET_TO_COLLATERAL_CURRENT
(
    CUT_OFF_DATE      DATE,
    COLLATERAL_ID     VARCHAR(64),
    ASSET_ID          VARCHAR(32),
    BRANCH            VARCHAR(8),
    SOURCE            VARCHAR(8)   NOT NULL,
    CREATED_USER      VARCHAR(128) NOT NULL,
    CREATED_TIMESTAMP TIMESTAMP    NOT NULL
);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_ASSET_TO_COLLATERAL_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- SWITCH erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_ASSET_TO_COLLATERAL_CURRENT');
------------------------------------------------------------------------------------------------------------------------


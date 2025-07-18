--TABELLEN FUER DIE CI ERSTELLEN, DA DIESE IN FACILITY_11_INSTRUMENT GEBRAUCHT WERDEN, ABER ERST IN 07_COLLATERALIZATION angelegt

call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_ASSET_REX_CURRENT');
create table AMC.TABLE_ASSET_REX_CURRENT (
    CUT_OFF_DATE DATE,
    ASSET_ID VARCHAR(34),
    CMS_ID_ORIG VARCHAR(64),
    PRM_LCTN VARCHAR(1),
    APPRSR VARCHAR(272),
    CRE_YRLY_INCM DOUBLE,
    CRE_YRLY_EXPNSS DOUBLE,
    CRE_INCM_CRRNCY VARCHAR(3),
    DVLPMNT_STTS BIGINT,
    USER VARCHAR(128) NOT NULL,
    TIMESTAMP_LOAD TIMESTAMP NOT NULL
);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_ASSET_REX_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- SWITCH erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_ASSET_REX_CURRENT');
------------------------------------------------------------------------------------------------------------------------

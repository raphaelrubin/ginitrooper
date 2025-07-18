--TABELLEN FUER DIE CI ERSTELLEN, DA DIESE IN FACILITY_11_INSTRUMENT GEBRAUCHT WERDEN, ABER ERST IN , 05_CLIENTS,
-- 07_COLLATERALIZATION angelegt

call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_CLIENT_EBIL_GLOBAL_FORMAT_CURRENT');
create table AMC.TABLE_CLIENT_EBIL_GLOBAL_FORMAT_CURRENT (
    CUT_OFF_DATE DATE,
    BRANCH VARCHAR(32) NOT NULL,
    CLIENT_ID VARCHAR(53),
    GRP_EBITDA DOUBLE,
    GRP_EQTY DOUBLE,
    GRP_NT_DBT DOUBLE,
    ANNL_TRNVR_LE DOUBLE,
    ANNL_TRNVR_PRVS DOUBLE,
    MNTHL_TRNVR DOUBLE,
    CAPEX DOUBLE,
    CAPEX_PRVS DOUBLE,
    CSH DOUBLE,
    CSH_PRVS DOUBLE,
    EBITDA DOUBLE,
    EBITDA_PRVS DOUBLE,
    EQTY DOUBLE,
    EQTY_PRVS DOUBLE,
    GDWILL DOUBLE,
    GDWILL_PRVS DOUBLE,
    LVRG DOUBLE,
    LVRG_PRVS DOUBLE,
    NT_INCM DOUBLE,
    NT_INCM_PRVS DOUBLE,
    DBT_SRVC_RT DOUBLE,
    DBT_SRVC_RT_12M DOUBLE,
    TTL_INTRST_PD DOUBLE,
    AKTUELLER_STICHTAG_KB DATE,
    AKTUELLER_STICHTAG_EB DATE,
    PRVS_STICHTAG_KB DATE,
    PRVS_STICHTAG_EB DATE,
    USER VARCHAR(128) NOT NULL,
    TIMESTAMP_LOAD TIMESTAMP NOT NULL
);

------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_CLIENT_EBIL_GLOBAL_FORMAT_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- SWITCH erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_CLIENT_EBIL_GLOBAL_FORMAT_CURRENT');
------------------------------------------------------------------------------------------------------------------------




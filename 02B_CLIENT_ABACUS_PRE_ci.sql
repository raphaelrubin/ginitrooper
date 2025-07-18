--TABELLE FUER DIE CI ERSTELLEN, DA DIESE IN FACILITY_ABACUS_INSTRUMENT GEBRAUCHT WIRD, ABER ERST IN 05_CLIENTS angelegt

call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_CLIENT_ABACUS_CURRENT');
create table AMC.TABLE_CLIENT_ABACUS_CURRENT (
    CUT_OFF_DATE DATE,
    DT_INTTN_LGL_PRCDNGS_LE DATE,
    LEI VARCHAR(32),
    ENTTY_NM VARCHAR(257),
    DFL_STTS INTEGER,
    ECNMC_ACTVTY VARCHAR(8),
    ENTRPRS_SZ_LE INTEGER,
    LGL_PRCDNG_STTS_LE INTEGER,
    ANNL_TRNVR_LE DOUBLE,
    CNTRY VARCHAR(3),
    DT_BRTH DATE,
    PD_CRR_RD DOUBLE,
    DT_FAILURE DATE,
    SAP_KUNDE VARCHAR(32),
    CLIENT_NO VARCHAR(16),
    USER VARCHAR(128) NOT NULL,
    TIMESTAMP_LOAD TIMESTAMP NOT NULL
);

------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_CLIENT_ABACUS_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- SWITCH erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_CLIENT_ABACUS_CURRENT');
------------------------------------------------------------------------------------------------------------------------




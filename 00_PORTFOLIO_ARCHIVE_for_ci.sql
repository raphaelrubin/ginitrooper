/*In dieser Datei wird eine leere PORTFOLIO ARCHIVE Tabelle und die zugehörige SWITCH erzeugt. Dadurch können die Views
  in den folgenden Dateien von der CALC.SWITCH_PORTFOLIO_ARCHIVE gebrauch machen, bevor sie aus basis der CURRENT
  Tabelle definiert wurde. Für die CI ist dies unerlässlich. */

-- Der folgende Code hilft dabei, diese Tabellendefinition zu aktualisieren:
-- select COLNAME || ' ' || TYPENAME || case when STRINGUNITSLENGTH is not NULL then '('||STRINGUNITSLENGTH||')' else '' end || case when NULLS = 'N' then ' NOT NULL' else '' end ||','
-- from SYSCAT.COLUMNS
-- where TABNAME = 'TABLE_PORTFOLIO_ARCHIVE' and TABSCHEMA = 'FKW' order by COLNO;

-- ARCHIVE TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('FKW','TABLE_PORTFOLIO_ARCHIVE');
create table FKW.TABLE_PORTFOLIO_ARCHIVE
(
    CUT_OFF_DATE                        DATE,
    DATA_CUT_OFF_DATE                   DATE,
    BRANCH_SYSTEM                       CHARACTER(64),
    SYSTEM                              VARCHAR(64),
    BRANCH_CLIENT                       CHARACTER(3),
    CLIENT_NO                           BIGINT,
    CLIENT_ID_ORIG                      VARCHAR(32),
    CLIENT_ID_ALT                       VARCHAR(1024),
    BORROWER_NO                         BIGINT,
    BRANCH_FACILITY                     CHARACTER(8),
    FACILITY_ID                         VARCHAR(64),
    FACILITY_ID_LEADING                 VARCHAR(64),
    FACILITY_ID_NLB                     VARCHAR(64),
    FACILITY_ID_BLB                     VARCHAR(64),
    FACILITY_ID_CBB                     VARCHAR(64),
    CURRENCY                            CHARACTER(3),
    PORTFOLIO_EY_FACILITY               VARCHAR(1024),
    PORTFOLIO_EY_CLIENT_ROOT            VARCHAR(1024),
    PORTFOLIO_IWHS_CLIENT_KUNDENBERATER VARCHAR(1024),
    PORTFOLIO_IWHS_CLIENT_SERVICE       VARCHAR(1024),
    PORTFOLIO_KR_CLIENT                 VARCHAR(1024),
    PORTFOLIO_GARANTIEN_CLIENT          VARCHAR(1024),
    IS_CLIENT_GUARANTEE_FLAGGED         BOOLEAN,
    IS_FACILITY_GUARANTEE_FLAGGED       BOOLEAN,
    CREATED_USER                        VARCHAR(128) NOT NULL,
    CREATED_TIMESTAMP                   TIMESTAMP    NOT NULL
);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('FKW','TABLE_PORTFOLIO_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

-- SWITCH erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('FKW','TABLE_PORTFOLIO_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

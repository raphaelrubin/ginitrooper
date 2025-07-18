/*Für die CI müssen wir hier schon die Archivtabelle für die Vererbung erstellen.
  Dadurch können die Dateien in diesem Ordner in alphanumerischer Reihenfolge ausgeführt werden.
  Es reicht, wenn dies für ein tape tun, da wir die richtige Archivtabelle eh später nochmal erstellen.
  Wir müssen aber aufpassen, dass uns die Daten nicht verloren gehen!!!!!!!!
 */

-- Der folgende Code hilft dabei, diese Tabellendefinition zu aktualisieren:
-- select COLNAME || ' ' || TYPENAME || case when STRINGUNITSLENGTH is not NULL then '('||STRINGUNITSLENGTH||')' else '' end || case when NULLS = 'N' then ' NOT NULL' else '' end ||','
-- from SYSCAT.COLUMNS
-- where TABNAME = 'TABLE_PORTFOLIO_DESIRED_CLIENTS_ARCHIVE' and TABSCHEMA = 'FKW' order by COLNO;

-- ARCHIVE TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('FKW','TABLE_PORTFOLIO_DESIRED_CLIENTS_ARCHIVE');
create table FKW.TABLE_PORTFOLIO_DESIRED_CLIENTS_ARCHIVE
(
    CUT_OFF_DATE                        DATE,
    BRANCH_CLIENT                       VARCHAR(512),
    CLIENT_NO                           DECFLOAT,
    CLIENT_ID                           VARCHAR(555),
    CLIENT_IDS_NLB                      VARCHAR(555),
    CLIENT_IDS_BLB                      VARCHAR(555),
    CLIENT_IDS_CBB                      VARCHAR(555),
    BORROWER_NO                         BIGINT,
    PORTFOLIO_EY_CLIENT_ROOT            VARCHAR(1024), -- as PORTFOLIO_ROOT,
    PORTFOLIO_IWHS_CLIENT_KUNDENBERATER VARCHAR(1024), -- as PORTFOLIO_ROOT_IWHS,
    PORTFOLIO_IWHS_CLIENT_SERVICE       VARCHAR(1024),
    PORTFOLIO_KR_CLIENT                 VARCHAR(1024),
    PORTFOLIO_GARANTIEN_CLIENT          VARCHAR(1024),
    SOURCE                              VARCHAR(64),
    IS_GUARANTEE_FLAGGED                BOOLEAN,
    CREATED_USER                        VARCHAR(128) NOT NULL,
    CREATED_TIMESTAMP                   TIMESTAMP    NOT NULL
);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('FKW','TABLE_PORTFOLIO_DESIRED_CLIENTS_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

-- SWITCH erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('FKW','TABLE_PORTFOLIO_DESIRED_CLIENTS_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

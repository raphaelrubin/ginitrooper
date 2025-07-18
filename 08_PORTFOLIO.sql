/*Hinzufügen von Sonderinformationen nach der Vererbung
  Das Ergebnis ist das finale Portfolio*/

-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_PORTFOLIO;
create or replace view CALC.VIEW_PORTFOLIO as
    with FACILITIES as (
            select NEW_CUT_OFF_DATE, DATA_CUT_OFF_DATE, BRANCH_SYSTEM, SYSTEM, BRANCH_CLIENT, CLIENT_NO, CLIENT_ID_ORIG, CLIENT_IDS_ALT, BORROWER_NO,  BRANCH_FACILITY, FACILITY_ID, FACILITY_ID_LEADING, FACILITY_ID_NLB, FACILITY_ID_BLB, FACILITY_ID_CBB, CURRENCY, FACILITY_REQUEST_TYPE
            from CALC.SWITCH_PORTFOLIO_INHERITANCE_CURRENT
    ),CURRENT_CUT_OFF_DATE as (
        select CUT_OFF_DATE from CALC.AUTO_TABLE_CUTOFFDATES where IS_ACTIVE
    ),
    CLIENT_INFO as (
        select distinct
            BRANCH_CLIENT, CLIENT_NO, CLIENT_ID, CLIENT_ID_LEADING,
            nullif(trim(B '+' FROM replace(replace(coalesce(CLIENT_IDS_NLB,'')||'+'||coalesce(CLIENT_IDS_BLB,'')||'+'||coalesce(CLIENT_IDS_CBB,''),coalesce(CLIENT_ID,''),''),'++','')),'') as CLIENT_IDS_ALT,  -- Alternative IDs des Kunden unter denen er in anderen Systemen der Bank gefunden werden könnte.
            PORTFOLIO_EY_CLIENT_ROOT, -- as PORTFOLIO_ROOT,
            PORTFOLIO_IWHS_CLIENT_KUNDENBERATER, -- as PORTFOLIO_ROOT_IWHS,
            PORTFOLIO_IWHS_CLIENT_SERVICE,
            PORTFOLIO_KR_CLIENT,
            PORTFOLIO_GARANTIEN_CLIENT
        from CALC.SWITCH_PORTFOLIO_DESIRED_CLIENTS_CURRENT
    ),
    -- IWHS GARANTIE FLAGGING
    CLIENTS_WITH_GUARANTEE_FLAG as (
        select distinct *
        from (
           select CUTOFFDATE as CUT_OFF_DATE, BRANCH as BRANCH_CLIENT, BORROWERID as CLIENT_NO
           from NLB.IWHS_GARANTIEFLAG_CURRENT
           union all
           select CUTOFFDATE as CUT_OFF_DATE, BRANCH as BRANCH_CLIENT, BORROWERID as CLIENT_NO
           from BLB.IWHS_GARANTIEFLAG_CURRENT
       )
    ),


    -- ADDING_GUARANTEE_FLAGS_AND_ALT_IDS
    DATA_WITH_FLAGS as (
        select
            -- Stichtag Info
            FACILITIES.NEW_CUT_OFF_DATE,DATA_CUT_OFF_DATE,
            -- System Info
            BRANCH_SYSTEM,SYSTEM,
            -- Client Info
            FACILITIES.BRANCH_CLIENT,FACILITIES.CLIENT_NO,CLIENT_ID_ORIG,CLIENT_INFO.CLIENT_ID_LEADING,CLIENT_INFO.CLIENT_IDS_ALT,BORROWER_NO,
            -- Facility Info
            BRANCH_FACILITY,FACILITIES.FACILITY_ID,FACILITY_ID_LEADING, FACILITY_ID_NLB, FACILITY_ID_BLB,FACILITY_ID_CBB,CURRENCY,
            -- Portfolio Bezeichnungen
            CLIENT_INFO.PORTFOLIO_EY_CLIENT_ROOT, -- ehemals PORTFOLIO_ROOT
            trim(
                case
                    when CLIENT_INFO.CLIENT_ID is NULL then
                        'Inaktive Kundennummer'
                    else
                        coalesce( CLIENT_INFO.PORTFOLIO_EY_CLIENT_ROOT,'Ohne Portfolio')||' '
                end ||
                case
                    when DATA_CUT_OFF_DATE = FACILITIES.NEW_CUT_OFF_DATE and SYSTEM = 'AVALOQ' then
                        'AVALOQ REACTIVATION'
                    when DATA_CUT_OFF_DATE = FACILITIES.NEW_CUT_OFF_DATE then
                        coalesce(SYSTEM,'')
                    else
                        ''
                end
            ) ||' '||FACILITY_REQUEST_TYPE as PORTFOLIO_EY,
            CLIENT_INFO.PORTFOLIO_IWHS_CLIENT_KUNDENBERATER, -- ehemals PORTFOLIO_ROOT_IWHS,
            CLIENT_INFO.PORTFOLIO_IWHS_CLIENT_SERVICE,
            CLIENT_INFO.PORTFOLIO_KR_CLIENT,
            CLIENT_INFO.PORTFOLIO_GARANTIEN_CLIENT,
            -- Garantieflagging
            case
                when FACILITIES.NEW_CUT_OFF_DATE < '30.04.2020' then
                    NULL -- vor dem 30.04. hatten wir keine Daten, also NULL statt FALSE
                when CLIENT_FLAG.CLIENT_NO is NULL then
                    FALSE
                else
                    TRUE
            end as IS_CLIENT_GUARANTEE_FLAGGED, -- Garantie Flagging aus IWHS hinzufügen
            case
                when FACILITIES.NEW_CUT_OFF_DATE < '30.04.2020' then
                    NULL -- vor dem 30.04. hatten wir keine Daten, also NULL statt FALSE
                when FACILITY_FLAG.FACILITY_ID is NULL then
                    FALSE
                else
                    TRUE
            end as IS_FACILITY_GUARANTEE_FLAGGED, -- Garantie Flagging aus IWHS hinzufügen
            case
                when substr(FACILITIES.FACILITY_ID,6,2) = '73' then
                    TRUE
                else
                    FALSE
            end as IS_FACILITY_FROM_SINGAPORE -- Singapur Konten flaggen
        from FACILITIES
        left join CLIENT_INFO as CLIENT_INFO on (FACILITIES.BRANCH_CLIENT, FACILITIES.CLIENT_NO) = (CLIENT_INFO.BRANCH_CLIENT, CLIENT_INFO.CLIENT_NO)
        left join CALC.VIEW_GUARANTEE_FLAG as FACILITY_FLAG on (FACILITIES.NEW_CUT_OFF_DATE,FACILITIES.FACILITY_ID) = (FACILITY_FLAG.CUT_OFF_DATE,FACILITY_FLAG.FACILITY_ID) -- Garantie Flagging aus IWHS/Derivate/LIQ hinzufügen
        left join CLIENTS_WITH_GUARANTEE_FLAG as CLIENT_FLAG on (FACILITIES.NEW_CUT_OFF_DATE, FACILITIES.CLIENT_NO, FACILITIES.BRANCH_CLIENT) = (CLIENT_FLAG.CUT_OFF_DATE, CLIENT_FLAG.CLIENT_NO, CLIENT_FLAG.BRANCH_CLIENT) -- Garantie Flagging aus IWHS hinzufügen
    ),
    FINAL_RESULT as (
         -- Übersicht aller Spalten mit Beschreibung:
         select distinct
                -- Stichtag Infos
                DATE(NEW_CUT_OFF_DATE)                          as CUT_OFF_DATE,                    -- Derzeitiger Stichtag für den die Daten gelten
                DATE(DATA_CUT_OFF_DATE)                         as DATA_CUT_OFF_DATE,               -- Original Stichtag aus dem die Daten vererbt wurden
                -- Quellsystem Infos
                cast(BRANCH_SYSTEM as CHAR(64))                 as BRANCH_SYSTEM,                   -- BRANCH/INSTITUT des Systems aus dem das Konto kommt
                cast(SYSTEM as VARCHAR(64))                     as SYSTEM,                          -- Systems aus dem das Konto kommt
                -- Kunden Infos
                cast(BRANCH_CLIENT as CHAR(3))                  as BRANCH_CLIENT,                   -- BRANCH/INSTITUT der Kundennummer zum Blossom internen mappen
                cast(CLIENT_NO as BIGINT)                       as CLIENT_NO,                       -- Kundennummer zum Blossom internen mappen
                cast(CLIENT_ID_ORIG as VARCHAR(32))             as CLIENT_ID_ORIG,                  -- Kundennummer original mit Branch davor (zum Reporten nach außen)
                cast(CLIENT_ID_LEADING as VARCHAR(32))          as CLIENT_ID_LEADING,               -- führende Kundennummer
                cast(CLIENT_IDS_ALT as VARCHAR(1024))           as CLIENT_ID_ALT,                   -- Kundennummern alternativ zur CLIENT_ID_ORIG mit Branch davor
                BIGINT(BORROWER_NO)                             as BORROWER_NO,                     -- Kundennummer Kreditnehmer
                -- Konten Infos
                cast(BRANCH_FACILITY as CHAR(8))                as BRANCH_FACILITY,                 -- BRANCH/INSTITUT der Kontonummer
                cast(FACILITY_ID as VARCHAR(64))                as FACILITY_ID,                     -- FACILITY_ID (wie im System gefunden)
                cast(FACILITY_ID_LEADING as VARCHAR(64))                as FACILITY_ID_LEADING,     -- FACILITY_ID (bevorzugt nach NLB)
                nullif(cast(FACILITY_ID_NLB as VARCHAR(64)) ,NULL)           as FACILITY_ID_NLB,    -- FACILITY_ID nach NLB
                nullif(cast(FACILITY_ID_BLB as VARCHAR(64)) ,NULL)           as FACILITY_ID_BLB,    -- FACILITY_ID nach BLB
                nullif(cast(FACILITY_ID_CBB as VARCHAR(64)) ,NULL)           as FACILITY_ID_CBB,    -- FACILITY_ID nach CBB
                cast(CURRENCY as CHAR(3))                       as CURRENCY,                        -- Kontowährung
                -- Portfolio Infos
                cast(PORTFOLIO_EY as VARCHAR(1024))             as PORTFOLIO_EY_FACILITY,           -- Text Beschreibung, in welches Portfolio dieses Konto gehört, woher es kommt, ob es angefragt wurde und ob es eine Vererbung ist
                cast(PORTFOLIO_EY_CLIENT_ROOT as VARCHAR(1024)) as PORTFOLIO_EY_CLIENT_ROOT,        -- Text Beschreibung, in welches Portfolio dieser Kunde gehört
                nullif(cast(PORTFOLIO_IWHS_CLIENT_KUNDENBERATER as VARCHAR(1024)),NULL)  as PORTFOLIO_IWHS_CLIENT_KUNDENBERATER, -- Text Beschreibung, in welches Portfolio dieser Kunde nach IWHS KUNDENBRATER_OE gehört
                nullif(cast(PORTFOLIO_IWHS_CLIENT_SERVICE as VARCHAR(1024)),NULL)        as PORTFOLIO_IWHS_CLIENT_SERVICE,       -- Text Beschreibung, in welches Portfolio dieser Kunde nach IWHS SERVICE_OE gehört
                nullif(cast(PORTFOLIO_KR_CLIENT as VARCHAR(1024))     ,NULL)             as PORTFOLIO_KR_CLIENT,                 -- Text Beschreibung, ob dieser Kunde nach BigBen oder TowerBridge gehört
                nullif(cast(PORTFOLIO_GARANTIEN_CLIENT as VARCHAR(1024)) ,NULL)          as PORTFOLIO_GARANTIEN_CLIENT,          -- Text Beschreibung, ob dieser Kunde nach BigBen, TowerBridge, Aviation oder Maritime Industries gehört
                -- Flags Infos
                nullif(cast(IS_CLIENT_GUARANTEE_FLAGGED as BOOLEAN),NULL)    as IS_CLIENT_GUARANTEE_FLAGGED,     -- Ist der Kunde Garantie Flagged in IWHS?
                nullif(cast(IS_FACILITY_GUARANTEE_FLAGGED as BOOLEAN),NULL)  as IS_FACILITY_GUARANTEE_FLAGGED,   -- Ist das Konto Garantie Flagged in IWHS?
                nullif(cast(IS_FACILITY_FROM_SINGAPORE as BOOLEAN),NULL)     as IS_FACILITY_FROM_SINGAPORE,      -- Ist es ein Singapur Konto (d.h. Schützenswert)?
                -- Data Infos
                Current USER                                    as CREATED_USER,                    -- Letzter Nutzer, der diese Tabelle gebaut hat.
                Current TIMESTAMP                               as CREATED_TIMESTAMP                -- Neuester Zeitstempel, wann diese Tabelle zuletzt gebaut wurde.
         from DATA_WITH_FLAGS
         where (NEW_CUT_OFF_DATE in (select CUT_OFF_DATE from CURRENT_CUT_OFF_DATE) or
                DATA_CUT_OFF_DATE in (select CUT_OFF_DATE from CURRENT_CUT_OFF_DATE))
     )
select * from FINAL_RESULT
;
grant select on CALC.VIEW_PORTFOLIO to group NLB_MW_ADAP_S_GNI_TROOPER;
------------------------------------------------------------------------------------------------------------------------

-- CI START FOR ALL TAPES

-- CURRENT TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_PORTFOLIO_CURRENT');
create table AMC.TABLE_PORTFOLIO_CURRENT like CALC.VIEW_PORTFOLIO distribute by hash(FACILITY_ID_LEADING,FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_PORTFOLIO_CURRENT_BRANCH_CLIENT       on AMC.TABLE_PORTFOLIO_CURRENT (BRANCH_CLIENT);
create index AMC.INDEX_PORTFOLIO_CURRENT_CLIENT_NO           on AMC.TABLE_PORTFOLIO_CURRENT (CLIENT_NO);
create index AMC.INDEX_PORTFOLIO_CURRENT_CLIENT_ID_ORIG      on AMC.TABLE_PORTFOLIO_CURRENT (CLIENT_ID_ORIG);
create index AMC.INDEX_PORTFOLIO_CURRENT_FACILITY_ID         on AMC.TABLE_PORTFOLIO_CURRENT (FACILITY_ID);
create index AMC.INDEX_PORTFOLIO_CURRENT_FACILITY_ID_LEADING on AMC.TABLE_PORTFOLIO_CURRENT (FACILITY_ID_LEADING);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_PORTFOLIO_CURRENT');
grant select on AMC.TABLE_PORTFOLIO_CURRENT to group NLB_MW_ADAP_S_GNI_TROOPER;
------------------------------------------------------------------------------------------------------------------------

-- ARCHIVE TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_PORTFOLIO_ARCHIVE');
create table AMC.TABLE_PORTFOLIO_ARCHIVE like CALC.VIEW_PORTFOLIO distribute by hash(FACILITY_ID_LEADING,FACILITY_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_PORTFOLIO_ARCHIVE_BRANCH_CLIENT       on AMC.TABLE_PORTFOLIO_ARCHIVE (BRANCH_CLIENT);
create index AMC.INDEX_PORTFOLIO_ARCHIVE_CLIENT_NO           on AMC.TABLE_PORTFOLIO_ARCHIVE (CLIENT_NO);
create index AMC.INDEX_PORTFOLIO_ARCHIVE_CLIENT_ID_ORIG      on AMC.TABLE_PORTFOLIO_ARCHIVE (CLIENT_ID_ORIG);
create index AMC.INDEX_PORTFOLIO_ARCHIVE_FACILITY_ID         on AMC.TABLE_PORTFOLIO_ARCHIVE (FACILITY_ID);
create index AMC.INDEX_PORTFOLIO_ARCHIVE_FACILITY_ID_LEADING on AMC.TABLE_PORTFOLIO_ARCHIVE (FACILITY_ID_LEADING);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_PORTFOLIO_ARCHIVE');
grant select on AMC.TABLE_PORTFOLIO_ARCHIVE to group NLB_MW_ADAP_S_GNI_TROOPER;
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCHES erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_PORTFOLIO_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_PORTFOLIO_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

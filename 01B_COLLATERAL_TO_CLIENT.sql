------------------------------------------------------------------------------------------------------------------------
/* Collateral to Client
 *
 * Das Collateralization Tape besteht aus 4 Schritten, wovon dieser der erste zum Ausführen ist.
 * Dieses Tape zeigt die Beziehung zwischen Konten (Facilities), Sicherheitenverträgen (Collaterals) und
 * Vermögensobjekten (Assets) auf.
 * Collateral to Clients bildet spezielle Sicherheitenvertragsbeziehungen ab, welche nicht an einem Konto sondern direkt
 * am Kunden hängen.
 *
 * (1) Collateral to (A) Facility/ (B) Client
 * (2) Collaterals
 * (3) Asset to Collateral
 * (4) Assets
 */
------------------------------------------------------------------------------------------------------------------------
-- View erstellen
drop view CALC.VIEW_COLLATERAL_TO_CLIENT;
create or replace view CALC.VIEW_COLLATERAL_TO_CLIENT as
with
    -- Relevante Kontenliste
    PORTFOLIO as (
        select
            CLIENT_NO           as CLIENT_NO,
            CLIENT_ID_ORIG      as CLIENT_ID,
            CUT_OFF_DATE        as CUT_OFF_DATE,
            BRANCH_SYSTEM       as BRANCH
        from CALC.SWITCH_PORTFOLIO_CURRENT
    ),
    -- relevante Kontenliste erweitert um die detailierte Branch und der SKTO (Spot Kontonummer) aus CBB SPOT Stammdaten
    PORTFOLIO_EXTENDED as (
        select distinct
            PORTFOLIO.CUT_OFF_DATE,
            PORTFOLIO.CLIENT_NO,
            PORTFOLIO.CLIENT_ID,
            PORTFOLIO.BRANCH
        from PORTFOLIO as PORTFOLIO
    ),
    IWHS_LINK_CURRENT as (
        select
            IWHS_LINK.CUT_OFF_DATE,
            PORTFOLIO_EXTENDED.CLIENT_ID, /*Eindeutige Personennummer*/
            -- SICHERHEITENVERTRÄGE
            IWHS_LINK.SIRE_ID_IWHS as COLLATERAL_ID,
            IWHS_LINK.SIRE_ID_ORACLE as COLLATERAL_ID_ORACLE, /*Eindeutiger Schlüssel zur Identifikation eines Sicherungsrechtes im externen System (Oracle)*/
            IWHS_LINK.SICHERHEITENSCHLUESSEL,  /*Beschreibung des SVZ IMU, bei Rollen: lange Bezeichnung*/
            -- Sonstiges
            NULL as MAX_RISK_VERT_JE_GW,
            PORTFOLIO_EXTENDED.BRANCH,
            'IWHS' as DATA_SOURCE
        from PORTFOLIO_EXTENDED
        inner join NLB.IWHS_KF2SV_CURRENT as IWHS_LINK on IWHS_LINK.PERSONEN_NR = PORTFOLIO_EXTENDED.CLIENT_NO and IWHS_LINK.BRANCH = LEFT(PORTFOLIO_EXTENDED.CLIENT_ID,3) and IWHS_LINK.CUT_OFF_DATE = PORTFOLIO_EXTENDED.CUT_OFF_DATE
        where SIHT_BOBJ_TYP = 'KUNDE'
    ),
    -- AOER Verknüpfungen
    COLLATERAL_TO_CLIENT_AOER as (
        select
            CUT_OFF_DATE,CLIENT_ID,COLLATERAL_ID,COLLATERAL_ID_ORACLE,MAX_RISK_VERT_JE_GW,BRANCH,DATA_SOURCE,
            row_number() over (partition by CLIENT_ID,COLLATERAL_ID)  as NBR
        from IWHS_LINK_CURRENT
    ),
    COLLATERAL_TO_CLIENT as (
        select
            CUT_OFF_DATE,CLIENT_ID,COLLATERAL_ID,COLLATERAL_ID_ORACLE,MAX_RISK_VERT_JE_GW,BRANCH,DATA_SOURCE
        from COLLATERAL_TO_CLIENT_AOER where NBR = 1
     ),
     final as (
        select
            C2C.CUT_OFF_DATE,                                                                                              -- Stichtag
            C2C.CLIENT_ID,                                                                                                 -- Kundennummer (Format BRANCH_Nummer)
            C2C.COLLATERAL_ID,                                                                                             -- Sicherheitenvertragsnummer
            cast(NULL as DOUBLE)                                                                   as MAX_RISK_VERT_JE_GW, -- An diesem Konto(Saldo inkl Auszahlungsverprflichtungen) durch diese Sicherheit besichert in EUR
            NULLIF(C2C.BRANCH, NULL)                                                               as BRANCH,              -- Institut (des Kontos?)
            NULLIF(case 
				when C2C.DATA_SOURCE = '1SUR' then 'SUR'
				when C2C.DATA_SOURCE = '2LIQ' then 'LIQ'
				when C2C.DATA_SOURCE = 'CMS' then 'CMS'
                when C2C.DATA_SOURCE = 'IWHS' then 'IWHS'
				else 'MAN'
			end, NULL)                                                                             as SOURCE,
            Current USER                                                                           as CREATED_USER,        -- Letzter Nutzer, der dieses Tape gebaut hat.
            Current TIMESTAMP                                                                      as CREATED_TIMESTAMP,   -- Neuester Zeitstempel, wann dieses Tape zuletzt gebaut wurde.
            row_number() over (partition by CLIENT_ID,C2C.COLLATERAL_ID ORDER BY DATA_SOURCE DESC) as NBR                  --sortiere nach Data_Source, damit gilt: MANUAL>CMS>LIQ>SUR.
        from COLLATERAL_TO_CLIENT as C2C
        where CLIENT_ID is not NULL and COLLATERAL_ID is not NULL
     )
    select CUT_OFF_DATE,CLIENT_ID,COLLATERAL_ID,MAX_RISK_VERT_JE_GW,BRANCH,SOURCE,CREATED_USER,CREATED_TIMESTAMP from final where NBR =1
;

-- CI START FOR ALL TAPES
-- Current-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_COLLATERAL_TO_CLIENT_CURRENT');
create table AMC.TABLE_COLLATERAL_TO_CLIENT_CURRENT like CALC.VIEW_COLLATERAL_TO_CLIENT distribute by hash(COLLATERAL_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_COLLATERAL_TO_CLIENT_CURRENT_FACILITY_ID   on AMC.TABLE_COLLATERAL_TO_CLIENT_CURRENT (CLIENT_ID);
create index AMC.INDEX_COLLATERAL_TO_CLIENT_CURRENT_COLLATERAL_ID on AMC.TABLE_COLLATERAL_TO_CLIENT_CURRENT (COLLATERAL_ID);
comment on table AMC.TABLE_COLLATERAL_TO_CLIENT_CURRENT is 'Verknüpfung aller Collaterals, welche an einem der gewünschten Kunden hängen aber nicht an einem Konto (Aktueller Stichtag)';
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_COLLATERAL_TO_CLIENT_CURRENT');
-- Archiv-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_COLLATERAL_TO_CLIENT_ARCHIVE');
create table AMC.TABLE_COLLATERAL_TO_CLIENT_ARCHIVE like CALC.VIEW_COLLATERAL_TO_CLIENT distribute by hash(COLLATERAL_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2025' EVERY 1 MONTH) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_COLLATERAL_TO_CLIENT_ARCHIVE_FACILITY_ID   on AMC.TABLE_COLLATERAL_TO_CLIENT_ARCHIVE (CLIENT_ID);
create index AMC.INDEX_COLLATERAL_TO_CLIENT_ARCHIVE_COLLATERAL_ID on AMC.TABLE_COLLATERAL_TO_CLIENT_ARCHIVE (COLLATERAL_ID);
comment on table AMC.TABLE_COLLATERAL_TO_CLIENT_ARCHIVE is 'Verknüpfung aller Collaterals, welche an einem der gewünschten Kunden hängen aber nicht an einem Konto (Alle Stichtage)';
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_COLLATERAL_TO_CLIENT_ARCHIVE');
-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_COLLATERAL_TO_CLIENT_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_COLLATERAL_TO_CLIENT_ARCHIVE');
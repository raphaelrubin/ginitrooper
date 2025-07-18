------------------------------------------------------------------------------------------------------------------------
/* Collateral to Facility
 *
 * Das Collateralization Tape besteht aus 4 Schritten, wovon dieser der erste zum Ausführen ist.
 * Dieses Tape zeigt die Beziehung zwischen Konten (Facilities), Sicherheitenverträgen (Collaterals) und
 * Vermögensobjekten (Assets) auf.
 *
 * (1) Collateral to (A) Facility/ (B) Client
 * (2) Collaterals
 * (3) Asset to Collateral
 * (4) Assets
 */
------------------------------------------------------------------------------------------------------------------------
-- View erstellen
drop view CALC.VIEW_COLLATERAL_TO_FACILITY;
create or replace view CALC.VIEW_COLLATERAL_TO_FACILITY as
with
    -- Relevante Kontenliste
    PORTFOLIO as (
        select
            CLIENT_NO           as CLIENT_NO,
            CLIENT_ID_ORIG      as CLIENT_ID,
            FACILITY_ID         as FACILITY_ID,
            FACILITY_ID_NLB,
            FACILITY_ID_CBB,
            CUT_OFF_DATE        as CUT_OFF_DATE,
            BRANCH_SYSTEM       as BRANCH
        from CALC.SWITCH_PORTFOLIO_CURRENT
    ),
    -- relevante Kontenliste erweitert um die detailierte Branch und der SKTO (Spot Kontonummer) aus CBB SPOT Stammdaten
    PORTFOLIO_EXTENDED as (
        select
            PORTFOLIO.CUT_OFF_DATE,
            PORTFOLIO.FACILITY_ID,
            PORTFOLIO.FACILITY_ID_NLB,
            PORTFOLIO.FACILITY_ID_CBB,
            PORTFOLIO.CLIENT_NO,
            PORTFOLIO.CLIENT_ID,
            case
                when SUBSTR(PORTFOLIO.FACILITY_ID, 6, 2) in ('69') then 'NL07'
                when SUBSTR(PORTFOLIO.FACILITY_ID, 6, 2) in ('70') then 'NL01'
                when SUBSTR(PORTFOLIO.FACILITY_ID, 6, 2) in ('71') then 'NL02'
                when SUBSTR(PORTFOLIO.FACILITY_ID, 6, 2) in ('73') then 'NL03'
                when SUBSTR(PORTFOLIO.FACILITY_ID, 1, 4) = '0004' then 'BLB'
                else 'NLB'
            end                         as BRANCH,
            SPOT_STAMMDATEN_CBB.SKTO    as SPOT_INTERNAL_FACILITY_ID_CBB -- SPOT interne Kontonummer/ HNV_KEY (Schlüssel HR)
        from PORTFOLIO                     as PORTFOLIO
        left join CBB.SPOT_STAMMDATEN_CURRENT   as SPOT_STAMMDATEN_CBB  on SPOT_STAMMDATEN_CBB.CUTOFFDATE = PORTFOLIO.CUT_OFF_DATE
                                                                          and left(PORTFOLIO.FACILITY_ID_CBB, 12) = 'K028-' || (SPOT_STAMMDATEN_CBB.KKTOAVA + case when PORTFOLIO.FACILITY_ID_CBB = 'K028-2588653_1020' then 3 else 1 end)
    ),
    CMS_LINK_CURRENT as (
        --Replacements aus issue #678
        select *
        from CALC.SWITCH_NLB_CMS_LINK_REPLACEMENT_CURRENT
        union all
        select *
        from CALC.SWITCH_BLB_CMS_LINK_REPLACEMENT_CURRENT
    ),
    IWHS_LINK_CURRENT as (
        select
            IWHS_LINK.CUT_OFF_DATE,
            coalesce(PORTFOLIO_EXTENDED.FACILITY_ID_CBB, PORTFOLIO_EXTENDED.FACILITY_ID)    as FACILITY_ID,
            PORTFOLIO_EXTENDED.CLIENT_ID as CLIENT_ID, /*Eindeutige Personennummer*/
            -- SICHERHEITENVERTRÄGE
            IWHS_LINK.SIRE_ID_IWHS as COLLATERAL_ID,
            IWHS_LINK.SIRE_ID_ORACLE as COLLATERAL_ID_ORACLE, /*Eindeutiger Schlüssel zur Identifikation eines Sicherungsrechtes im externen System (Oracle)*/
            IWHS_LINK.SICHERHEITENSCHLUESSEL,  /*Beschreibung des SVZ IMU, bei Rollen: lange Bezeichnung*/
            -- Sonstiges
            NULL as MAX_RISK_VERT_JE_GW,
            IWHS_LINK.BRANCH,
            QUELLE as DATA_SOURCE
        from PORTFOLIO_EXTENDED
        inner join NLB.IWHS_KF2SV_CURRENT as IWHS_LINK on IWHS_LINK.FACILITY_ID = PORTFOLIO_EXTENDED.FACILITY_ID_NLB and IWHS_LINK.CUT_OFF_DATE = PORTFOLIO_EXTENDED.CUT_OFF_DATE
        where SIHT_BOBJ_TYP <> 'KUNDE' -- unnötig, da inner join auf das Portfolio?
          and IWHS_LINK.FACILITY_ID is not NULL
    ),
    LIQ_GESCHAEFTE as (
        select * from NLB.LIQ_GESCHAEFTE where left(ALIAS, 3) = '425'
    ),
    -- AOER Verknüpfungen aus CMS_LINK
    COLLATERAL_TO_FACILITY_AOER as (
        select
            CMS_LINK.CUTOFFDATE                                 as CUT_OFF_DATE,
            coalesce(PORTFOLIO_EXTENDED.FACILITY_ID_CBB, PORTFOLIO_EXTENDED.FACILITY_ID)    as FACILITY_ID,
            PORTFOLIO_EXTENDED.CLIENT_ID as CLIENT_ID, /*Eindeutige Personennummer*/
            cast(CMS_LINK.SV_ID  as VARCHAR(32))                as COLLATERAL_ID,
            CMS_LINK.MAX_RISK_VERT_JE_GW,
            CMS_LINK.BRANCH,
            QUELLE                                              as DATA_SOURCE,
            row_number() over (partition by FACILITY_ID,SV_ID)  as NBR
        from PORTFOLIO_EXTENDED
        inner join CMS_LINK_CURRENT as CMS_LINK on (left(CMS_LINK.GW_FORDERUNGSID, 22) = left(PORTFOLIO_EXTENDED.FACILITY_ID_NLB, 22) or left(CMS_LINK.GW_FORDERUNGSID, 22) = left(PORTFOLIO_EXTENDED.FACILITY_ID, 22)) and CMS_LINK.CUTOFFDATE = PORTFOLIO_EXTENDED.CUT_OFF_DATE
        where CMS_LINK.SV_STATUS = 'Rechtlich aktiv'
        union all
        select
            CUT_OFF_DATE,FACILITY_ID,CLIENT_ID,COLLATERAL_ID,MAX_RISK_VERT_JE_GW,BRANCH,DATA_SOURCE,
            row_number() over (partition by FACILITY_ID,COLLATERAL_ID)  as NBR
        from IWHS_LINK_CURRENT
    ),
     collateral_LIQ_VIRTUAL_CONNECTIONS as (
         select
            LINK.CUTOFFDATE                     as CUT_OFF_DATE,
            FACILITY.FACILITY_ID                as FACILITY_ID,
            case
                when FACILITY.BRANCH in ('NLB', 'ANL', 'NL01', 'NL02', 'NL03', 'NL07')
                    then 'NLB'
                else FACILITY.BRANCH
            end || '_' || FACILITY.CLIENT_NO    as CLIENT_ID,
            LINK.SV_ID                          as COLLATERAL_ID,
            null                                as MAX_RISK_VERT_JE_GW, -- dieser wert ist für künstliche verbindungen immer null
            FACILITY.BRANCH                     as BRANCH,
         row_number() over (partition by FACILITY_ID,SV_ID)  as NBR
        from PORTFOLIO          as FACILITY
        inner join LIQ_GESCHAEFTE        as LIQ_STRUCT   on substr(FACILITY.FACILITY_ID, 11, 10) =
                                                          case
                                                              when substr(FACILITY.FACILITY_ID, 11, 3) = '421' then VARCHAR(DCN)
                                                              when substr(FACILITY.FACILITY_ID, 11, 3) = '423' then VARCHAR(FCN)
                                                              else ALIAS
                                                          end
                                                          and FACILITY.CUT_OFF_DATE = date(LIQ_STRUCT.BESTANDSDATUM)
        left join NLB.LIQ_DEAL_STATUS   as LIQ_STATUS   on LIQ_STATUS.OUTSTANDING_ID = ALIAS and LIQ_STATUS.CUTOFFDATE = FACILITY.CUT_OFF_DATE
        left join CALC.SWITCH_NLB_CMS_LINK_REPLACEMENT_CURRENT         as LINK         on LINK.GW_KONTO =
                                                          case
                                                              when substr(LINK.GW_KONTO, 1, 3) = '421'
                                                                  then VARCHAR(LIQ_STRUCT.DCN)
                                                              when substr(LINK.GW_KONTO, 1, 3) = '423'
                                                                  then VARCHAR(LIQ_STRUCT.FCN)
                                                              when substr(LINK.GW_KONTO, 1, 3) = '425'
                                                                  then ALIAS
                                                              else substr(FACILITY.FACILITY_ID, 11, 10)
                                                          end
                                                          and LINK.CUTOFFDATE = FACILITY.CUT_OFF_DATE
         where SV_STATUS = 'Rechtlich aktiv' and ACTIVATION_STATUS ='Active'

     ),
    -- CBB Verknüpfungen aus CMS_LINK
    COLLATERAL_TO_FACILITY_CBB as (
        select distinct
            CMS_LINK.CUTOFFDATE                                     as CUT_OFF_DATE
          , coalesce(PORTFOLIO_EXTENDED.FACILITY_ID_CBB, PORTFOLIO_EXTENDED.FACILITY_ID)    as FACILITY_ID
          , CASE
                WHEN PORTFOLIO_EXTENDED.BRANCH in ('NLB', 'ANL', 'NL01', 'NL02', 'NL03', 'NL07') THEN 'NLB'
                ELSE PORTFOLIO_EXTENDED.BRANCH
            END || '_' || PORTFOLIO_EXTENDED.CLIENT_NO              as CLIENT_ID
          , cast(CMS_LINK.SV_ID  as VARCHAR(32))                    as COLLATERAL_ID
          ,CMS_LINK.MAX_RISK_VERT_JE_GW
          , CMS_LINK.BRANCH
          , QUELLE as DATA_SOURCE
        from PORTFOLIO_EXTENDED
        inner join CMS_LINK_CURRENT as CMS_LINK on CMS_LINK.GW_KONTO = PORTFOLIO_EXTENDED.SPOT_INTERNAL_FACILITY_ID_CBB and CMS_LINK.CUTOFFDATE = PORTFOLIO_EXTENDED.CUT_OFF_DATE
        where CMS_LINK.SV_STATUS = 'Rechtlich aktiv'
    ),
        COLLATERAL_FROM_SURROGATE as (
         select c2f.CUT_OFF_DATE as CUT_OFF_DATE,
                sur.FACILITY_ID_NEW as FACILITY_ID,
                CLIENT_ID,
                cast(COLLATERAL_ID as VARCHAR(32))  as COLLATERAL_ID,
                MAX_RISK_VERT_JE_GW,
                BRANCH,
                '1SUR' as DATA_SOURCE
                from CALC.VIEW_SURROGATE sur inner join COLLATERAL_TO_FACILITY_AOER c2f on c2f.FACILITY_ID = sur.FACILITY_ID_INIT
         where c2f.NBR =1 and c2f.CUT_OFF_DATE BETWEEN coalesce(sur.VALID_FROM_DATE, DATE('1900-01-01')) AND coalesce(sur.VALID_TO_DATE, DATE('9999-12-31')) --Konten, die nicht durch Rekursion entstanden sind, haben kein Enddatum
            union all
            select c2f.CUT_OFF_DATE as CUT_OFF_DATE,
                sur.FACILITY_ID_NEW as FACILITY_ID,
                CLIENT_ID,
                cast(COLLATERAL_ID as VARCHAR(32))  as COLLATERAL_ID,
                MAX_RISK_VERT_JE_GW,
                BRANCH,
                '1SUR' as DATA_SOURCE
                from CALC.VIEW_SURROGATE sur inner join COLLATERAL_TO_FACILITY_CBB c2f on c2f.FACILITY_ID = sur.FACILITY_ID_INIT
         where c2f.CUT_OFF_DATE BETWEEN coalesce(sur.VALID_FROM_DATE, DATE('1900-01-01')) AND coalesce(sur.VALID_TO_DATE, DATE('9999-12-31')) --Konten, die nicht durch Rekursion entstanden sind, haben kein Enddatum
         ),
             COLLATERAL_FROM_LIQ_NACHFOLGE as (
         select c2f.CUT_OFF_DATE as CUT_OFF_DATE,
                sur.NEW_OUTSTANDING as FACILITY_ID,
                CLIENT_ID,
                COLLATERAL_ID,
                MAX_RISK_VERT_JE_GW,
                BRANCH
               ,'2LIQ' as DATA_SOURCE
                from CALC.VIEW_LIQ_NACHFOLGE sur inner join COLLATERAL_TO_FACILITY_AOER c2f on c2f.FACILITY_ID = sur.OLD_OUTSTANDING
         where c2f.NBR =1 and c2f.CUT_OFF_DATE > sur.BESTANDSDATUM
            union all
            select c2f.CUT_OFF_DATE as CUT_OFF_DATE,
                sur.NEW_OUTSTANDING as FACILITY_ID,
                CLIENT_ID,
                COLLATERAL_ID,
                MAX_RISK_VERT_JE_GW,
                BRANCH
               ,'2LIQ' as DATA_SOURCE
                from CALC.VIEW_LIQ_NACHFOLGE sur inner join COLLATERAL_TO_FACILITY_CBB c2f on c2f.FACILITY_ID = sur.OLD_OUTSTANDING
         where c2f.CUT_OFF_DATE > sur.BESTANDSDATUM
         ),
    COLLATERAL_TO_FACILITY as (
        select
            CUT_OFF_DATE,FACILITY_ID,CLIENT_ID,COLLATERAL_ID,MAX_RISK_VERT_JE_GW,BRANCH,DATA_SOURCE
        from COLLATERAL_TO_FACILITY_AOER where NBR = 1
        union all
        select distinct
            CUT_OFF_DATE,FACILITY_ID,CLIENT_ID,COLLATERAL_ID,MAX_RISK_VERT_JE_GW,BRANCH,DATA_SOURCE
        from COLLATERAL_TO_FACILITY_CBB
        /*
        union all
        select
            CUT_OFF_DATE,FACILITY_ID,CLIENT_ID,COLLATERAL_ID,MAX_RISK_VERT_JE_GW,BRANCH
        from collateral_LIQ_VIRTUAL_CONNECTIONS where NBR = 1
        --diese Funktionalität wird derzeit nicht benötigt. Absprache mit EY. iehe dazu auch MAIL von Fabian kOch an Sven Wilbert vom 22.06.2020 20:00 Uhr
         */
        union
        select
            CUT_OFF_DATE,FACILITY_ID,CLIENT_ID,COLLATERAL_ID,MAX_RISK_VERT_JE_GW,BRANCH,DATA_SOURCE
        from COLLATERAL_FROM_SURROGATE
        union
        select
            CUT_OFF_DATE,FACILITY_ID,CLIENT_ID,COLLATERAL_ID,MAX_RISK_VERT_JE_GW,BRANCH,DATA_SOURCE
        from COLLATERAL_FROM_LIQ_NACHFOLGE
     ),
     final as (
        select
            C2F.CUT_OFF_DATE,                                -- Stichtag
            C2F.CLIENT_ID,                                   -- Kundennummer (Format BRANCH_Nummer)
            C2f.FACILITY_ID,
            cast(C2F.COLLATERAL_ID as VARCHAR(32))                                     as COLLATERAL_ID,       -- Sicherheitenvertragsnummer
            sum(MAX_RISK_VERT_JE_GW) over (partition by FACILITY_ID,C2f.COLLATERAL_ID) as MAX_RISK_VERT_JE_GW, -- An diesem Konto(Saldo inkl Auszahlungsverprflichtungen) durch diese Sicherheit besichert in EUR
            NULLIF(C2F.BRANCH, NULL)                                                   as BRANCH,              -- Institut (des Kontos?)
            NULLIF(case 
				when C2F.DATA_SOURCE = '1SUR' then 'SUR'
				when C2F.DATA_SOURCE = '2LIQ' then 'LIQ'
				when C2F.DATA_SOURCE = 'CMS' then 'CMS'
                when C2F.DATA_SOURCE = 'IWHS' then 'IWHS'
				else 'MAN'
			end, NULL)        as DATA_SOURCE,
            Current USER      as CREATED_USER,            -- Letzter Nutzer, der dieses Tape gebaut hat.
            Current TIMESTAMP as CREATED_TIMESTAMP,       -- Neuester Zeitstempel, wann dieses Tape zuletzt gebaut wurde.
            row_number() over (partition by FACILITY_ID,C2f.COLLATERAL_ID ORDER BY DATA_SOURCE DESC)  as NBR --sortiere nach Data_Source, damit gilt: MANUAL>CMS>LIQ>SUR.
        from COLLATERAL_TO_FACILITY as C2F
     )
    select CUT_OFF_DATE,CLIENT_ID,FACILITY_ID,COLLATERAL_ID,MAX_RISK_VERT_JE_GW,BRANCH,DATA_SOURCE,CREATED_USER,CREATED_TIMESTAMP from final where NBR =1
;

-- CI START FOR ALL TAPES
-- Current-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_COLLATERAL_TO_FACILITY_CURRENT');
create table AMC.TABLE_COLLATERAL_TO_FACILITY_CURRENT like CALC.VIEW_COLLATERAL_TO_FACILITY distribute by hash(COLLATERAL_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_COLLATERAL_TO_FACILITY_CURRENT_FACILITY_ID   on AMC.TABLE_COLLATERAL_TO_FACILITY_CURRENT (FACILITY_ID);
create index AMC.INDEX_COLLATERAL_TO_FACILITY_CURRENT_COLLATERAL_ID on AMC.TABLE_COLLATERAL_TO_FACILITY_CURRENT (COLLATERAL_ID);
comment on table AMC.TABLE_COLLATERAL_TO_FACILITY_CURRENT is 'Verknüpfung aller Collaterals, welche an einem der gewünschten Konten hängen. (Aktueller Stichtag)';
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_COLLATERAL_TO_FACILITY_CURRENT');
-- Archiv-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_COLLATERAL_TO_FACILITY_ARCHIVE');
create table AMC.TABLE_COLLATERAL_TO_FACILITY_ARCHIVE like CALC.VIEW_COLLATERAL_TO_FACILITY distribute by hash(COLLATERAL_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2025' EVERY 1 MONTH) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_COLLATERAL_TO_FACILITY_ARCHIVE_FACILITY_ID   on AMC.TABLE_COLLATERAL_TO_FACILITY_ARCHIVE (FACILITY_ID);
create index AMC.INDEX_COLLATERAL_TO_FACILITY_ARCHIVE_COLLATERAL_ID on AMC.TABLE_COLLATERAL_TO_FACILITY_ARCHIVE (COLLATERAL_ID);
comment on table AMC.TABLE_COLLATERAL_TO_FACILITY_ARCHIVE is 'Verknüpfung aller Collaterals, welche an einem der gewünschten Konten hängen. (Alle Stichtage)';
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_COLLATERAL_TO_FACILITY_ARCHIVE');
-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_COLLATERAL_TO_FACILITY_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_COLLATERAL_TO_FACILITY_ARCHIVE');
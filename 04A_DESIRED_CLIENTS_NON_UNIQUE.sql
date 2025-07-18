/*Liste aller gewünschten Kunden in allen möglichen Formaten*/

-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_PORTFOLIO_DESIRED_CLIENTS_PRE;
create or replace view CALC.VIEW_PORTFOLIO_DESIRED_CLIENTS_PRE as
with
    CURRENT_CUTOFFDATE as (
        select CUT_OFF_DATE from CALC.AUTO_TABLE_CUTOFFDATES where IS_ACTIVE
    ),
    LAST_CUTOFFDATE as (
        select MAX(ARCHIVE.CUT_OFF_DATE) as CUT_OFF_DATE
        from CALC.AUTO_TABLE_CUTOFFDATES as ARCHIVE
        inner join CURRENT_CUTOFFDATE as CURRENT on CURRENT.CUT_OFF_DATE > ARCHIVE.CUT_OFF_DATE
    ),
    -- Grundgesammtheit
    CLIENT_COLLECTION_BASICS as (
        select COD.CUT_OFF_DATE, BRANCH_CLIENT, CLIENT_NO, PORTFOLIO as PORTFOLIO, SOURCE
        from CALC.SWITCH_PORTFOLIO_MANUAL_CLIENTS_CURRENT as CLIENTS
        inner join CURRENT_CUTOFFDATE            as COD      on COD.CUT_OFF_DATE between COALESCE(CLIENTS.VALID_FROM_DATE,'01/01/2015') and COALESCE(CLIENTS.VALID_TO_DATE,CURRENT_DATE)
        where SOURCE <> 'Manuelle Kundenliste'
    ),
    -- Kunden aus manueller Ergänzung
    CLIENT_COLLECTION_MANUAL as (
        select distinct COD.CUT_OFF_DATE, BRANCH_CLIENT, CLIENT_NO, PORTFOLIO as PORTFOLIO, 'Manuelle Kundenliste' as SOURCE
        from CALC.SWITCH_PORTFOLIO_MANUAL_CLIENTS_CURRENT  as CLIENTS
        inner join CURRENT_CUTOFFDATE                    as COD      on COD.CUT_OFF_DATE between COALESCE(CLIENTS.VALID_FROM_DATE,'01/01/2015') and COALESCE(CLIENTS.VALID_TO_DATE,CURRENT_DATE)
        where SOURCE = 'Manuelle Kundenliste'
    ),
    -- Kunden zu Konten aus GG, Manueller ergänzung und Archiv
    CLIENT_COLLECTION_FACILITIES as (
        select distinct COD.CUT_OFF_DATE, BRANCH_CLIENT, CLIENT_NO, PORTFOLIO_ROOT as PORTFOLIO, SOURCE as SOURCE
        from CALC.SWITCH_PORTFOLIO_CLIENTS_FROM_FACILITIES_CURRENT  as CLIENTS
        inner join CURRENT_CUTOFFDATE                    as COD      on COD.CUT_OFF_DATE = CLIENTS.CUT_OFF_DATE
    ),
    -- Derivate reinholen
    CLIENT_COLLECTION_DERIVATE_SPOT as (
        select
            -- stellt die Kundengrundgesamtheit aus dem Derivatebereich ab März 2020 dar
            CUT_OFF_DATE,
            'NLB'                as BRANCH_CLIENT,
            BORROWERID           as CLIENT_NO,
            NULL                 as PORTFOLIO_ROOT,
            'SPOT Derivate'      as SOURCE
        from NLB.SPOT_DERIVATE_CURRENT
    ),
    CLIENT_COLLECTION_DERIVATE_SPOT_BIS_202003 as (
        select
            --stellt die Kundengrundgesamtheit aus dem Derivatebereich bis März 2020 dar
            CUT_OFF_DATE,
            'NLB' as BRANCH_CLIENT,
            KUNDENNUMMER as CLIENT_NO,
            NULL as PORTFOLIO_ROOT,
            'SPOT Derivate Hüsken'      as SOURCE
        from NLB.DERIVATE_TEMP_CURRENT
    ),
     CLIENT_COLLECTION_DERIVATE_MUREX as (
        select
            --stellt die Kundengrundgesamtheit aus dem Derivatebereich Aviation dar
            CUT_OFF_DATE,
            'NLB' as BRANCH_CLIENT,
            KUNDENNUMMER as CLIENT_NO,
            NULL as PORTFOLIO_ROOT,
            'Murex Derivate'      as SOURCE
        from NLB.DERIVATE_MUREX_CURRENT
    ),
    -- Kunden aus früheren Läufen
    CLIENT_COLLECTION_ARCHIVE as (
        select
            CUT_OFF_DATE,
            BRANCH_CLIENT,
            CLIENT_NO,
            case
                when PORTFOLIO_ROOT <> 'Ohne Portfolio' then
                    PORTFOLIO_ROOT
                else
                    NULL
            end as PORTFOLIO,
            'Archive'      as SOURCE
        from (
            select distinct
                COD.CUT_OFF_DATE,
                BRANCH_CLIENT                            as BRANCH_CLIENT,
                CLIENT_NO as CLIENT_NO,
                NULL                                                              as CLIENT_ID_REQUESTED,
                CALC.MAP_FUNC_PORTFOLIO_TO_ROOT(PORTFOLIO_EY_CLIENT_ROOT)                      as PORTFOLIO_ROOT
            from CALC.SWITCH_PORTFOLIO_DESIRED_CLIENTS_ARCHIVE as PORTFOLIO_ARCHIVE
            inner join LAST_CUTOFFDATE on LAST_CUTOFFDATE.CUT_OFF_DATE = PORTFOLIO_ARCHIVE.CUT_OFF_DATE
            cross join CURRENT_CUTOFFDATE as COD
        )
        where BRANCH_CLIENT in ('NLB','BLB','CBB') -- komische ANL Kunden aus der Vergangenheit ausschließen
    ),
    -- ZEB Kunden für ZEB Portfolio
    CLIENTS_ZEB as (
        select distinct
            CUTOFFDATE as CUT_OFF_DATE,
            BRANCH as BRANCH_CLIENT,
            BIGINT(E_CUSTOMER_ID) as CLIENT_NO,
            PRJ_OE_NAME as PORTFOLIO_ROOT,
            PRJ_KUST_ID as KUST_ID
        from NLB.ZEB_CONTROL
    ),
    -- IWHS Kunden (außer Privatpersonen) für OE Match
    CLIENTS_IWHS as (
        select CUTOFFDATE, BRANCH, BORROWERID, OE_BEZEICHNUNG as BERATER_OE_BEZEICHNUNG, OE_NR as BERATER_OE_NR, SERVICE_OE_BEZEICHNUNG, SERVICE_OE_NR,
            case when IWHS.PERSONTYPE in ('N', 'P') then TRUE else FALSE end as IS_PRIVATE
        from NLB.IWHS_KUNDE_CURRENT as IWHS
        left join CALC.AUTO_TABLE_TAPES as TAPE on TAPE.IS_ACTIVE = TRUE
        where (IWHS.PERSONTYPE not in ('N', 'P') or TAPE.INCLUDE_PRIVATE_CLIENTS) -- Privatkunden ausschließen wenn nicht im Tape erwünscht
          and not (IWHS.PERSONTYPE in ('P','N') and IWHS.BIRTHDAY > CURRENT_DATE - 18 YEARS) -- keine Kinder!
        union all
        select CUTOFFDATE, BRANCH, BORROWERID, OE_BEZEICHNUNG as BERATER_OE_BEZEICHNUNG, OE_NR as BERATER_OE_NR, SERVICE_OE_BEZEICHNUNG, SERVICE_OE_NR,
            case when IWHS.PERSONTYPE in ('N', 'P') then TRUE else FALSE end as IS_PRIVATE
        from BLB.IWHS_KUNDE_CURRENT as IWHS
        left join CALC.AUTO_TABLE_TAPES as TAPE on TAPE.IS_ACTIVE = TRUE
        where (IWHS.PERSONTYPE not in ('N', 'P') or TAPE.INCLUDE_PRIVATE_CLIENTS) -- Privatkunden ausschließen wenn nicht im Tape erwünscht
          and not (IWHS.PERSONTYPE in ('P','N') and IWHS.BIRTHDAY > CURRENT_DATE - 18 YEARS) -- keine Kinder!
    ),
    -- alle gewünschten Kunden zusammenführen (Info: PORTFOLIO_ORDER 2 ist reserviert für Einträge mit IWHS Portfolio)
    CLIENT_COLLECTION as (
        -- Grundgesammtheit
        select *, 4 as PORTFOLIO_ORDER from CLIENT_COLLECTION_BASICS
        union all
        -- Kunden aus manueller Ergänzung
        select *, 1 as PORTFOLIO_ORDER from CLIENT_COLLECTION_MANUAL
        union all
        -- Kunden aus Facility Analyse
        select *, case when SOURCE = 'Konten Archiv' then 8 else 4 end as PORTFOLIO_ORDER from CLIENT_COLLECTION_FACILITIES
        union all
        -- Kunden aus SPOT Derivate
        select SOURCE.*, 7 as PORTFOLIO_ORDER from CLIENT_COLLECTION_DERIVATE_SPOT as SOURCE
        left join CALC.AUTO_TABLE_TAPES as TAPE on TAPE.IS_ACTIVE = TRUE
        where TAPE.INCLUDE_ALL_DERIVATIVES_BY_DEFAULT -- Kunden für alle Derivate nur für gewünschte Tapes
        union all
        -- Kunden aus SPOT Derivate Hüsken
        select SOURCE.*, 7 as PORTFOLIO_ORDER from CLIENT_COLLECTION_DERIVATE_SPOT_BIS_202003 as SOURCE
        left join CALC.AUTO_TABLE_TAPES as TAPE on TAPE.IS_ACTIVE = TRUE
        where TAPE.INCLUDE_ALL_DERIVATIVES_BY_DEFAULT -- Kunden für alle Derivate nur für gewünschte Tapes
        union all
        -- Kunden aus Murex Derivate
        select SOURCE.*, 7 as PORTFOLIO_ORDER from CLIENT_COLLECTION_DERIVATE_MUREX as SOURCE
        left join CALC.AUTO_TABLE_TAPES as TAPE on TAPE.IS_ACTIVE = TRUE
        where TAPE.INCLUDE_ALL_DERIVATIVES_BY_DEFAULT -- Kunden für alle Derivate nur für gewünschte Tapes
    ),
    -- Join über OSPlusOE
    CLIENTS_WITH_SAME_OE as (
        select distinct
            IWHS_A.BRANCH         as BRANCH_CLIENT,
            IWHS_A.BORROWERID     as CLIENT_NO,
            IWHS_A.BERATER_OE_BEZEICHNUNG as PORTFOLIO,
            'IWHS OSPlusOE'       as SOURCE
        from CLIENTS_IWHS               as IWHS_A
        inner join CLIENTS_IWHS         as IWHS_B           on IWHS_B.BRANCH = IWHS_A.BRANCH
                                                               and left(IWHS_A.BERATER_OE_NR, 5) = left(IWHS_B.BERATER_OE_NR, 5)
        inner join CLIENT_COLLECTION    as CLIENTS_SO_FAR   on IWHS_B.BRANCH = CLIENTS_SO_FAR.BRANCH_CLIENT
                                                               and IWHS_B.BORROWERID = CLIENTS_SO_FAR.CLIENT_NO
        where IWHS_B.BERATER_OE_NR not in ('5140509','0','2270204','2270302','2270304','2270203','2191204','2220102','2210405','2142012','2161105','2142003','2142008')
          and left(IWHS_B.BERATER_OE_NR,5) not in ('22201','21908','21439','21203','22703','21611','21443','21913','21714','22104','21002','21001')
    ),
    CLIENTS_COLLECTION_IWHS as (
        select distinct
            IWHS.BRANCH         as BRANCH_CLIENT,
            IWHS.BORROWERID     as CLIENT_NO,
            IWHS.BERATER_OE_BEZEICHNUNG as PORTFOLIO,
            'IWHS'              as SOURCE
        from CLIENTS_IWHS               as IWHS
        inner join CLIENT_COLLECTION    as CLIENTS_SO_FAR   on IWHS.BRANCH = CLIENTS_SO_FAR.BRANCH_CLIENT
                                                               and IWHS.BORROWERID = CLIENTS_SO_FAR.CLIENT_NO
        where IWHS.BERATER_OE_BEZEICHNUNG is not NULL
    ),
    CLIENTS_COLLECTION_MAN_OE as (
        select distinct
            IWHS.CUTOFFDATE     as CUT_OFF_DATE,
            IWHS.BRANCH         as BRANCH_CLIENT,
            IWHS.BORROWERID     as CLIENT_NO,
            MAN_OE.PORTFOLIO    as PORTFOLIO,
            'IWHS manuelle OEn'              as SOURCE
        from CLIENTS_IWHS               as IWHS
        inner join CALC.SWITCH_PORTFOLIO_MANUAL_OE_CURRENT as  MAN_OE on IWHS.BERATER_OE_BEZEICHNUNG = MAN_OE.OE_BEZEICHNUNG and IWHS.CUTOFFDATE between MAN_OE.VALID_FROM_DATE and MAN_OE.VALID_TO_DATE
        --inner join CURRENT_CUTOFFDATE on IWHS.CUTOFFDATE between MAN_OE.VALID_FROM_DATE and MAN_OE.VALID_TO_DATE
        left join CLIENT_COLLECTION    as CLIENTS_SO_FAR   on IWHS.BRANCH = CLIENTS_SO_FAR.BRANCH_CLIENT
                                                               and IWHS.BORROWERID = CLIENTS_SO_FAR.CLIENT_NO
        where CLIENTS_SO_FAR.CLIENT_NO is null or CLIENTS_SO_FAR.PORTFOLIO_ORDER > 8 --be sure Client is not in already desired clients
    ),
    CLIENT_COLLECTION_INCLUDING_ARCHIVE as (
        select * from CLIENT_COLLECTION
        union all
--        select *, 2 as PORTFOLIO_ORDER from CLIENTS_WITH_SAME_OE
--         union all
--                 select *, 2 as PORTFOLIO_ORDER from CLIENTS_COLLECTION_IWHS
--         union all
         select *, 9 as PORTFOLIO_ORDER from CLIENTS_COLLECTION_MAN_OE
         union all
        select *, 11 as PORTFOLIO_ORDER from CLIENT_COLLECTION_ARCHIVE
    ),
    -- Portfolio eindeutig machen
    PORTFOLIO_SELECTION as (
        select distinct
            first_value(CUT_OFF_DATE) over (partition by CLIENT_NO, BRANCH_CLIENT order by CUT_OFF_DATE DESC nulls last) as CUT_OFF_DATE,
            BRANCH_CLIENT,
            CLIENT_NO,
            first_value(PORTFOLIO) over (partition by CLIENT_NO, BRANCH_CLIENT order by PORTFOLIO_ORDER, PORTFOLIO ASC nulls last) as PORTFOLIO_ROOT,
            first_value(case when PORTFOLIO in ('BigBen','TowerBridge') then PORTFOLIO else NULL end) over (partition by CLIENT_NO, BRANCH_CLIENT order by case when PORTFOLIO in ('BigBen','TowerBridge') then PORTFOLIO else NULL end ASC NULLS last) as PORTFOLIO_KR_CLIENT, --,'Aviation','Maritime Industries'
            first_value(SOURCE) over (partition by CLIENT_NO, BRANCH_CLIENT order by PORTFOLIO_ORDER, PORTFOLIO ASC nulls last) as SOURCE,
            first_value(PORTFOLIO_ORDER) over (partition by CLIENT_NO, BRANCH_CLIENT order by PORTFOLIO_ORDER, PORTFOLIO ASC nulls last) as PORTFOLIO_ORDER
        from CLIENT_COLLECTION_INCLUDING_ARCHIVE
    ),
    -- bevorzugten Portfolionamen auswählen
    -- Dies ist eine eindeutige Liste aller explizit gewünschten Kunden
    -- IWHS wird rangejoint um aktuelle Portfolio Bezeichnungen zu haben
    DESIRED_CLIENTS_REQUESTED as (
        select
            CUT_OFF_DATE,
            BRANCH_CLIENT,
            CLIENT_NO,
            BRANCH_CLIENT || '_' || CLIENT_NO as CLIENT_ID,
            case when BRANCH_CLIENT = 'NLB' then
                BRANCH_CLIENT || '_' || CLIENT_NO
            end as CLIENT_ID_NLB,
            case when BRANCH_CLIENT = 'BLB' then
                BRANCH_CLIENT || '_' || CLIENT_NO
            end as CLIENT_ID_BLB,
            case when BRANCH_CLIENT = 'CBB' then
                BRANCH_CLIENT || '_' || CLIENT_NO
            end as CLIENT_ID_CBB,
            case when PORTFOLIO_ORDER = 1 then
                coalesce(PORTFOLIO_ROOT,CLIENTS_IWHS.BERATER_OE_BEZEICHNUNG)
            else coalesce(CLIENTS_IWHS.BERATER_OE_BEZEICHNUNG,PORTFOLIO_ROOT)
            end as PORTFOLIO_EY_CLIENT_ROOT,
            PORTFOLIO_KR_CLIENT,
            CLIENTS_IWHS.BERATER_OE_BEZEICHNUNG as PORTFOLIO_IWHS_CLIENT_KUNDENBERATER,
            CLIENTS_IWHS.SERVICE_OE_BEZEICHNUNG as PORTFOLIO_IWHS_CLIENT_SERVICE,
            SOURCE,
            case when CLIENTS_IWHS.BERATER_OE_BEZEICHNUNG is not NULL then
                MIN(PORTFOLIO_ORDER,2)
            else
                PORTFOLIO_ORDER
            end as PORTFOLIO_ORDER
        from PORTFOLIO_SELECTION
        left join CLIENTS_IWHS on (CLIENTS_IWHS.BORROWERID,CLIENTS_IWHS.BRANCH) = (PORTFOLIO_SELECTION.CLIENT_NO,PORTFOLIO_SELECTION.BRANCH_CLIENT)
    ),
    -- Bekannte Doppelkunden:
--     CLIENT_DUPLICATES as (
--         select DUPLICATES.*
--         from CALC.VIEW_GEKO_DOPPELKUNDEN as DUPLICATES
--         inner join CURRENT_CUTOFFDATE    as COD          on COD.CUT_OFF_DATE = DUPLICATES.CUT_OFF_DATE
--     ),
    -- Mapping von NLB Kundennummern auf CBB Kundennummern
    CLIENT_NLB_TO_LUX as (
        select * from CALC.VIEW_CLIENT_CBB_TO_NLB
    ),
    -- Institutsfusions-Mapping
    CLIENT_BLB_TO_NLB as (
        select * from CALC.SWITCH_CLIENTS_BLB_TO_NLB_CURRENT
    ),
--     -- Institutsfusions-Mapping
--     CLIENT_INSTITUTSFUSION as (
--         select * from SMAP.CLIENT_INSTITUTSFUSION
--     ),
    -- hinzufügen der Geko Doppelkunden und Institutsfusion
    DESIRED_CLIENTS_NLB_TO_BLB_REVERSE as (
        select
            BASE.BRANCH_CLIENT                                         as BRANCH_CLIENT,
            BASE.CLIENT_NO                                             as CLIENT_NO,
            BASE.CLIENT_ID                                             as CLIENT_ID,
            coalesce(MAPPING.CLIENT_ID_LEADING,BASE.CLIENT_ID)         as CLIENT_ID_LEADING,
            coalesce(MAPPING.CLIENT_ID_NLB,BASE.CLIENT_ID_NLB)         as CLIENT_ID_NLB,
            coalesce(MAPPING.CLIENT_ID_BLB,BASE.CLIENT_ID_BLB)         as CLIENT_ID_BLB,
            BASE.CLIENT_ID_CBB                                         as CLIENT_ID_CBB,
            PORTFOLIO_EY_CLIENT_ROOT,
            PORTFOLIO_KR_CLIENT,
            PORTFOLIO_IWHS_CLIENT_KUNDENBERATER                        as PORTFOLIO_IWHS_CLIENT_KUNDENBERATER,
            PORTFOLIO_IWHS_CLIENT_SERVICE,
            BASE.SOURCE                                                as SOURCE,
            BASE.PORTFOLIO_ORDER                                       as PORTFOLIO_ORDER
        from DESIRED_CLIENTS_REQUESTED as BASE
        left join CLIENT_BLB_TO_NLB    as MAPPING on (MAPPING.BRANCH, MAPPING.CLIENT_NO) = (BASE.BRANCH_CLIENT, BASE.CLIENT_NO)
    ),
    -- Doppelkunden + Insitutsfusion basierend of CLIENT_ID_LEADING
    DESIRED_CLIENTS_NLB_TO_BLB_NLB_LEADING as (
        select
            MAPPING.BRANCH                            as BRANCH_CLIENT,
            MAPPING.CLIENT_NO                         as CLIENT_NO,
            MAPPING.CLIENT_ID                         as CLIENT_ID,
            MAPPING.CLIENT_ID_LEADING,
            MAPPING.CLIENT_ID_NLB                     as CLIENT_ID_NLB,
            MAPPING.CLIENT_ID_BLB                     as CLIENT_ID_BLB,
            BASE.CLIENT_ID_CBB                        as CLIENT_ID_CBB,
            PORTFOLIO_EY_CLIENT_ROOT,
            PORTFOLIO_KR_CLIENT,
            PORTFOLIO_IWHS_CLIENT_KUNDENBERATER       as PORTFOLIO_IWHS_CLIENT_KUNDENBERATER,
            PORTFOLIO_IWHS_CLIENT_SERVICE,
            MAPPING.SOURCE                            as SOURCE,
            BASE.PORTFOLIO_ORDER+MAPPING.PORTFOLIO_ORDER                         as PORTFOLIO_ORDER
        from DESIRED_CLIENTS_REQUESTED as BASE
        left join CLIENT_BLB_TO_NLB    as MAPPING on (MAPPING.CLIENT_ID_LEADING) = (BASE.CLIENT_ID)
        where CLIENT_ID_LEADING is not NULL
    ),
    -- Doppelkunden + Insitutsfusion basierend of CLIENT_ID_NLB
    DESIRED_CLIENTS_NLB_TO_BLB_NLB as (
        select
            MAPPING.BRANCH                            as BRANCH_CLIENT,
            MAPPING.CLIENT_NO                         as CLIENT_NO,
            MAPPING.CLIENT_ID                         as CLIENT_ID,
            MAPPING.CLIENT_ID_LEADING,
            MAPPING.CLIENT_ID_NLB                     as CLIENT_ID_NLB,
            MAPPING.CLIENT_ID_BLB                     as CLIENT_ID_BLB,
            BASE.CLIENT_ID_CBB                        as CLIENT_ID_CBB,
            PORTFOLIO_EY_CLIENT_ROOT,
            PORTFOLIO_KR_CLIENT,
            PORTFOLIO_IWHS_CLIENT_KUNDENBERATER       as PORTFOLIO_IWHS_CLIENT_KUNDENBERATER,
            PORTFOLIO_IWHS_CLIENT_SERVICE,
            MAPPING.SOURCE                            as SOURCE,
            BASE.PORTFOLIO_ORDER+MAPPING.PORTFOLIO_ORDER                        as PORTFOLIO_ORDER
        from DESIRED_CLIENTS_REQUESTED as BASE
        left join CLIENT_BLB_TO_NLB    as MAPPING on (MAPPING.CLIENT_ID_NLB) = (BASE.CLIENT_ID)
        where CLIENT_ID_LEADING is not NULL
    ),
    -- Doppelkunden + Insitutsfusion basierend of CLIENT_ID_BLB
    DESIRED_CLIENTS_NLB_TO_BLB_BLB as (
        select
            MAPPING.BRANCH                            as BRANCH_CLIENT,
            MAPPING.CLIENT_NO                         as CLIENT_NO,
            MAPPING.CLIENT_ID                         as CLIENT_ID,
            MAPPING.CLIENT_ID_LEADING,
            MAPPING.CLIENT_ID_NLB                     as CLIENT_ID_NLB,
            MAPPING.CLIENT_ID_BLB                     as CLIENT_ID_BLB,
            BASE.CLIENT_ID_CBB                        as CLIENT_ID_CBB,
            PORTFOLIO_EY_CLIENT_ROOT,
            PORTFOLIO_KR_CLIENT,
            PORTFOLIO_IWHS_CLIENT_KUNDENBERATER       as PORTFOLIO_IWHS_CLIENT_KUNDENBERATER,
            PORTFOLIO_IWHS_CLIENT_SERVICE,
            MAPPING.SOURCE                            as SOURCE,
            BASE.PORTFOLIO_ORDER+MAPPING.PORTFOLIO_ORDER                        as PORTFOLIO_ORDER
        from DESIRED_CLIENTS_REQUESTED as BASE
        left join CLIENT_BLB_TO_NLB    as MAPPING on (MAPPING.CLIENT_ID_BLB) = (BASE.CLIENT_ID)
        where CLIENT_ID_LEADING is not NULL
    ),
    DESIRED_CLIENTS_WITHOUT_LUX as (
        select * from DESIRED_CLIENTS_NLB_TO_BLB_REVERSE
        union all
        select * from DESIRED_CLIENTS_NLB_TO_BLB_NLB_LEADING
        union all
        select * from DESIRED_CLIENTS_NLB_TO_BLB_NLB
        union all
        select * from DESIRED_CLIENTS_NLB_TO_BLB_BLB
    ),
    -- hinzufügen der LUX-Kundennummern
    -- Alias für bestehende Kunden hinzufügen
    DESIRED_CLIENTS_LUX_REVERSE as (
        select
            BASE.BRANCH_CLIENT                      as BRANCH_CLIENT,
            BASE.CLIENT_NO                          as CLIENT_NO,
            BASE.CLIENT_ID                          as CLIENT_ID,
            coalesce('NLB_' || CBB2NLB.CLIENT_NO_NLB,BASE.CLIENT_ID_LEADING) as CLIENT_ID_LEADING,
            case when CBB2NLB.CLIENT_NO_NLB is not NULL then
                'NLB_' || CBB2NLB.CLIENT_NO_NLB
            else
                CLIENT_ID_NLB
            end                                     as CLIENT_ID_NLB,
            CLIENT_ID_BLB                           as CLIENT_ID_BLB,
            case when NLB2CBB.CLIENT_NO_CBB is not NULL then
                'CBB_' || NLB2CBB.CLIENT_NO_CBB
            else
                CLIENT_ID_CBB
            end                                     as CLIENT_ID_CBB,
            PORTFOLIO_EY_CLIENT_ROOT                as PORTFOLIO_EY_CLIENT_ROOT,
            PORTFOLIO_IWHS_CLIENT_KUNDENBERATER     as PORTFOLIO_IWHS_CLIENT_KUNDENBERATER,
            PORTFOLIO_IWHS_CLIENT_SERVICE,
            PORTFOLIO_KR_CLIENT,
            BASE.SOURCE                                  as SOURCE,
            PORTFOLIO_ORDER                         as PORTFOLIO_ORDER
        from DESIRED_CLIENTS_WITHOUT_LUX as BASE
        left join CLIENT_NLB_TO_LUX as NLB2CBB on ('NLB', NLB2CBB.CLIENT_NO_NLB) = (BASE.BRANCH_CLIENT, BASE.CLIENT_NO)
        left join CLIENT_NLB_TO_LUX as CBB2NLB on ('CBB', CBB2NLB.CLIENT_NO_CBB) = (BASE.BRANCH_CLIENT, BASE.CLIENT_NO)
    ),
    -- neue CBB Kunden mit bestehendem Kunden als Alias hinzufügen.
    DESIRED_CLIENTS_LUX as (
        select
            'CBB'                                   as BRANCH_CLIENT,
            MAPPING.CLIENT_NO_CBB                   as CLIENT_NO,
            'CBB_' || MAPPING.CLIENT_NO_CBB         as CLIENT_ID,
            coalesce('NLB_' || MAPPING.CLIENT_NO_NLB,BASE.CLIENT_ID_LEADING) as CLIENT_ID_LEADING,
            BASE.CLIENT_ID_NLB                      as CLIENT_ID_NLB,
            BASE.CLIENT_ID_BLB                      as CLIENT_ID_BLB,
            case when BASE.CLIENT_ID_CBB is NULL then
                'CBB_' || MAPPING.CLIENT_NO_CBB
            else
                BASE.CLIENT_ID_CBB
            end                                     as CLIENT_ID_CBB,
            PORTFOLIO_EY_CLIENT_ROOT                as PORTFOLIO_EY_CLIENT_ROOT,
            PORTFOLIO_IWHS_CLIENT_KUNDENBERATER     as PORTFOLIO_IWHS_CLIENT_KUNDENBERATER,
            PORTFOLIO_IWHS_CLIENT_SERVICE,
            PORTFOLIO_KR_CLIENT,
            'LUX KUNDEN'                            as SOURCE,
            PORTFOLIO_ORDER+1                       as PORTFOLIO_ORDER
        from DESIRED_CLIENTS_WITHOUT_LUX as BASE
        left join CLIENT_NLB_TO_LUX as MAPPING on ('NLB', MAPPING.CLIENT_NO_NLB) = (BASE.BRANCH_CLIENT, BASE.CLIENT_NO)
        where MAPPING.CLIENT_NO_CBB is not NULL
    ),
    -- Alle Kundennummern zusammenfügen
    ALL_DESIRED_CLIENTS as (
        select *
        from DESIRED_CLIENTS_LUX_REVERSE
        union all
        select *
        from DESIRED_CLIENTS_LUX
    )
select
    BASE.BRANCH_CLIENT,
    CLIENT_NO,
    CLIENT_ID,
    CLIENT_ID_LEADING,
    CLIENT_ID_NLB,
    CLIENT_ID_BLB,
    CLIENT_ID_CBB,
    PORTFOLIO_EY_CLIENT_ROOT,
    PORTFOLIO_IWHS_CLIENT_KUNDENBERATER,
    PORTFOLIO_IWHS_CLIENT_SERVICE,
    PORTFOLIO_KR_CLIENT,
    SOURCE,
    PORTFOLIO_ORDER
from ALL_DESIRED_CLIENTS as BASE
left join CLIENTS_IWHS as CLIENTS_IWHS on (BASE.BRANCH_CLIENT,BASE.CLIENT_NO)=(CLIENTS_IWHS.BRANCH,CLIENTS_IWHS.BORROWERID)
where CLIENT_NO is not NULL -- Sanity-Check. Sollte eigentlich nur bei fehlerhaften Anlieferungen passieren.
  and (CLIENTS_IWHS.BORROWERID is not NULL or BASE.BRANCH_CLIENT = 'CBB') -- Alle NLB und BLB Kunden müssen im IWHS stehen, Privatkunden werden ausgeschlossen
;
------------------------------------------------------------------------------------------------------------------------

-- CI START FOR ALL TAPES

-- CURRENT TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_PORTFOLIO_DESIRED_CLIENTS_PRE_CURRENT');
create table AMC.TABLE_PORTFOLIO_DESIRED_CLIENTS_PRE_CURRENT like CALC.VIEW_PORTFOLIO_DESIRED_CLIENTS_PRE distribute by hash(BRANCH_CLIENT,CLIENT_NO) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_PORTFOLIO_DESIRED_CLIENTS_PRE_CURRENT_CLIENT_ID on AMC.TABLE_PORTFOLIO_DESIRED_CLIENTS_PRE_CURRENT(BRANCH_CLIENT,CLIENT_NO);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_PORTFOLIO_DESIRED_CLIENTS_PRE_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_PORTFOLIO_DESIRED_CLIENTS_PRE_CURRENT');
------------------------------------------------------------------------------------------------------------------------

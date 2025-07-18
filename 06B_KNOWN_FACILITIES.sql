/* Diese View enthällt alle Konten aus allen Systemen für deren Kontoinhaber wir uns interessieren. Dabei sind Konten
   eindeutig. */

-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_PORTFOLIO_KNOWN_FACILITIES;
create or replace view CALC.VIEW_PORTFOLIO_KNOWN_FACILITIES as
with
    KNOWN_FACILITIES_ALL as (
        select * from CALC.SWITCH_PORTFOLIO_KNOWN_FACILITIES_NON_UNIQUE_CURRENT
    ),
    CHECK_CLIENT_LISTS as (
        select count(1) as ANZ
        from CALC.SWITCH_PORTFOLIO_MANUAL_CLIENTS_CURRENT
    ),
    CLIENTS_KNOWN_FACILITIES as (
        select BRANCH_CLIENT, KF.CLIENT_NO, SUM(ORDER_FACILITY) as COUNT_KNOWN_FACILITIES
        from CALC.SWITCH_PORTFOLIO_KNOWN_FACILITIES_NON_UNIQUE_CURRENT KF
        group by BRANCH_CLIENT, KF.CLIENT_NO
    ),
    KNOWN_FACILITIES_WITH_SELECTION as (
        select KNOWN_FACILITIES_ALL.*,
            ROW_NUMBER() over (partition by FACILITY_ID_LEADING,FACILITY_ID_CBB,CUT_OFF_DATE order by ORDER_NUMBER, BRANCH_SYSTEM ASC) as SELECTION, -- Muss hier CBB ID mit reinnehmen, weil mehrere CBB IDs an einer NLB ID hängen können, weil Gründe
            CLIENT.COUNT_KNOWN_FACILITIES,
            CCL.ANZ
        from KNOWN_FACILITIES_ALL
        cross join CHECK_CLIENT_LISTS as CCL
        left join CLIENTS_KNOWN_FACILITIES as CLIENT on (KNOWN_FACILITIES_ALL.CLIENT_NO, KNOWN_FACILITIES_ALL.BRANCH_CLIENT) = (CLIENT.CLIENT_NO, CLIENT.BRANCH_CLIENT)
    ),
    FACILITIES_FILTERED as (
        select KF.* from KNOWN_FACILITIES_WITH_SELECTION KF
            left join CALC.SWITCH_PORTFOLIO_FACILITY_MANUAL_CURRENT FM on
                                KF.FACILITY_ID = FM.FACILITY_ID OR
                                KF.FACILITY_ID_NLB = FM.FACILITY_ID OR
                                KF.FACILITY_ID_BLB = FM.FACILITY_ID OR
                                KF.FACILITY_ID_CBB = FM.FACILITY_ID OR
                                KF.FACILITY_ID_LEADING = FM.FACILITY_ID
            where KF.ANZ > 0 or FM.FACILITY_ID is not null
    ),
    RESULT as (
        select
            CUT_OFF_DATE,
            BRANCH_SYSTEM,  -- Institut des Quellsystems
            BRANCH_CLIENT,  -- Institut des Kunden
            CLIENT_NO,
            CLIENT_ID_SYSTEM,  -- Kunden ID wie im Quellsystem
            nullif(trim(B '+' FROM replace(replace(coalesce(CLIENT_IDS_NLB,'')||'+'||coalesce(CLIENT_IDS_BLB,'')||'+'||coalesce(CLIENT_IDS_CBB,''),coalesce(CLIENT_ID_SYSTEM,''),''),'++','')),'') as CLIENT_IDS_ALT,  -- Alternative IDs des Kunden unter denen er in anderen Systemen der Bank gefunden werden könnte.
            BORROWER_NO,
            BRANCH_FACILITY,  -- Institut des Kontos
            FACILITY_ID_LEADING,
            FACILITY_ID,
            FACILITY_ID_NLB,
            FACILITY_ID_BLB,
            FACILITY_ID_CBB,
            SYSTEM,
            case
                when COUNT_KNOWN_FACILITIES = 0 then
                    coalesce(FACILITY_REQUEST_TYPE,'') || ' (KUNDE HAT NUR ZUSATZKONTEN)'
                else
                    FACILITY_REQUEST_TYPE
            end as  FACILITY_REQUEST_TYPE,
            CURRENCY
        from FACILITIES_FILTERED
        where SELECTION = 1
    )
select
    CUT_OFF_DATE,                                                                           -- Stichtag für den die Daten berechnet werden
    CUT_OFF_DATE                                                as NEW_CUT_OFF_DATE,        -- Stichtag für den die Daten berechnet werden
    CUT_OFF_DATE                                                as DATA_CUT_OFF_DATE,       -- Stichtag für den die Daten gefunden wurden (in dieser Tabelle immer gleich NEW_CUT_OFF_DATE)
    BRANCH_SYSTEM                                               as BRANCH_SYSTEM,           -- Institut der Quelltabelle (NLB, BLB, ANL, CBB) z.B. BRANCH_SYSTEM = BLB und SYSTEM = SPOT => Quelle = BLB.SPOT_STAMMDATEN
    BRANCH_FACILITY                                             as BRANCH_FACILITY,         -- Institut des Kontos (NLB, BLB, CBB oder genaue ANL wie im Quellsystem gefunden)
    BRANCH_CLIENT                                               as BRANCH_CLIENT,           -- Institut des Kunden
    CLIENT_NO                                                   as CLIENT_NO,               -- Kundennummer ohne Institut
    cast(CLIENT_ID_SYSTEM as VARCHAR(64))                       as CLIENT_ID,               -- Kunden ID (Institut und Kundennummer in einem)
    cast(nullif(CLIENT_IDS_ALT,NULL) as VARCHAR(512))           as CLIENT_IDS_ALT,          -- alternative Kunden IDs + getrennt
    BORROWER_NO,
    cast(nullif(SYSTEM,NULL) as VARCHAR(64))                    as SYSTEM,                  -- Führendes Quellsystem für das Konto (SPOT, ALIS, DERIVATE, BW, DLD, AVALOQ)
    cast(nullif(FACILITY_REQUEST_TYPE,NULL) as VARCHAR(128))    as FACILITY_REQUEST_TYPE,   -- Anfrage Typ (ZUSATZKONTO o. KONTOAUFFÜLLUNG)
    cast(FACILITY_ID as VARCHAR(64))                            as FACILITY_ID,             -- enhält die Konto ID wie im System gefunden
    cast(FACILITY_ID_LEADING as VARCHAR(64))                    as FACILITY_ID_LEADING,     -- enhält die führende Konto ID (vermeidet Luxemburg IDs und BLB IDs wenn möglich)
    cast(nullif(FACILITY_ID_NLB,NULL) as VARCHAR(64))           as FACILITY_ID_NLB,         -- enhält die NLB Konto ID sofern vorhanden
    cast(nullif(FACILITY_ID_BLB,NULL) as VARCHAR(64))           as FACILITY_ID_BLB,         -- enhält die BLB Konto ID sofern vorhanden
    cast(nullif(FACILITY_ID_CBB,NULL) as VARCHAR(64))           as FACILITY_ID_CBB,         -- enhält die Luxemburg Konto ID sofern vorhanden
    CURRENCY                                                    as ORIGINAL_CURRENCY        -- Währung in welcher das Konto geführt wird.
from RESULT
;
------------------------------------------------------------------------------------------------------------------------

-- CI START FOR ALL TAPES

-- CURRENT TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_PORTFOLIO_KNOWN_FACILITIES_CURRENT');
create table AMC.TABLE_PORTFOLIO_KNOWN_FACILITIES_CURRENT like CALC.VIEW_PORTFOLIO_KNOWN_FACILITIES distribute by hash(FACILITY_ID,FACILITY_ID_CBB) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_PORTFOLIO_KNOWN_FACILITIES_CURRENT_BRANCH_CLIENT   on AMC.TABLE_PORTFOLIO_KNOWN_FACILITIES_CURRENT (BRANCH_CLIENT);
create index AMC.INDEX_PORTFOLIO_KNOWN_FACILITIES_CURRENT_CLIENT_NO       on AMC.TABLE_PORTFOLIO_KNOWN_FACILITIES_CURRENT (CLIENT_NO);
create index AMC.INDEX_PORTFOLIO_KNOWN_FACILITIES_CURRENT_FACILITY_ID     on AMC.TABLE_PORTFOLIO_KNOWN_FACILITIES_CURRENT (FACILITY_ID);
create index AMC.INDEX_PORTFOLIO_KNOWN_FACILITIES_CURRENT_FACILITY_ID_CBB on AMC.TABLE_PORTFOLIO_KNOWN_FACILITIES_CURRENT (FACILITY_ID_CBB);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_PORTFOLIO_KNOWN_FACILITIES_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- ARCHIVE TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_PORTFOLIO_KNOWN_FACILITIES_ARCHIVE');
create table AMC.TABLE_PORTFOLIO_KNOWN_FACILITIES_ARCHIVE like CALC.VIEW_PORTFOLIO_KNOWN_FACILITIES distribute by hash(FACILITY_ID,FACILITY_ID_CBB) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_PORTFOLIO_KNOWN_FACILITIES_ARCHIVE_BRANCH_CLIENT   on AMC.TABLE_PORTFOLIO_KNOWN_FACILITIES_ARCHIVE (BRANCH_CLIENT);
create index AMC.INDEX_PORTFOLIO_KNOWN_FACILITIES_ARCHIVE_CLIENT_NO       on AMC.TABLE_PORTFOLIO_KNOWN_FACILITIES_ARCHIVE (CLIENT_NO);
create index AMC.INDEX_PORTFOLIO_KNOWN_FACILITIES_ARCHIVE_FACILITY_ID     on AMC.TABLE_PORTFOLIO_KNOWN_FACILITIES_ARCHIVE (FACILITY_ID);
create index AMC.INDEX_PORTFOLIO_KNOWN_FACILITIES_ARCHIVE_FACILITY_ID_CBB on AMC.TABLE_PORTFOLIO_KNOWN_FACILITIES_ARCHIVE (FACILITY_ID_CBB);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_PORTFOLIO_KNOWN_FACILITIES_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_PORTFOLIO_KNOWN_FACILITIES_CURRENT');
------------------------------------------------------------------------------------------------------------------------

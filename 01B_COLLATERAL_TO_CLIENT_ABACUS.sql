------------------------------------------------------------------------------------------------------------------------
/*
 *  Collateral to Client ABACUS
 */
------------------------------------------------------------------------------------------------------------------------
-- View erstellen
drop view CALC.VIEW_COLLATERAL_TO_CLIENT_ABACUS;
create or replace view CALC.VIEW_COLLATERAL_TO_CLIENT_ABACUS as
with FACILITY_SAP as (
         select BW.CUT_OFF_DATE,
                case
                    when coalesce(GESCHAEFTSPARTNER_NO, '') = '' then null
                    else case
                             when
                                 translate(GESCHAEFTSPARTNER_NO, '', '0123456789') = ''
                                 then GESCHAEFTSPARTNER_NO end
                    end as SAP_KUNDE,
                    -- Abweichungen Kundennummer ca. 73 Stueck Portfolio und BW_EXT
                    LTRIM(BW.CLIENT_NO,'0') as CLIENT_NO
         from CALC.SWITCH_FACILITY_BW_P80_EXTERNAL_CURRENT BW
     ),
     DIST_SAP_KUNDE as (
        select distinct CUT_OFF_DATE, SAP_KUNDE, CLIENT_NO from FACILITY_SAP
     ),
     ABACUS_SAP_KUNDE as (
         select CUT_OFF_DATE,
                POSITION_ID as COLLATERAL_ID,
                case
                    when coalesce(PARTNER_ID30, '') = '' then null
                    else case
                             when
                                 translate(PARTNER_ID30, '', '0123456789') = ''
                                 then PARTNER_ID30 end
                    end as SAP_KUNDE,
                QUELLE
         FROM NLB.ABACUS_POSITION_CURRENT AP
         WHERE AP.POSITION_ID Like '0009-10-%-10-%'
     ),
    ABACUS_COLL_CLIENT_DIRECT as (
       SELECT ASK.CUT_OFF_DATE,
       COLLATERAL_ID,
       ASK.SAP_KUNDE,
       FS.CLIENT_NO,
       ASK.QUELLE
    FROM ABACUS_SAP_KUNDE ASK INNER JOIN DIST_SAP_KUNDE FS ON (ASK.CUT_OFF_DATE,ASK.SAP_KUNDE) = (FS.CUT_OFF_DATE,FS.SAP_KUNDE)
    ),
     -- Optional Collaterals direkt unter einem Kunden ohne FACILITY / Position connection
    ABACUS_COLL_CLIENT_DIRECT_FILTER as (
        select S.*
        FROM (SELECT
                   ACCD.CUT_OFF_DATE,
                   ACCD.CLIENT_NO,
                   ASK.COLLATERAL_ID,
                   ASK.SAP_KUNDE,
                   ASK.QUELLE
              FROM ABACUS_COLL_CLIENT_DIRECT as ACCD
              inner join ABACUS_SAP_KUNDE ASK on ASK.COLLATERAL_ID = ACCD.COLLATERAL_ID) as S
        LEFT JOIN NLB.ABACUS_POSITION_TO_POSITION_CURRENT P2P
            on S.COLLATERAL_ID = P2P.POSITION_ID2
        where P2P.POSITION_ID1 is null
    ),
    final as (
        select
            C2C.CUT_OFF_DATE,                                                                                              -- Stichtag
            C2C.COLLATERAL_ID,  -- Sicherheitenkennung
            C2C.CLIENT_NO,      -- Kundennummer
            C2C.SAP_KUNDE,
            QUELLE              as SOURCE,
            Current USER        as CREATED_USER,       -- Letzter Nutzer, der dieses Tape gebaut hat.
            Current TIMESTAMP   as CREATED_TIMESTAMP   -- Neuester Zeitstempel, wann dieses Tape zuletzt gebaut wurde.
        from ABACUS_COLL_CLIENT_DIRECT as C2C
        where SAP_KUNDE is not NULL and COLLATERAL_ID is not NULL
    )
    select distinct
        CUT_OFF_DATE,
        COLLATERAL_ID,
        CLIENT_NO,
        SAP_KUNDE,
        SOURCE,
        CREATED_USER,
        CREATED_TIMESTAMP
    from final
;

-- CI START FOR ALL TAPES
-- Current-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_COLLATERAL_TO_CLIENT_ABACUS_CURRENT');
create table AMC.TABLE_COLLATERAL_TO_CLIENT_ABACUS_CURRENT like CALC.VIEW_COLLATERAL_TO_CLIENT_ABACUS distribute by hash(COLLATERAL_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_COLLATERAL_TO_CLIENT_ABACUS_CURRENT_FACILITY_ID   on AMC.TABLE_COLLATERAL_TO_CLIENT_ABACUS_CURRENT (CLIENT_NO);
create index AMC.INDEX_COLLATERAL_TO_CLIENT_ABACUS_CURRENT_COLLATERAL_ID on AMC.TABLE_COLLATERAL_TO_CLIENT_ABACUS_CURRENT (COLLATERAL_ID);
comment on table AMC.TABLE_COLLATERAL_TO_CLIENT_ABACUS_CURRENT is 'Verknüpfung aller Collaterals, welche an einem der gewünschten Kunden hängen aber nicht an einem Konto (Aktueller Stichtag)';
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_COLLATERAL_TO_CLIENT_ABACUS_CURRENT');
-- Archiv-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_COLLATERAL_TO_CLIENT_ABACUS_ARCHIVE');
create table AMC.TABLE_COLLATERAL_TO_CLIENT_ABACUS_ARCHIVE like CALC.VIEW_COLLATERAL_TO_CLIENT_ABACUS distribute by hash(COLLATERAL_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2025' EVERY 1 MONTH) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_COLLATERAL_TO_CLIENT_ABACUS_ARCHIVE_FACILITY_ID   on AMC.TABLE_COLLATERAL_TO_CLIENT_ABACUS_ARCHIVE (CLIENT_NO);
create index AMC.INDEX_COLLATERAL_TO_CLIENT_ABACUS_ARCHIVE_COLLATERAL_ID on AMC.TABLE_COLLATERAL_TO_CLIENT_ABACUS_ARCHIVE (COLLATERAL_ID);
comment on table AMC.TABLE_COLLATERAL_TO_CLIENT_ABACUS_ARCHIVE is 'Verknüpfung aller Collaterals, welche an einem der gewünschten Kunden hängen aber nicht an einem Konto (Alle Stichtage)';
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_COLLATERAL_TO_CLIENT_ABACUS_ARCHIVE');
-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_COLLATERAL_TO_CLIENT_ABACUS_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_COLLATERAL_TO_CLIENT_ABACUS_ARCHIVE');
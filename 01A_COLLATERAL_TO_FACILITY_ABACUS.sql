------------------------------------------------------------------------------------------------------------------------
/*
 * COLLATERAL_TO_FACILITY_ABACUS
 */
------------------------------------------------------------------------------------------------------------------------
-- View erstellen
drop view CALC.VIEW_COLLATERAL_TO_FACILITY_ABACUS;
create or replace view CALC.VIEW_COLLATERAL_TO_FACILITY_ABACUS as
with ABACUS_KONTEN as (
        select * from CALC.SWITCH_FACILITY_ABACUS_KONTEN_GG_CURRENT
     ),
     ABACUS_FILTERED as (
        select distinct
               CUT_OFF_DATE,
               F001,
               case when instr(POSITION_ID1, '0#') > 1
                   then left(POSITION_ID1,instr(POSITION_ID1, '0#'))
                   else POSITION_ID1
               end as FACILITY_ID,
               case when instr(POSITION_ID2, '0#') > 1
                   then left(POSITION_ID2,instr(POSITION_ID2, '0#'))
                   else POSITION_ID2
               end as COLLATERAL_ID,
               TYP200,
               QUELLE
            from NLB.ABACUS_POSITION_TO_POSITION_CURRENT
        where POSITION_ID2 like '0009-10-%-10%'
     ),
     ABACUS_COLLATERAL_TO_FACILITY as (
        select PORTFOLIO.CUT_OFF_DATE,
               PORTFOLIO.FACILITY_ID,
               PORTFOLIO.CLIENT_NO,
               PORTFOLIO.SAP_KUNDE,
               AF.COLLATERAL_ID,
               AF.F001,
               AF.TYP200,
               AF.QUELLE as SOURCE
        from ABACUS_KONTEN as PORTFOLIO
         left join ABACUS_FILTERED as AF
          on PORTFOLIO.FACILITY_ID = AF.FACILITY_ID and PORTFOLIO.CUT_OFF_DATE = AF.CUT_OFF_DATE
     ),
     final as (
        select
            C2F.CUT_OFF_DATE,                                -- Stichtag
            C2F.FACILITY_ID,
            C2F.CLIENT_NO,
            C2F.SAP_KUNDE,
            cast(C2F.COLLATERAL_ID as VARCHAR(38)) as COLLATERAL_ID, -- Sicherheitenvertragsnummer
            C2F.F001,                                       -- Meldeeinheit
            C2F.TYP200,                                     -- Beziehungstyp
            C2F.SOURCE,
            Current USER      as CREATED_USER,            -- Letzter Nutzer, der dieses Tape gebaut hat.
            Current TIMESTAMP as CREATED_TIMESTAMP       -- Neuester Zeitstempel, wann dieses Tape zuletzt gebaut wurde.
        from ABACUS_COLLATERAL_TO_FACILITY as C2F
         where COLLATERAL_ID is not null and FACILITY_ID is not null
     )
    select
        CUT_OFF_DATE,
        FACILITY_ID,
        CLIENT_NO,
        SAP_KUNDE,
        COLLATERAL_ID,
        F001,
        TYP200,
        SOURCE,
        CREATED_USER,
        CREATED_TIMESTAMP
    from final
;

-- CI START FOR ALL TAPES
-- Current-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_COLLATERAL_TO_FACILITY_ABACUS_CURRENT');
create table AMC.TABLE_COLLATERAL_TO_FACILITY_ABACUS_CURRENT like CALC.VIEW_COLLATERAL_TO_FACILITY_ABACUS distribute by hash(COLLATERAL_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_COLLATERAL_TO_FACILITY_ABACUS_CURRENT_FACILITY_ID   on AMC.TABLE_COLLATERAL_TO_FACILITY_ABACUS_CURRENT (FACILITY_ID);
create index AMC.INDEX_COLLATERAL_TO_FACILITY_ABACUS_CURRENT_COLLATERAL_ID on AMC.TABLE_COLLATERAL_TO_FACILITY_ABACUS_CURRENT (COLLATERAL_ID);
comment on table AMC.TABLE_COLLATERAL_TO_FACILITY_ABACUS_CURRENT is 'Verknüpfung aller Collaterals, welche an einem der gewünschten Konten hängen. (Aktueller Stichtag)';
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_COLLATERAL_TO_FACILITY_ABACUS_CURRENT');
-- Archiv-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_COLLATERAL_TO_FACILITY_ABACUS_ARCHIVE');
create table AMC.TABLE_COLLATERAL_TO_FACILITY_ABACUS_ARCHIVE like CALC.VIEW_COLLATERAL_TO_FACILITY_ABACUS distribute by hash(COLLATERAL_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2025' EVERY 1 MONTH) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_COLLATERAL_TO_FACILITY_ABACUS_ARCHIVE_FACILITY_ID   on AMC.TABLE_COLLATERAL_TO_FACILITY_ABACUS_ARCHIVE (FACILITY_ID);
create index AMC.INDEX_COLLATERAL_TO_FACILITY_ABACUS_ARCHIVE_COLLATERAL_ID on AMC.TABLE_COLLATERAL_TO_FACILITY_ABACUS_ARCHIVE (COLLATERAL_ID);
comment on table AMC.TABLE_COLLATERAL_TO_FACILITY_ABACUS_ARCHIVE is 'Verknüpfung aller Collaterals, welche an einem der gewünschten Konten hängen. (Alle Stichtage)';
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_COLLATERAL_TO_FACILITY_ABACUS_ARCHIVE');
-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_COLLATERAL_TO_FACILITY_ABACUS_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_COLLATERAL_TO_FACILITY_ABACUS_ARCHIVE');
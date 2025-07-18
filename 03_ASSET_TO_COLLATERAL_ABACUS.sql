------------------------------------------------------------------------------------------------------------------------
/*
 * Asset to Collateral ABACUS
 */
------------------------------------------------------------------------------------------------------------------------
-- View erstellen
drop view CALC.VIEW_ASSET_TO_COLLATERAL_ABACUS;
create or replace view CALC.VIEW_ASSET_TO_COLLATERAL_ABACUS as
with
    -- Alle Collateral zu Asset Verknüpfungen in ABACUS
    Coll2Asset as (
        select distinct CUT_OFF_DATE,
                        F001,
                        POSITION_ID1 as COLLATERAL_ID,
                        OBJECT_ID1 as ASSET_ID,
                        L003, -- Vorlasten
                        BRANCH,
                        QUELLE as SOURCE
        from NLB.ABACUS_POSITION_TO_OBJECT_CURRENT
        where POSITION_ID1 like '0009-10%'
    ),
    -- alle möglichen ABACUS Assets
    ASSETS as (
        select distinct CUT_OFF_DATE,
                        OBJECT_ID as ASSET_ID,
                        QUELLE as SOURCE
        from NLB.ABACUS_OBJECT_CURRENT
    ),
    -- alle ABACUS Collaterals, welche mit dem Portfolio verknüpft sind
    COLLATERALS_DESIRED_ALL as (
        select CUT_OFF_DATE, COLLATERAL_ID
        from CALC.SWITCH_COLLATERAL_TO_FACILITY_ABACUS_CURRENT
        union all
        select CUT_OFF_DATE, COLLATERAL_ID
        from CALC.SWITCH_COLLATERAL_TO_CLIENT_ABACUS_CURRENT
    ),
    COLLATERALS_DESIRED_DIST as (
        select CUT_OFF_DATE, COLLATERAL_ID from (
                      select *,
                             ROWNUMBER() over ( PARTITION BY COLLATERAL_ID ORDER BY COLLATERAL_ID desc nulls last) as RN
                      from COLLATERALS_DESIRED_ALL
        ) where RN = 1
    )
select
    C2A.CUT_OFF_DATE                          as CUT_OFF_DATE,     -- Stichtag
    cast(C2A.COLLATERAL_ID as VARCHAR(64))    as COLLATERAL_ID,    -- ID Nummer des Sicherheiten Vertrages
    cast(C2A.ASSET_ID as VARCHAR(64))         as ASSET_ID,         -- ID Nummer des Vermögensobjekts
    cast(C2A.SOURCE as VARCHAR(32))           as SOURCE,
    C2A.L003 as L003,
    Current USER                              as CREATED_USER,     -- Letzter Nutzer, der dieses Tape gebaut hat.
    Current TIMESTAMP                         as CREATED_TIMESTAMP -- Neuester Zeitstempel, wann dieses Tape zuletzt gebaut wurde.
from Coll2Asset as C2A
left join ASSETS on (C2A.ASSET_ID,C2A.CUT_OFF_DATE)=(ASSETS.ASSET_ID,ASSETS.CUT_OFF_DATE)
inner join COLLATERALS_DESIRED_DIST as COLLATERALS  on (C2A.COLLATERAL_ID,C2A.CUT_OFF_DATE)=(COLLATERALS.COLLATERAL_ID,COLLATERALS.CUT_OFF_DATE)
;

-- CI START FOR ALL TAPES
-- Current-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_ASSET_TO_COLLATERAL_ABACUS_CURRENT');
create table AMC.TABLE_ASSET_TO_COLLATERAL_ABACUS_CURRENT like CALC.VIEW_ASSET_TO_COLLATERAL_ABACUS distribute by hash(ASSET_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.ASSET_TO_COLLATERAL_ABACUS_CURRENT_ASSET_ID      on AMC.TABLE_ASSET_TO_COLLATERAL_ABACUS_CURRENT (ASSET_ID);
create index AMC.ASSET_TO_COLLATERAL_ABACUS_CURRENT_COLLATERAL_ID on AMC.TABLE_ASSET_TO_COLLATERAL_ABACUS_CURRENT (COLLATERAL_ID);
comment on table AMC.TABLE_ASSET_TO_COLLATERAL_ABACUS_CURRENT is 'Verknüpfung aller Assets, welche an einem der gewünschten Collaterals hängen (Aktueller Stichtag)';
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_ASSET_TO_COLLATERAL_ABACUS_CURRENT');
-- Archiv-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_ASSET_TO_COLLATERAL_ABACUS_ARCHIVE');
create table AMC.TABLE_ASSET_TO_COLLATERAL_ABACUS_ARCHIVE like AMC.TABLE_ASSET_TO_COLLATERAL_ABACUS_CURRENT distribute by hash(ASSET_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2025' EVERY 1 MONTH) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.ASSET_TO_COLLATERAL_ABACUS_ARCHIVE_ASSET_ID      on AMC.TABLE_ASSET_TO_COLLATERAL_ABACUS_ARCHIVE (ASSET_ID);
create index AMC.ASSET_TO_COLLATERAL_ABACUS_ARCHIVE_COLLATERAL_ID on AMC.TABLE_ASSET_TO_COLLATERAL_ABACUS_ARCHIVE (COLLATERAL_ID);
comment on table AMC.TABLE_ASSET_TO_COLLATERAL_ABACUS_ARCHIVE is 'Verknüpfung aller Assets, welche an einem der gewünschten Collaterals hängen (Alle Stichtage)';
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_ASSET_TO_COLLATERAL_ABACUS_ARCHIVE');
-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_ASSET_TO_COLLATERAL_ABACUS_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_ASSET_TO_COLLATERAL_ABACUS_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------
/* Asset to Collateral
 *
 * Das Collateralization Tape besteht aus 4 Schritten, wovon dieser der dritte zum Ausführen ist.
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
drop view CALC.VIEW_ASSET_TO_COLLATERAL;
create or replace view CALC.VIEW_ASSET_TO_COLLATERAL as
with
    CMS_SV2VO as (
        select * from NLB.CMS_LAST_CURRENT
        union all
        select * from BLB.CMS_LAST_CURRENT
    ),
    IWHS_SV2VO as (
        select * from NLB.IWHS_SV2VO_CURRENT
        --union all
        --select * from BLB.IWHS_SV2VO_CURRENT
    ),
    -- Alle Collateral zu Asset Verknüpfungen
    SV2VO as (
        select CUTOFFDATE, cast(SV_ID as VARCHAR(64)) as SV_ID, cast(VO_ID as VARCHAR(32)) as VO_ID, BRANCH, 'CMS' as QUELLE from CMS_SV2VO
        union all
        select CUT_OFF_DATE as CUTOFFDATE, cast(SIRE_ID_IWHS as VARCHAR(64)) as SV_ID, cast(VMGO_ID_VVS as VARCHAR(32)) as VO_ID, BRANCH, 'IWHS' as QUELLE from IWHS_SV2VO
    ),
    -- alle möglichen Assets
    ASSETS as (
        select CUTOFFDATE as CUT_OFF_DATE, cast(VO_ID as VARCHAR(32)) as VO_ID, VO_STATUS, 'CMS' as QUELLE from NLB.CMS_VO_CURRENT
        union all
        select CUTOFFDATE as CUT_OFF_DATE, cast(VO_ID as VARCHAR(32)) as VO_ID, VO_STATUS, 'CMS' as QUELLE from BLB.CMS_VO_CURRENT
        union all
        select CUT_OFF_DATE, cast(VMGO_ID_VVS as VARCHAR(32)) as VO_ID, NULL as VO_STATUS, 'IWHS' as QUELLE from NLB.IWHS_VO_CURRENT
    ),
    -- alle Collaterals, welche mit dem Portfolio verknüpft sind
    COLLATERALS_DESIRED as (
    select distinct CUT_OFF_DATE, COLLATERAL_ID, BRANCH, SOURCE from
     (
         select CUT_OFF_DATE, COLLATERAL_ID, BRANCH,DATA_SOURCE as SOURCE
         from CALC.SWITCH_COLLATERAL_TO_FACILITY_CURRENT
         union all
         select CUT_OFF_DATE, COLLATERAL_ID, BRANCH,SOURCE
         from CALC.SWITCH_COLLATERAL_TO_CLIENT_CURRENT
     )
    )
select distinct
    SV2VO.CUTOFFDATE                          as CUT_OFF_DATE,     -- Stichtag
    cast(SV2VO.SV_ID as VARCHAR(64))          as COLLATERAL_ID,    -- ID Nummer des Sicherheiten Vertrages
    cast(SV2VO.VO_ID as VARCHAR(32))          as ASSET_ID,         -- ID Nummer des Vermögensobjekts
    cast(coalesce(COLLATERALS.BRANCH,SV2VO.BRANCH) as VARCHAR(8))  as BRANCH,           -- Institut
    cast(SV2VO.QUELLE as VARCHAR(8))          as SOURCE,
    Current USER                              as CREATED_USER,     -- Letzter Nutzer, der dieses Tape gebaut hat.
    Current TIMESTAMP                         as CREATED_TIMESTAMP -- Neuester Zeitstempel, wann dieses Tape zuletzt gebaut wurde.
from SV2VO                     as SV2VO
left join ASSETS               as ASSET        on (SV2VO.VO_ID,SV2VO.QUELLE,SV2VO.CUTOFFDATE)=(ASSET.VO_ID,ASSET.QUELLE,ASSET.CUT_OFF_DATE)
inner join COLLATERALS_DESIRED as COLLATERALS  on (SV2VO.SV_ID,SV2VO.QUELLE,SV2VO.CUTOFFDATE)=(COLLATERALS.COLLATERAL_ID,COLLATERALS.SOURCE,COLLATERALS.CUT_OFF_DATE)
where ASSET.VO_STATUS='Rechtlich aktiv' or SV2VO.QUELLE = 'IWHS'
;

-- CI START FOR ALL TAPES
-- Current-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_ASSET_TO_COLLATERAL_CURRENT');
create table AMC.TABLE_ASSET_TO_COLLATERAL_CURRENT like CALC.VIEW_ASSET_TO_COLLATERAL distribute by hash(ASSET_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_ASSET_TO_COLLATERAL_CURRENT_ASSET_ID      on AMC.TABLE_ASSET_TO_COLLATERAL_CURRENT (ASSET_ID);
create index AMC.INDEX_ASSET_TO_COLLATERAL_CURRENT_COLLATERAL_ID on AMC.TABLE_ASSET_TO_COLLATERAL_CURRENT (COLLATERAL_ID);
comment on table AMC.TABLE_ASSET_TO_COLLATERAL_CURRENT is 'Verknüpfung aller Assets, welche an einem der gewünschten Collaterals hängen (Aktueller Stichtag)';
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_ASSET_TO_COLLATERAL_CURRENT');
-- Archiv-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_ASSET_TO_COLLATERAL_ARCHIVE');
create table AMC.TABLE_ASSET_TO_COLLATERAL_ARCHIVE like AMC.TABLE_ASSET_TO_COLLATERAL_CURRENT distribute by hash(ASSET_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2025' EVERY 1 MONTH) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_ASSET_TO_COLLATERAL_ARCHIVE_ASSET_ID      on AMC.TABLE_ASSET_TO_COLLATERAL_ARCHIVE (ASSET_ID);
create index AMC.INDEX_ASSET_TO_COLLATERAL_ARCHIVE_COLLATERAL_ID on AMC.TABLE_ASSET_TO_COLLATERAL_ARCHIVE (COLLATERAL_ID);
comment on table AMC.TABLE_ASSET_TO_COLLATERAL_ARCHIVE is 'Verknüpfung aller Assets, welche an einem der gewünschten Collaterals hängen (Alle Stichtage)';
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_ASSET_TO_COLLATERAL_ARCHIVE');
-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_ASSET_TO_COLLATERAL_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_ASSET_TO_COLLATERAL_ARCHIVE');
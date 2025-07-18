/* VIEW_PORTFOLIO_ALIS
 * Sammelt alle Konten für die DESIRED CLIENTS aus den ALIS Quelltabellen
 */

-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_PORTFOLIO_ALIS;
create or replace view CALC.VIEW_PORTFOLIO_ALIS as
with
    ALL_CLIENTS as (
        select * from CALC.SWITCH_PORTFOLIO_DESIRED_CLIENTS_CURRENT
    ),
    -- Alle ALIS Konten
    ALIS_KONTEN as (
         select * from NLB.ALIS_KONTO
         union all
         select * from BLB.ALIS_KONTO
    ),
    -- Alle Kreditnehmer Infos
    KN_KNE as (
         select BRANCH as BRANCH_SYSTEM, BRANCH as BRANCH_CLIENT, KND_NR as CLIENT_NO, KREDITN_NR as NO from NLB.KN_KNE_CURRENT
         union all
         select BRANCH as BRANCH_SYSTEM, BRANCH as BRANCH_CLIENT, KND_NR as CLIENT_NO, KREDITN_NR as NO from BLB.KN_KNE_CURRENT
         union all
         select BRANCH as BRANCH_SYSTEM, 'NLB' as BRANCH_CLIENT, KND_NR as CLIENT_NO, KREDITN_NR as NO from ANL.KN_KNE_CURRENT
    ),
    -- KONTONUMMERN aus SPOT Stammdaten für alle gewünschten Kunden
    STAMM_SPOT as (
        select
            STAMM.CUTOFFDATE as CUT_OFF_DATE,
            'NLB' as BRANCH,
            STAMM.CLIENT_ID,
            CLIENT.CLIENT_IDS_NLB           as CLIENT_IDS_NLB,
            CLIENT.CLIENT_IDS_BLB           as CLIENT_IDS_BLB,
            CLIENT.CLIENT_IDS_CBB           as CLIENT_IDS_CBB,
            CLIENT.BORROWER_NO as BORROWER_NO,
            trim(L '0' from substr(STAMM.FACILITY_ID,11,10)) as SKTO
        from NLB.SPOT_STAMMDATEN_CURRENT as STAMM
        inner join ALL_CLIENTS           as CLIENT     on (CLIENT.CLIENT_NO, CLIENT.BRANCH_CLIENT,CLIENT.CUT_OFF_DATE) = (STAMM.CLIENT_ID, 'NLB',STAMM.CUTOFFDATE)
        union all
        select
            STAMM.CUTOFFDATE as CUT_OFF_DATE,
            'BLB' as BRANCH,
            STAMM.CLIENT_ID,
            CLIENT.CLIENT_IDS_NLB           as CLIENT_IDS_NLB,
            CLIENT.CLIENT_IDS_BLB           as CLIENT_IDS_BLB,
            CLIENT.CLIENT_IDS_CBB           as CLIENT_IDS_CBB,
            CLIENT.BORROWER_NO as BORROWER_NO,
            trim(L '0' from substr(STAMM.FACILITY_ID,11,10)) as SKTO
        from BLB.SPOT_STAMMDATEN_CURRENT as STAMM
        inner join ALL_CLIENTS     as CLIENT     on (CLIENT.CLIENT_NO, CLIENT.BRANCH_CLIENT,CLIENT.CUT_OFF_DATE) = (STAMM.CLIENT_ID, 'BLB',STAMM.CUTOFFDATE)
        union all
        select
            STAMM.CUTOFFDATE as CUT_OFF_DATE,
            'ANL' as BRANCH,
            STAMM.CLIENT_ID,
            CLIENT.CLIENT_IDS_NLB           as CLIENT_IDS_NLB,
            CLIENT.CLIENT_IDS_BLB           as CLIENT_IDS_BLB,
            CLIENT.CLIENT_IDS_CBB           as CLIENT_IDS_CBB,
            CLIENT.BORROWER_NO as BORROWER_NO,
            trim(L '0' from substr(STAMM.FACILITY_ID,11,10)) as SKTO
        from ANL.SPOT_STAMMDATEN_CURRENT as STAMM
        inner join ALL_CLIENTS     as CLIENT     on (CLIENT.CLIENT_NO, CLIENT.BRANCH_CLIENT,CLIENT.CUT_OFF_DATE) = (STAMM.CLIENT_ID, 'NLB',STAMM.CUTOFFDATE)
    ),
    -- KONTOAUFFÜLLUNGEN aus ALIS Stammdaten für alle gewünschten Kunden
    ALIS_RAHMEN as (
        select distinct
            ALIS.CUTOFFDATE                                                                                                                                        as CUT_OFF_DATE,
            ALIS.BRANCH                                                                                                                                            as BRANCH_SYSTEM,
            coalesce(STAMM.BRANCH,ALIS.BRANCH)                                                                                                                     as BRANCH_CLIENT,
            coalesce(STAMM.CLIENT_ID,case when ALIS.BRANCH = 'BLB' then DPK.CLIENT_NO_2 else BORROWER.CLIENT_NO end)                                          as CLIENT_NO,
            coalesce(STAMM.BRANCH || '_' || STAMM.CLIENT_ID, ALIS.branch || '_' ||  case when ALIS.branch = 'BLB' then DPK.CLIENT_NO_2 else BORROWER.CLIENT_NO end) as CLIENT_ID,
            STAMM.CLIENT_IDS_NLB                                                                                                                                   as CLIENT_IDS_NLB,
            STAMM.CLIENT_IDS_BLB                                                                                                                                   as CLIENT_IDS_BLB,
            STAMM.CLIENT_IDS_CBB                                                                                                                                   as CLIENT_IDS_CBB,
            ALIS.BRANCH                                                                                                                                            as BRANCH_FACILITY,
            case
                when ALIS.BRANCH = 'NLB' then
                    '0009-11-1' || lpad(CREDITLINEFACILITYID, 11, '0') || '-10-0000000000'
                when ALIS.BRANCH = 'BLB' then
                    '0004-11-1' || lpad(CREDITLINEFACILITYID, 11, '0') || '-10-0000000000'
            end                                                                                                                                                    as FACILITY_ID,
            COALESCE(BORROWER.NO,STAMM.BORROWER_NO) as BORROWER_NO,
            RAKISO as ORIGINAL_CURRENCY--,
            --min(EXTERNALLIMITVALIDFROMDATE) over (partition by ALIS.CREDITLINEFACILITYID) as ORIGINATION_DATE,
            --timestampdiff(64,TIMESTAMP(max(EXTERNALLIMITVALIDTODATE) over (partition by ALIS.CREDITLINEFACILITYID ))-TIMESTAMP(ALIS.CUTOFFDATE)) as MATURITY_IN_MONTHS
        from ALIS_KONTEN as ALIS
        inner join STAMM_SPOT                  as STAMM        on STAMM.SKTO=ALIS.SKTO and STAMM.CUT_OFF_DATE=ALIS.CUTOFFDATE
        left join KN_KNE                       as BORROWER     on (STAMM.BRANCH, STAMM.CLIENT_ID) = (BORROWER.BRANCH_CLIENT, BORROWER.CLIENT_NO)
--         left join NLB.ZO_KUNDE as ZO on ALIS.RAKKNR = ZO.BBK_KREDITNEHMER and ZO.CUTOFFDATE = (
--             -- da zo nicht immer direkt verfügbar ist und die ZO Daten sich auch nicht so schnell ändern diese ANpassung bis wir ZO Daten aus dem SPOT erhalten können.
--             select max(ZO.CUTOFFDATE) as CUTOFFDATE from NLB.ZO_KUNDE as ZO inner join ALIS_KONTEN as ALIS on ALIS.RAKKNR = ZO.BBK_KREDITNEHMER and ALIS.CUTOFFDATE >= ZO.CUTOFFDATE
--         )
        left join CALC.VIEW_GEKO_DOPPELKUNDEN  as DPK          on DPK.CLIENT_NO_1=BORROWER.CLIENT_NO and DPK.BRANCH_1 = 'NLB' and DPK.BRANCH_2 = 'BLB'
    ),
    ALIS_RAHMEN_UNIQUE as (
        select *, row_number() over (partition by FACILITY_ID, CUT_OFF_DATE order by CLIENT_ID desc) as NBR
        from ALIS_RAHMEN
    )
select
    DATE(CUT_OFF_DATE)                      as CUT_OFF_DATE,
    cast(BRANCH_SYSTEM as CHAR(3))          as BRANCH_SYSTEM,
    cast(BRANCH_CLIENT as CHAR(3))          as BRANCH_CLIENT,
    BIGINT(CLIENT_NO)                       as CLIENT_NO,
    cast(CLIENT_ID as VARCHAR(32))          as CLIENT_ID,
    cast(CLIENT_IDS_NLB as VARCHAR(32))     as CLIENT_IDS_NLB,
    cast(CLIENT_IDS_BLB as VARCHAR(32))     as CLIENT_IDS_BLB,
    cast(CLIENT_IDS_CBB as VARCHAR(32))     as CLIENT_IDS_CBB,
    cast(BORROWER_NO as BIGINT)             as BORROWER_NO,
    cast(BRANCH_FACILITY as CHAR(8))        as BRANCH_FACILITY,
    cast(FACILITY_ID as VARCHAR(64))        as FACILITY_ID,
    cast(ORIGINAL_CURRENCY as CHAR(3))      as CURRENCY,
    Current USER                            as CREATED_USER,     -- Letzter Nutzer, der diese Tabelle gebaut hat.
    Current TIMESTAMP                       as CREATED_TIMESTAMP -- Neuester Zeitstempel, wann diese Tabelle zuletzt gebaut wurde.
from ALIS_RAHMEN_UNIQUE where NBR = 1
;
------------------------------------------------------------------------------------------------------------------------

-- CI START FOR ALL TAPES

-- CURRENT TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_PORTFOLIO_ALIS_CURRENT');
create table AMC.TABLE_PORTFOLIO_ALIS_CURRENT like CALC.VIEW_PORTFOLIO_ALIS distribute by hash(FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_PORTFOLIO_ALIS_CURRENT_BRANCH_CLIENT on AMC.TABLE_PORTFOLIO_ALIS_CURRENT (BRANCH_CLIENT);
create index AMC.INDEX_PORTFOLIO_ALIS_CURRENT_CLIENT_NO     on AMC.TABLE_PORTFOLIO_ALIS_CURRENT (CLIENT_NO);
create index AMC.INDEX_PORTFOLIO_ALIS_CURRENT_FACILITY_ID   on AMC.TABLE_PORTFOLIO_ALIS_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_PORTFOLIO_ALIS_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_PORTFOLIO_ALIS_CURRENT');
------------------------------------------------------------------------------------------------------------------------

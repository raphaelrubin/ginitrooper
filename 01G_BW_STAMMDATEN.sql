
-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_BW_STAMMDATEN;
create or replace view CALC.VIEW_BW_STAMMDATEN as
with
    NLB_LENDING_LIABILITY as (
        select distinct IFRS.CUTOFFDATE, coalesce(BPART.ZM_EXTNR,IFRS.ZM_EXTNR) as ZM_IDNUM,ZM_PRODID as FACILITY_ID, ZM_PRKEY, IFRS.BRANCH as BRANCH_FACILITY, 'NLB' as BRANCH_SYSTEM, 'NLB' as BRANCH_CLIENT, ZM_AOCURR, ZM_ANVETA
        from NLB.BW_ZBC_IFRS_CURRENT    as IFRS
        left join IMAP.ZM_EXTNR_CURRENT as BPART    on BPART.ZM_BPKU = IFRS.ZM_BPKU and BPART.CUTOFFDATE=IFRS.CUTOFFDATE
        where 1=1
            and (left(CS_ITEM,1) in ('1','2') or substr(CS_ITEM, 1, 8) in ('96100005','96200005','96300005') )
            and left(ZM_KFSEM,1)<>'&' and ZM_RLSTD = 'I'
            and coalesce(ZM_STAKOR,'ALPAKA') <> 'F'
            and LEFT(ZM_PRODID,13) <> '0009-N001-DAR' -- Ausschluss von KSB Buchungen (#327)

            and SUBSTR(ZM_PRODID,6,2) <> '02'
    ),
    BLB_LENDING_LIABILITY as (
        select distinct IFRS.CUTOFFDATE, coalesce(BPART.ZM_EXTNR,IFRS.ZM_EXTNR) as ZM_IDNUM,ZM_PRODID as FACILITY_ID, ZM_PRKEY, IFRS.BRANCH as BRANCH_FACILITY, 'BLB' as BRANCH_SYSTEM, 'BLB' as BRANCH_CLIENT, ZM_AOCURR, ZM_ANVETA
        from BLB.BW_ZBC_IFRS_CURRENT    as IFRS
        left join IMAP.ZM_EXTNR_CURRENT as BPART    on BPART.ZM_BPKU = IFRS.ZM_BPKU and BPART.CUTOFFDATE=IFRS.CUTOFFDATE
        where 1=1
            and (left(CS_ITEM,1) in ('1','2') or substr(CS_ITEM, 1, 8) in ('96100005','96200005','96300005') )
            and left(ZM_KFSEM,1)<>'&' and ZM_RLSTD = 'I'
            and coalesce(ZM_STAKOR,'ALPAKA') <> 'F'
            and LEFT(ZM_PRODID,13) <> '0004-K001-DAR' -- Ausschluss von KSB Buchungen (#327)
            and LEFT(ZM_PRODID,3) <> 'FGB'
            and LEFT(ZM_PRODID,4) <> 'ISIN'
            and SUBSTR(ZM_PRODID,6,2) <> '02'
    ),
    ANL_LENDING_LIABILITY as (
        select distinct IFRS.CUTOFFDATE, coalesce(BPART.ZM_EXTNR,IFRS.ZM_EXTNR) as ZM_IDNUM, IFRS.ZM_PRODID as FACILITY_ID, IFRS.ZM_PRKEY, IFRS.BRANCH as BRANCH_FACILITY, 'ANL' as BRANCH_SYSTEM, 'NLB' as BRANCH_CLIENT, ZM_AOCURR, ZM_ANVETA
        from ANL.BW_ZBC_IFRS_CURRENT    as IFRS
        left join IMAP.ZM_EXTNR_CURRENT  as BPART    on BPART.ZM_BPKU = IFRS.ZM_BPKU and BPART.CUTOFFDATE=IFRS.CUTOFFDATE
        where 1=1
            and (left(CS_ITEM,1) in ('1','2') or substr(CS_ITEM, 1, 8) in ('96100005','96200005','96300005') )
            and left(ZM_KFSEM,1)<>'&' and ZM_RLSTD = 'I'
            and coalesce(ZM_STAKOR,'ALPAKA') <> 'F'
            and SUBSTR(ZM_PRODID,6,2) <> '02'
    ),
    NLB_KONZERN_EXT as (
        select distinct CUT_OFF_DATE,
                        ZM_KUNDE as ZM_IDNUM,
                        ZM_FORDID as FACILITY_ID,
                        NULL as ZM_PRKEY,
                        'NLB' as BRANCH_SYSTEM,
                        'NLB' as BRANCH_CLIENT,
                        BRANCH as BRANCH_FACILITY,
                        OBJ_CURR as ZM_AOCURR,
                        NULL as ZM_ANVETA
        from NLB.BW_P62_KONZERN_EXTERN_CURRENT
        where SUBSTR(ZM_FORDID,6,2) <> '02'
        and ZM_KUNDE <> 9999999999 -- Anonymisierte Kunden
    ),
    ANL_KONZERN_EXT as (
        select distinct CUT_OFF_DATE,
                        ZM_KUNDE as ZM_IDNUM,
                        ZM_FORDID as FACILITY_ID,
                        NULL as ZM_PRKEY,
                        'ANL' as BRANCH_SYSTEM,
                        'ANL' as BRANCH_CLIENT,
                        BRANCH as BRANCH_FACILITY,
                        OBJ_CURR as ZM_AOCURR,
                        NULL as ZM_ANVETA
        from ANL.BW_P62_KONZERN_EXTERN_CURRENT
        where SUBSTR(ZM_FORDID,6,2) <> '02'
        and ZM_KUNDE <> 9999999999 -- Anonymisierte Kunden
    ),
    CBB_KONZERN_EXT as (
        select distinct CUT_OFF_DATE,
                        ZM_KUNDE as ZM_IDNUM,
                        ZM_FORDID as FACILITY_ID,
                        NULL as ZM_PRKEY,
                        'CBB' as BRANCH_SYSTEM,
                        'CBB' as BRANCH_CLIENT,
                        BRANCH as BRANCH_FACILITY,
                        OBJ_CURR as ZM_AOCURR,
                        NULL as ZM_ANVETA
        from CBB.BW_P62_KONZERN_EXTERN_CURRENT
        where SUBSTR(ZM_FORDID,6,2) <> '02'
        and ZM_KUNDE <> 9999999999 -- Anonymisierte Kunden
    ),
    BW_STAMMDATEN_GROUPED as (
            select
                LENDING_LIABILITY.CUTOFFDATE, LENDING_LIABILITY.ZM_IDNUM, LENDING_LIABILITY.FACILITY_ID, LENDING_LIABILITY.ZM_PRKEY, LENDING_LIABILITY.BRANCH_SYSTEM, LENDING_LIABILITY.BRANCH_CLIENT, LENDING_LIABILITY.BRANCH_FACILITY, LENDING_LIABILITY.ZM_AOCURR,ZM_ANVETA as ZM_ANVETA
            from NLB_LENDING_LIABILITY as LENDING_LIABILITY
        union all
            select
                LENDING_LIABILITY.CUTOFFDATE, LENDING_LIABILITY.ZM_IDNUM, LENDING_LIABILITY.FACILITY_ID, LENDING_LIABILITY.ZM_PRKEY, LENDING_LIABILITY.BRANCH_SYSTEM, LENDING_LIABILITY.BRANCH_CLIENT, LENDING_LIABILITY.BRANCH_FACILITY, LENDING_LIABILITY.ZM_AOCURR,ZM_ANVETA as ZM_ANVETA
            from BLB_LENDING_LIABILITY as LENDING_LIABILITY
        union all
            select
                LENDING_LIABILITY.CUTOFFDATE, LENDING_LIABILITY.ZM_IDNUM, LENDING_LIABILITY.FACILITY_ID, LENDING_LIABILITY.ZM_PRKEY, LENDING_LIABILITY.BRANCH_SYSTEM, LENDING_LIABILITY.BRANCH_CLIENT, LENDING_LIABILITY.BRANCH_FACILITY, LENDING_LIABILITY.ZM_AOCURR,ZM_ANVETA as ZM_ANVETA
            from ANL_LENDING_LIABILITY as LENDING_LIABILITY
        --BW_P62_EXTERN_CURRENT
        union all
            select
                KONZERN_EXT.CUT_OFF_DATE as CUTOFFDATE, KONZERN_EXT.ZM_IDNUM, KONZERN_EXT.FACILITY_ID, KONZERN_EXT.ZM_PRKEY, KONZERN_EXT.BRANCH_SYSTEM, KONZERN_EXT.BRANCH_CLIENT, KONZERN_EXT.BRANCH_FACILITY, KONZERN_EXT.ZM_AOCURR, KONZERN_EXT.ZM_ANVETA
            from NLB_KONZERN_EXT as KONZERN_EXT
        union all
            select
                KONZERN_EXT.CUT_OFF_DATE as CUTOFFDATE, KONZERN_EXT.ZM_IDNUM, KONZERN_EXT.FACILITY_ID, KONZERN_EXT.ZM_PRKEY, KONZERN_EXT.BRANCH_SYSTEM, KONZERN_EXT.BRANCH_CLIENT, KONZERN_EXT.BRANCH_FACILITY, KONZERN_EXT.ZM_AOCURR, KONZERN_EXT.ZM_ANVETA
            from ANL_KONZERN_EXT as KONZERN_EXT
        union all
            select
                KONZERN_EXT.CUT_OFF_DATE as CUTOFFDATE, KONZERN_EXT.ZM_IDNUM, KONZERN_EXT.FACILITY_ID, KONZERN_EXT.ZM_PRKEY, KONZERN_EXT.BRANCH_SYSTEM, KONZERN_EXT.BRANCH_CLIENT, KONZERN_EXT.BRANCH_FACILITY, KONZERN_EXT.ZM_AOCURR, KONZERN_EXT.ZM_ANVETA
            from CBB_KONZERN_EXT as KONZERN_EXT
    ),MORE_THAN_ONE_CURR as (
        select FACILITY_ID,CUTOFFDATE from (
            select
              amc.*
              ,COUNT(*) over (partition by FACILITY_ID,CUTOFFDATE) AS nbr
            from BW_STAMMDATEN_GROUPED  AS amc
            ) AS amc
            where nbr>1
    ),
    BW_STAMMDATEN(CUT_OFF_DATE, BRANCH, BRANCH_SHORT,BRANCH_ACCOUNT,BRANCH_CLIENT, CLIENT_NO,CLIENT_ID_ORIG, FACILITY_ID, FACILITY_ID_CBB, PRODUCT_TYPE_DETAIL, PRODUCT_TYPE, CURRENCY, DAYS_OVERDUE) as (
        select distinct
                BW_STAMMDATEN.CUTOFFDATE
                ,BRANCH_FACILITY,BRANCH_SYSTEM,BRANCH_FACILITY,BRANCH_CLIENT
                ,BW_STAMMDATEN.ZM_IDNUM as CLIENT_NO
                ,BRANCH_CLIENT||'_'||BW_STAMMDATEN.ZM_IDNUM as CLIENT_ID_ORIG
                ,BW_STAMMDATEN.FACILITY_ID
                ,case when BRANCH_FACILITY = 'CBB' or BRANCH_SYSTEM = 'CBB' then BW_STAMMDATEN.FACILITY_ID
                    end as FACILITY_ID_CBB
                ,ZM_PRKEY as PRODUCT_TYPE_DETAIL
                ,ZM_PRKEY as PRODUCT_TYPE
                ,case when MTOC.FACILITY_ID is not null then NULL else ZM_AOCURR end as CURRENCY
                ,ZM_ANVETA as DAYS_OVERDUE
        from BW_STAMMDATEN_GROUPED  as BW_STAMMDATEN
        left join MORE_THAN_ONE_CURR as MTOC on MTOC.FACILITY_ID=BW_STAMMDATEN.FACILITY_ID and MTOC.CUTOFFDATE=BW_STAMMDATEN.CUTOFFDATE
        where 1 = 1
    )
select
    *,
    Current USER      as CREATED_USER,      -- Letzter Nutzer, der diese Tabelle gebaut hat.
    Current TIMESTAMP as CREATED_TIMESTAMP  -- Neuester Zeitstempel, wann diese Tabelle zuletzt gebaut wurde.
from BW_STAMMDATEN
;
------------------------------------------------------------------------------------------------------------------------

-- CI START FOR ALL TAPES

-- CURRENT TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_BW_STAMMDATEN_CURRENT');
create table AMC.TABLE_BW_STAMMDATEN_CURRENT like CALC.VIEW_BW_STAMMDATEN distribute by hash(FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_BW_STAMMDATEN_CURRENT on AMC.TABLE_BW_STAMMDATEN_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_BW_STAMMDATEN_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_BW_STAMMDATEN_CURRENT');
------------------------------------------------------------------------------------------------------------------------

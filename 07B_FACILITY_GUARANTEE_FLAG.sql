/*Liste aller Konten mit Garantie Flag*/

-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_GUARANTEE_FLAG;
create or replace view CALC.VIEW_GUARANTEE_FLAG as
with
    CURRENT_CUT_OFF_DATE as (
        select distinct CUT_OFF_DATE from NLB.SPOT_DERIVATE_CURRENT
    ),
    FACILITIES_CBB as (
        select distinct
            FAC.FACILITY_ID_CBB as FACILITY_ID,
            FLAG.CUTOFFDATE     as CUT_OFF_DATE,
            'IWHS_CBB'          as QUELLE
        from NLB.IWHS_GARANTIEFLAG_CURRENT      as FLAG
        left join CALC.VIEW_FACILITY_CBB_TO_NLB as FAC  on substring(FAC.FACILITY_ID_CBB,6,7) = RPAD(FACILITYID, 7, '_')
        where FLAG.INSTITUTE = 'CBB' and FACILITYID is not null
            union all
        select distinct
            FAC.FACILITY_ID_NLB as FACILITY_ID,
            FLAG.CUTOFFDATE     as CUT_OFF_DATE,
            'IWHS_CBB'          as QUELLE
        from NLB.IWHS_GARANTIEFLAG_CURRENT      as FLAG
        left join CALC.VIEW_FACILITY_CBB_TO_NLB as FAC  on substring(FAC.FACILITY_ID_CBB,6,7) = RPAD(FACILITYID, 7, '_')
        where FLAG.INSTITUTE = 'CBB' and FACILITYID is not null
                    union all
        select distinct
            'K028-'||FACILITYID||'_1020' as FACILITY_ID,
            FLAG.CUTOFFDATE     as CUT_OFF_DATE,
            'IWHS_CBB'          as QUELLE
        from NLB.IWHS_GARANTIEFLAG_CURRENT      as FLAG
        where FLAG.INSTITUTE = 'CBB' and FACILITYID is not null
                            union all
        select distinct
            'K028-'||FACILITYID||'_4200' as FACILITY_ID,
            FLAG.CUTOFFDATE     as CUT_OFF_DATE,
            'IWHS_CBB'          as QUELLE
        from NLB.IWHS_GARANTIEFLAG_CURRENT      as FLAG
        where FLAG.INSTITUTE = 'CBB' and FACILITYID is not null
    ),
    FACILITIES_DER as (
        select distinct
            FACILITY_ID     as FACILITY_ID,
            CUT_OFF_DATE    as CUT_OFF_DATE,
            'SPOT_DERIVATE' as QUELLE
        from NLB.SPOT_DERIVATE
    ),
    FACILITIES_ALIS as (
        select distinct
            STA.FACILITY_ID as FACILITY_ID,
            FLAG.CUTOFFDATE as CUT_OFF_DATE,
            'IWHS_ALIS'     as QUELLE
        from NLB.IWHS_GARANTIEFLAG_CURRENT  as FLAG
        left join NLB.ALIS_KONTO            as ALIS on ALIS.CREDITLINEFACILITYID = FLAG.FACILITYID
        join NLB.SPOT_STAMMDATEN            as STA  on ALIS.SKTO = substring(STA.FACILITY_ID,11,10)
        where length(FLAG.FACILITYID) = 5 and INSTITUTE = 'S009'
            union all
        select distinct
            STA.FACILITY_ID as FACILITY_ID,
            FLAG.CUTOFFDATE as CUT_OFF_DATE,
            'IWHS_ALIS'     as QUELLE
        from BLB.IWHS_GARANTIEFLAG_CURRENT  as FLAG
        left join BLB.ALIS_KONTO            as ALIS on ALIS.CREDITLINEFACILITYID = FLAG.FACILITYID
        join BLB.SPOT_STAMMDATEN            as STA  on ALIS.SKTO = substring(STA.FACILITY_ID,11,10)
        where length(FLAG.FACILITYID) = 5
                    union all
        select distinct
            '0004-11-1000000'||FACILITYID||'-10-0000000000' as FACILITY_ID,
            FLAG.CUTOFFDATE as CUT_OFF_DATE,
            'IWHS_ALIS'     as QUELLE
        from BLB.IWHS_GARANTIEFLAG_CURRENT  as FLAG
        where length(FLAG.FACILITYID) = 5
                            union all
        select distinct
            '0009-11-1000000'||FACILITYID||'-10-0000000000' as FACILITY_ID,
            FLAG.CUTOFFDATE as CUT_OFF_DATE,
            'IWHS_ALIS'     as QUELLE
        from NLB.IWHS_GARANTIEFLAG_CURRENT  as FLAG
        where length(FLAG.FACILITYID) = 5
    ),
    FACILITIES_NLB_BLB as (
        select distinct
            STA.FACILITY_ID as FACILITY_ID,
            FLAG.CUTOFFDATE as CUT_OFF_DATE,
            'IWHS_NLB'      as QUELLE
        from NLB.IWHS_GARANTIEFLAG_CURRENT  as FLAG
        left join NLB.SPOT_STAMMDATEN       as STA  on lpad(FLAG.FACILITYID,10,0) = substring(STA.FACILITY_ID,11,10)
        where length(FLAG.FACILITYID) in (9,10) and INSTITUTE = 'S009'
            union all
        select distinct
            STA.FACILITY_ID as FACILITY_ID,
            FLAG.CUTOFFDATE as CUT_OFF_DATE,
            'IWHS_ANL'      as QUELLE
        from NLB.IWHS_GARANTIEFLAG_CURRENT  as FLAG
        left join ANL.SPOT_STAMMDATEN       as STA  on lpad(FLAG.FACILITYID,10,0) = substring(STA.FACILITY_ID,11,10)
        where length(FLAG.FACILITYID) in (9,10) and INSTITUTE = 'S009'
        union all
        select distinct
            STA.FACILITY_ID as FACILITY_ID,
            FLAG.CUTOFFDATE as CUT_OFF_DATE,
            'IWHS_BLB'      as QUELLE
        from BLB.IWHS_GARANTIEFLAG_CURRENT  as FLAG
        left join BLB.SPOT_STAMMDATEN       as STA  on lpad(FLAG.FACILITYID,10,0) = substring(STA.FACILITY_ID,11,10)
        where length(FLAG.FACILITYID) in (9,10)
    ),
    FACILITIES_LIQ as (
        select
            coalesce(STA.FACILITY_ID,'0009-33-00' || PD.OUTSTANDING || '-31-0000000000')    as FACILITY_ID,
            FLAG.BESTANDSDATUM                                                              as CUT_OFF_DATE,
            'LIQ'                                                                           as QUELLE
        from NLB.LIQ_GESCHAEFTE         as FLAG
        left join NLB.SPOT_STAMMDATEN   as STA  on FLAG.ALIAS = substring(STA.FACILITY_ID,11,10)
        left join NLB.LIQ_PAST_DUE      as PD   on FLAG.ALIAS = PD.OUTSTANDING
        join CURRENT_CUT_OFF_DATE       as COD  on FLAG.BESTANDSDATUM = COD.CUT_OFF_DATE
        where FLAG.GUARANTEE_FLAG is not null
        union all
        select
            coalesce(STA.FACILITY_ID,'0009-33-00' || FLAG.FCN || '-21-0000000000')    as FACILITY_ID,
            FLAG.BESTANDSDATUM                                                              as CUT_OFF_DATE,
            'LIQ'                                                                           as QUELLE
        from NLB.LIQ_GESCHAEFTE         as FLAG
        left join NLB.SPOT_STAMMDATEN   as STA  on FLAG.FCN = substring(STA.FACILITY_ID,11,10)
        join CURRENT_CUT_OFF_DATE       as COD  on FLAG.BESTANDSDATUM = COD.CUT_OFF_DATE
        where FLAG.GUARANTEE_FLAG is not null
    ),
    FINAL_RESULT as (
        select * from FACILITIES_CBB
            union
        select * from FACILITIES_ALIS
            union
        select * from FACILITIES_DER
            union
        select * from FACILITIES_NLB_BLB
            union
        select * from FACILITIES_LIQ
    )
select
    FINAL.FACILITY_ID,                                       -- Konto ID
    FINAL.CUT_OFF_DATE,                                      -- Stichtag
    FINAL.QUELLE,                                            -- Woher kommen Konto und Flagging?
    Current USER                        as CREATED_USER,     -- Letzter Nutzer, der diese Tabelle gebaut hat.
    Current TIMESTAMP                   as CREATED_TIMESTAMP -- Neuester Zeitstempel, wann diese Tabelle zuletzt gebaut wurde.
from FINAL_RESULT as FINAL
;
grant select on CALC.VIEW_GUARANTEE_FLAG to group NLB_MW_ADAP_S_GNI_TROOPER;
------------------------------------------------------------------------------------------------------------------------

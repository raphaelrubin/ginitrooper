-- View erstellen
drop view CALC.VIEW_ASSET_REX;
create or replace view CALC.VIEW_ASSET_REX as
with
    -- Rex Stammnummer nach Asset ID (VO_ID) mappen & damit auch filtern
    REX_BASIS as (
	 SELECT C.VO_ID,C.VO_REX_NUMMER,B.*  FROM NLB.CMS_VO_CURRENT C
	 inner join NLB.REX_BASISDATEN_CURRENT B on (C.CUTOFFDATE,C.VO_REX_NUMMER) = (B.CUT_OFF_DATE,B.STAMMNUMMER)
    ),
    REX_BASIS_DUP as (
        select * from (
                      select *,
                             ROWNUMBER() over ( PARTITION BY STAMMNUMMER ORDER BY VERSION desc nulls last) as RN
                      from REX_BASIS where UPPER(STATUS) = 'GÜLTIG'
        ) where RN =1
    ),
    BASISDATEN_PRE as (
    select CUT_OFF_DATE,
           VO_ID,
           STAMMNUMMER,
           case when UPPER(BEARBEITER_MITARBEITERART) = 'INTERN' then 'intern'
                when UPPER(BEARBEITER_MITARBEITERART) = 'EXTERN' and GUTACHTERBUERO is null then 'extern'
                when UPPER(BEARBEITER_MITARBEITERART) = 'EXTERN' and GUTACHTERBUERO is not null then 'extern: ' || GUTACHTERBUERO
           end as APPRSR,
           case when UPPER(MAKROLAGE)='SEHR GUT' then true else false end as PRM_LCTN,
           GRAD_DER_FERTIGSTELLUNG
    from REX_BASIS_DUP
    ),
    BAUTEILE_SUM as (
    select BT.CUT_OFF_DATE,
           BT.STAMMNUMMER,
           Sum(NVL(BT.FLAECHE*BT.TATSAECHLICHE_MIETE_PA,BT.STUECK*BT.TATSAECHLICHE_MIETE_PA)) AS Sum_tatsaechliche_Miete_pa,
           Sum(BT.ROHERTRAG_PA) AS Sum_Rohertrag_pa,
           Sum(BT.REINERTRAG_PA) AS Sum_Reinertrag_pa,
           BT.WAEHRUNG
    from NLB.REX_BAUTEILE_CURRENT as BT where UPPER(STATUS) = 'GÜLTIG'
    group by BT.CUT_OFF_DATE, BT.STAMMNUMMER, BT.WAEHRUNG
    ),
    BAUTEILE_SUM_IN_EUR as (
    SELECT Bauteile_SUM.CUT_OFF_DATE,
           Bauteile_SUM.STAMMNUMMER,
           Bauteile_SUM.Sum_tatsaechliche_Miete_pa * CM.RATE_TARGET_TO_EUR AS CRE_YRLY_INCM,
           Bauteile_SUM.Sum_Rohertrag_pa * CM.RATE_TARGET_TO_EUR -
           Bauteile_SUM.Sum_Reinertrag_pa * CM.RATE_TARGET_TO_EUR          AS CRE_YRLY_EXPNSS,
           RC.Code  AS CRE_INCM_CRRNCY
    FROM (BAUTEILE_SUM INNER JOIN SMAP.REX_CURRENCY as RC
        ON Bauteile_SUM.WAEHRUNG = RC.WAEHRUNG_TXT)
    INNER JOIN IMAP.CURRENCY_MAP CM
        ON (BAUTEILE_SUM.CUT_OFF_DATE,RC.CODE) = (CM.CUT_OFF_DATE,CM.ZIEL_WHRG)
    ),
    DVLPMNT_STTS as (
    select BA.CUT_OFF_DATE,
           BA.STAMMNUMMER,
           GRAD_DER_FERTIGSTELLUNG,
           BS.Sum_tatsaechliche_Miete_pa,
           case when BA.GRAD_DER_FERTIGSTELLUNG = 100 then 4
                when BA.GRAD_DER_FERTIGSTELLUNG < 100 and BS.Sum_tatsaechliche_Miete_pa >0 then 3
                when BA.GRAD_DER_FERTIGSTELLUNG < 100 and BA.GRAD_DER_FERTIGSTELLUNG > 0 and
                     (BS.Sum_tatsaechliche_Miete_pa=0 or BS.Sum_tatsaechliche_Miete_pa is null) then 2
                when BA.GRAD_DER_FERTIGSTELLUNG is not null and BA.GRAD_DER_FERTIGSTELLUNG = 0 then 1
                else null
           end as DVLPMNT_STTS
    from BASISDATEN_PRE BA
    left join BAUTEILE_SUM BS
        on (BS.CUT_OFF_DATE, BS.STAMMNUMMER) = (BA.CUT_OFF_DATE,BA.STAMMNUMMER)
    ),
    REX_FINAL as (
    select BP.*,
           BTS.CRE_YRLY_INCM,
           BtS.CRE_INCM_CRRNCY,
           BTS.CRE_YRLY_EXPNSS,
           DS.Sum_tatsaechliche_Miete_pa,
           DS.DVLPMNT_STTS
           from BASISDATEN_PRE BP
           left join BAUTEILE_SUM_IN_EUR BTS on (BP.CUT_OFF_DATE,BP.STAMMNUMMER) = (BTS.CUT_OFF_DATE,BTS.STAMMNUMMER)
           left join DVLPMNT_STTS DS on (BP.CUT_OFF_DATE,BP.STAMMNUMMER) = (DS.CUT_OFF_DATE,DS.STAMMNUMMER)
    ),
    data as (
    select A.CUT_OFF_DATE,
           SMSC.SAPFDB_ID as ASSET_ID,
           A.ASSET_ID as CMS_ID_ORIG,
           STAMMNUMMER as VO_REX_NUMMER,
           RF.PRM_LCTN,
           RF.APPRSR,
           RF.CRE_YRLY_INCM,
           RF.CRE_YRLY_EXPNSS,
           RF.CRE_INCM_CRRNCY,
           RF.DVLPMNT_STTS
    from CALC.SWITCH_ASSET_CURRENT A
    inner join NLB.SPOT_LOANTAPE_PROTECTION_ASSET_CURRENT as SMSC
        on (A.CUT_OFF_DATE,A.ASSET_ID) = (SMSC.CUT_OFF_DATE,SMSC.CMS_ID)
    left join REX_FINAL as RF
        on (A.CUT_OFF_DATE, A.ASSET_ID) = (RF.CUT_OFF_DATE, RF.VO_ID)
    where A.SOURCE like '%CMS%'
    )
    select distinct *,
                    CURRENT_USER as USER,
                    CURRENT_TIMESTAMP as TIMESTAMP_LOAD
    from data;

-- CI START FOR ALL TAPES
-- Current-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_ASSET_REX_CURRENT');
create table AMC.TABLE_ASSET_REX_CURRENT like CALC.VIEW_ASSET_REX distribute by hash(ASSET_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_ASSET_REX_CURRENT_ASSET_ID on AMC.TABLE_ASSET_REX_CURRENT (ASSET_ID);
comment on table AMC.TABLE_ASSET_REX_CURRENT is 'Liste aller Assets, welche an einem der gewünschten Collaterals hängen (Aktueller Stichtag)';
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_ASSET_REX_CURRENT');
-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_ASSET_REX_CURRENT');
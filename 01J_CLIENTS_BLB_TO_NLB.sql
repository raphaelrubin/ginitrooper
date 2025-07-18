/* VIEW_CLIENTS_BLB_TO_NLB
 * Diese View führt Doppelkunden und Institutsfusion zusammen.
 */

-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_CLIENTS_BLB_TO_NLB;
create or replace view CALC.VIEW_CLIENTS_BLB_TO_NLB as
with CURRENT_CUTOFFDATE as (
        select CUT_OFF_DATE
        from CALC.AUTO_TABLE_CUTOFFDATES
        where IS_ACTIVE
     ),
     CLIENT_DUPLICATES as (
         select DUPLICATES.*,
                BRANCH_1 || '_' || CLIENT_NO_1 AS CLIENT_ID_1,
                BRANCH_2 || '_' || CLIENT_NO_2 AS CLIENT_ID_2
         from CALC.SWITCH_GEKO_DOPPELKUNDEN_CURRENT as DUPLICATES
                  inner join CURRENT_CUTOFFDATE as COD on COD.CUT_OFF_DATE = DUPLICATES.CUT_OFF_DATE
     ),
     CLIENT_INSTITUTSFUSION as (
         select *
         from SMAP.CLIENT_INSTITUTSFUSION
     ),
     ALL_CLIENTS_UNIQUE as (
         select *
         from CALC.SWITCH_PORTFOLIO_CLIENTS_BLB_TO_NLB_PRE_UNIQUE_CURRENT
     ),
     ALL_CLIENTS_NLB as (
         select BRANCH, CLIENT_NO, CLIENT_ID
         from ALL_CLIENTS_UNIQUE
         where BRANCH = 'NLB'
     ),
     MAPPED_CLIENTS_WITHOUT_NLB as (
         select SYSTEM.BRANCH,
                system.CLIENT_NO,
--                case
--                    when (DUPLICATES.BRANCH_1 = 'NLB' and DUPLICATES.BRANCH_2 <> 'NLB') then
--                        -- NLB Doppelkunde für einen BLB Doppelkunden
--                        DUPLICATES.CLIENT_ID_1
--                    when (DUPLICATES.BRANCH_2 = 'NLB' and DUPLICATES.BRANCH_1 <> 'NLB') then
--                        -- NLB Doppelkunde für einen BLB Doppelkunden
--                        DUPLICATES.CLIENT_ID_2
--                    when (DUPLICATES.BRANCH_1 = 'NLB' and DUPLICATES.BRANCH_2 = 'NLB' and DUPLICATES.CLIENT_NO_2 in (FUSION_NEU.CLIENT_NO_NEU, FUSION_ALT.CLIENT_NO_NEU, FUSION_DPK_OLD.CLIENT_NO_NEU)) then
--                        -- NLB Doppelkunde für einen NLB Doppelkunden und Kunde 2 ist ex BLB
--                        DUPLICATES.CLIENT_ID_1
--                    when (DUPLICATES.BRANCH_1 = 'NLB' and DUPLICATES.BRANCH_2 = 'NLB' and DUPLICATES.CLIENT_NO_1 in (FUSION_NEU.CLIENT_NO_NEU, FUSION_ALT.CLIENT_NO_NEU, FUSION_DPK_OLD.CLIENT_NO_NEU)) then
--                        -- NLB Doppelkunde für einen NLB Doppelkunden und Kunde 2 ist ex BLB
--                        DUPLICATES.CLIENT_ID_2
--                    when (DUPLICATES.BRANCH_1 = 'NLB' and DUPLICATES.BRANCH_2 = 'NLB') then
--                        -- NLB Doppelkunde für einen NLB Doppelkunden und kein Kunde ist ex BLB
--                        min(DUPLICATES.CLIENT_ID_1,DUPLICATES.CLIENT_ID_2)
--                    when (DUPLICATES.BRANCH_1 = 'NLB' and FUSION_NEU.CLIENT_NO_NEU is null) then
--                        -- NLB Doppelkunde und keine NLB Institutsfusionsnummer für die System ID
--                        DUPLICATES.CLIENT_ID_1
--                    when (DUPLICATES.BRANCH_1 = 'NLB' and FUSION_NEU.CLIENT_NO_NEU is not null) then
--                        -- NLB Doppelkunde und eine NLB Institutsfusionsnummer für die System ID
--                        DUPLICATES.CLIENT_ID_2
--                    else
--                        -- Sonst: NLB Nummer aus Institutsfusion, sonst System Nummer
--                        coalesce(FUSION_NEU.CLIENT_ID_NEU, FUSION_ALT.CLIENT_ID_NEU, SYSTEM.CLIENT_ID)
--                    end                                                                                    as CLIENT_ID_LEADING,
                coalesce(nullif('NLB_' || min(NLB_CLIENTS.CLIENT_NO), 'NLB_'), SYSTEM.CLIENT_ID)           as CLIENT_ID_LEADING,
                SYSTEM.CLIENT_ID                                                                           as CLIENT_ID,
                null                                                                                       as CLIENT_ID_NLB,
                case
                    when (DUPLICATES.BRANCH_1 = 'BLB') then
                        DUPLICATES.CLIENT_ID_1
                    when (DUPLICATES.BRANCH_2 = 'BLB') then
                        DUPLICATES.CLIENT_ID_2
                    else
                        coalesce(FUSION_ALT.CLIENT_ID_ALT, FUSION_NEU.CLIENT_ID_ALT, FUSION_DPK_NEW.CLIENT_ID_ALT)
                    end                                                                                    as CLIENT_ID_BLB,
                case when (DUPLICATES.BRANCH_1 = 'NLB') then DUPLICATES.CLIENT_ID_1 end                    as CLIENT_ID_DPK_1,
                case when (DUPLICATES.BRANCH_2 = 'NLB') then DUPLICATES.CLIENT_ID_2 end                    as CLIENT_ID_DPK_2,
                coalesce(FUSION_DPK_OLD.CLIENT_ID_NEU, FUSION_ALT.CLIENT_ID_NEU,
                         FUSION_NEU.CLIENT_ID_NEU)                                                         as CLIENT_ID_IF_NEW,
                SYSTEM.SOURCE,
                SYSTEM.PORTFOLIO_ORDER
         from ALL_CLIENTS_UNIQUE as SYSTEM
                  -- Institutsfusion Alte BLB an System ID ranspielen
                  left join CLIENT_INSTITUTSFUSION as FUSION_ALT
                            on (SYSTEM.CLIENT_NO, SYSTEM.BRANCH) = (FUSION_ALT.CLIENT_NO_ALT, FUSION_ALT.BRANCH_ALT)
             -- Institutsfusion Neue NLB an System ID ranspielen
                  left join CLIENT_INSTITUTSFUSION as FUSION_NEU
                            on (SYSTEM.CLIENT_NO, SYSTEM.BRANCH) = (FUSION_NEU.CLIENT_NO_NEU, FUSION_NEU.BRANCH_NEU)
             -- Duplikat an System ID ranspielen
                  left join CLIENT_DUPLICATES as DUPLICATES
                            on (SYSTEM.CLIENT_NO, SYSTEM.BRANCH) = (DUPLICATES.CLIENT_NO_1, DUPLICATES.BRANCH_1)
                                -- Duplikat an Institutsfusion ranspielen
                                or (FUSION_NEU.CLIENT_NO_ALT, FUSION_NEU.BRANCH_ALT) =
                                   (DUPLICATES.CLIENT_NO_1, DUPLICATES.BRANCH_1)
                  left join CLIENT_INSTITUTSFUSION as FUSION_DPK_OLD on (DUPLICATES.CLIENT_NO_2, DUPLICATES.BRANCH_2) =
                                                                        (FUSION_DPK_OLD.CLIENT_NO_ALT, FUSION_DPK_OLD.BRANCH_ALT)
                  left join CLIENT_INSTITUTSFUSION as FUSION_DPK_NEW on (DUPLICATES.CLIENT_NO_2, DUPLICATES.BRANCH_2) =
                                                                        (FUSION_DPK_NEW.CLIENT_NO_NEU, FUSION_DPK_NEW.BRANCH_NEU)
                  left join ALL_CLIENTS_NLB as NLB_CLIENTS on SYSTEM.CLIENT_ID = NLB_CLIENTS.CLIENT_ID
                                                           or FUSION_ALT.CLIENT_ID_NEU = NLB_CLIENTS.CLIENT_ID
                                                           or FUSION_NEU.CLIENT_ID_NEU = NLB_CLIENTS.CLIENT_ID
                                                           or DUPLICATES.CLIENT_ID_1 = NLB_CLIENTS.CLIENT_ID
                                                           or DUPLICATES.CLIENT_ID_2 = NLB_CLIENTS.CLIENT_ID
                                                           or FUSION_DPK_OLD.CLIENT_ID_NEU = NLB_CLIENTS.CLIENT_ID
                                                           or FUSION_DPK_NEW.CLIENT_ID_NEU = NLB_CLIENTS.CLIENT_ID
         group by SYSTEM.BRANCH, SYSTEM.CLIENT_NO, SYSTEM.CLIENT_ID,
                  DUPLICATES.CLIENT_ID_1, DUPLICATES.CLIENT_ID_2, DUPLICATES.BRANCH_1, DUPLICATES.BRANCH_2,
                  DUPLICATES.CLIENT_ID_1, DUPLICATES.CLIENT_ID_2,
                  FUSION_ALT.CLIENT_ID_ALT, FUSION_ALT.CLIENT_ID_NEU, FUSION_NEU.CLIENT_ID_ALT,
                  FUSION_NEU.CLIENT_ID_NEU,
                  FUSION_DPK_NEW.CLIENT_ID_ALT, FUSION_DPK_OLD.CLIENT_ID_NEU,
                  SYSTEM.SOURCE, SYSTEM.PORTFOLIO_ORDER
     ),
     MAPPED_CLIENTS as (
         select CUT_OFF_DATE,
                CLIENT_ID_LEADING,
                BRANCH,
                CLIENT_NO,
                CLIENT_ID,
                case
                    when not (coalesce(CLIENT_ID_IF_NEW, CLIENT_ID_LEADING) = CLIENT_ID_LEADING) then
                        CLIENT_ID_IF_NEW
                    when not (coalesce(CLIENT_ID_DPK_1, CLIENT_ID_LEADING) = CLIENT_ID_LEADING) then
                        CLIENT_ID_DPK_1
                    when not (coalesce(CLIENT_ID_DPK_2, CLIENT_ID_LEADING) = CLIENT_ID_LEADING) then
                        CLIENT_ID_DPK_2
                    else
                        CLIENT_ID_LEADING
                    end as CLIENT_ID_NLB,
                CLIENT_ID_BLB,
                SOURCE,
                PORTFOLIO_ORDER
         from MAPPED_CLIENTS_WITHOUT_NLB
                  cross join CURRENT_CUTOFFDATE as COD
     )
select *
from MAPPED_CLIENTS;
;
grant select on CALC.VIEW_CLIENTS_BLB_TO_NLB to NLB_MW_ADAP_S_GNI_TROOPER;

-- CI START FOR ALL TAPES
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_CLIENTS_BLB_TO_NLB_CURRENT');
create table AMC.TABLE_CLIENTS_BLB_TO_NLB_CURRENT like CALC.VIEW_CLIENTS_BLB_TO_NLB distribute by hash (CLIENT_NO, BRANCH) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CLIENTS_BLB_TO_NLB_CURRENT_SV_ID_GW_KONTO on AMC.TABLE_CLIENTS_BLB_TO_NLB_CURRENT (CLIENT_NO, BRANCH);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_CLIENTS_BLB_TO_NLB_CURRENT');
-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_CLIENTS_BLB_TO_NLB_CURRENT');
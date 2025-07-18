/* VIEW_PORTFOLIO_CLIENTS_BLB_TO_NLB_PRE_UNIQUE
 * Diese View sorgt für einigartige Kunden für die Institutsfusion.
 */

-- VIEW erstellen
------------------------------------------------------------------------

drop view CALC.VIEW_PORTFOLIO_CLIENTS_BLB_TO_NLB_PRE_UNIQUE;
create or replace view CALC.VIEW_PORTFOLIO_CLIENTS_BLB_TO_NLB_PRE_UNIQUE as with
    CURRENT_CUTOFFDATE as (
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
     ALL_CLIENTS as (
             select BRANCH_1       as BRANCH,
                    CLIENT_NO_1    as CLIENT_NO,
                    CLIENT_ID_1    as CLIENT_ID,
                    'Doppelkunden' as SOURCE,
                    1              as PORTFOLIO_ORDER
         from CLIENT_DUPLICATES
         union all
         select BRANCH_ALT         as BRANCH,
                CLIENT_NO_ALT      as CLIENT_NO,
                CLIENT_ID_ALT      as CLIENT_ID,
                'Institutsfusion'  as SOURCE,
                2                  as PORTFOLIO_ORDER
         from CLIENT_INSTITUTSFUSION
         union all
         select BRANCH_NEU        as BRANCH,
                CLIENT_NO_NEU     AS CLIENT_NO,
                CLIENT_ID_NEU     AS CLIENT_ID,
                'Institutsfusion' as SOURCE,
                2                 as PORTFOLIO_ORDER
         from CLIENT_INSTITUTSFUSION
     ),
     ALL_CLIENTS_UNIQUE as (
         select distinct *
         from ALL_CLIENTS
     )
select COD.CUT_OFF_DATE,
       ACU.BRANCH,
       CLIENT_NO,
       CLIENT_ID,
       nullif(SOURCE,NULL) as SOURCE,
       nullif(PORTFOLIO_ORDER,NULL) as PORTFOLIO_ORDER
from ALL_CLIENTS_UNIQUE as ACU
left join CURRENT_CUTOFFDATE as COD on 1=1
;

grant select on CALC.VIEW_PORTFOLIO_CLIENTS_BLB_TO_NLB_PRE_UNIQUE to NLB_MW_ADAP_S_GNI_TROOPER;

-- CI START FOR ALL TAPES
call STG.TEST_PROC_BACKUP_AND_DROP('AMC', 'TABLE_PORTFOLIO_CLIENTS_BLB_TO_NLB_PRE_UNIQUE_CURRENT');
create table AMC.TABLE_PORTFOLIO_CLIENTS_BLB_TO_NLB_PRE_UNIQUE_CURRENT like CALC.VIEW_PORTFOLIO_CLIENTS_BLB_TO_NLB_PRE_UNIQUE distribute by hash (CLIENT_NO, BRANCH) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_PORTFOLIO_CLIENTS_BLB_TO_NLB_PRE_UNIQUE_CURRENT on AMC.TABLE_PORTFOLIO_CLIENTS_BLB_TO_NLB_PRE_UNIQUE_CURRENT (CLIENT_NO, BRANCH);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC', 'TABLE_PORTFOLIO_CLIENTS_BLB_TO_NLB_PRE_UNIQUE_CURRENT');
-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC', 'TABLE_PORTFOLIO_CLIENTS_BLB_TO_NLB_PRE_UNIQUE_CURRENT');
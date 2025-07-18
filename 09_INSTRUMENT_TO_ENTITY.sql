------------------------
-- ENTITIES / CLIENTS --
------------------------
-- Modellierung für EZB-Dictionary

drop view CALC.VIEW_PORTFOLIO_INSTRUMENT_TO_ENTITY;
create or replace view CALC.VIEW_PORTFOLIO_INSTRUMENT_TO_ENTITY as
with JNT_LBLTS_PRE as (
    select JNT_LBLTS.CUT_OFF_DATE,
           JNT_LBLTS.PARTNER_ID,
           NVL(POS.POSITION_ID, JNT_LBLTS.IDN202) as INSTRMNT_ID,
           CRI120
    from NLB.ABACUS_DM_AC_JNT_LBLTS_CURRENT as JNT_LBLTS
    inner join NLB.ABACUS_POSITION_CURRENT as POS
        on (POS.CUT_OFF_DATE,POS.IDN202) = (JNT_LBLTS.CUT_OFF_DATE,JNT_LBLTS.IDN202)
),
MAX_JNT_LBLTS_PRE as (
    select CUT_OFF_DATE,
           INSTRMNT_ID,
           max(CRI120) as JNT_LBLTS_AMOUNT
    from JNT_LBLTS_PRE
    group by CUT_OFF_DATE, INSTRMNT_ID
),
data as (
    select
        P.CUT_OFF_DATE as CUT_OFF_DATE, --DT_RFRNC,
        CLIENT_NO as CLIENT_NO, --ENTTY_ID,
        CLIENT_ID_ORIG as CLIENT_ID,
        FACILITY_ID as FACILITY_ID, --INSTRMNT_ID,
        JNT_LBLTS_AMOUNT as JOINT_LIABILITY_AMOUNT, --JNT_LBLTY_AMNT,
        null as ADD_NMRC1,
        null as ADD_NMRC2,
        null as ADD_DT1,
        null as ADD_TXT1,
        null as ADD_TXT2
    from CALC.SWITCH_PORTFOLIO_CURRENT as P
    left join MAX_JNT_LBLTS_PRE as JL
        on (P.CUT_OFF_DATE, P.FACILITY_ID) = (JL.CUT_OFF_DATE,JL.INSTRMNT_ID)
)
select distinct
    cast(CUT_OFF_DATE as DATE) as CUT_OFF_DATE, --DT_RFRNC,
    cast(CLIENT_NO as BIGINT) as CLIENT_NO, --ENTTY_ID,
    cast(CLIENT_ID as VARCHAR(32)) as CLIENT_ID,
    cast(FACILITY_ID as VARCHAR(60)) as FACILITY_ID, --INSTRMNT_ID,
    nullif(cast(JOINT_LIABILITY_AMOUNT as DECFLOAT),null) as JOINT_LIABILITY_AMOUNT, --JNT_LBLTY_AMNT,
    nullif(cast(ADD_NMRC1 as FLOAT),null) as ADD_NMRC1,
    nullif(cast(ADD_NMRC2 as FLOAT),null) as ADD_NMRC2,
    nullif(cast(ADD_DT1 as DATE),null) as ADD_DT1,
    nullif(cast(ADD_TXT1 as VARCHAR(255)),null) as ADD_TXT1,
    nullif(cast(ADD_TXT2 as VARCHAR(255)),null) as ADD_TXT2,
    USER as CREATED_USER,
    CURRENT_TIMESTAMP as CREATED_TIMESTAMP
from data
;
------------------------------------------------------------------------------------------------------------------------

-- CI START FOR ALL TAPES

-- Current-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_PORTFOLIO_INSTRUMENT_TO_ENTITY_CURRENT');
create table AMC.TABLE_PORTFOLIO_INSTRUMENT_TO_ENTITY_CURRENT like CALC.VIEW_PORTFOLIO_INSTRUMENT_TO_ENTITY distribute by hash(CLIENT_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_PORTFOLIO_INSTRUMENT_TO_ENTITY_CURRENT_CLIENT_ID on AMC.TABLE_PORTFOLIO_INSTRUMENT_TO_ENTITY_CURRENT (CLIENT_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_PORTFOLIO_INSTRUMENT_TO_ENTITY_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- Archiv-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_PORTFOLIO_INSTRUMENT_TO_ENTITY_ARCHIVE');
create table AMC.TABLE_PORTFOLIO_INSTRUMENT_TO_ENTITY_ARCHIVE like CALC.VIEW_PORTFOLIO_INSTRUMENT_TO_ENTITY distribute by hash(CLIENT_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_PORTFOLIO_INSTRUMENT_TO_ENTITY_ARCHIVE_CLIENT_ID on AMC.TABLE_PORTFOLIO_INSTRUMENT_TO_ENTITY_ARCHIVE (CLIENT_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_PORTFOLIO_INSTRUMENT_TO_ENTITY_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCHES erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_PORTFOLIO_INSTRUMENT_TO_ENTITY_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_PORTFOLIO_INSTRUMENT_TO_ENTITY_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------
-- INSTRUMENT_TO_ENTITY TAPE EZB DICTIONARY --
--------------------------------------------------
-- CI START FOR ALL TAPES
-- Drop View
drop view AMC.TAPE_PORTFOLIO_INSTRUMENT_TO_ENTITY_EZB;
-- View erstellen
create or replace view AMC.TAPE_PORTFOLIO_INSTRUMENT_TO_ENTITY_EZB as
select distinct
    cast(CUT_OFF_DATE as DATE) as DT_RFRNC,
    cast(CLIENT_ID as VARCHAR(255)) as ENTTY_ID,
    cast(FACILITY_ID as VARCHAR(60)) as INSTRMNT_ID,
    stg.NUMBER2STRECB(JOINT_LIABILITY_AMOUNT) as JNT_LBLTY_AMNT,
    cast(ADD_NMRC1 as FLOAT) as ADD_NMRC1,
    cast(ADD_NMRC2 as FLOAT) as ADD_NMRC2,
    varchar_format(ADD_DT1, 'YYYY-MM-DD') as ADD_DT1,
    cast(ADD_TXT1 as VARCHAR(255)) as ADD_TXT1,
    cast(ADD_TXT2 as VARCHAR(255)) as ADD_TXT2
from AMC.TABLE_PORTFOLIO_INSTRUMENT_TO_ENTITY_CURRENT as TAPE
;

call stg.TEST_PROC_GRANT_PERMISSION_TO('AMC','TAPE_PORTFOLIO_INSTRUMENT_TO_ENTITY_EZB');
-- CI END FOR ALL TAPES
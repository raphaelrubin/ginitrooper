------------------------------------------------------------------------------------------------------------------------
/* VIEW_GEKO_DOPPELKUNDEN
 *
 * In TABLE_GEKO_DOPPELKUNDEN befindet sich eine Liste mit allen vom GeKo markierten Doppelkunden.
 */
------------------------------------------------------------------------------------------------------------------------

-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_GEKO_DOPPELKUNDEN;
create or replace view CALC.VIEW_GEKO_DOPPELKUNDEN as (
    select distinct BRANCH_1, CLIENT_NO_1, BRANCH_2, CLIENT_NO_2, CUTOFFDATE AS CUT_OFF_DATE from (
        select BRANCH as BRANCH_1, CLIENT_NO as CLIENT_NO_1, BRANCH_ALT as  BRANCH_2, CLIENT_NO_ALT as CLIENT_NO_2, CUTOFFDATE from IMAP.DPK_MERGED
            union
        select BRANCH_A as BRANCH_1,CLIENT_NO_A as CLIENT_NO_1,BRANCH_B as  BRANCH_2,CLIENT_NO_B as CLIENT_NO_2, CUTOFFDATE from NLB.DOPPELKUNDEN_CURRENT
            union
        select BRANCH_B as BRANCH_1,CLIENT_NO_B as CLIENT_NO_1,BRANCH_A as  BRANCH_2,CLIENT_NO_A as CLIENT_NO_2, CUTOFFDATE from NLB.DOPPELKUNDEN_CURRENT
            union
        select BRANCH_A as BRANCH_1,CLIENT_NO_A as CLIENT_NO_1,BRANCH_B as  BRANCH_2,CLIENT_NO_B as CLIENT_NO_2, CUTOFFDATE from BLB.DOPPELKUNDEN_CURRENT
            union
        select BRANCH_B as BRANCH_1,CLIENT_NO_B as CLIENT_NO_1,BRANCH_A as  BRANCH_2,CLIENT_NO_A as CLIENT_NO_2, CUTOFFDATE from BLB.DOPPELKUNDEN_CURRENT
            union
        select 'NLB',80120369,'BLB',7051523, CUTOFFDATE from SYSIBM.SYSDUMMY1 cross join NLB.DOPPELKUNDEN_CURRENT  -- Bremer Kunde ist falsch angelegter Gemeinschaftskunde an dem noch ein GIRO (Schiffsdarlehen) hängt, daher korrekterweise noch nicht im GeKo. Deshalb hier manuell eingefügt.
            union
        select 'BLB',7051523,'NLB',80120369, CUTOFFDATE from SYSIBM.SYSDUMMY1 cross join NLB.DOPPELKUNDEN_CURRENT
    )
 )
;
------------------------------------------------------------------------------------------------------------------------

-- CI START FOR ALL TAPES

-- CURRENT TABLE erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_GEKO_DOPPELKUNDEN_CURRENT');
create table AMC.TABLE_GEKO_DOPPELKUNDEN_CURRENT like CALC.VIEW_GEKO_DOPPELKUNDEN distribute by hash(CLIENT_NO_1) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_GEKO_DOPPELKUNDEN_CURRENT_CLIENT_NO_1 on AMC.TABLE_GEKO_DOPPELKUNDEN_CURRENT (CLIENT_NO_1);
create index AMC.INDEX_GEKO_DOPPELKUNDEN_CURRENT_CLIENT_NO_2 on AMC.TABLE_GEKO_DOPPELKUNDEN_CURRENT (CLIENT_NO_2);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_GEKO_DOPPELKUNDEN_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCH erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_GEKO_DOPPELKUNDEN_CURRENT');
------------------------------------------------------------------------------------------------------------------------
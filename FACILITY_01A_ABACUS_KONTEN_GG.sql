drop view CALC.VIEW_FACILITY_ABACUS_KONTEN_GG;
create or replace view CALC.VIEW_FACILITY_ABACUS_KONTEN_GG as
with FACILITY_SAP as (
         select CUT_OFF_DATE,
                case
                    when coalesce(GESCHAEFTSPARTNER_NO, '') = '' then null
                    else case
                             when
                                 translate(GESCHAEFTSPARTNER_NO, '', '0123456789') = ''
                                 then GESCHAEFTSPARTNER_NO end
                    end as SAP_KUNDE,
                    -- Abweichungen Kundennummer ca. 73 Stueck Portfolio und BW_EXT
                    LTRIM(CLIENT_NO,'0') as CLIENT_NO,
                FACILITY_ID
         from CALC.SWITCH_FACILITY_BW_P80_EXTERNAL_CURRENT
     ),
     ABACUS_SAP_KUNDE as (
         select CUT_OFF_DATE,
                POSITION_ID,
                case
                    when coalesce(PARTNER_ID30, '') = '' then null
                    else case
                             when
                                 translate(PARTNER_ID30, '', '0123456789') = ''
                                 then PARTNER_ID30 end
                    end as SAP_KUNDE,
                QUELLE
         FROM NLB.ABACUS_POSITION_CURRENT AP
         where POSITION_ID not like '0009-10-%-10-%'
           and POSITION_ID is not null
     ),
ABACUS_KONTEN_GG as (
         select distinct CUT_OFF_DATE,POSITION_ID as FACILITY_ID, SAP_KUNDE, CLIENT_NO from (
             select ASK.CUT_OFF_DATE, ASK.POSITION_ID, ASK.SAP_KUNDE, PS.CLIENT_NO
             from ABACUS_SAP_KUNDE ASK
             inner join FACILITY_SAP PS on (PS.CUT_OFF_DATE, PS.SAP_KUNDE) = (ASK.CUT_OFF_DATE, ASK.SAP_KUNDE)
             union all
             select ASK.CUT_OFF_DATE, ASK.POSITION_ID, ASK.SAP_KUNDE, PS.CLIENT_NO
             from FACILITY_SAP PS
             inner join ABACUS_SAP_KUNDE ASK on (PS.CUT_OFF_DATE, PS.FACILITY_ID) = (ASK.CUT_OFF_DATE, ASK.POSITION_ID)
         )
)
select *,
       CURRENT_USER as USER,
       CURRENT_TIMESTAMP as TIMESTAMP_LOAD
from ABACUS_KONTEN_GG;

-- CI START FOR ALL TAPES

-- Current-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_FACILITY_ABACUS_KONTEN_GG_CURRENT');
create table AMC.TABLE_FACILITY_ABACUS_KONTEN_GG_CURRENT like CALC.VIEW_FACILITY_ABACUS_KONTEN_GG distribute by hash(FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_FACILITY_ABACUS_KONTEN_GG_CURRENT_FACILITY_ID on AMC.TABLE_FACILITY_ABACUS_KONTEN_GG_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_FACILITY_ABACUS_KONTEN_GG_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCHES erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_FACILITY_ABACUS_KONTEN_GG_CURRENT');
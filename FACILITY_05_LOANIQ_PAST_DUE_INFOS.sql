-- View erstellen
drop view CALC.VIEW_LOANIQ_PAST_DUE_INFOS;
create or replace view CALC.VIEW_LOANIQ_PAST_DUE_INFOS as
with
    LOANIQ_PAST_DUE as (
        select distinct * from NLB.LIQ_PAST_DUE
    ),
    TILGUNG as (
        select distinct
            OUTSTANDING,'0009-33-00' || OUTSTANDING || '-31-0000000000'                                         as FACILITY_ID,
            SUM(coalesce(PAST_DUE_SUM,0))over (partition by OUTSTANDING,CUTOFFDATE)                             as PAST_DUE_AMOUNT,
            first_value(PRICING_OPTION) over (partition by OUTSTANDING, CUTOFFDATE order by PAST_DUE_DUE desc nulls last)   as PRICING_OPTION,
            first_value(PD_ALL_IN_RATE) over (partition by OUTSTANDING, CUTOFFDATE order by PAST_DUE_DUE desc nulls last)   as PAST_DUE_ALL_IN_RATE,
            MIN(PAST_DUE_DUE) over (partition by OUTSTANDING,CUTOFFDATE)                                        as PAST_DUE_SINCE,
            CUTOFFDATE
        from LOANIQ_PAST_DUE
        where coalesce(PAST_DUE_SUM,0) > 0 and TYPE = 'PPYMT'
    ),
    ZINSEN as (
        select distinct
            OUTSTANDING,'0009-33-00' || OUTSTANDING || '-31-0000000000'                                         as FACILITY_ID,
            SUM(coalesce(PAST_DUE_SUM,0)) over (partition by OUTSTANDING,CUTOFFDATE)                            as PAST_DUE_AMOUNT,
            first_value(PRICING_OPTION) over (partition by OUTSTANDING, CUTOFFDATE order by PAST_DUE_DUE desc nulls last)   as PRICING_OPTION,
            first_value(PD_ALL_IN_RATE) over (partition by OUTSTANDING, CUTOFFDATE order by PAST_DUE_DUE desc nulls last)   as PAST_DUE_ALL_IN_RATE,
            MIN(PAST_DUE_DUE) over (partition by OUTSTANDING,CUTOFFDATE)                                        as PAST_DUE_SINCE,
            CUTOFFDATE
        from LOANIQ_PAST_DUE
        where coalesce(PAST_DUE_SUM,0) > 0 and TYPE = 'INTPY'
    )
select distinct
    '0009-33-00' || PAST_DUE.OUTSTANDING || '-31-0000000000' as FACILITY_ID,
    GLOBAL_CURRENT,
    GLOBAL_ORIGINAL,
    NETTO_ANTEIL,
    CURRENCY,
    HOST_BANK_GROSS,
    HOST_BANK_NET,
    TILGUNG.PAST_DUE_SINCE                                   as PAST_DUE_AMORTIZATION_SINCE,
    TILGUNG.PAST_DUE_AMOUNT                                  as PAST_DUE_AMORTIZATION_AMOUNT,
    TILGUNG.PAST_DUE_ALL_IN_RATE                             as PAST_DUE_AMORTIZATION_ALL_IN_RATE,
    TILGUNG.PRICING_OPTION                                   as PAST_DUE_AMORTIZATION_PRICING_OPTION,
    ZINSEN.PAST_DUE_SINCE           as PAST_DUE_INTEREST_SINCE,
    ZINSEN.PAST_DUE_AMOUNT          as PAST_DUE_INTEREST_AMOUNT,
    ZINSEN.PAST_DUE_ALL_IN_RATE                              as PAST_DUE_INTEREST_ALL_IN_RATE,
    ZINSEN.PRICING_OPTION                                    as PAST_DUE_INTEREST_PRICING_OPTION,
    case
        when (GLOBAL_CURRENT = 0 and TILGUNG.PAST_DUE_AMOUNT  <> 0 ) or GLOBAL_CURRENT=TILGUNG.PAST_DUE_AMOUNT  then TILGUNG.PAST_DUE_ALL_IN_RATE
        else NULL
    end                                                      as FULL_PAST_DUE_ALL_IN_RATE,
    case
        when (GLOBAL_CURRENT = 0 and TILGUNG.PAST_DUE_AMOUNT  <> 0 ) or GLOBAL_CURRENT=TILGUNG.PAST_DUE_AMOUNT  then TILGUNG.PRICING_OPTION
        else NULL
    end                                                      as FULL_PAST_DUE_PRICING_OPTION,
    PAST_DUE.CUTOFFDATE,
    Current_USER                                             as CREATED_USER,      -- Letzter Nutzer, der diese Tabelle gebaut hat.
    Current_TIMESTAMP                                        as CREATED_TIMESTAMP  -- Neuester Zeitstempel, wann diese Tabelle zuletzt gebaut wurde.
from LOANIQ_PAST_DUE   as PAST_DUE
left join TILGUNG       as TILGUNG  on TILGUNG.OUTSTANDING=PAST_DUE.OUTSTANDING and PAST_DUE.CUTOFFDATE=TILGUNG.CUTOFFDATE
left join ZINSEN        as ZINSEN   on ZINSEN.OUTSTANDING=PAST_DUE.OUTSTANDING and PAST_DUE.CUTOFFDATE=ZINSEN.CUTOFFDATE
;

-- CI START FOR ALL TAPES
-- Current-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_LOANIQ_PAST_DUE_INFOS_CURRENT');
create table AMC.TABLE_LOANIQ_PAST_DUE_INFOS_CURRENT like CALC.VIEW_LOANIQ_PAST_DUE_INFOS distribute by hash(FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_LOANIQ_PAST_DUE_INFOS_CURRENT_FACILITY_ID on AMC.TABLE_LOANIQ_PAST_DUE_INFOS_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_LOANIQ_PAST_DUE_INFOS_CURRENT');
-- Archiv-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_LOANIQ_PAST_DUE_INFOS_ARCHIVE');
create table AMC.TABLE_LOANIQ_PAST_DUE_INFOS_ARCHIVE like AMC.TABLE_LOANIQ_PAST_DUE_INFOS_CURRENT distribute by hash(FACILITY_ID) partition by RANGE (CUTOFFDATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_LOANIQ_PAST_DUE_INFOS_ARCHIVE_FACILITY_ID on AMC.TABLE_LOANIQ_PAST_DUE_INFOS_ARCHIVE (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_LOANIQ_PAST_DUE_INFOS_ARCHIVE');
-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_LOANIQ_PAST_DUE_INFOS_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_LOANIQ_PAST_DUE_INFOS_ARCHIVE');


------------------------------------------------------------------------------------------------------------------------
--Historie zu Vorgänger/Nachfolger Konten und gitlab issue #439 gelöscht. Zu finden als txt im Filesystem unter Sonstige_Themen->Migration_Repo_Aufräumen

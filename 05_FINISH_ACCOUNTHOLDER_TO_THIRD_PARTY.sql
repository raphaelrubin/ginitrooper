----------------------------------------
-- CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY --
----------------------------------------
-- CI START FOR ALL TAPES
-- Drop View
drop view AMC.TAPE_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_FINISH;
-- View erstellen
create or replace view AMC.TAPE_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_FINISH as
with MAX_CUT_OFF_DATE as (
    select MAX(CUT_OFF_DATE) as CUT_OFF_DATE from AMC.TABLE_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_CURRENT
)
select distinct
    TAPE.CUT_OFF_DATE,                                      -- Stichtag
    CLIENT_ID_BORROWER_ORIG     AS CLIENT_ID_BORROWER,      -- Haupt-Kundennummer des Schuldners/Kreditnehmers
    CLIENT_ID_NOBORROWER_ORIG   AS CLIENT_ID_NOBORROWER,    -- Haupt-Kundennummer des Bürgen
    CLIENT_ID_BORROWER_ALT      AS CLIENT_ID_BORROWER_ALT,  -- Haupt-Kundennummer des Schuldners/Kreditnehmers
    CLIENT_ID_NOBORROWER_ALT    AS CLIENT_ID_NOBORROWER_ALT,-- Haupt-Kundennummer des Bürgen
    ROLE,                                                   -- Fluggesellschaft oder Garantor?
    GUARANTOR_FUNCTION,
    ORDER_NUMBER                                            -- Nummer um Einträge (nach Wichtigkeit?) zu sortieren
from AMC.TABLE_CLIENT_ACCOUNTHOLDER_TO_THIRDPARTY_CURRENT as TAPE
inner join MAX_CUT_OFF_DATE on MAX_CUT_OFF_DATE.CUT_OFF_DATE = TAPE.CUT_OFF_DATE
;
-- CI END FOR ALL TAPES
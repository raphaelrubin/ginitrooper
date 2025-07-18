-----------------------
-- CLIENT_THIRDPARTY --
-----------------------
-- CI START FOR ALL TAPES
-- Drop View
drop view AMC.TAPE_CLIENT_THIRDPARTY_FINISH;
-- View erstellen
create or replace view AMC.TAPE_CLIENT_THIRDPARTY_FINISH as
with MAX_CUT_OFF_DATE as (
    select MAX(CUT_OFF_DATE) as CUT_OFF_DATE from AMC.TABLE_CLIENT_THIRDPARTY_CURRENT
)
select distinct
    TAPE.CUT_OFF_DATE,                  -- Stichtag
    BRANCH,                             -- Institut des Kunden (führendes Institut bevorzugt)
    CLIENT_ID_ORIG as CLIENT_ID,        -- Kundennummer des Original Instituts
    CLIENT_ID_ALT as CLIENT_ID_ALT,     -- Alternative Kundennummer wenn bekannt
    NACE,
    CLIENT_EBA_GVK_1,                   -- GVK nach EBA Richtlinen
    CLIENT_EBA_GVK_2,                   -- GVK nach EBA Richtlinen
    CLIENT_COUNTRY_ALPHA2,              -- Registerland des Kunden
    BALANCESHEET_CURRENCY_ISO,          -- Währung der Geld-Felder
    BALANCESHEET_EBITDA,                -- EBITDA (earnings before interest, taxes, depreciation and amortization)
    BALANCESHEET_DATE,                  -- Bilanzstichtag
    BALANCESHEET_TURNOVER_TOTAL,        -- Gesammtumsatz
    BALANCESHEET_COUNTRY_ALPHA2,        -- 2-stelliger Ländercode
    BALANCESHEET_CAPITAL_SHARE,         -- Stammkapital
    RATING_ID,
    RATING_MODUL
from AMC.TABLE_CLIENT_THIRDPARTY_CURRENT as TAPE
inner join MAX_CUT_OFF_DATE on MAX_CUT_OFF_DATE.CUT_OFF_DATE = TAPE.CUT_OFF_DATE;
-- CI END FOR ALL TAPES
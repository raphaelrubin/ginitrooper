--------------------------
-- CLIENT_ACCOUNTHOLDER --
--------------------------
-- CI START FOR ALL TAPES
-- Drop View
drop view AMC.TAPE_CLIENT_ACCOUNTHOLDER_FINISH;
-- View erstellen
create or replace view AMC.TAPE_CLIENT_ACCOUNTHOLDER_FINISH as
select distinct
    TAPE.CUT_OFF_DATE,                              -- Stichtag
    BRANCH,                                         -- Institut des Kunden (führendes Institut bevorzugt)
    CLIENT_ID_ORIG      as CLIENT_ID,               -- Kundennummer des Original Instituts
    CLIENT_ID_LEADING,                              -- Führende Kundennummer aus dem Ergebnis der Institutsfusion
    CLIENT_ID_ALTERNATIVE,                          -- Alternative Kundennummer wenn bekannt
    BORROWERNAME,                                   -- Kundenname
    KONZERN_ID,                                     -- Konzern_ID
    KONZERN_BEZEICHNUNG,                            -- Konzen_Bezeichnung
    GVK_BUNDESBANKNUMMER,
    NACE,                                           -- statistische Systematik der Wirtschaftszweige in der EU [abbr.: NACE]
    COUNTRY,                                        -- Land KNK Code + Text
    COUNTRY_APLHA2,                                 -- Land Alpha2 Wert
    LEGALFORM,                                      -- Legaler Aufbau des Unternehmens (GmbH, AG,...)
    EBITDA,                                         -- Ergebnis vor Zinsen, Steuern und Abschreibungen
    REVENUE,                                        -- Einnahmen?
    OPERATING_EXPENSES,                             -- Betriebskosten?
    OTHER_EXPENSES,                                 -- Andere Ausgaben
    CLIENT_BALANCE_SHEET_CURRENCY,                  -- Hauptwährung des Kunden
    CLIENT_BALANCE_SHEET_DATE,
    ARISK_GESSICHW,
    MRISK_GESSICHW,
    RISK_GESSIW_WAEHR,
    RATING_ID,
    RATING_MODUL
from AMC.TABLE_CLIENT_ACCOUNTHOLDER_CURRENT as TAPE
;
-- CI END FOR ALL TAPES

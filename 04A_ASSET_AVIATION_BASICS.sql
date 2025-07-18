------------------------------------------------------------------------------------------------------------------------
/* Aircraft Tape (5) Assets
 *
 * Flugzeuge Assets ist eine von zwei großen Asset Tapes. Assets, oder Vermögensobjekte stehen hinter einem
 * Sicherheitenvertrag. Ein Sicherheitenvetrag besichert ein Konto. Die Konten befinden sich in FACILITY_DETAILS.
 * Informationen über Sicherheitenverträge für Flugzeuge werden in dieser Datei in Schritt 3 erzeugt und Informationen
 * über Vermögensobjekte für Flugzeuge in Schritt 5. Schritte 2 und 4 erstellen Tabellen, welche Verknüpfungen zwischen
 * den drei Informationstabellen darstellen.
 *
 * Dieses Tape wird in mehreren Schritten gebaut:
 * 1. Basistabellen
 *   a) AMC.TABLE_AIRCRAFT_LAST
 *   b) AMC.TABLE_AIRCRAFT_LINK
 * 2. COLLATERAL TO FACILITY LINKING
 *   a) AMC.TAPE_FLUGZEUGE_PORTFOLIO_COLLATERAL_TO_FACILITY
 * 3. COLLATERAL / Sicherheitenverträge
 *   a) AMC.TAPE_FLUGZEUGE_PORTFOLIO_COLLATERAL
 * 4. ASSETS TO COLLATERAL LINKING
 *   a) AMC.TAPE_FLUGZEUGE_PORTFOLIO_ASSET_TO_COLLATERAL
 * 5. ASSETS / Vermögensobjekte / VO
 *   a) AMC.FLUGZEUGE_ASSET_BASICS
 *   b) AMC.TAPE_FLUGZEUGE_PORTFOLIO_ASSET
 */
------------------------------------------------------------------------------------------------------------------------

/*****************************************
 * ASSETS / Vermögensobjekte / VO
 * 5a) AMC.FLUGZEUGE_ASSET_BASICS
 *****************************************/

-- BASICS VIEW
------------------------------------------------------------------------------------------------------------------------
-- View erstellen
drop view CALC.VIEW_AVIATION_ASSET_BASICS;
create or replace view CALC.VIEW_AVIATION_ASSET_BASICS as
    with
     -- Daten aus CMS_VO
     VERMOEGENSOBJEKTE as (
         select CUTOFFDATE,
                VO_ID,
                VO_ACR_REGLAND,
                VO_TYP,
                VO_ART,
                VO_STATUS,
                VO_ACR_TYPKLASSE,
                VO_NOMINAL_WERT,
                VO_NOMINAL_WERT_WAEHR,
                VO_ANZUS_WERT,
                VO_ANZUS_WERT_WAEHR,
                trim (trim (L '0' from left(VO_ACR_MSN, 11))) as MSN
         from NLB.CMS_VO_CURRENT as VO where VO_STATUS = 'Rechtlich aktiv' and VO_TYP='Flugzeuge'
     ),
     -- Daten aus SPECIFICS_MORE_AIRCRAFT_PROPERTIES
     AIRCRAFT_PROPERTIES as (
         select CUTOFFDATE,
                left(CMS_ID, 11) as VO_ID,
                trim (trim (L '0' from left(MSN, 11))) as MSN,
                CMS_ID,
                FINANZIERUNGSOBJEKTTYP,
                BAUJAHR,
                AVAC_RATINGNOTE,
                FIRMA_DES_LEASINGNEHMER,
                LB_RATINGNOTE_FC_DES_LEASINGNEHMER,
                LEASELAUFZEIT_BIS_DES_LEASINGNEHMER,
                FIRMA_DES_SUBLEASINGNEHMER,
                LB_RATINGNOTE_FC_DES_SUBLEASINGNEHMER,
                LEASELAUFZEIT_BIS_DES_SUBLEASINGNEHMER,
                FINANZIERUNGSOBJEKTNUMMER -- für zweiten join
         from NLB.SPECIFICS_MORE_AIRCRAFT_PROPERTIES
         where NOT (CMS_ID in ('9000729') and FINANZIERUNGSOBJEKTTYP = 'ATR72')
     ),
     -- Daten aus SPECIFICS_FLUGZEUG_FULL_LENGTH für Flugzeuge und Mieter
     AIRCRAFT_SPECIFICS as (
         select
                CUTOFFDATE,
                case
                    --when ASSET_ID_CMS = '9002414' and CUTOFFDATE not in ('2019-03-31','2019-09-30') then '9000729'  -- hierbei handelt es sich um eine fehlerhafte MSN die nicht verwendet werden darf. Problem ATR72/A330 mit identischer MSN
                    when ASSET_ID_CMS = '9002414' and CUTOFFDATE in ('2019-03-31','2019-09-30') then NULL           -- Korrektur fehlerhafte Verknüpfung wenn join über VO_ID statt MSN erfolgt.
                    --when ASSET_ID_CMS = '9000729' and CUTOFFDATE not in ('2019-03-31','2019-09-30') then NULL       -- hierbei handelt es sich um eine fehlerhafte MSN die nicht verwendet werden darf. Problem ATR72/A330 mit identischer MSN
                    when ASSET_ID_CMS = '9000913' and CUTOFFDATE in ('2019-03-31') then '9002501'                   -- Korrektur fehlerhafte Verknüpfung wenn join über VO_ID statt MSN erfolgt.
                    when ASSET_ID_CMS = '31932'   and CUTOFFDATE = '2018-12-31' then '9002420'                      -- Korrektur fehlerhafte Verknüpfung wenn join über VO_ID statt MSN erfolgt.
                    else
                        ASSET_ID_CMS
                end                     as VO_ID,
                MSN_ESN,
                trim (trim (L '0' from MSN_ESN)) AS MSN,
                REGISTRATION_COUNTRY,
                CLASSIFICATION,
                BESICHERUNGSART,
                REGISTRATION_ID,
                TYPE_CLASS,
                MANUFACTURER_MODEL,
                VARIANT,
                BUILD_YEAR,
                AVAC_RATING,
                GUTACHTERDATUM,
                LESSEE_ID, -- Mieter ID
                LESSEE_LEASE_START_DATE,
                LESSEE_LEASE_END_DATE,
                LESSEE_LEASE_RATE,
                LESSEE_LEASE_RATE_CURRENCY,
                LESSEE_LEASE_RATE_PERIODE,
                SUB_LESSEE_ID,
                SUB_LESSEE_LEASE_END_DATE
         from NLB.SPECIFICS_FLUGZEUG_FULL_LENGTH
     ),
     -- Kombination der Flugzeug Basisdaten aus CMS_VO, SPECIFICS_MORE_AIRCRAFT_PROPERTIES und SPECIFICS_FLUGZEUG_FULL_LENGTH
     AIRCRAFT_DETAILS as (
         select distinct
            -- START VERMOEGENSOBJEKTE
            VERMOEGENSOBJEKTE.CUTOFFDATE                                                                    as CUT_OFF_DATE,
            VERMOEGENSOBJEKTE.VO_ID                                                                         as ASSET_ID,
            VERMOEGENSOBJEKTE.VO_TYP,
            VERMOEGENSOBJEKTE.VO_NOMINAL_WERT,
            VERMOEGENSOBJEKTE.VO_NOMINAL_WERT_WAEHR,
            VERMOEGENSOBJEKTE.VO_ANZUS_WERT,
            VERMOEGENSOBJEKTE.VO_ANZUS_WERT_WAEHR,
            -- ENDE VERMOEGENSOBJEKTE
            -- START AIRCRAFT_PROPERTIES
            AIRCRAFT_PROPERTIES.CMS_ID,
            AIRCRAFT_PROPERTIES.AVAC_RATINGNOTE,
            AIRCRAFT_PROPERTIES.FIRMA_DES_LEASINGNEHMER,
            AIRCRAFT_PROPERTIES.LB_RATINGNOTE_FC_DES_LEASINGNEHMER                                          as AIRCRAFT_LESSEE_RATING,
            AIRCRAFT_PROPERTIES.LEASELAUFZEIT_BIS_DES_LEASINGNEHMER,
            AIRCRAFT_PROPERTIES.FIRMA_DES_SUBLEASINGNEHMER,
            AIRCRAFT_PROPERTIES.LB_RATINGNOTE_FC_DES_SUBLEASINGNEHMER,
            AIRCRAFT_PROPERTIES.LEASELAUFZEIT_BIS_DES_SUBLEASINGNEHMER,
            --first_value(coalesce(prop.PRODUKTGRUPPE, prop2.PRODUKTGRUPPE)) over (partition by MSN_ESN, FLG.CUTOFFDATE order by coalesce(prop.PRODUKTGRUPPE, prop2.PRoduktgruppe) ASC) as PRODUKTGRUPPE,
            -- ENDE AIRCRAFT_PROPERTIES
            -- START AIRCRAFT_SPECIFICS
            AIRCRAFT_SPECIFICS.REGISTRATION_ID                                                              as AIRCRAFT_REGISTRATION_ID,
            AIRCRAFT_SPECIFICS.VARIANT,
            AIRCRAFT_SPECIFICS.AVAC_RATING,
            AIRCRAFT_SPECIFICS.GUTACHTERDATUM,
            AIRCRAFT_SPECIFICS.LESSEE_ID, -- Mieter ID
            AIRCRAFT_SPECIFICS.LESSEE_LEASE_START_DATE,
            AIRCRAFT_SPECIFICS.LESSEE_LEASE_END_DATE,
            AIRCRAFT_SPECIFICS.LESSEE_LEASE_RATE                                                            as AIRCRAFT_LEASE_RATE,
            AIRCRAFT_SPECIFICS.LESSEE_LEASE_RATE_CURRENCY                                                   as AIRCRAFT_LEASE_RATE_CURRENCY,
            AIRCRAFT_SPECIFICS.LESSEE_LEASE_RATE_PERIODE                                                    as AIRCRAFT_LEASE_RATE_PERIOD,
            AIRCRAFT_SPECIFICS.SUB_LESSEE_ID,
            AIRCRAFT_SPECIFICS.SUB_LESSEE_LEASE_END_DATE,
            -- ENDE AIRCRAFT_SPECIFICS
            A2C.BRANCH,
            -- START KOMBINATIONEN
            case
                when VERMOEGENSOBJEKTE.VO_ID='9000729' and coalesce(VERMOEGENSOBJEKTE.MSN,AIRCRAFT_PROPERTIES.MSN,AIRCRAFT_SPECIFICS.MSN) = '883'
                    then '883'  --hierbei handelt es sich um eine fehlerhafte MSN die nicht verwendet werden darf. Problem ATR72/A330 mit identischer MSN
                when VERMOEGENSOBJEKTE.VO_ID='9002414' and coalesce(VERMOEGENSOBJEKTE.MSN,AIRCRAFT_PROPERTIES.MSN,AIRCRAFT_SPECIFICS.MSN) = '883'
                    then '8830' --hierbei handelt es sich um eine fehlerhafte MSN die nicht verwendet werden darf. Problem ATR72/A330 mit identischer MSN. MSN 8830 ist eine künstlich erstellte MSN für späteren Join mit GUTACHTEN!
                else coalesce(VERMOEGENSOBJEKTE.MSN,AIRCRAFT_PROPERTIES.MSN,AIRCRAFT_SPECIFICS.MSN)
            end                                                                                             as MSN,
            coalesce(VERMOEGENSOBJEKTE.VO_ART, AIRCRAFT_SPECIFICS.CLASSIFICATION)                           as ASSET_DESCRIPTION,
            coalesce(VERMOEGENSOBJEKTE.VO_STATUS, AIRCRAFT_SPECIFICS.BESICHERUNGSART)                       as VO_STATUS,
            coalesce(AIRCRAFT_SPECIFICS.TYPE_CLASS, VERMOEGENSOBJEKTE.VO_ACR_TYPKLASSE)                     as AIRCRAFT_TYPE_CLASS,
            coalesce(AIRCRAFT_SPECIFICS.MANUFACTURER_MODEL, AIRCRAFT_PROPERTIES.FINANZIERUNGSOBJEKTTYP)     as MANUFACTURER_MODEL,
            replace(replace(replace(replace(replace(replace(replace(
                coalesce(AIRCRAFT_SPECIFICS.REGISTRATION_COUNTRY, VERMOEGENSOBJEKTE.VO_ACR_REGLAND),
                'Verein. Königr.', 'UK'),
                'Ver.Arab.Emir.', 'AE'),
                'Schweiz', 'CH'),
                'Südkorea', 'KR' ),
                'Taiwan', 'TW' ),
                'USA', 'US'),
                'Österreich', 'AT')
                                                                                                            as REGISTRATION_COUNTRY_PREMAP,
            replace(replace(UPPER(coalesce(AIRCRAFT_SPECIFICS.REGISTRATION_COUNTRY, VERMOEGENSOBJEKTE.VO_ACR_REGLAND)),'Ä', 'AE'), 'Ü', 'UE')
                                                                                                            as REGISTRATION_COUNTRY_NOUMLAUT,
            coalesce(year(AIRCRAFT_SPECIFICS.BUILD_YEAR), AIRCRAFT_PROPERTIES.BAUJAHR)                      as BUILD_YEAR,
            coalesce(AIRCRAFT_SPECIFICS.AVAC_RATING, AIRCRAFT_PROPERTIES.AVAC_RATINGNOTE)                   as AIRCRAFT_AVAC_RATING,
            coalesce(AIRCRAFT_SPECIFICS.LESSEE_LEASE_END_DATE, AIRCRAFT_PROPERTIES.LEASELAUFZEIT_BIS_DES_LEASINGNEHMER)
                                                                                                            as AIRCRAFT_LESSEE_LEASE_END_DATE,
            coalesce(AIRCRAFT_SPECIFICS.SUB_LESSEE_LEASE_END_DATE, AIRCRAFT_PROPERTIES.LEASELAUFZEIT_BIS_DES_SUBLEASINGNEHMER)
                                                                                                            as AIRCRAFT_SUB_LESSEE_LEASE_END_DATE,
            Current_USER                                                                                    as CREATED_USER,      -- Letzter Nutzer, der diese Tabelle gebaut hat.
            Current_TIMESTAMP                                                                               as CREATED_TIMESTAMP  -- Neuester Zeitstempel, wann diese Tabelle zuletzt gebaut wurde.
            -- ENDE KOMBINATIONEN
         from VERMOEGENSOBJEKTE -- aus NLB.CMS_VO
         inner join CALC.SWITCH_ASSET_TO_COLLATERAL_CURRENT as A2C on (VERMOEGENSOBJEKTE.VO_ID,VERMOEGENSOBJEKTE.CUTOFFDATE) = (A2C.ASSET_ID,A2C.CUT_OFF_DATE) -- nur interessiert an VOs, die auch im Mapping sind
         left join AIRCRAFT_PROPERTIES                                      on (AIRCRAFT_PROPERTIES.VO_ID, AIRCRAFT_PROPERTIES.CUTOFFDATE) = (VERMOEGENSOBJEKTE.VO_ID, VERMOEGENSOBJEKTE.CUTOFFDATE) -- aus NLB.SPECIFICS_MORE_AIRCRAFT_PROPERTIES
         left join AIRCRAFT_SPECIFICS                                       on (AIRCRAFT_SPECIFICS.VO_ID, AIRCRAFT_SPECIFICS.CUTOFFDATE) = (VERMOEGENSOBJEKTE.VO_ID, VERMOEGENSOBJEKTE.CUTOFFDATE)   -- aus NLB.SPECIFICS_FLUGZEUG_FULL_LENGTH
         --left join AIRCRAFT_PROPERTIES                          as prop1    on FLG.FLEET_NBR = prop1.FINANZIERUNGSOBJEKTNUMMER
     )
select * from AIRCRAFT_DETAILS
;

-- CI START FOR ALL TAPES
-- Current-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_AVIATION_ASSET_BASICS_CURRENT');
create table AMC.TABLE_AVIATION_ASSET_BASICS_CURRENT like CALC.VIEW_AVIATION_ASSET_BASICS distribute by hash(ASSET_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_AVIATION_ASSET_BASICS_CURRENT_ASSET_ID on AMC.TABLE_AVIATION_ASSET_BASICS_CURRENT (ASSET_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_AVIATION_ASSET_BASICS_CURRENT');
-- Archiv-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_AVIATION_ASSET_BASICS_ARCHIVE');
create table AMC.TABLE_AVIATION_ASSET_BASICS_ARCHIVE like CALC.VIEW_AVIATION_ASSET_BASICS distribute by hash(ASSET_ID) partition by range(CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2025' every 1 MONTH) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_AVIATION_ASSET_BASICS_ARCHIVE_ASSET_ID on AMC.TABLE_AVIATION_ASSET_BASICS_ARCHIVE (ASSET_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_AVIATION_ASSET_BASICS_ARCHIVE');
-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_AVIATION_ASSET_BASICS_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_AVIATION_ASSET_BASICS_ARCHIVE');
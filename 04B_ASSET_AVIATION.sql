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
 * 5b) AMC.TAPE_FLUGZEUGE_PORTFOLIO_ASSET
 *****************************************/


-- VIEW
------------------------------------------------------------------------------------------------------------------------
/* FLUGZEUGE_PORTFOLIO_ASSET_NEU
 * Assets auf Flugzeug Seite
 * basiert auf:
 * - AMC.FLUGZEUGE_ASSET_BASICS
 * - NLB.ACASA_FLUGZEUG_GUTACHTEN
 * - NLB.FLUGZEUG_RATING_INFOS
 * - NLB.FLUGZEUG_MAINTENANCE_RESERVES
 * - NLB.SPECIFICS_FLUGZEUG_FULL_LENGTH
 * - NLB.SPECIFICS_MORE_AIRCRAFT_PROPERTIES
 * - NLB.SAP_BW_KR_BORROWER
 * - ANL.SAP_BW_KR_BORROWER
 * - NLB.IWHS_KUNDE
 * - IMAP.ISO_LAENDER
 * - SMAP.CURRENCY_MAP
 */
-- View erstellen
drop view CALC.VIEW_AVIATION_ASSET;
create or replace view CALC.VIEW_AVIATION_ASSET as
    with
    -- Flugzeug Gutachten
    GUTACHTEN as (
         select *
        from (
                 select A.*,
                        row_number()
                                over (partition by trim(L '0' from MSN),CUTOFFDATE order by DATUM_GUELTIG desc nulls last) as NBR
                 from NLB.ACASA_FLUGZEUG_GUTACHTEN as A where msn <> '883'
                union
                 --Betrachte MSN 883 wegen Dopplung getrennt
                             select auftragsnummer, version, angefordert_am, angelegt_am, frist_intern, status, auftragsart, beauftragt_am,
                                    kundennr, gutachter, flu_nr, specifics_nr, anforderer, frist_fuer_extern, gesendet_an_ext, erhalten_von_ext,
                                    gesendet_an_fb, datum_eda, datum_da_i, datum_da_ii, datum_gueltig, kuev_monat, kuev_jahr, rechnung_nr,
                                    rg_datum, rg_weitergabe_datum, rg_vermerk, ueberpruefung_beantragt, ilv, kostenstelle, anforderer_zuleitung,
                                    gp_bezeichnung, flugzeughersteller, flugzeugmuster,
                                    case when MSN = '883' and FLUGZEUGMUSTER like '%ATR%' then '8830' else msn end as msn,
                                    triebwerkstyp, baudatum, regno_prefix, regno_rest,
                                    register_authority, land, ges_operator, ges_owner, ges_manager, anmerkungen, cmv_eda_usd, cmv_da_i_usd,
                                    cmv_da_ii_usd, cbv_eda_usd, cbv_da_i_usd, cbv_da_ii_usd, amv_usd, blw, risikomarktwert, current_lease,
                                    cms_triebwerkstyp, cms_triebwerksvariante, cms_id, cms_flugzeugmustertyp, cms_flugzeugmustervariante,
                                    specifics_eintrag, specifics_datum, vorlaeufig, sicherheitenwert, cbv_gem_fgs, cmv_gem_fgs, bewertungsanlass,
                                    esn1, esn2, esn3, esn4, intmxadjeda, hvymxadjeda, lgadjeda, llpadjeda, esvadjeda, totalmxadjeda,
                                    intmxadjoebm, hvymxadjoebm, lgadjoebm, llpadjoebm, esvadjoebm, totalmxadjoebm, triebwerkshaftungsverbund,
                                    drittverwendungsfaehigkeit, wartungsnachweis, eigenkapitalentlastend, cutoffdate, timestamp_load, etl_nr,
                                    quelle, branch, user,
                        row_number()
                                over (partition by trim(L '0' from MSN),AUFTRAGSNUMMER,CUTOFFDATE order by DATUM_GUELTIG desc nulls last) as NBR
                 from NLB.ACASA_FLUGZEUG_GUTACHTEN as A where msn = '883'
             ) AS GUTACHTEN
        where NBR = 1
    ),
    AIRCRAFT_STATUS as (
      select distinct
                      case when MSN_ESN = '883' and AC_TYPE like '%ATR%' then '8830' else MSN_ESN end as MSN_ESN,
                      register, oem, ac_type, type_detail, yom, operator, region_operator, market_class, market_class_detail, aircraft_status,
                      marktwert_bm_in_usd, datum_marktwert_bm, wertindikation_in_usd, cutoffdate from NLB.ACASA_AIRCRAFT_AKT_STATUS
    ),
    FLUGZEUG_RATING_INFOS as (
        select *
        from NLB.FLUGZEUG_RATING_INFOS
        where NOT (KUNDE_NR = '80111709' and FLU_MANUAL_SERIAL_NUM = '883')
          and NOT (KUNDE_NR = '80072782' and FLU_TECH_RATING_ID = '530837' and FLU_TECH_AIRCRAFT_ID = '1')
    ),
    MSN_TO_MAINTENANCE_RESERVES_RAW as (
        select distinct
            RATING_INFOS.FLU_MANUAL_SERIAL_NUM                                                                                                                                                                                         as MSN,
            first_value(MAINTENANCE_RESERVES.MAINT_RES_VALUE) over (partition by FLU_MANUAL_SERIAL_NUM,MAINTENANCE_RESERVES.CUTOFFDATE order by date(PERIOD_DATE) desc /*RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING */) as FULL_LIFE_MR,
            MAINTENANCE_RESERVES.CUTOFFDATE                                                                                                                                                                                            as CUT_OFF_DATE
        from FLUGZEUG_RATING_INFOS as RATING_INFOS
        left join NLB.FLUGZEUG_MAINTENANCE_RESERVES as MAINTENANCE_RESERVES
            on MAINTENANCE_RESERVES.TECH_RATING_ID = RATING_INFOS.FLU_TECH_RATING_ID
                and MAINTENANCE_RESERVES.TECH_AIRCRAFT_ID = RATING_INFOS.FLU_TECH_AIRCRAFT_ID
                and MAINTENANCE_RESERVES.CUTOFFDATE = RATING_INFOS.CUTOFFDATE
    ),
    -- Maintenance Reserve
    MAINTENANCE_RESERVES as (
         select MSN
              , FULL_LIFE_MR
              , CUT_OFF_DATE
         from MSN_TO_MAINTENANCE_RESERVES_RAW
         where FULL_LIFE_MR > 0
    ),
    RATING as (
        select * from (
             select *,
             row_number() over (partition by FLU_MANUAL_SERIAL_NUM,CUTOFFDATE order by coalesce(RATING_ZEITPUNKT,'01.01.9999') desc ) as NBR
             from NLB.FLUGZEUG_RATING_INFOS
             where NOT (KUNDE_NR = '80111709' and FLU_MANUAL_SERIAL_NUM = '883')
               and NOT (KUNDE_NR = '80072782' and FLU_TECH_RATING_ID = '530837' and FLU_TECH_AIRCRAFT_ID = '1')
               --and FLU_MANUAL_SERIAL_NUM = '39612'
                      )
        where NBR = 1
    ),
    PRODUKTGRUPPEN as (
         select distinct CMS_ID, PRODUKTGRUPPE, MSN, RN
                --Nimm Cutoffdate aus der Selektion, da für Join eh nicht benötigt, und es sonst Dopplungen wg NULL Einträgen erzeugt.
         from (
                  select distinct prop.CMS_ID
                                , coalesce(prop.PRODUKTGRUPPE, prop2.PRoduktgruppe)                                  as PRODUKTGRUPPE
                                , case
                                    when MSN_ESN = '883' and prop.CMS_ID = 9002414 then '8830'
                                        else MSN_ESN end as MSN
                                , FLG.CUTOFFDATE
                                , row_number()
                          over (partition by MSN_ESN,prop.CMS_ID, FLG.CUTOFFDATE order by coalesce(prop.PRODUKTGRUPPE, prop2.PRODUKTGRUPPE) ASC) as rn
                  from NLB.SPECIFICS_FLUGZEUG_FULL_LENGTH as FLG
                           left join NLB.SPECIFICS_MORE_AIRCRAFT_PROPERTIES as prop
                                     on prop.CMS_ID = flg.ASSET_ID_CMS
                                        left join NLB.SPECIFICS_MORE_AIRCRAFT_PROPERTIES as prop2
                                     on prop2.FINANZIERUNGSOBJEKTNUMMER = FLG.FLEET_NBR
              )
        where rn = 1 and PRODUKTGRUPPE is not null
    ),
    -- Kombination der Flugzeug Basisdaten aus CMS_VO, SPECIFICS_MORE_AIRCRAFT_PROPERTIES und SPECIFICS_FLUGZEUG_FULL_LENGTH
    AIRCRAFT_DETAILS as (
        select * from CALC.SWITCH_AVIATION_ASSET_BASICS_CURRENT
    ),
    KR_BORROWER as (
        select BORROWERID, INTERNALRATING, INTERNALRATINGMETHOD, CUTOFFDATE
        from NLB.SAP_BW_KR_BORROWER
        union all
        select BORROWERID, INTERNALRATING, INTERNALRATINGMETHOD, CUTOFFDATE
        from ANL.SAP_BW_KR_BORROWER
    ),
    DATA as (
         select distinct
             ACR_DET.CUT_OFF_DATE                                                      as CUT_OFF_DATE,
             ACR_DET.ASSET_ID                                                          as ASSET_ID,
             case
                 when ACR_DET.MSN is not NULL then
                     coalesce(ACR_DET.VO_TYP, 'Flugzeuge')
                 else ACR_DET.VO_TYP
             end                                                                       as ASSET_TYPE,
             ACR_DET.ASSET_DESCRIPTION                                                 as ASSET_DESCRIPTION,
             ACR_DET.VO_STATUS                                                         as VO_STATUS,
             ACR_DET.BRANCH                                                            as BRANCH,
             case when ACR_DET.MSN = '8830' then '883' else ACR_DET.MSN end            as AIRCRAFT_MSN_NUMBER,
                         -- Hierbei muss die Künstliche MSN 8330 die konstruiert wird um den Join über die Doppelte MSN nutzen, zurück auf die orginale gemappt werden
             ACR_DET.AIRCRAFT_REGISTRATION_ID                                          as AIRCRAFT_REGISTRATION_ID,
             round(coalesce(RATING.CURRENT_VALUE, CMV_DA_II_USD) / USD_EXCHANGE.KURS, 2)
                                                                                       as AIRCRAFT_APPRAISAL_MARKET_VALUE_HALF_LIFE_EUR,
             round(nullif(coalesce(RATING.CURRENT_VALUE, CMV_DA_II_USD, 0) + coalesce(FULL_LIFE_MR, 0), 0) / USD_EXCHANGE.KURS, 2)
                                                                                       as AIRCRAFT_APPRAISAL_MARKET_VALUE_FULL_LIFE_EUR,
             case
                 when ACR_DET.VO_TYP in ('Schiffe', 'Schiff', 'Flugzeuge', 'Flugzeug', 'Triebwerk') then
                     round(ACR_DET.VO_ANZUS_WERT / coalesce(ANZ_WERT_EXCHANGE.KURS, 1), 2)
                 else
                     round(ACR_DET.VO_NOMINAL_WERT / coalesce(NOM_WERT_EXCHANGE.KURS, 1), 2)
             end                                                                       as AIRCRAFT_APPRAISAL_MARKET_VALUE_CMS,
             round(coalesce(CBV_DA_II_USD, RATING.CURRENT_BASE_VALUE) / USD_EXCHANGE.KURS,2)
                                                                                       as AIRCRAFT_APPRAISAL_BASE_VALUE_HALF_LIFE_EUR,
             round(nullif(coalesce(CBV_DA_II_USD, RATING.CURRENT_BASE_VALUE, 0) + coalesce(FULL_LIFE_MR, 0), 0) /USD_EXCHANGE.KURS, 2)
                                                                                       as AIRCRAFT_APPRAISAL_BASE_VALUE_FULL_LIFE_EUR,
             case
                 when ACR_DET.VO_TYP in ('Schiffe', 'Schiff', 'Flugzeuge', 'Flugzeug', 'Triebwerk') then
                     round(ACR_DET.VO_NOMINAL_WERT / coalesce(NOM_WERT_EXCHANGE.KURS, 1), 2)
                 else
                     round(ACR_DET.VO_ANZUS_WERT / coalesce(ANZ_WERT_EXCHANGE.KURS, 1), 2)
             end                                                                       as AIRCRAFT_APPRAISAL_BASE_VALUE_CMS,
             round(MAINTENANCE_RESERVE.FULL_LIFE_MR / USD_EXCHANGE.KURS, 2)            as AIRCRAFT_MAINTENANCE_RESERVES,
             case
               when MAINTENANCE_RESERVE.FULL_LIFE_MR > 0
                   then 'full life'
               else 'half life'
             end                                                                       as AIRCRAFT_RETURN_CONDITION,
             ACR_DET.AIRCRAFT_TYPE_CLASS                                               as AIRCRAFT_TYPE_CLASS,
             coalesce(ACR_DET.MANUFACTURER_MODEL, GUTACHTEN.FLUGZEUGMUSTER)            as AIRCRAFT_MANUFACTURER_MODEL,
             coalesce(ACR_DET.VARIANT, GUTACHTEN.CMS_FLUGZEUGMUSTERVARIANTE)           as aircraft_variant,
             coalesce(REGISTRATION_COUNTRY.COUNTRY_APLHA2, ACR_DET.REGISTRATION_COUNTRY_PREMAP,REPORT_COUNTRY.COUNTRY_APLHA2)
                                                                                       as AIRCRAFT_REGISTRATION_COUNTRY,
             coalesce(ACR_DET.BUILD_YEAR, LEFT(year(GUTACHTEN.BAUDATUM), 4))           as AIRCRAFT_BUILD_YEAR,
             timestampdiff(256, timestamp(ACR_DET.CUT_OFF_DATE) - timestamp(coalesce(GUTACHTEN.BAUDATUM, ACR_DET.CUT_OFF_DATE)))
                 -- Zeitdifferenz in Jahren
                                                                                       as AIRCAFT_AGE_IN_YEARS,
             ACR_DET.AIRCRAFT_AVAC_RATING                                              as AIRCRAFT_AVAC_RATING,
             PRODUKTGRUPPE.PRODUKTGRUPPE                                               as AIRCRAFT_FINANCE_TYPE,
             GUTACHTEN.GES_OWNER                                                       as AIRCRAFT_OWNER,
             ID2.CLIENT_ID                                                             as AIRCRAFT_OWNER_CLIENT_ID,
             GUTACHTEN.GES_MANAGER                                                     as AIRCRAFT_MANAGER,
             ID1.CLIENT_ID                                                             as AIRCRAFT_MANAGER_CLIENT_ID,
             GUTACHTEN.GES_OPERATOR                                                    as AIRCRAFT_OPERATOR,
             ID3.CLIENT_ID                                                             as AIRCRAFT_OPERATOR_CLIENT_ID,
             GUTACHTEN.GUTACHTER                                                       as AIRCRAFT_APPRAISER,
             ID4.CLIENT_ID                                                             as AIRCRAFT_APPRAISER_CLIENT_ID,
             1                                                                         as AIRCRAFT_APRAISER_DATA_ISTAT_GUIEDELINES,
             coalesce(ACR_DET.GUTACHTERDATUM, GUTACHTEN.DATUM_GUELTIG)                 as AIRCRAFT_VALUATION_DATE,
             case
                 when UPPER(GUTACHTEN.WARTUNGSNACHWEIS) = 'JA' then 1
                 else 0
             end                                                                       as AIRCRAFT_MAINTENANCE_CERTIFICATE,
             case
                 when UPPER(GUTACHTEN.DRITTVERWENDUNGSFAEHIGKEIT) = 'JA' then 1
                 else 0
             end                                                                       as AIRCRAFT_THIRD_PARTY_USABILITY,
             RATING.RATING_ZEITPUNKT                                                   as AIRCRAFT_RATING_DATE,
             RATING.T_RISIKONOTE_L                                                     as AIRCRAFT_RATING,
             replace(coalesce(LESSEE_IWHS.BORROWERNAME, ACR_DET.FIRMA_DES_LEASINGNEHMER), 'OÜ','Oue')
                                                                                       as AIRCRAFT_LESSEE_NAME,
             ACR_DET.AIRCRAFT_LESSEE_RATING                                            as AIRCRAFT_LESSEE_RATING,
             LESSEE_KR.INTERNALRATING                                                  as AIRCRAFT_LESSEE_RATING_KR,
             ACR_DET.AIRCRAFT_LESSEE_LEASE_END_DATE                                    as AIRCRAFT_LESSEE_LEASE_END_DATE,
             coalesce(SUB_LESSEE_IWHS.BORROWERNAME,ACR_DET.FIRMA_DES_SUBLEASINGNEHMER) as AIRCRAFT_SUB_LESSEE_NAME,
             ACR_DET.LB_RATINGNOTE_FC_DES_SUBLEASINGNEHMER                             as AIRCRAFT_SUB_LESSEE_RATING,
             SUB_LESSEE_KR.INTERNALRATING                                              as AIRCRAFT_SUB_LESSEE_RATING_KR,
             ACR_DET.AIRCRAFT_SUB_LESSEE_LEASE_END_DATE                                as AIRCRAFT_SUB_LESSEE_LEASE_END_DATE,
             RATING.LEA_SEC_DEPOSITS                                                   as AIRCRAFT_PLEDGED_LIQUIDITY_RESERVE,
             RATING.LEA_CURRENCY_SEC_DEP_ISO                                           as AIRCRAFT_PLEDGED_LIQUIDITY_RESERVE_CURRENCY,
             ACR_DET.AIRCRAFT_LEASE_RATE                                               as AIRCRAFT_LEASE_RATE,
             ACR_DET.AIRCRAFT_LEASE_RATE_CURRENCY                                      as AIRCRAFT_LEASE_RATE_CURRENCY,
             ACR_DET.AIRCRAFT_LEASE_RATE_PERIOD                                        as AIRCRAFT_LEASE_RATE_PERIOD,
             case
                 when ACR_DET.MSN is not NULL
                    and coalesce(ACR_DET.LESSEE_LEASE_END_DATE, ACR_DET.LEASELAUFZEIT_BIS_DES_LEASINGNEHMER) > ACR_DET.CUT_OFF_DATE
                    and coalesce(ACR_DET.LESSEE_LEASE_START_DATE, ACR_DET.LESSEE_LEASE_END_DATE, ACR_DET.LEASELAUFZEIT_BIS_DES_LEASINGNEHMER) <= ACR_DET.CUT_OFF_DATE
                    then 1.0
                 when ACR_DET.MSN is not NULL
                    and coalesce(ACR_DET.LESSEE_LEASE_END_DATE, ACR_DET.LEASELAUFZEIT_BIS_DES_LEASINGNEHMER) > ACR_DET.CUT_OFF_DATE
                    and coalesce(ACR_DET.BUILD_YEAR, LEFT(YEAR(GUTACHTEN.BAUDATUM), 4)) >= Year(ACR_DET.CUT_OFF_DATE)
                    then 1.0
                 when ACR_DET.MSN is not NULL
                    and ACR_DET.LESSEE_LEASE_START_DATE < ACR_DET.CUT_OFF_DATE
                    then coalesce(timestampdiff(16,timestamp(ACR_DET.CUT_OFF_DATE) - timestamp(ACR_DET.LESSEE_LEASE_START_DATE)), 0) / (90.0)
                 -- Zeitdifferenz in Tagen / 90
                 else NULL
             end                                                                       as AIRCRAFT_LEASED_RATE_CURRENT_LEASE_CURRENT_YEAR,
            -- NEUE SPALTEN AUS AIRCRAFT STATUS
            ACS.REGION_OPERATOR,
            ACS.MARKET_CLASS ,
            ACS.MARKET_CLASS_DETAIL,
            ACS.MARKTWERT_BM_IN_USD ,
            ACS.DATUM_MARKTWERT_BM ,
            ACS.WERTINDIKATION_IN_USD,
            ACS.AIRCRAFT_STATUS,
            ACS.CUTOFFDATE as DATUM_AIRCRAFT_STATUS,
             Current_USER                                                              as CREATED_USER,
                         -- Letzter Nutzer, der diese Tabelle gebaut hat.
             Current_TIMESTAMP                                                         as CREATED_TIMESTAMP
              -- Neuester Zeitstempel, wann diese Tabelle zuletzt gebaut wurde.
        from AIRCRAFT_DETAILS                   as ACR_DET
        left join IMAP.CURRENCY_MAP             as NOM_WERT_EXCHANGE    on (ACR_DET.VO_NOMINAL_WERT_WAEHR, ACR_DET.CUT_OFF_DATE) = (NOM_WERT_EXCHANGE.ZIEL_WHRG, NOM_WERT_EXCHANGE.CUT_OFF_DATE)
        left join IMAP.CURRENCY_MAP             as ANZ_WERT_EXCHANGE    on (ACR_DET.VO_ANZUS_WERT_WAEHR, ACR_DET.CUT_OFF_DATE) = (ANZ_WERT_EXCHANGE.ZIEL_WHRG, ANZ_WERT_EXCHANGE.CUT_OFF_DATE)
        left join PRODUKTGRUPPEN                as PRODUKTGRUPPE        on PRODUKTGRUPPE.MSN = ACR_DET.MSN
                                                                        --and VO.CUTOFFDATE = PG.CUTOFFDATE --hier derzeit kein Cutoffdate nutzen
        left join RATING                        as RATING               on trim(L '0' from ACR_DET.MSN) = trim(L '0' from RATING.FLU_MANUAL_SERIAL_NUM)
                                                                          and ACR_DET.CUT_OFF_DATE = RATING.CUTOFFDATE
        left join MAINTENANCE_RESERVES          as MAINTENANCE_RESERVE  on trim(L '0' from MAINTENANCE_RESERVE.msn) = trim(L '0' from ACR_DET.MSN)
                                                                          and ACR_DET.CUT_OFF_DATE = MAINTENANCE_RESERVE.CUT_OFF_DATE
        --left join NLB.FLUGZEUG_LEASING_RATEN    as LEASING_RATE         on (ACR_DET.ASSET_ID, ACR_DET.CUT_OFF_DATE) = (LEASING_RATE.CMS_ID, LEASING_RATE.CUTOFFDATE) --TODO: still needed?
        left join IMAP.CURRENCY_MAP             as USD_EXCHANGE         on ACR_DET.CUT_OFF_DATE = USD_EXCHANGE.CUT_OFF_DATE and USD_EXCHANGE.ZIEL_WHRG = 'USD'
        left join GUTACHTEN                     as GUTACHTEN            on trim(L '0' from GUTACHTEN.MSN) = trim(L '0' from ACR_DET.MSN)
                                                                          and ACR_DET.CUT_OFF_DATE = GUTACHTEN.CUTOFFDATE
        left join IMAP.ISO_LAENDER              as REGISTRATION_COUNTRY on REGISTRATION_COUNTRY.COUNTRY_ISO3166_OHNE_VR = ACR_DET.REGISTRATION_COUNTRY_NOUMLAUT
        left join IMAP.ISO_LAENDER              as REPORT_COUNTRY       on REPORT_COUNTRY.COUNTRY_ISO3166_OHNE_VR = UPPER(GUTACHTEN.LAND)
        left join NLB.IWHS_KUNDE_CURRENT        as LESSEE_IWHS          on trim(L '0' from ACR_DET.LESSEE_ID) = LESSEE_IWHS.BORROWERID
                                                                          and ACR_DET.CUT_OFF_DATE = LESSEE_IWHS.CUTOFFDATE
        left join NLB.IWHS_KUNDE_CURRENT        as SUB_LESSEE_IWHS      on trim(L '0' from ACR_DET.SUB_LESSEE_ID) = SUB_LESSEE_IWHS.BORROWERID
                                                                          and ACR_DET.CUT_OFF_DATE = SUB_LESSEE_IWHS.CUTOFFDATE
        left join KR_BORROWER                   as LESSEE_KR            on ACR_DET.LESSEE_ID = LESSEE_KR.BORROWERID
                                                                          and ACR_DET.CUT_OFF_DATE = LESSEE_KR.CUTOFFDATE
        left join KR_BORROWER                   as SUB_LESSEE_KR        on ACR_DET.SUB_LESSEE_ID = SUB_LESSEE_KR.BORROWERID
                                                                          and ACR_DET.CUT_OFF_DATE = SUB_LESSEE_KR.CUTOFFDATE
        left join AIRCRAFT_STATUS               as ACS                  on ACS.MSN_ESN=ACR_DET.MSN and ACS.CUTOFFDATE>=ACR_DET.CUT_OFF_DATE and ACS.CUTOFFDATE < last_day(ACR_DET.CUT_OFF_DATE + 1 month)
                                                                            --and ACS.AC_TYPE=ACR_DET.MANUFACTURER_MODEL
        left join SMAP.AIRLINE_AIRCRAFT_OWNER_NAME_TO_CLIENT_ID as ID1  on (ID1.NAME_ACASA_RAW=GUTACHTEN.GES_MANAGER and id1.IS_ACTIVE is true) or (ID1.NAME_NORMALIZED=GUTACHTEN.GES_MANAGER and id1.IS_ACTIVE is true)
            --Stelle sicher, dass nur Zeilen aus AIRLINE_AIRCRAFT_OWNER_NAME_TO_CLIENT_ID verwendet werden, die in der ursprünglichen SMAP-View-Version nciht auskommentiert waren.
        left join SMAP.AIRLINE_AIRCRAFT_OWNER_NAME_TO_CLIENT_ID as ID2  on (ID2.NAME_ACASA_RAW=GUTACHTEN.GES_OWNER and id2.IS_ACTIVE is true) or (ID2.NAME_NORMALIZED=GUTACHTEN.GES_OWNER and id2.IS_ACTIVE is true)
        left join SMAP.AIRLINE_AIRCRAFT_OWNER_NAME_TO_CLIENT_ID as ID3  on (ID3.NAME_ACASA_RAW=GUTACHTEN.GES_OPERATOR and id3.IS_ACTIVE is true) or (ID3.NAME_NORMALIZED=GUTACHTEN.GES_OPERATOR and id3.IS_ACTIVE is true)
        left join SMAP.AIRLINE_AIRCRAFT_OWNER_NAME_TO_CLIENT_ID as ID4  on (ID4.NAME_ACASA_RAW=GUTACHTEN.GUTACHTER and id4.IS_ACTIVE is true) or (ID4.NAME_NORMALIZED=GUTACHTEN.GUTACHTER and id4.IS_ACTIVE is true)
    )
select distinct * from DATA
;

-- CI START FOR ALL TAPES
-- Current-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_AVIATION_ASSET_CURRENT');
create table AMC.TABLE_AVIATION_ASSET_CURRENT like CALC.VIEW_AVIATION_ASSET distribute by hash(ASSET_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_AVIATION_ASSET_CURRENT_ASSET_ID on AMC.TABLE_AVIATION_ASSET_CURRENT (ASSET_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_AVIATION_ASSET_CURRENT');
-- Archiv-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_AVIATION_ASSET_ARCHIVE');
create table AMC.TABLE_AVIATION_ASSET_ARCHIVE like CALC.VIEW_AVIATION_ASSET distribute by hash(ASSET_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2025' EVERY 1 MONTH) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_AVIATION_ASSET_ARCHIVE_ASSET_ID on AMC.TABLE_AVIATION_ASSET_ARCHIVE (ASSET_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_AVIATION_ASSET_ARCHIVE');
-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_AVIATION_ASSET_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_AVIATION_ASSET_ARCHIVE');
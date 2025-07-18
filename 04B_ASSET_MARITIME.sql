------------------------------------------------------------------------------------------------------------------------
/* Ship Tape (4) Assets
 *
 * Das Ship Tape besteht aus 4 Dateien, wovon diese die vierte zum Ausführen ist.
 * Dieses Tape zeigt die Beziehung zwischen Konten (Facilities), Sicherheitenverträgen (Collaterals) und
 * Vermögensobjekten (Assets) auf.
 *
 * (1) Collateral to Facility
 * (2) Collaterals
 * (3) Asset to Collateral
 * (4) Assets
 */
------------------------------------------------------------------------------------------------------------------------
--
-- select VO_BELEIHSATZ1_P,VO_KUST,VO_PAS,VO_VOE as VO_PAS,VO_CRR_KZ
--     ,VO_GEBAEUDE_KZ -- nur für Immobilien
--     ,VO_DECKUNGSKZ_TXS --nur für Immobilien
-- from NLB.CMS_VO_CURRENT where VO_STATUS = 'Rechtlich aktiv';
--
-- View erstellen
drop view CALC.VIEW_MARITIME_ASSET;
create or replace view CALC.VIEW_MARITIME_ASSET as
with
    SONDERINFORMATIONEN_BEWERTUNGEN as (
        select
            *,
            trim(left(AUFTRAG_NR,locate_in_string(AUFTRAG_NR,'/')-1)) as AUFTRAG,
            trim(SUBSTR(AUFTRAG_NR,locate_in_string(AUFTRAG_NR,'/')+1)) as VERSION
        from NLB.SPO_SCHIFFE_BEWERTUNGSSONDERINFORMATIONEN
    ),
    SONDERINFORMATIONEN_ANDERE as (
        select
            *,
            trim(left(AUFTRAGSNUMMER,locate_in_string(AUFTRAGSNUMMER,'/')-1)) as AUFTRAG,
            trim(SUBSTR(AUFTRAGSNUMMER,locate_in_string(AUFTRAGSNUMMER,'/')+1)) as VERSION
        from NLB.SPO_SCHIFFE_SONDERINFORMATIONEN
    ),
    SONDERINFORMATIONEN_ALLE as  (
        select replace(IMO_ODER_KUNDENNUMMER,'(ENI) 0','') as IMO_ODER_KUNDENNUMMER,BAUDATUM,BESICHTIGUNGSDATUM,ZBA_BESI,MARKTWERT_GUELTIG,SHP.AUFTRAGSNUMMER,BEW.*, ROW_NUMBER() over (PARTITION BY IMO_ODER_KUNDENNUMMER) as NBR,SUM(RESEARCH_WERT_GEWICHTUNG) over ( partition by IMO_ODER_KUNDENNUMMER) as MAX_GEW
        from SONDERINFORMATIONEN_ANDERE as SHP
        left join SONDERINFORMATIONEN_BEWERTUNGEN as BEW on BEW.AUFTRAG=SHP.ASSET_NR
            where AUFTRAGSNUMMER is not null
    ),
    APPRAISER_1 as (
        select
            IMO_ODER_KUNDENNUMMER,
            BAUDATUM,
            RESEARCH_WERT__RESEARCH_WERT_WAEHRUNG,
            BESICHTIGUNGSDATUM,
            ZBA_BESI,
            MARKTWERT_GUELTIG,
            RESEARCH_WERT__RESEARCH_TYP                                    as TYPE,
            RESEARCH_WERT__QUELLE                                          as NAME,
            RESEARCH_WERT_GEWICHTUNG                                       as WEIGHTING,
            RESEARCH_WERT_INDEXIERUNG                                      as INDEX,
            RESEARCH_WERT_GEWICHTUNG * RESEARCH_WERT_INDEXIERUNG / MAX_GEW as QUOTA,
            RESEARCH_WERT_RESEARCH_WERT                                    as VALUE,
            CUTOFFDATE
        from SONDERINFORMATIONEN_ALLE
        where NBR = 1
    ),
    APPRAISER_2 as (
        select
            IMO_ODER_KUNDENNUMMER,
            RESEARCH_WERT__RESEARCH_TYP                                    as TYPE,
            RESEARCH_WERT__QUELLE                                          as NAME,
            RESEARCH_WERT_GEWICHTUNG * RESEARCH_WERT_INDEXIERUNG / MAX_GEW as QUOTA,
            RESEARCH_WERT_GEWICHTUNG                                       as WEIGHTING,
            RESEARCH_WERT_INDEXIERUNG                                      as INDEX,
            RESEARCH_WERT_RESEARCH_WERT                                    as VALUE,
            CUTOFFDATE
        from SONDERINFORMATIONEN_ALLE
        where NBR = 2
    ),
    APPRAISER_3 as (
        select
            IMO_ODER_KUNDENNUMMER,
            RESEARCH_WERT__RESEARCH_TYP                                    as TYPE,
            RESEARCH_WERT__QUELLE                                          as NAME,
            RESEARCH_WERT_GEWICHTUNG * RESEARCH_WERT_INDEXIERUNG / MAX_GEW as QUOTA,
            RESEARCH_WERT_GEWICHTUNG                                       as WEIGHTING,
            RESEARCH_WERT_INDEXIERUNG                                      as INDEX,
            RESEARCH_WERT_RESEARCH_WERT                                    as VALUE,
            CUTOFFDATE
        from SONDERINFORMATIONEN_ALLE
        where NBR = 3
    ),
    APPRAISER_4 as (
        select
            IMO_ODER_KUNDENNUMMER,
            RESEARCH_WERT__RESEARCH_TYP                                    as TYPE,
            RESEARCH_WERT__QUELLE                                          as NAME,
            RESEARCH_WERT_GEWICHTUNG * RESEARCH_WERT_INDEXIERUNG / MAX_GEW as QUOTA,
            RESEARCH_WERT_GEWICHTUNG                                       as WEIGHTING,
            RESEARCH_WERT_INDEXIERUNG                                      as INDEX,
            RESEARCH_WERT_RESEARCH_WERT                                    as VALUE,
            CUTOFFDATE
        from SONDERINFORMATIONEN_ALLE
        where NBR = 4
    ),
    APPRAISER_5 as (
        select
            IMO_ODER_KUNDENNUMMER,
            RESEARCH_WERT__RESEARCH_TYP                                    as TYPE,
            RESEARCH_WERT__QUELLE                                          as NAME,
            RESEARCH_WERT_GEWICHTUNG * RESEARCH_WERT_INDEXIERUNG / MAX_GEW as QUOTA,
            RESEARCH_WERT_GEWICHTUNG                                       as WEIGHTING,
            RESEARCH_WERT_INDEXIERUNG                                      as INDEX,
            RESEARCH_WERT_RESEARCH_WERT                                    as VALUE,
            CUTOFFDATE
        from SONDERINFORMATIONEN_ALLE
        where NBR = 5
    ),
    APPRAISER_6 as (
        select
            IMO_ODER_KUNDENNUMMER,
            RESEARCH_WERT__RESEARCH_TYP                                    as TYPE,
            RESEARCH_WERT__QUELLE                                          as NAME,
            RESEARCH_WERT_GEWICHTUNG * RESEARCH_WERT_INDEXIERUNG / MAX_GEW as QUOTA,
            RESEARCH_WERT_GEWICHTUNG                                       as WEIGHTING,
            RESEARCH_WERT_INDEXIERUNG                                      as INDEX,
            RESEARCH_WERT_RESEARCH_WERT                                    as VALUE,
            CUTOFFDATE
        from SONDERINFORMATIONEN_ALLE
        where NBR = 6
    ),
    -- ersten 6 Appraiser TODO: eigene Tabelle mit mapping Tabelle erstellen?
    APPRAISER as (
        select distinct
            APPRAISER_1.CUTOFFDATE,
            APPRAISER_1.IMO_ODER_KUNDENNUMMER                   as IMO_ODER_KUNDENNUMMER,
            APPRAISER_1.BESICHTIGUNGSDATUM                      as BESICHTIGUNGSDATUM,
            APPRAISER_1.ZBA_BESI                                as ABSCHLAG,
            APPRAISER_1.MARKTWERT_GUELTIG                       as MARKTWERT_GUELTIG,
            APPRAISER_1.RESEARCH_WERT__RESEARCH_WERT_WAEHRUNG   as CURRENCY,
            -- Appraiser 1
            APPRAISER_1.NAME                                    as SHIP_APPRAISER_1,
            APPRAISER_1.TYPE                                    as SHIP_APPRAISER_TYPE_1,
            APPRAISER_1.VALUE                                   as SHIP_APPRAISER_VALUE_1,
            APPRAISER_1.QUOTA                                   as SHIP_APPRAISER_QUOTA_1,
            APPRAISER_1.WEIGHTING                               as SHIP_APPRAISER_GEWICHTUNG_1,
            APPRAISER_1.INDEX                                   as SHIP_APPRAISER_INDEXIERUNG_1,
            -- Appraiser 2
            APPRAISER_2.NAME                                    as SHIP_APPRAISER_2,
            APPRAISER_2.TYPE                                    as SHIP_APPRAISER_TYPE_2,
            APPRAISER_2.VALUE                                   as SHIP_APPRAISER_VALUE_2,
            APPRAISER_2.QUOTA                                   as SHIP_APPRAISER_QUOTA_2,
            APPRAISER_2.WEIGHTING                               as SHIP_APPRAISER_GEWICHTUNG_2,
            APPRAISER_2.INDEX                                   as SHIP_APPRAISER_INDEXIERUNG_2,
            -- Appraiser 3
            APPRAISER_3.NAME                                    as SHIP_APPRAISER_3,
            APPRAISER_3.TYPE                                    as SHIP_APPRAISER_TYPE_3,
            APPRAISER_3.VALUE                                   as SHIP_APPRAISER_VALUE_3,
            APPRAISER_3.QUOTA                                   as SHIP_APPRAISER_QUOTA_3,
            APPRAISER_3.WEIGHTING                               as SHIP_APPRAISER_GEWICHTUNG_3,
            APPRAISER_3.INDEX                                   as SHIP_APPRAISER_INDEXIERUNG_3,
            -- Appraiser 4
            APPRAISER_4.NAME                                    as SHIP_APPRAISER_4,
            APPRAISER_4.TYPE                                    as SHIP_APPRAISER_TYPE_4,
            APPRAISER_4.VALUE                                   as SHIP_APPRAISER_VALUE_4,
            APPRAISER_4.QUOTA                                   as SHIP_APPRAISER_QUOTA_4,
            APPRAISER_4.WEIGHTING                               as SHIP_APPRAISER_GEWICHTUNG_4,
            APPRAISER_4.INDEX                                   as SHIP_APPRAISER_INDEXIERUNG_4,
            -- Appraiser 5
            APPRAISER_5.NAME                                    as SHIP_APPRAISER_5,
            APPRAISER_5.TYPE                                    as SHIP_APPRAISER_TYPE_5,
            APPRAISER_5.VALUE                                   as SHIP_APPRAISER_VALUE_5,
            APPRAISER_5.QUOTA                                   as SHIP_APPRAISER_QUOTA_5,
            APPRAISER_5.WEIGHTING                               as SHIP_APPRAISER_GEWICHTUNG_5,
            APPRAISER_5.INDEX                                   as SHIP_APPRAISER_INDEXIERUNG_5,
            -- Appraiser 6
            APPRAISER_6.NAME                                    as SHIP_APPRAISER_6,
            APPRAISER_6.TYPE                                    as SHIP_APPRAISER_TYPE_6,
            APPRAISER_6.VALUE                                   as SHIP_APPRAISER_VALUE_6,
            APPRAISER_6.QUOTA                                   as SHIP_APPRAISER_QUOTA_6,
            APPRAISER_6.WEIGHTING                               as SHIP_APPRAISER_GEWICHTUNG_6,
            APPRAISER_6.INDEX                                   as SHIP_APPRAISER_INDEXIERUNG_6
        from APPRAISER_1        as APPRAISER_1
        left join APPRAISER_2   as APPRAISER_2 on APPRAISER_2.IMO_ODER_KUNDENNUMMER = APPRAISER_1.IMO_ODER_KUNDENNUMMER and APPRAISER_1.CUTOFFDATE = APPRAISER_2.CUTOFFDATE
        left join APPRAISER_3   as APPRAISER_3 on APPRAISER_3.IMO_ODER_KUNDENNUMMER = APPRAISER_1.IMO_ODER_KUNDENNUMMER and APPRAISER_1.CUTOFFDATE = APPRAISER_3.CUTOFFDATE
        left join APPRAISER_4   as APPRAISER_4 on APPRAISER_4.IMO_ODER_KUNDENNUMMER = APPRAISER_1.IMO_ODER_KUNDENNUMMER and APPRAISER_1.CUTOFFDATE = APPRAISER_4.CUTOFFDATE
        left join APPRAISER_5   as APPRAISER_5 on APPRAISER_5.IMO_ODER_KUNDENNUMMER = APPRAISER_1.IMO_ODER_KUNDENNUMMER and APPRAISER_1.CUTOFFDATE = APPRAISER_5.CUTOFFDATE
        left join APPRAISER_6   as APPRAISER_6 on APPRAISER_6.IMO_ODER_KUNDENNUMMER = APPRAISER_1.IMO_ODER_KUNDENNUMMER and APPRAISER_1.CUTOFFDATE = APPRAISER_6.CUTOFFDATE
    ),
    PRE_EZB_SCHIFFE_TAPE as (
        SELECT
            A2C.CUT_OFF_DATE,
            EZB_ACASA.CUTOFFDATE as DATA_CUT_OFF_DATE,
            ASSET_ID,
            --CMS_ID,
            IMO_ID,
            VESSEL_NAME,
            THE_LATEST_APPRAISAL_DATE,
            THE_LATEST_APPRAISED_MARKET_VALUE_EUR,
            THE_LATEST_APPRAISED_MARKET_VALUE_USD,
            APPRAISER,
            --THE_PREVIOUS_APPRAISAL_DATE,
            --THE_PREVIOUS_APPRAISED_MARKET_VALUE_EUR,
            --THE_PREVIOUS_APPRAISED_MARKET_VALUE_USD,
            --THE_APPRAISER_OF_THE_PREVIOUS_APPRAISAL,
            SEGMENT,
            SUB_SEGMENT,
            VESSEL_CAPACITY_IN_UNIT,
            VESSEL_CAPACITY_MEASURE,
            SHIP_HAS_GEAR,
            null as TYPE_OF_GEAR,
            --ICE_CLASS_CERTIFICATION_SOCIETY,
            ICE_CLASS,
            FURTHER_FEATURES,
            BUILT,
            BUILT_IN_COUNTRY,
            SHIPYARD,
            IN_CONSTRUCTION,
            ONE_YEAR_TC_RATE,
            OPEX,
            CLASS_CERTIFICATE_UNTIL,
            THE_LATEST_TECHNICAL_INSPECTION_INSTRUCTED_BY_THE_INSTITUTION,
            THE_LATEST_APPRAISED_MARKET_VALUE_WITH_CHARTERS_INCLUDED_EUR,
            THE_LATEST_APPRAISED_MARKET_VALUE_WITH_CHARTERS_INCLUDED_USD,
            EMPTY_WEIGHT_IN_LWT,
            FLAG_JURISDICTION_OF_THE_VESSEL
        from NLB.ACASA_SHIP_EZB as EZB_ACASA
        inner join CALC.SWITCH_ASSET_TO_COLLATERAL_CURRENT as A2C on trim(L '0' from EZB_ACASA.CMS_ID) = trim(L '0' from ASSET_ID) and EZB_ACASA.CUTOFFDATE <= A2C.CUT_OFF_DATE -- nur Assets aus der mapping Tabelle interessant.
    ),
    -- Vermögensobjekte aus CMS
    CMS_ASSETS as (
        select  *  from NLB.CMS_VO_CURRENT where VO_STATUS = 'Rechtlich aktiv' and VO_TYP='Schiffe'
        union all
        select * from BLB.CMS_VO_CURRENT where VO_STATUS = 'Rechtlich aktiv' and VO_TYP='Schiffe'
    ),
    ACASA_SCHIFFE(CUT_OFF_DATE, DATA_CUT_OFF_DATE, ASSET_ID, IMO_ID, VESSEL_NAME, THE_LATEST_APPRAISAL_DATE, THE_LATEST_APPRAISED_MARKET_VALUE_EUR, THE_LATEST_APPRAISED_MARKET_VALUE_USD, APPRAISER, SEGMENT, SUB_SEGMENT, VESSEL_CAPACITY_IN_UNIT, VESSEL_CAPACITY_MEASURE, SHIP_HAS_GEAR, TYPE_OF_GEAR, ICE_CLASS, FURTHER_FEATURES, BUILT, BUILT_IN_COUNTRY, SHIPYARD, IN_CONSTRUCTION, ONE_YEAR_TC_RATE, OPEX, CLASS_CERTIFICATE_UNTIL, THE_LATEST_TECHNICAL_INSPECTION_INSTRUCTED_BY_THE_INSTITUTION, THE_LATEST_APPRAISED_MARKET_VALUE_WITH_CHARTERS_INCLUDED_EUR, THE_LATEST_APPRAISED_MARKET_VALUE_WITH_CHARTERS_INCLUDED_USD, EMPTY_WEIGHT_IN_LWT, FLAG_JURISDICTION_OF_THE_VESSEL) as (
        select
            CMS.CUTOFFDATE  as CUT_OFF_DATE
            ,ACA.CUT_OFF_DATE as DATA_CUT_OFF_DATE
            ,CMS.VO_ID as ASSET_ID
            ,IMO
            ,SCHIFFSNAME
            ,GUELTIGKEITSDATUM_AKTUELLES_GUTACHTEN
            ,case
                when coalesce(ACA.MARKTWERT_ISO,'EUR') = 'EUR' then
                    DOUBLE(ACA.MARKTWERT_GUELTIG)
                else
                    DOUBLE(ACA.MARKTWERT_GUELTIG) * coalesce(CUR.RATE_TARGET_TO_EUR,1)
            end                                                         as THE_LATEST_APPRAISED_MARKET_VALUE_EUR
            ,case
                when coalesce(ACA.MARKTWERT_ISO,'EUR') = 'USD' then
                    -- ist schon in USD
                    DOUBLE(ACA.MARKTWERT_GUELTIG)
                when coalesce(ACA.MARKTWERT_ISO,'EUR') <> 'EUR' then
                    -- Umrechnung der Währung in EUR und von EUR in USD
                    DOUBLE(ACA.MARKTWERT_GUELTIG) * coalesce(CUR.RATE_TARGET_TO_EUR,1) * CUR_USD.RATE_EUR_TO_TARGET
                else
                    -- Umrechnung von EUR in USD
                    DOUBLE(ACA.MARKTWERT_GUELTIG) * CUR_USD.RATE_EUR_TO_TARGET
            end                                                         as THE_LATEST_APPRAISED_MARKET_VALUE_USD
            ,coalesce(nullif(GESELLSCHAFT_GUTACHTER,'0'),'BANK') as APPRAISER
            ,case
                when HAUPTSEGMENT = 'Sonstige' and Fein_Segment='Sonstige Segmente - Ferry/RoRo  (RoPax)' then 'FERRY'
                when HAUPTSEGMENT = 'Sonstige' and Fein_Segment='Sonstige Segmente - Kreuzfahrtschiffe - See' then 'CRUISE'
                when HAUPTSEGMENT = 'Sonstige' and Fein_Segment='Sonstige Segmente - Kühlschiffe (bis 300.000 cbft)' then 'REEFER'
                when HAUPTSEGMENT = 'Sonstige' and Fein_Segment='Sonstige Segmente - Kühlschiffe (über 300.000 cbft)' then 'REEFER'
                when HAUPTSEGMENT = 'Sonstige' and Fein_Segment='Sonstige Segmente - Pure Car & Truck Carrier (PCTC ) (4.000 - 6.000 RT)' then 'OTHER'
                when HAUPTSEGMENT = 'Sonstige' and Fein_Segment='Sonstige Segmente - Sonstige' then 'OTHER'
                when HAUPTSEGMENT like 'Multipurpose%' then 'MPP'
                when HAUPTSEGMENT = 'Gastanker' then 'TANKER_GAS'
                when HAUPTSEGMENT = 'Offshore' then 'OFFSHORE'
                when HAUPTSEGMENT = 'Container' then 'CONTAINER'
                when HAUPTSEGMENT = 'Bulker' then 'BULKER'
                when HAUPTSEGMENT = 'Offshore' then 'OFFSHORE'
                when HAUPTSEGMENT = 'Tanker' and Fein_Segment like '%Produkten%' then 'TANKER_PRODUCT'
                when HAUPTSEGMENT = 'Tanker' and Fein_Segment like '%Rohöl%' then 'TANKER_OIL'

            end as HAUPTSEGMENT
            ,FEIN_SEGMENT
            ,TEU
            ,EINHEIT
            ,case when KRAENE in ('NONE','KEINE') then 0 else 1 end as SHIP_HAS_GEAR
            ,KRAENE as TYPE_OF_GEAR
            ,case
                when EISKLASSE = 'Keine Eisklasse'      then 'NO_ICE_CLASS'
                when EISKLASSE = 'Einfache Eisklasse'   then 'CATEGORY_II'
                when EISKLASSE = 'Standard Eisklasse'   then 'IC'
                when EISKLASSE = 'Mittlere Eisklasse'   then 'IB'
                when EISKLASSE = 'Hohe Eisklasse'       then 'IA'
                when EISKLASSE = 'Höchste Eisklasse'    then 'IA_SUPER'
                else EISKLASSE
            end as EISKLASSE
            ,nullif(coalesce(concat('Gear: ',case when KRAENE in ('NONE','KEINE') then NULL else KRAENE end),'') || case when REEFER_ANSCHLUESSE = 0 or KRAENE in ('NONE','KEINE') then '' else ', ' end || coalesce(concat('Reefer: ',nullif(REEFER_ANSCHLUESSE,0)),''),'') as FURTHER_FEATURES
            ,BAUDATUM as BUILD
            ,B.COUNTRY_CODE as BUILD_IN_COUTRY_CODE
            ,case when locate_in_string(WERFT,',') > 0 then trim(left(WERFT,locate_in_string(WERFT,',')-1)) else WERFT end as SHIPYARD
            ,case when FERTIGSTELLUNGSGRAD_IN_PROZENT < 100 then 1 else 0 end as IN_CONSTRUCTION
            ,TIMECHARTER_RATE_GUELTIG_IN_USD_JE_DAY  as ONE_YEAR_TC_RATE
            ,OPEX_GUELTIG_IN_USD_JE_DAY
            ,DATUM_KLASSE as CLASS_CERTIFICATE_UNTIL
            ,BESICHTIGUNGSDATUM
            ,NULL as THE_LATEST_APPRAISED_MARKET_VALUE_WITH_CHARTERS_INCLUDED_EUR
            ,NULL as THE_LATEST_APPRAISED_MARKET_VALUE_WITH_CHARTERS_INCLUDED_USD
            ,LEERGEWICHT as EMPTY_WEIGHT_IN_LWT
            ,R.COUNTRY_CODE as FLAGGENSTAAT_CODE
            --,MARKTWERT_ISO
            --,AUFTRAGSNUMMER_GUELTIG
            --,WERFT
            --,trim(substr(WERFT,locate_in_string(WERFT,',')+1)) as BUILT_IN_COUNTR
            --,TRAGFAEHIGKEIT
            --,FLAGGENSTAAT
            --,REEFER_ANSCHLUESSE
            --,KRAENE
            -- ,trim(substr(WERFT,locate_in_string(WERFT,',')+1)) as BUILT_IN_COUNTRY
        from NLB.ACASA_SCHIFF as ACA
        left join SMAP.COUNTRY_CODE_MAP as B on Upper(B.COUNTRY_NAME) = UPPER(trim(substr(ACA.WERFT,locate_in_string(ACA.WERFT,',')+1)))
        left join SMAP.COUNTRY_CODE_MAP as R on Upper(R.COUNTRY_NAME) = UPPER(trim(ACA.FLAGGENSTAAT))
        left join IMAP.CURRENCY_MAP as CUR on CUR.CUT_OFF_DATE = ACA.CUT_OFF_DATE and coalesce(ACA.MARKTWERT_ISO,'EUR') = CUR.ZIEL_WHRG
        left join IMAP.CURRENCY_MAP as CUR_USD on CUR_USD.CUT_OFF_DATE = ACA.CUT_OFF_DATE and 'USD' = CUR_USD.ZIEL_WHRG
        inner join CMS_ASSETS as CMS on CMS.CUTOFFDATE >= ACA.CUT_OFF_DATE and ACA.IMO = CMS.VO_SHP_IMO
        /*
        select distinct
        --ICE_CLASS,EISKLASSE,
        FLAGGENSTAAT,FLAG_JURISDICTION_OF_THE_VESSEL
        --,IMO
        from NLB.ACASA_SHIP_EZB as A
        left join NLB.ACASA_SCHIFF on IMO_ID=IMO
        where A.CUTOFFDATE = '30.09.2019'

        select distinct
        --SEGMENT,HAUPTSEGMENT
        ICE_CLASS,EISKLASSE
        --FLAGGENSTAAT,FLAG_JURISDICTION_OF_THE_VESSEL
        --,IMO
        from NLB.ACASA_SCHIFF as B
        left join NLB.ACASA_SHIP_EZB as A on IMO_ID=IMO
        where A.CUTOFFDATE = '30.09.2019'

         */
    ),
    EZB_SCHIFFE_TAPE as (
        select *
        from (
            select *,
                 ROW_NUMBER() over (PARTITION BY ASSET_ID,CUT_OFF_DATE ORDER BY DATA_CUT_OFF_DATE desc) AS nbr
            from (
                select A.* from PRE_EZB_SCHIFFE_TAPE as A
                   union all
                select A.* from ACASA_SCHIFFE  as A
                )
             )
        where NBR = 1
    )
    ,
    SHIP_ADDITIONAL_FIELDS as (
        select * from NLB.SHIP_ADDITIONAL_FIELDS
        union all
        select * from ANL.SHIP_ADDITIONAL_FIELDS
        union all
        select * from BLB.SHIP_ADDITIONAL_FIELDS
    ),
    ASSET_PORTFOLIO as (
        select distinct CUT_OFF_DATE, ASSET_ID, BRANCH from CALC.SWITCH_ASSET_TO_COLLATERAL_CURRENT
    ),
    data as (
        select distinct
                    CMS_ASSET.CUTOFFDATE                                                                         as CUT_OFF_DATE,
                    EZB_TAPE.DATA_CUT_OFF_DATE                                                                   as APPRAISER_DATA_CUT_OFF_DATE,
                    VO_ID                                                                                        as ASSET_ID,
                    VO_TYP                                                                                       as ASSET_TYPE,
                    VO_ART                                                                                       as ASSET_DESCRIPTION,
                    A2C.BRANCH                                                                                   as BRANCH,
                    strip(VO_SHP_IMO, L, '0')                                                                    as SHIP_IMO_NUMBER,
                    coalesce(SHIP_CLASS_MAPPING.SHIPTYPECLASS, ACASA_ASSET.SHIPTYPECLASS,
                             VO_SHP_TYPKLASSE)                                                                   as SHIP_TYPE_CLASS,
                    case
                        when VO_TYP in ('Schiffe', 'Schiff', 'Flugzeuge', 'Flugzeug', 'Triebwerk') then
                            round(DOUBLE(VO_ANZUS_WERT) * coalesce(RATE_ASSESSMENT_CURRENCY.RATE_TARGET_TO_EUR, 1), 2)
                        else
                            round(DOUBLE(VO_NOMINAL_WERT) * coalesce(RATE_NOMINAL_CURRENCY.RATE_TARGET_TO_EUR, 1), 2)
                        end                                                                                      as SHIP_MARKET_VALUE_EUR,
                    coalesce(VO_SHP_AUSLIEFERUNGSDATUM, ADDITIONAL_FIELDS.BUILT)                                 as SHIP_HANDOVER_DATE,
                    timestampdiff(256, timestamp(CMS_ASSET.CUTOFFDATE) - timestamp(
                            coalesce(EZB_TAPE.BUILT, ADDITIONAL_FIELDS.BUILT, VO_SHP_AUSLIEFERUNGSDATUM,
                                     DATE(CMS_ASSET.CUTOFFDATE))))                                               as SHIP_AGE,
                    coalesce(nullif(EZB_TAPE.VESSEL_NAME, 'MISS'), CMS_ASSET.VO_SHP_SCHIFFSNAME, HAGE_ALI_DETAILS.VESSEL_NAME,
                             ADDITIONAL_FIELDS.SHIP_NAME
                            )                                                       as SHIP_VESSEL_NAME,
                    coalesce(nullif(EZB_TAPE.SEGMENT, 'MISS'), HAGE_ALI_DETAILS.TYPE_OF_VESSEL_SEGMENT,
                             SHIP_CLASS_MAPPING.HAUPTSEGMENT)                                                    as SHIP_TYPE_OF_VESSEL_SEGMENT,
                    coalesce(nullif(EZB_TAPE.SUB_SEGMENT, 'MISS'),
                             HAGE_ALI_DETAILS.TYPE_OF_VESSEL_SUB_SEGMENT)                                        as SHIP_TYPE_OF_VESSEL_SUB_SEGMENT,
                    coalesce(EZB_TAPE.SHIP_HAS_GEAR, HAGE_ALI_DETAILS.HAS_GEAR)                                  as SHIP_HAS_GEAR,
                    coalesce(EZB_TAPE.TYPE_OF_GEAR, HAGE_ALI_DETAILS.TYPE_OF_GEAR)                               as TYPE_OF_GEAR,
                    coalesce(EZB_TAPE.ICE_CLASS, HAGE_ALI_DETAILS.ICE_CLASS,
                             ADDITIONAL_FIELDS.ICE_CLASS)                                                        as SHIP_ICE_CLASS,
                    coalesce(EZB_TAPE.BUILT, HAGE_ALI_DETAILS.VESSEL_DELIVERED)                                  as SHIP_VESSEL_DELIVERED,
                    coalesce(EZB_TAPE.SHIPYARD, HAGE_ALI_DETAILS.SHIPYARD)                                       as SHIP_SHIPYARD,
                    coalesce(EZB_TAPE.BUILT_IN_COUNTRY,
                             HAGE_ALI_DETAILS.COUNTRY_OF_YARD)                                                   as SHIP_COUNTRY_OF_YARD,
                    coalesce(EZB_TAPE.FLAG_JURISDICTION_OF_THE_VESSEL,
                             HAGE_ALI_DETAILS.REGISTRY_JURISDICTION_OF_THE_VESSEL)                               as SHIP_REGISTRY_JURISDICTION_OF_THE_VESSEL,
                    coalesce(EZB_TAPE.EMPTY_WEIGHT_IN_LWT,
                             HAGE_ALI_DETAILS.EMPTY_WEIGHT_IN_LWT)                                               as EMPTY_WEIGHT_IN_LWT,
                    coalesce(EZB_TAPE.VESSEL_CAPACITY_IN_UNIT, HAGE_ALI_DETAILS.CAPACITY,
                             ADDITIONAL_FIELDS.VESSEL_CAPACITY_IN_UNIT)                                          as SHIP_CAPACITY,
                    coalesce(EZB_TAPE.VESSEL_CAPACITY_MEASURE, HAGE_ALI_DETAILS.CAPACITY_UNIT,
                             ADDITIONAL_FIELDS.VESSEL_CAPACITY_MEASURE)                                          as SHIP_CAPACITY_UNIT,
                    coalesce(EZB_TAPE.IN_CONSTRUCTION,
                             translate(ADDITIONAL_FIELDS.IN_CONSTRUCTION, '10', 'YN'))                           as SHIP_IN_CONSTRUCTIPON,
                    EZB_TAPE.FURTHER_FEATURES                                                                    as SHIP_ADDITIONAL_FEATURES,
                    case
                        when EZB_TAPE.CLASS_CERTIFICATE_UNTIL < CMS_ASSET.CUTOFFDATE then 0
                        else 1 end                                                                               as CLASS_CERTIFICATE_UNTILL,
                    coalesce(EZB_TAPE.OPEX, HAGE_ALI_DETAILS.OPEX_USD,
                             ADDITIONAL_FIELDS.OPEX)                                                             as SHIP_OPEX_USD,
                    coalesce(EZB_TAPE.THE_LATEST_TECHNICAL_INSPECTION_INSTRUCTED_BY_THE_INSTITUTION,
                             HAGE_ALI_DETAILS.THE_LATEST_TECHNICAL_INSPECTION_INSTRUCTED_BY_THE_BANK)            as SHIP_THE_LATEST_TECHNICAL_INSPECTION_INSTRUCTED_BY_THE_BANK,
                    coalesce(EZB_TAPE.THE_LATEST_APPRAISAL_DATE,
                             HAGE_ALI_DETAILS.LATEST_VALUATION_DATE)                                             as SHIP_LATEST_VALUATION_DATE,
                    coalesce(EZB_TAPE.APPRAISER, HAGE_ALI_DETAILS.APPRAISER,
                             ADDITIONAL_FIELDS.APPRAISER)                                                        as SHIP_APPRAISER,
                    coalesce(EZB_TAPE.THE_LATEST_APPRAISED_MARKET_VALUE_WITH_CHARTERS_INCLUDED_USD,
                             EZB_TAPE.THE_LATEST_APPRAISED_MARKET_VALUE_USD, HAGE_ALI_DETAILS.VALUE_OF_LATEST_VALUATION
                             )                                         as SHIP_VALUE_OF_LATEST_VALUATION_USD,
                    coalesce(IWHS_KUNDE.BORROWERNAME, CMS_ASSET.VO_SHP_CHARTERNAME, HAGE_ALI_DETAILS.CHARTERER,
                             ADDITIONAL_FIELDS.CHARTERER_NAME)                                                   as SHIP_CHARTERER,
                    coalesce(ADDITIONAL_FIELDS.CHARTERERS_EXTERNAL_RATING, NULL)                                 as SHIP_CHARTERERS_EXTERNAL_RATING, --todo: hier muss das rating hin
                    coalesce(SHIP_SPECIFICS.CHARTER_SINCE,
                             HAGE_ALI_DETAILS.CHARTER_BEGIN)                                                     as SHIP_CHARTER_BEGIN,
                    coalesce(SHIP_SPECIFICS.CHARTER_TO, HAGE_ALI_DETAILS.CHARTER_END)                            as SHIP_CHARTER_END,
                    coalesce(SHIP_SPECIFICS.CHARTER_RATE, HAGE_ALI_DETAILS.CHARTER_RATE)                         as SHIP_CHARTER_RATE_USD,
                    EZB_TAPE.ONE_YEAR_TC_RATE                                                                    as SHIP_ONE_YEAR_TC_RATE_MARKET_QUOTE_USD,
                    coalesce(SHIP_SPECIFICS.EMPLOYMENT_TYPE,
                             HAGE_ALI_DETAILS.CHARTER_TYPE)                                                      as CHARTER_TYPE,
                    coalesce(TRANSLATE(SHIP_SPECIFICS.VESSEL_LAY_UP, '10', 'YN'), HAGE_ALI_DETAILS.LAY_UP,
                             TRANSLATE(ADDITIONAL_FIELDS.VESSEL_LAY_UP, '10', 'YN'))                             as SHIP_LAY_UP,
                    coalesce(SHIP_SPECIFICS.LAY_UP_SINCE, ADDITIONAL_FIELDS.LAY_UP_SINCE,
                             HAGE_ALI_DETAILS.LAY_UP_SINCE)                                                      as SHIP_LAY_UP_SINCE,
                    --HAGE_ALI_DETAILS.SYNDICATION_SHARE_IN_VESSEL_INCOME                                          as SYNDICATION_SHARE_IN_VESSEL_INCOME,
                    --coalesce(HAGE_ALI_DETAILS.DRY_DOCKING_DATE, NULL)                                            as DRY_DOCKING_DATE,
                    APPRAISER.IMO_ODER_KUNDENNUMMER,
                    BESICHTIGUNGSDATUM,
                    ABSCHLAG,
                    MARKTWERT_GUELTIG,
                    CURRENCY,
                    APPRAISER.SHIP_APPRAISER_1,
                    APPRAISER.SHIP_APPRAISER_TYPE_1,
                    APPRAISER.SHIP_APPRAISER_VALUE_1,
                    APPRAISER.SHIP_APPRAISER_QUOTA_1,
                    APPRAISER.SHIP_APPRAISER_GEWICHTUNG_1,
                    APPRAISER.SHIP_APPRAISER_INDEXIERUNG_1,
                    APPRAISER.SHIP_APPRAISER_2,
                    APPRAISER.SHIP_APPRAISER_TYPE_2,
                    APPRAISER.SHIP_APPRAISER_VALUE_2,
                    APPRAISER.SHIP_APPRAISER_QUOTA_2,
                    APPRAISER.SHIP_APPRAISER_GEWICHTUNG_2,
                    APPRAISER.SHIP_APPRAISER_INDEXIERUNG_2,
                    APPRAISER.SHIP_APPRAISER_3,
                    APPRAISER.SHIP_APPRAISER_TYPE_3,
                    APPRAISER.SHIP_APPRAISER_VALUE_3,
                    APPRAISER.SHIP_APPRAISER_QUOTA_3,
                    APPRAISER.SHIP_APPRAISER_GEWICHTUNG_3,
                    APPRAISER.SHIP_APPRAISER_INDEXIERUNG_3,
                    APPRAISER.SHIP_APPRAISER_4,
                    APPRAISER.SHIP_APPRAISER_TYPE_4,
                    APPRAISER.SHIP_APPRAISER_VALUE_4,
                    APPRAISER.SHIP_APPRAISER_QUOTA_4,
                    APPRAISER.SHIP_APPRAISER_GEWICHTUNG_4,
                    APPRAISER.SHIP_APPRAISER_INDEXIERUNG_4,
                    APPRAISER.SHIP_APPRAISER_5,
                    APPRAISER.SHIP_APPRAISER_TYPE_5,
                    APPRAISER.SHIP_APPRAISER_VALUE_5,
                    APPRAISER.SHIP_APPRAISER_QUOTA_5,
                    APPRAISER.SHIP_APPRAISER_GEWICHTUNG_5,
                    APPRAISER.SHIP_APPRAISER_INDEXIERUNG_5,
                    APPRAISER.SHIP_APPRAISER_6,
                    APPRAISER.SHIP_APPRAISER_TYPE_6,
                    APPRAISER.SHIP_APPRAISER_VALUE_6,
                    APPRAISER.SHIP_APPRAISER_QUOTA_6,
                    APPRAISER.SHIP_APPRAISER_GEWICHTUNG_6,
                    APPRAISER.SHIP_APPRAISER_INDEXIERUNG_6,                                                                                                    --
                    Current USER                                                                                 as CREATED_USER,                    -- Letzter Nutzer, der dieses Tape gebaut hat.
                    Current TIMESTAMP                                                                            as CREATED_TIMESTAMP                -- Neuester Zeitstempel, wann dieses Tape zuletzt gebaut wurde.
    from CMS_ASSETS                                         as CMS_ASSET
             --inner join AMC.TAPE_SHIP_ASSET_TO_COLLATERAL_CURRENT as A2C
             inner join ASSET_PORTFOLIO                     as A2C
                                                                on CMS_ASSET.VO_ID = A2C.ASSET_ID
                                                               and A2C.CUT_OFF_DATE = CMS_ASSET.CUTOFFDATE
             left join IMAP.CURRENCY_MAP                    as RATE_NOMINAL_CURRENCY
                                                                on CMS_ASSET.VO_NOMINAL_WERT_WAEHR = RATE_NOMINAL_CURRENCY.ZIEL_WHRG
                                                               and CMS_ASSET.CUTOFFDATE = RATE_NOMINAL_CURRENCY.CUT_OFF_DATE
             left join IMAP.CURRENCY_MAP                    as RATE_ASSESSMENT_CURRENCY
                                                                on CMS_ASSET.VO_ANZUS_WERT_WAEHR = RATE_ASSESSMENT_CURRENCY.ZIEL_WHRG
                                                               and CMS_ASSET.CUTOFFDATE = RATE_ASSESSMENT_CURRENCY.CUT_OFF_DATE
             left join NLB.ACASA_SCHIFF_VERMOEGENSWERT      as ACASA_ASSET
                                                                on bigint(CMS_ASSET.VO_SHP_IMO) = bigint(replace(ACASA_ASSET.SHIPIMONUMBER, '(ENI)', ''))
                                                               and CMS_ASSET.CUTOFFDATE = ACASA_ASSET.CUTOFFDATE
             left join SMAP.LANG_SHIP_TYPE_CLASS_MAP        as SHIP_CLASS_MAPPING
                                                                on coalesce(ACASA_ASSET.SHIPTYPECLASS, VO_SHP_TYPKLASSE) = SHIP_CLASS_MAPPING.SHP_TYPKLASSE
             left join NLB.SCHIFFE_DETAILS_HAGE_ALI         as HAGE_ALI_DETAILS
                                                                on lpad(HAGE_ALI_DETAILS.VESSEL_ID, 10, '0') = lpad(VO_SHP_IMO, 10, '0')
                                                               and CMS_ASSET.CUTOFFDATE < '31.12.2018'
             left join SHIP_ADDITIONAL_FIELDS               as ADDITIONAL_FIELDS
                                                                on lpad(ADDITIONAL_FIELDS.SHIP_IMO_NUMBER, 10, '0') = lpad(VO_SHP_IMO, 10, '0')
             left join EZB_SCHIFFE_TAPE                     as EZB_TAPE
                                                                on EZB_TAPE.ASSET_ID = VO_ID
                                                               and EZB_TAPE.CUT_OFF_DATE = CMS_ASSET.CUTOFFDATE -- Match über aktuelles CUT_OFF_DATE und nicht das DATA_CUT_OFF_DATE, da ACASA_SHIP_EZB ist nicht immer up to date
             left join NLB.SPECIFICS_SCHIFFE_FULL_LENGTH    as SHIP_SPECIFICS
                                                                on SHIP_SPECIFICS.IMO_ID = trim(L '0' from CMS_ASSET.VO_SHP_IMO)
                                                               and SHIP_SPECIFICS.CUTOFFDATE = CMS_ASSET.CUTOFFDATE
                                                               and SHIP_SPECIFICS.CMS_VO_ID is not null
             left join APPRAISER                            as APPRAISER
                                                                on APPRAISER.IMO_ODER_KUNDENNUMMER = trim(L '0' from VO_SHP_IMO)
                                                               and APPRAISER.CUTOFFDATE = CMS_ASSET.CUTOFFDATE
             left join NLB.IWHS_KUNDE_CURRENT               as IWHS_KUNDE
                                                                on IWHS_KUNDE.CUTOFFDATE = CMS_ASSET.CUTOFFDATE
                                                               and SHIP_SPECIFICS.CHARTERER_KUNDENNUMMER = IWHS_KUNDE.BORROWERID
    --where VO_STATUS = 'Rechtlich aktiv'
)
select * from data
;

-- CI START FOR ALL TAPES
-- Current-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_MARITIME_ASSET_CURRENT');
create table AMC.TABLE_MARITIME_ASSET_CURRENT like CALC.VIEW_MARITIME_ASSET distribute by hash(ASSET_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_MARITIME_ASSET_CURRENT_ASSET_ID on AMC.TABLE_MARITIME_ASSET_CURRENT (ASSET_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_MARITIME_ASSET_CURRENT');
-- Archiv-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_MARITIME_ASSET_ARCHIVE');
create table AMC.TABLE_MARITIME_ASSET_ARCHIVE like AMC.TABLE_MARITIME_ASSET_CURRENT distribute by hash(ASSET_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2025' EVERY 1 MONTH) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_MARITIME_ASSET_ARCHIVE_ASSET_ID on AMC.TABLE_MARITIME_ASSET_ARCHIVE (ASSET_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_MARITIME_ASSET_ARCHIVE');
-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_MARITIME_ASSET_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_MARITIME_ASSET_ARCHIVE');
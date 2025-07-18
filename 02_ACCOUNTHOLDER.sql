-- View erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_CLIENT_ACCOUNTHOLDER;
create or replace view CALC.VIEW_CLIENT_ACCOUNTHOLDER as
with
    CLIENT_KONZERN as ( -- aus KNDB, Konzern-Zugehörigkeit
        select CUTOFFDATE as CUT_OFF_DATE, BRANCH, KND_NR as CLIENT_NO, KONZERN_NR, KONZERN_BEZ as KONZERN_BEZEICHNUNG
        from NLB.KN_KNE_CURRENT
        union all
        select CUTOFFDATE as CUT_OFF_DATE, BRANCH, KND_NR as CLIENT_NO, KONZERN_NR, KONZERN_BEZ as KONZERN_BEZEICHNUNG
        from BLB.KN_KNE_CURRENT
        union all
        select CUTOFFDATE as CUT_OFF_DATE, BRANCH, KND_NR as CLIENT_NO, KONZERN_NR, KONZERN_BEZ as KONZERN_BEZEICHNUNG
        from ANL.KN_KNE_CURRENT
    ),
    CLIENT_ZO as(
        select ZO.CUTOFFDATE as CUT_OFF_DATE, ZO.BRANCH, ZO.PARTNER_C072 as PARTNER_NO, ZO.KREDITNEHMEREINHEIT_SAP,ZO.BBK_KREDITNEHMER, ZO.B913
        from BLB.ZO_KUNDE_CURRENT as ZO
        union all
        select ZO.CUTOFFDATE as CUT_OFF_DATE, ZO.BRANCH, ZO.PARTNER_C072 as PARTNER_NO, ZO.KREDITNEHMEREINHEIT_SAP,ZO.BBK_KREDITNEHMER, ZO.B913
        from ANL.ZO_KUNDE_CURRENT as ZO
                 union all
        select ZO.CUTOFFDATE as CUT_OFF_DATE, ZO.BRANCH, ZO.PARTNER_C072 as PARTNER_NO, ZO.KREDITNEHMEREINHEIT_SAP,ZO.BBK_KREDITNEHMER, ZO.B913
        from NLB.ZO_KUNDE_CURRENT as ZO
    ),
    CLIENT_IWHS as (
        select CUTOFFDATE as CUT_OFF_DATE, BRANCH as BRANCH_BORROWER, BORROWERID as BORROWER_NO, BORROWERNAME, COUNTRY, NACE, LEGALFORM, OE_BEZEICHNUNG, SERVICE_OE_BEZEICHNUNG, PERSONTYPE, ZUGRIFFSSCHUTZ
        from NLB.IWHS_KUNDE_CURRENT
        union all
        select CUTOFFDATE as CUT_OFF_DATE, BRANCH as BRANCH_BORROWER, BORROWERID as BORROWER_NO, BORROWERNAME, COUNTRY, NACE, LEGALFORM, OE_BEZEICHNUNG, SERVICE_OE_BEZEICHNUNG, PERSONTYPE, ZUGRIFFSSCHUTZ
        from BLB.IWHS_KUNDE_CURRENT
        union all
        select CUTOFFDATE as CUT_OFF_DATE, BRANCH as BRANCH_BORROWER, BORROWERID as BORROWER_NO, BORROWERNAME, COUNTRY, NACE, LEGALFORM, OE_BEZEICHNUNG, SERVICE_OE_BEZEICHNUNG, PERSONTYPE, ZUGRIFFSSCHUTZ
        from ANL.IWHS_KUNDE_CURRENT
    ),
    BORROWER_GROUPS as (
        select distinct
            DATA.BRANCH,
            DATA.CLIENT_ID,
            DATA.KONZERN_ID,
            DATA.KONZERN_BEZEICHNUNG,
            DATA.GVK_BUNDESBANKNUMMER,
            DATA.CUT_OFF_DATE
            from (
                  select PORTFOLIO.BRANCH_FACILITY                                        AS BRANCH
                       , PORTFOLIO.BRANCH_CLIENT || '_' || PORTFOLIO.CLIENT_NO            AS CLIENT_ID
                       , KN.BRANCH || '_' || KN.KONZERN_NR                                AS KONZERN_ID
                       , KN.KONZERN_BEZEICHNUNG as KONZERN_BEZEICHNUNG
                       , BBK_KREDITNEHMER                                       as GVK_BUNDESBANKNUMMER
                       , PORTFOLIO.CUT_OFF_DATE                                       as CUT_OFF_DATE
                  from CALC.SWITCH_PORTFOLIO_CURRENT as PORTFOLIO
                  left join CLIENT_KONZERN as KN on (KN.CUT_OFF_DATE,KN.CLIENT_NO,KN.BRANCH) = (PORTFOLIO.CUT_OFF_DATE,PORTFOLIO.CLIENT_NO,PORTFOLIO.BRANCH_CLIENT)
                  left join CLIENT_ZO as ZO on (ZO.CUT_OFF_DATE,ZO.PARTNER_NO,ZO.BRANCH) = (PORTFOLIO.CUT_OFF_DATE,PORTFOLIO.CLIENT_NO,PORTFOLIO.BRANCH_CLIENT)
              ) as DATA
    ),
     -- Bilanzdaten für einzelne Kundennummern NLB und BLB
    BILANZDATEN as (
        select * from (
        select KUNDENNUMMER,EBITDA_9320,UMSATZERLOESE_4000_1,A_O_AUFWAND_3670,SONSTIGER_AUFWAND_3240,BILANZSTICHTAG,WAEHRUNG, row_number() over (partition by KUNDENNUMMER order by BILANZSTICHTAG desc) as NBR,'NLB' as BRANCH
        from NLB.GLOBAL_FORMAT_KUNDENDATEN
                      ) where NBR = 1

        union all
        select * from (
        select KUNDENKISNR, EBITDA,GESAMTKAPITALUMSCHLAG,BETRIEBSAUFWAND,BETRIEBSAUFWANDSONST,BILANZSTICHTAG,WAEHRUNG,row_number() over (partition by KUNDENKISNR order by BILANZSTICHTAG desc) as NBR,'NLB' as BRANCH
        from NLB.EBIL_KUNDENDATEN
                      ) where NBR = 1

        union all
        select * from (
        select KUNDENKISNR, EBITDA,GESAMTKAPITALUMSCHLAG,BETRIEBSAUFWAND,BETRIEBSAUFWANDSONST,BILANZSTICHTAG,WAEHRUNG,row_number() over (partition by KUNDENKISNR order by BILANZSTICHTAG desc) as NBR,'BLB' as BRANCH
        from BLB.EBIL_KUNDENDATEN
                      ) where NBR = 1
    ),
    -- Kunden Basisdaten
    BASIS as (
        select distinct
            BRANCH_CLIENT || '_' ||  CLIENT_NO  as CLIENT_ID    -- Kundennummer im Format BRANCH_Kundennummer
            ,CLIENT_NO                          as CLIENT_NO -- Kundennummer als Zahl
            ,CLIENT_ID_ORIG                                     -- original Kundennummer (CBB Kundennummer, falls von CBB in NLB übersetzt)
            ,CLIENT_ID_LEADING
            ,CLIENT_ID_ALT                                      -- alternative uns bekannte Kundennummern
            ,BRANCH_CLIENT                      as BRANCH       -- Institut des Kunden (passend zu CLIENT_ID_NO, nicht CLIENT_ID_ORIG!)
            ,PORTFOLIO.CUT_OFF_DATE             as CUT_OFF_DATE -- Stichtag (gemappt)
        from CALC.SWITCH_PORTFOLIO_CURRENT as PORTFOLIO
    ),
    CMS_LINK as (
        select distinct
            GW_PARTNER                          as CLIENT_ID
            ,MRISK_GESSICHW_KN                  as MRISK_GESSICHW
            ,ARISK_GESSICHW_KN                  as ARISK_GESSICHW
            ,RISK_GESSIW_KN_WAEHR               as RISK_GESSIW_WAEHR
            ,CUTOFFDATE                         as CUT_OFF_DATE
        from CALC.SWITCH_NLB_CMS_LINK_REPLACEMENT_CURRENT
        --Replacement aus issue #678
         union all
         select distinct
            GW_PARTNER                          as CLIENT_ID
            ,MRISK_GESSICHW_KN                  as MRISK_GESSICHW
            ,ARISK_GESSICHW_KN                  as ARISK_GESSICHW
            ,RISK_GESSIW_KN_WAEHR               as RISK_GESSIW_WAEHR
            ,CUTOFFDATE                         as CUT_OFF_DATE
        from CALC.SWITCH_BLB_CMS_LINK_REPLACEMENT_CURRENT
         --Replacement aus issue #678
     ),
     RATING as (
         select distinct
                         GP_NR
                         ,RATING_ID
                         ,SUBMODUL
                         ,'NLB' as Branch
                        ,CUT_OFF_DATE
         from NLB.SPOT_RATING_GESCHAEFTSPARTNER_CURRENT
         union all
         select distinct GP_NR
                         ,RATING_ID
                         ,SUBMODUL
                         ,'BLB' as Branch
                        ,CUT_OFF_DATE
         from BLB.SPOT_RATING_GESCHAEFTSPARTNER_CURRENT
     ),
     -- FACILITY_ACCOUNTHOLDER DATEN
     FACILITY_ACC as (
           select *
           from CALC.SWITCH_CLIENT_ACCOUNTHOLDER_FACILITY_CURRENT
     ),
     DONE_PRODUCT as (
        select distinct
            BASIS.CUT_OFF_DATE
            ,BASIS.BRANCH
            ,BASIS.CLIENT_ID
            ,BASIS.CLIENT_NO
            ,BASIS.CLIENT_ID_ORIG
            ,BASIS.CLIENT_ID_LEADING
            ,BASIS.CLIENT_ID_ALT
            ,IWHS.BORROWERNAME as BORROWERNAME
            ,IWHS.PERSONTYPE as CLIENT_TYPE
            ,case
                when upper(IWHS.PERSONTYPE) in ('N','P') then -- Privatperson/ Natürliche Person
                    cast(hex(hash(IWHS.BORROWERNAME,2)) as VARCHAR)
                when upper(IWHS.OE_BEZEICHNUNG) like '%MITARBEITER%' then
                    cast(hex(hash(IWHS.BORROWERNAME,2)) as VARCHAR) -- 2 = sha 256
                when upper(IWHS.OE_BEZEICHNUNG) like '%VORSTAND%' then
                    cast(hex(hash(IWHS.BORROWERNAME,2)) as VARCHAR)
                when upper(IWHS.OE_BEZEICHNUNG) like '%SINGAPUR%' then
                    cast(hex(hash(IWHS.BORROWERNAME,2)) as VARCHAR)
                when upper(IWHS.SERVICE_OE_BEZEICHNUNG) like '%MITARBEITER%' then
                    cast(hex(hash(IWHS.BORROWERNAME,2)) as VARCHAR)
                when upper(IWHS.SERVICE_OE_BEZEICHNUNG) like '%VORSTAND%' then
                    cast(hex(hash(IWHS.BORROWERNAME,2)) as VARCHAR)
                when upper(IWHS.SERVICE_OE_BEZEICHNUNG) like '%SINGAPUR%' then
                    cast(hex(hash(IWHS.BORROWERNAME,2)) as VARCHAR)
                when IWHS.ZUGRIFFSSCHUTZ then
                    cast(hex(hash(IWHS.BORROWERNAME,2)) as VARCHAR)
                else
                    IWHS.BORROWERNAME
            end as CLIENT_NAME_ANONYMIZED
            ,case
                when upper(IWHS.PERSONTYPE) in ('N','P') then -- Privatperson/ Natürliche Person
                    cast(hex(hash(borrower_groups.KONZERN_BEZEICHNUNG,2)) as VARCHAR)
                when upper(IWHS.OE_BEZEICHNUNG) like '%MITARBEITER%' then
                    cast(hex(hash(borrower_groups.KONZERN_BEZEICHNUNG,2)) as VARCHAR) -- 2 = sha 256
                when upper(IWHS.OE_BEZEICHNUNG) like '%VORSTAND%' then
                    cast(hex(hash(borrower_groups.KONZERN_BEZEICHNUNG,2)) as VARCHAR)
                when upper(IWHS.OE_BEZEICHNUNG) like '%SINGAPUR%' then
                    cast(hex(hash(borrower_groups.KONZERN_BEZEICHNUNG,2)) as VARCHAR)
                when upper(IWHS.SERVICE_OE_BEZEICHNUNG) like '%MITARBEITER%' then
                    cast(hex(hash(borrower_groups.KONZERN_BEZEICHNUNG,2)) as VARCHAR)
                when upper(IWHS.SERVICE_OE_BEZEICHNUNG) like '%VORSTAND%' then
                    cast(hex(hash(borrower_groups.KONZERN_BEZEICHNUNG,2)) as VARCHAR)
                when upper(IWHS.SERVICE_OE_BEZEICHNUNG) like '%SINGAPUR%' then
                    cast(hex(hash(borrower_groups.KONZERN_BEZEICHNUNG,2)) as VARCHAR)
                when IWHS.ZUGRIFFSSCHUTZ then
                    cast(hex(hash(borrower_groups.KONZERN_BEZEICHNUNG,2)) as VARCHAR)
                else
                    borrower_groups.KONZERN_BEZEICHNUNG
            end as KONZERN_BEZEICHNUNG_ANONYMIZED
            ,borrower_groups.KONZERN_ID as KONZERN_ID
            ,borrower_groups.KONZERN_BEZEICHNUNG as KONZERN_BEZEICHNUNG
            ,borrower_groups.GVK_BUNDESBANKNUMMER as GVK_BUNDESBANKNUMMER
            ,coalesce(IWHS.NACE,left(CBB.NACE,10)) as NACE
            ,IWHS.COUNTRY
            ,coalesce(LA.COUNTRY_APLHA2,left(CBB.COUNTRY,10)) as COUNTRY_APLHA2
            ,coalesce(IWHS.LEGALFORM,left(CBB.LEGAL_FORM,10)) as LEGALFORM
            ,coalesce(BIL.EBITDA_9320,left(CBB.CLIENT_EBITDA_EUR,10)) as EBITDA
            ,BIL.UMSATZERLOESE_4000_1 as REVENUE
            ,BIL.A_O_AUFWAND_3670 as OPERATING_EXPENSES
            ,BIL.SONSTIGER_AUFWAND_3240 as OTHER_EXPENSES
            ,case when CBB.CLIENT_ID is not nULL then 'EUR' else BIL.WAEHRUNG end as CLIENT_BALANCE_SHEET_CURRENCY
            ,BIL.BILANZSTICHTAG as CLIENT_BALANCE_SHEET_DATE
            ,row_number() over(partition by BASIS.CLIENT_ID_ORIG,BASIS.CUT_OFF_DATE) as NBR
            ,CMS.ARISK_GESSICHW
            ,CMS.MRISK_GESSICHW
            ,CMS.RISK_GESSIW_WAEHR
            ,RATING.RATING_ID   as RATING_ID
            ,RATING.SUBMODUL as RATING_MODUL
            ,ACC_FACILITY.SAP_EAD_SUMME
            ,ACC_FACILITY.SAP_EL_SUMME
            ,ACC_FACILITY.SAP_INANSPRUCHNAHME_SUMME
            ,ACC_FACILITY.SAP_INANSPRUCHNAHME_AZ6_SUMME
            ,ACC_FACILITY.SAP_INANSPRUCHNAHME_AVAL_SUMME
            ,ACC_FACILITY.SAP_BLANKO_SUMME
            ,ACC_FACILITY.SAP_FREILINIE_SUMME
            ,ACC_FACILITY.FORDERUNG_SUMME
            ,ACC_FACILITY.FORDERUNGAVAL_SUMME
            ,ACC_FACILITY.FORDERUNG_K028_SUMME
            ,ACC_FACILITY.FORDERUNG_RSMMARKETS_SUMME
            ,ACC_FACILITY.GUTHABEN_SUMME
            ,ACC_FACILITY.TILGUNGSRUECKSTAND_SUMME
            ,ACC_FACILITY.ZINSRUECKSTAND_SUMME
            ,ACC_FACILITY.PROVISIONSRUECKSTAND_SUMME
            ,ACC_FACILITY.OFFBALANCE_SUMME
            ,ACC_FACILITY.SAP_EWBTES_SUMME
            ,ACC_FACILITY.FVA_SUMME
            ,ACC_FACILITY.ABIT_EWB_EUR_SUMME
            ,ACC_FACILITY.ABIT_RST_EUR_SUMME
            ,ACC_FACILITY.ZEB_EWB_EUR_ONBALANCE_SUMME
            ,ACC_FACILITY.ZEB_EWB_EUR_OFFBALANCE_SUMME
            ,USER as CREATED_USER
            ,current_timestamp as CREATED_TIMESTAMP
        from BASIS
        left join CLIENT_IWHS           as IWHS             on (IWHS.CUT_OFF_DATE,IWHS.BORROWER_NO,IWHS.BRANCH_BORROWER) = (BASIS.CUT_OFF_DATE,BASIS.CLIENT_NO,BASIS.BRANCH)
        left join borrower_groups       as BORROWER_GROUPS  on borrower_groups.CLIENT_ID=BASIS.CLIENT_ID and BASIS.CUT_OFF_DATE=borrower_groups.CUT_OFF_DATE
        left join CBB.LENDING_CURRENT   as CBB              on (CBB.CUT_OFF_DATE,CBB.CLIENT_ID,'CBB') = (BASIS.CUT_OFF_DATE,BASIS.CLIENT_NO,BASIS.BRANCH)
        left join IMAP.ISO_LAENDER      as LA               on lpad(LA.LNDKNK,3,'0')=left(IWHS.COUNTRY,3)
        left join BILANZDATEN           as BIL              on BIL.KUNDENNUMMER=substr(BASIS.CLIENT_ID,5)
        left join CMS_LINK              as CMS              on BASIS.CLIENT_NO=CMS.CLIENT_ID and BASIS.CUT_OFF_DATE=CMS.CUT_OFF_DATE
        left join RATING                as RATING           on (RATING.CUT_OFF_DATE,RATING.GP_NR,RATING.Branch) = (BASIS.CUT_OFF_DATE,BASIS.CLIENT_NO,BASIS.BRANCH)
        left join FACILITY_ACC          as ACC_FACILITY     on (ACC_FACILITY.CUT_OFF_DATE, ACC_FACILITY.CLIENT_NO, ACC_FACILITY.BRANCH) = (BASIS.CUT_OFF_DATE,BASIS.CLIENT_NO,BASIS.BRANCH)
        )

select CUT_OFF_DATE,                                -- Stichtag
       BRANCH,                                      -- Institut des Kunden (passend zu CLIENT_ID_NO, nicht CLIENT_ID_ORIG!)
       CLIENT_NO AS CLIENT_ID,                      -- Kundennummer als Zahl
       CLIENT_ID AS CLIENT_ID_TXT,                  -- Kundennummer im Format Institut_Kundennummer
       CLIENT_ID_ORIG,                              -- original Kundennummer (CBB Kundennummer, falls von CBB in NLB übersetzt)
       CLIENT_ID_LEADING,                           -- Führende Kundennummer aus dem Ergebnis der Institutsfusion BLB->NLB
       CLIENT_ID_ALT,                               -- alternative uns bekannte Kundennummern
       CLIENT_ID_ALT ||
        case
            when CLIENT_ID<>CLIENT_ID_ORIG and CLIENT_ID_ALT <> CLIENT_ID then ',' || CLIENT_ID
            else ''
        end             as CLIENT_ID_ALTERNATIVE,   -- Alternative Kundennummer wenn bekannt
       CLIENT_TYPE,
       BORROWERNAME,                                -- Kundenname
       CLIENT_NAME_ANONYMIZED,                      -- Kundenname mit Singapur und Mitarbeiternamen ersetzt durch Anonym
       KONZERN_ID,                                  -- Konzern_ID aus KNDB
       KONZERN_BEZEICHNUNG,                         -- KONZERN_BEZEICHNUNG aus KNDB
       KONZERN_BEZEICHNUNG_ANONYMIZED,
       GVK_BUNDESBANKNUMMER,
       NACE,                                        -- statistische Systematik der Wirtschaftszweige in der EU [abbr.: NACE]
       COUNTRY,                                     -- Land KNK Code + Text
       COUNTRY_APLHA2,                              -- Land Alpha2 Wert z.B. 'DE'
       LEGALFORM,                                   -- Legaler Aufbau des Unternehmens (GmbH, AG,...)
       FLOAT(EBITDA) as EBITDA,                     -- Ergebnis vor Zinsen, Steuern und Abschreibungen
       REVENUE,                                     -- Einnahmen?
       OPERATING_EXPENSES,                          -- Betriebskosten?
       OTHER_EXPENSES,                              -- Andere Ausgaben
       CLIENT_BALANCE_SHEET_CURRENCY,               -- Hauptwährung des Kunden
       CLIENT_BALANCE_SHEET_DATE,
       ARISK_GESSICHW,
       MRISK_GESSICHW,
       RISK_GESSIW_WAEHR,
       RATING_ID,                                   -- Raiting Note
       RATING_MODUL,                                -- Raiting Modul
       SAP_EAD_SUMME,
       SAP_EL_SUMME,
       SAP_INANSPRUCHNAHME_SUMME,
       SAP_INANSPRUCHNAHME_AZ6_SUMME,
       SAP_INANSPRUCHNAHME_AVAL_SUMME,
       SAP_BLANKO_SUMME,
       SAP_FREILINIE_SUMME,
       FORDERUNG_SUMME,
       FORDERUNGAVAL_SUMME,
       FORDERUNG_K028_SUMME,
       FORDERUNG_RSMMARKETS_SUMME,
       GUTHABEN_SUMME,
       TILGUNGSRUECKSTAND_SUMME,
       ZINSRUECKSTAND_SUMME,
       PROVISIONSRUECKSTAND_SUMME,
       OFFBALANCE_SUMME,
       SAP_EWBTES_SUMME,
       FVA_SUMME,
       ABIT_EWB_EUR_SUMME,
       ABIT_RST_EUR_SUMME,
       ZEB_EWB_EUR_ONBALANCE_SUMME,
       ZEB_EWB_EUR_OFFBALANCE_SUMME,
       CREATED_USER,                                -- Letzter Nutzer, der dieses Tape gebaut hat.
       CREATED_TIMESTAMP                            -- Neuester Zeitstempel, wann dieses Tape zuletzt gebaut wurde.
from DONE_PRODUCT where NBR = 1
;
------------------------------------------------------------------------------------------------------------------------

-- CI START FOR ALL TAPES

-- Current-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_CLIENT_ACCOUNTHOLDER_CURRENT');
create table AMC.TABLE_CLIENT_ACCOUNTHOLDER_CURRENT like CALC.VIEW_CLIENT_ACCOUNTHOLDER distribute by hash(BRANCH,CLIENT_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CLIENT_ACCOUNTHOLDER_CURRENT_BRANCH    on AMC.TABLE_CLIENT_ACCOUNTHOLDER_CURRENT (BRANCH);
create index AMC.INDEX_CLIENT_ACCOUNTHOLDER_CURRENT_CLIENT_ID on AMC.TABLE_CLIENT_ACCOUNTHOLDER_CURRENT (CLIENT_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_CLIENT_ACCOUNTHOLDER_CURRENT');
------------------------------------------------------------------------------------------------------------------------

-- Archiv-Tabelle erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_CLIENT_ACCOUNTHOLDER_ARCHIVE');
create table AMC.TABLE_CLIENT_ACCOUNTHOLDER_ARCHIVE like CALC.VIEW_CLIENT_ACCOUNTHOLDER distribute by hash(BRANCH,CLIENT_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2015' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_CLIENT_ACCOUNTHOLDER_ARCHIVE_BRANCH    on AMC.TABLE_CLIENT_ACCOUNTHOLDER_ARCHIVE (BRANCH);
create index AMC.INDEX_CLIENT_ACCOUNTHOLDER_ARCHIVE_CLIENT_ID on AMC.TABLE_CLIENT_ACCOUNTHOLDER_ARCHIVE (CLIENT_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_CLIENT_ACCOUNTHOLDER_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

-- CI END FOR ALL TAPES

-- SWITCHES erstellen
------------------------------------------------------------------------------------------------------------------------
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_CLIENT_ACCOUNTHOLDER_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_CLIENT_ACCOUNTHOLDER_ARCHIVE');
------------------------------------------------------------------------------------------------------------------------

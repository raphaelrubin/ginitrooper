-- View erstellen
drop view CALC.VIEW_FACILITY_BW_P80_EXTERNAL;
create or replace view CALC.VIEW_FACILITY_BW_P80_EXTERNAL as
with
RDL_Q08_PRE as (
     select NLB_BW.*
     from NLB.BW_P80_RDL_EXTERNAL_CURRENT as NLB_BW
              inner join CALC.SWITCH_PORTFOLIO_CURRENT as P
                         on (P.CUT_OFF_DATE, P.FACILITY_ID) = (NLB_BW.CUT_OFF_DATE, NLB_BW.BA1_C11EXTCON)
     union all
     select ANL_BW.*
     from ANL.BW_P80_RDL_EXTERNAL_CURRENT as ANL_BW
              inner join CALC.SWITCH_PORTFOLIO_CURRENT as P
                         on (P.CUT_OFF_DATE, P.FACILITY_ID) = (ANL_BW.CUT_OFF_DATE, ANL_BW.BA1_C11EXTCON)
     union all
     select CBB_BW.*
     from CBB.BW_P80_RDL_EXTERNAL_CURRENT as CBB_BW
              inner join CALC.SWITCH_PORTFOLIO_CURRENT as P
                         on (P.CUT_OFF_DATE, P.FACILITY_ID) = (CBB_BW.CUT_OFF_DATE, CBB_BW.BA1_C11EXTCON)
),
RDL_Q08_CALCS as (
    SELECT CUT_OFF_DATE,
           BA1_C11EXTCON,
           (case when BIC_XB_EADCBT = 1 and BA_LCEKALART <> 'EADZERO' then BIC_E_INSPNA
                       when BIC_XB_EADCBT = 2 then BIC_E_FRELIN
                       when BIC_XB_EADCBT = 3 then BIC_E_FRELIN
                 else 0
            end
           + case when BA1_C35BTSRC = '02-SAP_FI' then BIC_E_INSPNA
                       when BA1_C35BTSRC = '20-BETL' then BIC_E_BUCHWE
                       when BA1_C35BTSRC = 'SPOT-WPM' then BIC_E_BUCHWE
                       when BA1_C35BTSRC = 'MUREX' then BIC_E_MARWER
                       when BA1_C35BTSRC = '15-MURHAN' then BIC_E_NOMBET
                   else 0
            end) as EADCB_berechnet
    FROM RDL_Q08_PRE
),
RDL_Q08_EXTERN as (
    select --Zuordnungen
           RP.CUT_OFF_DATE,
           substr(RP.BA1_C11EXTCON, 6, 2) || '-' || substr(RP.BA1_C11EXTCON, 22, 2) as SYSTEM_SATZART,
           RP.BA1_C11EXTCON,
           substr(RP.BA1_C11EXTCON, 9, 12)                                       as KtoNr,
           substr(RP.BA1_C11EXTCON, 25, 12)                                      as U_KtoNr,
           BA1_C55LGENT,
           BA1_C62CVAREL,
           BIC_XS_IDNUM,
           BA1_C20BPART,
           BIC_XA_RAVID,
           BA1_C41FINST,
           BA1_C43CLACC,
           BIC_XR_RVTNET,
           BIC_XX_CPICID,
           BIC_XB_VBRFID,
           BIC_XB_DKABTR,
           BIC_XX_EIGANT                                                      as Eigenanteil,
           -- Merkmale
           BA1_K55EXRAT,
           BIC_XS_CONTCU,
           BIC_XX_PRKEY,
           BA1_C35BTSRC,
           BA_LCEKALART,
           BIC_XB_EADCBT,
           BIC_B_CCFWER                                                       as CCF_Wert1,
           case when BIC_XB_EADCBT = 1 then BIC_B_CCFWER end                  as CCF1,
           case when BIC_XB_EADCBT = 2 then BIC_B_CCFWER end                  as CCF2,
           case when BIC_XB_EADCBT = 3 then BIC_B_CCFWER end                  as CCF3,
           case when BIC_XB_EADCBT = 4 then BIC_B_CCFWER end                  as CCF4,
           case when BIC_XB_EADCBT is null then BIC_B_CCFWER end              as CCFnull,
           BIC_XB_FKLBAS,
           BIC_XB_FKLARM,
           BIC_XB_FKLVRM,
           -- Grunddaten
           BIC_E_INSPNA,
           BIC_E_FRELIN,
           BIC_E_MARWER,
           BIC_E_NOMBET,
           BIC_E_BUCHWE,
           BIC_E_BEMGRD,
           case when BIC_E_INSPNA >= 0 then BIC_E_INSPNA else 0 end           as BIC_E_INSPNA_M,
           case when BIC_E_INSPNA >= 0 then 0 else -BIC_E_INSPNA end          as Guthaben,
           -- Grundwerte
           case when BIC_XB_EADCBT = 2 then BIC_E_FRELIN else 0 end           as unwiderruflicheZusage,
           case when BIC_XB_EADCBT = 3 then BIC_E_FRELIN else 0 end           as widerruflicheZusage,
           case when BIC_XB_EADCBT = 4 then 3 else 0 end                      as Sonstiges,
           -- Ableitung EADCB
           case when BA1_C35BTSRC in ('20-BETL','SPOT-WPM') then BIC_E_BUCHWE else 0 end as EADCB_SPOT_WPM_20_BETL_BUCHWE,
           case when BA1_C35BTSRC = '02-SAP-FI' then BIC_E_INSPNA else 0 end as EADCB_02_SAP_FI,
           case when BA1_C35BTSRC = 'MUREX' then BIC_E_MARWER else 0 end as EADCB_MUREX_AUS_MARWER,
           case when BA1_C35BTSRC = '15-MURHAN' then BIC_E_NOMBET else 0 end as EADCB_MURHAN_AUS_NOMBET,
           BIC_E_RIVO,
           BIC_E_RIVOA,
           -- Sonderfaelle_manuell
           case when
                RC.EADCB_berechnet - BIC_E_EADCB = BIC_E_RIVO then true
                else false
               end as RIVO_nicht_in_IA,
           case
               when BIC_E_EADCB <> RC.EADCB_berechnet
                   and not (
                       case
                           when RC.EADCB_berechnet - BIC_E_EADCB = BIC_E_RIVO then true
                            else false
                       end -- RIVO_nicht_in_IA
                       ) then true
               else false
           end as LIMIT_nicht_in_IA,
           case when BIC_E_INSPNA = 0 and (
               case when BIC_XB_EADCBT = 2 then BIC_E_FRELIN  -- unwiderruflicheZusage
                    when BIC_XB_EADCBT = 3 then BIC_E_FRELIN  -- widerruflicheZusage
                   else 0 end
               ) = 0 and BIC_E_EADCB > 0 then true
                else false
           end as Auszahlungsverpflichtung,
           --
           RC.EADCB_berechnet,
           BIC_E_EADCB,
           (case when BIC_XB_EADCBT = 1 and BA_LCEKALART <> 'EADZERO' then BIC_E_INSPNA
                 when BIC_XB_EADCBT = 2 then BIC_E_FRELIN
                 when BIC_XB_EADCBT = 3 then BIC_E_FRELIN
                 else 0 end
               + case when (case
                                when RC.EADCB_berechnet - BIC_E_EADCB = BIC_E_RIVO then true
                                else false
                            end -- RIVO_nicht_in_IA
                            )  = 1 then BIC_E_RIVO
                   else 0 end
               + case  when BA1_C35BTSRC = '02-SAP_FI' then BIC_E_INSPNA
                       when BA1_C35BTSRC = '20-BETL' then BIC_E_BUCHWE
                       when BA1_C35BTSRC = 'SPOT-WPM' then BIC_E_BUCHWE
                       when BA1_C35BTSRC = 'MUREX' then BIC_E_MARWER
                       when BA1_C35BTSRC = '15-MURHAN' then BIC_E_NOMBET
                       else 0
                 end)
               - BIC_E_EADCB as ABW_CB_berechnet_EADCB,
           -- Ableitung BMGVRM
           BIC_E_ANAKZI,
           BIC_E_ANPAZI,
           BIC_E_AKREAB,
           BIC_E_PAREAB,
           case when (BIC_E_EADCB + BIC_E_ANAKZI + BIC_E_ANPAZI + BIC_E_AKREAB + BIC_E_PAREAB + BIC_E_CVA) < 0 then 0
                else (1-BIC_B_ZAUST) * (BIC_E_EADCB + BIC_E_ANAKZI + BIC_E_ANPAZI + BIC_E_AKREAB + BIC_E_PAREAB + BIC_E_CVA)
           end as BMG_VRM_berechnet,
           BIC_E_BMGVRM,
           -- Abweichung BMGVRM moeglich durch RIVO
           case when (BIC_E_EADCB + BIC_E_ANAKZI + BIC_E_ANPAZI + BIC_E_AKREAB + BIC_E_PAREAB + BIC_E_CVA) < 0 then 0
                else (1-BIC_B_ZAUST) * ((BIC_E_EADCB + BIC_E_ANAKZI + BIC_E_ANPAZI + BIC_E_AKREAB + BIC_E_PAREAB + BIC_E_CVA) - BIC_E_BMGVRM)
           end as ABW_BMGVRM,
           BIC_XB_PIDSIV,
           BA_LZZSICTYP,
           BIC_XB_SICHKL,
           BIC_B_ALPHA,
           BIC_B_BETA,
           BIC_E_SIBAHC,
           BIC_E_SIBVHC,
           -- Sonderfaelle manuell
           -- EAD ARM beruecksichtigungsfaehige Guthaben (aktuell nicht moeglich)
           BIC_E_BMGARM,
           --BIC_E_BMGVRM - case when EAD_ARM_berueck_Guthaben = true then BIC_E_SIBAHC else 0 end as BMGARM_berechnet,
           --BIC_E_BMGVRM - ((case when EAD_ARM_berueck_Guthaben = true then BIC_E_SIBAHC else 0 end) - BIC_E_BMGARM) as Pruef_BMGVRMARM_berechnet,
           -- Ableitung EAD
           BIC_B_CCFWER,
           BIC_E_EAD,
           BIC_E_BMGVRM*BIC_B_CCFWER as EADVRM_berechnet,
           BIC_E_EAD-BIC_E_BMGVRM*BIC_B_CCFWER as ABW_EADVRM_berechnet,
           BIC_E_EADANT,
           BIC_E_BMGARM*BIC_B_CCFWER as EADARM_berechnet,
           BIC_E_EADANT-BIC_E_BMGARM*BIC_B_CCFWER as ABW_EADARM_berechnet,
           -- Auspl
           case when BIC_XB_DAUSKZ = 5 and BIC_B_ZAUST = 0 then BIC_E_EADCB else 0 end as Verbriefung,
           case when BIC_XB_DAUSKZ = 5 and BIC_B_ZAUST > 0 then BIC_E_EADCB else 0 end as ausplatzierteForderungen,
           BIC_XB_DAUSKZ,
           BIC_B_ZAUST,
           BIC_E_EADAUS,
           BIC_E_RWAARM,
           BIC_E_RWAAUS,
           --ECB
           BIC_B_LGDVRM,
           BIC_B_LGDWER,
           BIC_XB_RTMOD,
           BIC_E_JAHRUM
           from RDL_Q08_PRE as RP
           LEFT JOIN RDL_Q08_CALCS RC ON (RP.CUT_OFF_DATE, RP.BA1_C11EXTCON) =
                                         (RC.CUT_OFF_DATE, RC.BA1_C11EXTCON)
           WHERE BA1_C35BTSRC in (
                                  'LOANIQ',
                                  '02-SAP_FI',
                                  '13-KONT',
                                  '35-OSPLUS',
                                  '49-KONT',
                                  '69-DARL',
                                  '69-KONT',
                                  '71-DARL',
                                  '71-KONT',
                                  '73-DARL',
                                  '73-KONT',
                                  'ALIS',
                                  'FMV',
                                  'IWHS',
                                  'IWHS_AZ6',
                                  'KMF',
                                  'MANUELL',
                                  'SR2020',
                                  'SPOT-WPM',
                                  '20-BETL'
               ) OR BA1_C35BTSRC not in (
                                  'SA_CCR',
                                  '15-MURHAN',
                                  'MUREX'
               )

 ),
RDL_Q08_COMP as (
    select CUT_OFF_DATE,
           BA1_C11EXTCON as FACILITY_ID,
           SYSTEM_SATZART,
           KTONR,
           U_KTONR,
           BA1_C55LGENT as LEGALE_EINHEIT,
           BIC_XS_IDNUM as CLIENT_NO,
           BA1_C20BPART as GESCHAEFTSPARTNER_NO,
           BIC_XA_RAVID as RAHMENAVAL_ID,
           BA1_C41FINST as FINANZINSTRUMENT_ID,
           BA1_C43CLACC as DEPOTGATTUNGBESTANDSKONTO_ID,
           BIC_XR_RVTNET as RAHMENVERTRAGSNO_NETTING,
           BIC_XX_CPICID as KOMPENSATIONS_ID,
           BIC_XB_VBRFID as VERBRIEFUNGS_ID,
           BIC_XB_DKABTR as KENNZ_ABTRETUNG_AUSPLATZIERUNG,
           BIC_XX_PRKEY as CONTROLLING_PRODUKTSCHLUESSEL,
           BA1_C35BTSRC as ANWENDUNG,
           max(CCF1) as MaxvonCCF1,
           max(CCF2) as MaxvonCCF2,
           max(CCF3) as MaxvonCCF3,
           max(CCF4) as MaxvonCCF4,
           sum(BIC_E_INSPNA) as Summe_INSPNA,
           sum(BIC_E_INSPNA_M) as Summe_INSPNA_M,
           sum(Guthaben) as Summe_Guthaben,
           sum(unwiderruflicheZusage) as Summe_unwiderruflicheZusage,
           sum(widerruflicheZusage) as Summe_widerruflicheZusage,
           sum(BIC_E_MARWER) as Summe_MARWER,
           sum(BIC_E_NOMBET) as Summe_NOMBET,
           sum(BIC_E_BUCHWE) as Summe_BUCHWE,
           --Grundwerte
           sum(EADCB_berechnet) as Summe_EADCB_berechnet,
           sum(BIC_E_EADCB) as Summe_EADCB,
           sum(ABW_CB_berechnet_EADCB) as Summe_ABW_CB_berechnet_EADCB,
           --Ableitung BMGVRM
           sum(BIC_E_ANAKZI) as Summe_ANAKZI,
           sum(BIC_E_ANPAZI) as Summe_ANPAZI,
           sum(BIC_E_AKREAB) as Summe_AKREAB,
           sum(BIC_E_PAREAB) as Summe_PAREAB,
           sum(BMG_VRM_berechnet) as Summe_BMG_VRM_berechnet,
           sum(BIC_E_BMGVRM) as Summe_BMGVRM,
           sum(BIC_E_RIVO) as Summe_ABW_moegl_durch_RIVO,
           sum(ABW_BMGVRM) as Summe_ABW_BMGVRM,
           sum(BIC_E_SIBAHC) as Summe_BIC_E_SIBAHC,
           sum(BIC_E_SIBVHC) as Summe_BIC_E_SIBVHC,
           --EADARM_berueck_Guthaben,
           --sum(BMGARM_berechnet) as Summe_BMGARM_berechnet,
           sum(BIC_E_BMGARM) as Summe_BMGARM,
           --sum(Pruef_BMGVRMARM_berechnet) as Summe_Pruef_BMGVRMARM_berechnet,
           --Ableitung EAD
           sum(EADVRM_berechnet) as Summe_EADVRM_berechnet,
           sum(BIC_E_EAD) as Summe_EAD,
           sum(BIC_E_RIVO) as Summe_moegl_Ursache_RIVO,
           sum(BIC_E_RIVOA) as Summe_moegl_Ursache_RIVOA,
           sum(ABW_EADVRM_berechnet) as Summe_ABW_EADVRM_berechnet,
           --Auspl
           sum(Verbriefung) as Summe_Verbriefung,
           sum(ausplatzierteForderungen) as Summe_auspl_Forderungen,
           sum(BIC_E_EADAUS) as Summe_EADARM_ausplatziert,
           sum(BIC_E_RIVOA) as Summe_auspl_bil_kum_RIVO,
           sum(BIC_E_RWAAUS) as Summe_RWAAUS,
           sum(BIC_E_RWAARM) as Summe_RWAARM,
           --ECB
           case when sum(BIC_E_FRELIN) <> 0 then sum(BIC_B_CCFWER*BIC_E_FRELIN) / sum(BIC_E_FRELIN) else 0 end as Weighted_CCFWER,
           case when sum(BIC_E_EAD) <> 0 then sum(BIC_B_LGDVRM*BIC_E_EAD) / sum(BIC_E_EAD) end as Weighted_LGDVRM,
           case when sum(BIC_E_EAD) <> 0 then sum(BIC_B_LGDWER*BIC_E_EAD) / sum(BIC_E_EAD) end as Weigthed_LGDWER,
           max(case when BIC_XB_PIDSIV is null or BIC_XB_PIDSIV = '' then null else BIC_XB_RTMOD end) as FLG_LBO,
           sum(BIC_E_JAHRUM) as Summe_JAHRESUMSATZ
           -- #### fehlende, unklare Spalten ####
           -- EAD // Welches Feld für regulatorisches EAD?
           -- FLG_LBO // Flag für Leverage Buy out true/false
           -- RWA // Welches Feld ?
           -- RWA_MTHD // Methode zur Berechnung der RWA (KSA) oder (IRBA)
           -- TRNCH // Tranching / Security Tranche der Nordlb
    FROM RDL_Q08_EXTERN
    GROUP BY CUT_OFF_DATE, BA1_C11EXTCON, SYSTEM_SATZART, KTONR, U_KTONR, BA1_C55LGENT, BIC_XS_IDNUM, BA1_C20BPART,
             BIC_XA_RAVID, BA1_C41FINST, BA1_C43CLACC, BIC_XR_RVTNET, BIC_XX_CPICID, BIC_XB_VBRFID, BIC_XB_DKABTR,
             BIC_XX_PRKEY, BA1_C35BTSRC
),
final_data as (
    select distinct CUT_OFF_DATE,
                    FACILITY_ID,
                    SYSTEM_SATZART,
                    KtoNr,
                    U_KtoNr,
                    LEGALE_EINHEIT,
                    CLIENT_NO,
                    GESCHAEFTSPARTNER_NO,
                    RAHMENAVAL_ID,
                    FINANZINSTRUMENT_ID,
                    DEPOTGATTUNGBESTANDSKONTO_ID,
                    RAHMENVERTRAGSNO_NETTING,
                    KOMPENSATIONS_ID,
                    VERBRIEFUNGS_ID,
                    KENNZ_ABTRETUNG_AUSPLATZIERUNG,
                    CONTROLLING_PRODUKTSCHLUESSEL,
                    ANWENDUNG,
                    MaxvonCCF1,
                    MaxvonCCF2,
                    MaxvonCCF3,
                    MaxvonCCF4,
                    Summe_INSPNA,
                    Summe_INSPNA_M,
                    Summe_Guthaben,
                    Summe_unwiderruflicheZusage,
                    Summe_widerruflicheZusage,
                    Summe_MARWER,
                    Summe_NOMBET,
                    Summe_BUCHWE,
                    Summe_EADCB_berechnet,
                    Summe_EADCB,
                    Summe_ABW_CB_berechnet_EADCB,
                    Summe_ANAKZI,
                    Summe_ANPAZI,
                    Summe_AKREAB,
                    Summe_PAREAB,
                    Summe_BMG_VRM_berechnet,
                    Summe_BMGVRM,
                    Summe_ABW_moegl_durch_RIVO,
                    Summe_ABW_BMGVRM,
                    Summe_BIC_E_SIBAHC,
                    Summe_BIC_E_SIBVHC,
                    Summe_BMGARM,
                    Summe_EADVRM_berechnet,
                    Summe_EAD,
                    Summe_moegl_Ursache_RIVO,
                    Summe_moegl_Ursache_RIVOA,
                    Summe_ABW_EADVRM_berechnet,
                    Summe_Verbriefung,
                    Summe_auspl_Forderungen,
                    Summe_EADARM_ausplatziert,
                    Summe_auspl_bil_kum_RIVO,
                    Summe_RWAAUS,
                    Summe_RWAARM,
                    Weighted_CCFWER,
                    Weighted_LGDVRM,
                    Weigthed_LGDWER,
                    case when round(Weighted_LGDVRM,2) <= 0.45 then 2
                         when round(Weighted_LGDVRM,2) > 0.45 and round(Weighted_LGDVRM,2) <= 0.75 then 3
                         when round(Weighted_LGDVRM,2) > 0.75 then 5
                         else null end as TRNCH,
                    case when FLG_LBO = 79 then true else false end as FLG_LBO,
                    Summe_JAHRESUMSATZ
    from RDL_Q08_COMP
)
select *,
       CURRENT_USER as USER,
       CURRENT_TIMESTAMP as TIMESTAMP_LOAD
from final_data;

-- CI START FOR ALL TAPES
-- Current-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_FACILITY_BW_P80_EXTERNAL_CURRENT');
create table AMC.TABLE_FACILITY_BW_P80_EXTERNAL_CURRENT like CALC.VIEW_FACILITY_BW_P80_EXTERNAL distribute by hash(FACILITY_ID) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_TABLE_FACILITY_BW_P80_EXTERNAL_CURRENT_FACILITY_ID on AMC.TABLE_FACILITY_BW_P80_EXTERNAL_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_FACILITY_BW_P80_EXTERNAL_CURRENT');
-- Archiv-Tabelle erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_FACILITY_BW_P80_EXTERNAL_ARCHIVE');
create table AMC.TABLE_FACILITY_BW_P80_EXTERNAL_ARCHIVE like AMC.TABLE_FACILITY_BW_P80_EXTERNAL_CURRENT distribute by hash(FACILITY_ID) partition by RANGE (CUT_OFF_DATE) (starting '1.1.2020' ending '31.12.2030' EVERY 1 Month) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_TABLE_FACILITY_BW_P80_EXTERNAL_ARCHIVE_FACILITY_ID on AMC.TABLE_FACILITY_BW_P80_EXTERNAL_CURRENT (FACILITY_ID);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_FACILITY_BW_P80_EXTERNAL_ARCHIVE');
-- CI END FOR ALL TAPES

-- SWITCH View erstellen
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_FACILITY_BW_P80_EXTERNAL_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_FACILITY_BW_P80_EXTERNAL_ARCHIVE');
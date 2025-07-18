--View die korrigierte CMS Link Daten an den 31.12. joined, siehe issue #678
drop view CALC.VIEW_CMS_LINK_NLB_20201231;
create or replace view CALC.VIEW_CMS_LINK_NLB_20201231 as
    with korrektes_1231 as
             (
                 select sv_id,
                        sv_status,
                        teilwert_proz,
                        teilwert_betrag,
                        teilwert_betrag_waehr,
                        teil_einschraenkung,
                        gw_kreditsystem,
                        gw_forderungsid,
                        gw_id,
                        gw_institut,
                        gw_partner,
                        gw_konto,
                        sv_teil_id,
                        gw_refikennz_darlehen,
                        gw_schliessdat,
                        sicherungszweck,
                        zuweisungsbetrag,
                        zuweisungsbetr_waehr,
                        max_risk_konto,
                        CUTOFFDATE
                 from NLB.CMS_LINK
                 where CUTOFFDATE = '2020-12-31'
             ),
         korrektur_0108 as
             (
                 select sv_id,
                        akt_risk_konto,
                        risk_konto_waehr,
                        max_risk_sv_zur_vert,
                        akt_risk_sv_zur_vert,
                        gw_produktschl_aktiv,
                        gw_produktschl_passiv,
                        arisk_gessichw_kn,
                        risk_gessiw_kn_waehr,
                        max_risk_vert_je_gw,
                        akt_risk_vert_je_gw,
                        risk_sv_zur_vert_waehr,
                        mrisk_gessichw_kn,
                        risk_vert_je_gw_waeh,
                        mrisk_sichw_je_sv_kn,
                        arisk_sichw_je_sv_kn
                 from NLB.CMS_LINK
                 where CUTOFFDATE = '2021-01-08'
             )
         select
                orig.sv_id,
           sv_status,
           teilwert_proz,
           teilwert_betrag,
           teilwert_betrag_waehr,
           teil_einschraenkung,
           gw_kreditsystem,
           gw_forderungsid,
           gw_id,
           gw_institut,
           gw_partner,
           gw_konto,
           sv_teil_id,
           gw_refikennz_darlehen,
           gw_schliessdat,
           sicherungszweck,
           zuweisungsbetrag,
           zuweisungsbetr_waehr,
           max_risk_konto,
           akt_risk_konto,
           risk_konto_waehr,
           max_risk_sv_zur_vert,
           akt_risk_sv_zur_vert,
           gw_produktschl_aktiv,
           gw_produktschl_passiv,
           arisk_gessichw_kn,
           risk_gessiw_kn_waehr,
           max_risk_vert_je_gw,
           akt_risk_vert_je_gw,
           risk_sv_zur_vert_waehr,
           mrisk_gessichw_kn,
           risk_vert_je_gw_waeh,
           mrisk_sichw_je_sv_kn,
           arisk_sichw_je_sv_kn,
           cutoffdate
                from korrektes_1231 orig
        left join korrektur_0108 korr on korr.sv_id = orig.SV_ID
;
drop view CALC.VIEW_CMS_LINK_BLB_20201231;
create or replace view CALC.VIEW_CMS_LINK_BLB_20201231 as
    with korrektes_1231 as
             (
                 select sv_id,
                        sv_status,
                        teilwert_proz,
                        teilwert_betrag,
                        teilwert_betrag_waehr,
                        teil_einschraenkung,
                        gw_kreditsystem,
                        gw_forderungsid,
                        gw_id,
                        gw_institut,
                        gw_partner,
                        gw_konto,
                        sv_teil_id,
                        gw_refikennz_darlehen,
                        gw_schliessdat,
                        sicherungszweck,
                        zuweisungsbetrag,
                        zuweisungsbetr_waehr,
                        max_risk_konto,
                        CUTOFFDATE
                 from BLB.CMS_LINK
                 where CUTOFFDATE = '2020-12-31'
             ) ,
         korrektur_0108 as
             (
                 select sv_id,
                        akt_risk_konto,
                        risk_konto_waehr,
                        max_risk_sv_zur_vert,
                        akt_risk_sv_zur_vert,
                        gw_produktschl_aktiv,
                        gw_produktschl_passiv,
                        arisk_gessichw_kn,
                        risk_gessiw_kn_waehr,
                        max_risk_vert_je_gw,
                        akt_risk_vert_je_gw,
                        risk_sv_zur_vert_waehr,
                        mrisk_gessichw_kn,
                        risk_vert_je_gw_waeh,
                        mrisk_sichw_je_sv_kn,
                        arisk_sichw_je_sv_kn
                from BLB.CMS_LINK
                 where CUTOFFDATE = '2021-01-08'
             )
         select                 orig.sv_id,
           sv_status,
           teilwert_proz,
           teilwert_betrag,
           teilwert_betrag_waehr,
           teil_einschraenkung,
           gw_kreditsystem,
           gw_forderungsid,
           gw_id,
           gw_institut,
           gw_partner,
           gw_konto,
           sv_teil_id,
           gw_refikennz_darlehen,
           gw_schliessdat,
           sicherungszweck,
           zuweisungsbetrag,
           zuweisungsbetr_waehr,
           max_risk_konto,
           akt_risk_konto,
           risk_konto_waehr,
           max_risk_sv_zur_vert,
           akt_risk_sv_zur_vert,
           gw_produktschl_aktiv,
           gw_produktschl_passiv,
           arisk_gessichw_kn,
           risk_gessiw_kn_waehr,
           max_risk_vert_je_gw,
           akt_risk_vert_je_gw,
           risk_sv_zur_vert_waehr,
           mrisk_gessichw_kn,
           risk_vert_je_gw_waeh,
           mrisk_sichw_je_sv_kn,
           arisk_sichw_je_sv_kn,
           cutoffdate
            from korrektes_1231 orig
        left join korrektur_0108 korr on korr.sv_id = orig.SV_ID
;
--Tabelle muss befüllt werden über insert Befehl in einer Changes Datei
call STG.TEST_PROC_BACKUP_AND_DROP('CALC','TABLE_CMS_LINK_NLB_20201231_CURRENT');
create table CALC.TABLE_CMS_LINK_NLB_20201231_CURRENT like CALC.VIEW_CMS_LINK_NLB_20201231 distribute by hash(SV_ID) in SPACE_NLB_A,SPACE_NLB_B,SPACE_NLB_C,SPACE_NLB_D,SPACE_NLB_E,SPACE_NLB_F;
create index CALC.INDEX_TABLE_CMS_LINK_NLB_20201231_CURRENT_SV_ID on CALC.TABLE_CMS_LINK_NLB_20201231_CURRENT (SV_ID);
create index CALC.INDEX_TABLE_CMS_LINK_NLB_20201231_CURRENT_CUTOFFDATE   on CALC.TABLE_CMS_LINK_NLB_20201231_CURRENT (CUTOFFDATE);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('CALC','TABLE_CMS_LINK_NLB_20201231_CURRENT');

call STG.TEST_PROC_BACKUP_AND_DROP('CALC','TABLE_CMS_LINK_BLB_20201231_CURRENT');
create table CALC.TABLE_CMS_LINK_BLB_20201231_CURRENT like CALC.VIEW_CMS_LINK_BLB_20201231 distribute by hash(SV_ID) in SPACE_BLB_A,SPACE_BLB_B,SPACE_BLB_C,SPACE_BLB_D,SPACE_BLB_E,SPACE_BLB_F;
create index CALC.INDEX_TABLE_CMS_LINK_BLB_20201231_CURRENT_SV_ID on CALC.TABLE_CMS_LINK_BLB_20201231_CURRENT (SV_ID);
create index CALC.INDEX_TABLE_CMS_LINK_BLB_20201231_CURRENT_CUTOFFDATE   on CALC.TABLE_CMS_LINK_BLB_20201231_CURRENT (CUTOFFDATE);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('CALC','TABLE_CMS_LINK_BLB_20201231_CURRENT');


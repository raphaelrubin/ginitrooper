--Replacement aus issue #678
drop view CALC.VIEW_NLB_CMS_LINK_REPLACEMENT;
create or replace view CALC.VIEW_NLB_CMS_LINK_REPLACEMENT as
    select cur.sv_id,
           coalesce(MAN.sv_status, rep.sv_status, cur.sv_status) as sv_status,
           coalesce(MAN.teilwert_proz,rep.teilwert_proz,cur.teilwert_proz) as teilwert_proz,
           coalesce(MAN.teilwert_betrag,rep.teilwert_betrag,cur.TEILWERT_BETRAG) as TEILWERT_BETRAG,
           coalesce(MAN.teilwert_betrag_waehr, rep.teilwert_betrag_waehr, cur.TEILWERT_BETRAG_WAEHR) as TEILWERT_BETRAG_WAEHR,
           coalesce(MAN.teil_einschraenkung, rep.teil_einschraenkung, cur.TEIL_EINSCHRAENKUNG) as TEIL_EINSCHRAENKUNG,
           coalesce(rep.gw_kreditsystem, cur.GW_KREDITSYSTEM) as GW_KREDITSYSTEM,
           coalesce(MAN.gw_forderungsid, rep.gw_forderungsid, cur.GW_FORDERUNGSID) as GW_FORDERUNGSID,
           coalesce(rep.gw_id, cur.GW_ID) as GW_ID,
           coalesce(rep.gw_institut, cur.GW_INSTITUT) as GW_INSTITUT,
           coalesce(rep.gw_partner, cur.GW_PARTNER) as GW_PARTNER,
           coalesce(MAN.gw_konto, rep.gw_konto, cur.GW_KONTO) as GW_KONTO,
           coalesce(rep.sv_teil_id, cur.SV_TEIL_ID) as SV_TEIL_ID,
           coalesce(rep.gw_refikennz_darlehen, cur.GW_REFIKENNZ_DARLEHEN) as GW_REFIKENNZ_DARLEHEN,
           coalesce(rep.gw_schliessdat, cur.GW_SCHLIESSDAT) as GW_SCHLIESSDAT,
           coalesce(rep.sicherungszweck, cur.SICHERUNGSZWECK) as SICHERUNGSZWECK,
           coalesce(rep.zuweisungsbetrag, cur.ZUWEISUNGSBETRAG) as ZUWEISUNGSBETRAG,
           coalesce(rep.zuweisungsbetr_waehr, cur.ZUWEISUNGSBETR_WAEHR) as ZUWEISUNGSBETR_WAEHR,
           coalesce(rep.max_risk_konto, cur.MAX_RISK_KONTO) as MAX_RISK_KONTO,
           coalesce(rep.akt_risk_konto, cur.AKT_RISK_KONTO) as AKT_RISK_KONTO,
           coalesce(rep.risk_konto_waehr, cur.RISK_KONTO_WAEHR) as RISK_KONTO_WAEHR,
           coalesce(MAN.max_risk_sv_zur_vert, rep.max_risk_sv_zur_vert, cur.MAX_RISK_SV_ZUR_VERT) as MAX_RISK_SV_ZUR_VERT,
           coalesce(rep.akt_risk_sv_zur_vert, cur.AKT_RISK_SV_ZUR_VERT) as AKT_RISK_SV_ZUR_VERT,
           coalesce(rep.gw_produktschl_aktiv, cur.GW_PRODUKTSCHL_AKTIV) as GW_PRODUKTSCHL_AKTIV,
           coalesce(rep.gw_produktschl_passiv, cur.GW_PRODUKTSCHL_PASSIV) as GW_PRODUKTSCHL_PASSIV,
           coalesce(rep.arisk_gessichw_kn, cur.ARISK_GESSICHW_KN) as ARISK_GESSICHW_KN,
           coalesce(rep.risk_gessiw_kn_waehr, cur.RISK_GESSIW_KN_WAEHR) as RISK_GESSIW_KN_WAEHR,
           coalesce(MAN.max_risk_vert_je_gw, rep.max_risk_vert_je_gw, cur.MAX_RISK_VERT_JE_GW) as MAX_RISK_VERT_JE_GW,
           coalesce(rep.akt_risk_vert_je_gw, cur.AKT_RISK_VERT_JE_GW) as AKT_RISK_VERT_JE_GW,
           coalesce(rep.risk_sv_zur_vert_waehr, cur.RISK_SV_ZUR_VERT_WAEHR) as RISK_SV_ZUR_VERT_WAEHR,
           coalesce(rep.mrisk_gessichw_kn, cur.MRISK_GESSICHW_KN) as MRISK_GESSICHW_KN,
           coalesce(rep.risk_vert_je_gw_waeh, cur.RISK_VERT_JE_GW_WAEH) as RISK_VERT_JE_GW_WAEH,
           coalesce(rep.mrisk_sichw_je_sv_kn, cur.MRISK_SICHW_JE_SV_KN) as MRISK_SICHW_JE_SV_KN,
           coalesce(rep.arisk_sichw_je_sv_kn, cur.ARISK_SICHW_JE_SV_KN) as ARISK_SICHW_JE_SV_KN,
           cur.cutoffdate,
           cur.BRANCH,
		   coalesce(MAN.QUELLE, 'CMS') as QUELLE
    from NLB.CMS_LINK_CURRENT 								as cur -- Original CMS Daten
    left join CALC.TABLE_CMS_LINK_NLB_20201231_CURRENT 		as rep -- rep enthält nur Daten für den 31.12.2020
        on (cur.CUTOFFDATE, cur.SV_ID, cur.SV_TEIL_ID) = (rep.CUTOFFDATE, rep.SV_ID, rep.SV_TEIL_ID)
	left join NLB.COLLATERAL_TO_FACILITY_ADDITION_CURRENT 	as MAN -- Änderungen durch den Fachbereich
        on (cur.CUTOFFDATE, cur.SV_ID, cur.SV_TEIL_ID) = (MAN.CUT_OFF_DATE, MAN.SV_ID, MAN.SV_TEIL_ID)
;

drop view CALC.VIEW_BLB_CMS_LINK_REPLACEMENT;
create or replace view CALC.VIEW_BLB_CMS_LINK_REPLACEMENT as
    select cur.sv_id,
           coalesce(MAN.sv_status, rep.sv_status, cur.sv_status) as sv_status,
           coalesce(MAN.teilwert_proz,rep.teilwert_proz,cur.teilwert_proz) as teilwert_proz,
           coalesce(MAN.teilwert_betrag,rep.teilwert_betrag,cur.TEILWERT_BETRAG) as TEILWERT_BETRAG,
           coalesce(MAN.teilwert_betrag_waehr, rep.teilwert_betrag_waehr, cur.TEILWERT_BETRAG_WAEHR) as TEILWERT_BETRAG_WAEHR,
           coalesce(MAN.teil_einschraenkung, rep.teil_einschraenkung, cur.TEIL_EINSCHRAENKUNG) as TEIL_EINSCHRAENKUNG,
           coalesce(rep.gw_kreditsystem, cur.GW_KREDITSYSTEM) as GW_KREDITSYSTEM,
           coalesce(MAN.gw_forderungsid, rep.gw_forderungsid, cur.GW_FORDERUNGSID) as GW_FORDERUNGSID,
           coalesce(rep.gw_id, cur.GW_ID) as GW_ID,
           coalesce(rep.gw_institut, cur.GW_INSTITUT) as GW_INSTITUT,
           coalesce(rep.gw_partner, cur.GW_PARTNER) as GW_PARTNER,
           coalesce(MAN.gw_konto, rep.gw_konto, cur.GW_KONTO) as GW_KONTO,
           coalesce(rep.sv_teil_id, cur.SV_TEIL_ID) as SV_TEIL_ID,
           coalesce(rep.gw_refikennz_darlehen, cur.GW_REFIKENNZ_DARLEHEN) as GW_REFIKENNZ_DARLEHEN,
           coalesce(rep.gw_schliessdat, cur.GW_SCHLIESSDAT) as GW_SCHLIESSDAT,
           coalesce(rep.sicherungszweck, cur.SICHERUNGSZWECK) as SICHERUNGSZWECK,
           coalesce(rep.zuweisungsbetrag, cur.ZUWEISUNGSBETRAG) as ZUWEISUNGSBETRAG,
           coalesce(rep.zuweisungsbetr_waehr, cur.ZUWEISUNGSBETR_WAEHR) as ZUWEISUNGSBETR_WAEHR,
           coalesce(rep.max_risk_konto, cur.MAX_RISK_KONTO) as MAX_RISK_KONTO,
           coalesce(rep.akt_risk_konto, cur.AKT_RISK_KONTO) as AKT_RISK_KONTO,
           coalesce(rep.risk_konto_waehr, cur.RISK_KONTO_WAEHR) as RISK_KONTO_WAEHR,
           coalesce(MAN.max_risk_sv_zur_vert, rep.max_risk_sv_zur_vert, cur.MAX_RISK_SV_ZUR_VERT) as MAX_RISK_SV_ZUR_VERT,
           coalesce(rep.akt_risk_sv_zur_vert, cur.AKT_RISK_SV_ZUR_VERT) as AKT_RISK_SV_ZUR_VERT,
           coalesce(rep.gw_produktschl_aktiv, cur.GW_PRODUKTSCHL_AKTIV) as GW_PRODUKTSCHL_AKTIV,
           coalesce(rep.gw_produktschl_passiv, cur.GW_PRODUKTSCHL_PASSIV) as GW_PRODUKTSCHL_PASSIV,
           coalesce(rep.arisk_gessichw_kn, cur.ARISK_GESSICHW_KN) as ARISK_GESSICHW_KN,
           coalesce(rep.risk_gessiw_kn_waehr, cur.RISK_GESSIW_KN_WAEHR) as RISK_GESSIW_KN_WAEHR,
           coalesce(MAN.max_risk_vert_je_gw, rep.max_risk_vert_je_gw, cur.MAX_RISK_VERT_JE_GW) as MAX_RISK_VERT_JE_GW,
           coalesce(rep.akt_risk_vert_je_gw, cur.AKT_RISK_VERT_JE_GW) as AKT_RISK_VERT_JE_GW,
           coalesce(rep.risk_sv_zur_vert_waehr, cur.RISK_SV_ZUR_VERT_WAEHR) as RISK_SV_ZUR_VERT_WAEHR,
           coalesce(rep.mrisk_gessichw_kn, cur.MRISK_GESSICHW_KN) as MRISK_GESSICHW_KN,
           coalesce(rep.risk_vert_je_gw_waeh, cur.RISK_VERT_JE_GW_WAEH) as RISK_VERT_JE_GW_WAEH,
           coalesce(rep.mrisk_sichw_je_sv_kn, cur.MRISK_SICHW_JE_SV_KN) as MRISK_SICHW_JE_SV_KN,
           coalesce(rep.arisk_sichw_je_sv_kn, cur.ARISK_SICHW_JE_SV_KN) as ARISK_SICHW_JE_SV_KN,
           cur.cutoffdate,
           cur.BRANCH,
		   coalesce(MAN.QUELLE, 'CMS') as QUELLE
    from BLB.CMS_LINK_CURRENT 								as cur -- Original CMS Daten
	left join CALC.TABLE_CMS_LINK_BLB_20201231_CURRENT 		as rep -- rep enthält nur Daten für den 31.12.2020
        on (cur.CUTOFFDATE, cur.SV_ID, cur.SV_TEIL_ID) = (rep.CUTOFFDATE, rep.SV_ID, rep.SV_TEIL_ID)
	left join BLB.COLLATERAL_TO_FACILITY_ADDITION_CURRENT 	as MAN -- Änderungen durch den Fachbereich
        on (cur.CUTOFFDATE, cur.SV_ID, cur.SV_TEIL_ID) = (MAN.CUT_OFF_DATE, MAN.SV_ID, MAN.SV_TEIL_ID)
    
;


-- CI START FOR ALL TAPES
-- Current-Tabellen erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_NLB_CMS_LINK_REPLACEMENT_CURRENT');
create table AMC.TABLE_NLB_CMS_LINK_REPLACEMENT_CURRENT like CALC.VIEW_NLB_CMS_LINK_REPLACEMENT distribute by hash(SV_ID, GW_KONTO) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_NLB_CMS_LINK_REPLACEMENT_CURRENT_SV_ID_GW_KONTO on AMC.TABLE_NLB_CMS_LINK_REPLACEMENT_CURRENT (SV_ID, GW_KONTO);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_NLB_CMS_LINK_REPLACEMENT_CURRENT');

call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_BLB_CMS_LINK_REPLACEMENT_CURRENT');
create table AMC.TABLE_BLB_CMS_LINK_REPLACEMENT_CURRENT like CALC.VIEW_BLB_CMS_LINK_REPLACEMENT distribute by hash(SV_ID, GW_KONTO) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_BLB_CMS_LINK_REPLACEMENT_CURRENT_SV_ID_GW_KONTO on AMC.TABLE_BLB_CMS_LINK_REPLACEMENT_CURRENT (SV_ID, GW_KONTO);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_BLB_CMS_LINK_REPLACEMENT_CURRENT');

-- Archiv-Tabellen erstellen
call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_NLB_CMS_LINK_REPLACEMENT_ARCHIVE');
create table AMC.TABLE_NLB_CMS_LINK_REPLACEMENT_ARCHIVE like CALC.VIEW_NLB_CMS_LINK_REPLACEMENT distribute by hash(SV_ID, GW_KONTO) partition by RANGE (CUTOFFDATE) (starting '1.1.2015' ending '31.12.2025' EVERY 1 MONTH) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_NLB_CMS_LINK_REPLACEMENT_ARCHIVE_SV_ID_GW_KONTO on AMC.TABLE_NLB_CMS_LINK_REPLACEMENT_ARCHIVE (SV_ID, GW_KONTO);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_NLB_CMS_LINK_REPLACEMENT_ARCHIVE');

call STG.TEST_PROC_BACKUP_AND_DROP('AMC','TABLE_BLB_CMS_LINK_REPLACEMENT_ARCHIVE');
create table AMC.TABLE_BLB_CMS_LINK_REPLACEMENT_ARCHIVE like CALC.VIEW_BLB_CMS_LINK_REPLACEMENT distribute by hash(SV_ID, GW_KONTO) partition by RANGE (CUTOFFDATE) (starting '1.1.2015' ending '31.12.2025' EVERY 1 MONTH) in SPACE_AMC_A,SPACE_AMC_B,SPACE_AMC_C,SPACE_AMC_D,SPACE_AMC_E,SPACE_AMC_F;
create index AMC.INDEX_BLB_CMS_LINK_REPLACEMENT_ARCHIVE_SV_ID_GW_KONTO on AMC.TABLE_NLB_CMS_LINK_REPLACEMENT_ARCHIVE (SV_ID, GW_KONTO);
call STG.TEST_PROC_LOAD_AND_DROP_BACKUP_FOR('AMC','TABLE_BLB_CMS_LINK_REPLACEMENT_ARCHIVE');
-- CI END FOR ALL TAPES

-- SWITCH Views erstellen
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_NLB_CMS_LINK_REPLACEMENT_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_BLB_CMS_LINK_REPLACEMENT_CURRENT');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_NLB_CMS_LINK_REPLACEMENT_ARCHIVE');
call STG.TEST_PROC_DROP_AND_CREATE_SWITCH('AMC','TABLE_BLB_CMS_LINK_REPLACEMENT_ARCHIVE');

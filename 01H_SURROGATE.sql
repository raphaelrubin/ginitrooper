------------------------------------------------------------------------------------------------------------------------
/* Portfolio SURROGATE
 *
 * Portfolio ist die Basis für alle AMC Tapes bestehend aus KR Zulieferung und SPOT Erweiterung. Hier stehen Kunden und
 * Konten, welche für AMC relevant sind, also alle Konten von Kunden aus dem Bereich Schiffe/Flugzeuge. Hier wurden auch
 * alternative Kunden- und Kontennummern gesammelt.
 *
 * VIEW_SURROGATE ist ein manuelles Mapping von alten FACILITY_IDs auf neue FACILITY_IDs.
 *
 * Es gibt mehrere PORTFOLIO_PRE Dateien, in denen sich manuell befüllte Views befinden. Diese müssen manuell
 * aktualisiert werden. Die Reihenfolge zum Ausführen ist:
 *
 * 1) PORTFOLIO_PRE Dateien:
 *   - SURROGATE
 *   - FACILITY_CBB_TO_NLB
 *   - CLIENT_CBB_TO_NLB
 * 2) BW_STAMMDATEN
 * 3) PORTFOLIO
 */
------------------------------------------------------------------------------------------------------------------------

-- VIEW erstellen
------------------------------------------------------------------------------------------------------------------------
drop view CALC.VIEW_SURROGATE;
create or replace view CALC.VIEW_SURROGATE as
with
    ALT_TO_NEU as ( select * from SMAP.SURROGATE_FACILITY_OLD_TO_NEW)

, result (FACILITY_ID_INIT,FACILITY_ID_NEW,VALID_FROM_DATE,EVOLUTION) as (
    select FACILITY_ID_OLD,FACILITY_ID_NEW,VALID_FROM_DATE,1
    from ALT_TO_NEU
    union all
    select B.FACILITY_ID_INIT ,A.FACILITY_ID_NEW,A.VALID_FROM_DATE,EVOLUTION +1
    from ALT_TO_NEU as A, result as B --rekursiver ausruf
    where A.FACILITY_ID_OLD=B.FACILITY_ID_NEW
)
select A.FACILITY_ID_INIT,A.FACILITY_ID_NEW,DATE(A.VALID_FROM_DATE) as VALID_FROM_DATE,DATE(B.VALID_FROM_DATE) as VALID_to_DATE from (
                  select *, row_number() over (partition by FACILITY_ID_INIT,VALID_FROM_DATE order by EVOLUTION desc) as NBR from RESULT
              ) as A
    left join ALT_TO_NEU as B on A.FACILITY_ID_NEW=B.FACILITY_ID_OLD
where 1=1
    and NBR =1 --jedes Konto zeigt nur auf seinen letzten Nachfolger innerhalb seines Geltungsbereiches
    --and EVOLUTION > 1
;
------------------------------------------------------------------------------------------------------------------------

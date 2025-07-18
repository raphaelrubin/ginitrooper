-- VIEW erstellen
drop view CALC.VIEW_FACILITY_RATING_FVC;
create or replace view CALC.VIEW_FACILITY_RATING_FVC as
with basis as (
    select PORTFOLIO.CUT_OFF_DATE
         , PORTFOLIO.FACILITY_ID
         ,coalesce(NLB.BWLKEY,BLB.BWLKEY) as FACILITY_ID_RAT
         ,coalesce(NLB.DATE, BLB.DATE) as RATING_DATE
         , case
               when coalesce(NLB.RH_RATING_SUB_MODUL, BLB.RH_RATING_SUB_MODUL) = 'CRP_1_PRI'
                   then 11
               when coalesce(NLB.RH_RATING_SUB_MODUL, BLB.RH_RATING_SUB_MODUL) = 'FLU_SAF'
                   then 11
               when coalesce(NLB.RH_RATING_SUB_MODUL, BLB.RH_RATING_SUB_MODUL) = 'LEA_lm'
                   then 15
               when coalesce(NLB.RH_RATING_SUB_MODUL, BLB.RH_RATING_SUB_MODUL) = 'PRF_AD'
                   then 9
               when coalesce(NLB.RH_RATING_SUB_MODUL, BLB.RH_RATING_SUB_MODUL) = 'PRF_RE'
                   then 9
               when coalesce(NLB.RH_RATING_SUB_MODUL, BLB.RH_RATING_SUB_MODUL) = 'SCH' then 18
               else NULL
        end                                                                                          as STANDARD_PARAMETER_RATING
         , case
               when coalesce(NLB.RH_RATING_SUB_MODUL, BLB.RH_RATING_SUB_MODUL) = 'CRP_1_PRI'
                   then '34.00'
               when coalesce(NLB.RH_RATING_SUB_MODUL, BLB.RH_RATING_SUB_MODUL) = 'FLU_SAF'
                   then '21.00'
               when coalesce(NLB.RH_RATING_SUB_MODUL, BLB.RH_RATING_SUB_MODUL) = 'LEA_lm'
                   then '48.00'
               when coalesce(NLB.RH_RATING_SUB_MODUL, BLB.RH_RATING_SUB_MODUL) = 'PRF_AD'
                   then '33.00'
               when coalesce(NLB.RH_RATING_SUB_MODUL, BLB.RH_RATING_SUB_MODUL) = 'PRF_RE'
                   then '33.00'
               when coalesce(NLB.RH_RATING_SUB_MODUL, BLB.RH_RATING_SUB_MODUL) = 'SCH'
                   then '16.00'
               else NULL
        end                                                                                          as STANDARD_PARAMETER_LGD_IN_PROZENT
         , case
               when coalesce(NLB.RH_RATING_SUB_MODUL, BLB.RH_RATING_SUB_MODUL) = 'CRP_1_PRI'
                   then '66.00'
               when coalesce(NLB.RH_RATING_SUB_MODUL, BLB.RH_RATING_SUB_MODUL) = 'FLU_SAF'
                   then '54.00'
               when coalesce(NLB.RH_RATING_SUB_MODUL, BLB.RH_RATING_SUB_MODUL) = 'LEA_lm'
                   then '121.00'
               when coalesce(NLB.RH_RATING_SUB_MODUL, BLB.RH_RATING_SUB_MODUL) = 'PRF_AD'
                   then '43.00'
               when coalesce(NLB.RH_RATING_SUB_MODUL, BLB.RH_RATING_SUB_MODUL) = 'PRF_RE'
                   then '43.00'
               when coalesce(NLB.RH_RATING_SUB_MODUL, BLB.RH_RATING_SUB_MODUL) = 'SCH'
                   then '135.00'
               else NULL
        end                                                                                          as STANDARD_PARAMETER_RISIKOGEWICHT_IN_PROZENT
         , coalesce(NLB.RH_RATING_SUB_MODUL, BLB.RH_RATING_SUB_MODUL)                                                         as RH_RATING_SUB_MODUL
         , coalesce(NLB.RH_RATING_MODUL_ID, BLB.RH_RATING_MODUL_ID)                                                          as RH_RATING_MODUL_ID
         , coalesce(NLB.RH_RATING_DATUM, BLB.RH_RATING_DATUM)                                                                as RH_RATING_DATUM
         , coalesce(NLB.RH_RATING_ID, BLB.RH_RATING_ID)                                                                     as RH_RATING_ID
         , coalesce(NLB.RH_RATING_ID_ZUGANG, BLB.RH_RATING_ID_ZUGANG)                                                         as RH_RATING_ID_ZUGANG
         , coalesce(NLB.RH_RATING_QUELLE, BLB.RH_RATING_QUELLE)                                                             as RH_RATING_QUELLE
         , coalesce(NLB.DIGP_RATING_DATUM, BLB.DIGP_RATING_DATUM)                                                           as DIGP_RATING_DATUM
         , coalesce(NLB.DIGP_RATING_ID, BLB.DIGP_RATING_ID)                                                                 as DIGP_RATING_ID
         , coalesce(NLB.DIGP_RATING_MODUL_ID, BLB.DIGP_RATING_MODUL_ID)                                                        as DIGP_RATING_MODUL_ID
         , coalesce(NLB.DIGP_RATING_SUB_MODUL, BLB.DIGP_RATING_SUB_MODUL)                                                       as DIGP_RATING_SUB_MODUL
         , coalesce(NLB.DKTO_RATING_DATUM, BLB.DKTO_RATING_DATUM)                                                           as DKTO_RATING_DATUM
         , coalesce(NLB.DKTO_RATING_ID, BLB.DKTO_RATING_ID)                                                                 as DKTO_RATING_ID
         , coalesce(NLB.DKTO_RATING_MODUL_ID, BLB.DKTO_RATING_MODUL_ID)                                                        as DKTO_RATING_MODUL_ID
         , coalesce(NLB.DKTO_RATING_SUB_MODUL, BLB.DKTO_RATING_SUB_MODUL)                                                       as DKTO_RATING_SUB_MODUL
         ,coalesce(NLB.LGD_PRZ,BLB.LGD_PRZ)                                                                                 as LGD_IN_PROZENT
         ,coalesce(NLB.RISIKOGEWICHT_PRZ,BLB.RISIKOGEWICHT_PRZ)                                                             as RISIKOGEWICHT_IN_PROZENT
    from CALC.SWITCH_PORTFOLIO_ARCHIVE as PORTFOLIO --todo: Nicht fertig Achtung
             left join NLB.SPOT_RATING_KONTO_CURRENT as NLB
                       on NLB.CUT_OFF_DATE = PORTFOLIO.CUT_OFF_DATE and NLB.BWLKEY = PORTFOLIO.FACILITY_ID
             left join BLB.SPOT_RATING_KONTO_CURRENT as BLB
                       on BLB.CUT_OFF_DATE = PORTFOLIO.CUT_OFF_DATE and BLB.BWLKEY = PORTFOLIO.FACILITY_ID
)
select distinct
    CUT_OFF_DATE
    ,FACILITY_ID
    ,RATING_DATE
   -- ,FACILITY_ID_RAT
    ,first_value (coalesce(RH_RATING_ID,DIGP_RATING_ID,DKTO_RATING_ID,STANDARD_PARAMETER_RATING))
        over (partition by FACILITY_ID,CUT_OFF_DATE order by coalesce(RH_RATING_DATUM,DIGP_RATING_DATUM,DKTO_RATING_DATUM)) as RATING_ID
    ,first_value (coalesce(LGD_IN_PROZENT,STANDARD_PARAMETER_LGD_IN_PROZENT)) over (partition by FACILITY_ID,CUT_OFF_DATE order by coalesce(RH_RATING_DATUM,DIGP_RATING_DATUM,DKTO_RATING_DATUM)) as LGD_IN_PRoZENT
    ,first_value (coalesce(RISIKOGEWICHT_IN_PROZENT,STANDARD_PARAMETER_RISIKOGEWICHT_IN_PROZENT)) over (partition by FACILITY_ID,CUT_OFF_DATE order by coalesce(RH_RATING_DATUM,DIGP_RATING_DATUM,DKTO_RATING_DATUM)) as RISIKOGEWICHT_IN_PROZENT
    --,Current_USER                                                                            as CREATED_USER      -- Letzter Nutzer, der diese Tabelle gebaut hat.
    --,Current_TIMESTAMP                                                                       as CREATED_TIMESTAMP  -- Neuester Zeitstempel, wann diese Tabelle zuletzt gebaut wurde.
from Basis
;
--#SET TERMINATOR ;
drop view CALC.VIEW_LIQ_NACHFOLGE;
create or replace view CALC.VIEW_LIQ_NACHFOLGE as
with
--      Rebookings zunächst rausgenommen, da inhaltliche Relevanz unklar. Wenn von allen Rebookings auf das neueste
--      Outstanding am selben Tag gebucht wird, dann brauchen wir eigentlich nur die Info zum neuesten Outstanding,
--      denn die anderen Outstandings sollten ja nicht mehr relevant sein. Falls diese Einschätzung falsch ist, müssen wir hier nochmal ran.
--      Deshlab auskommentierten Teil lassen.
--      REBOOKINGS as (
--          --Ziehe hier auch die Reebookings raus, ohne Rekursion (um nicht in einem Loop zu landen)
--          --die Verbindung rebooking-outstanding zu newoutstanding ist dabei immer schon gegeben in old_new_oustandings
--          select
--                 BESTANDSDATUM
--                 ,'0009-33-00'||REBOOKING_OUTSTANDING_4||'-31-0000000000' as OLD_OUTSTANDING
--          ,'0009-33-00'||REBOOKING_OUTSTANDING_3||'-31-0000000000' as NEW_OUTSTANDING
--          from NLB.LIQ_OUTSTANDING_EROEFFNUNG
--          where REBOOKING_TRANSACTION = 'Yes' and REBOOKING_OUTSTANDING_4 is not n
--          union
--                   select
--                 BESTANDSDATUM
--                 ,'0009-33-00'||REBOOKING_OUTSTANDING_3||'-31-0000000000' as OLD_OUTSTANDING
--          ,'0009-33-00'||NEW_OUTSTANDING||'-31-0000000000' as NEW_OUTSTANDING
--          from NLB.LIQ_OUTSTANDING_EROEFFNUNG
--          where REBOOKING_TRANSACTION = 'Yes' and REBOOKING_OUTSTANDING_3 is not null
--
--                   union
--                   select
--                 BESTANDSDATUM
--                 ,'0009-33-00'||REBOOKING_OUTSTANDING_2||'-31-0000000000' as OLD_OUTSTANDING
--          ,'0009-33-00'||NEW_OUTSTANDING||'-31-0000000000' as NEW_OUTSTANDING
--          ,2 as REBOOKING_EVOLUTION
--          from NLB.LIQ_OUTSTANDING_EROEFFNUNG
--          where REBOOKING_TRANSACTION = 'Yes' and REBOOKING_OUTSTANDING_2 is not null
--
--                   union
--                   select
--                 BESTANDSDATUM
--                 ,'0009-33-00'||REBOOKING_OUTSTANDING_1||'-31-0000000000' as OLD_OUTSTANDING
--          ,'0009-33-00'||NEW_OUTSTANDING||'-31-0000000000' as NEW_OUTSTANDING
--          ,1 as REBOOKING_EVOLUTION
--          from NLB.LIQ_OUTSTANDING_EROEFFNUNG
--          where REBOOKING_TRANSACTION = 'Yes' and REBOOKING_OUTSTANDING_1 is not null
 --    ),
    OLD_NEW_OUTSTANDINGS as (
        select
                BESTANDSDATUM
                ,'0009-33-00'||OLD_OUTSTANDING||'-31-0000000000' as OLD_OUTSTANDING
                ,'0009-33-00'||NEW_OUTSTANDING||'-31-0000000000' as NEW_OUTSTANDING
         ,0 as REBOOKING_EVOLUTION
         from NLB.LIQ_OUTSTANDING_EROEFFNUNG
         where OLD_OUTSTANDING is not null
    )
,
     ALT_TO_NEU as(
        -- select OLD_OUTSTANDING, NEW_OUTSTANDING, BESTANDSDATUM from REBOOKINGS
        -- union all
         select OLD_OUTSTANDING, NEW_OUTSTANDING, BESTANDSDATUM from OLD_NEW_OUTSTANDINGS
     )
select distinct * from ALT_TO_NEU
;
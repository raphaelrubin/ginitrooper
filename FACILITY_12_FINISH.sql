----------------------
-- FACILITY für PWC --
----------------------
-- CI START FOR ALL TAPES
-- Drop View
drop view AMC.TAPE_FACILITY_FINISH;
-- View erstellen
create or replace view AMC.TAPE_FACILITY_FINISH as
select *
from AMC.TABLE_FACILITY_CURRENT
;
grant select on AMC.TAPE_FACILITY_FINISH to group NLB_MW_ADAP_S_GNI_TROOPER;
-- CI END FOR ALL TAPES
cd "D:\david\SPJ_microenterprises\programs"
local country "SEN"
local lower_country = lower("`country'")
local file "../data/`country'/2021/s00_me_sen`lower_country.dta'"


tempfile temp temp2 temp_enterprise temp2_enterprise 
use "../data/SEN/2018/s10_2_me_sen2018", replace 

drop if s10q58==2  // drop inactive enterprises 
drop if s10q15__0<0 | s10q15__0==.  

** how should we break out enterprises 
** 6816 operating enterprises 
unique vague grappe menage s10q17a s10q12a_1
** 4199 unique households 
unique grappe menage 
** 6526 households plus main operator 
unique vague grappe menage s10q15__0
** 5480 households plus main activity 
unique vague grappe menage s10q17a 
** 6610 households plus main activity plus year established  
unique vague grappe menage s10q17a s10q20 
** main owner plus main activity plus year established 6785 
unique vague grappe s10q15__0 menage s10q17a s10q20 

** let's do it by main operator initially 

gen nonag_id=strofreal(grappe,"%3.0f")+"_"+strofreal(menage,"%02.0f")+"_"+strofreal(s10q15__0,"%02.0f") 


gen num_emp=max(s10q62a_1,0)+max(s10q62a_2,0)  
gen num_hhemp=0 
foreach person of numlist 1/14 {
replace num_hhemp=num_hhemp+1 if s10q61a_`person'<. 
}
 
sort nonag_id  



rename s10q62d_1 out_hh_worker_men_salary
rename s10q62d_2 out_hh_worker_women_salary
rename s10q62d_3 out_hh_worker_boys_salary
rename s10q62d_4 out_hh_worker_girls_salary

egen var1 = total(out_hh_worker_men_salary), by(nonag_id)
egen var2 = total(out_hh_worker_women_salary), by(nonag_id)
egen var3 = total(out_hh_worker_boys_salary), by(nonag_id)
egen var4 = total(out_hh_worker_girls_salary), by(nonag_id)

egen val_hired_labor = rowtotal(var1 var2 var3 var4)
drop var1 var2 var3 var4
 
gen value_machines=0
replace value_machines=s10q36 if s10q35==1

gen value_vehicles=0 
replace value_vehicles=s10q38 if s10q37==1

gen  value_furniture=0 
replace value_furniture=s10q40 if s10q39==1

gen value_other=0 
replace value_other=s10q42 if s10q41==1 

egen value_total=rowtotal(value_*)

gen owns_assets=(value_total>0 & value_total<.)
egen revenue=rowtotal(s10q46 s10q48 s10q50) 
replace s10q55=s10q55/12 
replace s10q56=s10q56/12 
replace s10q57=s10q57/12 
egen expenses=rowtotal(s10q47 s10q49 s10q51 s10q52-s10q57 val_hired_labor) 

gen profit=revenue-expenses 


egen max_rev=max(revenue), by(nonag_id)
egen N_businesses=sum(1), by(nonag_id)
gen place=s10q23
gen financing=s10q34
gen year_est=s10q20 

gen firm_keeps_accounts    = inlist(s10q29, 1, 2)
gen firm_has_fisc_id       = (s10q30 == 1)
gen firm_in_trade_register = (s10q31 == 1)


gsort nonag_id -revenue -value_total 
bys nonag_id: keep if _n==1 




recode s10q17a (1/2=1 "Ag and extractives") (3=2 "Manufacturing") (4/5=3 "Utilities and construction") (6/7=5 "Retail") (8=6 "Transport") (17=7 "Personal services") (9/16 18=9 "Other"), gen(sector)
label val place s10q23 
label val financing s10q34 

gen share_revenue_resale=s10q46/revenue 
gen share_revenue_processed=s10q48/revenue 
gen share_revenue_services=s10q50/revenue  

label var s10q45a "Problem: Supply of raw materials"
label var s10q45b "Problem: Lack of customers"
label var s10q45c "Problem: Too much competition"
label var s10q45d "Problem: Accessing credit"
label var s10q45e "Problem: Recruiting personnel"
label var s10q45f "Problem: Insufficient space"
label var s10q45g "Problem: Accessing equipment"
label var s10q45h "Problem: Technical manufacturing difficulties"
label var s10q45i "Problem: Technical management difficulties"
label var s10q45j "Problem: Electricity access"
label var s10q45k "Problem: Power outages"
label var s10q45l "Problem: Other infrastructure (water, phone)"
label var s10q45m "Problem: Internet-related"
label var s10q45n "Problem: Too much insecurity"
label var s10q45o "Problem: Too much regulation and taxes"
label define s10q45 1 "Yes" 2 "No" 3 "N/A"
label values s10q45? s10q45 


save `temp' 

*** 2021 

use "../data/SEN/2021/s10b_me_sen2021", replace 
drop if s10q58==2  // drop inactive enterprises 
drop if s10q15__0<0 | s10q15__0==. 

gen nonag_id=strofreal(grappe,"%3.0f")+"_"+strofreal(menage,"%02.0f")+"_"+strofreal(s10q15__0,"%02.0f") 


** let's do it by main operator initially 

gen numind=s10q15__0 

gen num_emp=max(s10q62a_1,0)+max(s10q62a_2,0)  
gen num_hhemp=0 
foreach person of numlist 1/8 {
replace num_hhemp=num_hhemp+1 if s10q61a_`person'<. 
}

gen value_machines=0
replace value_machines=s10q36 if s10q35==1

gen value_vehicles=0 
replace value_vehicles=s10q38 if s10q37==1

gen  value_furniture=0 
replace value_furniture=s10q40 if s10q39==1

gen value_other=0 
replace value_other=s10q42 if s10q41==1 

egen value_total=rowtotal(value_*)

gen owns_assets=(value_total>0 & value_total<.)

egen revenue=rowtotal(s10q46 s10q48 s10q50) 
egen expenses=rowtotal(s10q47 s10q49 s10q51 s10q52-s10q57) 
gen profit=revenue-expenses 


egen max_rev=max(revenue), by(nonag_id)
egen N_businesses=sum(1), by(nonag_id)
gen place=s10q23  
gen financing=s10q34  
gen year_est=s10q20   
gen firm_keeps_accounts    = inlist(s10q29, 1, 2)
gen firm_has_fisc_id       = (s10q30 == 1)
gen firm_in_trade_register = (s10q31 == 1)

gsort nonag_id -revenue -value_total 
bys nonag_id: keep if _n==1 
recode s10q17a (1/2=1 "Ag and extractives") (3=2 "Manufacturing") (4/5=3 "Utilities and construction") (6/7=5 "Retail") (8=6 "Transport") (17=7 "Personal services") (9/16 18=9 "Other"), gen(sector)


count 
* collapse (sum) num_emp value* revenue expenses profit s10q46 s10q48 s10q50 (max) owns_assets, by(nonag_id) 


gen share_revenue_resale=s10q46/revenue 
gen share_revenue_processed=s10q48/revenue 
gen share_revenue_services=s10q50/revenue  

rename * *_2021 
rename nonag_id_2021 nonag_id 


save `temp2'








* This code shows that about half of the people listed as the primary business owner are also running a business 
** start with full individual roster for 2018 

use "../data/SEN/2018/ehcvm_individu_sen2018", replace 
keep grappe menage numind hhweight sexe age hhid zae milieu csp activ7j educ_hi alfab educ_scol 
rename sexe sexe_2018 
rename educ_hi educ_hi_2018 
rename alfab alfab_2018  
rename educ_scol educ_scol_2018 
rename age age_2018 
dis "all individuals in 2018"
count 
rename activ7j activ7j_2018 
rename csp hcsp_2018 
rename hhweight hhweight_2018 
** merge in individuals from 2021 at individual level 
qui merge n:1 grappe menage numind using "../data/SEN/2021/ehcvm_individu_sen2021", keep(1 2 3) 
gen panel_ind=_m==3 
drop _m 
dis "panel individuals"
count 

rename activ7j activ7j_2021 
rename csp hcsp_2021 
rename hhweight hhweight_2021 


gen nonag_id=strofreal(grappe,"%3.0f")+"_"+strofreal(menage,"%02.0f")+"_"+strofreal(numind,"%02.0f") 
merge 1:1 nonag_id using `temp', keep(1 3) 

gen ent_2018=(_m==3)
drop _m 
dis "number of microenterprise proprieters in 2018"
* unique grappe menage vague numind 
unique nonag_id if ent_2018==1 

** merge in enttrepeneurs from 2021 
qui merge 1:1 nonag_id using `temp2', keep(1 3)
gen ent_2021=(_m==3)
tab ent_2018 panel_ind 
gen panel_ent=(ent_2021==1 & ent_2018==1)
tab ent_2018 panel_ent 

/* out of 6,522 enterpreneurs in 2018, 5090 are in the survey in 2021 and 2690 are panel entrepeneurs */ 

drop _m 

qui merge n:1 hhid using "../data/SEN/2018/ehcvm_menage_sen2018", keep(1 3) 
tab _m 
drop _m 

qui merge n:1 hhid using "../data/SEN/2018/ehcvm_welfare_sen2018", keep(1 3)  
tab _m 

gen age_diff=age - age_2018 
count if age_diff>=2 & age_diff <=4 
count if age_diff <. 


save "../intermediate_data/SEN_entrepreneurs", replace 

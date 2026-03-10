

tempfile temp1 temp2 temp3 temp4 

local root "\row_data\2021_2022"
use "`root'\\s20b_1_me_sen2021.dta", clear
duplicates report grappe menage
sort grappe menage 

keep (grappe ///
	menage ///
	s20bq01   ///
    s20bq03   ///
    s20bq09   ///
    s20bq10   ///
    s20bq11   ///
    s20bq13a  ///
    s20bq13b2 ///
    s20bq13c  ///
    s20bq13d  ///
    s20bq13e  ///
    s20bq13f  ///
    s20bq13g  ///
    s20bq13h  ///
    s20bq13i  ///
    s20bq13j  ///
    s20bq14a  ///
    s20bq14b  ///
    s20bq14c  ///
    s20bq18a  ///
    s20bq18b  ///
    s20bq18c  ///
    s20bq18d  ///
    s20bq18e  ///
    s20bq18f  ///
    s20bq18g  )
*-----------------------------
* Rename des variables
*-----------------------------
rename ( ///
    s20bq01   ///
    s20bq03   ///
    s20bq09   ///
    s20bq10   ///
    s20bq11   ///
    s20bq13a  ///
    s20bq13b2 ///
    s20bq13c  ///
    s20bq13d  ///
    s20bq13e  ///
    s20bq13f  ///
    s20bq13g  ///
    s20bq13h  ///
    s20bq13i  ///
    s20bq13j  ///
    s20bq14a  ///
    s20bq14b  ///
    s20bq14c  ///
    s20bq18a  ///
    s20bq18b  ///
    s20bq18c  ///
    s20bq18d  ///
    s20bq18e  ///
    s20bq18f  ///
    s20bq18g  ///
) ( ///
    human_rights_respected       ///
    satis_democracy              ///
    local_auth_power             ///
    info_policies_budgets        ///
    corruption_problem           ///
    corr_civil_servants          ///
    corr_police                  ///
    corr_tax_customs             ///
    corr_justice_staff           ///
    corr_president               ///
    corr_ministers               ///
    corr_mps                     ///
    corr_local_auth              ///
    corr_relig_auth              ///
    corr_trad_leaders            ///
    anticorr_org_exists          ///
    anticorr_govt_effective      ///
    anticorr_info_available      ///
    member_local_assoc           ///
    member_relig_assoc           ///
    member_prof_assoc            ///
    member_family_assoc          ///
    member_saving_assoc          ///
    member_political_party       ///
    member_other_assoc           ///
)

*-----------------------------
* Labels de variables
*-----------------------------
label var human_rights_respected      "Perception: human rights respected"
label var satis_democracy             "Satisfaction with democracy functioning"
label var local_auth_power            "Perception: local authorities have power"
label var info_policies_budgets       "Info on policies/budgets from authorities"
label var corruption_problem          "Corruption is a problem in the country"

label var corr_civil_servants         "Civil servants involved in corruption"
label var corr_police                 "Police involved in corruption"
label var corr_tax_customs            "Tax/customs agents involved in corruption"
label var corr_justice_staff          "Justice staff involved in corruption"
label var corr_president              "President involved in corruption"
label var corr_ministers              "Ministers involved in corruption"
label var corr_mps                    "MPs involved in corruption"
label var corr_local_auth             "Local authorities involved in corruption"
label var corr_relig_auth             "Religious authorities involved in corruption"
label var corr_trad_leaders           "Traditional leaders involved in corruption"

label var anticorr_org_exists         "Anti-corruption body exists"
label var anticorr_govt_effective     "Government effective vs. corruption"
label var anticorr_info_available     "Information on anti-corruption efforts"

label var member_local_assoc          "Member of local association"
label var member_relig_assoc          "Member of religious association"
label var member_prof_assoc           "Member of professional association"
label var member_family_assoc         "Member of family association"
label var member_saving_assoc         "Member of savings association"
label var member_political_party      "Member of political party"
label var member_other_assoc          "Member of other associations"


local vars member_local_assoc member_relig_assoc member_prof_assoc member_family_assoc member_saving_assoc member_political_party member_other_assoc
capture label drop yesno
label define yesno 0 "otherwise" 1 "yes"

foreach var of local vars {
    recode `var' (1 = 1) (2 3 = 0)
    label values `var' yesno
    codebook `var'
}


sort grappe menage 
save `temp1', replace




use "`root'\\s20b_2_me_sen2021.dta", clear
duplicates report grappe menage
duplicates report grappe menage s20bq02
keep grappe menage s20bq02 s20bq02b
sort grappe menage s20bq02
duplicates report grappe menage s20bq02
sort grappe menage s20bq02
reshape wide s20bq02b, i(grappe menage) j(s20bq02)
rename s20bq02b1 dem_free_expression
rename s20bq02b2 dem_free_press
rename s20bq02b3 dem_equal_law
rename s20bq02b4 dem_free_politics
rename s20bq02b5 dem_free_elections
rename s20bq02b6 dem_free_travel
rename s20bq02b7 dem_free_religion
rename s20bq02b8 dem_free_association
rename s20bq02b9 dem_no_discrimination

label var dem_free_expression    "Freedom of expression respected"
label var dem_free_press         "Freedom of the press respected"
label var dem_equal_law          "Equal treatment before the law respected"
label var dem_free_politics      "Political freedom (choice of party) respected"
label var dem_free_elections     "Free and fair elections respected"
label var dem_free_travel        "Freedom of movement respected"
label var dem_free_religion      "Freedom of religion respected"
label var dem_free_association   "Freedom of association respected"
label var dem_no_discrimination  "Absence of discrimination respected"



duplicates report grappe menage 
sort grappe menage 
save `temp2', replace


use "`root'\\s20b_3_me_sen2021.dta", clear
duplicates report grappe menage
duplicates report grappe menage s20bq05
keep grappe menage s20bq05 s20bq05a
sort grappe menage s20bq05
reshape wide s20bq05a, i(grappe menage) j(s20bq05)
rename s20bq05a1 disc_ethnicity
rename s20bq05a2 disc_region
rename s20bq05a3 disc_religion
rename s20bq05a4 disc_poverty
rename s20bq05a5 disc_gender
rename s20bq05a6 disc_disability

label var disc_ethnicity   "Perceived discrimination based on ethnicity"
label var disc_region      "Perceived discrimination based on region of origin"
label var disc_religion    "Perceived discrimination based on religion"
label var disc_poverty     "Perceived discrimination based on economic situation"
label var disc_gender      "Perceived discrimination based on gender"
label var disc_disability  "Perceived discrimination based on disability"

local vars 	disc_ethnicity disc_region disc_religion disc_poverty ///
    disc_gender disc_disability 
capture label drop yesno
label define yesno 0 "otherwise" 1 "yes"

foreach var of local vars {
    recode `var' (1 = 1) (2 = 0)
    label values `var' yesno
    codebook `var'
}	
sort grappe menage 
save `temp3', replace





use "`root'\\s20c_me_sen2021.dta", clear
codebook s20cq01 s20cq07a s20cq07b s20cq07c s20cq07d
keep grappe menage s20cq01 s20cq07a s20cq07b s20cq07c s20cq07d

*-----------------------------
* Rename des variables
*-----------------------------
rename ( ///
    s20cq01  ///
    s20cq07a ///
    s20cq07b ///
    s20cq07c ///
    s20cq07d ///
) ( ///
    night_safety_neighborhood     ///
    trust_police_justice          ///
    trust_gendarmerie_justice     ///
    trust_comm_leader_justice     ///
    trust_relig_leader_justice    ///
)

recode night_safety_neighborhood (4 5 = 4)
*-----------------------------
* Labels de variables
*-----------------------------
label var night_safety_neighborhood ///
    "Perceived safety in neighborhood at night"

label var trust_police_justice ///
    "Trust in police to deliver justice in case of aggression"

label var trust_gendarmerie_justice ///
    "Trust in gendarmerie to deliver justice in case of aggression"

label var trust_comm_leader_justice ///
    "Trust in community leaders to deliver justice in case of aggression"

label var trust_relig_leader_justice ///
    "Trust in religious leaders to deliver justice in case of aggression"

sort grappe menage 
save `temp4', replace

	   
	   
	   
*******************************
** MERGING
*******************************

use "\SEN_entrepreneurs.dta", clear 
*preserve
keep if panel_ind==1
drop if age<=15 
duplicates report grappe menage
sort grappe menage
capture drop _merge
merge m:1 grappe menage using `temp1', nogenerate keep(1 3)
merge m:1 grappe menage using `temp2', nogenerate keep(1 3)
merge m:1 grappe menage using `temp3', nogenerate keep(1 3)
merge m:1 grappe menage using `temp4',  nogenerate keep(1 3)


***********************************
** GET stat on gov indicators
********************************
preserve
bysort grappe menage: keep if _n == 1
count
		
local table    "Table1"
local sheetcol `"sheetcol("B")"'	

local vars human_rights_respected satis_democracy ///
    corruption_problem anticorr_govt_effective member_relig_assoc ///
    member_prof_assoc member_saving_assoc ///
    dem_free_expression dem_free_press dem_equal_law dem_free_politics ///
    dem_free_elections dem_free_travel dem_free_religion ///
    dem_free_association dem_no_discrimination ///
    disc_ethnicity disc_region disc_religion disc_poverty ///
    disc_gender disc_disability ///
    night_safety_neighborhood trust_police_justice ///
    trust_gendarmerie_justice trust_comm_leader_justice ///
    trust_relig_leader_justice


local startrow = 3

foreach var of local vars {
    
    capture drop ones
    gen ones = 1
    label define ones 1 "`var'", replace
    label values ones ones 
    
    tabexcel ones `var' using "Tables.xlsx" [aw=hhweight], ///
        nofreq row sheet("`table'") fmt("0.0") ///
        sheetrow(`startrow') nocolheader `sheetcol'
    
    local startrow = `startrow' + 3
}
restore
**************************************************************************



*******************************************
* Gov indicators and Performance 
*******************************************


gen lnprofit_2021=max(log(profit_2021),0) if profit_2021<. 
sum lnprofit_2021 
hist lnprofit_2021
kdensity lnprofit_2021
count 

local vars human_rights_respected satis_democracy ///
    corruption_problem anticorr_govt_effective ///
    dem_free_expression dem_free_press dem_equal_law dem_free_politics ///
    dem_free_elections dem_free_travel dem_free_religion ///
    dem_free_association dem_no_discrimination
capture label drop yesno
label define yesno_2 0 "otherwise" 1 "yes"

foreach var of local vars {
    recode `var' (1 2 = 1) (3 4 = 0)
    label values `var' yesno_2
    codebook `var'
}

recode night_safety_neighborhood (1 2= 1) (3 4 5 = 0)
lab val night_safety_neighborhood yesno
codebook night_safety_neighborhood

local vars trust_police_justice ///
    trust_gendarmerie_justice trust_comm_leader_justice ///
    trust_relig_leader_justice
foreach var of local vars {
    recode `var' (1 2 3 = 1) (4 5 = 0)
    label values `var' yesno_2
    codebook `var'
}

	
gen freedom = (dem_free_expression == 1 | dem_free_press == 1 | dem_equal_law == 1 | dem_free_politics == 1 | dem_free_elections == 1 | dem_free_travel == 1 | dem_free_religion == 1 | dem_free_association == 1 | dem_no_discrimination)

gen discrimination = (disc_ethnicity == 1 | disc_region == 1 | disc_religion == 1 | disc_poverty == 1 | disc_gender == 1 | disc_disability == 1 )

gen safety = (night_safety_neighborhood == 1 | trust_police_justice == 1 | trust_gendarmerie_justice == 1 |  trust_comm_leader_justice == 1 | trust_relig_leader_justice == 1 )

local govvars human_rights_respected satis_democracy ///
    corruption_problem anticorr_govt_effective freedom discrimination safety

	
local outfile "kwallis_profit_governance.xlsx"
putexcel set "`outfile'", sheet("profit_2021") replace
putexcel A1 = "variable" ///
        B1 = "mean_profit_cat0" ///
        C1 = "mean_profit_cat1" ///
        D1 = "pvalue_kwallis"

local row = 2

foreach v of local govvars {

    kwallis lnprofit_2021, by(`v')
    local p = r(p)

    quietly summarize lnprofit_2021 [aw=hhweight] if `v' == 0 & !missing(lnprofit_2021)
    local mean0 = r(mean)

    quietly summarize lnprofit_2021 [aw=hhweight] if `v' == 1 & !missing(lnprofit_2021)
    local mean1 = r(mean)

    putexcel A`row' = "`v'" ///
            B`row' = `mean0' ///
            C`row' = `mean1' ///
            D`row' = (`p'), nformat("0.000")

    local ++row
}
display "Results exported into `outfile'"







*******************************************************
* DESIGN THE TFP MEASURE
*********************************************************

	  
use "C:\Users\djafo\OneDrive\Consultancy\Contract_2\work_on_david_data\SEN_entrepreneurs.dta", clear 
*preserve
keep if panel_ind==1
drop if age<=15 
keep if ent_2018==1 & ent_2021 == 1 
count

recode age (15/29=1 "15-29") (30/44=2 "30-44") (45/64=3 "45-64") (64/120=4 "65+"), gen(age_cat)
recode educ_hi (1=1 "Less than primary") (3=2 "Less than Secondary") (4/9 = 3 "Secondary+"), gen(educ)
replace educ=1 if educ_scol==1 
replace educ=3 if educ_scol>1 & educ_scol<. 
xtile pcexpQ=pcexp [aw=hhweight], nq(5)
recode year_est (1940/1999.5=1 "<2000") (2000/2009=2 "2000-2009") (2010/2014 = 3 "2010-2014") (2015/2019 = 4 "2015-2019"), gen(firm_age)
recode num_emp (0=0 "0") (1=1 "1") (2/100=2 "2+"), gen(emp_cat)
recode num_hhemp (0=0 "0") (1=1 "1") (2/100=2 "2+"), gen(emphh_cat)



global main_var revenue revenue_2021 value_total value_total_2021 expenses expenses_2021 val_hired_labor val_hired_labor_2021

global baseline_var sexe_2018 age_cat milieu zae ethnie alfa2 educ internet elec_ac pcexpQ firm_age emp_cat emphh_cat sector place financing s10q45*

keep grappe menage nonag_id hhweight $main_var $baseline_var
duplicates report nonag_id

expand 2, gen(_copy)
bysort nonag_id (_copy): gen year = _n - 1  

gen val_output = .
replace val_output = revenue       if year == 0
replace val_output = revenue_2021  if year == 1
drop revenue revenue_2021

gen val_capital = .
replace val_capital = value_total if year == 0
replace val_capital = value_total_2021 if year == 1
drop value_total value_total_2021 

gen val_inter_good = .
replace val_inter_good = expenses if year == 0
replace val_inter_good = expenses_2021 if year == 1
drop expenses expenses_2021 

gen _var = .
replace _var = val_hired_labor if year == 0
replace _var = val_hired_labor_2021 if year == 1
drop val_hired_labor val_hired_labor_2021 
rename _var val_hired_labor 


global var val_output val_capital val_inter_good val_hired_labor
sum $var

foreach var in $var {
	gen log_`var' = log(1+`var')
}


gen l_cap_squared = log_val_capital*log_val_capital
gen l_intergood_squared = log_val_inter_good*log_val_inter_good
gen l_labor_squared = log_val_hired_labor*log_val_hired_labor

gen l_cap_l_intergood = log_val_capital*log_val_inter_good
gen l_cap_l_labor = log_val_capital*log_val_hired_labor
gen l_labor_l_intergood = log_val_hired_labor*log_val_inter_good

encode nonag_id, gen(hhid_num)
codebook year 
duplicates report hhid_num
sort hhid_num year 
xtset hhid_num year

global reg_var log_val_capital log_val_inter_good log_val_hired_labor  l_cap_squared l_intergood_squared l_labor_squared l_cap_l_intergood l_cap_l_labor l_labor_l_intergood

xtreg log_val_output $reg_var, fe 
estimates store fe_model

xtreg log_val_output $reg_var, re
estimates store re_model

hausman fe_model re_model

xtreg log_val_output $reg_var [pw=hhweight], fe vce(cluster grappe)
predict tfp, e


global reg_var log_val_capital log_val_inter_good log_val_hired_labor ///
    l_cap_squared l_intergood_squared l_labor_squared ///
    l_cap_l_intergood l_cap_l_labor l_labor_l_intergood

	
	*** Define the local file
local excel_file "excel_outputs/tfp_results.xlsx"
	****************
	
	
xtreg log_val_output $reg_var [pw=hhweight],  fe vce(cluster grappe)	   
putexcel set `excel_file', modify sheet("tfp_estimates")

putexcel C1 = "Variable"
putexcel D1 = "Coefficient" 
putexcel E1 = "Std Error"

matrix results = r(table)'
matrix coef = results[1..., 1]      
matrix se   = results[1..., 2]     

putexcel C2 = matrix(coef), rownames nformat("0.000")
putexcel E2 = matrix(se),            nformat("0.000")

	   
	  ******* 


reg tfp i.sexe_2018 i.age_cat i.milieu i.zae i.ethnie i.alfa2 i.educ i.internet i.elec_ac i.pcexpQ i.firm_age i.emp_cat i.emphh_cat i.sector i.place i.financing i.s10q45* [aw=hhweight] if year == 0, robust baselevels cluster(grappe)	   
putexcel set `excel_file', modify sheet("tfp_reg")
putexcel B1 = "Variable"
putexcel C1 = "Coefficient" 
putexcel D1 = "Std Error"

matrix results = r(table)'
matrix coef = results[1..., 1]     
matrix se = results[1..., 2]        

putexcel C2 = matrix(coef), rownames nformat("0.000")
putexcel E2 = matrix(se),            nformat("0.000")   
	   







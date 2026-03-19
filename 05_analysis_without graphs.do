********************************************************************************
* EHCVM SENEGAL - ANALYSIS DO-FILE
********************************************************************************
* Purpose: Generate all analysis tables and export to Excel with separate tabs.
*          Sections 1-4 as specified in the Analysis Plan.
*
* Author:  Zaineb Majoka (mzaineb@worldbank.org)
* Date:    March 2026
*
* INPUT:   ${final}/SEN_panel_2018_2021.dta
*
* OUTPUT:  ${output}/SEN_analysis.xlsx  (all tabs)
*          ${output}/hist_*.gph         (histograms)
*
* REFERENCE DO-FILES (from main branch):
*   - regressions.do        → regression specifications
*   - Add_gov_measures_and_TFP_estimates.do → TFP estimation
*   - descriptive_stats.do  → descriptive statistics layout
*
* NOTE ON LEVEL OF ANALYSIS
* -------------------------
* The panel dataset includes all individuals from the 2018 household roster.
* Three variables created in 04_create_panel.do allow changing the level of
* analysis:
*
*   is_entrepreneur     = 1 if individual was an entrepreneur in either wave.
*                         Use: keep if is_entrepreneur == 1
*
*   ent_status          = 4-category variable:
*                           1 = Not entrepreneur in either wave
*                           2 = Entrepreneur in 2018 only
*                           3 = Entrepreneur in 2021 only
*                           4 = Entrepreneur in both waves
*                         Use: keep if ent_status != 1 (drop non-entrepreneurs)
*
*   hh_has_enterprise   = 1 if any HH member was an entrepreneur in either wave.
*                         Use: keep if hh_has_enterprise == 1
*
* Entrepreneurs are identified at the individual level using nonag_id
* (grappe + menage + numind), matching the approach in set_up_data.do.
********************************************************************************

clear all
set more off
set matsize 5000

********************************************************************************
* PART 0: SET PATHS
********************************************************************************

* Main project directory — UPDATE THIS TO MATCH YOUR SETUP
global project "C:\Users\WB461621\OneDrive - WBG\SPJ\West Africa\Regional HH Enterprise Work"

* Data directories
global data_2018     "${project}/Data/SEN/2018"
global data_2021     "${project}/Data/SEN/2021"
global intermediate  "${project}/Data/SEN/Intermediate"
global output        "${project}/Output/SEN"
global final         "${project}/Data/SEN/Final"

capture mkdir "${output}"

* Excel output file
global xlout "${output}/SEN_analysis.xlsx"

* GDP Deflator values (2018 base year, source: WDI)
global gdpdef_2018 = 167.29
global gdpdef_2021 = 213.67


********************************************************************************
* PART 1: LOAD DATA AND CREATE REGRESSION VARIABLES
********************************************************************************

di as text _n "=============================================="
di as text "LOADING PANEL DATA AND CREATING VARIABLES"
di as text "=============================================="

use "${final}/SEN_panel_2018_2021.dta", clear

gen indweight2018 = hhweight/hhsize_2018
gen indweight2021 = hhweight/hhsize_2021

********************************************************************************
* PART 1a: Additional Summary Stats
********************************************************************************
*access to credit and source of credit (individual level)

preserve
sort hhid hh_has_loan_2018 hh_has_enterprise_2018
collapse (first) hh_has_loan_2018 hh_has_enterprise_2018 hhweight, by(hhid)
collapse hh_has_loan_2018 [pweight=hhweight], by(hh_has_enterprise_2018)
outsheet using "$output\credit_access_hh2018.xls", replace
restore

preserve
sort hhid hh_has_loan_2021 hh_has_enterprise_2021
collapse (first) hh_has_loan_2021 hh_has_enterprise_2021 hhweight, by(hhid)
collapse hh_has_loan_2021 [pweight=hhweight], by(hh_has_enterprise_2021)
outsheet using "$output\credit_access_hh2021.xls", replace
restore

preserve
collapse ind_has_loan_2018 [pweight=indweight2018], by(ent_2018)
outsheet using "$output\credit_access_ind_2018.xls", replace
restore

preserve
collapse ind_has_loan_2021 [pweight=indweight2021], by(ent_2021)
outsheet using "$output\credit_access_ind_2021.xls", replace
restore

*main source of credit 

gen byte total = 1
label variable total "All entrepreneurs"

tabout hh_main_credit_source_2018 total if hh_has_enterprise_2018 ==1 [iweight=hhweight_2018] using "$output\Results.xls", replace c(freq col row) format(0c 1p 1p) layout(cb) style(xls) h1("Source of credit, 2018")  
tabout hh_main_credit_source_2021 total if hh_has_enterprise_2021 ==1 [iweight=hhweight_2021] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb) style(xls) h1("Source of credit, 2021")  

*sector by location

tabout sector_2018 location_2018 if hh_has_enterprise_2018 ==1 [iweight=hhweight_2018] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb) h1("Sector of enterprise by location, 2018")
tabout sector_2021 location_2021 if hh_has_enterprise_2021 ==1 [iweight=hhweight_2021] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb) h1("Sector of enterprise by location, 2021")

*------------------------------------------------------------------------------
* 1.1: Log transformations matching regressions.do
*------------------------------------------------------------------------------

* Log profit: floor at 0 (matching regressions.do: max(log(x), 0))
capture drop lnprofit_2018 lnprofit_2021
gen lnprofit_2018 = max(log(profit_2018), 0) if profit_2018 < .
gen lnprofit_2021 = max(log(profit_2021), 0) if profit_2021 < .

* Log capital: floor at 0
capture drop lnvalue_total_2018 lnvalue_total_2021
gen lnvalue_total_2018 = max(log(value_total_2018), 0) if value_total_2018 < .
gen lnvalue_total_2021 = max(log(value_total_2021), 0) if value_total_2021 < .

*------------------------------------------------------------------------------
* 1.2: Recode variables for regressions (matching regressions.do exactly)
*------------------------------------------------------------------------------

* Age categories (from regressions.do)
capture drop age_cat_2018
recode age_2018 (15/29=1 "15-29") (30/44=2 "30-44") (45/64=3 "45-64") ///
    (64/120=4 "65+"), gen(age_cat_2018)

* Education categories (3 categories, from regressions.do)
capture drop educ_2018
recode educ_hi_2018 (1=1 "Less than primary") (3=2 "Less than Secondary") ///
    (4/9 = 3 "Secondary+"), gen(educ_2018)
replace educ_2018 = 1 if educ_scol_2018 == 1
replace educ_2018 = 3 if educ_scol_2018 > 1 & educ_scol_2018 < .

capture drop educ_2021
recode educ_hi_2021 (1=1 "Less than primary") (3=2 "Less than Secondary") ///
    (4/9 = 3 "Secondary+"), gen(educ_2021)
replace educ_2021 = 1 if educ_scol_2021 == 1
replace educ_2021 = 3 if educ_scol_2021 > 1 & educ_scol_2021 < .

* Per capita consumption quintiles
capture drop pcexpQ_2018
xtile pcexpQ_2018 = pcexp_2018 [aw=hhweight_2018], nq(5)

* Firm age categories (from regressions.do)
capture drop firm_age_2018
recode year_est_2018 (1940/1999.5=1 "<2000") (2000/2009=2 "2000-2009") ///
    (2010/2014 = 3 "2010-2014") (2015/2019 = 4 "2015-2019"), gen(firm_age_2018)

* Non-HH employee categories (from regressions.do)
capture drop emp_cat_2018
recode num_emp_2018 (0=0 "0") (1=1 "1") (2/100=2 "2+"), gen(emp_cat_2018)

* HH employee categories (from regressions.do)
capture drop emphh_cat_2018
recode num_hhemp_2018 (0=0 "0") (1=1 "1") (2/100=2 "2+"), gen(emphh_cat_2018)

* Ethnicity: replace missing with 99 (from regressions.do)
replace ethnie_2018 = 99 if ethnie_2018 == .

*------------------------------------------------------------------------------
* 1.3: Create derived variables needed for regressions
*------------------------------------------------------------------------------

* Internet alias (source variable is has_internet_2018, rename for consistency)
capture drop internet_2018
gen internet_2018 = has_internet_2018

*------------------------------------------------------------------------------
* 1.4: Additional variables needed for analysis
*------------------------------------------------------------------------------

* Number of HH members in wage jobs (for transition analysis)
foreach yr in 2018 2021 {
    capture drop has_wage_job_`yr'
    gen byte has_wage_job_`yr' = (activity_type_`yr' == 2)
    bysort hhid: egen n_hh_wage_`yr' = total(has_wage_job_`yr')
    label variable n_hh_wage_`yr' "Number of HH members in wage jobs (`yr')"
    drop has_wage_job_`yr'
}

* Formal enterprise dummy: meets all three definitions
foreach yr in 2018 2021 {
    gen byte formal_all3_`yr' = (firm_keeps_accounts_`yr' == 1 & ///
        firm_has_fisc_id_`yr' == 1 & firm_in_trade_register_`yr' == 1) ///
        if ent_`yr' == 1
    label variable formal_all3_`yr' "Formal by all 3 definitions (`yr')"
}


********************************************************************************
* PART 2: TFP ESTIMATION (preserve/restore)
********************************************************************************

di as text _n "=============================================="
di as text "ESTIMATING TFP"
di as text "=============================================="

preserve

* Keep only panel enterprises (in both waves)
keep if ent_2018 == 1 & ent_2021 == 1 & ind_matched == 1

* Create enterprise identifier
gen str ent_id = string(grappe) + "_" + string(menage) + "_" + string(numind)

* Keep needed variables
keep ent_id grappe menage numind hhweight_2018 ///
    revenue_2018 revenue_2021 value_total_2018 value_total_2021 ///
    expenses_2018 expenses_2021 val_hired_labor_2018 val_hired_labor_2021

* Expand to long format (2 obs per enterprise)
expand 2, gen(_copy)
bysort ent_id (_copy): gen year = _n - 1

* Create production function variables
gen val_output = .
replace val_output = revenue_2018     if year == 0
replace val_output = revenue_2021     if year == 1

gen val_capital = .
replace val_capital = value_total_2018 if year == 0
replace val_capital = value_total_2021 if year == 1

gen val_inter_good = .
replace val_inter_good = expenses_2018 if year == 0
replace val_inter_good = expenses_2021 if year == 1

gen val_hired_labor = .
replace val_hired_labor = val_hired_labor_2018 if year == 0
replace val_hired_labor = val_hired_labor_2021 if year == 1

* Log transformations (using log(1+x) as in TFP do-file)
foreach var in val_output val_capital val_inter_good val_hired_labor {
    gen log_`var' = log(1 + `var')
}

* Translog terms (squared and interactions)
gen l_cap_squared        = log_val_capital * log_val_capital
gen l_intergood_squared  = log_val_inter_good * log_val_inter_good
gen l_labor_squared      = log_val_hired_labor * log_val_hired_labor
gen l_cap_l_intergood    = log_val_capital * log_val_inter_good
gen l_cap_l_labor        = log_val_capital * log_val_hired_labor
gen l_labor_l_intergood  = log_val_hired_labor * log_val_inter_good

* Panel setup
encode ent_id, gen(hhid_num)
sort hhid_num year
xtset hhid_num year

* Fixed effects regression (translog production function)
global tfp_regressors log_val_capital log_val_inter_good log_val_hired_labor ///
    l_cap_squared l_intergood_squared l_labor_squared ///
    l_cap_l_intergood l_cap_l_labor l_labor_l_intergood

xtreg log_val_output $tfp_regressors [pw=hhweight_2018], fe vce(cluster grappe)

* Export TFP production function estimates
* Capture r(table) before putexcel set clears r() results
matrix results = r(table)'

putexcel set "${xlout}", sheet("TFP_Estimates") replace
putexcel B1 = "TFP Production Function Estimates (Fixed Effects)"
putexcel B3 = "Variable" C3 = "Coefficient" D3 = "Std Error" E3 = "P-value"
matrix coef = results[1..., 1]
matrix se   = results[1..., 2]
matrix pval = results[1..., 4]

putexcel B4 = matrix(coef), rownames nformat("0.000")
putexcel D4 = matrix(se), nformat("0.000")

* Add p-values
local nrows = rowsof(results)
forvalues i = 1/`nrows' {
    local pv = results[`i', 4]
    local row = `i' + 3
    putexcel E`row' = `pv', nformat("0.000")
}

* Predict TFP residual
predict tfp, e

* Save TFP values per enterprise-year
keep grappe menage numind year tfp
reshape wide tfp, i(grappe menage numind) j(year)
rename tfp0 tfp_2018
rename tfp1 tfp_2021

tempfile tfp_data
save `tfp_data'

restore

* Merge TFP back into main dataset
merge m:1 grappe menage numind using `tfp_data', nogenerate

* TFP increased dummy
gen byte tfp_increased = (tfp_2021 > tfp_2018) ///
    if !missing(tfp_2018) & !missing(tfp_2021)
label variable tfp_increased "TFP increased between 2018 and 2021"


********************************************************************************
* PART 3: SECTION 1 — INTRODUCTION
********************************************************************************

di as text _n "=============================================="
di as text "SECTION 1: INTRODUCTION"
di as text "=============================================="

*% of HHs operating at least one enterprise 
tabout hh_has_enterprise_2018 total [iweight=hhweight_2018] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb) h1("% of HHs with an enterprise, 2018")
tabout hh_has_enterprise_2021 total [iweight=hhweight_2021] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb) h1("% of HHs with an enterprise, 2021")



putexcel set "${xlout}", sheet("S1_Introduction") modify
putexcel B1 = "Section 1: Introduction"
putexcel B2 = "Household Enterprises in Senegal, 2018 and 2021"

*--- % of HH operating at least 1 enterprise ---
putexcel B4 = "Indicator" C4 = "2018" D4 = "2021"

*2018 total number of enterprises within a household 

bysort hhid: egen num_enterprise_2018 = total(ent_2018) if ent_2018==1
replace num_enterprise_2018=0 if ent_2018==0

*2018: average number of enterprises per household, among those with an enterprise
preserve
sort hhid num_enterprise_2018 ent_2018
collapse (first) num_enterprise_2018 ent_2018 hhweight, by(hhid)
collapse num_enterprise_2018 if ent_2018==1 [pweight=hhweight]
outsheet using "$output/av_enterprises2018.xls", replace
restore
 
* 2018: HH with at least 1 enterprise
preserve 
keep if in_2018 == 1
bysort hhid: keep if _n == 1
sum hh_has_enterprise_2018 [aw=hhweight]
local pct_hh_ent_2018 = r(mean) * 100
restore

*2021 total number of enterprises within a household 

bysort hhid: egen num_enterprise_2021 = total(ent_2021) if ent_2021==1
replace num_enterprise_2021=0 if ent_2021==0

*2021: average number of enterprises per household, among those with an enterprise
preserve
sort hhid num_enterprise_2021 ent_2021
collapse (first) num_enterprise_2021 ent_2021 hhweight, by(hhid)
collapse num_enterprise_2021 if ent_2021==1 [pweight=hhweight]
outsheet using "$output/av_enterprises2021.xls", replace
restore

* 2021: HH with at least 1 enterprise
preserve
    keep if in_2021 == 1
    bysort hhid: keep if _n == 1
    sum hh_has_enterprise_2021 [aw=hhweight_2021]
    local pct_hh_ent_2021 = r(mean) * 100
restore

putexcel B5 = "% of HH operating at least 1 enterprise"
putexcel C5 = `pct_hh_ent_2018', nformat("0.0")
putexcel D5 = `pct_hh_ent_2021', nformat("0.0")

*Number of Enterprises per household - categories 1, 2, 3+

foreach yr in 2018 2021 {
    gen byte n_ent_cat_`yr' = .
    replace n_ent_cat_`yr' = 1 if num_enterprise_`yr' == 1
    replace n_ent_cat_`yr' = 2 if num_enterprise_`yr' == 2
    replace n_ent_cat_`yr' = 3 if num_enterprise_`yr' >= 3 & !missing(num_enterprise_`yr')
    
    label variable n_ent_cat_`yr' "Enterprise count category (`yr')"
}

label define n_ent_cat_lbl 1 "1" 2 "2" 3 "3+"
label values n_ent_cat_2018 n_ent_cat_lbl
label values n_ent_cat_2021 n_ent_cat_lbl

tabout n_ent_cat_2018 total [iweight=hhweight_2018] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb) h1("Number of enterprises per hh, 2018")
tabout n_ent_cat_2021 total [iweight=hhweight_2021] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb) h1("Number of enterprises per hh, 2021")


*--- Average enterprise size (employees) ---
putexcel B7 = "Average Enterprise Size"

* Total employees (family + non-family, excl. proprietor)
putexcel B8 = "Total employees (family + non-family)"
sum total_emp_2018 [aw=hhweight_2018] if ent_2018 == 1
local _mean = r(mean)
putexcel C8 = `_mean', nformat("0.00")
sum total_emp_2021 [aw=hhweight_2021] if ent_2021 == 1
local _mean = r(mean)
putexcel D8 = `_mean', nformat("0.00")

* Family employees
putexcel B9 = "Family employees"
sum num_hhemp_2018 [aw=hhweight_2018] if ent_2018 == 1
local _mean = r(mean)
putexcel C9 = `_mean', nformat("0.00")
sum num_hhemp_2021 [aw=hhweight_2021] if ent_2021 == 1
local _mean = r(mean)
putexcel D9 = `_mean', nformat("0.00")

* Non-family employees
putexcel B10 = "Non-family employees"
sum num_emp_2018 [aw=hhweight_2018] if ent_2018 == 1
local _mean = r(mean)
putexcel C10 = `_mean', nformat("0.00")
sum num_emp_2021 [aw=hhweight_2021] if ent_2021 == 1
local _mean = r(mean)
putexcel D10 = `_mean', nformat("0.00")

* % with 0 non-family employees
putexcel B11 = "% with 0 non-family employees"
sum num_emp_2018 [aw=hhweight_2018] if ent_2018 == 1
local pct0_18 = r(mean)
gen byte _zero_emp_2018 = (num_emp_2018 == 0) if ent_2018 == 1
sum _zero_emp_2018 [aw=hhweight_2018] if ent_2018 == 1
putexcel C11 = (r(mean) * 100), nformat("0.0")
gen byte _zero_emp_2021 = (num_emp_2021 == 0) if ent_2021 == 1
sum _zero_emp_2021 [aw=hhweight_2021] if ent_2021 == 1
putexcel D11 = (r(mean) * 100), nformat("0.0")

* % with 1 or more non-family employees
putexcel B12 = "% with 1+ non-family employees"
gen byte _oneplus_emp_2018 = (num_emp_2018 >= 1 & !missing(num_emp_2018)) if ent_2018 == 1
sum _oneplus_emp_2018 [aw=hhweight_2018] if ent_2018 == 1
putexcel C12 = (r(mean) * 100), nformat("0.0")
gen byte _oneplus_emp_2021 = (num_emp_2021 >= 1 & !missing(num_emp_2021)) if ent_2021 == 1
sum _oneplus_emp_2021 [aw=hhweight_2021] if ent_2021 == 1
putexcel D12 = (r(mean) * 100), nformat("0.0")

* % with 2 or more non-family employees
putexcel B13 = "% with 2+ non-family employees"
gen byte _twoplus_emp_2018 = (num_emp_2018 >= 2 & !missing(num_emp_2018)) if ent_2018 == 1
sum _twoplus_emp_2018 [aw=hhweight_2018] if ent_2018 == 1
putexcel C13 = (r(mean) * 100), nformat("0.0")
gen byte _twoplus_emp_2021 = (num_emp_2021 >= 2 & !missing(num_emp_2021)) if ent_2021 == 1
sum _twoplus_emp_2021 [aw=hhweight_2021] if ent_2021 == 1
putexcel D13 = (r(mean) * 100), nformat("0.0")

drop _zero_emp_* _oneplus_emp_* _twoplus_emp_*


*--- 1b: HH enterprise ownership by location 
* % of households with at least 1 enterprise, Urban vs Rural, 2018 & 2021

preserve
keep if ent_2018==1
tabout ent_2018 rural_2018 [iweight=hhweight_2018] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1("Enterprise by location 2018")
restore 

preserve
keep if ent_2021==1
tabout ent_2021 rural_2021 [iweight=hhweight_2021] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb) h1("Enterprise location 2021")
restore 


*--- 1c: Composition of all employment excluding agriculture 
* All workers (15-64), including no activity 

tabout activity_type_2018 total if sector_work_2018!=1 & working_age_2018==1 [iweight=indweight2018] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1("Non-ag Activity Type for 15-64, 2018")
tabout activity_type_2021 total if sector_work_2021!=1 & working_age_2021==1 [iweight=indweight2021] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1("Non-ag Activity Type for 15-64, 2021")

*activity type excluding no activity 

tabout emp_type_2018 total if sector_work_2018!=1 & working_age_2018==1 [iweight=indweight2018] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1("Non-ag Activity Type 15-64, excluding no activity, 2018")
tabout emp_type_2021 total if sector_work_2021!=1 & working_age_2021==1 [iweight=indweight2021] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1("Non-ag Activity Type 15-64 excluding no activity, 2021")


********************************************************************************
* PART 4: SECTION 2 — STYLIZED FACTS ON THE PROFILE
********************************************************************************

di as text _n "=============================================="
di as text "SECTION 2: PROFILE"
di as text "=============================================="

*--- 2a: Formality shares ---

tabout firm_keeps_accounts_2018 total if ent_2018==1 [iweight=hhweight_2018] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1("% keeping written accounts, 2018")
tabout firm_keeps_accounts_2021 total if ent_2021==1 [iweight=hhweight_2021] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1("% keeping written accounts, 2021")

tabout firm_has_fisc_id_2018 total if ent_2018==1 [iweight=hhweight_2018] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1("% with fiscal ID NINEA, 2018")
tabout firm_has_fisc_id_2021 total if ent_2021==1 [iweight=hhweight_2021] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1("% with fiscal ID NINEA, 2021")

tabout firm_in_trade_register_2018 total if ent_2018==1 [iweight=hhweight_2018] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1(% registered in trade register, 2018)
tabout firm_in_trade_register_2021 total if ent_2021==1 [iweight=hhweight_2021] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1(% registered in trade register, 2021)

tabout formal_all3_2018 total if ent_2018==1 [iweight=hhweight_2018] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1(% meeting all 3 definitions, 2018)
tabout formal_all3_2021 total if ent_2021==1 [iweight=hhweight_2021] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1(% meeting all 3 definitions, 2021)


*--- 2b: Non-family employees change ---
putexcel set "${xlout}", sheet("S2_Profile") modify
putexcel B1 = "Section 2: Stylized Facts on the Profile"

putexcel B3 = "Non-Family Employee Changes (Panel Enterprises)"
putexcel B4 = "Indicator" C4 = "Value"

* Average non-family employees in 2018 (panel enterprises)
sum num_emp_2018 [aw=hhweight_2018] if ent_status==4
local _mean = r(mean)
putexcel B5 = "Avg non-family employees in 2018"
putexcel C5 = `_mean', nformat("0.00")

* Average non-family employees in 2021 (panel enterprises)
sum num_emp_2021 [aw=hhweight_2021] if ent_status==4
local _mean = r(mean)
putexcel B6 = "Avg non-family employees in 2021"
putexcel C6 = `_mean', nformat("0.00")

* Number and share that increased
count if change_num_emp > 0 & change_num_emp < . & ent_status==4
local n_increased = r(N)
putexcel B7 = "N enterprises that increased non-family employees"
putexcel C7 = `n_increased'

sum change_num_emp [aw=hhweight_2018] if ent_status==4
local n_total = r(N)

gen byte emp_increased = (change_num_emp > 0) if ent_status==4 & !missing(change_num_emp)
sum emp_increased [aw=hhweight_2018] if ent_status==4
local _mean = r(mean) * 100
putexcel B8 = "Share that increased non-family employees (%)"
putexcel C8 = `_mean', nformat("0.0")

*--- 2c: Sector of operation ---
tabout sector_2018 total if ent_2018==1 [iweight=hhweight_2018] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1(Sector of HHE, 2018)
tabout sector_2021 total if ent_2021==1 [iweight=hhweight_2021] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1(Sector of HHE, 2021)


*--- 2d: Gender of entrepreneurs ---
tabout sexe_2018 total if ent_2018==1 [iweight=hhweight_2018] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1(Gender of entrepreneur, 2018)
tabout sexe_2021 total if ent_2021==1 [iweight=hhweight_2021] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1(Gender of entrepreneur, 2021)

*--- 2e: Sector distribution by gender (2018): which sectors are men/women in?
tabout sexe_2018 sector_2018 if ent_2018==1 [iweight=hhweight_2018] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1(Gender/Sector of entrepreneur, 2018)
tabout sexe_2021 sector_2021 if ent_2021==1 [iweight=hhweight_2021] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1(Gender/Sector of entrepreneur, 2021)

*--- 2f: HH enterprise ownership across welfare quintiles

preserve
    * Collapse to household level
    bysort hhid: keep if _n == 1
tabout hh_has_enterprise_2018 welfare_quintile_2018 [iweight=hhweight_2018] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1(HH enterprise by quintile, 2018)
tabout hh_has_enterprise_2021 welfare_quintile_2021 [iweight=hhweight_2021] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1(HH Enterprise by quintile, 2021)
restore 


*--- 2g: Profiles of HE vs Wage Workers

*2018

preserve

    * Keep working-age individuals observed in 2018
    keep if in_2018 == 1 & age_2018 >= 15 & age_2018 < .

    * Identify HE workers (entrepreneurs) and Wage workers
    gen byte worker_type = .
    replace worker_type = 1 if ent_2018 == 1                     // HE
    replace worker_type = 2 if activity_type_2018 == 2            // Wage
    keep if inlist(worker_type, 1, 2)

    label define wtype 1 "HE" 2 "Wage"
    label values worker_type wtype
	
	tabout worker_type sexe_2018 [iweight=hhweight_2018] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1(entreprenuer vs. wage by gender, 2018)
	tabout worker_type rural_2018 [iweight=hhweight_2018] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1(entreprenuer vs. wage by urban/rural, 2018)
	tabout worker_type location_2018 [iweight=hhweight_2018] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1(entreprenuer vs. wage by location, 2018)
	tabout worker_type educ_2018 [iweight=hhweight_2018] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1(entreprenuer vs. wage by education, 2018)

restore

   *2021

preserve
    * Keep working-age individuals observed in 2021
    keep if in_2021 == 1 & age_2021 >= 15 & age_2021 < .

    * Identify HE workers (entrepreneurs) and Wage workers
    gen byte worker_type = .
    replace worker_type = 1 if ent_2021 == 1                     // HE
    replace worker_type = 2 if activity_type_2021 == 2            // Wage
    keep if inlist(worker_type, 1, 2)
    label define wtype 1 "HE" 2 "Wage"
    label values worker_type wtype

	tabout worker_type sexe_2021 [iweight=hhweight_2021] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1(entreprenuer vs. wage by gender, 2021)
	tabout worker_type rural_2021 [iweight=hhweight_2021] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1(entreprenuer vs. wage by urban/rural, 2021)
	tabout worker_type location_2021 [iweight=hhweight_2021] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1(entreprenuer vs. wage by location, 2021)
	tabout worker_type educ_2021 [iweight=hhweight_2021] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1(entreprenuer vs. wage by education, 2021)
	
restore

********************************************************************************
* PART 5: SECTION 3 — PERFORMANCE (DESCRIPTIVE)
********************************************************************************

di as text _n "=============================================="
di as text "SECTION 3: PERFORMANCE (DESCRIPTIVE)"
di as text "=============================================="

putexcel set "${xlout}", sheet("S3_Performance") modify
putexcel B1 = "Section 3: Stylized Facts on Performance"

*--- 3a: Average profits ---
putexcel B3 = "Profits" C3 = "2018" D3 = "2021"

putexcel B4 = "Average monthly profit (CFA)"
sum profit_2018 [aw=hhweight_2018] if ent_2018 == 1
local _mean = r(mean)
putexcel C4 = `_mean', nformat("#,##0")
sum profit_2021 [aw=hhweight_2021] if ent_2021 == 1
local _mean = r(mean)
putexcel D4 = `_mean', nformat("#,##0")

*--- 3b: Profit categories ---
putexcel B6 = "Profit Distribution (%)" C6 = "2018" D6 = "2021"

* 2018
sum hhweight_2018 if ent_2018 == 1 & profit_2018 < 0
local w_neg = r(sum)
sum hhweight_2018 if ent_2018 == 1 & profit_2018 == 0
local w_zero = r(sum)
sum hhweight_2018 if ent_2018 == 1 & profit_2018 > 0 & profit_2018 < .
local w_pos = r(sum)
local w_all = `w_neg' + `w_zero' + `w_pos'

putexcel B7 = "Negative/loss"
putexcel C7 = (`w_neg'/`w_all'*100), nformat("0.0")
putexcel B8 = "Zero profits"
putexcel C8 = (`w_zero'/`w_all'*100), nformat("0.0")
putexcel B9 = "Positive profits"
putexcel C9 = (`w_pos'/`w_all'*100), nformat("0.0")

* 2021
sum hhweight_2021 if ent_2021 == 1 & profit_2021 < 0
local w_neg = r(sum)
sum hhweight_2021 if ent_2021 == 1 & profit_2021 == 0
local w_zero = r(sum)
sum hhweight_2021 if ent_2021 == 1 & profit_2021 > 0 & profit_2021 < .
local w_pos = r(sum)
local w_all = `w_neg' + `w_zero' + `w_pos'

putexcel D7 = (`w_neg'/`w_all'*100), nformat("0.0")
putexcel D8 = (`w_zero'/`w_all'*100), nformat("0.0")
putexcel D9 = (`w_pos'/`w_all'*100), nformat("0.0")

*--- 3c: Profit growth (panel enterprises) ---
putexcel B11 = "Profitability Over Time (Panel Enterprises)"
putexcel B12 = "Indicator" C12 = "Value"

* Average real profit in 2018 and 2021
putexcel B13 = "Average real profit 2018 (CFA)"
sum profit_real_2018 [aw=hhweight_2018] if ent_status==4
local _mean = r(mean)
putexcel C13 = `_mean', nformat("#,##0")

putexcel B14 = "Average real profit 2021 (CFA, 2018 prices)"
sum profit_real_2021 [aw=hhweight_2018] if ent_status==4
local _mean = r(mean)
putexcel C14 = `_mean', nformat("#,##0")

* Average annual growth rate of profits
* Annual growth = ((profit_2021_real / profit_2018)^(1/3) - 1) for 3-year gap
gen annual_growth_profit = .
replace annual_growth_profit = ((profit_real_2021 / profit_real_2018)^(1/3) - 1) ///
    if profit_real_2018 > 0 & profit_real_2021 > 0 & ///
    ent_2018 == 1 & ent_2021 == 1 & ind_matched == 1

putexcel B15 = "Average annual growth rate of profits"
sum annual_growth_profit [aw=hhweight_2018]
local _mean = r(mean)
putexcel C15 = `_mean', nformat("0.000")

* Share with annual growth > 10%
gen byte growth_gt10 = (annual_growth_profit > 0.10) if !missing(annual_growth_profit)
putexcel B16 = "Share with annual profit growth > 10% (%)"
sum growth_gt10 [aw=hhweight_2018]
local _mean = r(mean)
putexcel C16 = (`_mean' * 100), nformat("0.0")

*--- 3d: Internet and electricity access ---
putexcel B18 = "Internet and Electricity Access" C18 = "2018 (%)" D18 = "2021 (%)"

putexcel B19 = "Share with internet access"
sum has_internet_2018 [aw=hhweight_2018] if ent_2018 == 1
local _mean = r(mean)
putexcel C19 = (`_mean' * 100), nformat("0.0")
sum has_internet_2021 [aw=hhweight_2021] if ent_2021 == 1
local _mean = r(mean)
putexcel D19 = (`_mean' * 100), nformat("0.0")

putexcel B20 = "Share with electricity"

sum has_electricity_2018 [aw=hhweight_2018] if ent_2018 == 1
local _mean = r(mean)
putexcel C20 = (`_mean' * 100), nformat("0.0")

sum has_electricity_2021 [aw=hhweight_2021] if ent_2021 == 1
local _mean = r(mean)
putexcel D20 = (`_mean' * 100), nformat("0.0")


********************************************************************************
* PART 6: SECTION 3 — REGRESSIONS (without cooperative)
********************************************************************************

di as text _n "=============================================="
di as text "SECTION 3: REGRESSIONS"
di as text "=============================================="

* Restrict sample for regressions (matching regressions.do)
* Keep entrepreneurs, adults 15+
* The regressions use panel enterprises but regressions.do doesn't explicitly
* restrict to panel — it uses all observations with non-missing variables.
* Following the do-file: no explicit panel restriction.

*--- Helper program to export regression results ---
capture program drop export_reg_results
program define export_reg_results
    args sheet startrow

    * Store e() results and r(table) before putexcel set clears r()
    local _eN = e(N)
    local _er2 = e(r2)
    matrix results = r(table)'

    putexcel set "${xlout}", sheet("`sheet'") modify

    local r1 = `startrow'
    putexcel B`r1' = "Variable" C`r1' = "Coefficient" D`r1' = "Std Error" ///
        E`r1' = "P-value" F`r1' = "Sig"
    local nrows = rowsof(results)

    matrix coef = results[1..., 1]
    matrix se   = results[1..., 2]

    local r2 = `r1' + 1
    putexcel B`r2' = matrix(coef), rownames nformat("0.0000")
    putexcel D`r2' = matrix(se), nformat("0.0000")

    * Add p-values and significance stars
    forvalues i = 1/`nrows' {
        local pv = results[`i', 4]
        local row = `i' + `startrow'
        putexcel E`row' = `pv', nformat("0.000")
        local stars = ""
        if `pv' < 0.01      local stars = "***"
        else if `pv' < 0.05 local stars = "**"
        else if `pv' < 0.1  local stars = "*"
        putexcel F`row' = "`stars'"
    }

    * N and R-squared
    local lastrow = `nrows' + `startrow' + 2
    putexcel B`lastrow' = "N"
    putexcel C`lastrow' = `_eN'
    local lastrow2 = `lastrow' + 1
    putexcel B`lastrow2' = "R-squared"
    putexcel C`lastrow2' = `_er2', nformat("0.000")
end

* NOTE: All independent variables are from 2018 except sex and age, which are
*       from 2021 (see set_up_data.do for how the dataset was constructed).

*--- 6a: Profit regression ---
putexcel set "${xlout}", sheet("S3_Reg_Profit") modify
putexcel B1 = "Regression: Log Profit 2021"
putexcel B2 = "OLS with clustering at EA level"

regress lnprofit_2021 lnprofit_2018 lnvalue_total_2018 i.sexe_2018 i.age_cat_2018 i.milieu_2018 i.zae_2018 i.ethnie_2018 i.alfab_2018 i.educ_2018 i.internet_2018 i.has_electricity_2018 i.pcexpQ_2018 i.firm_age_2018 i.emp_cat_2018 i.emphh_cat_2018 ib5.sector_2018 i.place_2018 i.financing_2018 ib2.s10q45a_2018 ib2.s10q45b_2018 ib2.s10q45c_2018 ib2.s10q45d_2018 ib2.s10q45e_2018 ib2.s10q45f_2018 ib2.s10q45g_2018 ib2.s10q45h_2018 ib2.s10q45i_2018 ib2.s10q45j_2018 ib2.s10q45k_2018 ib2.s10q45l_2018 ib2.s10q45m_2018 ib2.s10q45n_2018 ib2.s10q45o_2018 i.firm_keeps_accounts_2018 i.firm_has_fisc_id_2018 i.firm_in_trade_register_2018 [aw=hhweight_2018], robust baselevels cluster(grappe)

export_reg_results "S3_Reg_Profit" 4

*--- 6b: Capital regression ---
putexcel set "${xlout}", sheet("S3_Reg_Capital") modify
putexcel B1 = "Regression: Log Capital Value 2021"
putexcel B2 = "OLS with clustering at EA level"

regress lnvalue_total_2021 lnvalue_total_2018 lnprofit_2018 i.sexe_2018 i.age_cat_2018 i.milieu_2018 i.zae_2018 i.ethnie_2018 i.alfab_2018 i.educ_2018 i.internet_2018 i.has_electricity_2018 i.pcexpQ_2018 i.firm_age_2018 i.emp_cat_2018 i.emphh_cat_2018 ib5.sector_2018 i.place_2018 i.financing_2018 ib2.s10q45a_2018 ib2.s10q45b_2018 ib2.s10q45c_2018 ib2.s10q45d_2018 ib2.s10q45e_2018 ib2.s10q45f_2018 ib2.s10q45g_2018 ib2.s10q45h_2018 ib2.s10q45i_2018 ib2.s10q45j_2018 ib2.s10q45k_2018 ib2.s10q45l_2018 ib2.s10q45m_2018 ib2.s10q45n_2018 ib2.s10q45o_2018 i.firm_keeps_accounts_2018 i.firm_has_fisc_id_2018 i.firm_in_trade_register_2018 [aw=hhweight_2018], robust baselevels cluster(grappe)

export_reg_results "S3_Reg_Capital" 4

*--- 6c: Number of employees regression ---
putexcel set "${xlout}", sheet("S3_Reg_NumEmp") modify
putexcel B1 = "Regression: Non-Family Employees 2021"
putexcel B2 = "OLS with clustering at EA level"

regress num_emp_2021 num_emp_2018 lnprofit_2018 lnvalue_total_2018 i.sexe_2018 i.age_cat_2018 i.milieu_2018 i.zae_2018 i.ethnie_2018 i.alfab_2018 i.educ_2018 i.internet_2018 i.has_electricity_2018 i.pcexpQ_2018 i.firm_age_2018 i.emphh_cat_2018 ib5.sector_2018 i.place_2018 i.financing_2018 ib2.s10q45a_2018 ib2.s10q45b_2018 ib2.s10q45c_2018 ib2.s10q45d_2018 ib2.s10q45e_2018 ib2.s10q45f_2018 ib2.s10q45g_2018 ib2.s10q45h_2018 ib2.s10q45i_2018 ib2.s10q45j_2018 ib2.s10q45k_2018 ib2.s10q45l_2018 ib2.s10q45m_2018 ib2.s10q45n_2018 ib2.s10q45o_2018 i.firm_keeps_accounts_2018 i.firm_has_fisc_id_2018 i.firm_in_trade_register_2018 [aw=hhweight_2018], robust baselevels cluster(grappe)

export_reg_results "S3_Reg_NumEmp" 4


********************************************************************************
* PART 7: SECTION 3 — REGRESSIONS WITH COOPERATIVE
********************************************************************************

di as text _n "=============================================="
di as text "SECTION 3: REGRESSIONS WITH COOPERATIVE"
di as text "=============================================="

putexcel set "${xlout}", sheet("S3_Reg_Coop") modify
putexcel B1 = "Regressions with Cooperative Dummy"
putexcel B2 = "All three regressions with cooperative (legal form) as additional control"

*--- Profit with cooperative ---
putexcel B4 = "=== (i) Log Profit 2021 ==="

regress lnprofit_2021 lnprofit_2018 lnvalue_total_2018 i.sexe_2018 i.age_cat_2018 i.milieu_2018 i.zae_2018 i.ethnie_2018 i.alfab_2018 i.educ_2018 i.internet_2018 i.has_electricity_2018 i.pcexpQ_2018 i.firm_age_2018 i.emp_cat_2018 i.emphh_cat_2018 ib5.sector_2018 i.place_2018 i.financing_2018 ib2.s10q45a_2018 ib2.s10q45b_2018 ib2.s10q45c_2018 ib2.s10q45d_2018 ib2.s10q45e_2018 ib2.s10q45f_2018 ib2.s10q45g_2018 ib2.s10q45h_2018 ib2.s10q45i_2018 ib2.s10q45j_2018 ib2.s10q45k_2018 ib2.s10q45l_2018 ib2.s10q45m_2018 ib2.s10q45n_2018 ib2.s10q45o_2018 i.firm_keeps_accounts_2018 i.firm_has_fisc_id_2018 i.firm_in_trade_register_2018 i.cooperative_2018 [aw=hhweight_2018], robust baselevels cluster(grappe)

export_reg_results "S3_Reg_Coop" 5

* Record where profit regression ends (for capital regression placement)
matrix results = r(table)'
local profit_nrows = rowsof(results)
local capital_start = `profit_nrows' + 5 + 5  // 5 (start) + nrows + gap

*--- Capital with cooperative ---
local cs = `capital_start'
putexcel B`cs' = "=== (ii) Log Capital Value 2021 ==="
local cs1 = `cs' + 1

regress lnvalue_total_2021 lnvalue_total_2018 lnprofit_2018 i.sexe_2018 i.age_cat_2018 i.milieu_2018 i.zae_2018 i.ethnie_2018 i.alfab_2018 i.educ_2018 i.internet_2018 i.has_electricity_2018 i.pcexpQ_2018 i.firm_age_2018 i.emp_cat_2018 i.emphh_cat_2018 ib5.sector_2018 i.place_2018 i.financing_2018 ib2.s10q45a_2018 ib2.s10q45b_2018 ib2.s10q45c_2018 ib2.s10q45d_2018 ib2.s10q45e_2018 ib2.s10q45f_2018 ib2.s10q45g_2018 ib2.s10q45h_2018 ib2.s10q45i_2018 ib2.s10q45j_2018 ib2.s10q45k_2018 ib2.s10q45l_2018 ib2.s10q45m_2018 ib2.s10q45n_2018 ib2.s10q45o_2018 i.firm_keeps_accounts_2018 i.firm_has_fisc_id_2018 i.firm_in_trade_register_2018 i.cooperative_2018 [aw=hhweight_2018], robust baselevels cluster(grappe)

export_reg_results "S3_Reg_Coop" `cs1'

* Record where capital ends for num_emp placement
matrix results = r(table)'
local cap_nrows = rowsof(results)
local nemp_start = `cs1' + `cap_nrows' + 4

*--- Num emp with cooperative ---
local ns = `nemp_start'
putexcel B`ns' = "=== (iii) Non-Family Employees 2021 ==="
local ns1 = `ns' + 1

regress num_emp_2021 num_emp_2018 lnprofit_2018 lnvalue_total_2018 i.sexe_2018 i.age_cat_2018 i.milieu_2018 i.zae_2018 i.ethnie_2018 i.alfab_2018 i.educ_2018 i.internet_2018 i.has_electricity_2018 i.pcexpQ_2018 i.firm_age_2018 i.emphh_cat_2018 ib5.sector_2018 i.place_2018 i.financing_2018 ib2.s10q45a_2018 ib2.s10q45b_2018 ib2.s10q45c_2018 ib2.s10q45d_2018 ib2.s10q45e_2018 ib2.s10q45f_2018 ib2.s10q45g_2018 ib2.s10q45h_2018 ib2.s10q45i_2018 ib2.s10q45j_2018 ib2.s10q45k_2018 ib2.s10q45l_2018 ib2.s10q45m_2018 ib2.s10q45n_2018 ib2.s10q45o_2018 i.firm_keeps_accounts_2018 i.firm_has_fisc_id_2018 i.firm_in_trade_register_2018 i.cooperative_2018 [aw=hhweight_2018], robust baselevels cluster(grappe)

export_reg_results "S3_Reg_Coop" `ns1'


********************************************************************************
* PART 8: ANNEX — DESCRIPTIVE STATISTICS
********************************************************************************

di as text _n "=============================================="
di as text "ANNEX: DESCRIPTIVE STATISTICS"
di as text "=============================================="

putexcel set "${xlout}", sheet("Annex_DescStats") modify
putexcel B1 = "Annex: Descriptive Statistics for Regression Variables"

* --- Continuous variables ---
putexcel B3 = "Variable" C3 = "P10" D3 = "P50" E3 = "P90" ///
    F3 = "Mean" G3 = "SD" H3 = "N"

local row = 4
local desc_vars "lnprofit_2021 lnprofit_2018 lnvalue_total_2021 lnvalue_total_2018 num_emp_2021 num_emp_2018"

foreach v of local desc_vars {
    sum `v' [aw=hhweight_2018], detail
    putexcel B`row' = "`v'"
    local _N = r(N)
    local _mean = r(mean)
    local _p10 = r(p10)
    local _p50 = r(p50)
    local _p90 = r(p90)
    local _sd = r(sd)
    putexcel C`row' = `_p10', nformat("0.0")
    putexcel D`row' = `_p50', nformat("0.0")
    putexcel E`row' = `_p90', nformat("0.0")
    putexcel F`row' = `_mean', nformat("0.00")
    putexcel G`row' = `_sd', nformat("0.00")
    putexcel H`row' = `_N', nformat("#,##0")
    local row = `row' + 1
}

* --- Binary/categorical variables ---
local row = `row' + 1
putexcel B`row' = "Categorical Variables (% or mean)"
local row = `row' + 1
putexcel B`row' = "Variable" C`row' = "Mean" D`row' = "N"
local row = `row' + 1

* Gender (share female)
putexcel B`row' = "Female (sexe_2018==2)"
gen byte _female = (sexe_2018 == 2)
sum _female [aw=hhweight_2018] if ent_2018 == 1
local _N = r(N)
local _mean = r(mean)
putexcel C`row' = `_mean', nformat("0.000")
putexcel D`row' = `_N'
drop _female
local row = `row' + 1

* Urban/rural
putexcel B`row' = "Rural (milieu_2018==2)"
gen byte _rural = (milieu_2018 == 2) if !missing(milieu_2018)
sum _rural [aw=hhweight_2018] if ent_2018 == 1
local _N = r(N)
local _mean = r(mean)
putexcel C`row' = `_mean', nformat("0.000")
putexcel D`row' = `_N'
drop _rural
local row = `row' + 1

* Internet
putexcel B`row' = "Has internet"
sum internet_2018 [aw=hhweight_2018] if ent_2018 == 1
local _N = r(N)
local _mean = r(mean)
putexcel C`row' = `_mean', nformat("0.000")
putexcel D`row' = `_N'
local row = `row' + 1

* Electricity (HH level)
putexcel B`row' = "Has electricity (HH)"
sum has_electricity_2018 [aw=hhweight_2018] if ent_2018 == 1
local _N = r(N)
local _mean = r(mean)
putexcel C`row' = `_mean', nformat("0.000")
putexcel D`row' = `_N'
local row = `row' + 1

* Formality indicators
foreach v in firm_keeps_accounts_2018 firm_has_fisc_id_2018 firm_in_trade_register_2018 {
    putexcel B`row' = "`v'"
    sum `v' [aw=hhweight_2018] if ent_2018 == 1
    local _N = r(N)
    local _mean = r(mean)
    putexcel C`row' = `_mean', nformat("0.000")
    putexcel D`row' = `_N'
    local row = `row' + 1
}

* --- Self-reported enterprise problems (s10q45a-o) ---
local row = `row' + 1
putexcel B`row' = "Self-Reported Enterprise Problems (share reporting problem)"
local row = `row' + 1
putexcel B`row' = "Variable" C`row' = "Mean (2018)" D`row' = "N (2018)" ///
    E`row' = "Mean (2021)" F`row' = "N (2021)"
local row = `row' + 1

local prob_a "Supply of raw materials"
local prob_b "Lack of customers"
local prob_c "Too much competition"
local prob_d "Accessing credit"
local prob_e "Recruiting personnel"
local prob_f "Insufficient space"
local prob_g "Accessing equipment"
local prob_h "Technical manufacturing"
local prob_i "Technical management"
local prob_j "Electricity access"
local prob_k "Power outages"
local prob_l "Other infrastructure"
local prob_m "Internet"
local prob_n "Insecurity"
local prob_o "Regulation and taxes"

foreach letter in a b c d e f g h i j k l m n o {
    putexcel B`row' = "Problem: `prob_`letter''"

    * 2018
    capture gen byte _prob_`letter'_18 = (s10q45`letter'_2018 == 1) if ent_2018 == 1
    sum _prob_`letter'_18 [aw=hhweight_2018] if ent_2018 == 1
    local _N18 = r(N)
    local _mean18 = r(mean)
    putexcel C`row' = `_mean18', nformat("0.000")
    putexcel D`row' = `_N18'
    capture drop _prob_`letter'_18

    * 2021
    capture gen byte _prob_`letter'_21 = (s10q45`letter'_2021 == 1) if ent_2021 == 1
    sum _prob_`letter'_21 [aw=hhweight_2021] if ent_2021 == 1
    local _N21 = r(N)
    local _mean21 = r(mean)
    putexcel E`row' = `_mean21', nformat("0.000")
    putexcel F`row' = `_N21'
    capture drop _prob_`letter'_21

    local row = `row' + 1
}

* Age categories
putexcel B`row' = "Age category distribution"
local row = `row' + 1
forvalues c = 1/4 {
    local lbl : label (age_cat_2018) `c'
    putexcel B`row' = "Age: `lbl'"
    gen byte _ac = (age_cat_2018 == `c') if !missing(age_cat_2018)
    sum _ac [aw=hhweight_2018] if ent_2018 == 1
    local _N = r(N)
    local _mean = r(mean)
    putexcel C`row' = `_mean', nformat("0.000")
    putexcel D`row' = `_N'
    drop _ac
    local row = `row' + 1
}

* Education categories
putexcel B`row' = "Education distribution"
local row = `row' + 1
forvalues c = 1/3 {
    local lbl : label (educ_2018) `c'
    putexcel B`row' = "Educ: `lbl'"
    gen byte _ed = (educ_2018 == `c') if !missing(educ_2018)
    sum _ed [aw=hhweight_2018] if ent_2018 == 1
    local _N = r(N)
    local _mean = r(mean)
    putexcel C`row' = `_mean', nformat("0.000")
    putexcel D`row' = `_N'
    drop _ed
    local row = `row' + 1
}

* Consumption quintiles
putexcel B`row' = "Consumption quintile distribution"
local row = `row' + 1
forvalues c = 1/5 {
    putexcel B`row' = "Quintile `c'"
    gen byte _pq = (pcexpQ_2018 == `c') if !missing(pcexpQ_2018)
    sum _pq [aw=hhweight_2018] if ent_2018 == 1
    local _N = r(N)
    local _mean = r(mean)
    putexcel C`row' = `_mean', nformat("0.000")
    putexcel D`row' = `_N'
    drop _pq
    local row = `row' + 1
}


********************************************************************************
* PART 9: SECTION 4 — ENDOWMENTS AND VARIATION
********************************************************************************

di as text _n "=============================================="
di as text "SECTION 4: ENDOWMENTS AND VARIATION"
di as text "=============================================="

putexcel set "${xlout}", sheet("S4_Endowments") modify
putexcel B1 = "Section 4: Different Motives — Endowments and Variation"

*--- 4a: Descriptive stats on endowments ---
putexcel B3 = "Endowment Levels"
putexcel B4 = "Variable" C4 = "Mean" D4 = "Median" E4 = "P10" ///
    F4 = "P90"

local row = 5
foreach yr in 2018 2021 {
    * Log capital
    putexcel B`row' = "Log capital `yr'"
    sum log_capital_`yr' [aw=hhweight_`yr'] if ent_`yr' == 1, detail
    local _mean = r(mean)
    local _p10 = r(p10)
    local _p50 = r(p50)
    local _p90 = r(p90)
    putexcel C`row' = `_mean', nformat("0.00")
    putexcel D`row' = `_p50', nformat("0.00")
    putexcel E`row' = `_p10', nformat("0.00")
    putexcel F`row' = `_p90', nformat("0.00")
    local row = `row' + 1

    * Log profits
    putexcel B`row' = "Log profit `yr'"
    sum log_profit_`yr' [aw=hhweight_`yr'] if ent_`yr' == 1, detail
    local _mean = r(mean)
    local _p10 = r(p10)
    local _p50 = r(p50)
    local _p90 = r(p90)
    putexcel C`row' = `_mean', nformat("0.00")
    putexcel D`row' = `_p50', nformat("0.00")
    putexcel E`row' = `_p10', nformat("0.00")
    putexcel F`row' = `_p90', nformat("0.00")
    local row = `row' + 1

    * Non-family employees
    putexcel B`row' = "Non-family employees `yr'"
    sum num_emp_`yr' [aw=hhweight_`yr'] if ent_`yr' == 1, detail
    local _mean = r(mean)
    local _p10 = r(p10)
    local _p50 = r(p50)
    local _p90 = r(p90)
    putexcel C`row' = `_mean', nformat("0.00")
    putexcel D`row' = `_p50', nformat("0.00")
    putexcel E`row' = `_p10', nformat("0.00")
    putexcel F`row' = `_p90', nformat("0.00")
    local row = `row' + 1
}

*--- 4b: Histograms (profitability and investment) ---
* Following descriptive_stats.do for histogram specification

* Profits 2018 (winsorized, in 1000 CFA)
preserve
    keep if ent_2018 == 1
    sum profit_2018 [aw=hhweight_2018], d
    replace profit_2018 = r(p99) if profit_2018 > r(p99) & profit_2018 < .
    replace profit_2018 = r(p1) if profit_2018 < r(p1)
    gen profit_1k = profit_2018 / 1000
    histogram profit_1k [fw=int(hhweight_2018)], bins(20) percent ///
        color("60 168 158") lcolor("60 168 158") ///
        xtitle("Monthly Profit (1000 CFA)") ///
        title("Distribution of Profits, 2018") ///
        graphregion(color(white)) plotregion(fcolor(white)) ///
        saving("${output}/hist_profit_2018", replace) ///
        name(hist_profit_2018, replace)
    graph export "${output}/hist_profit_2018.png", replace
restore

* Capital 2018 (winsorized, in 1000 CFA)
preserve
    keep if ent_2018 == 1
    sum value_total_2018 [aw=hhweight_2018], d
    replace value_total_2018 = 1000000 if value_total_2018 > 1000000 & value_total_2018 < .
    gen capital_1k = value_total_2018 / 1000
    histogram capital_1k [fw=int(hhweight_2018)], bins(20) percent ///
        color("60 168 158") lcolor("60 168 158") ///
        xtitle("Capital Value (1000 CFA)") ///
        title("Distribution of Capital, 2018") ///
        graphregion(color(white)) plotregion(fcolor(white)) ///
        saving("${output}/hist_capital_2018", replace) ///
        name(hist_capital_2018, replace)
    graph export "${output}/hist_capital_2018.png", replace
restore

* Change in profit (real, winsorized, in 1000 CFA)
preserve
    keep if ent_2018 == 1 & ent_2021 == 1 & ind_matched == 1
    gen dprofit = profit_2021 - (profit_2018 * ${gdpdef_2021} / ${gdpdef_2018})
    * Note: using GDP deflator for consistency with panel construction
    sum dprofit [aw=hhweight_2018], d
    replace dprofit = r(p99) if dprofit > r(p99) & dprofit < .
    replace dprofit = r(p1) if dprofit < r(p1)
    gen dprofit_1k = dprofit / 1000
    histogram dprofit_1k [fw=int(hhweight)], bins(20) percent ///
        color("60 168 158") lcolor("60 168 158") ///
        xtitle("Change in Profit (1000 CFA)") ///
        title("Distribution of Change in Profits, 2018-2021") ///
        graphregion(color(white)) plotregion(fcolor(white)) ///
        saving("${output}/hist_dprofit", replace) ///
        name(hist_dprofit, replace)
    graph export "${output}/hist_dprofit.png", replace
restore

* Change in capital (real, in 1000 CFA)
preserve
    keep if ent_2018 == 1 & ent_2021 == 1 & ind_matched == 1
    gen dcapital = value_total_2021 - (value_total_2018 * ${gdpdef_2021} / ${gdpdef_2018})
    sum dcapital [aw=hhweight_2018], d
    replace dcapital = r(p99) if dcapital > r(p99) & dcapital < .
    replace dcapital = r(p1) if dcapital < r(p1)
    gen dcapital_1k = dcapital / 1000
    histogram dcapital_1k [fw=int(hhweight)], bins(20) percent ///
        color("60 168 158") lcolor("60 168 158") ///
        xtitle("Change in Capital (1000 CFA)") ///
        title("Distribution of Change in Capital, 2018-2021") ///
        graphregion(color(white)) plotregion(fcolor(white)) ///
        saving("${output}/hist_dcapital", replace) ///
        name(hist_dcapital, replace)
    graph export "${output}/hist_dcapital.png", replace
restore

*--- 4c: Value added per worker ---

local row = `row' + 2
putexcel B`row' = "Value Added per Worker"
local row = `row' + 1
putexcel B`row' = "Measure" C`row' = "2018" D`row' = "2021"
local row = `row' + 1

* Overall
putexcel B`row' = "Overall mean"
sum va_per_worker_2018 [aw=hhweight_2018] if ent_2018 == 1
local _mean = r(mean)
putexcel C`row' = `_mean', nformat("#,##0")
sum va_per_worker_2021 [aw=hhweight_2021] if ent_2021 == 1
local _mean = r(mean)
putexcel D`row' = `_mean', nformat("#,##0")
local row = `row' + 1

* By sector
putexcel B`row' = "VA/worker by sector"
local row = `row' + 1

* Get union of sector values across both waves
levelsof sector_2018 if ent_2018 == 1, local(svals_2018)
levelsof sector_2021 if ent_2021 == 1, local(svals_2021)
local all_svals : list svals_2018 | svals_2021
local all_svals : list sort all_svals

foreach s of local all_svals {
    * Try to get label from either wave
    capture local lbl : label (sector_2021) `s'
    if _rc != 0 {
        capture local lbl : label (sector_2018) `s'
    }
    if _rc != 0 local lbl "`s'"
    putexcel B`row' = "`lbl' (`s')"

    * 2018
    sum va_per_worker_2018 [aw=hhweight_2018] if ent_2018 == 1 & sector_2018 == `s'
    if r(N) > 0 {
        local _mean = r(mean)
        putexcel C`row' = `_mean', nformat("#,##0")
    }

    * 2021
    sum va_per_worker_2021 [aw=hhweight_2021] if ent_2021 == 1 & sector_2021 == `s'
    if r(N) > 0 {
        local _mean = r(mean)
        putexcel D`row' = `_mean', nformat("#,##0")
    }

    local row = `row' + 1
}


* Histograms for VA per worker
preserve
    keep if ent_2018 == 1
    sum va_per_worker_2018 [aw=hhweight_2018], d
    replace va_per_worker_2018 = r(p99) if va_per_worker_2018 > r(p99) & va_per_worker_2018 < .
    replace va_per_worker_2018 = r(p1) if va_per_worker_2018 < r(p1)
    gen va_1k = va_per_worker_2018 / 1000
    histogram va_1k [fw=int(hhweight_2018)], bins(20) percent ///
        color("60 168 158") lcolor("60 168 158") ///
        xtitle("VA per Worker (1000 CFA)") ///
        title("Value Added per Worker, 2018") ///
        graphregion(color(white)) plotregion(fcolor(white)) ///
        saving("${output}/hist_va_2018", replace) ///
        name(hist_va_2018, replace)
    graph export "${output}/hist_va_2018.png", replace
restore

* Export histogram summary statistics to Excel
putexcel set "${xlout}", sheet("S4_Histogram_Data") modify
putexcel B1 = "Histogram Chart Data — Summary Statistics (Winsorized)"
putexcel B3 = "Variable" C3 = "Mean" D3 = "Median" E3 = "SD" ///
    F3 = "P1" G3 = "P99" H3 = "N"

local hrow = 4

* Profit 2018
preserve
    keep if ent_2018 == 1
    sum profit_2018 [aw=hhweight_2018], d
    replace profit_2018 = r(p99) if profit_2018 > r(p99) & profit_2018 < .
    replace profit_2018 = r(p1) if profit_2018 < r(p1)
    gen profit_1k = profit_2018 / 1000
    sum profit_1k [aw=hhweight_2018], d
    putexcel B`hrow' = "Monthly Profit 2018 (1000 CFA)"
    local _N = r(N)
    local _max = r(max)
    local _mean = r(mean)
    local _min = r(min)
    local _p50 = r(p50)
    local _sd = r(sd)
    putexcel C`hrow' = `_mean', nformat("#,##0.0")
    putexcel D`hrow' = `_p50', nformat("#,##0.0")
    putexcel E`hrow' = `_sd', nformat("#,##0.0")
    putexcel F`hrow' = `_min', nformat("#,##0.0")
    putexcel G`hrow' = `_max', nformat("#,##0.0")
    putexcel H`hrow' = `_N'
restore
local hrow = `hrow' + 1

* Capital 2018
preserve
    keep if ent_2018 == 1
    sum value_total_2018 [aw=hhweight_2018], d
    replace value_total_2018 = 1000000 if value_total_2018 > 1000000 & value_total_2018 < .
    gen capital_1k = value_total_2018 / 1000
    sum capital_1k [aw=hhweight_2018], d
    putexcel B`hrow' = "Capital Value 2018 (1000 CFA)"
    local _N = r(N)
    local _max = r(max)
    local _mean = r(mean)
    local _min = r(min)
    local _p50 = r(p50)
    local _sd = r(sd)
    putexcel C`hrow' = `_mean', nformat("#,##0.0")
    putexcel D`hrow' = `_p50', nformat("#,##0.0")
    putexcel E`hrow' = `_sd', nformat("#,##0.0")
    putexcel F`hrow' = `_min', nformat("#,##0.0")
    putexcel G`hrow' = `_max', nformat("#,##0.0")
    putexcel H`hrow' = `_N'
restore
local hrow = `hrow' + 1

* Change in profit
preserve
    keep if ent_2018 == 1 & ent_2021 == 1 & ind_matched == 1
    gen dprofit = profit_2021 - (profit_2018 * ${gdpdef_2021} / ${gdpdef_2018})
    sum dprofit [aw=hhweight_2018], d
    replace dprofit = r(p99) if dprofit > r(p99) & dprofit < .
    replace dprofit = r(p1) if dprofit < r(p1)
    gen dprofit_1k = dprofit / 1000
    sum dprofit_1k [aw=hhweight_2018], d
    putexcel B`hrow' = "Change in Profit 2018-2021 (1000 CFA)"
    local _N = r(N)
    local _max = r(max)
    local _mean = r(mean)
    local _min = r(min)
    local _p50 = r(p50)
    local _sd = r(sd)
    putexcel C`hrow' = `_mean', nformat("#,##0.0")
    putexcel D`hrow' = `_p50', nformat("#,##0.0")
    putexcel E`hrow' = `_sd', nformat("#,##0.0")
    putexcel F`hrow' = `_min', nformat("#,##0.0")
    putexcel G`hrow' = `_max', nformat("#,##0.0")
    putexcel H`hrow' = `_N'
restore
local hrow = `hrow' + 1

* Change in capital
preserve
    keep if ent_2018 == 1 & ent_2021 == 1 & ind_matched == 1
    gen dcapital = value_total_2021 - (value_total_2018 * ${gdpdef_2021} / ${gdpdef_2018})
    sum dcapital [aw=hhweight_2018], d
    replace dcapital = r(p99) if dcapital > r(p99) & dcapital < .
    replace dcapital = r(p1) if dcapital < r(p1)
    gen dcapital_1k = dcapital / 1000
    sum dcapital_1k [aw=hhweight_2018], d
    putexcel B`hrow' = "Change in Capital 2018-2021 (1000 CFA)"
    local _N = r(N)
    local _max = r(max)
    local _mean = r(mean)
    local _min = r(min)
    local _p50 = r(p50)
    local _sd = r(sd)
    putexcel C`hrow' = `_mean', nformat("#,##0.0")
    putexcel D`hrow' = `_p50', nformat("#,##0.0")
    putexcel E`hrow' = `_sd', nformat("#,##0.0")
    putexcel F`hrow' = `_min', nformat("#,##0.0")
    putexcel G`hrow' = `_max', nformat("#,##0.0")
    putexcel H`hrow' = `_N'
restore
local hrow = `hrow' + 1

* VA per worker 2018
preserve
    keep if ent_2018 == 1
    sum va_per_worker_2018 [aw=hhweight_2018], d
    replace va_per_worker_2018 = r(p99) if va_per_worker_2018 > r(p99) & va_per_worker_2018 < .
    replace va_per_worker_2018 = r(p1) if va_per_worker_2018 < r(p1)
    gen va_1k = va_per_worker_2018 / 1000
    sum va_1k [aw=hhweight_2018], d
    putexcel B`hrow' = "VA per Worker 2018 (1000 CFA)"
    local _N = r(N)
    local _max = r(max)
    local _mean = r(mean)
    local _min = r(min)
    local _p50 = r(p50)
    local _sd = r(sd)
    putexcel C`hrow' = `_mean', nformat("#,##0.0")
    putexcel D`hrow' = `_p50', nformat("#,##0.0")
    putexcel E`hrow' = `_sd', nformat("#,##0.0")
    putexcel F`hrow' = `_min', nformat("#,##0.0")
    putexcel G`hrow' = `_max', nformat("#,##0.0")
    putexcel H`hrow' = `_N'
restore

*--- 4d: Productivity change ---
local row = `row' + 1
putexcel B`row' = "Productivity Changes (Panel Enterprises)"
local row = `row' + 1

gen va_change = va_per_worker_2021 - va_per_worker_2018 ///
    if ent_2018 == 1 & ent_2021 == 1 & ind_matched == 1

gen byte prod_direction = .
replace prod_direction = 1 if va_change > 0 & !missing(va_change)
replace prod_direction = 2 if va_change == 0 & !missing(va_change)
replace prod_direction = 3 if va_change < 0 & !missing(va_change)

putexcel B`row' = "Direction" C`row' = "Share (%)"
local row = `row' + 1

* Increased
gen byte _inc = (prod_direction == 1) if !missing(prod_direction)
sum _inc [aw=hhweight_2018] if ent_2018 == 1 & ent_2021 == 1 & ind_matched == 1
putexcel B`row' = "Productivity increased"
local _mean = r(mean)
putexcel C`row' = (`_mean' * 100), nformat("0.0")
drop _inc
local row = `row' + 1

* Same
gen byte _same = (prod_direction == 2) if !missing(prod_direction)
sum _same [aw=hhweight_2018] if ent_2018 == 1 & ent_2021 == 1 & ind_matched == 1
putexcel B`row' = "Productivity unchanged"
local _mean = r(mean)
putexcel C`row' = (`_mean' * 100), nformat("0.0")
drop _same
local row = `row' + 1

* Decreased
gen byte _dec = (prod_direction == 3) if !missing(prod_direction)
sum _dec [aw=hhweight_2018] if ent_2018 == 1 & ent_2021 == 1 & ind_matched == 1
putexcel B`row' = "Productivity decreased"
local _mean = r(mean)
putexcel C`row' = (`_mean' * 100), nformat("0.0")
drop _dec


********************************************************************************
* PART 10: SECTION 4 — GROWTH POTENTIAL
********************************************************************************

di as text _n "=============================================="
di as text "SECTION 4: GROWTH POTENTIAL"
di as text "=============================================="
putexcel set "${xlout}", sheet("S4_GrowthPotential") modify
putexcel B1 = "Section 4: Enterprises with Growth Potential"
putexcel B3 = "Indicator" C3 = "Value"
local row = 4

* Condition: matched enterprises present in both waves
local cond "ent_status == 4"

* Share that increased non-HH employees
putexcel B`row' = "Share that increased non-HH employees (%)"
gen byte _inc_emp = (change_num_emp > 0 & !missing(change_num_emp)) if `cond'
sum _inc_emp [aw=hhweight_2018] if `cond'
local _mean = r(mean)
putexcel C`row' = (`_mean' * 100), nformat("0.0")
local row = `row' + 1

* Share that increased real capital
putexcel B`row' = "Share that increased real capital (%)"
gen byte _inc_cap = (capital_increased == 1) if `cond'
sum _inc_cap [aw=hhweight_2018] if `cond'
local _mean = r(mean)
putexcel C`row' = (`_mean' * 100), nformat("0.0")
local row = `row' + 1

* Share that increased either
putexcel B`row' = "Share that increased employees or capital (%)"
gen byte _inc_either = (_inc_emp == 1 | _inc_cap == 1) if `cond'
sum _inc_either [aw=hhweight_2018] if `cond'
local _mean = r(mean)
putexcel C`row' = (`_mean' * 100), nformat("0.0")
local row = `row' + 1

* Share that increased both
putexcel B`row' = "Share that increased employees and capital (%)"
gen byte _inc_both = (_inc_emp == 1 & _inc_cap == 1) if `cond'
sum _inc_both [aw=hhweight_2018] if `cond'
local _mean = r(mean)
putexcel C`row' = (`_mean' * 100), nformat("0.0")

drop _inc_emp _inc_cap _inc_either _inc_both


********************************************************************************
* PART 11: SECTION 4 — LOW ENTRY BARRIERS / STEPPING STONE
********************************************************************************

di as text _n "=============================================="
di as text "SECTION 4: ENTRY, EXIT, AND STEPPING STONE"
di as text "=============================================="

tabout ent_exited total [iweight=hhweight_2021] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1(Share discontinued operations 2018-2021)
tabout ent_transition total if ent_2021==1 [iweight=hhweight_2021] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1(Share of 2021 enterprises that are new entrants in 2021)
tabout ent_entry_source total if ent_2021==1 [iweight=hhweight_2021] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1(Source of entry for all enterprises in 2021)
tabout ent_entry_source total if ent_2021==1 & ent_entry_source!=1 [iweight=hhweight_2021] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1(Source of entry for new enterprises in 2021)
tabout activity_type_2021 total if ent_2018==1 & ent_2021==0 [iweight=hhweight_2021] using "$output\Results.xls", append c(freq col row) format(0c 1p 1p) layout(cb)  h1(Current activity of those who were entrepreneurs in 2018 but left)

putexcel set "${xlout}", sheet("S4_EntryExit") modify
putexcel B1 = "Section 4: Low Entry Barriers and Stepping Stone"

putexcel B3 = "Low Entry Barriers" C3 = "Value"

local row = 4

* Share that discontinued operations (2018 entrepreneurs who exited)
putexcel B`row' = "Share discontinued operations 2018-2021 (%)"
sum ent_exited [aw=hhweight_2018] if ent_2018 == 1 & ind_matched == 1
local _mean = r(mean)
putexcel C`row' = (`_mean' * 100), nformat("0.0")
local row = `row' + 1


* Stepping stone
putexcel B`row' = "Household Enterprises as Stepping Stone"
local row = `row' + 1
putexcel B`row' = "Indicator" C`row' = "Share (%)"
local row = `row' + 1

* Share that experienced increase in profits (panel enterprises)
putexcel B`row' = "Enterprises with increased real profits"
sum profit_increased [aw=hhweight_2018] if ent_status==4
local _mean = r(mean)
putexcel C`row' = (`_mean' * 100), nformat("0.0")
local row = `row' + 1

* Share that experienced increase in TFP
putexcel B`row' = "Enterprises with increased TFP"
sum tfp_increased [aw=hhweight_2018] if ent_status==4
local _mean = r(mean)
putexcel C`row' = (`_mean' * 100), nformat("0.0")
local row = `row' + 1



********************************************************************************
* PART 12: SECTION 4 — TRANSITION TRAJECTORIES
********************************************************************************

di as text _n "=============================================="
di as text "SECTION 4: TRANSITION TRAJECTORIES"
di as text "=============================================="




putexcel set "${xlout}", sheet("S4_Transitions") modify
putexcel B1 = "Section 4: Transition Trajectories"

local row = 3

*--- Wage job to enterprise (ent_entry_source == 2) ---
putexcel B`row' = "Transition: Wage Job (2018) → Enterprise (2021)"
local row = `row' + 1

* Compare 2021 enterprise profit with 2018 wage income
gen byte _earn_compare = .
replace _earn_compare = 1 if profit_2021 > total_emp_income_month_2018 & ///
    !missing(profit_2021) & !missing(total_emp_income_month_2018) & ent_entry_source == 2
replace _earn_compare = 2 if profit_2021 == total_emp_income_month_2018 & ///
    !missing(profit_2021) & !missing(total_emp_income_month_2018) & ent_entry_source == 2
replace _earn_compare = 3 if profit_2021 < total_emp_income_month_2018 & ///
    !missing(profit_2021) & !missing(total_emp_income_month_2018) & ent_entry_source == 2

putexcel B`row' = "Earning comparison" C`row' = "Share (%)"
local row = `row' + 1

foreach cat in 1 2 3 {
    if `cat' == 1 local lbl = "Earning more as enterprise"
    if `cat' == 2 local lbl = "Earning the same"
    if `cat' == 3 local lbl = "Earning less as enterprise"
    putexcel B`row' = "`lbl'"
    gen byte _ec = (_earn_compare == `cat') if !missing(_earn_compare)
    sum _ec [aw=hhweight_2018] if ent_entry_source == 2
    local _N = r(N)
    local _mean = r(mean)
    if `_N' > 0 putexcel C`row' = (`_mean' * 100), nformat("0.0")
    drop _ec
    local row = `row' + 1
}
drop _earn_compare
local row = `row' + 1

*--- Enterprise to wage job ---
putexcel B`row' = "Transition: Enterprise (2018) → Wage Job (2021)"
local row = `row' + 1

* Identify: 2018 entrepreneur, 2021 wage worker
gen byte _ent_to_wage = (ent_2018 == 1 & activity_type_2021 == 2 & ind_matched == 1)

putexcel B`row' = "Job Type" C`row' = "Share (%)" D`row' = "N"
local row = `row' + 1

* Public/private
putexcel B`row' = "Public employer"
sum public_employer_2021 [aw=hhweight_2018] if _ent_to_wage == 1
if r(N) > 0 {
    local _N = r(N)
    local _mean = r(mean)
    putexcel C`row' = (`_mean' * 100), nformat("0.0")
    putexcel D`row' = `_N'
}
local row = `row' + 1

putexcel B`row' = "Private employer"
gen byte _priv = (public_employer_2021 == 0) if _ent_to_wage == 1 & !missing(public_employer_2021)
sum _priv [aw=hhweight_2018] if _ent_to_wage == 1
local _N = r(N)
local _mean = r(mean)
if `_N' > 0 putexcel C`row' = (`_mean' * 100), nformat("0.0")
drop _priv
local row = `row' + 1

* Formal/informal
putexcel B`row' = "Formal (pension contribution)"
sum formal_2021 [aw=hhweight_2018] if _ent_to_wage == 1
if r(N) > 0 {
    local _N = r(N)
    local _mean = r(mean)
    putexcel C`row' = (`_mean' * 100), nformat("0.0")
    putexcel D`row' = `_N'
}
local row = `row' + 1

putexcel B`row' = "Informal"
gen byte _inf = (formal_2021 == 0) if _ent_to_wage == 1 & !missing(formal_2021)
sum _inf [aw=hhweight_2018] if _ent_to_wage == 1
local _N = r(N)
local _mean = r(mean)
if `_N' > 0 putexcel C`row' = (`_mean' * 100), nformat("0.0")
drop _inf
local row = `row' + 1

* Sector of wage job
putexcel B`row' = "Sector of wage job (2021)"
local row = `row' + 1
levelsof sector_work_2021 if _ent_to_wage == 1, local(sw_vals)
foreach s of local sw_vals {
    local lbl : label (sector_work_2021) `s'
    putexcel B`row' = "`lbl' (`s')"
    gen byte _sw = (sector_work_2021 == `s') if _ent_to_wage == 1 & !missing(sector_work_2021)
    sum _sw [aw=hhweight_2018] if _ent_to_wage == 1
    local _N = r(N)
    local _mean = r(mean)
    if `_N' > 0 putexcel C`row' = (`_mean' * 100), nformat("0.0")
    drop _sw
    local row = `row' + 1
}
local row = `row' + 1

*--- Hours worked by transition type ---
putexcel B`row' = "Hours Worked (2021) by Transition Type"
local row = `row' + 1
putexcel B`row' = "Transition" C`row' = "Avg Hours/Month"
local row = `row' + 1

* Remained entrepreneur
putexcel B`row' = "Remained entrepreneur"
sum hours_worked_month_2021 [aw=hhweight_2018] if ent_transition == 4
local _N = r(N)
local _mean = r(mean)
if `_N' > 0 putexcel C`row' = `_mean', nformat("0.0")
local row = `row' + 1

* Enterprise → Wage
putexcel B`row' = "Enterprise to wage job"
sum hours_worked_month_2021 [aw=hhweight_2018] if _ent_to_wage == 1
local _N = r(N)
local _mean = r(mean)
if `_N' > 0 putexcel C`row' = `_mean', nformat("0.0")
local row = `row' + 1

* Wage → Enterprise
putexcel B`row' = "Wage job to enterprise"
sum hours_worked_month_2021 [aw=hhweight_2018] if ent_entry_source == 2
local _N = r(N)
local _mean = r(mean)
if `_N' > 0 putexcel C`row' = `_mean', nformat("0.0")
local row = `row' + 1

* Inactive → Enterprise
putexcel B`row' = "Inactive to enterprise"
sum hours_worked_month_2021 [aw=hhweight_2018] if ent_entry_source == 4
local _N = r(N)
local _mean = r(mean)
if `_N' > 0 putexcel C`row' = `_mean', nformat("0.0")
local row = `row' + 2

*--- Average HH members in wage jobs by transition type ---
putexcel B`row' = "Avg HH Members in Wage Jobs (2021) by Transition Type"
local row = `row' + 1
putexcel B`row' = "Transition" C`row' = "Avg N wage earners in HH"
local row = `row' + 1

putexcel B`row' = "Remained entrepreneur"
sum n_hh_wage_2021 [aw=hhweight_2018] if ent_transition == 4
local _N = r(N)
local _mean = r(mean)
if `_N' > 0 putexcel C`row' = `_mean', nformat("0.00")
local row = `row' + 1

putexcel B`row' = "Enterprise to wage job"
sum n_hh_wage_2021 [aw=hhweight_2018] if _ent_to_wage == 1
local _N = r(N)
local _mean = r(mean)
if `_N' > 0 putexcel C`row' = `_mean', nformat("0.00")
local row = `row' + 1

putexcel B`row' = "Wage job to enterprise"
sum n_hh_wage_2021 [aw=hhweight_2018] if ent_entry_source == 2
local _N = r(N)
local _mean = r(mean)
if `_N' > 0 putexcel C`row' = `_mean', nformat("0.00")
local row = `row' + 1

putexcel B`row' = "Inactive to enterprise"
sum n_hh_wage_2021 [aw=hhweight_2018] if ent_entry_source == 4
local _N = r(N)
local _mean = r(mean)
if `_N' > 0 putexcel C`row' = `_mean', nformat("0.00")

drop _ent_to_wage


********************************************************************************
* PART 13: GRAPH — HH ENTERPRISE EMPLOYMENT: YOUTH VS ADULTS
********************************************************************************

di as text _n "=============================================="
di as text "GRAPH: Youth vs Adult HH Enterprise Employment"
di as text "=============================================="

* Compute share of non-farm employment in HH enterprises by age group
* Non-farm = sector_work != 1 (excludes agriculture and extractives)
* Youth = 15-24, Adults = 25+

preserve

    * We need 4 data points: Youth & Adults × 2018 & 2021
    * Build a small dataset with the computed shares

    * --- 2018 ---
    * Youth non-farm employed
    count if employed_2018 == 1 & sector_work_2018 != 1 & !missing(sector_work_2018) ///
        & age_2018 >= 15 & age_2018 <= 24
    local nf_youth_18 = r(N)
    * Youth in HH enterprises (ent == 1 is a subset of non-farm employed)
    count if ent_2018 == 1 & age_2018 >= 15 & age_2018 <= 24
    local ent_youth_18 = r(N)

    * Adults non-farm employed
    count if employed_2018 == 1 & sector_work_2018 != 1 & !missing(sector_work_2018) ///
        & age_2018 >= 25 & age_2018 < .
    local nf_adult_18 = r(N)
    * Adults in HH enterprises
    count if ent_2018 == 1 & age_2018 >= 25 & age_2018 < .
    local ent_adult_18 = r(N)

    * Weighted versions
    sum hhweight_2018 if employed_2018 == 1 & sector_work_2018 != 1 ///
        & !missing(sector_work_2018) & age_2018 >= 15 & age_2018 <= 24
    local w_nf_youth_18 = r(sum)
    sum hhweight_2018 if ent_2018 == 1 & age_2018 >= 15 & age_2018 <= 24
    local w_ent_youth_18 = r(sum)

    sum hhweight_2018 if employed_2018 == 1 & sector_work_2018 != 1 ///
        & !missing(sector_work_2018) & age_2018 >= 25 & age_2018 < .
    local w_nf_adult_18 = r(sum)
    sum hhweight_2018 if ent_2018 == 1 & age_2018 >= 25 & age_2018 < .
    local w_ent_adult_18 = r(sum)

    * --- 2021 ---
    sum hhweight_2021 if employed_2021 == 1 & sector_work_2021 != 1 ///
        & !missing(sector_work_2021) & age_2021 >= 15 & age_2021 <= 24
    local w_nf_youth_21 = r(sum)
    sum hhweight_2021 if ent_2021 == 1 & age_2021 >= 15 & age_2021 <= 24
    local w_ent_youth_21 = r(sum)

    sum hhweight_2021 if employed_2021 == 1 & sector_work_2021 != 1 ///
        & !missing(sector_work_2021) & age_2021 >= 25 & age_2021 < .
    local w_nf_adult_21 = r(sum)
    sum hhweight_2021 if ent_2021 == 1 & age_2021 >= 25 & age_2021 < .
    local w_ent_adult_21 = r(sum)

    * Compute shares
    local sh_youth_18 = `w_ent_youth_18' / `w_nf_youth_18'
    local sh_adult_18 = `w_ent_adult_18' / `w_nf_adult_18'
    local sh_youth_21 = `w_ent_youth_21' / `w_nf_youth_21'
    local sh_adult_21 = `w_ent_adult_21' / `w_nf_adult_21'

    * Build plotting dataset
    clear
    set obs 2
    gen float ypos = .
    gen float youth = .
    gen float adult = .
    replace ypos  = 2 in 1
    replace youth = `sh_youth_18' in 1
    replace adult = `sh_adult_18' in 1
    replace ypos  = 1 in 2
    replace youth = `sh_youth_21' in 2
    replace adult = `sh_adult_21' in 2

    * Labels for y-axis
    label define country_lbl 2 "SEN (2018)" 1 "SEN (2021)"
    label values ypos country_lbl

    * Cleveland dot plot with connecting lines (Teal-Terracotta palette)
    twoway ///
        (pcspike ypos youth ypos adult, ///
            horizontal lcolor("232 224 208") lwidth(medium)) ///
        (scatter ypos youth, ///
            msymbol(circle) msize(large) mcolor("193 68 14") ///
            mlwidth(none)) ///
        (scatter ypos adult, ///
            msymbol(triangle) msize(large) mcolor("60 168 158") ///
            mlwidth(none)) ///
        , ///
        ytitle("") ///
        ylabel(1 "SEN (2021)" 2 "SEN (2018)", angle(0) labsize(medium) nogrid) ///
        yscale(range(0.5 2.5)) ///
        xtitle("Share of non-farm employment in household enterprises", size(small)) ///
        xlabel(, format(%4.2f) grid gstyle(dot)) ///
        title("Household enterprise employment: youth vs adults", size(medium)) ///
        legend(order(2 "Youth (15{&ndash}24)" 3 "Adults (25+)") ///
            rows(1) position(6) size(small) ///
            symxsize(4) region(lcolor(none))) ///
        plotregion(margin(l=2 r=2)) ///
        graphregion(color(white)) ///
        scheme(s2color) ///
        name(youth_vs_adults, replace)

    graph export "${output}/youth_vs_adults_hh_enterprise.png", replace width(1200)
    graph save "${output}/youth_vs_adults_hh_enterprise.gph", replace

restore

* Also export the shares to Excel
putexcel set "${xlout}", sheet("S1_YouthAdults") modify
putexcel B1 = "HH Enterprise Employment: Youth vs Adults"
putexcel B2 = "Share of non-farm employment in household enterprises (weighted)"
putexcel B4 = "Country-Year" C4 = "Youth (15-24)" D4 = "Adults (25+)"
putexcel B5 = "SEN (2018)"
putexcel C5 = `sh_youth_18', nformat("0.000")
putexcel D5 = `sh_adult_18', nformat("0.000")
putexcel B6 = "SEN (2021)"
putexcel C6 = `sh_youth_21', nformat("0.000")
putexcel D6 = `sh_adult_21', nformat("0.000")


********************************************************************************
* ENTERPRISE SECTOR DISAGGREGATION BY LOCATION (2021)
********************************************************************************

* location_2021 created in 03_clean_2021.do:
*   1 = Dakar (urban only), 2 = Thiès (urban only),
*   3 = Other urban, 4 = Rural

* Sector labels (from s10q17a recode)
local sec_1 "Ag and extractives"
local sec_2 "Manufacturing"
local sec_3 "Utilities & construction"
local sec_5 "Retail"
local sec_6 "Transport"
local sec_7 "Personal services"
local sec_9 "Other"

* Sector codes in order
local sec_codes 1 2 3 5 6 7 9

* Compute share of enterprises in each sector, by location (columns sum to 100)
* Using 2021 enterprise owners only, weighted
foreach loc in 1 2 3 4 {
    * Total weighted enterprises in this location
    sum ent_2021 [aw=hhweight_2021] if ent_2021 == 1 & location_2021 == `loc'
    local tot_`loc' = r(sum_w)

    foreach s of local sec_codes {
        gen byte _sec_`s' = (sector_2021 == `s') if ent_2021 == 1 & location_2021 == `loc'
        sum _sec_`s' [aw=hhweight_2021] if ent_2021 == 1 & location_2021 == `loc'
        local sh_`s'_`loc' = r(mean) * 100
        drop _sec_`s'
    }
}

* Write to Excel
putexcel set "${xlout}", sheet("Sector_by_Location") modify
putexcel B1 = "Enterprise Sector Distribution by Location (2021)"
putexcel B2 = "Share of enterprises by sector within each location (%, weighted)"
putexcel B3 = "Each column sums to 100"

putexcel B5 = "Sector" C5 = "Dakar" D5 = "Thiès" E5 = "Other urban" F5 = "Rural"

local row = 6
foreach s of local sec_codes {
    putexcel B`row' = "`sec_`s''"
    putexcel C`row' = `sh_`s'_1', nformat("0.0")
    putexcel D`row' = `sh_`s'_2', nformat("0.0")
    putexcel E`row' = `sh_`s'_3', nformat("0.0")
    putexcel F`row' = `sh_`s'_4', nformat("0.0")
    local row = `row' + 1
}

* Add totals row
putexcel B`row' = "Total"
putexcel C`row' = formula("=SUM(C6:C12)"), nformat("0.0")
putexcel D`row' = formula("=SUM(D6:D12)"), nformat("0.0")
putexcel E`row' = formula("=SUM(E6:E12)"), nformat("0.0")
putexcel F`row' = formula("=SUM(F6:F12)"), nformat("0.0")

local row = `row' + 2
putexcel B`row' = "N (weighted enterprises)"
putexcel C`row' = `tot_1', nformat("#,##0")
putexcel D`row' = `tot_2', nformat("#,##0")
putexcel E`row' = `tot_3', nformat("#,##0")
putexcel F`row' = `tot_4', nformat("#,##0")


********************************************************************************
* CREDIT SOURCES BY ENTERPRISE STATUS (2021, Module 6)
********************************************************************************

* Credit access and source shares for entrepreneurs vs non-entrepreneurs
* Using HH-level credit variables from 2021 cleaning file

putexcel set "${xlout}", sheet("Credit_by_Enterprise") modify
putexcel B1 = "Sources of Credit by Enterprise Status (2021)"
putexcel B2 = "Share of households (%, weighted)"

putexcel B4 = "" C4 = "Entrepreneurs" D4 = "Non-entrepreneurs"

local row = 5

* a) Got any credit
putexcel B`row' = "Got credit (any source)"
foreach g in 1 0 {
    local col = cond(`g'==1, "C", "D")
    sum hh_has_loan_2021 [aw=hhweight_2021] if ent_2021 == `g'
    local _mean = r(mean)
    putexcel `col'`row' = (`_mean' * 100), nformat("0.0")
}
local row = `row' + 1

* b) Formal vs informal (among those with credit)
putexcel B`row' = "  Formal source"
foreach g in 1 0 {
    local col = cond(`g'==1, "C", "D")
    sum hh_formal_credit_2021 [aw=hhweight_2021] if ent_2021 == `g' & hh_has_loan_2021 == 1
    local _mean = r(mean)
    putexcel `col'`row' = (`_mean' * 100), nformat("0.0")
}
local row = `row' + 1

putexcel B`row' = "  Informal source"
foreach g in 1 0 {
    local col = cond(`g'==1, "C", "D")
    sum hh_informal_credit_2021 [aw=hhweight_2021] if ent_2021 == `g' & hh_has_loan_2021 == 1
    local _mean = r(mean)
    putexcel `col'`row' = (`_mean' * 100), nformat("0.0")
}
local row = `row' + 1

* c) Specific sources (among those with credit)
putexcel B`row' = "Credit source breakdown (among HHs with credit):"
local row = `row' + 1

local src_lab_1 "  Bank"
local src_lab_2 "  MFI/Rural Credit Union"
local src_lab_3 "  Cooperative"
local src_lab_4 "  Tontine"
local src_var_1 "hh_credit_bank_2021"
local src_var_2 "hh_credit_mfi_2021"
local src_var_3 "hh_credit_coop_2021"
local src_var_4 "hh_credit_tontine_2021"

forvalues i = 1/4 {
    putexcel B`row' = "`src_lab_`i''"
    foreach g in 1 0 {
        local col = cond(`g'==1, "C", "D")
        sum `src_var_`i'' [aw=hhweight_2021] if ent_2021 == `g' & hh_has_loan_2021 == 1
        local _mean = r(mean)
        putexcel `col'`row' = (`_mean' * 100), nformat("0.0")
    }
    local row = `row' + 1
}

* d) Mean credit amount (among those with credit)
putexcel B`row' = "Mean credit amount (FCFA)"
foreach g in 1 0 {
    local col = cond(`g'==1, "C", "D")
    sum hh_total_credit_amount_2021 [aw=hhweight_2021] if ent_2021 == `g' & hh_has_loan_2021 == 1
    local _mean = r(mean)
    putexcel `col'`row' = `_mean', nformat("#,##0")
}
local row = `row' + 1

* e) Has outstanding loans
putexcel B`row' = "Has outstanding loans"
foreach g in 1 0 {
    local col = cond(`g'==1, "C", "D")
    sum hh_has_outstanding_2021 [aw=hhweight_2021] if ent_2021 == `g'
    local _mean = r(mean)
    putexcel `col'`row' = (`_mean' * 100), nformat("0.0")
}
local row = `row' + 2

* Sample sizes
putexcel B`row' = "N (households)"
sum ent_2021 [aw=hhweight_2021] if ent_2021 == 1
local _N = r(N)
putexcel C`row' = `_N', nformat("#,##0")
sum ent_2021 [aw=hhweight_2021] if ent_2021 == 0
local _N = r(N)
putexcel D`row' = `_N', nformat("#,##0")


********************************************************************************
* REMITTANCES BY ENTERPRISE STATUS (2021, Module 13)
********************************************************************************

putexcel set "${xlout}", sheet("Remittances_by_Enterprise") modify
putexcel B1 = "Remittances Received by Enterprise Status (2021)"
putexcel B2 = "Share of households (%, weighted)"

putexcel B4 = "" C4 = "Entrepreneurs" D4 = "Non-entrepreneurs"

local row = 5

* a) Received any remittances
putexcel B`row' = "Received remittances"
foreach g in 1 0 {
    local col = cond(`g'==1, "C", "D")
    sum hh_received_remittances_2021 [aw=hhweight_2021] if ent_2021 == `g'
    local _mean = r(mean)
    putexcel `col'`row' = (`_mean' * 100), nformat("0.0")
}
local row = `row' + 1

* b) Remittances from abroad (among those receiving)
putexcel B`row' = "  From abroad"
foreach g in 1 0 {
    local col = cond(`g'==1, "C", "D")
    sum hh_remit_from_abroad_2021 [aw=hhweight_2021] if ent_2021 == `g' & hh_received_remittances_2021 == 1
    local _mean = r(mean)
    putexcel `col'`row' = (`_mean' * 100), nformat("0.0")
}
local row = `row' + 1

* c) Domestic only (among those receiving)
putexcel B`row' = "  Domestic only"
foreach g in 1 0 {
    local col = cond(`g'==1, "C", "D")
    gen byte _dom_remit = (hh_remit_from_abroad_2021 == 0) if hh_received_remittances_2021 == 1
    sum _dom_remit [aw=hhweight_2021] if ent_2021 == `g' & hh_received_remittances_2021 == 1
    local _mean = r(mean)
    putexcel `col'`row' = (`_mean' * 100), nformat("0.0")
    drop _dom_remit
}
local row = `row' + 1

* d) Mean annual remittance amount (among those receiving)
putexcel B`row' = "Mean annual amount (FCFA)"
foreach g in 1 0 {
    local col = cond(`g'==1, "C", "D")
    sum hh_remit_total_annual_2021 [aw=hhweight_2021] if ent_2021 == `g' & hh_received_remittances_2021 == 1
    local _mean = r(mean)
    putexcel `col'`row' = `_mean', nformat("#,##0")
}
local row = `row' + 1

* e) Median annual remittance amount (among those receiving)
putexcel B`row' = "Median annual amount (FCFA)"
foreach g in 1 0 {
    local col = cond(`g'==1, "C", "D")
    _pctile hh_remit_total_annual_2021 [aw=hhweight_2021] if ent_2021 == `g' & hh_received_remittances_2021 == 1, p(50)
    local _r1 = r(r1)
    putexcel `col'`row' = `_r1', nformat("#,##0")
}
local row = `row' + 2

* Sample sizes
putexcel B`row' = "N (households)"
sum ent_2021 [aw=hhweight_2021] if ent_2021 == 1
local _N = r(N)
putexcel C`row' = `_N', nformat("#,##0")
sum ent_2021 [aw=hhweight_2021] if ent_2021 == 0
local _N = r(N)
putexcel D`row' = `_N', nformat("#,##0")


********************************************************************************
* DONE
********************************************************************************

di as text _n "=============================================="
di as result "ANALYSIS COMPLETE"
di as text "=============================================="
di as text ""
di as text "Output file: ${xlout}"
di as text ""
di as text "Excel tabs created:"
di as text "  1. S1_Introduction        - HH enterprise rates, enterprise size"
di as text "  2. S1_EntByLocation       - HH enterprise ownership by location (chart data)"
di as text "  3. S1_NonfarmComposition  - Non-farm employment composition (chart data)"
di as text "  4. S2_Profile             - Formality, sectors, gender, employees"
di as text "  5. S2_SectorComposition   - Sector composition of HH enterprises (chart data)"
di as text "  6. S2_EmployerEnterprises - Employer enterprises by urban/rural (chart data)"
di as text "  7. S2_HE_Welfare          - HE ownership across welfare quintiles (chart data)"
di as text "  8. S2_Profile_Chart       - HE vs Wage worker profiles (chart data)"
di as text "  5. S3_Performance         - Profits, profit growth, internet/electricity"
di as text "  6. S3_Reg_Profit          - Profit regression results"
di as text "  7. S3_Reg_Capital         - Capital regression results"
di as text "  8. S3_Reg_NumEmp          - Employee regression results"
di as text "  9. S3_Reg_Coop            - All 3 regressions with cooperative dummy"
di as text "  10. Annex_DescStats       - Descriptive statistics for variables"
di as text "  11. S4_Endowments         - Endowment levels, VA per worker"
di as text "  12. S4_Histogram_Data     - Histogram summary statistics (chart data)"
di as text "  13. S4_GrowthPotential    - Growth indicators"
di as text "  14. S4_EntryExit          - Entry/exit, stepping stone, TFP"
di as text "  15. S4_Transitions        - Transition trajectories"
di as text "  16. TFP_Estimates         - Production function estimates"
di as text "  17. S1_YouthAdults        - Youth vs adult HH enterprise employment"
di as text "  18. Sector_by_Location    - Enterprise sector distribution by Dakar/Thiès/Urban/Rural (2021)"
di as text "  19. Credit_by_Enterprise  - Credit sources: entrepreneurs vs non-entrepreneurs (2021)"
di as text "  20. Remittances_by_Enterprise - Remittances: entrepreneurs vs non-entrepreneurs (2021)"
di as text ""
di as text "Graphs saved to ${output}/"
di as text "  hh_ent_by_location.png"
di as text "  sector_composition.png"
di as text "  employer_enterprises.png"
di as text "  he_ownership_welfare.png"
di as text "  nonfarm_composition.png"
di as text "  profile_he_vs_wage.png"
di as text "  youth_vs_adults_hh_enterprise.png"
di as text "  hist_profit_2018.png, hist_capital_2018.png"
di as text "  hist_dprofit.png, hist_dcapital.png"
di as text "  hist_va_2018.png"
di as text "=============================================="

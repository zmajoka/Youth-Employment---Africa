********************************************************************************
* EHCVM SENEGAL - PANEL DATA: MERGE 2018 AND 2021
********************************************************************************
* Purpose: Create a panel dataset by merging 2018 and 2021 cleaned data.
*          Includes all variables specified in the Analysis Plan.
*
* Author:  Zaineb Majoka (mzaineb@worldbank.org)
* Date:    March 2026
*
* INPUT:   ${intermediate}/SEN_2018_cleaned.dta
*          ${intermediate}/SEN_2021_cleaned.dta
*
* OUTPUT:  ${final}/SEN_panel_2018_2021.dta
*
* NOTES:
*   - Unit of observation: individual (numind) within household (grappe+menage)
*   - HH matching uses grappe + menage (same EA and household number)
*   - Individual matching uses grappe + menage + numind, with gender/age checks
*   - All year-specific variables carry _2018 or _2021 suffixes
*   - Panel-level variables (transitions, changes) have no suffix
*
* CHANGING THE LEVEL OF ANALYSIS
* ------------------------------
* The panel dataset contains ALL individuals from the 2018 household roster,
* including non-entrepreneurs. The following variables (created in Part 5)
* allow you to restrict the sample depending on the research question:
*
*   is_entrepreneur     Individual-level dummy. = 1 if the person was an
*                       entrepreneur in at least one wave. Entrepreneurs are
*                       identified at the individual level using nonag_id
*                       (grappe + menage + numind), matching the approach in
*                       set_up_data.do.
*                       Usage: keep if is_entrepreneur == 1
*
*   ent_status          4-category variable:
*                         1 = Not entrepreneur in either wave
*                         2 = Entrepreneur in 2018 only
*                         3 = Entrepreneur in 2021 only
*                         4 = Entrepreneur in both waves
*                       Usage: keep if ent_status != 1  (drop non-entrepreneurs)
*                              keep if ent_status == 4  (panel entrepreneurs only)
*
*   hh_has_enterprise   Household-level dummy. = 1 if ANY member of the
*                       household was an entrepreneur in either wave. Use this
*                       to keep all members of entrepreneurial households.
*                       Usage: keep if hh_has_enterprise == 1
*
*   is_hh_head_YYYY     Household head dummy based on relationship to head
*                       (lien == 1) from the individual roster, not numind.
********************************************************************************

clear all
set more off

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

* Create directories if needed
capture mkdir "${final}"
capture mkdir "${output}"

* GDP Deflator values (2018 base year)
* Source: WDI
global gdpdef_2018 = 167.29
global gdpdef_2021 = 213.67
* NOTE: GDP deflator is a broader economy-wide price index that covers all
* goods and services produced in the economy, including investment goods and
* government spending, not just consumer goods. For firm-level data (revenue
* and costs), it tends to be a more neutral and representative deflator than CPI.
*
* Formula for real values:
* Real Value (2018 prices) = Nominal Value × (Deflator_2018 / Deflator_2021)

********************************************************************************
* PART 1: PREPARE 2018 DATA - Rename all variables with _2018 suffix
********************************************************************************

di as text _n "=============================================="
di as text "STEP 1: Preparing 2018 data"
di as text "=============================================="

use "${intermediate}/SEN_2018_cleaned.dta", clear

* ----- Identification variables: keep as-is for merging -----
* grappe, menage, numind will be used as merge keys

* ----- Create hhid consistently -----
capture drop hhid
gen long hhid = grappe * 1000 + menage
label variable hhid "Household ID (grappe*1000 + menage)"

* ----- Variables already suffixed with _2018 in cleaning do-file -----
* sexe_2018, age_2018, educ_hi_2018, alfab_2018, educ_scol_2018
* activ7j_2018, hcsp_2018, hhweight_2018, ethnie_2018

* ----- Rename non-suffixed variables to add _2018 -----

* Enterprise indicators
capture rename ent_2018 ent_2018  // already named

* Individual characteristics
rename zae zae_2018
rename milieu milieu_2018

* Enterprise variables (only exist for entrepreneurs)
foreach v in proprietor_id nonag_id is_proprietor {
    capture rename `v' `v'_2018
}

* Enterprise performance
foreach v in revenue expenses profit value_total value_machines ///
    value_vehicles value_furniture value_other owns_assets ///
    val_hired_labor max_rev_by_owner {
    capture rename `v' `v'_2018
}

* Enterprise characteristics
foreach v in num_emp num_emp_tot num_emp_child ent_child_emp ///
    num_hhemp hires_nonhh_workers num_hhemp_cat ///
    no_wages_paid place financing year_est ///
    firm_keeps_accounts firm_has_fisc_id ///
    firm_in_trade_register firm_cnps_registered ///
    legal_form cooperative is_highest_revenue sector ///
    share_revenue_resale share_revenue_processed share_revenue_services ///
    N_enterprises_hh multiple_enterprises {
    capture rename `v' `v'_2018
}

* Problem variables
foreach letter in a b c d e f g h i j k l m n o {
    capture rename s10q45`letter' s10q45`letter'_2018
}

* Employment variables
foreach v in employed unemployed in_labor_force working_age ///
    sector_work emp_type formal public_employer ///
    days_worked_month hours_worked_day hours_worked_month months_worked ///
    salary_month bonus_month benefits_inkind_month food_value_month ///
    total_comp_month has_secondary_job ///
    days_worked_month_sec hours_worked_day_sec hours_worked_month_sec ///
    salary_month_sec bonus_month_sec benefits_inkind_month_sec ///
    food_value_month_sec total_comp_month_sec total_emp_income_month {
    capture rename `v' `v'_2018
}

* Section 4 raw variables (keep for reference)
foreach v of varlist s04q* {
    capture rename `v' `v'_2018
}

* Household head variables
foreach v in hgender hage hmstat hreligion hnation halfab ///
    heduc hdiploma hhandig hactiv7j hactiv12m hbranch hsectins hcsp {
    capture rename `v' `v'_2018
}

* Household characteristics
foreach v in hhweight hhsize eqadu1 eqadu2 region ///
    logem mur toit sol ///
    eauboi_ss eauboi_sp elec_ac elec_ur elec_ua ///
    ordure toilet eva_toi eva_eau ///
    tv fer frigo cuisin ordin decod car superf ///
    grosrum petitrum porc lapin volail ///
    sh_id_demo sh_co_natu sh_co_eco sh_id_eco sh_co_vio sh_co_oth {
    capture rename `v' `v'_2018
}

* Rename household electricity to has_electricity
capture rename elec_ac_2018 has_electricity_2018

* Welfare variables
foreach v in dali dnal dtot pcexp zzae zref def_spa def_temp {
    capture rename `v' `v'_2018
}

* Credit variables
foreach v in ind_credit_12m ind_has_loan ind_loan_source ind_credit_amount ///
    ind_has_outstanding ind_num_outstanding ///
    hh_credit_12m hh_has_loan hh_num_with_loan hh_main_credit_source ///
    hh_total_credit_amount hh_has_outstanding hh_total_outstanding ///
    hh_formal_credit hh_informal_credit ///
    hh_credit_bank hh_credit_mfi hh_credit_coop hh_credit_tontine {
    capture rename `v' `v'_2018
}

* Remittance variables
foreach v in hh_remit_total_annual hh_remit_from_abroad hh_received_remittances {
    capture rename `v' `v'_2018
}

* Bank account variable
capture rename has_bank has_bank_2018

* Location classification
capture rename location location_2018

* Credit section raw variables
foreach v of varlist s06q* {
    capture rename `v' `v'_2018
}

* Section 10 raw variables (enterprise detail)
foreach v of varlist s10q* {
    capture rename `v' `v'_2018
}

* Internet access: has_internet_2018 already created from ehcvm_individu in 02_clean_2018.do
* (individual-level variable "internet", coded 0/1)

* Country and year
capture rename country country_2018
drop if missing(grappe) | missing(menage) | missing(numind)

* Keep track of which year
gen byte in_2018 = 1
label variable in_2018 "Individual observed in 2018"

* Household head dummy (based on relationship to head variable, lien == 1)
gen byte is_hh_head_2018 = (lien_2018 == 1)
label variable is_hh_head_2018 "Is household head in 2018"

* Enterprise household dummy
bysort hhid: egen byte hh_has_enterprise_2018 = max(ent_2018)
label variable hh_has_enterprise_2018 "Household has at least one enterprise in 2018"

tempfile data_2018
save `data_2018'

di as result "2018 data prepared: `=_N' observations"


********************************************************************************
* PART 2: PREPARE 2021 DATA - Rename all variables with _2021 suffix
********************************************************************************

di as text _n "=============================================="
di as text "STEP 2: Preparing 2021 data"
di as text "=============================================="

use "${intermediate}/SEN_2021_cleaned.dta", clear

* ----- Create hhid consistently -----
capture drop hhid
capture drop hhid1
gen long hhid = grappe * 1000 + menage
label variable hhid "Household ID (grappe*1000 + menage)"

* ----- Variables already suffixed with _2021 in cleaning do-file -----
* sexe_2021, age_2021, educ_hi_2021, alfab_2021, educ_scol_2021
* activ7j_2021, hcsp_2021, hhweight_2021, ethnie_2021

* ----- Rename non-suffixed variables to add _2021 -----

* Enterprise indicators
capture rename ent_2021 ent_2021  // already named

* Individual characteristics
rename zae zae_2021
rename milieu milieu_2021

* Enterprise variables
foreach v in proprietor_id nonag_id is_proprietor {
    capture rename `v' `v'_2021
}

* Enterprise performance
foreach v in revenue expenses profit value_total value_machines ///
    value_vehicles value_furniture value_other owns_assets ///
    val_hired_labor max_rev_by_owner {
    capture rename `v' `v'_2021
}

* Enterprise characteristics
foreach v in num_emp num_emp_tot num_emp_child ent_child_emp ///
    num_hhemp hires_nonhh_workers num_hhemp_cat ///
    no_wages_paid place financing year_est ///
    firm_keeps_accounts firm_has_fisc_id ///
    firm_in_trade_register firm_cnps_registered ///
    legal_form cooperative is_highest_revenue sector ///
    share_revenue_resale share_revenue_processed share_revenue_services ///
    N_enterprises_hh multiple_enterprises ///
    labor_affected_covid {
    capture rename `v' `v'_2021
}

* Problem variables
foreach letter in a b c d e f g h i j k l m n o {
    capture rename s10q45`letter' s10q45`letter'_2021
}
* COVID-specific problem variables (2021 only)
foreach v of varlist s10q45*covid* {
    capture rename `v' `v'_2021
}

* Employment variables
foreach v in employed unemployed in_labor_force working_age ///
    sector_work emp_type formal public_employer ///
    days_worked_month hours_worked_day hours_worked_month months_worked ///
    salary_month bonus_month benefits_inkind_month food_value_month ///
    total_comp_month has_secondary_job ///
    days_worked_month_sec hours_worked_day_sec hours_worked_month_sec ///
    salary_month_sec bonus_month_sec benefits_inkind_month_sec ///
    food_value_month_sec total_comp_month_sec total_emp_income_month {
    capture rename `v' `v'_2021
}

* Section 4 raw variables
foreach v of varlist s04q* {
    capture rename `v' `v'_2021
}

* Household head variables
foreach v in hgender hage hmstat hreligion hnation ///
    heduc hdiploma hhandig hactiv7j hactiv12m hbranch hsectins hcsp {
    capture rename `v' `v'_2021
}
* 2021 has different variable names for some HH head vars
capture rename halfa halfa_2021
capture rename halfa2 halfa2_2021
capture rename hethnie hethnie_2021
capture rename halfab halfab_2021

* Location classification
capture rename location location_2021

* Household characteristics
foreach v in hhweight hhsize eqadu1 eqadu2 region month ///
    logem mur toit sol ///
    eauboi_ss eauboi_sp elec_ac elec_ur elec_ua ///
    ordure toilet eva_toi eva_eau ///
    tv fer frigo cuisin ordin decod car superf ///
    grosrum petitrum porc lapin volail ///
    sh_id_demo sh_co_natu sh_co_eco sh_id_eco sh_co_vio sh_co_oth {
    capture rename `v' `v'_2021
}

* Rename household electricity to has_electricity
capture rename elec_ac_2021 has_electricity_2021

* Welfare variables
foreach v in dali dnal dtot pcexp zzae zref def_spa def_temp ///
    def_temp_prix2021m11 def_temp_cpi def_temp_adj ///
    zali0 dtet monthly_cpi cpi2017 icp2017 dollars {
    capture rename `v' `v'_2021
}

* Credit variables
foreach v in ind_credit_12m ind_has_loan ind_loan_source ind_credit_amount ///
    ind_has_outstanding ind_num_outstanding ///
    hh_credit_12m hh_has_loan hh_num_with_loan hh_main_credit_source ///
    hh_total_credit_amount hh_has_outstanding hh_total_outstanding ///
    hh_formal_credit hh_informal_credit ///
    hh_credit_bank hh_credit_mfi hh_credit_coop hh_credit_tontine {
    capture rename `v' `v'_2021
}

* Remittance variables
foreach v in hh_remit_total_annual hh_remit_from_abroad hh_received_remittances {
    capture rename `v' `v'_2021
}

* Bank account variable
capture rename has_bank has_bank_2021

* Credit section raw variables
foreach v of varlist s06q* {
    capture rename `v' `v'_2021
}

* Section 10 raw variables
foreach v of varlist s10q* {
    capture rename `v' `v'_2021
}

* Internet access: has_internet_2021 already created from ehcvm_individu in 03_clean_2021.do
* (individual-level variable "internet", coded 0/1)

* Country and year
capture rename country country_2021
capture drop year
capture drop vague

drop if missing(grappe) | missing(menage) | missing(numind)

* Keep track of which year
gen byte in_2021 = 1
label variable in_2021 "Individual observed in 2021"

* Household head dummy (based on relationship to head variable, lien == 1)
gen byte is_hh_head_2021 = (lien_2021 == 1)
label variable is_hh_head_2021 "Is household head in 2021"

* Enterprise household dummy
bysort hhid: egen byte hh_has_enterprise_2021 = max(ent_2021)
label variable hh_has_enterprise_2021 "Household has at least one enterprise in 2021"

tempfile data_2021
save `data_2021'

di as result "2021 data prepared: `=_N' observations"


********************************************************************************
* PART 3: MERGE 2018 AND 2021 INTO PANEL
********************************************************************************

di as text _n "=============================================="
di as text "STEP 3: Merging into panel"
di as text "=============================================="

* Merge on grappe + menage + numind (individual-level panel)
use `data_2018', clear
merge 1:1 grappe menage numind using `data_2021'

* Document merge results
tab _merge

* ----- Create match indicators -----

* Household-level match: HH appears in both waves
gen byte hh_matched = 0
label variable hh_matched "Household matched across 2018 and 2021"

* An HH is matched if at least one individual from that HH appears in both waves
* We check at the HH level: does this grappe+menage combo have obs in both years?
bysort hhid: egen has_2018 = max(in_2018)
bysort hhid: egen has_2021 = max(in_2021)
replace hh_matched = 1 if has_2018 == 1 & has_2021 == 1
drop has_2018 has_2021

label define hh_matched 0 "Not matched" 1 "Matched across waves"
label values hh_matched hh_matched

* Individual-level match: same person in both waves
gen byte ind_matched = (_merge == 3)
label variable ind_matched "Individual matched across 2018 and 2021"
label define ind_matched 0 "Not matched" 1 "Matched across waves"
label values ind_matched ind_matched

* ----- Validate individual match with gender and age checks -----

* Gender consistency check (same person should have same gender)
gen byte gender_consistent = .
replace gender_consistent = 1 if ind_matched == 1 & sexe_2018 == sexe_2021
replace gender_consistent = 0 if ind_matched == 1 & sexe_2018 != sexe_2021
label variable gender_consistent "Gender matches across waves (quality check)"

* Age consistency check: age in 2021 should be ~3 years more than 2018
gen age_diff = age_2021 - age_2018 if ind_matched == 1
gen byte age_consistent = .
replace age_consistent = 1 if ind_matched == 1 & inrange(age_diff, 1, 5)
replace age_consistent = 0 if ind_matched == 1 & !inrange(age_diff, 1, 5)
label variable age_consistent "Age difference 1-5 years across waves (quality check)"
label variable age_diff "Age difference (2021 - 2018)"

* Validated individual match: matched AND passes gender + age checks
gen byte ind_validated = 0
replace ind_validated = 1 if ind_matched == 1 & gender_consistent == 1 & age_consistent == 1
label variable ind_validated "Individual validated match (ID + gender + age consistent)"
label define ind_validated 0 "Not validated" 1 "Validated match"
label values ind_validated ind_validated

* Fill in missing year indicators
replace in_2018 = 0 if missing(in_2018)
replace in_2021 = 0 if missing(in_2021)

* Clean up merge variable
drop _merge

di as result "Panel merge complete"
tab hh_matched
tab ind_matched
tab ind_validated


********************************************************************************
* PART 4: CREATE ANALYSIS VARIABLES - DEMOGRAPHICS
********************************************************************************

di as text _n "=============================================="
di as text "STEP 4: Creating analysis variables"
di as text "=============================================="

*------------------------------------------------------------------------------
* 4.1: Age categories (for each year)
*------------------------------------------------------------------------------

foreach yr in 2018 2021 {
    recode age_`yr' ///
        (15/29 = 1 "15-29") ///
        (30/44 = 2 "30-44") ///
        (45/64 = 3 "45-64") ///
        (65/max = 4 "65+") ///
        (min/14 = .), ///
        gen(age_cat_`yr')
    label variable age_cat_`yr' "Age category (`yr')"
}

*------------------------------------------------------------------------------
* 4.2: Urban/rural dummy (rural=1)
*------------------------------------------------------------------------------

foreach yr in 2018 2021 {
    gen byte rural_`yr' = .
    * milieu: 1=Urban, 2=Rural (standard EHCVM coding)
    replace rural_`yr' = 0 if milieu_`yr' == 1
    replace rural_`yr' = 1 if milieu_`yr' == 2
    label variable rural_`yr' "Rural area (`yr')"
    label define rural_`yr' 0 "Urban" 1 "Rural"
    label values rural_`yr' rural_`yr'
}

*------------------------------------------------------------------------------
* 4.3: Education categories
*------------------------------------------------------------------------------

* Education levels from educ_hi: map to analysis plan categories
* no education / less than primary / less than secondary / secondary and higher

foreach yr in 2018 2021 {
    * educ_hi codes: 1=Aucun 2=Maternelle 3=Primaire
    * 4=Second.gl1 5=Second.tech1 6=Second.gl2 7=Second.tech2
    * 8=Postsecondaire 9=Superieur

    gen educ_cat_`yr' = .
    replace educ_cat_`yr' = 1 if educ_hi_`yr' == 1              // No education
    replace educ_cat_`yr' = 2 if educ_hi_`yr' == 2              // Less than primary
    replace educ_cat_`yr' = 3 if educ_hi_`yr' == 3              // Less than secondary
    replace educ_cat_`yr' = 4 if inrange(educ_hi_`yr', 4, 9)   // Secondary and higher

    label variable educ_cat_`yr' "Education category (`yr')"
    label define educ_cat_`yr' 1 "No education" 2 "Less than primary" 3 "Less than secondary" 4 "Secondary and higher"
    label values educ_cat_`yr' educ_cat_`yr'
}

*------------------------------------------------------------------------------
* 4.4: Type of activity
*------------------------------------------------------------------------------

foreach yr in 2018 2021 {
    gen activity_type_`yr' = .
    * Only assign activity type for individuals actually observed in this year
    * emp_type codes: 1=Paid work, 2=Unpaid work, 3=Unpaid family worker,
    *                 4=Own account worker, 5=Employer
    replace activity_type_`yr' = 1 if ent_`yr' == 1 & in_`yr' == 1
    replace activity_type_`yr' = 2 if employed_`yr' == 1 & ent_`yr' != 1 & ///
        inlist(emp_type_`yr', 1, 5) & in_`yr' == 1  // paid workers and employers
    replace activity_type_`yr' = 3 if employed_`yr' == 1 & ent_`yr' != 1 & ///
        inlist(emp_type_`yr', 2, 3) & in_`yr' == 1  // unpaid work and unpaid family workers
    replace activity_type_`yr' = 4 if employed_`yr' != 1 & ent_`yr' != 1 & in_`yr' == 1

    label variable activity_type_`yr' "Type of activity (`yr')"
    label define activity_type_`yr' ///
        1 "Entrepreneur" ///
        2 "Wage job" ///
        3 "Non-wage job" ///
        4 "Not working"
    label values activity_type_`yr' activity_type_`yr'
}

*------------------------------------------------------------------------------
* 4.5: Wage job sub-categories
*------------------------------------------------------------------------------

* Note: formal_YYYY and public_employer_YYYY are now created in the cleaning
* do-files using the proper source variables:
*   - formal: from s04q38 (contributes to IPRES/FNR/Retraite Complémentaire)
*   - public_employer: from s04q53 (principal employer)
* These are renamed with year suffixes in Parts 1 and 2 above.


********************************************************************************
* PART 5: CREATE ANALYSIS VARIABLES - LEVEL OF ANALYSIS INDICATORS
********************************************************************************

* NOTE ON LEVEL OF ANALYSIS
* -------------------------
* The panel dataset contains ALL individuals from the 2018 household roster,
* including non-entrepreneurs. The variables below allow the user to change
* the level of analysis depending on the research question:
*
*   (a) is_entrepreneur: Individual-level dummy. Identifies anyone who was an
*       entrepreneur in at least one wave. Entrepreneurs are matched at the
*       individual level using nonag_id (grappe + menage + numind), which is
*       the same approach as in set_up_data.do. Use this to restrict the
*       sample to entrepreneurs only:
*           keep if is_entrepreneur == 1
*
*   (b) ent_status: 4-category variable classifying each individual's
*       entrepreneur status across waves. Useful for comparing outcomes
*       across groups (e.g., stayers vs. exiters vs. entrants):
*           tab ent_status
*           keep if ent_status != 1   // drop non-entrepreneurs
*
*   (c) hh_has_enterprise: Household-level dummy. Equals 1 if ANY member of
*       the household was an entrepreneur in either wave. Use this to keep
*       all members of entrepreneurial households (not just the entrepreneur):
*           keep if hh_has_enterprise == 1

*------------------------------------------------------------------------------
* 5.1: Individual-level entrepreneur dummy
*------------------------------------------------------------------------------

* Identifies entrepreneurs at the individual level, matching the approach in
* set_up_data.do: an individual is an entrepreneur if they appear in the
* enterprise data (Section 10) for that wave, matched via nonag_id.
gen byte is_entrepreneur = (ent_2018 == 1 | ent_2021 == 1)
label variable is_entrepreneur "Is entrepreneur in at least one wave"
label define is_entrepreneur 0 "Not an entrepreneur" 1 "Entrepreneur"
label values is_entrepreneur is_entrepreneur

tab is_entrepreneur, mi

*------------------------------------------------------------------------------
* 5.2: Entrepreneur status across waves (4 categories)
*------------------------------------------------------------------------------

* Individual-level classification based on entrepreneur status in each wave.
* Matching is at the individual level (nonag_id = grappe + menage + numind),
* as in set_up_data.do.
gen byte ent_status = 1
replace ent_status = 2 if ent_2018 == 1 & ent_2021 != 1
replace ent_status = 3 if ent_2018 != 1 & ent_2021 == 1
replace ent_status = 4 if ent_2018 == 1 & ent_2021 == 1

label variable ent_status "Entrepreneur status across waves"
label define ent_status ///
    1 "Not entrepreneur in either wave" ///
    2 "Entrepreneur in 2018 only" ///
    3 "Entrepreneur in 2021 only" ///
    4 "Entrepreneur in both waves"
label values ent_status ent_status

tab ent_status, mi

*------------------------------------------------------------------------------
* 5.3: Household has enterprise dummy
*------------------------------------------------------------------------------

* Household-level flag: equals 1 if any member of the household was an
* entrepreneur in either wave. Useful for keeping all individuals in
* entrepreneurial households (e.g., to study household-level outcomes).
bysort hhid: egen byte hh_has_enterprise = max(is_entrepreneur)
label variable hh_has_enterprise "Household has an entrepreneur in at least one wave"
label define hh_has_enterprise 0 "No enterprise in HH" 1 "HH has enterprise"
label values hh_has_enterprise hh_has_enterprise

tab hh_has_enterprise, mi


********************************************************************************
* PART 5b: TRANSITION INDICATORS
********************************************************************************

*------------------------------------------------------------------------------
* 5b.1: Entrepreneurship transition (4 categories, panel individuals only)
*------------------------------------------------------------------------------

* Only for individuals observed in both waves
gen ent_transition = . if ind_matched == 1
replace ent_transition = 1 if ent_2018 ==0 & ent_2021 ==0 & ind_matched == 1
replace ent_transition = 2 if ent_2018 ==0 & ent_2021 == 1 & ind_matched == 1
replace ent_transition = 3 if ent_2018 == 1 & ent_2021 ==0 & ind_matched == 1
replace ent_transition = 4 if ent_2018 == 1 & ent_2021 == 1 & ind_matched == 1

label variable ent_transition "Entrepreneurship transition 2018-2021"
label define ent_transition ///
    1 "Not entrepreneur in either year" ///
    2 "Entered entrepreneurship in 2021" ///
    3 "Exited entrepreneurship in 2021" ///
    4 "Remained entrepreneur"
label values ent_transition ent_transition

*------------------------------------------------------------------------------
* 5b.2: Entry source for 2021 entrepreneurs (4 categories)
*------------------------------------------------------------------------------

gen ent_entry_source = . if ent_2021 == 1 & ind_matched == 1
replace ent_entry_source = 1 if ent_2018 == 1 & ent_2021 == 1 & ind_matched == 1
replace ent_entry_source = 2 if ent_2018 != 1 & ent_2021 == 1 & ///
    activity_type_2018 == 2 & ind_matched == 1
replace ent_entry_source = 3 if ent_2018 != 1 & ent_2021 == 1 & ///
    activity_type_2018 == 3 & ind_matched == 1
replace ent_entry_source = 4 if ent_2018 != 1 & ent_2021 == 1 & ///
    activity_type_2018 == 4 & ind_matched == 1

label variable ent_entry_source "Source of entry into entrepreneurship in 2021"
label define ent_entry_source ///
    1 "Was entrepreneur in 2018" ///
    2 "Entered from wage job" ///
    3 "Entered from non-wage job" ///
    4 "Entered from non-work"
label values ent_entry_source ent_entry_source

*------------------------------------------------------------------------------
* 5b.3: Exit dummy
*------------------------------------------------------------------------------

gen byte ent_exited = .
replace ent_exited = 1 if ent_2018 == 1 & ent_2021 != 1 & ind_matched == 1
replace ent_exited = 0 if ent_2018 == 1 & ent_2021 == 1 & ind_matched == 1
label variable ent_exited "Exited entrepreneurship between 2018 and 2021"
label define ent_exited 0 "Remained entrepreneur" 1 "Exited"
label values ent_exited ent_exited


********************************************************************************
* PART 6: CREATE ANALYSIS VARIABLES - HOUSEHOLD HEAD INDICATORS
********************************************************************************

*------------------------------------------------------------------------------
* 6.1: Household head characteristics (from welfare data)
*------------------------------------------------------------------------------

* These are already in the data as hgender_YYYY, hage_YYYY, heduc_YYYY
* Create additional analysis variables

foreach yr in 2018 2021 {
    * HH head age categories
    capture drop hage_cat_`yr'
    gen hage_cat_`yr' = .
    replace hage_cat_`yr' = 1 if hage_`yr' >= 15 & hage_`yr' <= 29
    replace hage_cat_`yr' = 2 if hage_`yr' >= 30 & hage_`yr' <= 44
    replace hage_cat_`yr' = 3 if hage_`yr' >= 45 & hage_`yr' <= 64
    replace hage_cat_`yr' = 4 if hage_`yr' >= 65 & hage_`yr' < .
    label variable hage_cat_`yr' "HH head age category (`yr')"
    label define hage_cat_`yr' 1 "15-29" 2 "30-44" 3 "45-64" 4 "65+"
    label values hage_cat_`yr' hage_cat_`yr'

    * HH head education category (same codes as educ_hi)
    gen heduc_cat_`yr' = .
    replace heduc_cat_`yr' = 1 if heduc_`yr' == 1              // No education
    replace heduc_cat_`yr' = 2 if heduc_`yr' == 2              // Less than primary
    replace heduc_cat_`yr' = 3 if heduc_`yr' == 3              // Less than secondary
    replace heduc_cat_`yr' = 4 if inrange(heduc_`yr', 4, 9)   // Secondary and higher

    label variable heduc_cat_`yr' "HH head education category (`yr')"
    label define heduc_cat_`yr' 1 "No education" 2 "Less than primary" 3 "Less than secondary" 4 "Secondary and higher"
    label values heduc_cat_`yr' heduc_cat_`yr'
}

*------------------------------------------------------------------------------
* 6.2: HH head is NOT the entrepreneur - employment characteristics
*------------------------------------------------------------------------------

foreach yr in 2018 2021 {
    gen byte head_not_ent_`yr' = (is_hh_head_`yr' == 1 & ent_`yr' != 1)
    label variable head_not_ent_`yr' "HH head is not the entrepreneur (`yr')"
}

*------------------------------------------------------------------------------
* 6.3: Share of HH members in wage jobs
*------------------------------------------------------------------------------

foreach yr in 2018 2021 {
    gen byte has_wage_job_`yr' = (activity_type_`yr' == 2)
    bysort hhid: egen n_wage_`yr' = total(has_wage_job_`yr')
    bysort hhid: egen n_employed_`yr' = total(employed_`yr' == 1)
    gen share_wage_hh_`yr' = n_wage_`yr' / n_employed_`yr' if n_employed_`yr' > 0
    label variable share_wage_hh_`yr' "Share of employed HH members with wage job (`yr')"
    drop has_wage_job_`yr' n_wage_`yr' n_employed_`yr'
}


********************************************************************************
* PART 7: CREATE ANALYSIS VARIABLES - ENTERPRISE PERFORMANCE
********************************************************************************

*------------------------------------------------------------------------------
* 7.1: GDP deflator-adjusted profits and capital (real 2018 prices)
*------------------------------------------------------------------------------

foreach yr in 2018 2021 {
    * Deflate to 2018 prices: Real = Nominal × (Deflator_2018 / Deflator_year)
    gen profit_real_`yr' = profit_`yr' * (${gdpdef_2018} / ${gdpdef_`yr'}) if ent_`yr' == 1
    label variable profit_real_`yr' "Monthly profit in real 2018 prices (`yr')"

    gen value_total_real_`yr' = value_total_`yr' * (${gdpdef_2018} / ${gdpdef_`yr'}) if ent_`yr' == 1
    label variable value_total_real_`yr' "Capital value in real 2018 prices (`yr')"
}

*------------------------------------------------------------------------------
* 7.2: Log transformations
*------------------------------------------------------------------------------

foreach yr in 2018 2021 {
    * Log of profit (handle zeros and negatives with IHS or conditional log)
    gen log_profit_`yr' = ln(profit_`yr') if profit_`yr' > 0 & ent_`yr' == 1
    label variable log_profit_`yr' "Log of monthly profit (`yr')"

    * Log of capital value
    gen log_capital_`yr' = ln(value_total_`yr') if value_total_`yr' > 0 & ent_`yr' == 1
    label variable log_capital_`yr' "Log of capital value (`yr')"
}

*------------------------------------------------------------------------------
* 7.3: Changes between years (panel enterprises only)
*------------------------------------------------------------------------------

* Change in profits (real terms)
gen change_profit_real = profit_real_2021 - profit_real_2018 ///
    if ent_2018 == 1 & ent_2021 == 1 & ind_matched == 1
label variable change_profit_real "Change in real profit (2021 - 2018)"

* Change in capital (real terms)
gen change_capital_real = value_total_real_2021 - value_total_real_2018 ///
    if ent_2018 == 1 & ent_2021 == 1 & ind_matched == 1
label variable change_capital_real "Change in real capital value (2021 - 2018)"

* Change in number of non-family employees
gen change_num_emp = num_emp_2021 - num_emp_2018 ///
    if ent_2018 == 1 & ent_2021 == 1 & ind_matched == 1
label variable change_num_emp "Change in non-family employees (2021 - 2018)"

* Change in number of family employees
gen change_num_hhemp = num_hhemp_2021 - num_hhemp_2018 ///
    if ent_2018 == 1 & ent_2021 == 1 & ind_matched == 1
label variable change_num_hhemp "Change in family employees (2021 - 2018)"

* Annual growth rate of profits
gen growth_profit = .
replace growth_profit = ((profit_real_2021 / profit_real_2018) - 1) ///
    if profit_real_2018 > 0 & profit_real_2021 > 0 & ///
    ent_2018 == 1 & ent_2021 == 1 & ind_matched == 1
label variable growth_profit "Annual growth rate of real profits"

* Profit increased dummy
gen byte profit_increased = (change_profit_real > 0) ///
    if ent_2018 == 1 & ent_2021 == 1 & ind_matched == 1 & !missing(change_profit_real)
label variable profit_increased "Enterprise increased real profits 2018-2021"

* Capital increased dummy
gen byte capital_increased = (change_capital_real > 0) ///
    if ent_2018 == 1 & ent_2021 == 1 & ind_matched == 1 & !missing(change_capital_real)
label variable capital_increased "Enterprise increased real capital 2018-2021"

*------------------------------------------------------------------------------
* 7.4: Profit categories
*------------------------------------------------------------------------------

foreach yr in 2018 2021 {
    gen profit_cat_`yr' = .
    replace profit_cat_`yr' = 1 if profit_`yr' < 0 & ent_`yr' == 1
    replace profit_cat_`yr' = 2 if profit_`yr' == 0 & ent_`yr' == 1
    replace profit_cat_`yr' = 3 if profit_`yr' > 0 & profit_`yr' < . & ent_`yr' == 1
    label variable profit_cat_`yr' "Profit category (`yr')"
    label define profit_cat_`yr' 1 "Negative/loss" 2 "Zero" 3 "Positive"
    label values profit_cat_`yr' profit_cat_`yr'
}

*------------------------------------------------------------------------------
* 7.5: Formality indicators
*------------------------------------------------------------------------------

* Note: Three formality definitions already exist from cleaning files:
*   - firm_keeps_accounts_YYYY: keeps written accounts
*   - firm_has_fisc_id_YYYY: has NIF/NINEA
*   - firm_in_trade_register_YYYY: has trade registration
* Additionally, formal_YYYY (pension contribution) is available for wage workers.

*------------------------------------------------------------------------------
* 7.6: Firm age categories
*------------------------------------------------------------------------------

foreach yr in 2018 2021 {
    local survey_year = `yr'
    gen firm_age_`yr' = `survey_year' - year_est_`yr' if ent_`yr' == 1
    label variable firm_age_`yr' "Firm age in years (`yr')"

    recode year_est_`yr' ///
        (min/1999 = 1 "Before 2000") ///
        (2000/2009 = 2 "2000-2009") ///
        (2010/2014 = 3 "2010-2014") ///
        (2015/2021 = 4 "2015+"), ///
        gen(year_est_cat_`yr')
    label variable year_est_cat_`yr' "Year established category (`yr')"
}

*------------------------------------------------------------------------------
* 7.7: Value added per worker
*------------------------------------------------------------------------------

foreach yr in 2018 2021 {
    * Value added = revenue - intermediate costs (excl. labor)
    * Intermediate costs = costs of goods for resale + raw materials + operating costs
    * Total employees includes family + non-family + proprietor
    gen total_workers_`yr' = 1 + num_hhemp_`yr' + num_emp_`yr' if ent_`yr' == 1
    replace total_workers_`yr' = 1 if total_workers_`yr' == 0 & ent_`yr' == 1

    * Value added = revenue - expenses + wages (since wages are included in expenses)
    gen value_added_`yr' = revenue_`yr' - expenses_`yr' + val_hired_labor_`yr' if ent_`yr' == 1
    replace value_added_`yr' = revenue_`yr' - expenses_`yr' if missing(val_hired_labor_`yr') & ent_`yr' == 1
    label variable value_added_`yr' "Value added (`yr')"

    gen va_per_worker_`yr' = value_added_`yr' / total_workers_`yr' if ent_`yr' == 1
    label variable va_per_worker_`yr' "Value added per worker (`yr')"
}

* NOTE: Value added per worker construction
*   value_added = revenue - expenses + val_hired_labor
*     (wages are added back because they are included in expenses but are part
*      of value added; if val_hired_labor is missing, value_added = revenue - expenses)
*   total_workers = 1 (proprietor) + num_hhemp (family workers) + num_emp (non-family workers)
*     (floored at 1 so every active enterprise has at least the proprietor)
*   va_per_worker = value_added / total_workers

*------------------------------------------------------------------------------
* 7.8: Total employees (family + non-family)
*------------------------------------------------------------------------------

foreach yr in 2018 2021 {
    gen total_emp_`yr' = num_hhemp_`yr' + num_emp_`yr' if ent_`yr' == 1
    replace total_emp_`yr' = num_hhemp_`yr' if missing(num_emp_`yr') & ent_`yr' == 1
    label variable total_emp_`yr' "Total employees, family + non-family (`yr')"
}

*------------------------------------------------------------------------------
* 7.9: Internet access (from ehcvm_individu, variable "internet", 0/1)
*------------------------------------------------------------------------------

* has_internet_2018 and has_internet_2021 created in cleaning files
* from the individual-level "internet" variable in ehcvm_individu datasets


********************************************************************************
* PART 8: CREATE ANALYSIS VARIABLES - HOUSEHOLD LEVEL
********************************************************************************

*------------------------------------------------------------------------------
* 8.1: Consumption and welfare quintiles
*------------------------------------------------------------------------------

foreach yr in 2018 2021 {
    * Total consumption is dtot
    * Per capita consumption is pcexp

    * Welfare quintiles based on per capita consumption
    * Create within each year
    xtile welfare_quintile_`yr' = pcexp_`yr', nq(5)
    label variable welfare_quintile_`yr' "Welfare quintile based on consumption (`yr')"
    label define welfare_quintile_`yr' 1 "Q1 (poorest)" 2 "Q2" 3 "Q3" 4 "Q4" 5 "Q5 (richest)"
    label values welfare_quintile_`yr' welfare_quintile_`yr'
}

*------------------------------------------------------------------------------
* 8.2: Per capita consumption (adult equivalent) and log transforms
*------------------------------------------------------------------------------

* Using eqadu2 (adult equivalent scale 2) for per capita measures
foreach yr in 2018 2021 {
    gen pc_total_cons_`yr' = dtot_`yr' / eqadu2_`yr' if eqadu2_`yr' > 0
    gen pc_food_cons_`yr'  = dali_`yr' / eqadu2_`yr' if eqadu2_`yr' > 0
    gen pc_nfood_cons_`yr' = dnal_`yr' / eqadu2_`yr' if eqadu2_`yr' > 0

    label variable pc_total_cons_`yr' "Per capita total consumption, adult eq. (`yr')"
    label variable pc_food_cons_`yr'  "Per capita food consumption, adult eq. (`yr')"
    label variable pc_nfood_cons_`yr' "Per capita non-food consumption, adult eq. (`yr')"

    * Log consumption (main dependent variables for consumption smoothing)
    gen ln_pc_total_`yr' = ln(pc_total_cons_`yr')
    gen ln_pc_food_`yr'  = ln(pc_food_cons_`yr')
    gen ln_pc_nfood_`yr' = ln(pc_nfood_cons_`yr') if pc_nfood_cons_`yr' > 0

    label variable ln_pc_total_`yr' "Log per capita total consumption (`yr')"
    label variable ln_pc_food_`yr'  "Log per capita food consumption (`yr')"
    label variable ln_pc_nfood_`yr' "Log per capita non-food consumption (`yr')"

    * Real consumption (spatially deflated)
    gen real_pc_total_`yr' = pc_total_cons_`yr' / def_spa_`yr' if def_spa_`yr' > 0
    gen ln_real_pc_total_`yr' = ln(real_pc_total_`yr')

    label variable real_pc_total_`yr'    "Real per capita total consumption (`yr')"
    label variable ln_real_pc_total_`yr' "Log real per capita total consumption (`yr')"
}

*------------------------------------------------------------------------------
* 8.3: Poverty indicator
*------------------------------------------------------------------------------

foreach yr in 2018 2021 {
    gen poor_`yr' = (pcexp_`yr' < zref_`yr') if pcexp_`yr' != . & zref_`yr' != .
    label variable poor_`yr' "Below poverty line (`yr')"
    label define poor_`yr' 0 "Non-poor" 1 "Poor"
    label values poor_`yr' poor_`yr'
}

*------------------------------------------------------------------------------
* 8.4: Composite negative shock dummy
*------------------------------------------------------------------------------

foreach yr in 2018 2021 {
    gen neg_shock_`yr' = 0
    replace neg_shock_`yr' = 1 if sh_id_demo_`yr' == 1 | sh_co_natu_`yr' == 1 | ///
        sh_co_eco_`yr' == 1 | sh_id_eco_`yr' == 1 | ///
        sh_co_vio_`yr' == 1 | sh_co_oth_`yr' == 1
    label variable neg_shock_`yr' "Any negative shock (`yr')"
}


********************************************************************************
* PART 9: VARIABLE FOR YEAR IDENTIFIER (LONG-FORMAT COMPATIBLE)
********************************************************************************

* The dataset is in wide format. Add a year variable for reference.
* For analysis requiring long format, reshape can be done downstream.

replace year = 2021 if in_2018 == 0 & in_2021 == 1
replace year = . if in_2018 == 1 & in_2021 == 1  // panel individuals
label variable year "Survey year (missing if observed in both waves)"


********************************************************************************
* PART 10: ORDER AND LABEL FINAL DATASET
********************************************************************************

* Order key identification variables first
order grappe menage numind hhid ///
      in_2018 in_2021 hh_matched ind_matched ind_validated ///
      gender_consistent age_consistent age_diff ///
      year ///
      ent_2018 ent_2021 ///
      ent_transition ent_entry_source ent_exited ///
      sexe_2018 sexe_2021 age_2018 age_2021 ///
      age_cat_2018 age_cat_2021 ///
      milieu_2018 milieu_2021 rural_2018 rural_2021 ///
      educ_cat_2018 educ_cat_2021 ///
      activity_type_2018 activity_type_2021

label data "EHCVM Senegal Panel 2018-2021"

* Compress to reduce file size
compress


********************************************************************************
* PART 11: SAVE
********************************************************************************

save "${final}/SEN_panel_2018_2021.dta", replace

di as result "Panel dataset saved: ${final}/SEN_panel_2018_2021.dta"
di as result "Observations: `=_N'"

* Summary statistics
di as text _n "=============================================="
di as text "PANEL SUMMARY"
di as text "=============================================="
di as text "Total observations: `=_N'"
count if in_2018 == 1
di as text "In 2018: `r(N)'"
count if in_2021 == 1
di as text "In 2021: `r(N)'"
count if hh_matched == 1
di as text "In matched households: `r(N)'"
count if ind_matched == 1
di as text "Individuals matched: `r(N)'"
count if ind_validated == 1
di as text "Individuals validated (gender+age): `r(N)'"

tab ent_transition if ind_matched == 1
tab ent_entry_source if ind_matched == 1



********************************************************************************
* DONE
********************************************************************************

di as text _n "=============================================="
di as result "PANEL CREATION COMPLETE"
di as text "=============================================="
di as text ""
di as text "Output files:"
di as text "  1. ${final}/SEN_panel_2018_2021.dta"
di as text ""
di as text "Key variables created:"
di as text "  - hh_matched: HH appears in both waves"
di as text "  - ind_matched: Individual appears in both waves"
di as text "  - ind_validated: Individual match confirmed by gender + age"
di as text "  - ent_transition: Entrepreneurship transition (4 categories)"
di as text "  - ent_entry_source: Source of entry for 2021 entrepreneurs"
di as text "  - ent_exited: Dummy for 2018 entrepreneurs who exited"
di as text "  - age_cat_YYYY: Age categories (15-29, 30-44, 45-64, 65+)"
di as text "  - educ_cat_YYYY: Education (no educ, < primary, < secondary, secondary+)"
di as text "  - rural_YYYY: Rural dummy"
di as text "  - activity_type_YYYY: Entrepreneur/wage/non-wage/not working"
di as text "  - formal_YYYY: Formal employment (pension contribution)"
di as text "  - public_employer_YYYY: Public sector employer (from s04q53)"
di as text "  - profit_real_YYYY: GDP deflator-adjusted profit (2018 prices)"
di as text "  - log_profit_YYYY, log_capital_YYYY: Log transformations"
di as text "  - change_profit_real, change_capital_real: Real changes"
di as text "  - change_num_emp, change_num_hhemp: Employee changes"
di as text "  - growth_profit: Profit growth rate"
di as text "  - firm_keeps_accounts_YYYY, firm_has_fisc_id_YYYY, firm_in_trade_register_YYYY: Firm formality"
di as text "  - va_per_worker_YYYY: Value added per worker"
di as text "  - welfare_quintile_YYYY: Consumption quintiles"
di as text "  - share_wage_hh_YYYY: Share of HH in wage jobs"
di as text "=============================================="

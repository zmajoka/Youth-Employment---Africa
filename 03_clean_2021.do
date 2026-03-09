********************************************************************************
* EHCVM SENEGAL - 2021 DATA CLEANING
********************************************************************************
* Purpose: Clean and prepare 2021 wave enterprise data for analysis
* Author: Zaineb Majoka (mzaineb@worldbank.org). Based on David/Joseph's do-files 
* Date: March 2026
* 
* INPUT:  Raw 2021 data files
* OUTPUT: Cleaned 2021 dataset

********************************************************************************

********************************************************************************
* PART 0: SET PATHS
********************************************************************************

* Main project directory
global project "C:\Users\WB461621\OneDrive - WBG\SPJ\West Africa\Regional HH Enterprise Work"

* Data directories
global data_2021     "${project}/Data/SEN/2021"
global intermediate  "${project}/Data/SEN/Intermediate"
global output        "${project}/Output/SEN"
global final         "${project}/Data/SEN/Final"

* Create directories if needed
capture mkdir "${intermediate}"
capture mkdir "${output}"


********************************************************************************
* PART 1: CLEAN ENTERPRISE DATA (SECTION 10)
********************************************************************************

use "${data_2021}/s10b_me_sen2021", clear

*------------------------------------------------------------------------------
* 1.1: Drop inactive enterprises and invalid owners
*------------------------------------------------------------------------------

drop if s10q58==2
drop if s10q15__0<0 | s10q15__0==.


*------------------------------------------------------------------------------
* 1.2: Create enterprise/individual identifier
*------------------------------------------------------------------------------

* Proprietor ID - who owns/runs this enterprise


gen proprietor_id = s10q15__0
label variable proprietor_id "Proprietor/owner ID (from Section 10)"

* Enterprise ID: cluster_household_proprietor
* This uses the proprietor ID, not individual ID
gen nonag_id = strofreal(grappe,"%3.0f") + "_" + ///
               strofreal(menage,"%02.0f") + "_" + ///
               strofreal(proprietor_id,"%02.0f")

label variable nonag_id "Enterprise ID (cluster_household_proprietor)"

sort nonag_id

*Create a numind to be used when merging datasets 

gen numind = s10q15__0

*------------------------------------------------------------------------------
* 1.3: Calculate number of employees
*------------------------------------------------------------------------------

* Hired employees (non-household workers)
* Only including adults when counting number of employees

* Adult employees 

gen num_emp = max(s10q62a_1, 0) + max(s10q62a_2, 0)
label variable num_emp "Number of hired employees"

* Total employees
gen num_emp_tot = max(s10q62a_1,0) + max(s10q62a_2,0) + ///
              max(s10q62a_3,0) + max(s10q62a_4,0)

* Children only (if we want it for child labor analysis)
gen num_emp_child = max(s10q62a_3,0) + max(s10q62a_4,0)

* enterprises with children employees 
gen ent_child_emp = 1 if num_emp_child>=1 & num_emp_child!=.
replace ent_child_emp = 0 if num_emp_child==0

* Household employees (family workers) - up to 8 in 2021 (CHANGED FROM 14)
* each variable refers to individual id within the household

gen num_hhemp = 0
label variable num_hhemp "Number of household employees"

forvalues person = 1/8 {
    capture confirm variable s10q61a_`person'
    if !_rc {
        replace num_hhemp = num_hhemp + 1 if s10q61a_`person' < .
    }
}

*dummy for enterprises that hire non-household employees 

gen hires_nonhh_workers = (num_emp_tot > 0) if !missing(num_emp_tot)
label variable hires_nonhh_workers "Enterprise hires non-household workers"
label define hires_nonhh_workers 0 "No hired workers" 1 "Hires non-HH workers"
label values hires_nonhh_workers hires_nonhh_workers

*categorical variable for number of household member employees 

recode num_hhemp (0=0 "0") (1=1 "1") (2/max=2 "2+"), gen(num_hhemp_cat)
label variable num_hhemp_cat "Number of household employees (categorical)"

*------------------------------------------------------------------------------
* 1.4: Calculate wages paid to hired workers
*------------------------------------------------------------------------------

* Rename wage variables
rename s10q62d_1 out_hh_worker_men_salary
rename s10q62d_2 out_hh_worker_women_salary
rename s10q62d_3 out_hh_worker_boys_salary
rename s10q62d_4 out_hh_worker_girls_salary

* Sum total wages
egen var1 = total(out_hh_worker_men_salary), by(nonag_id)
egen var2 = total(out_hh_worker_women_salary), by(nonag_id)
egen var3 = total(out_hh_worker_boys_salary), by(nonag_id)
egen var4 = total(out_hh_worker_girls_salary), by(nonag_id)

egen val_hired_labor = rowtotal(var1 var2 var3 var4)
label variable val_hired_labor "Total wages paid"

drop var1 var2 var3 var4

*Dummy for enterprises that hire non-hh members but pay no salary 
gen no_wages_paid = (val_hired_labor == 0 | missing(val_hired_labor)) if num_emp > 0
label variable no_wages_paid "Enterprise has hired workers but pays no wages"
label define no_wages_paid 0 "Pays wages" 1 "No wages paid"
label values no_wages_paid no_wages_paid

*------------------------------------------------------------------------------
* 1.5: Calculate capital value
*------------------------------------------------------------------------------

gen value_machines = 0
replace value_machines = s10q36 if s10q35==1
label variable value_machines "Value of machines"

gen value_vehicles = 0
replace value_vehicles = s10q38 if s10q37==1
label variable value_vehicles "Value of vehicles"

gen value_furniture = 0
replace value_furniture = s10q40 if s10q39==1
label variable value_furniture "Value of furniture"

gen value_other = 0
replace value_other = s10q42 if s10q41==1
label variable value_other "Value of other equipment"

egen value_total = rowtotal(value_machines value_vehicles value_furniture value_other)
label variable value_total "Total capital value"

gen owns_assets = (value_total>0 & value_total<.)
label variable owns_assets "Owns any assets"

*------------------------------------------------------------------------------
* 1.6: Calculate revenue
*------------------------------------------------------------------------------

egen revenue = rowtotal(s10q46 s10q48 s10q50)
label variable revenue "Total monthly revenue (FCFA)"

*------------------------------------------------------------------------------
* 1.7: Calculate expenses
*------------------------------------------------------------------------------

* Convert annual taxes to monthly
replace s10q55 = s10q55/12  // Business license
replace s10q56 = s10q56/12  // Other taxes
replace s10q57 = s10q57/12  // Admin fees

* Total expenses
egen expenses = rowtotal(s10q47 s10q49 s10q51 s10q52-s10q57 val_hired_labor)
label variable expenses "Total monthly expenses (FCFA)"

*------------------------------------------------------------------------------
* 1.8: Calculate profit
*------------------------------------------------------------------------------

gen profit = revenue - expenses
label variable profit "Monthly profit (FCFA)"

*------------------------------------------------------------------------------
* 1.9: Enterprise characteristics
*------------------------------------------------------------------------------

* Place of business
gen place = s10q23
label variable place "Place of business"

label define place ///
    1 "Office, workshop, store, shop, garage" ///
    2 "Fixed post on public road" ///
    3 "Mobile post on public road" ///
    4 "At home" ///
    5 "Client's home" ///
    6 "Car, motorcycle" ///
    7 "Mobile/itinerant" ///
    8 "Other (specify)" ///
	9 "Market"
    
label values place place

* Financing source
gen financing = s10q34
label variable financing "Source of initial financing"

label define financing ///
    1 "Own funds" ///
    2 "Help from relative in country" ///
    3 "Help from relative abroad" ///
    4 "Loan from another household" ///
    5 "Loan from tontine" ///
    6 "Bank loan or microfinance" ///
    7 "Loan/support from cooperative" ///
    8 "Loan/support from NGO" ///
    9 "Other (specify)"
    
label values financing financing

* Year established
gen year_est = s10q20
label variable year_est "Year established"

* Electricity
gen has_electricity = (s10q26 == 1)
label variable has_electricity "Has electricity"

* Formality indicators
* option 1 and 2: yes, transmitted to tax authority and Yes, not transmitted to tax authority 
gen firm_keeps_accounts = inlist(s10q29, 1, 2)
label variable firm_keeps_accounts "Keeps written accounts"

gen firm_has_fisc_id = (s10q30 == 1)
label variable firm_has_fisc_id "Has fiscal ID (NIF)"

gen firm_in_trade_register = (s10q31 == 1)
label variable firm_in_trade_register "In trade register"

* CNPS registration
gen firm_cnps_registered = (s10q32 == 1)
label variable firm_cnps_registered "Registered with CNPS"

* Legal form and cooperative
gen legal_form = s10q33
label variable legal_form "Legal form"
label define legal_form 1 "Individual" 2 "Cooperative/GIE" 3 "Other"
label values legal_form legal_form

gen cooperative = (legal_form == 2)
label variable cooperative "Is a cooperative"

*------------------------------------------------------------------------------
* 1.9b: COVID-19 impact (NEW IN 2021)
*------------------------------------------------------------------------------

* Labor management affected by COVID-19
gen labor_affected_covid = (s10q62_a == 1) if !missing(s10q62_a)
label variable labor_affected_covid "Labor management affected by COVID-19"
label define labor_affected_covid 0 "Not affected" 1 "Affected"
label values labor_affected_covid labor_affected_covid

*------------------------------------------------------------------------------
* 1.10: Flag highest-revenue enterprise per owner
*------------------------------------------------------------------------------

* Calculate maximum revenue for each owner
egen max_rev_by_owner = max(revenue), by(nonag_id)

* Create dummy for highest-revenue enterprise
gen is_highest_revenue = (revenue == max_rev_by_owner) if !missing(revenue)
label variable is_highest_revenue "Is highest-revenue enterprise for this owner"
label define is_highest_revenue 0 "Not highest revenue" 1 "Highest revenue"
label values is_highest_revenue is_highest_revenue

* Note: If owner has only 1 enterprise, is_highest_revenue = 1
* If owner has multiple enterprises with same revenue, multiple will = 1

*------------------------------------------------------------------------------
* 1.11: Keep highest-revenue enterprise per owner
*------------------------------------------------------------------------------

gsort nonag_id -revenue -value_total
bysort nonag_id: keep if _n==1

*------------------------------------------------------------------------------
* 1.12: Recode sector
*------------------------------------------------------------------------------

recode s10q17a ///
    (1/2   = 1 "Ag and extractives") ///
    (3     = 2 "Manufacturing") ///
    (4/5   = 3 "Utilities and construction") ///
    (6/7   = 5 "Retail") ///
    (8     = 6 "Transport") ///
    (17    = 7 "Personal services") ///
    (9/16 18 19 = 9 "Other"), ///
    gen(sector)

label variable sector "Sector"

*------------------------------------------------------------------------------
* 1.13: Revenue shares
*------------------------------------------------------------------------------

gen share_revenue_resale = s10q46/revenue
gen share_revenue_processed = s10q48/revenue
gen share_revenue_services = s10q50/revenue

*------------------------------------------------------------------------------
* 1.14: Problem variables (keep for regressions)
*------------------------------------------------------------------------------

* Label problem variables
label variable s10q45a "Problem: Supply of raw materials"
label variable s10q45b "Problem: Lack of customers"
label variable s10q45c "Problem: Too much competition"
label variable s10q45d "Problem: Accessing credit"
label variable s10q45e "Problem: Recruiting personnel"
label variable s10q45f "Problem: Insufficient space"
label variable s10q45g "Problem: Accessing equipment"
label variable s10q45h "Problem: Technical manufacturing"
label variable s10q45i "Problem: Technical management"
label variable s10q45j "Problem: Electricity access"
label variable s10q45k "Problem: Power outages"
label variable s10q45l "Problem: Other infrastructure"
label variable s10q45m "Problem: Internet"
label variable s10q45n "Problem: Insecurity"
label variable s10q45o "Problem: Regulation and taxes"

label define s10q45 1 "Yes" 2 "No" 3 "N/A"
label values s10q45? s10q45 

*------------------------------------------------------------------------------
* 1.15: Number of enterprises per household 
*------------------------------------------------------------------------------

* Create household ID
gen hhid = grappe * 1000 + menage
label variable hhid "Household ID (numeric, matches individual dataset)"

bysort hhid: egen N_enterprises_hh = count(proprietor_id)
label variable N_enterprises_hh "Number of enterprises in household"

* Dummy for households with multiple enterprises
gen multiple_enterprises = (N_enterprises_hh > 1) if !missing(N_enterprises_hh)
label variable multiple_enterprises "Household operates more than 1 enterprise"
label define multiple_enterprises 0 "Single enterprise" 1 "Multiple enterprises"
label values multiple_enterprises multiple_enterprises

*------------------------------------------------------------------------------
* 1.16: Save enterprise data
*------------------------------------------------------------------------------

tempfile enterprise_2021
save `enterprise_2021', replace

********************************************************************************
* PART 2: LOAD AND PREPARE INDIVIDUAL-LEVEL DATA
********************************************************************************
use "${data_2021}/ehcvm_individu_sen2021", clear

* Keep relevant variables
* Note: numind here is the INDIVIDUAL ID from the roster (s01q00a)
* This is different from proprietor_id which identifies enterprise owners

keep grappe menage numind hhid hhweight ///
     sexe age zae milieu csp activ7j ///
     educ_hi alfa educ_scol ethnie

* Note: In 2021, ethnicity (ethnie) already exists in individual dataset
* This is different from 2018 where we got it from Section 1
* 2021 also has alfa (not alfab like 2018)

* Rename with _2021 suffix
rename sexe sexe_2021
rename age age_2021
rename educ_hi educ_hi_2021
rename alfa alfab_2021  // CHANGED: alfab in 2018, so renamed for consistency
rename educ_scol educ_scol_2021
rename activ7j activ7j_2021
rename csp hcsp_2021
rename hhweight hhweight_2021
rename ethnie ethnie_2021  // CHANGED: directly from individual dataset in 2021

*------------------------------------------------------------------------------
* 2.1: Create individual ID for merging with enterprises
*------------------------------------------------------------------------------

* Create composite ID using INDIVIDUAL ID (numind from roster)
* This will match with enterprise data where nonag_id uses proprietor_id
* For entrepreneurs: numind should equal proprietor_id
* For non-entrepreneurs: they won't match to enterprises
gen nonag_id = strofreal(grappe,"%3.0f") + "_" + ///
               strofreal(menage,"%02.0f") + "_" + ///
               strofreal(numind,"%02.0f")

label variable nonag_id "Individual ID (cluster_household_individual)"

*------------------------------------------------------------------------------
* 2.2 Merge with enterprise data
*------------------------------------------------------------------------------

merge 1:1 nonag_id using `enterprise_2021'

/*
  Result                      Number of obs
    -----------------------------------------
    Not matched                        57,696
        from master                    57,696  (_merge==1)
        from using                          0  (_merge==2)

    Matched                             5,834  (_merge==3)
    -----------------------------------------

*/

* Keep all individuals (entrepreneurs and non-entrepreneurs)
keep if _merge == 1 | _merge == 3
* This keeps: all individuals whether they have enterprises or not
* This drops: any enterprise records without corresponding individuals (shouldn't exist)

* Create entrepreneur indicator based on merge result
gen ent_2021 = (_merge==3)
label variable ent_2021 "Is entrepreneur in 2021"

* Create proprietor flag
* For entrepreneurs: check if this individual is the main proprietor
* For non-entrepreneurs: will be missing
gen is_proprietor = (numind == proprietor_id) if ent_2021==1
replace is_proprietor = 0 if numind != proprietor_id 
label variable is_proprietor "Individual is the main proprietor (vs other HH member)"
label define is_proprietor 0 "HH member, not proprietor" 1 "Main proprietor"
label values is_proprietor is_proprietor

* Note: proprietor_id only exists for entrepreneurs (from enterprise data)
* So is_proprietor is only defined for ent_2021==1

tab _merge
drop _merge

*for consistent hhids across panels

rename hhid hhid1

gen hhid = grappe * 1000 + menage
    label variable hhid "Household ID (numeric)"

tempfile ind_data
save `ind_data', replace 

********************************************************************************
* PART 3: Load and merge Section 4 Employment Data - 2021
********************************************************************************

* NOTE: In 2021, Section 4 is split into 3 files:
* - s04a_me_sen2021: Employment status and job search
* - s04b_me_sen2021: Primary job details
* - s04c_me_sen2021: Secondary job details

*------------------------------------------------------------------------------
* 3.0: Merge all Section 4 files together first
*------------------------------------------------------------------------------

* Step 1: Load s04a (employment status)
preserve
    use "${data_2021}/s04a_me_sen2021", clear
	
 
    gen hhid = grappe * 1000 + menage
    label variable hhid "Household ID (numeric)"

    
    * Keep only relevant variables
    keep grappe menage hhid membres__id ///
         s04q06 s04q07 s04q08 s04q09 s04q13 s04q14 /// Working status questions
         s04q28a s04q28b /// type of work for primary and secondary emp
         s04q15 s04q17 s04q19 // Job search questions
    
    * Rename individual ID
    rename membres__id numind
    
    tempfile s04a
    save `s04a'
restore

* Step 2: Load s04b (primary job details)
preserve
    use "${data_2021}/s04b_me_sen2021", clear
    
    gen hhid = grappe * 1000 + menage
    
    * Keep only relevant variables
    keep grappe menage hhid membres__id ///
         s04q29b s04q30b /// Occupation and industry
         s04q32 /// Months worked
         s04q36 s04q37 /// Days and hours worked
         s04q38 /// Pension/retirement contribution (formality)
         s04q39 /// Socioprofessional category
         s04q31 /// Principal employer (public/private)
         s04q43 s04q43_unite /// Salary primary
         s04q44 s04q45 s04q45_unite /// Bonuses primary
         s04q46 s04q47 s04q47_unite /// In-kind benefits primary
         s04q48 s04q49 s04q49_unite /// Food primary
         s04q50 // Has secondary job
    
    * Rename individual ID
    rename membres__id numind
    
    * Merge with s04a
    merge 1:1 hhid numind using `s04a'
	/*
	 Result                      Number of obs
    -----------------------------------------
    Not matched                        32,367
        from master                         0  (_merge==1)
        from using                     32,367  (_merge==2)

    Matched                            22,159  (_merge==3)
    -----------------------------------------
*/
	
    
    * Keep all (some may only have status, some only have job details)
    keep if _merge == 1 | _merge == 2 | _merge == 3
    drop _merge
    
    tempfile s04ab
    save `s04ab'
restore

* Step 3: Load s04c (secondary job details)
preserve
    use "${data_2021}/s04c_me_sen2021", clear
    
    gen hhid = grappe * 1000 + menage
    
    * Keep only relevant variables
    keep grappe menage hhid membres__id ///
         s04q50 /// Has secondary job (may be duplicate from s04b)
		 s04q54 /// months worked
         s04q55 s04q56 /// Secondary job days and hours
         s04q58 s04q58_unite /// Salary secondary
         s04q59 s04q60 s04q60_unite /// Bonuses secondary
         s04q61 s04q62 s04q62_unite /// Benefits secondary
         s04q63 s04q64 s04q64_unite // Food secondary
    
    * Rename individual ID
    rename membres__id numind
    
    * Merge with s04ab
    merge 1:1 hhid numind using `s04ab'
	
	/*
	Result                      Number of obs
    -----------------------------------------
    Not matched                        49,901
        from master                         0  (_merge==1)
        from using                     49,901  (_merge==2)

    Matched                             4,625  (_merge==3)
    -----------------------------------------
*/

    * Keep all
    keep if _merge == 1 | _merge == 2 | _merge == 3
    drop _merge
    
    * Now we have all Section 4 data combined
    
    *--------------------------------------------------------------------------
    * Add labels in English
    *--------------------------------------------------------------------------
    
    label var s04q06 "worked at least 1 hour in a field/garden or raised animals for his/her own account in the last 7 days"
    label var s04q07 "worked at least 1 hour, with remuneration, in a commercial/market activity for his/her own account in the last 7 days"
    label var s04q08 "worked at least 1 hour, for a company/employer or State/Government in the last 7 days"
    label var s04q09 "worked at least 1 hour, with remuneration, as an apprentice in the last 7 days"
    label var s04q13 "worked in a field/garden, for another HH member without remuneration in the last 7 days"
    label var s04q14 "worked in a shop/business for another HH member without remuneration in the last 7 days"
    label var s04q15 "looked for paid employment during the last 30 days"
    label var s04q17 "looked for paid employment during the last 30 days"
    label var s04q19 "available to work immediately"
    
    label var s04q29b "Occupation"
    
    label define occupation_lbl ///
        0  "Armed forces" ///
        1  "Managers" ///
        2  "Professionals" ///
        3  "Technicians and Associate Professionals)" ///
        4  "Clerical Support Staff" ///
        5  "Service and Sales Workers" ///
        6  "Skilled agri, forestry, and fishery workers" ///
        7  "Craft and related trades workers" ///
        8  "Plant and machine operators and assembler" ///
        9  "Elementry occupations" ///
      
    
    label values s04q29b occupation_lbl
    
    label var s04q30b "Industry"
    label var s04q32 "months worked in the job in the past 12 months"
    label var s04q36 "days per month worked in this job"
    label var s04q37 "hours per day worked in this job"
    label var s04q39 "socio-professional category"
    
    label define socioprof_lbl ///
        1  "Senior manager / executive" ///
        2  "Middle manager / supervisor" ///
        3  "Skilled worker or employee" ///
        4  "Unskilled worker or employee" ///
        5  "Labourer / domestic helper" ///
        6  "Paid intern or apprentice" ///
        7  "Unpaid intern or apprentice" ///
        8  "Contributing family worker" ///
        9  "Own-account worker (self-employed)" ///
        10 "Employer / business owner"
    
    label values s04q39 socioprof_lbl
    
    label var s04q38 "Contributes to IPRES/FNR/Retraite Complémentaire for this job"
    label define yesno_lbl 1 "Yes" 2 "No", replace
    label values s04q38 yesno_lbl

    label var s04q31 "Principal employer for this job"
    label define employer_lbl ///
        1 "State/Local government" ///
        2 "Public/parastatal enterprise" ///
        3 "Private enterprise" ///
        4 "Associative enterprise" ///
        5 "Household as employer of domestic staff" ///
        6 "International organization/Embassy"
    label values s04q31 employer_lbl

    label var s04q43 "Salary/wage for this job for the reference time period"
    label var s04q43_unite "unit salary"

    label var s04q50 "In addition to the main job, do you have a secondary job?"
    
    tempfile employment_data
    save `employment_data'
restore

* Merge employment data with individual data
merge 1:1 hhid numind using `employment_data'

tab _merge
drop _merge

*------------------------------------------------------------------------------
* 3.1: PRIMARY EMPLOYMENT - Employment status
*------------------------------------------------------------------------------

* Working status (employed if worked in last 7 days)
* Employed includes: own account work, wage work, unpaid family work
gen employed = 0
replace employed = 1 if s04q06==1  // Worked in field/garden for own account
replace employed = 1 if s04q07==1  // Worked with pay for own account
replace employed = 1 if s04q08==1  // Worked with pay for the state
replace employed = 1 if s04q09==1  // Worked with pay as apprentice
replace employed = 1 if s04q13==1  // Worked in field for HH member without pay
replace employed = 1 if s04q14==1  // Worked in commerce for HH member without pay

label variable employed "Employed (worked in last 7 days, paid or unpaid)"
label define employed 0 "Not employed" 1 "Employed"
label values employed employed

* Unemployed (not working but looking for job)
gen unemployed = 0
replace unemployed = 1 if employed==0 & (s04q15==1 | s04q17==1)

label variable unemployed "Unemployed (not working but looking and available)"
label define unemployed 0 "Not unemployed" 1 "Unemployed"
label values unemployed unemployed

* Labor force participation (employed or unemployed)
gen in_labor_force = (employed==1 | unemployed==1)
label variable in_labor_force "In labor force (employed or unemployed)"

gen working_age = (age_2021 >= 15 & age_2021 <= 64)
label variable working_age "Working age population (15-64)"

*------------------------------------------------------------------------------
* 3.2: PRIMARY EMPLOYMENT - Sector and occupation
*------------------------------------------------------------------------------

* Industry/sector - recode to match enterprise categories
recode s04q30b ///
    (1 2   = 1 "Ag and extractives") ///
    (3     = 2 "Manufacturing") ///
    (4 5 6 = 3 "Utilities and construction") ///
    (7 9   = 5 "Retail") ///
    (8     = 6 "Transport") ///
    (19    = 7 "Personal services") ///
    (10/18 20 21 = 9 "Other"), ///
    gen(sector_work) 

label variable sector_work "Sector of work (primary employment)"

*------------------------------------------------------------------------------
* 3.3: PRIMARY EMPLOYMENT - Type of employment
*------------------------------------------------------------------------------

* Type of employment based on socioprofessional category (s04q39)
* 1-6 = Paid work, 7 = Unpaid intern/apprentice, 8 = Unpaid family worker,
* 9 = Own-account worker, 10 = Employer

gen emp_type = .
replace emp_type = 1 if inrange(s04q39, 1, 6)   // Paid work (salaried + paid apprentices)
replace emp_type = 2 if s04q39 == 7             // Unpaid work (unpaid intern/apprentice)
replace emp_type = 3 if s04q39 == 8             // Unpaid family worker
replace emp_type = 4 if s04q39 == 9             // Own account worker (self-employed)
replace emp_type = 5 if s04q39 == 10            // Employer

label variable emp_type "Type of employment"
label define emp_type ///
    1 "Paid work" ///
    2 "Unpaid work" ///
    3 "Unpaid family worker" ///
    4 "Own account worker" ///
    5 "Employer"
label values emp_type emp_type

*------------------------------------------------------------------------------
* 3.3b: PRIMARY EMPLOYMENT - Formal employment (pension contribution)
*------------------------------------------------------------------------------

* Formal employment: contributes to IPRES, FNR, or Retraite Complémentaire (s04q38)
gen formal = (s04q38 == 1) if s04q38 != .
label variable formal "Formal employment (contributes to pension/retirement)"
label define formal_lbl 0 "Informal" 1 "Formal"
label values formal formal_lbl

*------------------------------------------------------------------------------
* 3.3c: PRIMARY EMPLOYMENT - Public/private employer
*------------------------------------------------------------------------------

* Public/private based on principal employer (s04q53)
gen public_employer = .
replace public_employer = 1 if inlist(s04q31, 1, 2)    // State or public/parastatal enterprise
replace public_employer = 0 if inlist(s04q31, 3, 4, 5, 6)  // Private, associative, household, international

label variable public_employer "Public sector employer"
label define public_lbl 0 "Private" 1 "Public"
label values public_employer public_lbl

*------------------------------------------------------------------------------
* 3.4: PRIMARY EMPLOYMENT - Hours worked
*------------------------------------------------------------------------------

* Days per month
gen days_worked_month = s04q36
label variable days_worked_month "Days per month worked (primary job)"

* Hours per day
gen hours_worked_day = s04q37
label variable hours_worked_day "Hours per day worked (primary job)"

* Total hours per month
gen hours_worked_month = days_worked_month * hours_worked_day
label variable hours_worked_month "Total hours per month (primary job)"

* Months worked in last 12 months
gen months_worked = s04q32
label variable months_worked "Months worked in last 12 months (primary job)"

*------------------------------------------------------------------------------
* 3.5: PRIMARY EMPLOYMENT - Salary and benefits (MONTHLY)
*------------------------------------------------------------------------------

* Unit conversion codes:
* 1 = Week (semaine)
* 2 = Month (mois)
* 3 = Quarter (trimestre)
* 4 = Year (an)

* Salary (convert to monthly)
gen salary_month = .
replace salary_month = s04q43 * 4.33 if s04q43_unite==1    // Weekly
replace salary_month = s04q43 if s04q43_unite==2           // Monthly
replace salary_month = s04q43 / 3 if s04q43_unite==3       // Quarterly
replace salary_month = s04q43 / 12 if s04q43_unite==4      // Annually

label variable salary_month "Monthly salary (primary job, FCFA)"

* Bonuses (convert to monthly)
gen bonus_month = 0
replace bonus_month = s04q45 * 4.33 if s04q44==1 & s04q45_unite==1
replace bonus_month = s04q45 if s04q44==1 & s04q45_unite==2
replace bonus_month = s04q45 / 3 if s04q44==1 & s04q45_unite==3
replace bonus_month = s04q45 / 12 if s04q44==1 & s04q45_unite==4

label variable bonus_month "Monthly bonuses (primary job, FCFA)"

* In-kind benefits (convert to monthly)
gen benefits_inkind_month = 0
replace benefits_inkind_month = s04q47 * 4.33 if s04q46==1 & s04q47_unite==1
replace benefits_inkind_month = s04q47 if s04q46==1 & s04q47_unite==2
replace benefits_inkind_month = s04q47 / 3 if s04q46==1 & s04q47_unite==3
replace benefits_inkind_month = s04q47 / 12 if s04q46==1 & s04q47_unite==4

label variable benefits_inkind_month "Monthly in-kind benefits (primary job, FCFA)"

* Food value (convert to monthly)
gen food_value_month = 0
replace food_value_month = s04q49 * 4.33 if s04q48==1 & s04q49_unite==1
replace food_value_month = s04q49 if s04q48==1 & s04q49_unite==2
replace food_value_month = s04q49 / 3 if s04q48==1 & s04q49_unite==3
replace food_value_month = s04q49 / 12 if s04q48==1 & s04q49_unite==4

label variable food_value_month "Monthly food value (primary job, FCFA)"

* Total compensation (salary + bonuses + benefits + food)
egen total_comp_month = rowtotal(salary_month bonus_month benefits_inkind_month food_value_month)
label variable total_comp_month "Total monthly compensation (primary job, FCFA)"

*------------------------------------------------------------------------------
* 3.6: SECONDARY EMPLOYMENT
*------------------------------------------------------------------------------

* Has secondary job
gen has_secondary_job = (s04q50==1)
label variable has_secondary_job "Has secondary job"
label define has_secondary_job 0 "No secondary job" 1 "Has secondary job"
label values has_secondary_job has_secondary_job

* Hours worked - secondary job
gen days_worked_month_sec = s04q55 if has_secondary_job==1
label variable days_worked_month_sec "Days per month (secondary job)"

gen hours_worked_day_sec = s04q56 if has_secondary_job==1
label variable hours_worked_day_sec "Hours per day (secondary job)"

gen hours_worked_month_sec = days_worked_month_sec * hours_worked_day_sec
label variable hours_worked_month_sec "Total hours per month (secondary job)"

* Salary - secondary job (convert to monthly)
gen salary_month_sec = .
replace salary_month_sec = s04q58 * 4.33 if has_secondary_job==1 & s04q58_unite==1
replace salary_month_sec = s04q58 if has_secondary_job==1 & s04q58_unite==2
replace salary_month_sec = s04q58 / 3 if has_secondary_job==1 & s04q58_unite==3
replace salary_month_sec = s04q58 / 12 if has_secondary_job==1 & s04q58_unite==4

label variable salary_month_sec "Monthly salary (secondary job, FCFA)"

* Bonuses - secondary job
gen bonus_month_sec = 0
replace bonus_month_sec = s04q60 * 4.33 if has_secondary_job==1 & s04q59==1 & s04q60_unite==1
replace bonus_month_sec = s04q60 if has_secondary_job==1 & s04q59==1 & s04q60_unite==2
replace bonus_month_sec = s04q60 / 3 if has_secondary_job==1 & s04q59==1 & s04q60_unite==3
replace bonus_month_sec = s04q60 / 12 if has_secondary_job==1 & s04q59==1 & s04q60_unite==4

label variable bonus_month_sec "Monthly bonuses (secondary job, FCFA)"

* In-kind benefits - secondary job
gen benefits_inkind_month_sec = 0
replace benefits_inkind_month_sec = s04q62 * 4.33 if has_secondary_job==1 & s04q61==1 & s04q62_unite==1
replace benefits_inkind_month_sec = s04q62 if has_secondary_job==1 & s04q61==1 & s04q62_unite==2
replace benefits_inkind_month_sec = s04q62 / 3 if has_secondary_job==1 & s04q61==1 & s04q62_unite==3
replace benefits_inkind_month_sec = s04q62 / 12 if has_secondary_job==1 & s04q61==1 & s04q62_unite==4

label variable benefits_inkind_month_sec "Monthly benefits (secondary job, FCFA)"

* Food - secondary job
gen food_value_month_sec = 0
replace food_value_month_sec = s04q64 * 4.33 if has_secondary_job==1 & s04q63==1 & s04q64_unite==1
replace food_value_month_sec = s04q64 if has_secondary_job==1 & s04q63==1 & s04q64_unite==2
replace food_value_month_sec = s04q64 / 3 if has_secondary_job==1 & s04q63==1 & s04q64_unite==3
replace food_value_month_sec = s04q64 / 12 if has_secondary_job==1 & s04q63==1 & s04q64_unite==4

label variable food_value_month_sec "Monthly food value (secondary job, FCFA)"

* Total secondary compensation
egen total_comp_month_sec = rowtotal(salary_month_sec bonus_month_sec benefits_inkind_month_sec food_value_month_sec)
label variable total_comp_month_sec "Total monthly compensation (secondary job, FCFA)"

*------------------------------------------------------------------------------
* 3.7: COMBINED EMPLOYMENT INCOME
*------------------------------------------------------------------------------

* Total employment income (primary + secondary)
egen total_emp_income_month = rowtotal(total_comp_month total_comp_month_sec)
label variable total_emp_income_month "Total monthly employment income (both jobs, FCFA)"

********************************************************************************
* PART 4: MERGE HOUSEHOLD-LEVEL DATA
********************************************************************************

*------------------------------------------------------------------------------
* 4.1: Merge household characteristics
*------------------------------------------------------------------------------

*first fix the hhid variable in the hh survey data
preserve
use "${data_2021}/ehcvm_menage_sen2021", clear
rename hhid hhid1
gen hhid = grappe * 1000 + menage

tempfil hhdata
save `hhdata', replace
restore

merge n:1 hhid using `hhdata'

/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                             0
    Matched                            63,530  (_merge==3)
    -----------------------------------------
*/



tab _merge
drop _merge

*------------------------------------------------------------------------------
* 4.2: Merge welfare data
*------------------------------------------------------------------------------

*first fix the hhid variable in the hh survey data
preserve
use "${data_2021}/ehcvm_welfare_sen2021", clear
rename hhid hhid1
gen hhid = grappe * 1000 + menage

tempfil welfaredata
save `welfaredata', replace
restore

merge n:1 hhid using `welfaredata'

/*

    Result                      Number of obs
    -----------------------------------------
    Not matched                             0
    Matched                            63,530  (_merge==3)
    -----------------------------------------

*/

tab _merge
drop _merge

********************************************************************************
* PART 5: CREDIT SECTION (SECTION 6) - HOUSEHOLD LEVEL - 2021
********************************************************************************

* Section 6 is individual-level, so we need to aggregate to household level

*------------------------------------------------------------------------------
* 5.1: Load and merge Section 6 credit data
*------------------------------------------------------------------------------

preserve
    use "${data_2021}/s06_me_sen2021", clear

    gen hhid = grappe * 1000 + menage
    label variable hhid "Household ID (numeric)"
    
    * Keep only relevant variables
    keep grappe menage hhid membres__id ///
         s06q05 s06q12 s06q12_autre s06q14 s06q09 s06q10
    
    * Rename individual ID for merge
    rename membres__id numind
    
    tempfile credit_data
    save `credit_data'
restore

* Merge credit data
merge 1:1 hhid numind using `credit_data'

tab _merge
drop _merge

*------------------------------------------------------------------------------
* 5.2: Individual-level credit indicators
*------------------------------------------------------------------------------

* Individual got credit in last 12 months (s06q05)
gen ind_got_credit = (s06q05 == 1) if !missing(s06q05)
label variable ind_got_credit "Individual obtained credit in last 12 months"

* Individual credit source (s06q12)
gen ind_credit_source = s06q12 if ind_got_credit==1
label variable ind_credit_source "Source of individual's credit"

label define credit_source ///
    1 "Bank" ///
    2 "Rural Credit Union/MFI" ///
    3 "NGO" ///
    4 "Supplier" ///
    5 "Cooperative" ///
    6 "Other Household" ///
    7 "Tontine" ///
    8 "Moneylender" ///
    9 "Other"
    
label values ind_credit_source credit_source

* Individual credit amount
gen ind_credit_amount = s06q14 if ind_got_credit==1
label variable ind_credit_amount "Amount of individual's last credit (FCFA)"

* Individual has outstanding loans from past
gen ind_has_outstanding = (s06q09 == 1) if !missing(s06q09)
label variable ind_has_outstanding "Individual has outstanding loans from past"

* Number of outstanding loans
gen ind_num_outstanding = s06q10 if ind_has_outstanding==1
label variable ind_num_outstanding "Number of outstanding loans"

*------------------------------------------------------------------------------
* 5.3: HOUSEHOLD-LEVEL credit indicators
*------------------------------------------------------------------------------

* Whether ANY household member got credit
bysort hhid: egen hh_got_credit = max(ind_got_credit)
replace hh_got_credit = 0 if missing(hh_got_credit)
label variable hh_got_credit "Any HH member obtained credit in last 12 months"
label define hh_got_credit 0 "No credit" 1 "Got credit"
label values hh_got_credit hh_got_credit

* Number of household members who got credit
bysort hhid: egen hh_num_with_credit = total(ind_got_credit)
label variable hh_num_with_credit "Number of HH members who got credit"

* Main credit source for household (most common source among HH members)
* For households with credit, identify the most frequent source
bysort hhid ind_credit_source: gen source_count = _N if !missing(ind_credit_source)
bysort hhid: egen max_source_count = max(source_count)

gen hh_credit_source = ind_credit_source if source_count == max_source_count & hh_got_credit==1
bysort hhid: egen hh_main_credit_source = mode(hh_credit_source), maxmode
drop source_count max_source_count hh_credit_source

label variable hh_main_credit_source "Main credit source for household"
label values hh_main_credit_source credit_source

* Total credit amount at household level (sum of all individual credits)
bysort hhid: egen hh_total_credit_amount = total(ind_credit_amount)
replace hh_total_credit_amount = 0 if hh_got_credit==0
label variable hh_total_credit_amount "Total credit amount for household (FCFA)"

* Whether household has outstanding loans
bysort hhid: egen hh_has_outstanding = max(ind_has_outstanding)
replace hh_has_outstanding = 0 if missing(hh_has_outstanding)
label variable hh_has_outstanding "Any HH member has outstanding loans"

* Total number of outstanding loans in household
bysort hhid: egen hh_total_outstanding = total(ind_num_outstanding)
label variable hh_total_outstanding "Total outstanding loans in household"

*------------------------------------------------------------------------------
* 5.4: Credit source categories (for analysis)
*------------------------------------------------------------------------------

* Formal credit (bank, MFI, NGO, cooperative)
gen hh_formal_credit = 0 if hh_got_credit==1
replace hh_formal_credit = 1 if inlist(hh_main_credit_source, 1, 2, 3, 5)
label variable hh_formal_credit "HH got credit from formal source"
label define hh_formal_credit 0 "Informal source" 1 "Formal source"
label values hh_formal_credit hh_formal_credit

* Informal credit (supplier, other HH, tontine, moneylender, other)
gen hh_informal_credit = 0 if hh_got_credit==1
replace hh_informal_credit = 1 if inlist(hh_main_credit_source, 4, 6, 7, 8, 9)
label variable hh_informal_credit "HH got credit from informal source"
label define hh_informal_credit 0 "Formal source" 1 "Informal source"
label values hh_informal_credit hh_informal_credit

* Specific source dummies (for cooperative analysis)
gen hh_credit_bank = (hh_main_credit_source == 1) if hh_got_credit==1
label variable hh_credit_bank "HH main credit from bank"

gen hh_credit_mfi = (hh_main_credit_source == 2) if hh_got_credit==1
label variable hh_credit_mfi "HH main credit from MFI"

gen hh_credit_coop = (hh_main_credit_source == 5) if hh_got_credit==1
label variable hh_credit_coop "HH main credit from cooperative"

gen hh_credit_tontine = (hh_main_credit_source == 7) if hh_got_credit==1
label variable hh_credit_tontine "HH main credit from tontine"

********************************************************************************
* PART 6: REMITTANCES SECTION (SECTION 13) - HOUSEHOLD LEVEL - 2021
********************************************************************************

* This section creates household-level remittance indicators
* Section 13_2 contains transfer details (amount and frequency)

*------------------------------------------------------------------------------
* 6.1: Load Section 13 remittance data and create hhid 
*------------------------------------------------------------------------------

preserve
    use "${data_2021}/s13_2_me_sen2021", clear
    gen hhid = grappe * 1000 + menage
    label variable hhid "Household ID"
    
    *this is also individual level data 

    *--------------------------------------------------------------------------
    * Convert frequency to annual amount
    *--------------------------------------------------------------------------
    
    * s13q22a = Amount sent each time (2021 - was s13aq17a in 2018)
    * s13q22b = Frequency of transfers (2021 - was s13aq17b in 2018)
    * Frequency codes:
    * 1 = Per month (mois)
    * 2 = Per quarter (trimestre)
    * 3 = Per semester (semestre)
    * 4 = Per year (année)
    * 5 = Irregular (irrégulier)

    gen amount_remit_annual = s13q22a
    replace amount_remit_annual = s13q22a * 12 if s13q22b == 1  // Monthly
    replace amount_remit_annual = s13q22a * 4  if s13q22b == 2  // Quarterly
    replace amount_remit_annual = s13q22a * 2  if s13q22b == 3  // Semester
    replace amount_remit_annual = s13q22a * 1  if s13q22b == 4  // Annual
    * For irregular (5), keep as reported (assume annual)
    replace amount_remit_annual = s13q22a * 1  if s13q22b == 5  // Irregular

    label variable amount_remit_annual "Annual remittance amount (FCFA)"
    
    * Sender location (for abroad indicator)
    * s13q19: 1-3 and 10 = Senegal, 4+ (except 10) = Abroad (2021 - was s13aq14 in 2018)
    gen remit_from_abroad = 0
    replace remit_from_abroad = 1 if inrange(s13q19, 4, 16)  // ECOWAS (except Senegal)
	replace remit_from_abroad = 1 if inrange(s13q19, 18, 24) // Togo + other countries
	replace remit_from_abroad = 0 if inlist(s13q19, 1, 2, 3, 17) // Senegal

	
	
	
    label variable remit_from_abroad "Remittance from abroad"
    label define remit_from_abroad 0 "Domestic (Senegal)" 1 "From abroad"
    label values remit_from_abroad remit_from_abroad

    * Keep detailed location for reference
    gen remit_sender_location = s13q19
    label variable remit_sender_location "Sender location (detailed)"

   label define sender_location ///
    1 "Same city/village" ///
    2 "Same region" ///
    3 "Elsewhere in Senegal" ///
    4 "Benin" ///
    5 "Burkina Faso" ///
    6 "Cape Verde" ///
    7 "Côte d'Ivoire" ///
    8 "Gambia" ///
    9 "Ghana" ///
    10 "Guinea" ///
    11 "Guinea-Bissau" ///
    12 "Liberia" ///
    13 "Niger" ///
    14 "Nigeria" ///
    15 "Mali" ///
    16 "Sierra Leone" ///
    17 "Senegal" ///
    18 "Togo" ///
    19 "Other Africa" ///
    20 "France" ///
    21 "Spain" ///
    22 "Italy" ///
    23 "USA" ///
    24 "Other (outside Africa)"
    
    label values remit_sender_location sender_location

    * Total remittances per household (sum across all transfers)
    collapse (sum) amount_remit_annual ///
             (max) remit_from_abroad, ///
             by(hhid)
    
    * Create indicator for received remittances
    gen hh_received_remittances = 1
    label variable hh_received_remittances "Household received remittances"
    
    rename amount_remit_annual hh_remit_total_annual
    label variable hh_remit_total_annual "Total annual remittances received (FCFA)"
    
    rename remit_from_abroad hh_remit_from_abroad
    label variable hh_remit_from_abroad "HH received remittances from abroad"
    label define hh_remit_from_abroad 0 "Domestic only" 1 "From abroad"
    label values hh_remit_from_abroad hh_remit_from_abroad
    
    tempfile remittances_hh
    save `remittances_hh'
restore   

merge m:1 hhid using `remittances_hh'

* Fill in missing values for households without remittances
replace hh_received_remittances = 0 if _merge == 1
replace hh_remit_total_annual = 0 if _merge == 1
replace hh_remit_from_abroad = 0 if _merge == 1

drop _merge

********************************************************************************
* PART 7: FINAL ORGANIZATION - 2021
********************************************************************************

* Add year identifier
* year variable is already in 2021 data. it was part of the individual level data

* Order variables
order year vague grappe menage numind nonag_id hhid ///
      ent_2021 sexe_2021 age_2021 hhweight_2021

* Label dataset
label data "EHCVM Senegal 2021 - Cleaned"

********************************************************************************
* PART 8: SAVE - 2021
********************************************************************************

compress
save "${intermediate}/SEN_2021_cleaned.dta", replace

*--- Create 5-household subset for sharing ---
set seed 12345
preserve
    * Pick 5 unique households
    bysort hhid: gen _first = (_n == 1)
    gen _rand = runiform() if _first == 1
    bysort hhid (_rand): replace _rand = _rand[1]
    egen _rank = rank(_rand) if _first == 1, unique
    bysort hhid (_rank): replace _rank = _rank[1]
    keep if _rank <= 5
    drop _first _rand _rank
    save "${output}/SEN_2021_cleaned_subset5.dta", replace
    export excel using "${output}/SEN_2021_cleaned_subset5.xlsx", firstrow(variables) replace
    di as result "Subset saved: 5 households from 2021 data"
restore

********************************************************************************
* PART 9: QUALITY CHECKS - 2021
********************************************************************************

* Check duplicates
duplicates report nonag_id

* Summary for entrepreneurs
sum revenue profit value_total if ent_2021==1 [aw=hhweight_2021], detail

* Summary statistics
summarize ent_2021 employed unemployed hh_got_credit hh_received_remittances [aw=hhweight_2021]

* Cross-tabulations
tab ent_2021 cooperative if ent_2021==1 [aw=hhweight_2021]
tab ent_2021 hh_credit_coop [aw=hhweight_2021]

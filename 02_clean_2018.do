********************************************************************************
* EHCVM SENEGAL - 2018 DATA CLEANING (CORRECTED VERSION)
********************************************************************************
* Purpose: Clean and prepare 2018 wave data for analysis
* Author: Zaineb Majoka (mzaineb@worldbank.org). Based on Do-Files shared by David & Joseph
* Date: March 5th 2026
* 
*
* INPUT:  Raw 2018 data files
* OUTPUT: Cleaned 2018 dataset
********************************************************************************

clear all
set more off

********************************************************************************
* PART 0: SET PATHS
********************************************************************************

* Main project directory
global project "C:\Users\WB461621\OneDrive - WBG\SPJ\West Africa\Regional HH Enterprise Work"

* Data directories
global data_2018     "${project}/Data/SEN/2018"
global intermediate  "${project}/Data/SEN/Intermediate"
global output        "${project}/Output/SEN"
global final         "${project}/Data/SEN/Final"

* Create directories if needed
capture mkdir "${intermediate}"
capture mkdir "${output}"

********************************************************************************
* PART 1: CLEAN ENTERPRISE DATA (SECTION 10)
********************************************************************************

use "${data_2018}/s10_2_me_sen2018", clear

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
* David did not include boys/girls working in the enterprise. We are only including 
* adults when counting number of employees

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

* Household employees (family workers) - up to 14 in 2018
* each variable refers to individual id within the household

gen num_hhemp = 0
label variable num_hhemp "Number of household employees"

forvalues person = 1/14 {
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
    8 "Other (specify)"
    
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

* Electricity - CORRECTED VARIABLE
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

* CNPS registration - NEW VARIABLE
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
* 1.11: Recode sector
*------------------------------------------------------------------------------

/*Sector categories in the original variable:


   10.17a Code de la branche d'activit� |      Freq.     Percent        Cum.
----------------------------------------+-----------------------------------
         Agriculture, p�che, foresterie |        105        1.61        1.61
                  Activit�s extractives |        132        2.02        3.63
               Activit�s de fabrication |      1,238       18.97       22.60
                  Eau, �lectricit�, gaz |         11        0.17       22.77
                           Construction |        252        3.86       26.63
Commerce de gros, d�tail et r�paration  |      3,117       47.76       74.39
                  Hotel et restauration |        175        2.68       77.08
Transport, activit�s des auxilliaires d |        284        4.35       81.43
                  Activit�s financi�res |         11        0.17       81.60
Immobilier, locations et services aux e |         27        0.41       82.01
                              �ducation |         47        0.72       82.73
 Activit�s de sant� et d'action sociale |         38        0.58       83.31
Assainissement, voirie et gestion des d |          1        0.02       83.33
                 Activit�s associatives |          2        0.03       83.36
Activit�s r�cr�atives, culturelles et s |          9        0.14       83.50
       Activit�s de services personnels |      1,067       16.35       99.85
Activit�s des m�nages en tant qu'employ |         10        0.15      100.00
----------------------------------------+-----------------------------------
                                  Total |      6,526      100.00

*/								

recode s10q17a ///
    (1/2   = 1 "Ag and extractives") ///
    (3     = 2 "Manufacturing") ///
    (4/5   = 3 "Utilities and construction") ///
    (6/7   = 5 "Retail") ///
    (8     = 6 "Transport") ///
    (17    = 7 "Personal services") ///
    (9/16 18 = 9 "Other"), ///
    gen(sector)

label variable sector "Sector"

*------------------------------------------------------------------------------
* 1.12: Revenue shares
*------------------------------------------------------------------------------

gen share_revenue_resale = s10q46/revenue
gen share_revenue_processed = s10q48/revenue
gen share_revenue_services = s10q50/revenue

*------------------------------------------------------------------------------
* 1.13: Problem variables (keep for regressions)
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
* 1.14: Number of enterprises per household 
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
* 1.15: Save enterprise data
*------------------------------------------------------------------------------

tempfile enterprise_2018
save `enterprise_2018', replace

********************************************************************************
* PART 2: LOAD AND PREPARE INDIVIDUAL-LEVEL DATA
********************************************************************************

use "${data_2018}/ehcvm_individu_sen2018", clear

/*Quality check - compare hhid from the enterprise dataset 

gen hhid1 = grappe * 1000 + menage
gen hhid_match = (hhid1 == hhid)

/*

hhid_match |      Freq.     Percent        Cum.
------------+-----------------------------------
          1 |     66,120      100.00      100.00
------------+-----------------------------------
      Total |     66,120      100.00

*/

drop hhid1

*/


* Keep relevant variables
* Note: numind here is the INDIVIDUAL ID from the roster (s01q00a)
* This is different from proprietor_id which identifies enterprise owners

keep grappe menage numind hhid hhweight ///
     sexe age zae milieu csp activ7j ///
     educ_hi alfab educ_scol

* Note: ethnie should NOT be in this dataset per user notes
* Will need to get from Section 1 roster

* Rename with _2018 suffix
rename sexe sexe_2018
rename age age_2018
rename educ_hi educ_hi_2018
rename alfab alfab_2018  // Correct variable name
rename educ_scol educ_scol_2018
rename activ7j activ7j_2018
rename csp hcsp_2018
rename hhweight hhweight_2018



*------------------------------------------------------------------------------
* 2.1: Merge ethnicity from Section 1 roster
*------------------------------------------------------------------------------

* Load ethnicity from Section 1
preserve
    use "${data_2018}/s01_me_sen2018", clear
    keep grappe menage s01q00a s01q16
    rename s01q00a numind
    rename s01q16 ethnie_2018
    tempfile ethnie_data
    save `ethnie_data'
restore

* Merge ethnicity
merge 1:1 grappe menage numind using `ethnie_data'

/* _merge values:

 Result                      Number of obs
    -----------------------------------------
    Not matched                             1
        from master                         1  (_merge==1)
        from using                          0  (_merge==2)

    Matched                            66,119  (_merge==3)
    -----------------------------------------
*/

* Keep all observations (both matched and unmatched from master)
keep if _merge == 1 | _merge == 3
* This keeps: individuals with or without ethnicity data
* This drops: any ethnicity records without corresponding individuals (shouldn't exist)

tab _merge
drop _merge

*------------------------------------------------------------------------------
* 2.2: Create individual ID for merging with enterprises
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
* 2.3: Merge with enterprise data
*------------------------------------------------------------------------------

merge 1:1 nonag_id using `enterprise_2018'

/* _merge values:
Result                      Number of obs
    -----------------------------------------
    Not matched                        59,604
        from master                    59,599  (_merge==1)
        from using                          5  (_merge==2)

    Matched                             6,521  (_merge==3)
    -----------------------------------------
*/
	
* Keep all individuals (entrepreneurs and non-entrepreneurs)
keep if _merge == 1 | _merge == 3
* This keeps: all individuals whether they have enterprises or not
* This drops: any enterprise records without corresponding individuals (shouldn't exist)

* Create entrepreneur indicator based on merge result
gen ent_2018 = (_merge==3)
label variable ent_2018 "Is entrepreneur in 2018"

* Create proprietor flag
* For entrepreneurs: check if this individual is the main proprietor
* For non-entrepreneurs: will be missing
gen is_proprietor = (numind == proprietor_id) if ent_2018==1
replace is_proprietor = 0 if numind != proprietor_id 
label variable is_proprietor "Individual is the main proprietor (vs other HH member)"
label define is_proprietor 0 "HH member, not proprietor" 1 "Main proprietor"
label values is_proprietor is_proprietor

* Note: proprietor_id only exists for entrepreneurs (from enterprise data)
* So is_proprietor is only defined for ent_2018==1

tab _merge
drop _merge

tempfile ind_data
save `ind_data', replace 

********************************************************************************
* PART 3: Load and merge Section 4 Employment Data 
********************************************************************************
preserve 
 use "${data_2018}/s04_me_sen2018", clear
 
gen hhid = grappe * 1000 + menage
label variable hhid "Household ID (numeric)"

  * Keep only relevant variables
    keep grappe menage hhid s01q00a ///
         s04q06 s04q07 s04q08 s04q09 s04q13 s04q14 /// Working status questions
		 s04q28a s04q28b /// type of work for primary and secondary emp
         s04q15 s04q17 s04q19 /// Job search questions
         s04q29b s04q30b /// Occupation and industry
         s04q32 /// Months worked
         s04q36 s04q37 /// Days and hours worked
         s04q39 /// Socioeconomic category
         s04q43 s04q43_unite /// Salary primary
         s04q44 s04q45 s04q45_unite /// Bonuses primary
         s04q46 s04q47 s04q47_unite /// In-kind benefits primary
         s04q48 s04q49 s04q49_unite /// Food primary
         s04q50 /// Has secondary job
         s04q55 s04q56 /// Secondary job days and hours
         s04q58 s04q58_unite /// Salary secondary
         s04q59 s04q60 s04q60_unite /// Bonuses secondary
         s04q61 s04q62 s04q62_unite /// Benefits secondary
         s04q63 s04q64 s04q64_unite // Food secondary
    
    * Rename individual ID for merge
    rename s01q00a numind
	
	*labels in English 
	label var s04q06 "worked at least 1 hour in a field/garden/raising livestock for his/her own account in the last 7 days"
	label var s04q07 "worked at least 1 hour, with remuneration, in a commercial/market activityfor his/her own account in the last 7 days"
	label var s04q08 "worked at least 1 hour, with remuneration, for the State/Government in the last 7 days"
	label var s04q09 "worked at least 1 hour, with remuneration, as an apprentice in the last 7 days"
	label var s04q13 "worked in a field/garden, for another HH member without remuneration in the last 7 days"
	label var s04q14 "worked in a shop/business for another HH member without remuneration in the last 7 days"
	label var s04q15 "looked for paid employment during the last 30 days"
	label var s04q17 "looked for paid employment during the last 30 days"
	label var s04q19 "available to work immediately"

	label var s04q29b "Occupation"
	
	*categories of occupation are different across years. To align with ISCO
	
	recode s04q29b ///
    (1  = 1) ///  Managers
    (2  = 2) ///  Professionals
    (3  = 3) ///  Technicians and associate professionals
    (4  = 4) ///  Clerical support workers
    (5  = 5) ///  Service and sales workers
    (6  = 6) ///  Skilled agricultural, forestry and fishery workers
    (7  = 7) ///  Craft and related trades workers
    (8  = 8) ///  Plant and machine operators and assemblers
    (9  = 9) ///  Elementary occupations
    (10 = 0) ///  Armed forces
    (11 = .) ///  Other — no ISCO-08 equivalent
    (12 = .) /// No occupation — set to missing
   
	
	label define occupation_lbl ///
   0 "Armed forces occupations" ///
    1 "Managers" ///
    2 "Professionals" ///
    3 "Technicians and associate professionals" ///
    4 "Clerical support workers" ///
    5 "Service and sales workers" ///
    6 "Skilled agricultural, forestry and fishery workers" ///
    7 "Craft and related trades workers" ///
    8 "Plant and machine operators and assemblers" ///
    9 "Elementary occupations"

* Apply labels to variable
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

* Apply labels to variable
label values s04q39 socioprof_lbl

	label var s04q43 "Salary/wage for this job for the reference time period"
	label var s04q43_unite "unit salary"
        
    label var s04q50 "In addtion to the main job, do you have a secondary job?"		
	/*
	*very few observations 
	label var s04q28a "Type of primary employment in the last 12 months"
	label var s04q28b "Type of secondary employment in the last 12 months"
	
	
label define employment_lbl ///
    1 "Farming, livestock, hunting, fishing (own account)" ///
    2 "Non-agricultural individual enterprise (own account)" ///
    3 "Public or private sector employee" ///
    4 "Occasional or part-time work" ///
    5 "Apprentice"

label values s04q28a employment_lbl
*/
	
    
    tempfile employment_data
    save `employment_data'
restore

* Merge employment data
merge 1:1 hhid numind using `employment_data'

/*
 Result                      Number of obs
    -----------------------------------------
    Not matched                             0
    Matched                            66,120  (_merge==3)
    -----------------------------------------

*/
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

gen working_age = (age >= 15 & age <= 64)
label variable working_age "Working age population (15-64)"

*------------------------------------------------------------------------------
* 3.2: PRIMARY EMPLOYMENT - Sector and occupation
*------------------------------------------------------------------------------

* Industry/sector - recode to match enterprise categories
recode s04q30b ///
    (1 2   = 1 "Ag and extractives") ///
    (3     = 2 "Manufacturing") ///
    (4 5   = 3 "Utilities and construction") ///
    (6 7   = 5 "Retail") ///
    (8     = 6 "Transport") ///
    (17    = 7 "Personal services") ///
    (9/16 18 19 = 9 "Other"), ///
    gen(sector_work) 

label variable sector_work "Sector of work (primary employment)"


*------------------------------------------------------------------------------
* 3.3: PRIMARY EMPLOYMENT - Type of employment
*------------------------------------------------------------------------------

* Type of employment based on socioeconomic category (s04q39)
* Need to check actual codes, but typical categories:
/*
_lbl:
           1 Senior manager / executive
           2 Middle manager / supervisor
           3 Skilled worker or employee
           4 Unskilled worker or employee
           5 Labourer / domestic helper
           6 Paid intern or apprentice
           7 Unpaid intern or apprentice
           8 Contributing family worker
           9 Own-account worker (self-employed)
          10 Employer / business owner

*/ 

gen emp_type = .
replace emp_type = 1 if inrange(s04q39, 1, 7)   // Wage worker (all salaried + apprentices)
replace emp_type = 2 if s04q39 == 9             // Own account worker (self-employed)
replace emp_type = 3 if s04q39 == 10            // Employer
replace emp_type = 4 if s04q39 == 8             // Unpaid family worker

label variable emp_type "Type of employment"
label define emp_type ///
    1 "Wage worker" ///
    2 "Own account worker" ///
    3 "Employer" ///
    4 "Unpaid family worker"
label values emp_type emp_type

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

merge n:1 hhid using "${data_2018}/ehcvm_menage_sen2018"

/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                             0
    Matched                            66,120  (_merge==3)
    -----------------------------------------
*/

* Keep all individuals (with or without household data)
keep if _merge == 1 | _merge == 3
* This keeps: all individuals whether they matched to household or not
* This drops: any household records without individuals

tab _merge
drop _merge

*------------------------------------------------------------------------------
* 4.1: Merge welfare data
*------------------------------------------------------------------------------

merge n:1 hhid using "${data_2018}/ehcvm_welfare_sen2018"

/*
 Result                      Number of obs
    -----------------------------------------
    Not matched                             0
    Matched                            66,120  (_merge==3)
    -----------------------------------------
*/


* Keep all individuals (with or without welfare data)
keep if _merge == 1 | _merge == 3
* This keeps: all individuals whether they have welfare data or not
* This drops: any welfare records without corresponding individuals

tab _merge
drop _merge

********************************************************************************
* PART 5: CREDIT SECTION (SECTION 6) - HOUSEHOLD LEVEL
********************************************************************************

* Section 6 is individual-level, so we need to aggregate to household level

*------------------------------------------------------------------------------
* 5.1: Load and merge Section 6 credit data
*------------------------------------------------------------------------------

preserve
    use "${data_2018}/s06_me_sen2018", clear

gen hhid = grappe * 1000 + menage
label variable hhid "Household ID (numeric)"
    
    * Keep only relevant variables
    keep grappe menage hhid s01q00a ///
         s06q05 s06q12 s06q12_autre s06q14 s06q09 s06q10
    
    * Rename individual ID for merge
    rename s01q00a numind
    
    tempfile credit_data
    save `credit_data'
restore

* Merge credit data
merge 1:1 hhid numind using `credit_data'

/*

    Result                      Number of obs
    -----------------------------------------
    Not matched                             0
    Matched                            66,120  (_merge==3)
    -----------------------------------------

*/
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
* PART 6: REMITTANCES SECTION (SECTION 13) - HOUSEHOLD LEVEL
********************************************************************************

* This section creates household-level remittance indicators
* Section 13a_2 contains transfer details (amount and frequency)

*------------------------------------------------------------------------------
* 6.1: Load Section 13 remittance data and create hhid 
*------------------------------------------------------------------------------

preserve
    use "${data_2018}/s13a_2_me_sen2018", clear
    gen hhid = grappe * 1000 + menage
    label variable hhid "Household ID"
	
	*this is also individual level data 

    *--------------------------------------------------------------------------
    * Convert frequency to annual amount
    *--------------------------------------------------------------------------
    
   * s13aq17a = Amount sent each time
* s13aq17b = Frequency of transfers
* Frequency codes:
* 1 = Per month (mois)
* 2 = Per quarter (trimestre)
* 3 = Per semester (semestre)
* 4 = Per year (année)
* 5 = Irregular (irrégulier)

gen amount_remit_annual = s13aq17a
replace amount_remit_annual = s13aq17a * 12 if s13aq17b == 1  // Monthly
replace amount_remit_annual = s13aq17a * 4  if s13aq17b == 2  // Quarterly
replace amount_remit_annual = s13aq17a * 2  if s13aq17b == 3  // Semester
replace amount_remit_annual = s13aq17a * 1  if s13aq17b == 4  // Annual
* For irregular (5), keep as reported (assume annual)
replace amount_remit_annual = s13aq17a * 1  if s13aq17b == 5  // Irregular

label variable amount_remit_annual "Annual remittance amount (FCFA)"
    
    * Sender location (for abroad indicator)
    * s13aq14: 1-3 = Senegal, 4+ = Abroad
  gen remit_from_abroad = 0
replace remit_from_abroad = 1 if inlist(s13aq14, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14)
replace remit_from_abroad = 0 if inlist(s13aq14, 1, 2, 3, 10)

label variable remit_from_abroad "Remittance from abroad"
label define remit_from_abroad 0 "Domestic (Senegal)" 1 "From abroad"
label values remit_from_abroad remit_from_abroad

* Keep detailed location for reference
gen remit_sender_location = s13aq14
label variable remit_sender_location "Sender location (detailed)"

label define sender_location ///
    1 "Same city/village" ///
    2 "Same region" ///
    3 "Elsewhere in Senegal" ///
    4 "Benin" ///
    5 "Burkina Faso" ///
    6 "Côte d'Ivoire" ///
    7 "Guinea-Bissau" ///
    8 "Mali" ///
    9 "Niger" ///
    10 "Senegal" ///
    11 "Togo" ///
    12 "Other Africa" ///
    13 "France" ///
    14 "Other (outside Africa)"
    
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

/*. merge m:1 hhid using `remittances_hh'

   Result                      Number of obs
    -----------------------------------------
    Not matched                        25,288
        from master                    25,288  (_merge==1)
        from using                          0  (_merge==2)

    Matched                            40,832  (_merge==3)
    -----------------------------------------

*/

drop _merge

********************************************************************************
* PART 6: FINAL ORGANIZATION
********************************************************************************

* Add year identifier
* year variable is already in 2018 data. it was part of the individual level data
/*gen year = 2018
label variable year "Survey year"
*/

* Order variables
order year vague grappe menage numind nonag_id hhid ///
      ent_2018 sexe_2018 age_2018 hhweight_2018

* Label dataset
label data "EHCVM Senegal 2018 - Cleaned"

********************************************************************************
* PART 7: SAVE
********************************************************************************

compress
save "${intermediate}/SEN_2018_cleaned.dta", replace

********************************************************************************
* PART 8: QUALITY CHECKS
********************************************************************************

* Check duplicates
duplicates report nonag_id

* Summary for entrepreneurs
sum revenue profit value_total if ent_2018==1 [aw=hhweight_2018], detail

********************************************************************************
*--- Create 5-household subset for sharing ---
********************************************************************************
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
    save "${output}/SEN_2018_cleaned_subset5.dta", replace
    export excel using "${output}/SEN_2018_cleaned_subset5.xlsx", firstrow(variables) replace
    di as result "Subset saved: 5 households from 2018 data"
restore



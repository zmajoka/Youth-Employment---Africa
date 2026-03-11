********************************************************************************
*                                                                              *
*  CONSUMPTION SMOOTHING AND HOUSEHOLD ENTERPRISE INCOME                       *
*  EHCVM Senegal Panel (2018/19 - 2021/22)                                    *
*                                                                              *
*  Following: Jack & Suri (2014, AER) - "Risk Sharing and Transactions Costs"  *
*             Chaijaroen (2019, JDE) - "Long-lasting income shocks"            *
*                                                                              *
*  Research Question: Does household enterprise income help households          *
*  smooth consumption in the face of negative shocks?                          *
*                                                                              *
*  Core Idea: Adapt the Jack & Suri DiD framework where the "treatment"        *
*  variable (M-PESA use in their paper) is replaced by household enterprise    *
*  participation/income. We test whether enterprise HHs experience smaller     *
*  consumption drops when hit by shocks.                                       *
*                                                                              *
*  Equation (adapted from Jack & Suri eq. 9):                                  *
*  ln(c_it) = alpha_i + gamma*Shock_it + mu*Enterprise_it                      *
*           + beta*(Enterprise_it x Shock_it)                                  *
*           + theta_S*(X_it x Shock_it) + theta_M*X_it                         *
*           + eta_jt + pi_t + epsilon_it                                       *
*                                                                              *
*  beta is the coefficient of interest: if positive and offsetting gamma,      *
*  enterprise income enables consumption smoothing.                            *
*                                                                              *
********************************************************************************

clear all
set more off
set matsize 10000

* ============================================================================
* USER: SET YOUR FILE PATHS HERE
* ============================================================================
* Point these to wherever you store the EHCVM .dta files on your machine
* The code assumes standard EHCVM file naming conventions

global datadir   "YOUR_DATA_DIRECTORY"     // <-- CHANGE THIS
global outputdir "YOUR_OUTPUT_DIRECTORY"   // <-- CHANGE THIS

* ============================================================================
* PROGRAM OUTLINE
* ============================================================================
* PART 0: Data Preparation — Panel Construction
* PART 1: Build Enterprise Variables (from Section 10)
* PART 2: Build Shock Variables (from ehcvm_menage / Section 14)
* PART 3: Build Consumption Variables (from ehcvm_welfare)
* PART 4: Build Control Variables (demographics, assets, financial access)
* PART 5: Merge All Modules and Construct Panel
* PART 6: Descriptive Statistics and Balance Tables
* PART 7: Main Regression Analysis — Consumption Smoothing
* PART 8: Heterogeneity Analysis
* PART 9: Robustness Checks
* ============================================================================



********************************************************************************
*                                                                              *
*  PART 0: PANEL CONSTRUCTION NOTES                                           *
*                                                                              *
*  EHCVM Senegal has a panel component: the 2021 survey re-interviews a        *
*  subset of 2018 households. The 2021 file s00_me_sen2021 has a variable      *
*  "PanelHH" (Type de ménage) that flags panel households, and s00q07d asks    *
*  "Le ménage a-t-il été interviewé lors de l'enquête ménage en 2018/2019?"   *
*                                                                              *
*  The panel identifier is the (grappe, menage) combination. Both waves use    *
*  this pair as household ID. The variable "hhid" in ehcvm_welfare is a        *
*  string identifier constructed from grappe + menage.                         *
*                                                                              *
*  IMPORTANT: You must verify that the same grappe-menage pair across          *
*  waves truly refers to the same household. Use PanelHH and s00q07d/s00q07e  *
*  to confirm panel status.                                                    *
*                                                                              *
********************************************************************************



********************************************************************************
*                                                                              *
*  PART 1: BUILD ENTERPRISE VARIABLES                                          *
*                                                                              *
*  Source 2018: s10_1_me_sen2018 (enterprise filter/screening)                 *
*              s10_2_me_sen2018 (enterprise details — revenues, costs, etc.)   *
*                                                                              *
*  Source 2021: s10a_me_sen2021 (enterprise filter/screening)                  *
*              s10b_me_sen2021 (enterprise details — revenues, costs, etc.)    *
*                                                                              *
*  Key variables from screening (s10_1 / s10a):                                *
*    s10q02 - Made beignets/grilled meat etc. (food processing)               *
*    s10q03 - Owned small tailoring/confection enterprise                      *
*    s10q04 - Owned construction enterprise                                    *
*    s10q05 - Owned commerce/trade enterprise                                  *
*    s10q06 - Exercised liberal profession (doctor, lawyer, etc.)             *
*    s10q07 - Owned service enterprise (taxi, moto-taxi, etc.)                *
*    s10q08 - Owned restaurant/bar                                             *
*    s10q09 - Owned rental enterprise (chairs, tables, etc.)                  *
*    s10q10 - Owned any other non-agricultural enterprise                      *
*    s10q11 - Filter: =1 if any of q02-q10 is positive (2018 only)           *
*                                                                              *
*  Key variables from details (s10_2 / s10b):                                  *
*    s10q46 - Revenue from resale of merchandise (last operating month)       *
*    s10q47 - Cost of merchandise purchased for resale                         *
*    s10q48 - Revenue from sale of transformed products                        *
*    s10q49 - Cost of raw materials for transformed products                   *
*    s10q50 - Revenue from services rendered                                   *
*    s10q51 - Other intermediate consumption costs                             *
*    s10q52 - Rent/water/electricity costs                                     *
*    s10q53 - Equipment service fees                                           *
*    s10q54 - Other fees and services                                          *
*    s10q59 - Number of months enterprise operated in last 12 months          *
*    s10q58 - Enterprise currently active (yes/no)                             *
*                                                                              *
********************************************************************************

* --- 2018 Enterprise Data ---

* Step 1a: Load enterprise screening to get HH-level enterprise ownership dummy
use "$datadir/s10_1_me_sen2018.dta", clear

* NOTE: s10q11 = 1 if any of questions 10.02 to 10.10 is positive
*       This is the built-in filter variable indicating HH owns at least 1 enterprise
gen has_enterprise_2018 = (s10q11 == 1) if s10q11 != .

* Also create dummies for specific enterprise types for heterogeneity analysis
* Food processing (beignets, grilled meat, etc.)
gen ent_food_2018 = (s10q02 == 1) if s10q02 != .
* Commerce/trade
gen ent_commerce_2018 = (s10q05 == 1) if s10q05 != .
* Services (taxi, moto, other services)
gen ent_services_2018 = (s10q07 == 1) if s10q07 != .

* Keep HH-level variables
keep grappe menage has_enterprise_2018 ent_food_2018 ent_commerce_2018 ent_services_2018
duplicates drop grappe menage, force

tempfile ent_screen_2018
save `ent_screen_2018'


* Step 1b: Load enterprise details to compute enterprise profits
use "$datadir/s10_2_me_sen2018.dta", clear

* -----------------------------------------------------------------------
* COMPUTE MONTHLY ENTERPRISE PROFIT (for the last operating month)
*
* Profit = Total Revenue - Total Costs
*
* Revenue components:
*   s10q46 = Revenue from resale of merchandise
*   s10q48 = Revenue from sale of transformed products
*   s10q50 = Revenue from services rendered
*
* Cost components:
*   s10q47 = Cost of merchandise for resale
*   s10q49 = Cost of raw materials
*   s10q51 = Other intermediate consumption
*   s10q52 = Rent/water/electricity
*   s10q53 = Equipment service fees
*   s10q54 = Other fees and services
* -----------------------------------------------------------------------

foreach var in s10q46 s10q47 s10q48 s10q49 s10q50 s10q51 s10q52 s10q53 s10q54 {
    replace `var' = 0 if `var' == .
}

gen ent_revenue_month = s10q46 + s10q48 + s10q50
gen ent_cost_month    = s10q47 + s10q49 + s10q51 + s10q52 + s10q53 + s10q54
gen ent_profit_month  = ent_revenue_month - ent_cost_month

* Annualize using months of operation (s10q59)
* s10q59 = Number of months enterprise operated in the last 12 months
gen ent_profit_annual = ent_profit_month * s10q59 if s10q59 != .
replace ent_profit_annual = ent_profit_month * 12 if s10q59 == .

* Aggregate to HH level (a household can have multiple enterprises)
collapse (sum) ent_revenue_annual=ent_revenue_month ent_cost_annual=ent_cost_month ///
              ent_profit_annual ///
         (count) n_enterprises=ent_profit_month, ///
         by(grappe menage)

* NOTE: The count gives us the number of enterprises per household
* Revenue and cost are still monthly sums; for now we keep annual profit

tempfile ent_details_2018
save `ent_details_2018'


* --- 2021 Enterprise Data ---

* Step 1c: Load 2021 enterprise screening
use "$datadir/s10a_me_sen2021.dta", clear

* NOTE: 2021 does not have a single filter variable like s10q11
* We construct it from the individual enterprise type questions (s10q02-s10q10)
* Same questions as 2018: food, confection, construction, commerce, liberal
* profession, services, restaurant, rental, other

gen has_enterprise_2021 = 0
foreach var in s10q02 s10q03 s10q04 s10q05 s10q06 s10q07 s10q08 s10q09 s10q10 {
    replace has_enterprise_2021 = 1 if `var' == 1
}

gen ent_food_2021     = (s10q02 == 1) if s10q02 != .
gen ent_commerce_2021 = (s10q05 == 1) if s10q05 != .
gen ent_services_2021 = (s10q07 == 1) if s10q07 != .

keep grappe menage has_enterprise_2021 ent_food_2021 ent_commerce_2021 ent_services_2021
duplicates drop grappe menage, force

tempfile ent_screen_2021
save `ent_screen_2021'


* Step 1d: Load 2021 enterprise details
use "$datadir/s10b_me_sen2021.dta", clear

* Same profit computation as 2018 (variable names are identical in s10b)
foreach var in s10q46 s10q47 s10q48 s10q49 s10q50 s10q51 s10q52 s10q53 s10q54 {
    replace `var' = 0 if `var' == .
}

gen ent_revenue_month = s10q46 + s10q48 + s10q50
gen ent_cost_month    = s10q47 + s10q49 + s10q51 + s10q52 + s10q53 + s10q54
gen ent_profit_month  = ent_revenue_month - ent_cost_month

gen ent_profit_annual = ent_profit_month * s10q59 if s10q59 != .
replace ent_profit_annual = ent_profit_month * 12 if s10q59 == .

collapse (sum) ent_revenue_annual=ent_revenue_month ent_cost_annual=ent_cost_month ///
              ent_profit_annual ///
         (count) n_enterprises=ent_profit_month, ///
         by(grappe menage)

tempfile ent_details_2021
save `ent_details_2021'



********************************************************************************
*                                                                              *
*  PART 2: BUILD SHOCK VARIABLES                                               *
*                                                                              *
*  Source (both years): ehcvm_menage_sen20XX contains pre-constructed shock     *
*  dummies at the HH level. These are binary indicators (0/1) for whether      *
*  the household experienced each type of shock.                               *
*                                                                              *
*  From ehcvm_menage:                                                          *
*    sh_id_demo  = Idiosyncratic demographic shock (death, illness, etc.)     *
*    sh_co_natu  = Covariate natural shock (drought, flood, pests, etc.)      *
*    sh_co_eco   = Covariate economic shock (price increases, etc.)           *
*    sh_id_eco   = Idiosyncratic economic shock (job loss, business failure)  *
*    sh_co_vio   = Covariate violence shock (conflict, insecurity)            *
*    sh_co_oth   = Other shocks                                                *
*                                                                              *
*  For the Jack & Suri framework, we need:                                     *
*    1. An "any negative shock" dummy (analogous to their overall shock)       *
*    2. Specific shock types (analogous to their illness shock analysis)       *
*                                                                              *
*  ADDITIONALLY: Section 14 (s14_me_sen2018 / s14b_me_sen2021) has detailed   *
*  shock-level data including:                                                 *
*    s14q01/s14bq01 = Nature of shock (categorical code)                      *
*    s14q02/s14bq02 = Whether affected in last 3 years                        *
*    s14q04a-f / s14bq04a-f = Consequences on income, assets, production      *
*    s14q05__1-26 / s14bq05__1-26 = Coping strategies adopted                *
*                                                                              *
*  We use the ehcvm_menage pre-built dummies as our main shock measures        *
*  because they are cleaner and already at HH level. Section 14 can be used   *
*  for robustness (e.g., shock severity, coping strategies as mechanisms).    *
*                                                                              *
********************************************************************************

* --- 2018 Shocks ---
use "$datadir/ehcvm_menage_sen2018.dta", clear

* Create overall negative shock dummy (any shock = 1)
* This mirrors Jack & Suri's "overall negative shock" variable
gen neg_shock = 0
replace neg_shock = 1 if sh_id_demo == 1 | sh_co_natu == 1 | sh_co_eco == 1 | ///
                         sh_id_eco == 1 | sh_co_vio == 1 | sh_co_oth == 1

* Rename individual shock types for clarity
rename sh_id_demo shock_demo      // Idiosyncratic demographic (illness, death)
rename sh_co_natu shock_natural   // Covariate natural (drought, flood)
rename sh_co_eco  shock_econ_cov  // Covariate economic (price shocks)
rename sh_id_eco  shock_econ_idio // Idiosyncratic economic (job loss, business)
rename sh_co_vio  shock_violence  // Violence/conflict
rename sh_co_oth  shock_other     // Other

* Keep HH identifiers + shock variables + some asset/dwelling controls
* (ehcvm_menage also has useful asset & dwelling quality vars)
keep grappe menage hhid neg_shock shock_demo shock_natural shock_econ_cov ///
     shock_econ_idio shock_violence shock_other ///
     tv fer frigo cuisin ordin car ///
     superf grosrum petitrum volail ///
     logem mur toit sol eauboi_ss elec_ac toilet

gen year = 2018

tempfile shocks_2018
save `shocks_2018'


* --- 2021 Shocks ---
use "$datadir/ehcvm_menage_sen2021.dta", clear

gen neg_shock = 0
replace neg_shock = 1 if sh_id_demo == 1 | sh_co_natu == 1 | sh_co_eco == 1 | ///
                         sh_id_eco == 1 | sh_co_vio == 1 | sh_co_oth == 1

rename sh_id_demo shock_demo
rename sh_co_natu shock_natural
rename sh_co_eco  shock_econ_cov
rename sh_id_eco  shock_econ_idio
rename sh_co_vio  shock_violence
rename sh_co_oth  shock_other

keep grappe menage hhid neg_shock shock_demo shock_natural shock_econ_cov ///
     shock_econ_idio shock_violence shock_other ///
     tv fer frigo cuisin ordin car ///
     superf grosrum petitrum volail ///
     logem mur toit sol eauboi_ss elec_ac toilet

gen year = 2021

tempfile shocks_2021
save `shocks_2021'



********************************************************************************
*                                                                              *
*  PART 3: BUILD CONSUMPTION VARIABLES                                         *
*                                                                              *
*  Source: ehcvm_welfare_sen20XX                                               *
*                                                                              *
*  Key variables:                                                              *
*    hhid     = Household identifier (string, constructed from grappe+menage)  *
*    grappe   = Cluster number                                                 *
*    menage   = Household number within cluster                                *
*    hhsize   = Household size                                                 *
*    hhweight = Survey weight                                                  *
*    region   = Region of residence                                            *
*    milieu   = Urban/rural                                                    *
*    dali     = Annual food consumption (CFA)                                  *
*    dnal     = Annual non-food consumption (CFA)                              *
*    dtot     = Annual total consumption (CFA) = dali + dnal                   *
*    pcexp    = Per capita consumption (welfare indicator)                      *
*    def_spa  = Spatial deflator (for regional price differences)              *
*    def_temp = Temporal deflator (for inflation between waves)                *
*    zref     = National poverty line                                          *
*                                                                              *
*  NOTE: Following both Jack & Suri and Chaijaroen, we use:                    *
*    - Log per capita total consumption as main dependent variable             *
*    - Log per capita food consumption for food-specific analysis              *
*    - Per capita non-food consumption to test non-food smoothing              *
*                                                                              *
*  HH head characteristics (also in welfare file):                             *
*    hgender  = Gender of HH head                                             *
*    hage     = Age of HH head                                                *
*    heduc    = Education level of HH head                                     *
*    hdiploma = Highest diploma of HH head                                     *
*    hactiv7j = Activity status of HH head (7 days)                           *
*    hbranch  = Branch of activity of HH head                                 *
*    hsectins = Institutional sector of HH head                                *
*                                                                              *
********************************************************************************

* --- 2018 Welfare/Consumption ---
use "$datadir/ehcvm_welfare_sen2018.dta", clear

* Per capita consumption measures
gen pc_total_cons = dtot / hhsize
gen pc_food_cons  = dali / hhsize
gen pc_nfood_cons = dnal / hhsize

* Log consumption (main dependent variables)
gen ln_pc_total = ln(pc_total_cons)
gen ln_pc_food  = ln(pc_food_cons)
gen ln_pc_nfood = ln(pc_nfood_cons) if pc_nfood_cons > 0

* Real consumption (deflated for spatial price differences)
gen real_pc_total = pc_total_cons / def_spa
gen ln_real_pc_total = ln(real_pc_total)

* Poverty indicator
gen poor = (pcexp < zref) if pcexp != . & zref != .

* Wealth quintiles (based on pcexp) — for heterogeneity analysis (Jack & Suri Table 4B)
xtile wealth_q = pcexp, nq(5)

* Keep relevant variables
keep grappe menage hhid vague region milieu zae hhweight hhsize ///
     pc_total_cons pc_food_cons pc_nfood_cons ///
     ln_pc_total ln_pc_food ln_pc_nfood ///
     real_pc_total ln_real_pc_total ///
     pcexp poor wealth_q def_spa def_temp ///
     hgender hage hmstat heduc hdiploma hactiv7j hbranch hsectins ///
     eqadu1

gen year = 2018

tempfile welfare_2018
save `welfare_2018'


* --- 2021 Welfare/Consumption ---
use "$datadir/ehcvm_welfare_sen2021.dta", clear

gen pc_total_cons = dtot / hhsize
gen pc_food_cons  = dali / hhsize
gen pc_nfood_cons = dnal / hhsize

gen ln_pc_total = ln(pc_total_cons)
gen ln_pc_food  = ln(pc_food_cons)
gen ln_pc_nfood = ln(pc_nfood_cons) if pc_nfood_cons > 0

gen real_pc_total = pc_total_cons / def_spa
gen ln_real_pc_total = ln(real_pc_total)

gen poor = (pcexp < zref) if pcexp != . & zref != .

xtile wealth_q = pcexp, nq(5)

keep grappe menage hhid vague region milieu zae hhweight hhsize ///
     pc_total_cons pc_food_cons pc_nfood_cons ///
     ln_pc_total ln_pc_food ln_pc_nfood ///
     real_pc_total ln_real_pc_total ///
     pcexp poor wealth_q def_spa def_temp ///
     hgender hage hmstat heduc hdiploma hactiv7j hbranch hsectins ///
     eqadu1

gen year = 2021

tempfile welfare_2021
save `welfare_2021'



********************************************************************************
*                                                                              *
*  PART 4: BUILD CONTROL VARIABLES                                             *
*                                                                              *
*  Jack & Suri (eq. 9) control for X_it and X_it x Shock_it where X includes: *
*    - HH demographics (size, composition)                                     *
*    - HH head education and occupation                                        *
*    - Use of financial instruments (bank, SACCO, ROSCA)                       *
*    - Cell phone ownership                                                    *
*                                                                              *
*  For our Senegal context, analogous controls from EHCVM include:             *
*    - From ehcvm_welfare: hgender, hage, heduc, hdiploma, hactiv7j, hhsize   *
*    - From ehcvm_menage: asset dummies (tv, frigo, car, etc.)                *
*    - From ehcvm_individu: bank account ownership (variable: bank)           *
*    - From s01_me (demographics): household composition details              *
*                                                                              *
*  NOTE: Most demographic controls are already in the welfare file.            *
*  We supplement with bank access from the individu file.                      *
*                                                                              *
********************************************************************************

* --- 2018 Bank Account / Financial Access ---
* Source: ehcvm_individu_sen2018
* Variable: bank = "compte banque ou autre" (has bank or other account)
* This is at individual level; we want a HH-level indicator

use "$datadir/ehcvm_individu_sen2018.dta", clear

* Create HH-level dummy: at least one member has a bank account
gen has_bank_ind = (bank == 1) if bank != .

collapse (max) has_bank = has_bank_ind, by(grappe menage)

gen year = 2018
tempfile bank_2018
save `bank_2018'


* --- 2021 Bank Account ---
use "$datadir/ehcvm_individu_sen2021.dta", clear

gen has_bank_ind = (bank == 1) if bank != .
collapse (max) has_bank = has_bank_ind, by(grappe menage)

gen year = 2021
tempfile bank_2021
save `bank_2021'



********************************************************************************
*                                                                              *
*  PART 5: MERGE ALL MODULES AND CONSTRUCT PANEL                               *
*                                                                              *
********************************************************************************

* --- Build 2018 cross-section ---
use `welfare_2018', clear

merge 1:1 grappe menage using `shocks_2018', nogen keep(master match)
merge 1:1 grappe menage using `ent_screen_2018', nogen keep(master match)
merge 1:1 grappe menage using `ent_details_2018', nogen keep(master match)
merge 1:1 grappe menage using `bank_2018', nogen keep(master match)

* Fill enterprise vars for HHs with no enterprise
replace has_enterprise_2018 = 0 if has_enterprise_2018 == .
replace n_enterprises = 0 if n_enterprises == .
replace ent_profit_annual = 0 if has_enterprise_2018 == 0

* Harmonize enterprise variable name for panel
gen has_enterprise = has_enterprise_2018
gen ent_food       = ent_food_2018
gen ent_commerce   = ent_commerce_2018
gen ent_services   = ent_services_2018

tempfile panel_2018
save `panel_2018'


* --- Build 2021 cross-section ---
use `welfare_2021', clear

merge 1:1 grappe menage using `shocks_2021', nogen keep(master match)
merge 1:1 grappe menage using `ent_screen_2021', nogen keep(master match)
merge 1:1 grappe menage using `ent_details_2021', nogen keep(master match)
merge 1:1 grappe menage using `bank_2021', nogen keep(master match)

replace has_enterprise_2021 = 0 if has_enterprise_2021 == .
replace n_enterprises = 0 if n_enterprises == .
replace ent_profit_annual = 0 if has_enterprise_2021 == 0

gen has_enterprise = has_enterprise_2021
gen ent_food       = ent_food_2021
gen ent_commerce   = ent_commerce_2021
gen ent_services   = ent_services_2021

tempfile panel_2021
save `panel_2021'


* --- Append into panel ---
use `panel_2018', clear
append using `panel_2021'

* -----------------------------------------------------------------------
* CREATE PANEL IDENTIFIER
* The panel unit is the household identified by (grappe, menage)
* We create a numeric panel ID from these two variables
* -----------------------------------------------------------------------
egen hhpanel = group(grappe menage)

* -----------------------------------------------------------------------
* IDENTIFY PANEL HOUSEHOLDS
* Only households observed in BOTH waves can contribute to the 
* household fixed effects estimation. 
* For the 2021 wave, the variable PanelHH or s00q07d flags panel HHs.
* Here we identify them statistically: observed in both years.
* -----------------------------------------------------------------------
bysort hhpanel: gen n_waves = _N
gen is_panel = (n_waves == 2)

* Report panel balance
tab year is_panel, m
di "Number of panel households: " 
distinct hhpanel if is_panel == 1

* -----------------------------------------------------------------------
* LABEL VARIABLES
* -----------------------------------------------------------------------
label var has_enterprise  "HH owns non-farm enterprise (0/1)"
label var neg_shock       "Any negative shock (0/1)"
label var shock_demo      "Demographic shock (illness, death)"
label var shock_natural   "Natural/weather shock (drought, flood)"
label var shock_econ_cov  "Covariate economic shock (price increase)"
label var shock_econ_idio "Idiosyncratic economic shock (job loss)"
label var shock_violence  "Violence/conflict shock"
label var ln_pc_total     "Log per capita total consumption"
label var ln_pc_food      "Log per capita food consumption"
label var ln_pc_nfood     "Log per capita non-food consumption"
label var ent_profit_annual "Annual enterprise profit (CFA)"
label var n_enterprises   "Number of enterprises owned"
label var has_bank        "HH has bank/financial account (0/1)"
label var is_panel        "Household observed in both waves"

* -----------------------------------------------------------------------
* GENERATE INTERACTION TERMS FOR REGRESSION
* Following Jack & Suri eq. 9: Enterprise x Shock and X_it x Shock
* -----------------------------------------------------------------------

* Main interaction of interest (beta in the model)
gen enterprise_x_shock = has_enterprise * neg_shock
label var enterprise_x_shock "Enterprise x Negative Shock"

* Shock type interactions (for disaggregated analysis)
gen enterprise_x_demo    = has_enterprise * shock_demo
gen enterprise_x_natural = has_enterprise * shock_natural
gen enterprise_x_econcov = has_enterprise * shock_econ_cov
gen enterprise_x_econidio = has_enterprise * shock_econ_idio

* Control x Shock interactions (Jack & Suri's theta_S * X_it * Shock_it)
* These control for other HH characteristics that may independently help 
* with consumption smoothing (e.g., educated HHs may smooth better)
gen shock_x_hhsize   = neg_shock * hhsize
gen shock_x_hage     = neg_shock * hage
gen shock_x_hgender  = neg_shock * hgender
gen shock_x_heduc    = neg_shock * heduc
gen shock_x_bank     = neg_shock * has_bank
gen shock_x_milieu   = neg_shock * milieu
gen shock_x_tv       = neg_shock * tv
gen shock_x_frigo    = neg_shock * frigo

* Enterprise income share (alternative continuous treatment)
* Share of enterprise profit in total consumption
gen ent_share = ent_profit_annual / (pc_total_cons * hhsize) if pc_total_cons > 0
replace ent_share = 0 if has_enterprise == 0
gen ent_share_x_shock = ent_share * neg_shock
label var ent_share "Enterprise profit share of total consumption"

* -----------------------------------------------------------------------
* SAVE ANALYSIS DATASET
* -----------------------------------------------------------------------
sort hhpanel year
save "$outputdir/consumption_smoothing_panel.dta", replace



********************************************************************************
*                                                                              *
*  PART 6: DESCRIPTIVE STATISTICS AND BALANCE                                  *
*                                                                              *
********************************************************************************

use "$outputdir/consumption_smoothing_panel.dta", clear

* --- Table 1: Summary Statistics by Wave (cf. Jack & Suri Table 1A) ---
estpost tabstat has_enterprise n_enterprises neg_shock shock_demo shock_natural ///
    shock_econ_cov shock_econ_idio ///
    pc_total_cons pc_food_cons hhsize hage has_bank ///
    if is_panel == 1, ///
    by(year) stat(mean sd) columns(stat) nototal
esttab using "$outputdir/table1_summary_stats.csv", replace ///
    cells("mean(fmt(3)) sd(fmt(3))") label

* --- Table 2: Shock correlates (cf. Jack & Suri Table 3) ---
* Test whether shocks are correlated with enterprise status and other observables
* Under the identification assumption, shocks should be exogenous
* and NOT correlated with HH characteristics
foreach shock in neg_shock shock_demo shock_natural shock_econ_cov {
    di _n "=== Correlates of `shock' ==="
    reg `shock' has_enterprise has_bank hage hgender heduc hhsize ///
        milieu tv frigo i.year if is_panel == 1, robust cluster(grappe)
}

* --- Table 3: Enterprise HH vs Non-Enterprise HH Comparison ---
* This shows whether enterprise HHs are systematically different
* (important for interpreting results and understanding selection)
foreach var in pc_total_cons pc_food_cons hhsize hage has_bank neg_shock {
    di _n "=== `var' by enterprise status ==="
    ttest `var' if is_panel == 1 & year == 2018, by(has_enterprise)
}



********************************************************************************
*                                                                              *
*  PART 7: MAIN REGRESSION ANALYSIS — CONSUMPTION SMOOTHING                    *
*                                                                              *
*  This is the heart of the analysis, closely following Jack & Suri (2014)     *
*  Tables 4A and 4B. We adapt their specification:                             *
*                                                                              *
*  Equation 9 (adapted):                                                       *
*  ln(c_it) = alpha_i + gamma*Shock + mu*Enterprise                            *
*           + beta*(Enterprise x Shock)                                        *
*           + theta_S*(X x Shock) + theta_M*X                                  *
*           + eta_jt + pi_t + epsilon_it                                       *
*                                                                              *
*  Interpretation (from Jack & Suri p. 200-201):                               *
*    gamma = effect of shock on non-enterprise HHs                             *
*    beta  = DIFFERENTIAL effect for enterprise HHs                            *
*    If gamma < 0 and beta > 0: enterprises help smooth consumption            *
*    If gamma + beta ≈ 0: enterprise HHs are "fully insured"                  *
*    We test H0: gamma + beta = 0 (full insurance for enterprise HHs)         *
*                                                                              *
*  Column structure mirrors Jack & Suri Table 4A:                              *
*    Col 1: OLS, no controls                                                   *
*    Col 2: Panel FE, location x time FE                                       *
*    Col 3: Panel FE + demographic controls                                    *
*    Col 4: Panel FE + full controls + control x shock interactions            *
*    Col 5: Panel FE + full controls + interactions (preferred specification)  *
*                                                                              *
********************************************************************************

use "$outputdir/consumption_smoothing_panel.dta", clear

* Restrict to panel households
keep if is_panel == 1

* Set panel structure
xtset hhpanel year

* -----------------------------------------------------------------------
* TABLE 4A: MAIN RESULTS — TOTAL CONSUMPTION
* -----------------------------------------------------------------------

* Column 1: Pooled OLS, no controls (baseline comparison)
* NOTE: This is comparable to Jack & Suri Table 4A Column 1
reg ln_pc_total neg_shock has_enterprise enterprise_x_shock ///
    i.year [pw=hhweight], cluster(grappe)
estimates store col1_ols

* Compute effects for enterprise and non-enterprise HHs
lincom neg_shock + enterprise_x_shock   // Effect of shock on enterprise HHs
lincom neg_shock                         // Effect of shock on non-enterprise HHs
test neg_shock + enterprise_x_shock = 0  // Test full insurance for enterprise HHs


* Column 2: Panel FE + region x year FE
* NOTE: This adds HH fixed effects (alpha_i) and region-year FE (eta_jt)
* Following Jack & Suri, the HH FE absorbs time-invariant selection into 
* enterprise ownership. Only HHs that change status contribute to beta.
xtreg ln_pc_total neg_shock has_enterprise enterprise_x_shock ///
      i.year##i.region [pw=hhweight], ///
      fe vce(cluster grappe)
estimates store col2_fe


* Column 3: Panel FE + demographic controls
* Jack & Suri note: "most tests of risk sharing control flexibly for 
* the demographic composition of a household (e.g., Townsend 1994)"
xtreg ln_pc_total neg_shock has_enterprise enterprise_x_shock ///
      hhsize hage hgender i.heduc ///
      i.year##i.region [pw=hhweight], ///
      fe vce(cluster grappe)
estimates store col3_fe_demo


* Column 4: Panel FE + full controls + shock interactions
* THIS IS THE PREFERRED SPECIFICATION (Jack & Suri eq. 9)
* Including shock x controls is critical: it ensures that beta captures 
* the enterprise effect specifically, not just wealth/education/financial access
* that happen to correlate with enterprise ownership
xtreg ln_pc_total neg_shock has_enterprise enterprise_x_shock ///
      hhsize hage hgender i.heduc has_bank tv frigo milieu ///
      shock_x_hhsize shock_x_hage shock_x_hgender shock_x_heduc ///
      shock_x_bank shock_x_tv shock_x_frigo shock_x_milieu ///
      i.year##i.region [pw=hhweight], ///
      fe vce(cluster grappe)
estimates store col4_preferred

* Key test: is the effect of shocks on enterprise HHs = 0? (full insurance)
lincom neg_shock + enterprise_x_shock
test neg_shock + enterprise_x_shock = 0

* Effect for non-enterprise HHs (evaluated at mean of controls)
* NOTE: With interactions, gamma alone isn't interpretable at face value
* The shock effect for non-enterprise HHs = gamma + theta_S * mean(X)
* We compute marginal effects below
margins, dydx(neg_shock) at(has_enterprise=0) 
margins, dydx(neg_shock) at(has_enterprise=1)


* Column 5: Same as Col 4 but restricted to bottom 3 wealth quintiles
* Jack & Suri Table 4B Col 5: "We find that the effects are strong for 
* the bottom three quintiles" — richer HHs can smooth shocks regardless
xtreg ln_pc_total neg_shock has_enterprise enterprise_x_shock ///
      hhsize hage hgender i.heduc has_bank tv frigo milieu ///
      shock_x_hhsize shock_x_hage shock_x_hgender shock_x_heduc ///
      shock_x_bank shock_x_tv shock_x_frigo shock_x_milieu ///
      i.year##i.region [pw=hhweight] ///
      if wealth_q <= 3, ///
      fe vce(cluster grappe)
estimates store col5_poor

lincom neg_shock + enterprise_x_shock
test neg_shock + enterprise_x_shock = 0


* --- Export main results table ---
esttab col1_ols col2_fe col3_fe_demo col4_preferred col5_poor ///
    using "$outputdir/table4a_main_results.csv", replace ///
    keep(neg_shock has_enterprise enterprise_x_shock) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2 r2_w, labels("Observations" "R-squared" "Within R-sq")) ///
    mtitles("OLS" "Panel FE" "FE+Demo" "FE+Full (Preferred)" "FE+Poor") ///
    title("Table 4A: Impact of Enterprise Income on Consumption Smoothing") ///
    note("Dep var: Log per capita total consumption. SEs clustered at grappe level.") ///
    label


* -----------------------------------------------------------------------
* TABLE 4B: CONSUMPTION TYPE DISAGGREGATION
* Following Jack & Suri Table 4B Col 3 and Chaijaroen's protein analysis
* -----------------------------------------------------------------------

* Food consumption — Jack & Suri find food is well smoothed by ALL HHs
xtreg ln_pc_food neg_shock has_enterprise enterprise_x_shock ///
      hhsize hage hgender i.heduc has_bank tv frigo milieu ///
      shock_x_hhsize shock_x_hage shock_x_hgender shock_x_heduc ///
      shock_x_bank shock_x_tv shock_x_frigo shock_x_milieu ///
      i.year##i.region [pw=hhweight], ///
      fe vce(cluster grappe)
estimates store food

* Non-food consumption — this is where smoothing failures show up
xtreg ln_pc_nfood neg_shock has_enterprise enterprise_x_shock ///
      hhsize hage hgender i.heduc has_bank tv frigo milieu ///
      shock_x_hhsize shock_x_hage shock_x_hgender shock_x_heduc ///
      shock_x_bank shock_x_tv shock_x_frigo shock_x_milieu ///
      i.year##i.region [pw=hhweight], ///
      fe vce(cluster grappe)
estimates store nonfood

esttab col4_preferred food nonfood ///
    using "$outputdir/table4b_consumption_types.csv", replace ///
    keep(neg_shock has_enterprise enterprise_x_shock) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("Total" "Food" "Non-Food") ///
    title("Table 4B: Consumption Smoothing by Type of Consumption") ///
    label


* -----------------------------------------------------------------------
* TABLE 4C: SHOCK TYPE DISAGGREGATION
* Following Jack & Suri Table 4C (health shocks) and Chaijaroen (natural)
* -----------------------------------------------------------------------

* Natural/weather shocks — enterprise should be especially protective here
* (diversification away from agriculture)
xtreg ln_pc_total shock_natural has_enterprise enterprise_x_natural ///
      hhsize hage hgender i.heduc has_bank ///
      i.year##i.region [pw=hhweight], ///
      fe vce(cluster grappe)
estimates store natural

lincom shock_natural + enterprise_x_natural  // Effect on enterprise HHs
test shock_natural + enterprise_x_natural = 0

* Demographic shocks (illness/death) — cf. Jack & Suri Table 4C
xtreg ln_pc_total shock_demo has_enterprise enterprise_x_demo ///
      hhsize hage hgender i.heduc has_bank ///
      i.year##i.region [pw=hhweight], ///
      fe vce(cluster grappe)
estimates store demo

* Economic covariate shocks (price increases)
xtreg ln_pc_total shock_econ_cov has_enterprise enterprise_x_econcov ///
      hhsize hage hgender i.heduc has_bank ///
      i.year##i.region [pw=hhweight], ///
      fe vce(cluster grappe)
estimates store econcov

* Idiosyncratic economic shocks (job loss, business failure)
xtreg ln_pc_total shock_econ_idio has_enterprise enterprise_x_econidio ///
      hhsize hage hgender i.heduc has_bank ///
      i.year##i.region [pw=hhweight], ///
      fe vce(cluster grappe)
estimates store econidio

esttab natural demo econcov econidio ///
    using "$outputdir/table4c_shock_types.csv", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("Natural" "Demographic" "Econ Covariate" "Econ Idiosyncratic") ///
    title("Table 4C: Consumption Smoothing by Type of Shock") ///
    label



********************************************************************************
*                                                                              *
*  PART 8: HETEROGENEITY ANALYSIS                                             *
*                                                                              *
*  Test whether the smoothing effect varies by:                                *
*    A. Urban vs Rural (milieu)                                                *
*    B. Wealth quintiles (Jack & Suri find effects in bottom 3 quintiles)     *
*    C. Enterprise type (food, commerce, services)                             *
*    D. Continuous enterprise income (intensive margin)                        *
*                                                                              *
********************************************************************************

* --- A. Urban vs Rural ---
* Enterprises may serve different smoothing roles in each context
forvalues m = 1/2 {
    local mlab = cond(`m'==1, "Urban", "Rural")
    di _n "=== `mlab' ==="
    xtreg ln_pc_total neg_shock has_enterprise enterprise_x_shock ///
          hhsize hage hgender i.heduc has_bank ///
          i.year##i.region [pw=hhweight] ///
          if milieu == `m', ///
          fe vce(cluster grappe)
    lincom neg_shock + enterprise_x_shock
}

* --- B. By Wealth Quintile ---
forvalues q = 1/5 {
    di _n "=== Wealth Quintile `q' ==="
    xtreg ln_pc_total neg_shock has_enterprise enterprise_x_shock ///
          hhsize hage hgender i.heduc has_bank ///
          i.year##i.region [pw=hhweight] ///
          if wealth_q == `q', ///
          fe vce(cluster grappe)
    lincom neg_shock + enterprise_x_shock
}

* --- C. By Enterprise Type ---
* Replace the generic enterprise dummy with type-specific dummies
foreach etype in ent_food ent_commerce ent_services {
    gen `etype'_x_shock = `etype' * neg_shock
    
    xtreg ln_pc_total neg_shock `etype' `etype'_x_shock ///
          hhsize hage hgender i.heduc has_bank ///
          i.year##i.region [pw=hhweight], ///
          fe vce(cluster grappe)
    estimates store het_`etype'
    
    lincom neg_shock + `etype'_x_shock
}

* --- D. Continuous Enterprise Income (Intensive Margin) ---
* Does HIGHER enterprise income provide MORE smoothing?
* This uses the enterprise profit share of total consumption
xtreg ln_pc_total neg_shock ent_share ent_share_x_shock ///
      hhsize hage hgender i.heduc has_bank ///
      i.year##i.region [pw=hhweight], ///
      fe vce(cluster grappe)
estimates store intensive



********************************************************************************
*                                                                              *
*  PART 9: ROBUSTNESS CHECKS                                                  *
*                                                                              *
********************************************************************************

* --- R1: Alternative consumption measures ---
* Use real (spatially deflated) consumption instead of nominal
xtreg ln_real_pc_total neg_shock has_enterprise enterprise_x_shock ///
      hhsize hage hgender i.heduc has_bank ///
      i.year##i.region [pw=hhweight], ///
      fe vce(cluster grappe)
estimates store robust_real

* --- R2: Without survey weights ---
* Check sensitivity to weighting
xtreg ln_pc_total neg_shock has_enterprise enterprise_x_shock ///
      hhsize hage hgender i.heduc has_bank ///
      i.year##i.region, ///
      fe vce(cluster grappe)
estimates store robust_nowt

* --- R3: Correlated Random Effects (Mundlak/Chamberlain) ---
* Alternative to FE that allows estimating time-invariant coefficients
* Add within-household means of time-varying variables (Mundlak approach)
foreach var in has_enterprise neg_shock hhsize hage has_bank {
    bysort hhpanel: egen mean_`var' = mean(`var')
}

reg ln_pc_total neg_shock has_enterprise enterprise_x_shock ///
    hhsize hage hgender i.heduc has_bank ///
    mean_has_enterprise mean_neg_shock mean_hhsize mean_hage mean_has_bank ///
    i.year##i.region [pw=hhweight], ///
    cluster(grappe)
estimates store robust_mundlak

* --- R4: Consumption VOLATILITY approach ---
* Instead of testing shock pass-through, directly test whether enterprise
* HHs have lower consumption volatility across waves
* This is a cross-sectional test using the panel dimension
preserve
    bysort hhpanel: gen d_ln_cons = ln_pc_total - ln_pc_total[_n-1] if _n == 2
    keep if year == 2021 & is_panel == 1
    
    * Test: do enterprise HHs have smaller absolute changes in consumption?
    gen abs_d_ln_cons = abs(d_ln_cons)
    
    reg abs_d_ln_cons has_enterprise hhsize hage hgender i.heduc has_bank ///
        i.region milieu [pw=hhweight], ///
        cluster(grappe)
    estimates store robust_volatility
restore

* --- R5: Placebo test using positive/no shocks ---
* Enterprise x no-shock should not predict consumption differently
gen no_shock = (neg_shock == 0)
gen enterprise_x_noshock = has_enterprise * no_shock

xtreg ln_pc_total no_shock has_enterprise enterprise_x_noshock ///
      hhsize hage hgender i.heduc has_bank ///
      i.year##i.region [pw=hhweight], ///
      fe vce(cluster grappe)
estimates store robust_placebo


* --- Export robustness table ---
esttab robust_real robust_nowt robust_mundlak robust_volatility robust_placebo ///
    using "$outputdir/table_robustness.csv", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("Real Cons" "No Weights" "Mundlak" "Volatility" "Placebo") ///
    title("Robustness Checks") ///
    label



********************************************************************************
*                                                                              *
*  OPTIONAL EXTENSION: COPING STRATEGIES AS MECHANISMS                         *
*                                                                              *
*  Section 14 (s14_me_sen2018 / s14b_me_sen2021) records which coping          *
*  strategies HHs adopted after shocks. Analogous to Jack & Suri's            *
*  remittance mechanism analysis (their Table 5A), we can test whether         *
*  enterprise HHs are LESS LIKELY to adopt distress coping strategies.        *
*                                                                              *
*  Key coping strategy dummies (s14q05__X / s14bq05__X):                      *
*    __1  = Used savings                                                       *
*    __2  = Help from family/friends                                           *
*    __6  = Changed consumption habits                                         *
*    __7  = Bought cheaper food                                                *
*    __8  = Active members took extra jobs                                     *
*    __10 = Children under 15 put to work                                      *
*    __11 = Children taken out of school                                       *
*    __13 = Reduced health/education spending                                  *
*    __15 = Sold agricultural assets                                           *
*    __16 = Sold durable goods                                                 *
*    __21 = Sold livestock                                                     *
*    __26 = No strategy adopted                                                *
*                                                                              *
*  You would collapse these to HH level and run the same interaction           *
*  specification with each coping strategy as the dependent variable.          *
*                                                                              *
********************************************************************************

* This section is left as a template — uncomment and adapt as needed
/*
use "$datadir/s14_me_sen2018.dta", clear

* Collapse to HH level (a HH may report multiple shocks)
* Take max of each coping strategy across all reported shocks
collapse (max) s14q05__1 s14q05__2 s14q05__6 s14q05__7 s14q05__8 ///
               s14q05__10 s14q05__13 s14q05__15 s14q05__16 s14q05__21 ///
               s14q05__26, by(grappe menage)

rename s14q05__1  cope_savings
rename s14q05__6  cope_change_cons
rename s14q05__7  cope_cheap_food
rename s14q05__13 cope_reduce_health_edu
rename s14q05__15 cope_sell_agri_assets
rename s14q05__16 cope_sell_durables
rename s14q05__21 cope_sell_livestock
rename s14q05__26 cope_nothing

* Then merge with panel data and run:
* xtreg cope_sell_livestock neg_shock has_enterprise enterprise_x_shock ...
* A negative beta would mean enterprise HHs are LESS likely to sell livestock
* This would be evidence that enterprises provide a buffer mechanism
*/



********************************************************************************
*                                                                              *
*  END OF DO FILE                                                              *
*                                                                              *
*  SUMMARY OF KEY TABLES PRODUCED:                                             *
*                                                                              *
*  table1_summary_stats.csv      — Descriptive statistics by wave              *
*  table4a_main_results.csv      — Main consumption smoothing results          *
*  table4b_consumption_types.csv — By consumption type (food vs non-food)      *
*  table4c_shock_types.csv       — By shock type (natural, demo, economic)     *
*  table_robustness.csv          — Robustness checks                           *
*                                                                              *
*  NEXT STEPS TO CONSIDER:                                                     *
*  1. Merge in Section 14 coping strategies for mechanism analysis             *
*  2. Add COVID-specific shocks from s14a_me_sen2021 (pandemic impacts)       *
*  3. Use agricultural data (s16a) to test enterprise vs farm diversification *
*  4. Construct asset index for alternative wealth measure                      *
*  5. Consider IV strategy using community-level enterprise infrastructure    *
*                                                                              *
********************************************************************************

log close _all

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
*  Equation (adapted from Jack & Suri eq. 9):                                  *
*  ln(c_it) = alpha_i + gamma*Shock_it + mu*Enterprise_it                      *
*           + beta*(Enterprise_it x Shock_it)                                  *
*           + theta_S*(X_it x Shock_it) + theta_M*X_it                         *
*           + eta_jt + pi_t + epsilon_it                                       *
*                                                                              *
*  beta is the coefficient of interest: if positive and offsetting gamma,      *
*  enterprise income enables consumption smoothing.                            *
*                                                                              *
*  Author:  Zaineb Majoka (mzaineb@worldbank.org)                             *
*  Date:    March 2026                                                         *
*                                                                              *
*  INPUT:   ${final}/SEN_panel_2018_2021.dta  (from 04_create_panel.do)        *
*                                                                              *
*  OUTPUT:  ${output}/consumption_smoothing_panel.dta                          *
*           ${output}/table1_summary_stats.csv                                 *
*           ${output}/table4a_main_results.csv                                 *
*           ${output}/table4b_consumption_types.csv                            *
*           ${output}/table4c_shock_types.csv                                  *
*           ${output}/table_robustness.csv                                     *
*                                                                              *
* PROGRAM OUTLINE                                                              *
*   PART 1: Reshape Panel to HH-Level Long Format                             *
*   PART 2: Create Interaction Terms                                           *
*   PART 3: Descriptive Statistics and Balance Tables                          *
*   PART 4: Main Regression Analysis                                           *
*   PART 5: Heterogeneity Analysis                                             *
*   PART 6: Robustness Checks                                                  *
*                                                                              *
********************************************************************************

clear all
set more off
set matsize 10000

* Paths are set by 01_master.do. If running standalone, uncomment below:
* global project "C:\Users\WB461621\OneDrive - WBG\SPJ\West Africa\Regional HH Enterprise Work"
* global data_2018     "${project}/Data/SEN/2018"
* global data_2021     "${project}/Data/SEN/2021"
* global intermediate  "${project}/Data/SEN/Intermediate"
* global output        "${project}/Output/SEN"
* global final         "${project}/Data/SEN/Final"
* global gdpdef_2018 = 167.29
* global gdpdef_2021 = 213.67


********************************************************************************
*                                                                              *
*  PART 1: RESHAPE PANEL TO HH-LEVEL LONG FORMAT                              *
*                                                                              *
*  The panel dataset (04_create_panel.do) is individual-level, wide format.    *
*  For xtreg with HH fixed effects, we need HH-level, long format (one row    *
*  per HH-year). We collapse to HH level and then reshape/append.             *
*                                                                              *
********************************************************************************

use "${final}/SEN_panel_2018_2021.dta", clear

* -----------------------------------------------------------------------
* Step 1a: Build 2018 HH-level cross-section
* -----------------------------------------------------------------------

preserve

    keep if in_2018 == 1

    * Collapse to one row per HH, keeping HH head demographics and HH-level vars
    * For HH head vars: take value where numind == 1 (head)
    * For HH-level vars (same for all members): take first non-missing

    * Tag HH heads
    gen is_head = (numind == 1)

    * Enterprise status at HH level (already exists as hh_has_enterprise_2018)
    * Enterprise type dummies are already at HH level from screening file

    * HH head demographics — take from head row
    foreach v in hgender_2018 hage_2018 hmstat_2018 heduc_2018 hdiploma_2018 ///
        hactiv7j_2018 hbranch_2018 hsectins_2018 {
        capture confirm variable `v'
        if _rc == 0 {
            bysort hhid (is_head): replace `v' = `v'[_N]
        }
    }

    * Collapse: keep one row per household
    * For HH-level variables, take the first value (same for all members)
    collapse (firstnm) grappe menage hh_matched ///
        hh_has_enterprise_2018 ///
        ent_food_2018 ent_confection_2018 ent_construct_2018 ///
        ent_commerce_2018 ent_liberal_2018 ent_services_2018 ///
        ent_restaurant_2018 ent_rental_2018 ent_other_2018 ///
        sh_id_demo_2018 sh_co_natu_2018 sh_co_eco_2018 ///
        sh_id_eco_2018 sh_co_vio_2018 sh_co_oth_2018 neg_shock_2018 ///
        pc_total_cons_2018 pc_food_cons_2018 pc_nfood_cons_2018 ///
        ln_pc_total_2018 ln_pc_food_2018 ln_pc_nfood_2018 ///
        real_pc_total_2018 ln_real_pc_total_2018 ///
        pcexp_2018 poor_2018 welfare_quintile_2018 ///
        def_spa_2018 zref_2018 ///
        hhweight_2018 hhsize_2018 eqadu1_2018 eqadu2_2018 ///
        region_2018 milieu_2018 zae_2018 ///
        hgender_2018 hage_2018 hmstat_2018 heduc_2018 hdiploma_2018 ///
        hactiv7j_2018 hbranch_2018 hsectins_2018 ///
        has_bank_2018 location_2018 sector_2018 ///
        tv_2018 fer_2018 frigo_2018 cuisin_2018 ordin_2018 car_2018 ///
        superf_2018 grosrum_2018 petitrum_2018 volail_2018 ///
        logem_2018 mur_2018 toit_2018 sol_2018 ///
        eauboi_ss_2018 has_electricity_2018 toilet_2018 ///
        dtot_2018 dali_2018 dnal_2018, ///
        by(hhid)

    * Rename to remove year suffix (will add year variable instead)
    foreach v in hh_has_enterprise ///
        ent_food ent_confection ent_construct ent_commerce ///
        ent_liberal ent_services ent_restaurant ent_rental ent_other ///
        sh_id_demo sh_co_natu sh_co_eco sh_id_eco sh_co_vio sh_co_oth neg_shock ///
        pc_total_cons pc_food_cons pc_nfood_cons ///
        ln_pc_total ln_pc_food ln_pc_nfood ///
        real_pc_total ln_real_pc_total ///
        pcexp poor welfare_quintile def_spa zref ///
        hhweight hhsize eqadu1 eqadu2 region milieu zae ///
        hgender hage hmstat heduc hdiploma hactiv7j hbranch hsectins ///
        has_bank location sector ///
        tv fer frigo cuisin ordin car ///
        superf grosrum petitrum volail ///
        logem mur toit sol eauboi_ss has_electricity toilet ///
        dtot dali dnal {
        capture rename `v'_2018 `v'
    }

    rename hh_has_enterprise has_enterprise
    gen year = 2018

    tempfile hh_2018
    save `hh_2018'

restore


* -----------------------------------------------------------------------
* Step 1b: Build 2021 HH-level cross-section
* -----------------------------------------------------------------------

preserve

    keep if in_2021 == 1

    gen is_head = (numind == 1)

    foreach v in hgender_2021 hage_2021 hmstat_2021 heduc_2021 hdiploma_2021 ///
        hactiv7j_2021 hbranch_2021 hsectins_2021 {
        capture confirm variable `v'
        if _rc == 0 {
            bysort hhid (is_head): replace `v' = `v'[_N]
        }
    }

    collapse (firstnm) grappe menage hh_matched ///
        hh_has_enterprise_2021 ///
        ent_food_2021 ent_confection_2021 ent_construct_2021 ///
        ent_commerce_2021 ent_liberal_2021 ent_services_2021 ///
        ent_restaurant_2021 ent_rental_2021 ent_other_2021 ///
        sh_id_demo_2021 sh_co_natu_2021 sh_co_eco_2021 ///
        sh_id_eco_2021 sh_co_vio_2021 sh_co_oth_2021 neg_shock_2021 ///
        pc_total_cons_2021 pc_food_cons_2021 pc_nfood_cons_2021 ///
        ln_pc_total_2021 ln_pc_food_2021 ln_pc_nfood_2021 ///
        real_pc_total_2021 ln_real_pc_total_2021 ///
        pcexp_2021 poor_2021 welfare_quintile_2021 ///
        def_spa_2021 zref_2021 ///
        hhweight_2021 hhsize_2021 eqadu1_2021 eqadu2_2021 ///
        region_2021 milieu_2021 zae_2021 ///
        hgender_2021 hage_2021 hmstat_2021 heduc_2021 hdiploma_2021 ///
        hactiv7j_2021 hbranch_2021 hsectins_2021 ///
        has_bank_2021 location_2021 sector_2021 ///
        tv_2021 fer_2021 frigo_2021 cuisin_2021 ordin_2021 car_2021 ///
        superf_2021 grosrum_2021 petitrum_2021 volail_2021 ///
        logem_2021 mur_2021 toit_2021 sol_2021 ///
        eauboi_ss_2021 has_electricity_2021 toilet_2021 ///
        dtot_2021 dali_2021 dnal_2021, ///
        by(hhid)

    foreach v in hh_has_enterprise ///
        ent_food ent_confection ent_construct ent_commerce ///
        ent_liberal ent_services ent_restaurant ent_rental ent_other ///
        sh_id_demo sh_co_natu sh_co_eco sh_id_eco sh_co_vio sh_co_oth neg_shock ///
        pc_total_cons pc_food_cons pc_nfood_cons ///
        ln_pc_total ln_pc_food ln_pc_nfood ///
        real_pc_total ln_real_pc_total ///
        pcexp poor welfare_quintile def_spa zref ///
        hhweight hhsize eqadu1 eqadu2 region milieu zae ///
        hgender hage hmstat heduc hdiploma hactiv7j hbranch hsectins ///
        has_bank location sector ///
        tv fer frigo cuisin ordin car ///
        superf grosrum petitrum volail ///
        logem mur toit sol eauboi_ss has_electricity toilet ///
        dtot dali dnal {
        capture rename `v'_2021 `v'
    }

    rename hh_has_enterprise has_enterprise
    gen year = 2021

    tempfile hh_2021
    save `hh_2021'

restore


* -----------------------------------------------------------------------
* Step 1c: Append into HH-level long panel
* -----------------------------------------------------------------------

use `hh_2018', clear
append using `hh_2021'

* Create panel identifier
egen hhpanel = group(grappe menage)

* Identify panel households (observed in both waves)
bysort hhpanel: gen n_waves = _N
gen is_panel = (n_waves == 2)

* Report panel balance
tab year is_panel, m
di "Number of panel households: "
distinct hhpanel if is_panel == 1

* Create time-invariant weight using 2018 (baseline) value
* xtreg, fe requires weights to be constant within panel unit
bysort hhpanel (year): gen hhweight_base = hhweight[1]
label var hhweight_base "HH weight (baseline 2018, time-invariant)"

* Rename shock variables for clarity
rename sh_id_demo shock_demo
rename sh_co_natu shock_natural
rename sh_co_eco  shock_econ_cov
rename sh_id_eco  shock_econ_idio
rename sh_co_vio  shock_violence
rename sh_co_oth  shock_other


* -----------------------------------------------------------------------
* Labels
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
capture label var ln_pc_nfood "Log per capita non-food consumption"
label var has_bank        "HH has bank/financial account (0/1)"
label var is_panel        "Household observed in both waves"


********************************************************************************
*                                                                              *
*  PART 2: CREATE INTERACTION TERMS                                            *
*                                                                              *
*  Following Jack & Suri eq. 9: Enterprise x Shock and X_it x Shock           *
*                                                                              *
********************************************************************************

* Main interaction of interest (beta in the model)
gen enterprise_x_shock = has_enterprise * neg_shock
label var enterprise_x_shock "Enterprise x Negative Shock"

* Shock type interactions (for disaggregated analysis)
gen enterprise_x_demo    = has_enterprise * shock_demo
gen enterprise_x_natural = has_enterprise * shock_natural
gen enterprise_x_econcov = has_enterprise * shock_econ_cov
gen enterprise_x_econidio = has_enterprise * shock_econ_idio

* Control x Shock interactions (Jack & Suri's theta_S * X_it * Shock_it)
gen shock_x_hhsize   = neg_shock * hhsize
gen shock_x_hage     = neg_shock * hage
gen shock_x_hgender  = neg_shock * hgender
gen shock_x_heduc    = neg_shock * heduc
gen shock_x_bank     = neg_shock * has_bank
gen shock_x_milieu   = neg_shock * milieu
gen shock_x_tv       = neg_shock * tv
gen shock_x_frigo    = neg_shock * frigo

* Enterprise type interactions (all 9 types)
foreach etype in ent_food ent_confection ent_construct ent_commerce ///
    ent_liberal ent_services ent_restaurant ent_rental ent_other {
    gen `etype'_x_shock = `etype' * neg_shock
}

* Enterprise income share (alternative continuous treatment)
* Share of enterprise profit in total consumption
* Use HH-level profit from the panel data if available; otherwise skip
capture confirm variable ent_profit_annual
if _rc == 0 {
    gen ent_share = ent_profit_annual / (pc_total_cons * eqadu2) if pc_total_cons > 0
    replace ent_share = 0 if has_enterprise == 0
    gen ent_share_x_shock = ent_share * neg_shock
    label var ent_share "Enterprise profit share of total consumption"
}


* -----------------------------------------------------------------------
* SAVE ANALYSIS DATASET
* -----------------------------------------------------------------------
sort hhpanel year
save "${output}/consumption_smoothing_panel.dta", replace



********************************************************************************
*                                                                              *
*  PART 3: DESCRIPTIVE STATISTICS AND BALANCE                                  *
*                                                                              *
********************************************************************************

use "${output}/consumption_smoothing_panel.dta", clear

* --- Table 1: Summary Statistics by Wave (cf. Jack & Suri Table 1A) ---
estpost tabstat has_enterprise neg_shock shock_demo shock_natural ///
    shock_econ_cov shock_econ_idio ///
    pc_total_cons pc_food_cons hhsize hage has_bank ///
    if is_panel == 1, ///
    by(year) stat(mean sd) columns(stat) nototal
esttab using "${output}/table1_summary_stats.csv", replace ///
    cells("mean(fmt(3)) sd(fmt(3))") label

* --- Table 2: Shock correlates (cf. Jack & Suri Table 3) ---
* Test whether shocks are correlated with enterprise status and other observables
foreach shock in neg_shock shock_demo shock_natural shock_econ_cov {
    di _n "=== Correlates of `shock' ==="
    reg `shock' has_enterprise has_bank hage hgender heduc hhsize ///
        milieu tv frigo i.year if is_panel == 1, robust cluster(grappe)
}

* --- Table 3: Enterprise HH vs Non-Enterprise HH Comparison ---
foreach var in pc_total_cons pc_food_cons hhsize hage has_bank neg_shock {
    di _n "=== `var' by enterprise status ==="
    ttest `var' if is_panel == 1 & year == 2018, by(has_enterprise)
}



********************************************************************************
*                                                                              *
*  PART 4: MAIN REGRESSION ANALYSIS -- CONSUMPTION SMOOTHING                   *
*                                                                              *
*  Adapted from Jack & Suri (2014) Tables 4A and 4B.                          *
*                                                                              *
*  Column structure:                                                           *
*    Col 1: OLS, no controls                                                   *
*    Col 2: Panel FE, location x time FE                                       *
*    Col 3: Panel FE + demographic controls                                    *
*    Col 4: Panel FE + full controls + control x shock interactions            *
*    Col 5: Panel FE + full controls (bottom 3 quintiles only)                 *
*                                                                              *
********************************************************************************

use "${output}/consumption_smoothing_panel.dta", clear

* Restrict to panel households
keep if is_panel == 1

* Set panel structure
xtset hhpanel year

* -----------------------------------------------------------------------
* TABLE 4A: MAIN RESULTS -- TOTAL CONSUMPTION
* -----------------------------------------------------------------------

* Column 1: Pooled OLS, no controls
reg ln_pc_total neg_shock has_enterprise enterprise_x_shock ///
    i.year [pw=hhweight_base], cluster(grappe)
estimates store col1_ols

lincom neg_shock + enterprise_x_shock
lincom neg_shock
test neg_shock + enterprise_x_shock = 0


* Column 2: Panel FE + region x year FE
xtreg ln_pc_total neg_shock has_enterprise enterprise_x_shock ///
      i.year##i.region [pw=hhweight_base], ///
      fe vce(cluster grappe)
estimates store col2_fe


* Column 3: Panel FE + demographic controls
xtreg ln_pc_total neg_shock has_enterprise enterprise_x_shock ///
      hhsize hage hgender i.heduc ///
      i.year##i.region [pw=hhweight_base], ///
      fe vce(cluster grappe)
estimates store col3_fe_demo


* Column 4: Panel FE + full controls + shock interactions (PREFERRED)
xtreg ln_pc_total neg_shock has_enterprise enterprise_x_shock ///
      hhsize hage hgender i.heduc has_bank tv frigo milieu ///
      shock_x_hhsize shock_x_hage shock_x_hgender shock_x_heduc ///
      shock_x_bank shock_x_tv shock_x_frigo shock_x_milieu ///
      i.year##i.region [pw=hhweight_base], ///
      fe vce(cluster grappe)
estimates store col4_preferred

lincom neg_shock + enterprise_x_shock
test neg_shock + enterprise_x_shock = 0

margins, dydx(neg_shock) at(has_enterprise=0)
margins, dydx(neg_shock) at(has_enterprise=1)


* Column 5: Bottom 3 wealth quintiles (cf. Jack & Suri Table 4B Col 5)
xtreg ln_pc_total neg_shock has_enterprise enterprise_x_shock ///
      hhsize hage hgender i.heduc has_bank tv frigo milieu ///
      shock_x_hhsize shock_x_hage shock_x_hgender shock_x_heduc ///
      shock_x_bank shock_x_tv shock_x_frigo shock_x_milieu ///
      i.year##i.region [pw=hhweight_base] ///
      if welfare_quintile <= 3, ///
      fe vce(cluster grappe)
estimates store col5_poor

lincom neg_shock + enterprise_x_shock
test neg_shock + enterprise_x_shock = 0


* --- Export main results table ---
esttab col1_ols col2_fe col3_fe_demo col4_preferred col5_poor ///
    using "${output}/table4a_main_results.csv", replace ///
    keep(neg_shock has_enterprise enterprise_x_shock) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2 r2_w, labels("Observations" "R-squared" "Within R-sq")) ///
    mtitles("OLS" "Panel FE" "FE+Demo" "FE+Full (Preferred)" "FE+Poor") ///
    title("Table 4A: Impact of Enterprise Income on Consumption Smoothing") ///
    note("Dep var: Log per capita total consumption (adult equivalent). SEs clustered at grappe level.") ///
    label


* -----------------------------------------------------------------------
* TABLE 4B: CONSUMPTION TYPE DISAGGREGATION
* -----------------------------------------------------------------------

* Food consumption
xtreg ln_pc_food neg_shock has_enterprise enterprise_x_shock ///
      hhsize hage hgender i.heduc has_bank tv frigo milieu ///
      shock_x_hhsize shock_x_hage shock_x_hgender shock_x_heduc ///
      shock_x_bank shock_x_tv shock_x_frigo shock_x_milieu ///
      i.year##i.region [pw=hhweight_base], ///
      fe vce(cluster grappe)
estimates store food

* Non-food consumption
xtreg ln_pc_nfood neg_shock has_enterprise enterprise_x_shock ///
      hhsize hage hgender i.heduc has_bank tv frigo milieu ///
      shock_x_hhsize shock_x_hage shock_x_hgender shock_x_heduc ///
      shock_x_bank shock_x_tv shock_x_frigo shock_x_milieu ///
      i.year##i.region [pw=hhweight_base], ///
      fe vce(cluster grappe)
estimates store nonfood

esttab col4_preferred food nonfood ///
    using "${output}/table4b_consumption_types.csv", replace ///
    keep(neg_shock has_enterprise enterprise_x_shock) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("Total" "Food" "Non-Food") ///
    title("Table 4B: Consumption Smoothing by Type of Consumption") ///
    label


* -----------------------------------------------------------------------
* TABLE 4C: SHOCK TYPE DISAGGREGATION
* -----------------------------------------------------------------------

* Natural/weather shocks
xtreg ln_pc_total shock_natural has_enterprise enterprise_x_natural ///
      hhsize hage hgender i.heduc has_bank ///
      i.year##i.region [pw=hhweight_base], ///
      fe vce(cluster grappe)
estimates store natural

lincom shock_natural + enterprise_x_natural
test shock_natural + enterprise_x_natural = 0

* Demographic shocks (illness/death)
xtreg ln_pc_total shock_demo has_enterprise enterprise_x_demo ///
      hhsize hage hgender i.heduc has_bank ///
      i.year##i.region [pw=hhweight_base], ///
      fe vce(cluster grappe)
estimates store demo

* Economic covariate shocks (price increases)
xtreg ln_pc_total shock_econ_cov has_enterprise enterprise_x_econcov ///
      hhsize hage hgender i.heduc has_bank ///
      i.year##i.region [pw=hhweight_base], ///
      fe vce(cluster grappe)
estimates store econcov

* Idiosyncratic economic shocks (job loss, business failure)
xtreg ln_pc_total shock_econ_idio has_enterprise enterprise_x_econidio ///
      hhsize hage hgender i.heduc has_bank ///
      i.year##i.region [pw=hhweight_base], ///
      fe vce(cluster grappe)
estimates store econidio

esttab natural demo econcov econidio ///
    using "${output}/table4c_shock_types.csv", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("Natural" "Demographic" "Econ Covariate" "Econ Idiosyncratic") ///
    title("Table 4C: Consumption Smoothing by Type of Shock") ///
    label



********************************************************************************
*                                                                              *
*  PART 5: HETEROGENEITY ANALYSIS                                             *
*                                                                              *
*  A. Urban vs Rural                                                           *
*  B. Wealth quintiles                                                         *
*  C. Enterprise type (all 9 categories)                                       *
*  D. Continuous enterprise income (intensive margin)                          *
*                                                                              *
********************************************************************************

* --- A. Urban vs Rural ---
forvalues m = 1/2 {
    local mlab = cond(`m'==1, "Urban", "Rural")
    di _n "=== `mlab' ==="
    xtreg ln_pc_total neg_shock has_enterprise enterprise_x_shock ///
          hhsize hage hgender i.heduc has_bank ///
          i.year##i.region [pw=hhweight_base] ///
          if milieu == `m', ///
          fe vce(cluster grappe)
    lincom neg_shock + enterprise_x_shock
}

* --- B. By Wealth Quintile ---
forvalues q = 1/5 {
    di _n "=== Wealth Quintile `q' ==="
    xtreg ln_pc_total neg_shock has_enterprise enterprise_x_shock ///
          hhsize hage hgender i.heduc has_bank ///
          i.year##i.region [pw=hhweight_base] ///
          if welfare_quintile == `q', ///
          fe vce(cluster grappe)
    lincom neg_shock + enterprise_x_shock
}

* --- C. By Enterprise Type (all 9 categories) ---
* Each type-specific dummy interacted with shock separately
foreach etype in ent_food ent_confection ent_construct ent_commerce ///
    ent_liberal ent_services ent_restaurant ent_rental ent_other {
    di _n "=== Enterprise type: `etype' ==="
    xtreg ln_pc_total neg_shock `etype' `etype'_x_shock ///
          hhsize hage hgender i.heduc has_bank ///
          i.year##i.region [pw=hhweight_base], ///
          fe vce(cluster grappe)
    estimates store het_`etype'

    lincom neg_shock + `etype'_x_shock
}

* Additional specification: all enterprise type dummies together
xtreg ln_pc_total neg_shock ///
      ent_food ent_confection ent_construct ent_commerce ///
      ent_liberal ent_services ent_restaurant ent_rental ent_other ///
      ent_food_x_shock ent_confection_x_shock ent_construct_x_shock ///
      ent_commerce_x_shock ent_liberal_x_shock ent_services_x_shock ///
      ent_restaurant_x_shock ent_rental_x_shock ent_other_x_shock ///
      hhsize hage hgender i.heduc has_bank ///
      i.year##i.region [pw=hhweight_base], ///
      fe vce(cluster grappe)
estimates store het_all_types

* --- D. Continuous Enterprise Income (Intensive Margin) ---
capture confirm variable ent_share
if _rc == 0 {
    xtreg ln_pc_total neg_shock ent_share ent_share_x_shock ///
          hhsize hage hgender i.heduc has_bank ///
          i.year##i.region [pw=hhweight_base], ///
          fe vce(cluster grappe)
    estimates store intensive
}



********************************************************************************
*                                                                              *
*  PART 6: ROBUSTNESS CHECKS                                                  *
*                                                                              *
********************************************************************************

* --- R1: Alternative consumption measures ---
* Use real (spatially deflated) consumption
xtreg ln_real_pc_total neg_shock has_enterprise enterprise_x_shock ///
      hhsize hage hgender i.heduc has_bank ///
      i.year##i.region [pw=hhweight_base], ///
      fe vce(cluster grappe)
estimates store robust_real

* --- R2: Without survey weights ---
xtreg ln_pc_total neg_shock has_enterprise enterprise_x_shock ///
      hhsize hage hgender i.heduc has_bank ///
      i.year##i.region, ///
      fe vce(cluster grappe)
estimates store robust_nowt

* --- R3: Correlated Random Effects (Mundlak/Chamberlain) ---
foreach var in has_enterprise neg_shock hhsize hage has_bank {
    bysort hhpanel: egen mean_`var' = mean(`var')
}

reg ln_pc_total neg_shock has_enterprise enterprise_x_shock ///
    hhsize hage hgender i.heduc has_bank ///
    mean_has_enterprise mean_neg_shock mean_hhsize mean_hage mean_has_bank ///
    i.year##i.region [pw=hhweight_base], ///
    cluster(grappe)
estimates store robust_mundlak

* --- R4: Consumption VOLATILITY approach ---
preserve
    bysort hhpanel (year): gen d_ln_cons = ln_pc_total - ln_pc_total[_n-1] if _n == 2
    keep if year == 2021 & is_panel == 1

    gen abs_d_ln_cons = abs(d_ln_cons)

    reg abs_d_ln_cons has_enterprise hhsize hage hgender i.heduc has_bank ///
        i.region milieu [pw=hhweight_base], ///
        cluster(grappe)
    estimates store robust_volatility
restore

* --- R5: Placebo test ---
gen no_shock = (neg_shock == 0)
gen enterprise_x_noshock = has_enterprise * no_shock

xtreg ln_pc_total no_shock has_enterprise enterprise_x_noshock ///
      hhsize hage hgender i.heduc has_bank ///
      i.year##i.region [pw=hhweight_base], ///
      fe vce(cluster grappe)
estimates store robust_placebo


* --- Export robustness table ---
esttab robust_real robust_nowt robust_mundlak robust_volatility robust_placebo ///
    using "${output}/table_robustness.csv", replace ///
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
*  Uncomment and adapt as needed.                                              *
*                                                                              *
********************************************************************************


********************************************************************************
*                                                                              *
*  END OF DO FILE                                                              *
*                                                                              *
*  SUMMARY OF KEY TABLES PRODUCED:                                             *
*                                                                              *
*  table1_summary_stats.csv      -- Descriptive statistics by wave             *
*  table4a_main_results.csv      -- Main consumption smoothing results         *
*  table4b_consumption_types.csv -- By consumption type (food vs non-food)     *
*  table4c_shock_types.csv       -- By shock type (natural, demo, economic)    *
*  table_robustness.csv          -- Robustness checks                          *
*                                                                              *
********************************************************************************

log close _all

********************************************************************************
*                                                                              *
*  LABOR MARKET TRANSITIONS: AGRICULTURE, HH ENTERPRISE, WAGE WORK,           *
*  NOT WORKING                                                                *
*  EHCVM Senegal Panel (2018/19 - 2021/22)                                    *
*                                                                              *
*  MOTIVATION: We restrict the labor market to four mutually exclusive        *
*  categories (agriculture, non-farm HH enterprise, non-farm wage work,       *
*  not working) and examine transitions between them across the two panel     *
*  waves. Two guiding questions:                                              *
*    (1) Which is the more stable form of employment - non-farm wage work     *
*        or non-farm HH enterprise (self-employment)?                        *
*    (2) For those who transition into/out of these categories, what         *
*        factors are pushing/pulling them - earnings, or other factors       *
*        (assets, infrastructure, shocks, demographics)?                     *
*                                                                              *
*  Author:  Zaineb Majoka (mzaineb@worldbank.org)                             *
*  Date Editted:    June 26 2026                                              *
*                                                                              *
********************************************************************************

clear all
set more off
set matsize 10000


********************************************************************************
* PART 0: SET PATHS
********************************************************************************

global project "C:\Users\WB461621\OneDrive - WBG\SPJ\West Africa\Regional HH Enterprise Work"
global final    "${project}/Data/SEN/Final"
global output   "${project}/Output/SEN"
global intermediate  "${project}/Data/SEN/Intermediate"

capture mkdir "${output}"

log using "${output}/SEN_transitions_log.txt", text replace


********************************************************************************
*                                                                              *
*  PART 1: LOAD PANEL AND DEFINE ANALYTIC SAMPLE                              *
*                                                                              *
*  Starting from the individual-level panel produced by 04_create_panel.do.   *
*  The transition analysis requires individuals classified on work_activity   *
*  in BOTH waves, so the analytic sample is the subset of matched            *
*  individuals with non-missing work_activity in 2018 and 2021.              *
*                                                                              *
********************************************************************************

use "${final}/SEN_panel_2018_2021.dta", clear

* ----- Remittances recode: missing->0 (flag-if-yes variable upstream) -----
* Must run immediately after load, BEFORE any income checks or trim flags,
* so the variable is clean for the full file. Confirmed 42,237 changes.
* See Part 4.2 for diagnostic history.
recode hh_received_remittances_2018 (. = 0)
label variable hh_received_remittances_2018 "Household received remittances, 2018 (recoded: missing->0)"


* ----- Define the analytic (panel) sample -----
* creating a sample of individuals in both waves and also have work activity
* status in both waves.
* DECISION (confirmed): restrict to VALIDATED matches only (ind_validated==1),
* not just ind_matched==1, to avoid contaminating transitions with mismatched
* individuals. This is the 18,213 figure, not the 22,211 figure.

gen byte sample_trans = (ind_matched == 1) & (ind_validated == 1) & ///
    !missing(work_activity_2018) & !missing(work_activity_2021)
label variable sample_trans "Analytic sample: matched + validated + classified in both waves"

count
local N_total = r(N)

count if ind_matched == 1
local N_matched = r(N)

count if ind_matched == 1 & !missing(work_activity_2018) & !missing(work_activity_2021)
local N_classified = r(N)

count if sample_trans == 1
local N_analytic = r(N)

di as result "Total individual-obs in panel file:              `N_total'"
di as result "Matched in both waves (ind_matched==1):           `N_matched'"
di as result "+ classified on work_activity in both waves:      `N_classified'"
di as result "+ also passes gender/age validation check:        `N_analytic'"

*N_classified is 22,211 and N_analytic (validated) is 18,213

tab sample_trans, missing

* ----- Quick unweighted sanity-check cross-tab (full weighted version in Part 2) -----

tab work_activity_2018 work_activity_2021 if sample_trans == 1, missing

/* ----- Restrict working dataset to the analytic sample for all subsequent parts -----
keep if sample_trans == 1

di as result _n "Analytic sample for transition analysis: `=_N' individuals"
*/

********************************************************************************
*                                                                              *
*  PART 2: INCOME / WAGE DATA QUALITY CHECKS                                  *
*                                                                              *
*  Using monthly_income variable. It uses salary + bonus for wage workers
*  And profits for entrepreneurs (employers + own account workers).                   *
*  
*	We will check for missing values but we will also mark paid/unpaid workers
*	within each category of activity 			type                                                                             *
*

*	TWO STRUCTURAL GAPS TO QUANTIFY BELOW (not data errors - built in by       *
*  the construction logic above):                                            *
*    (a) Unpaid family workers (s04q39==8 / emp_type==4) are bucketed into    *
*        work_activity == "HH enterprise (non-ag)" but never get an income   *
*        value - the enterprise's profit isn't attributed to them.           *
*    (b) profit comes entirely from Section 10 (non-ag enterprise) data, so  *
*        self-employed/family-worker farmers - most of "Agriculture" - will  *
*        have missing income regardless of response quality. Only           *
*        agricultural WAGE laborers (s04q39 1-7) get a value.                *
*                                                                              *
*  monthly_income_real_YYYY = monthly_income_YYYY deflated to 2018 FCFA      *
*  (GDP-deflated in 04_create_panel.do, Part 7.1b).                          *
*                                                                              *
********************************************************************************

*------------------------------------------------------------------------------
* 2.1: Coverage - is monthly_income_real missing, by category and by emp_type
*------------------------------------------------------------------------------
gen byte miss_inc18 = missing(monthly_income_real_2018)
gen byte miss_inc21 = missing(monthly_income_real_2021)

di as text _n "2018:"
tab work_activity_2018 miss_inc18, row nofreq
di as text _n "2021:"
tab work_activity_2021 miss_inc21, row nofreq


tab emp_type_2018 miss_inc18 if work_activity_2018 == 2, row nofreq
tab emp_type_2021 miss_inc21 if work_activity_2021 == 2, row nofreq

* ----- Export: income missingness by category (headline result) -----
tabout work_activity_2018 miss_inc18 using "$output\Part2_IncomeChecks.xls", replace ///
    c(freq row) format(0c 1p) layout(cb) style(xls) h1("Income missingness by category, 2018")
tabout work_activity_2021 miss_inc21 using "$output\Part2_IncomeChecks.xls", append ///
    c(freq row) format(0c 1p) layout(cb) style(xls) h1("Income missingness by category, 2021")
	
	


/*Notes based on the above summ stats

Agri income coverage is very thin: 86% missing in 2018 and 90% missing in 2021
It's mainly because we are not calculating "profits" for ag businesses/farms

We are lumping unpaid interns and apprentices with wage workers.
Fixed below (2.1b) - now tagged and excluded as unpaid, same as family workers.

HH enterprise's ~22% missingness is NOT mainly unpaid family workers (they're
only ~4% of the category) - it's genuine non-response among own-account
workers/employers themselves (~18% missing profit even though they should
have it). Worth a closer look at some point, separate from the unpaid fix.

*/

*------------------------------------------------------------------------------
* 2.1b: Share of UNPAID workers, by category
*       Two sources of "structurally unpaid", confirmed from data checks:
*       (i)  emp_type==4: unpaid family worker (HH enterprise / Agriculture)
*       (ii) s04q39==7:   unpaid intern/apprentice (Wage worker / Agriculture)
*       Both get bucketed into a paid-looking category but can never have an
*       income value - confirmed 56-57% of Wage worker's missing salary in
*       both waves is exactly this apprentice group, not genuine non-response.
*------------------------------------------------------------------------------

gen byte unpaid_2018 = (emp_type_2018 == 4) | (s04q39_2018 == 7)
gen byte unpaid_2021 = (emp_type_2021 == 4) | (s04q39_2021 == 7)


tab work_activity_2018 unpaid_2018 if ind_validated == 1 [aweight=hhweight_2018], row nofreq

tab work_activity_2021 unpaid_2021 if ind_validated == 1 [aweight=hhweight_2021], row nofreq

* ----- Export: share of unpaid workers by category (headline result) -----
tabout work_activity_2018 unpaid_2018 if ind_validated==1 [iweight=hhweight_2018] ///
    using "$output\Part2_IncomeChecks.xls", append c(freq row) format(0c 1p) layout(cb) style(xls) ///
    h1("Share unpaid workers (emp_type==4 or s04q39==7), by category, 2018")
tabout work_activity_2021 unpaid_2021 if ind_validated==1 [iweight=hhweight_2021] ///
    using "$output\Part2_IncomeChecks.xls", append c(freq row) format(0c 1p) layout(cb) style(xls) ///
    h1("Share unpaid workers, by category, 2021")

* Share unpaid AND missing income within each category
gen unpaid_missing_2018 = (unpaid_2018==1 & missing(monthly_income_real_2018))
tab work_activity_2018 unpaid_missing_2018, row nofreq

gen byte unpaid_missing_2021 = (unpaid_2021==1 & missing(monthly_income_real_2021))
tab work_activity_2021 unpaid_missing_2021, row nofreq


*------------------------------------------------------------------------------
* 2.2: Distributional checks - PAID WORKERS ONLY, VALIDATED SAMPLE
*       Excludes unpaid family workers, who have no individual income by
*       construction (see 2.1 above - this would otherwise just show up as
*       more missingness rather than a meaningful zero/low income).
*       Agriculture is included in the by-group, but check N first - the
*       paid (mostly hired ag-labor) subset of Agriculture may be small,
*       since self-employed farmers' profit isn't captured at all (Part 2
*       header note (b)).
*------------------------------------------------------------------------------

* DISTRIBUTION: monthly_income_real, PAID WORKERS ONLY, BY CATEGORY (2018, validated)"

tabstat monthly_income_real_2018 if !unpaid_2018 & ind_validated == 1, ///
    by(work_activity_2018) stat(n mean sd p1 p10 p50 p90 p99 min max) col(stat)

* DISTRIBUTION: monthly_income_real, PAID WORKERS ONLY, BY CATEGORY (2021, validated)"

tabstat monthly_income_real_2021 if !unpaid_2021 & ind_validated == 1, ///
    by(work_activity_2021) stat(n mean sd p1 p10 p50 p90 p99 min max) col(stat)

* ----- Export: untrimmed income distribution (headline result, Section 1) -----
estpost tabstat monthly_income_real_2018 if !unpaid_2018 & ind_validated==1, ///
    by(work_activity_2018) statistics(n mean sd p1 p10 p50 p90 p99 min max) columns(statistics)
esttab using "$output\Part2_IncomeSummary.csv", replace cells("count(fmt(0)) mean(fmt(0)) sd(fmt(0)) p1(fmt(0)) p10(fmt(0)) p50(fmt(0)) p90(fmt(0)) p99(fmt(0)) min(fmt(0)) max(fmt(0))") ///
    noobs label title("Untrimmed income distribution, by category, 2018 (paid workers, validated)")

estpost tabstat monthly_income_real_2021 if !unpaid_2021 & ind_validated==1, ///
    by(work_activity_2021) statistics(n mean sd p1 p10 p50 p90 p99 min max) columns(statistics)
esttab using "$output\Part2_IncomeSummary.csv", append cells("count(fmt(0)) mean(fmt(0)) sd(fmt(0)) p1(fmt(0)) p10(fmt(0)) p50(fmt(0)) p90(fmt(0)) p99(fmt(0)) min(fmt(0)) max(fmt(0))") ///
    noobs label title("Untrimmed income distribution, by category, 2021 (paid workers, validated)")

* "NEGATIVE VALUES (paid workers, validated): legitimate for HH enterprise"

tab work_activity_2018 if monthly_income_real_2018 < 0 & !unpaid_2018 & ind_validated == 1
tab work_activity_2021 if monthly_income_real_2021 < 0 & !unpaid_2021 & ind_validated == 1

* ----- Export: negative income values by category (headline result) -----
tabout work_activity_2018 if monthly_income_real_2018<0 & !unpaid_2018 & ind_validated==1 ///
    using "$output\Part2_IncomeChecks.xls", append c(freq col) format(0c 1p) layout(cb) style(xls) ///
    h1("Negative income values, by category, 2018")
tabout work_activity_2021 if monthly_income_real_2021<0 & !unpaid_2021 & ind_validated==1 ///
    using "$output\Part2_IncomeChecks.xls", append c(freq col) format(0c 1p) layout(cb) style(xls) ///
    h1("Negative income values, by category, 2021")

/* Note: HH enterprise has implausible extremes (2018 min ~ -11.1M FCFA/month;
2021 range -13.1M to +26.8M) - almost certainly data errors (e.g. annual
figure entered as monthly), not real business swings. SD is ~20x the mean,
median (20-26k) is the trustworthy "typical" figure, not the mean. The 1/99
pctile trim below should catch most of this, but the worst cases may be
worth eyeballing individually since a single typo can still distort even a
trimmed mean if it's not quite in the 1%/99% tail. */


*------------------------------------------------------------------------------
* 2.3: Scope check for wage workers - what does monthly_income leave out?
*       (monthly_income = salary+bonus only: excludes in-kind benefits, food
*        value, and any secondary job earnings, by construction). Wage
*        workers (code 3) can never be emp_type==4, so no paid-worker filter
*        needed here - just adding the validated filter.
*------------------------------------------------------------------------------


gen gap_emp_inc_2018 = total_emp_income_month_2018 - monthly_income_2018 ///
    if work_activity_2018 == 3 & ind_validated == 1
tabstat gap_emp_inc_2018, stat(n mean sd p50 p90 max)

count if work_activity_2018 == 3 & ind_validated == 1 & missing(salary_month_2018)
di as result "Wage workers (2018, validated) with missing salary_month: `r(N)'"

* ----- Export: wage scope gap (headline result, Section 1) -----
estpost tabstat gap_emp_inc_2018, statistics(n mean sd p50 p90 max) columns(statistics)
esttab using "$output\Part2_IncomeSummary.csv", append cells("count(fmt(0)) mean(fmt(0)) sd(fmt(0)) p50(fmt(0)) p90(fmt(0)) max(fmt(0))") ///
    noobs label title("Wage scope gap: total_emp_income_month minus monthly_income, wage workers 2018")

*------------------------------------------------------------------------------
* 2.5: Trimming flag for robustness - paid workers, validated sample (NOT
*       applied by default - mirrors the 1st/99th percentile convention
*       used in 07_consumption_volatility.do)
*------------------------------------------------------------------------------
foreach yr in 2018 2021 {
    qui _pctile monthly_income_real_`yr' if !unpaid_`yr' & ind_validated == 1, p(1 99)
    local p1_`yr'  = r(r1)
    local p99_`yr' = r(r2)
    gen byte trim_inc_`yr' = (monthly_income_real_`yr' < `p1_`yr'' | ///
        monthly_income_real_`yr' > `p99_`yr'') if !missing(monthly_income_real_`yr')
    label variable trim_inc_`yr' "1%/99% outlier flag (paid workers, validated), `yr' (not applied by default)"
    di as result "monthly_income_real_`yr' (paid, validated): 1st pctile = `p1_`yr'', 99th pctile = `p99_`yr''"
}

*------------------------------------------------------------------------------
* 2.6: Robustness - mean/SD/median BY CATEGORY under two alternative
*       treatments of the raw income data, since the untrimmed 2.2 table
*       has SDs ~20x the mean for HH enterprise (driven by known data
*       errors in the multi-million FCFA range, not real income variation):
*       (a) TRIMMED ONLY - drop the 1%/99% outliers flagged in 2.5, leave
*           every remaining value (including ordinary negative profit) as-is
*       (b) TRIMMED + NEGATIVES->0 - same trim, but additionally floor any
*           remaining negative value to 0 (treats a reported loss as "no
*           income" rather than a negative income, on top of the trim)
*------------------------------------------------------------------------------


tabstat monthly_income_real_2018 if !unpaid_2018 & ind_validated==1 & trim_inc_2018==0, ///
    by(work_activity_2018) stat(n mean sd p50) col(stat)

tabstat monthly_income_real_2021 if !unpaid_2021 & ind_validated==1 & trim_inc_2021==0, ///
    by(work_activity_2021) stat(n mean sd p50) col(stat)

* ----- Export: trimmed-only income distribution (headline result, Section 1) -----
estpost tabstat monthly_income_real_2018 if !unpaid_2018 & ind_validated==1 & trim_inc_2018==0, ///
    by(work_activity_2018) statistics(n mean sd p50) columns(statistics)
esttab using "$output\Part2_IncomeSummary.csv", append cells("count(fmt(0)) mean(fmt(0)) sd(fmt(0)) p50(fmt(0))") ///
    noobs label title("Trimmed-only income distribution, by category, 2018")

estpost tabstat monthly_income_real_2021 if !unpaid_2021 & ind_validated==1 & trim_inc_2021==0, ///
    by(work_activity_2021) statistics(n mean sd p50) columns(statistics)
esttab using "$output\Part2_IncomeSummary.csv", append cells("count(fmt(0)) mean(fmt(0)) sd(fmt(0)) p50(fmt(0))") ///
    noobs label title("Trimmed-only income distribution, by category, 2021")

* Build the zero-floored version (negatives -> 0), unconditionally - the
* sample restriction (paid workers, validated, trimmed) is applied at the
* tabstat step below, same pattern as ihs_income_imp_2018 in Part 4.
gen income_nonneg_2018 = monthly_income_real_2018
replace income_nonneg_2018 = 0 if monthly_income_real_2018 < 0
label variable income_nonneg_2018 "monthly_income_real_2018, negatives recoded to 0"

gen income_nonneg_2021 = monthly_income_real_2021
replace income_nonneg_2021 = 0 if monthly_income_real_2021 < 0
label variable income_nonneg_2021 "monthly_income_real_2021, negatives recoded to 0"


tabstat income_nonneg_2018 if !unpaid_2018 & ind_validated==1 & trim_inc_2018==0, ///
    by(work_activity_2018) stat(n mean sd p50) col(stat)

tabstat income_nonneg_2021 if !unpaid_2021 & ind_validated==1 & trim_inc_2021==0, ///
    by(work_activity_2021) stat(n mean sd p50) col(stat)

* ----- Export: trimmed + negatives->0 income distribution (the "cleaned"
*       headline table in Section 1, and CoV input) -----
estpost tabstat income_nonneg_2018 if !unpaid_2018 & ind_validated==1 & trim_inc_2018==0, ///
    by(work_activity_2018) statistics(n mean sd p50) columns(statistics)
esttab using "$output\Part2_IncomeSummary.csv", append cells("count(fmt(0)) mean(fmt(0)) sd(fmt(0)) p50(fmt(0))") ///
    noobs label title("Cleaned income distribution (trimmed + negatives to 0), by category, 2018")

estpost tabstat income_nonneg_2021 if !unpaid_2021 & ind_validated==1 & trim_inc_2021==0, ///
    by(work_activity_2021) statistics(n mean sd p50) columns(statistics)
esttab using "$output\Part2_IncomeSummary.csv", append cells("count(fmt(0)) mean(fmt(0)) sd(fmt(0)) p50(fmt(0))") ///
    noobs label title("Cleaned income distribution (trimmed + negatives to 0), by category, 2021")

*------------------------------------------------------------------------------
* 2.7: WITHIN-PERSON income volatility, and income BY TRANSITION TYPE
*       (response to reviewer comment that the CoV table in 2.6 is "just
*       cross-sectional variance" - i.e. different PEOPLE having different
*       income levels, not the SAME person's income moving over time).
*
*       (a) income_change (built below) is inherently within-person - each
*           individual's own 2021 income minus their own 2018 income - so
*           its distribution, by category, directly answers the critique.
*           (Originally built on a ratio_inc measure - dropped in favor of
*           income_change throughout, for a simpler, more straightforward
*           variable that doesn't require strictly-positive income in both
*           years to be defined.)
*       (b) mean/median income BY TRANSITION TYPE (origin -> destination,
*           16 cells) - extends the by-2018-category tables in Section 1
*           with the destination dimension too.
*       (c) the actual within-person CHANGE in income, by transition type -
*           only defined where both waves' income is observed.
*------------------------------------------------------------------------------

* ----- (b) Income level, by TRANSITION TYPE (origin -> destination) -----
* (built first since (a) and (c) both need income_change/transition_type)
gen transition_type = work_activity_2018*10 + work_activity_2021 ///
    if sample_trans==1 & ind_validated==1
label define transition_type_lbl ///
    11 "Agriculture -> Agriculture"   12 "Agriculture -> HH enterprise" ///
    13 "Agriculture -> Wage"          14 "Agriculture -> Not working" ///
    21 "HH enterprise -> Agriculture" 22 "HH enterprise -> HH enterprise" ///
    23 "HH enterprise -> Wage"        24 "HH enterprise -> Not working" ///
    31 "Wage -> Agriculture"          32 "Wage -> HH enterprise" ///
    33 "Wage -> Wage"                 34 "Wage -> Not working" ///
    41 "Not working -> Agriculture"   42 "Not working -> HH enterprise" ///
    43 "Not working -> Wage"          44 "Not working -> Not working"
label values transition_type transition_type_lbl
label variable transition_type "Transition type: 2018 category -> 2021 category"

tabstat monthly_income_real_2018 if sample_trans==1, by(transition_type) stat(n mean sd p50)
tabstat monthly_income_real_2021 if sample_trans==1, by(transition_type) stat(n mean sd p50)

* ----- Export: income level by transition type (headline result) -----
estpost tabstat monthly_income_real_2018 if sample_trans==1, by(transition_type) statistics(n mean sd p50) columns(statistics)
esttab using "$output\Part2_IncomeSummary.csv", append cells("count(fmt(0)) mean(fmt(0)) sd(fmt(0)) p50(fmt(0))") ///
    noobs label title("2018 income (starting point), by transition type")

estpost tabstat monthly_income_real_2021 if sample_trans==1, by(transition_type) statistics(n mean sd p50) columns(statistics)
esttab using "$output\Part2_IncomeSummary.csv", append cells("count(fmt(0)) mean(fmt(0)) sd(fmt(0)) p50(fmt(0))") ///
    noobs label title("2021 income (ending point), by transition type")

* ----- (c) Change in income, by TRANSITION TYPE -----
gen income_change = monthly_income_real_2021 - monthly_income_real_2018 ///
    if sample_trans==1 & ind_validated==1
label variable income_change "monthly_income_real_2021 - monthly_income_real_2018"

tabstat income_change if sample_trans==1, by(transition_type) stat(n mean sd p50)

* ----- Export: income change by transition type (headline result) -----
estpost tabstat income_change if sample_trans==1, by(transition_type) statistics(n mean sd p50) columns(statistics)
esttab using "$output\Part2_IncomeSummary.csv", append cells("count(fmt(0)) mean(fmt(0)) sd(fmt(0)) p50(fmt(0))") ///
    noobs label title("Change in income (FCFA), by transition type")

* ----- (a) Within-person volatility, by 2018=2021 STAYER category -----
* income_change, restricted to people who STAYED in the same category both
* waves - the within-person volatility measure responding to the reviewer
* pushback, now built without needing ratio_inc.
tabstat income_change if work_activity_2018==work_activity_2021 & sample_trans==1, ///
    by(work_activity_2018) stat(n mean sd p10 p25 p50 p75 p90)

* ----- Export: within-person income change, stayers only, by category -----
estpost tabstat income_change if work_activity_2018==work_activity_2021 & sample_trans==1, ///
    by(work_activity_2018) statistics(n mean sd p10 p25 p50 p75 p90) columns(statistics)
esttab using "$output\Part2_IncomeSummary.csv", append cells("count(fmt(0)) mean(fmt(0)) sd(fmt(0)) p10(fmt(0)) p25(fmt(0)) p50(fmt(0)) p75(fmt(0)) p90(fmt(0))") ///
    noobs label title("Within-person income change, STAYERS only, by category (reviewer cross-sectional-variance response)")

* ----- Decomposition: loss/profit pattern, HH enterprise stayers -----
* Tests whether the headline income_change median for HHE->HHE stayers
* (pooled, in (c) above) is being pulled by people moving between a loss
* and a profit across the two years - found to explain it almost exactly:
* 26.7% of stayers cross the loss/profit line, and that group's large
* positive swings pull the pooled median positive even though the "profit
* both years" majority sub-group actually declined.
gen byte hhe_stayer = (transition_type==22)

gen byte loss_2018 = (monthly_income_real_2018 <= 0) if !missing(monthly_income_real_2018)
gen byte loss_2021 = (monthly_income_real_2021 <= 0) if !missing(monthly_income_real_2021)

gen byte loss_pattern = .
replace loss_pattern = 1 if loss_2018==0 & loss_2021==0  // profit both years
replace loss_pattern = 2 if loss_2018==1 & loss_2021==0  // loss 2018, profit 2021 (recovery)
replace loss_pattern = 3 if loss_2018==0 & loss_2021==1  // profit 2018, loss 2021 (decline)
replace loss_pattern = 4 if loss_2018==1 & loss_2021==1  // loss both years (persistent)
label define loss_pattern_lbl 1 "Profit both years" ///
    2 "Loss 2018, profit 2021 (recovery)" ///
    3 "Profit 2018, loss 2021 (decline)" ///
    4 "Loss both years (persistent)"
label values loss_pattern loss_pattern_lbl
label variable loss_pattern "Loss/profit pattern across 2018-2021"

tab loss_pattern if hhe_stayer==1 & sample_trans==1 & !missing(income_change)
tabstat income_change if hhe_stayer==1 & sample_trans==1, by(loss_pattern) stat(n mean sd p50)

* ----- Export: loss/profit decomposition for HH enterprise stayers -----
tabout loss_pattern if hhe_stayer==1 & sample_trans==1 & !missing(income_change) ///
    using "$output\Part2_IncomeChecks.xls", append c(freq col) format(0c 1p) layout(cb) style(xls) ///
    h1("Loss/profit pattern, HH enterprise stayers, 2018-2021")

estpost tabstat income_change if hhe_stayer==1 & sample_trans==1, by(loss_pattern) statistics(n mean sd p50) columns(statistics)
esttab using "$output\Part2_IncomeSummary.csv", append cells("count(fmt(0)) mean(fmt(0)) sd(fmt(0)) p50(fmt(0))") ///
    noobs label title("Income change by loss/profit pattern, HH enterprise stayers")

* ----- (d) Share EARNING MORE than 2018, stayers vs movers + by transition type -----
gen byte earned_more_2021 = (monthly_income_real_2021 > monthly_income_real_2018) ///
    if !missing(income_change)
label variable earned_more_2021 "2021 income > 2018 income (same population as income_change)"

gen byte switched_category = (work_activity_2018 != work_activity_2021) if sample_trans==1
label variable switched_category "Switched work_activity category, 2018 to 2021"

tab switched_category earned_more_2021 if sample_trans==1 [aweight=hhweight_2018], row nofreq
tab transition_type earned_more_2021 if sample_trans==1 [aweight=hhweight_2018], row nofreq

* ----- Export: share earning more than 2018 (headline result) -----
tabout switched_category earned_more_2021 if sample_trans==1 [iweight=hhweight_2018] ///
    using "$output\Part2_IncomeChecks.xls", append c(freq row) format(0c 1p) layout(cb) style(xls) ///
    h1("Share earning more than 2018 - stayers vs movers")
tabout transition_type earned_more_2021 if sample_trans==1 [iweight=hhweight_2018] ///
    using "$output\Part2_IncomeChecks.xls", append c(freq row) format(0c 1p) layout(cb) style(xls) ///
    h1("Share earning more than 2018 - by transition type")

*------------------------------------------------------------------------------
* 2.7(e): HISTOGRAM of income change, by transition type (reviewer request)
*          Four groups, built directly from work_activity/unpaid flags
*          rather than the paid_ent/paid_wage variables (which aren't
*          created until Part 4) - keeps this section self-contained:
*            1. Stayed HH enterprise
*            2. Stayed wage
*            3. Transitioned TO HH enterprise
*            4. Transitioned TO wage
*------------------------------------------------------------------------------

gen byte hist_group = .
replace hist_group = 1 if work_activity_2018==2 & unpaid_2018==0 & work_activity_2021==2 & unpaid_2021==0  // Stayed HH enterprise
replace hist_group = 2 if work_activity_2018==3 & unpaid_2018==0 & work_activity_2021==3 & unpaid_2021==0  // Stayed wage
replace hist_group = 3 if work_activity_2021==2 & unpaid_2021==0 & !(work_activity_2018==2 & unpaid_2018==0)  // Transitioned to HH enterprise
replace hist_group = 4 if work_activity_2021==3 & unpaid_2021==0 & !(work_activity_2018==3 & unpaid_2018==0)  // Transitioned to wage

label define hist_group_lbl 1 "Stayed HH enterprise" 2 "Stayed wage" ///
    3 "Transitioned to HH enterprise" 4 "Transitioned to wage"
label values hist_group hist_group_lbl
label variable hist_group "Transition-type group for income-change histograms"

* Trimmed income change - outliers excluded in EITHER year, since the
* change itself can be distorted by an outlier on either side
gen income_change_trim = income_change if trim_inc_2018==0 & trim_inc_2021==0

tab hist_group if !missing(income_change_trim)

* ----- Companion table: WHERE the mass sits relative to zero, not just
*       how spread out it is - share with a gain, a loss, or no change,
*       by transition-type group. Answers "which transitions are more
*       likely to see a decline" directly, complementing the histogram
*       shapes (which show spread/volatility but not direction at a glance).
gen byte income_change_sign = .
replace income_change_sign = 1 if income_change_trim > 0 & !missing(income_change_trim)
replace income_change_sign = 2 if income_change_trim < 0 & !missing(income_change_trim)
replace income_change_sign = 3 if income_change_trim == 0 & !missing(income_change_trim)
label define income_change_sign_lbl 1 "Gained (>0)" 2 "Lost (<0)" 3 "No change (=0)"
label values income_change_sign income_change_sign_lbl
label variable income_change_sign "Direction of trimmed income change, 2018-2021"

tab hist_group income_change_sign, row nofreq

* ----- Export: share gained/lost/no change, by transition-type group -----
tabout hist_group income_change_sign if !missing(hist_group) ///
    using "$output\Part2_IncomeChecks.xls", append c(freq row) format(0c 1p) layout(cb) style(xls) ///
    h1("Direction of income change (trimmed), by transition-type group")

histogram income_change_trim if !missing(hist_group), ///
    by(hist_group, cols(2) ///
       title("Change in real income (FCFA), 2018-2021, by transition type") ///
       note("Trimmed: 1st/99th percentile outliers excluded in both years. Red line = no change (0).")) ///
    percent xtitle("Change in monthly income (FCFA)") ///
    fcolor(%70) ///
    xline(0, lcolor(red) lwidth(thin))
graph export "$output\income_change_histograms.png", replace width(1200)


/* GIC SECTION COMMENTED OUT - dropped due to selection bias
   (requires positive income in both waves, excludes ~80% of sample
   including most interesting transitions). Code preserved for
   potential replication in other country contexts.

********************************************************************************
*                                                                              *
*  PART 2.8: NON-ANONYMOUS GROWTH INCIDENCE CURVE (GIC)                       *
*                                                                              *
*  Unlike a standard (anonymous) GIC, which compares percentiles of two       *
*  independent cross-sections (not necessarily the same people), this         *
*  version tracks the SAME individuals: rank everyone ONCE by their 2018      *
*  (baseline) income, then plot each baseline-rank group's OWN average        *
*  income growth rate from 2018 to 2021. This captures re-ranking/mobility    *
*  that an anonymous GIC would miss - relevant here given the substantial     *
*  churn already documented (transition matrix, loss/profit crossing, etc).   *
*                                                                              *                                                   *                                                                 *
*  Population: paid workers in BOTH waves (excludes unpaid family workers/   *
*  apprentices), validated, BOTH years' income trimmed (1st/99th pctile      *
*  outliers excluded - same flags as 2.5/2.6), and POSITIVE 2018 income      *
*  (growth rate is undefined/explosive for zero or negative baseline).       *
*  This is a narrower population than income_change's (which allows          *
*  negative/zero baseline) - expect a smaller N here, by design.             *
*                                                                              *
********************************************************************************

* ----- Build growth rate (% change), restricted population only -----
gen double gic_growth = (monthly_income_real_2021 - monthly_income_real_2018) ///
    / monthly_income_real_2018 * 100 ///
    if !unpaid_2018 & !unpaid_2021 & ind_validated==1 & sample_trans==1 ///
    & trim_inc_2018==0 & trim_inc_2021==0 & monthly_income_real_2018 > 0 ///
    & !missing(monthly_income_real_2021)
label variable gic_growth "Individual income growth rate, 2018-2021 (%), GIC population"

count if !missing(gic_growth)
di as result "GIC population (positive 2018 income, both years observed, trimmed, paid, validated): `r(N)'"

* ----- Rank by BASELINE (2018) income into ventiles (5% bins) -----
* Ventiles rather than percentiles, since percentiles would be too noisy
* given the GIC population size (low thousands, not tens of thousands).
* Unweighted ranking - xtile does not support survey weights directly.
xtile gic_ventile = monthly_income_real_2018 if !missing(gic_growth), nq(20)
label variable gic_ventile "Ventile of 2018 income (GIC population only, 1=poorest)"

* ----- Overall growth rate, for the reference line(s) -----
qui sum gic_growth if !missing(gic_growth), detail
local mean_growth = r(mean)
local median_growth = r(p50)
di as result "Overall MEAN growth rate: " %5.1f `mean_growth' "%"
di as result "Overall MEDIAN growth rate (reference line used below): " %5.1f `median_growth' "%"

* ----- Collapse to median growth rate per ventile, for plotting/export -----
* MEDIAN, not mean: an initial run using the mean showed ventile 1 (the
* poorest, by construction closest to a zero baseline) at an implausible
* ~1,374% - a handful of people with a tiny 2018 income and an ordinary
* FCFA gain produce enormous % growth rates by simple division, and a few
* of those are enough to drag a 127-observation MEAN into the thousands.
* This is a well-known issue for GICs anchored near zero, not a sign of
* thin data (n_obs was a normal ~127, not small). Median is far more
* robust to a handful of such outliers - kept the mean as a companion
* column so the gap between the two is visible, not hidden.

preserve
    collapse (median) gic_growth_median=gic_growth (mean) gic_growth_mean=gic_growth ///
        (count) n_obs=gic_growth if !missing(gic_growth), by(gic_ventile)
    label variable gic_growth_median "Median income growth rate (%), by 2018 income ventile"
    label variable gic_growth_mean "Mean income growth rate (%), by 2018 income ventile (for comparison)"



    list gic_ventile gic_growth_median gic_growth_mean n_obs, clean noobs

    twoway (connected gic_growth_median gic_ventile, lcolor(navy) mcolor(navy) msymbol(circle)) ///
        (function y=`median_growth', range(1 20) lcolor(red) lpattern(dash)), ///
        title("Non-anonymous growth incidence curve, 2018-2021") ///
        subtitle("Same individuals, ranked once by 2018 income (median growth rate)") ///
        xtitle("Ventile of 2018 income (1=poorest, 20=richest)") ///
        ytitle("Median income growth rate, 2018-2021 (%)") ///
        legend(order(1 "Ventile median growth rate" 2 "Overall median growth rate")) ///
        xlabel(1(1)20) ylabel(, angle(horizontal))
    graph export "$output\non_anonymous_GIC.png", replace width(1200)

    * ----- Export: GIC data table (both median and mean) -----
    export excel gic_ventile gic_growth_median gic_growth_mean n_obs using "$output\Part2_GIC.xlsx", ///
        replace firstrow(variables) sheet("NonAnonymousGIC")
restore


* ----- CONSUMPTION-RANKED GIC -----
* Same y-axis (income growth rate) but x-axis ranking now uses
* pc_total_cons_2018 (per-capita total consumption, 2018) instead of
* income. Advantages over the income-ranked version:
*   (1) No near-zero-denominator problem - consumption ranking is stable
*       and fully populated (no structural missingness unlike income).
*   (2) Consumption is a smoother, less noisy measure of permanent welfare
*       than individual monthly income, so the baseline ranking is more
*       stable and meaningful.
*   (3) Both versions are directly comparable (same y-axis, same GIC
*       population) - differences between the two reveal whether the
*       income-growth gradient is driven by WHO is poor (by consumption)
*       vs. which INCOME LEVEL experienced high proportional growth.
* Using ventiles (nq=20) for consistent granularity with the income-ranked
* version above.

xtile gic_ventile_cons = pc_total_cons_2018 if !missing(gic_growth), nq(20)
label variable gic_ventile_cons "Ventile of 2018 consumption (GIC population, 1=poorest)"

qui sum gic_growth if !missing(gic_growth), detail
local median_growth_cons = r(p50)

preserve
    collapse (median) gic_growth_median=gic_growth (mean) gic_growth_mean=gic_growth ///
        (count) n_obs=gic_growth if !missing(gic_growth), by(gic_ventile_cons)
    label variable gic_growth_median "Median income growth rate (%), by 2018 consumption ventile"
    label variable gic_growth_mean   "Mean income growth rate (%), by 2018 consumption ventile"

    di as text _n "=============================================="
    di as text "CONSUMPTION-RANKED GIC: median income growth rate by consumption ventile"
    di as text "=============================================="
    list gic_ventile_cons gic_growth_median gic_growth_mean n_obs, clean noobs

    twoway (connected gic_growth_median gic_ventile_cons, lcolor(navy) mcolor(navy) msymbol(circle)) ///
        (function y=`median_growth_cons', range(1 20) lcolor(red) lpattern(dash)), ///
        title("Non-anonymous growth incidence curve, 2018-2021") ///
        subtitle("Ranked by 2018 consumption; y-axis = income growth (median)") ///
        xtitle("Ventile of 2018 consumption (1=poorest, 20=richest)") ///
        ytitle("Median income growth rate, 2018-2021 (%)") ///
        legend(order(1 "Ventile median growth rate" 2 "Overall median growth rate")) ///
        xlabel(1(1)20) ylabel(, angle(horizontal))
    graph export "$output\non_anonymous_GIC_cons_ranked.png", replace width(1200)

    * ----- Export: consumption-ranked GIC data table -----
    export excel gic_ventile_cons gic_growth_median gic_growth_mean n_obs ///
        using "$output\Part2_GIC.xlsx", ///
        sheet("ConsumptionRanked_GIC") sheetreplace firstrow(variables)
restore

END GIC COMMENT */

********************************************************************************
*                                                                              *
*  PART 3: TRANSITION MATRIX (DESCRIPTIVE)                                    *
*                                                                              *
*  Headline output: the 4x4 transition matrix showing where each 2018         *
*  category ended up by 2021, row-normalized (conditional probabilities).     *
*  Weighted using the 2018 baseline household weight. Two versions exported   *
*  to the same file (Transition.xls):                                        *
*    (1) Full sample_trans==1 sample - "Not working" bundles unemployed +    *
*        out-of-labor-force (NILF: students, retired, homemakers, etc.)      *
*    (2) Restricted to in_labor_force==1 in BOTH waves - drops NILF, so      *
*        "Not working" here means unemployed/job-seeking specifically.       *
*  ("Not working" is not the same as the ILO unemployment-rate denominator   *
*  - see earlier discussion - (2) is the closer approximation of the two.)   *
*                                                                              *
********************************************************************************

tabout work_activity_2018 work_activity_2021 if sample_trans == 1 [iweight=hhweight_2018] using "$output\Transition.xls", replace c(freq col row) format(0c 1p 1p) layout(cb) style(xls) h1("Transitions")  
tabout work_activity_2018 work_activity_2021 if sample_trans == 1 & in_labor_force_2018==1 & in_labor_force_2021==1 [iweight=hhweight_2018] using "$output\Transition.xls", append c(freq col row) format(0c 1p 1p) layout(cb) style(xls) h1("Transitions for those in the labor force")  

*------------------------------------------------------------------------------
* 3.1: Marginal distributions - aggregate shift 2018 -> 2021 (added back -
*       useful context for whether the overall structure shifted, separate
*       from who-went-where conditionally in the matrix above)
*------------------------------------------------------------------------------
di as text _n "2018:"
tab work_activity_2018 if sample_trans==1 [aweight=hhweight_2018]
di as text _n "2021:"
tab work_activity_2021 if sample_trans==1 [aweight=hhweight_2018]

*------------------------------------------------------------------------------
* 3.2: Headline stability comparison - retention rate BY 2018 category
*       Built as a variable (stayed), not locals/scalars, so it can be
*       exported and appended into the same Transition.xls via tabout
*       instead of just printed to the log. One table gives retention for
*       ALL FOUR categories at once - HH enterprise and Wage worker are
*       just two rows of this same output, read directly off the export.
*------------------------------------------------------------------------------
gen byte stayed = (work_activity_2018 == work_activity_2021) if sample_trans==1
label variable stayed "Same work_activity category in 2018 and 2021"

tabout work_activity_2018 stayed if sample_trans==1 [iweight=hhweight_2018] using "$output\Transition.xls", append c(freq col row) format(0c 1p 1p) layout(cb) style(xls) h1("Retention rate, by 2018 category")

*------------------------------------------------------------------------------
* 3.3: Overall churn - share staying in the SAME category vs. switching
*       (collapses across all categories - reuses `stayed` from 3.2 above)
*------------------------------------------------------------------------------
tabout stayed if sample_trans == 1 & in_labor_force_2018==1 & in_labor_force_2021==1 [iweight=hhweight_2018] using "$output\Transition.xls", append c(freq col row) format(0c 1p 1p) layout(cb) style(xls) 


********************************************************************************
*                                                                              *
*  PART 4: DETERMINANTS OF TRANSITION - LOGIT MODELS                          *
*                                                                              *
*  Two binary models, mirroring the original research question:              *
*    Model A: determinants of transitioning INTO paid HH enterprise          *
*    Model B: determinants of transitioning INTO paid wage work              *
*  "Paid" excludes unpaid family workers / unpaid apprentices (unpaid_YYYY,   *
*  Part 2.1b) - excluding unpaid work as then can't control for income on RHS
*                                                                              *
*  Sample for each model: sample_trans==1, validated, NOT already in the     *
*  paid destination category in 2018 (so those who remained in HHEs across
*	two years were excluded     
*  unpaid workers/agriculture/wage/not-working in 2018 are all eligible).    *
*                                                                              *
*  All covariates at 2018 (baseline) - see specification discussion. Four    *
*  income variants per model:                                                *
*    v1: no income term                                                      *
*    v2: monthly_income_real_2018, level, negative values DROPPED            *
*    v3: monthly_income_real_2018, level, negative values INCLUDED (as is)   *
*    v4: IHS-transformed monthly_income_real_2018, negatives included        *
*                                                                              *                                         *
*                                                                              *
********************************************************************************

*------------------------------------------------------------------------------
* 4.1: Build outcome, sample, and income-transform variables
*------------------------------------------------------------------------------

* Outcome / sample indicators (paid version of each category only)
gen byte paid_ent18  = (work_activity_2018==2 & unpaid_2018==0) if sample_trans==1
gen byte paid_ent21  = (work_activity_2021==2 & unpaid_2021==0) if sample_trans==1
gen byte paid_wage18 = (work_activity_2018==3 & unpaid_2018==0) if sample_trans==1
gen byte paid_wage21 = (work_activity_2021==3 & unpaid_2021==0) if sample_trans==1
label variable paid_ent18  "Paid HH enterprise (own-account/employer), 2018"
label variable paid_ent21  "Paid HH enterprise (own-account/employer), 2021"
label variable paid_wage18 "Paid wage worker (excl. unpaid apprentice), 2018"
label variable paid_wage21 "Paid wage worker (excl. unpaid apprentice), 2021"

* IHS transform for income variant 4 (handles negatives/zero, behaves like
* log for larger values): asinh(x) = ln(x + sqrt(x^2+1))
gen ihs_income_2018 = ln(monthly_income_real_2018 + sqrt(monthly_income_real_2018^2 + 1)) ///
    if sample_trans==1
label variable ihs_income_2018 "IHS-transformed monthly_income_real_2018"

* Variant 4 only: flag + 0-impute, to recover the full sample rather than
* lose ~80% of it to income missingness (confirmed structural - mostly
* "Not working" in 2018, who have no income to report by construction).
* Imputing on IHS specifically (not the raw level) because asinh(0)=0 sits
* naturally at the low end of that scale; a 0-impute on raw FCFA levels
* would create an artificial pile-up that a single dummy can't cleanly
* absorb. Variants 2/3 (raw level) intentionally stay on the smaller
* income-reporting subsample, no dummy

gen byte no_income_2018 = missing(monthly_income_real_2018) if sample_trans==1
label variable no_income_2018 "No income reported, 2018 (structural - mostly Not working)"
gen ihs_income_imp_2018 = ihs_income_2018
replace ihs_income_imp_2018 = 0 if missing(ihs_income_2018)
label variable ihs_income_imp_2018 "IHS income, 2018 (0 where missing - use with no_income_2018)"

*------------------------------------------------------------------------------
* 4.2: CONFIRM reference categories BEFORE trusting any coefficient sign
*       (same lesson as work_activity/emp_type earlier - don't assume codes)
*------------------------------------------------------------------------------

label list s01q01              // sexe_2018: 1 Masculin, 2 Feminin
label list educ_cat_2018       // 1 No education ... 4 Secondary and higher
label list s01q07              // mstat_2018: 1 Celibataire ... 7 Separe(e)
label list welfare_quintile_2018  // 1 Q1 (poorest) ... 5 Q5 (richest)
label list ouinon              // has_electricity_2018 AND has_internet_2018
label list has_secondary_job   // has_secondary_job_2018: 0/1
* neg_shock_2018: 0/1, no value label attached
* location_2018: 1 Dakar, 2 Thies, 3 Other urban, 4 Rural

fvset base 4 location_2018       // intended base: Rural

* ----- NEW: finance-access variables (remittances, bank account) -----
* Testing whether access to finance eases entry into HH enterprise (capital
* constraint hypothesis). Confirm coding before trusting signs - same
* discipline as everything else above, don't assume 0/1 vs 1/2.

* NOTE: hh_received_remittances_2018 recode (. = 0) was moved to the top
* of the file (right after data load) to ensure consistent sequencing.
* See line ~57 for the actual recode.

* has_bank_2018 (HH has bank/financial account) - used INSTEAD of the
* originally-planned ind_got_credit_2018, which was 98.7% missing (likely
* asked of a restricted sub-sample only) and too sparse to use safely.

capture label list hh_received_remittances_2018
capture label list has_bank_2018

tab hh_received_remittances_2018, missing
tab has_bank_2018, missing


*------------------------------------------------------------------------------
* 4.3: Coverage check - missingness on each covariate, BY MODEL SAMPLE
*------------------------------------------------------------------------------

qui count if sample_trans==1 & !paid_ent18 & ind_validated==1
local ntot_A = r(N)
di as result "Model A sample size (before any covariate/income missingness): `ntot_A'"
foreach v in sexe_2018 age_2018 educ_cat_2018 mstat_2018 has_secondary_job_2018 ///
    hhsize_2018 dep_ratio_2018 welfare_quintile_2018 has_electricity_2018 ///
    has_internet_2018 neg_shock_2018 location_2018 ///
    hh_received_remittances_2018 has_bank_2018 {
    qui count if sample_trans==1 & !paid_ent18 & ind_validated==1 & missing(`v')
    di as result "`v': `r(N)' / `ntot_A' missing"
}


qui count if sample_trans==1 & !paid_wage18 & ind_validated==1
local ntot_B = r(N)
di as result "Model B sample size (before any covariate/income missingness): `ntot_B'"
foreach v in sexe_2018 age_2018 educ_cat_2018 mstat_2018 has_secondary_job_2018 ///
    hhsize_2018 dep_ratio_2018 welfare_quintile_2018 has_electricity_2018 ///
    has_internet_2018 neg_shock_2018 location_2018 ///
    hh_received_remittances_2018 has_bank_2018 {
    qui count if sample_trans==1 & !paid_wage18 & ind_validated==1 & missing(`v')
    di as result "`v': `r(N)' / `ntot_B' missing"
}

*------------------------------------------------------------------------------
* 4.4: Sparse-cell check on dummy blocks (risk of logit separation)
*------------------------------------------------------------------------------

tab educ_cat_2018         if sample_trans==1 & !paid_ent18 & ind_validated==1 [aweight=hhweight_2018]
tab mstat_2018           if sample_trans==1 & !paid_ent18 & ind_validated==1 [aweight=hhweight_2018]
tab welfare_quintile_2018 if sample_trans==1 & !paid_ent18 & ind_validated==1 [aweight=hhweight_2018]
tab location_2018        if sample_trans==1 & !paid_ent18 & ind_validated==1 [aweight=hhweight_2018]
tab hh_received_remittances_2018 if sample_trans==1 & !paid_ent18 & ind_validated==1 [aweight=hhweight_2018]
tab has_bank_2018  if sample_trans==1 & !paid_ent18 & ind_validated==1 [aweight=hhweight_2018]

tab educ_cat_2018         if sample_trans==1 & !paid_wage18 & ind_validated==1 [aweight=hhweight_2018]
tab mstat_2018           if sample_trans==1 & !paid_wage18 & ind_validated==1 [aweight=hhweight_2018]
tab welfare_quintile_2018 if sample_trans==1 & !paid_wage18 & ind_validated==1 [aweight=hhweight_2018]
tab location_2018        if sample_trans==1 & !paid_wage18 & ind_validated==1 [aweight=hhweight_2018]
tab hh_received_remittances_2018 if sample_trans==1 & !paid_wage18 & ind_validated==1 [aweight=hhweight_2018]
tab has_bank_2018  if sample_trans==1 & !paid_wage18 & ind_validated==1 [aweight=hhweight_2018]

* ----- Export: cell sizes for the two new finance-access variables -----
tabout hh_received_remittances_2018 if sample_trans==1 & !paid_ent18 & ind_validated==1 [iweight=hhweight_2018] ///
    using "$output\Part4_Checks.xls", append c(freq col) format(0c 1p) layout(cb) style(xls) ///
    h1("Remittances cell sizes, Model A sample")
tabout has_bank_2018 if sample_trans==1 & !paid_ent18 & ind_validated==1 [iweight=hhweight_2018] ///
    using "$output\Part4_Checks.xls", append c(freq col) format(0c 1p) layout(cb) style(xls) ///
    h1("Bank account cell sizes, Model A sample")
tabout hh_received_remittances_2018 if sample_trans==1 & !paid_wage18 & ind_validated==1 [iweight=hhweight_2018] ///
    using "$output\Part4_Checks.xls", append c(freq col) format(0c 1p) layout(cb) style(xls) ///
    h1("Remittances cell sizes, Model B sample")
tabout has_bank_2018 if sample_trans==1 & !paid_wage18 & ind_validated==1 [iweight=hhweight_2018] ///
    using "$output\Part4_Checks.xls", append c(freq col) format(0c 1p) layout(cb) style(xls) ///
    h1("Bank account cell sizes, Model B sample")

* ----- Export: pre-collapse sparse cell checks (Model A and Model B samples) -----
tabout educ_cat_2018 if sample_trans==1 & !paid_ent18 & ind_validated==1 [iweight=hhweight_2018] ///
    using "$output\Part4_Checks.xls", replace c(freq col) format(0c 1p) layout(cb) style(xls) ///
    h1("Pre-collapse education cell sizes, Model A sample")
tabout mstat_2018 if sample_trans==1 & !paid_ent18 & ind_validated==1 [iweight=hhweight_2018] ///
    using "$output\Part4_Checks.xls", append c(freq col) format(0c 1p) layout(cb) style(xls) ///
    h1("Pre-collapse marital status cell sizes, Model A sample")
tabout educ_cat_2018 if sample_trans==1 & !paid_wage18 & ind_validated==1 [iweight=hhweight_2018] ///
    using "$output\Part4_Checks.xls", append c(freq col) format(0c 1p) layout(cb) style(xls) ///
    h1("Pre-collapse education cell sizes, Model B sample")
tabout mstat_2018 if sample_trans==1 & !paid_wage18 & ind_validated==1 [iweight=hhweight_2018] ///
    using "$output\Part4_Checks.xls", append c(freq col) format(0c 1p) layout(cb) style(xls) ///
    h1("Pre-collapse marital status cell sizes, Model B sample")
tabout welfare_quintile_2018 if sample_trans==1 & !paid_ent18 & ind_validated==1 [iweight=hhweight_2018] ///
    using "$output\Part4_Checks.xls", append c(freq col) format(0c 1p) layout(cb) style(xls) ///
    h1("Welfare quintile cell sizes, Model A sample")
tabout location_2018 if sample_trans==1 & !paid_ent18 & ind_validated==1 [iweight=hhweight_2018] ///
    using "$output\Part4_Checks.xls", append c(freq col) format(0c 1p) layout(cb) style(xls) ///
    h1("Location cell sizes, Model A sample")
tabout welfare_quintile_2018 if sample_trans==1 & !paid_wage18 & ind_validated==1 [iweight=hhweight_2018] ///
    using "$output\Part4_Checks.xls", append c(freq col) format(0c 1p) layout(cb) style(xls) ///
    h1("Welfare quintile cell sizes, Model B sample")
tabout location_2018 if sample_trans==1 & !paid_wage18 & ind_validated==1 [iweight=hhweight_2018] ///
    using "$output\Part4_Checks.xls", append c(freq col) format(0c 1p) layout(cb) style(xls) ///
    h1("Location cell sizes, Model B sample")

*------------------------------------------------------------------------------
* 4.4b: Collapse sparse categories found in 4.4 above, before regression.
*       educ_cat_2018: "Less than primary" is ~0% in Model A's sample and
*       ~0.02% in Model B's - merged into "No education" (closest fit).
*       mstat_2018: "Union libre", "Divorce(e)", "Separe(e)" are all <2% in
*       both samples - collapsed into a single "Other" category alongside
*       the four well-populated levels. New codes deliberately keep the
*       same reference category (lowest code = No education / Never
*       married) as the originals, so no additional fvset base is needed.
*       Built from the ORIGINAL variable each time (not sequential recodes)
*       to avoid any risk of code collisions during the remapping.
*------------------------------------------------------------------------------
gen byte educ_cat_c_2018 = .
replace educ_cat_c_2018 = 1 if inlist(educ_cat_2018, 1, 2)
replace educ_cat_c_2018 = 2 if educ_cat_2018 == 3
replace educ_cat_c_2018 = 3 if educ_cat_2018 == 4
label define educ_cat_c_2018_lbl 1 "No/incomplete primary education" ///
    2 "Less than secondary" 3 "Secondary and higher"
label values educ_cat_c_2018 educ_cat_c_2018_lbl
label variable educ_cat_c_2018 "Education category (collapsed), 2018"

gen byte mstat_c_2018 = .
replace mstat_c_2018 = 1 if mstat_2018 == 1
replace mstat_c_2018 = 2 if mstat_2018 == 2
replace mstat_c_2018 = 3 if mstat_2018 == 3
replace mstat_c_2018 = 4 if mstat_2018 == 5
replace mstat_c_2018 = 5 if inlist(mstat_2018, 4, 6, 7)
label define mstat_c_2018_lbl 1 "Never married" 2 "Married, monogamous" ///
    3 "Married, polygamous" 4 "Widowed" 5 "Other (union libre/divorced/separated)"
label values mstat_c_2018 mstat_c_2018_lbl
label variable mstat_c_2018 "Marital status (collapsed), 2018"


tab educ_cat_c_2018 if sample_trans==1 & !paid_ent18 & ind_validated==1 [aweight=hhweight_2018]
tab mstat_c_2018    if sample_trans==1 & !paid_ent18 & ind_validated==1 [aweight=hhweight_2018]


tab educ_cat_c_2018 if sample_trans==1 & !paid_wage18 & ind_validated==1 [aweight=hhweight_2018]
tab mstat_c_2018    if sample_trans==1 & !paid_wage18 & ind_validated==1 [aweight=hhweight_2018]

* ----- Export: post-collapse verification cell sizes (Model A and B) -----
tabout educ_cat_c_2018 if sample_trans==1 & !paid_ent18 & ind_validated==1 [iweight=hhweight_2018] ///
    using "$output\Part4_Checks.xls", append c(freq col) format(0c 1p) layout(cb) style(xls) ///
    h1("Post-collapse education cell sizes, Model A sample")
tabout mstat_c_2018 if sample_trans==1 & !paid_ent18 & ind_validated==1 [iweight=hhweight_2018] ///
    using "$output\Part4_Checks.xls", append c(freq col) format(0c 1p) layout(cb) style(xls) ///
    h1("Post-collapse marital status cell sizes, Model A sample")
tabout educ_cat_c_2018 if sample_trans==1 & !paid_wage18 & ind_validated==1 [iweight=hhweight_2018] ///
    using "$output\Part4_Checks.xls", append c(freq col) format(0c 1p) layout(cb) style(xls) ///
    h1("Post-collapse education cell sizes, Model B sample")
tabout mstat_c_2018 if sample_trans==1 & !paid_wage18 & ind_validated==1 [iweight=hhweight_2018] ///
    using "$output\Part4_Checks.xls", append c(freq col) format(0c 1p) layout(cb) style(xls) ///
    h1("Post-collapse marital status cell sizes, Model B sample")

*------------------------------------------------------------------------------
* 4.5: Sample-flow table - how much does each income variant cost in N?
*       (isolates the income-driven attrition specifically, before any other
*       covariate missingness is layered on top)
*------------------------------------------------------------------------------

foreach m in ent wage {
    qui count if sample_trans==1 & !paid_`m'18 & ind_validated==1
    di as result "Model (`m'), v1 no income:              `r(N)'"
    qui count if sample_trans==1 & !paid_`m'18 & ind_validated==1 & !missing(monthly_income_real_2018)
    di as result "Model (`m'), v3/v4 income, neg included: `r(N)'"
    qui count if sample_trans==1 & !paid_`m'18 & ind_validated==1 & !missing(monthly_income_real_2018) & monthly_income_real_2018>=0
    di as result "Model (`m'), v2 income, neg dropped:      `r(N)'"
}

* ----- Export: sample flow by income variant (headline result) -----
* Built via putexcel rather than tabout/esttab, since this is a series of
* counts under different conditions, not a tab or tabstat output.
putexcel set "$output\Part4_SampleFlow.xlsx", replace
putexcel A1 = "Model" B1 = "Spec" C1 = "N"
local row = 2
foreach m in ent wage {
    qui count if sample_trans==1 & !paid_`m'18 & ind_validated==1
    putexcel A`row' = "`m'" B`row' = "v1: no income" C`row' = `r(N)'
    local row = `row' + 1
    qui count if sample_trans==1 & !paid_`m'18 & ind_validated==1 & !missing(monthly_income_real_2018)
    putexcel A`row' = "`m'" B`row' = "v3/v4: income, neg included" C`row' = `r(N)'
    local row = `row' + 1
    qui count if sample_trans==1 & !paid_`m'18 & ind_validated==1 & !missing(monthly_income_real_2018) & monthly_income_real_2018>=0
    putexcel A`row' = "`m'" B`row' = "v2: income, neg dropped" C`row' = `r(N)'
    local row = `row' + 1
}

*------------------------------------------------------------------------------
* 4.6: Multicollinearity check among continuous covariates
*------------------------------------------------------------------------------

corr age_2018 hhsize_2018 dep_ratio_2018 monthly_income_real_2018 ///
    if sample_trans==1 & !paid_ent18 & ind_validated==1

*------------------------------------------------------------------------------
* 4.6b: Income quintile dummies - testing for NON-LINEAR income effects
*       
*       "No income" is its own category (code 0, kept as the reference -
*       already the lowest code, no fvset base needed), covering the same
*       population as no_income_2018 in spec 4 (mostly Not working, plus
*       unpaid workers - both have missing income by construction). This
*       recovers the full sample, exactly like spec 4 does.
*------------------------------------------------------------------------------

xtile income_q5_2018 = monthly_income_real_2018 ///
    if sample_trans==1 & !unpaid_2018 & ind_validated==1, nq(5)

gen byte income_cat6_2018 = income_q5_2018
replace income_cat6_2018 = 0 if no_income_2018==1 & sample_trans==1
label define income_cat6_2018_lbl 0 "No income" 1 "Q1 (poorest)" 2 "Q2" ///
    3 "Q3" 4 "Q4" 5 "Q5 (richest)"
label values income_cat6_2018 income_cat6_2018_lbl
label variable income_cat6_2018 "Income category 2018: no income / quintile among earners"


tab income_cat6_2018 if sample_trans==1 & !paid_ent18 & ind_validated==1 [aweight=hhweight_2018]

tab income_cat6_2018 if sample_trans==1 & !paid_wage18 & ind_validated==1 [aweight=hhweight_2018]

* ----- Export: income quintile category cell sizes (Model A and B) -----
tabout income_cat6_2018 if sample_trans==1 & !paid_ent18 & ind_validated==1 [iweight=hhweight_2018] ///
    using "$output\Part4_Checks.xls", append c(freq col) format(0c 1p) layout(cb) style(xls) ///
    h1("Income quintile category cell sizes, Model A sample")
tabout income_cat6_2018 if sample_trans==1 & !paid_wage18 & ind_validated==1 [iweight=hhweight_2018] ///
    using "$output\Part4_Checks.xls", append c(freq col) format(0c 1p) layout(cb) style(xls) ///
    h1("Income quintile category cell sizes, Model B sample")

*------------------------------------------------------------------------------
* 4.7: MODEL A - determinants of transition into paid HH enterprise
*------------------------------------------------------------------------------
local controls "i.sexe_2018 c.age_2018##c.age_2018"
local controls "`controls' i.educ_cat_c_2018 i.mstat_c_2018"
local controls "`controls' i.has_secondary_job_2018 hhsize_2018 dep_ratio_2018"
local controls "`controls' i.welfare_quintile_2018 i.has_electricity_2018"
local controls "`controls' i.has_internet_2018 i.neg_shock_2018 i.location_2018"
local controls "`controls' i.hh_received_remittances_2018 i.has_bank_2018"

local spec1_rhs ""
local spec1_if  ""
local spec2_rhs "i.income_cat6_2018"
local spec2_if  ""
local spec3_rhs "monthly_income_real_2018"
local spec3_if  "& !missing(monthly_income_real_2018) & monthly_income_real_2018>=0"
local spec4_rhs "monthly_income_real_2018"
local spec4_if  ""
local spec5_rhs "ihs_income_imp_2018 i.no_income_2018"
local spec5_if  ""

forvalues v = 1/5 {
    eststo modelA_v`v': logit paid_ent21 `controls' `spec`v'_rhs' ///
        if sample_trans==1 & !paid_ent18 & ind_validated==1 `spec`v'_if' ///
        [pw=hhweight_2018], vce(cluster grappe)
}

local coefnames "0.has_electricity_2018 `"No electricity (2018)"' 1.has_electricity_2018 `"Has electricity (2018)"'"
local coefnames "`coefnames' 0.has_internet_2018 `"No internet (2018)"' 1.has_internet_2018 `"Has internet (2018)"'"
local coefnames "`coefnames' 2.location_2018 `"Thies (2018)"'"
* Pre-emptive: if hh_received_remittances_2018 / has_bank_2018 share the
* same ouinon (or similar Oui/Non) value label as electricity/internet, they'll
* hit the same duplicate-row problem we fixed before. Adding labels now rather
* than waiting to find out - if these variables turn out to already have their
* own distinct value label, these lines are harmless (coeflabels just won't
* find a matching row to relabel).
local coefnames "`coefnames' 0.hh_received_remittances_2018 `"No remittances (2018)"' 1.hh_received_remittances_2018 `"Received remittances (2018)"'"
local coefnames "`coefnames' 0.has_bank_2018 `"No bank account (2018)"' 1.has_bank_2018 `"Has bank account (2018)"'"

esttab modelA_v1 modelA_v2 modelA_v3 modelA_v4 modelA_v5 using "$output\ModelA_HHenterprise.csv", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) stats(N r2_p) label ///
    coeflabels(`coefnames') ///
    title("Determinants of transition into HH enterprise (paid), 2018-2021") ///
    mtitles("No income" "Income quintiles" "Income, neg dropped" "Income, neg incl." "IHS, full sample") ///
    note("Logit, pweight=hhweight_2018, cluster(grappe). Sample: not already paid HH enterprise in 2018, validated matches.")

*------------------------------------------------------------------------------
* 4.8: MODEL B - determinants of transition into paid wage work
*------------------------------------------------------------------------------
forvalues v = 1/5 {
    eststo modelB_v`v': logit paid_wage21 `controls' `spec`v'_rhs' ///
        if sample_trans==1 & !paid_wage18 & ind_validated==1 `spec`v'_if' ///
        [pw=hhweight_2018], vce(cluster grappe)
}

esttab modelB_v1 modelB_v2 modelB_v3 modelB_v4 modelB_v5 using "$output\ModelB_WageWorker.csv", replace ///
    se star(* 0.10 ** 0.05 *** 0.01) stats(N r2_p) label ///
    coeflabels(`coefnames') ///
    title("Determinants of transition into wage work (paid), 2018-2021") ///
    mtitles("No income" "Income quintiles" "Income, neg dropped" "Income, neg incl." "IHS, full sample") ///
    note("Logit, pweight=hhweight_2018, cluster(grappe). Sample: not already paid wage worker in 2018, validated matches.")
	

* ----------------------------------------------------------------------
* Characterizing exits from HH enterprise to "not working"
* Compare 2018 HH enterprise workers by 2021 outcome:
*   (a) Stayed in HH enterprise (work_activity_2021 == 2)
*   (b) Exited to not working (work_activity_2021 == 4)
* Restricted to sample_trans == 1
* ----------------------------------------------------------------------

* Define the two comparison groups
gen byte exit_group = .
replace exit_group = 1 if sample_trans == 1 & work_activity_2018 == 2 & work_activity_2021 == 2
replace exit_group = 2 if sample_trans == 1 & work_activity_2018 == 2 & work_activity_2021 == 4
label define exit_group_lbl 1 "Stayed in HHE" 2 "Exited to Not Working"
label values exit_group exit_group_lbl

* -----------------------------------------------------------------------
* Generate helper dummies used below
* educ_cat_2018: 1 No education, 2 Less than primary, 3 Less than secondary,
*                4 Secondary and higher
* location_2018: 1 Dakar, 2 Thies, 3 Other urban, 4 Rural (check via label)
* -----------------------------------------------------------------------
gen byte edu_none_2018    = (educ_cat_2018 == 1) if !missing(educ_cat_2018)
gen byte edu_lesssec_2018 = (educ_cat_2018 == 3) if !missing(educ_cat_2018)
gen byte edu_secplus_2018 = (educ_cat_2018 == 4) if !missing(educ_cat_2018)

capture confirm variable location_2018
if _rc == 0 {
    quietly levelsof location_2018, local(loc_levels)
    di as text "Values found in location_2018: `loc_levels'"
    gen byte loc_dakar = (location_2018 == 1) if !missing(location_2018)
    gen byte loc_rural = (location_2018 == 4) if !missing(location_2018)
}

* Group sizes
tab exit_group [aweight=hhweight_2018]

* Demographics comparison (t-tests)
foreach v in age_2018 hhsize_2018 dep_ratio_2018 {
    di as text _n "--- `v' ---"
    ttest `v', by(exit_group)
}

* Share female
gen byte female_2018_x = (sexe_2018 == 2) if !missing(sexe_2018)
di as text _n "--- Share female ---"
ttest female_2018_x, by(exit_group)

* Share 55+
gen byte age_55plus = (age_2018 >= 55) if !missing(age_2018)
di as text _n "--- Share age 55+ ---"
ttest age_55plus, by(exit_group)

* Share 65+
gen byte age_65plus = (age_2018 >= 65) if !missing(age_2018)
di as text _n "--- Share age 65+ ---"
ttest age_65plus, by(exit_group)

* Education categories
foreach v in edu_none_2018 edu_lesssec_2018 edu_secplus_2018 {
    di as text _n "--- `v' ---"
    ttest `v', by(exit_group)
}

* Location, infrastructure, financial access
foreach v in loc_dakar loc_rural has_electricity_2018 has_internet_2018 has_bank_2018 hh_received_remittances_2018 {
    di as text _n "--- `v' ---"
    ttest `v', by(exit_group)
}

*------------------------------------------------------------------------------
* Section 5: Enterprise-level statistics on high-growth HH enterprises (gazelles)
*
* This section is at the ENTERPRISE level (one observation per enterprise),
* not the individual level. It uses SEN_enterprises_2018.dta and
* SEN_enterprises_2021.dta (produced by 02_clean_2018.do / 03_clean_2021.do
* before the "keep highest-revenue enterprise per owner" collapse).
*
* Contents:
*   5.1 Verification of 2018 stylized facts referenced in Section 2.3 of the
*       report:
*       - Share of enterprises with at least one non-household employee
*       - Share of enterprises with capital stock > 3,000 FCFA
*   5.2 Enterprise-level gazelle analysis:
*       - Definition: profit AND non-family employees both grew 2018 -> 2021
*       - Share of surviving enterprises meeting this definition
*
* Note: the descriptive comparison of gazelles vs non-gazelles (baseline
* characteristics like gender, education, location, etc.) is INDIVIDUAL-level
* and remains in the transition-trajectory workflow. We do not repeat it here
* because most of those characteristics are individual, not enterprise, traits.
*------------------------------------------------------------------------------

*==============================================================================
* 5.1 Verify 2018 stylized facts (Section 2.3 of the report)
*==============================================================================

use "${intermediate}/SEN_enterprises_2018.dta", clear
di as text _n "=== 2018 enterprise file loaded ==="
count
local N_ent_2018 = r(N)

* Merge in household weights for weighted shares
preserve
    use "${final}/SEN_panel_2018_2021.dta", clear
    keep grappe menage hhweight_2018 hhweight_2021
    duplicates drop grappe menage, force
    tempfile hh_weights
    save `hh_weights'
restore

merge m:1 grappe menage using `hh_weights', gen(_merge_w) keep(1 3)
di as text _n "=== Weight merge outcome (2018 enterprises) ==="
tab _merge_w

*------------------------------------------------------------------------------
* Share of enterprises with at least one non-household employee (2018)
* Reference claim: "25% of enterprises reported having at least one
*                  non-household employee"
*------------------------------------------------------------------------------

* num_emp_2018 = paid non-household employees (adult men + women), from
*                s10q62a_1 + s10q62a_2 in 02_clean_2018.do
gen byte has_nonhh_emp = (num_emp_2018 > 0) if !missing(num_emp_2018)
label variable has_nonhh_emp "Enterprise has >=1 non-household employee (2018)"

di as text _n "=== Share of enterprises with >=1 non-household employee (2018) ==="
di as text "Unweighted:"
tab has_nonhh_emp

di as text _n "Weighted (2018 hh weights):"
tab has_nonhh_emp [aw=hhweight_2018]

*------------------------------------------------------------------------------
* Share of enterprises with capital stock > 3,000 FCFA (2018)
* Reference claim: "42% reported a capital stock of more than 3,000 CFA"
*------------------------------------------------------------------------------

* value_total_2018 = sum of machines + vehicles + furniture + other,
*                    from 02_clean_2018.do
gen byte cap_gt_3000 = (value_total_2018 > 3000) if !missing(value_total_2018)
label variable cap_gt_3000 "Enterprise has capital stock > 3,000 FCFA (2018)"

di as text _n "=== Share of enterprises with capital > 3,000 FCFA (2018) ==="
di as text "Unweighted:"
tab cap_gt_3000

di as text _n "Weighted (2018 hh weights):"
tab cap_gt_3000 [aw=hhweight_2018]

*==============================================================================
* 5.2 Enterprise-level gazelle analysis
*==============================================================================
*
* Definition: an enterprise is a "gazelle" if BOTH profit and non-household
* employees increased between 2018 and 2021.
*
* Sample: enterprises present in BOTH waves (stayers). Matching is done at
* the enterprise level via enterprise_uid (household + proprietor + within-
* proprietor rank).
*
* Deflator: WDI CPI series (114.5/107.4). This matches the deflator used in
* the cross-check with other researchers' code and lets 2018 profit be
* re-expressed in 2021 prices.
*==============================================================================

* Reload 2018 enterprises (fresh, without the weight merge) so we can do the
* clean enterprise-to-enterprise merge on enterprise_uid.
use "${intermediate}/SEN_enterprises_2018.dta", clear

* Merge with 2021 enterprise file
merge 1:1 enterprise_uid using "${intermediate}/SEN_enterprises_2021.dta", ///
    gen(_merge_ent)

di as text _n "=== Enterprise-level merge outcome ==="
tab _merge_ent
* 1 = 2018 only (exited), 2 = 2021 only (entered), 3 = both (stayer)

gen byte ent_stayer = (_merge_ent == 3)
label variable ent_stayer "Enterprise present in both 2018 and 2021"

* Merge in household weights
merge m:1 grappe menage using `hh_weights', gen(_merge_w2) keep(1 3)
di as text _n "=== Weight merge outcome (merged enterprise panel) ==="
tab _merge_w2

*------------------------------------------------------------------------------
* Build gazelle indicator at the enterprise level
*------------------------------------------------------------------------------

local deflator = 114.5/107.4

gen dprofit_real = profit_2021 - (profit_2018 * `deflator') if ent_stayer==1
label variable dprofit_real "Change in real profit 2018->2021 (2021 FCFA)"

gen dnum_emp = num_emp_2021 - num_emp_2018 if ent_stayer==1
label variable dnum_emp "Change in non-household employees 2018->2021"

gen byte gazelle_ent = (dprofit_real > 0 & dnum_emp > 0) ///
    if !missing(dprofit_real, dnum_emp) & ent_stayer==1
label variable gazelle_ent "Enterprise-level gazelle (profit + non-family emp both grew)"
label define gazelle_ent_lbl 0 "Non-gazelle stayer" 1 "Gazelle"
label values gazelle_ent gazelle_ent_lbl

*------------------------------------------------------------------------------
* Enterprise-level gazelle share
*------------------------------------------------------------------------------

di as text _n "=== UNWEIGHTED enterprise-level gazelle share (stayers) ==="
tab gazelle_ent if ent_stayer==1

di as text _n "=== WEIGHTED enterprise-level gazelle share, 2021 hh weights ==="
tab gazelle_ent if ent_stayer==1 [aw=hhweight_2021]

di as text _n "=== WEIGHTED enterprise-level gazelle share, 2018 hh weights ==="
tab gazelle_ent if ent_stayer==1 [aw=hhweight_2018]

* Weighted headline counts
qui sum gazelle_ent if ent_stayer==1 [aw=hhweight_2021]
di as result _n "Weighted N gazelle enterprises (2021 wt): " %12.0fc r(sum_w) * r(mean)
di as result "Weighted N stayer enterprises   (2021 wt): " %12.0fc r(sum_w)
di as result "Weighted gazelle share (2021 wt): " %5.2f r(mean)*100 "%"

qui sum gazelle_ent if ent_stayer==1 [aw=hhweight_2018]
di as result _n "Weighted N gazelle enterprises (2018 wt): " %12.0fc r(sum_w) * r(mean)
di as result "Weighted N stayer enterprises   (2018 wt): " %12.0fc r(sum_w)
di as result "Weighted gazelle share (2018 wt): " %5.2f r(mean)*100 "%"

*------------------------------------------------------------------------------
* Optional: Export the merged enterprise panel for downstream use
*------------------------------------------------------------------------------

save "${final}/SEN_enterprise_panel_2018_2021.dta", replace
di as text _n "Saved enterprise panel: ${final}/SEN_enterprise_panel_2018_2021.dta"

********************************************************************************
* Section 5.3: Enterprise-level gazelle vs non-gazelle comparison
* One row per enterprise. Proprietor demographics attached from the individual panel.
********************************************************************************

* Load enterprise panel (produced at end of Section 5.2)
use "${final}/SEN_enterprise_panel_2018_2021.dta", clear
keep if ent_stayer == 1
di as text _n "=== Stayer enterprises: `= _N' ==="

*------------------------------------------------------------------------------
* Attach proprietor demographics from the individual panel
* Merge key: (grappe, menage, proprietor_id) on enterprise file
*         =  (grappe, menage, numind)         on individual panel
*------------------------------------------------------------------------------

preserve
    use "${final}/SEN_panel_2018_2021.dta", clear
    * Keep the demographic + geographic variables we want on the enterprise file
    keep grappe menage numind sexe_2018 age_2018 educ_cat_2018 mstat_2018 ///
         hhsize_2018 dep_ratio_2018 welfare_quintile_2018 ///
         has_electricity_2018 has_internet_2018 has_bank_2018 ///
         hh_received_remittances_2018 location_2018 neg_shock_2018

    * The enterprise file's proprietor_id matches the individual file's numind.
    * Some individuals appear only in one wave; keep only those with 2018 demographics.
    drop if missing(sexe_2018)
    duplicates drop grappe menage numind, force  // safety: should already be unique

    * Rename numind to proprietor_id for the merge
    rename numind proprietor_id
    tempfile prop_demo
    save `prop_demo'
restore

merge m:1 grappe menage proprietor_id using `prop_demo', gen(_merge_demo) keep(1 3)
di as text _n "=== Merge outcome: proprietor demographics onto enterprises ==="
tab _merge_demo
* Any _merge_demo==1 rows are enterprises whose proprietor isn't in the
* individual panel (e.g., not matched across waves). Sample size for the
* comparison will be based on matched rows.

*------------------------------------------------------------------------------
* Build the comparison variables
*------------------------------------------------------------------------------

* Individual (proprietor) demographics
gen byte female        = (sexe_2018 == 2)                         if !missing(sexe_2018)
gen byte edu_none      = (educ_cat_2018 == 1)                     if !missing(educ_cat_2018)
gen byte edu_lesssec   = (educ_cat_2018 == 3)                     if !missing(educ_cat_2018)
gen byte edu_secplus   = (educ_cat_2018 == 4)                     if !missing(educ_cat_2018)
gen byte married_mono  = (mstat_2018 == 2)                        if !missing(mstat_2018)
gen byte q1_poorest    = (welfare_quintile_2018 == 1)             if !missing(welfare_quintile_2018)
gen byte q5_richest    = (welfare_quintile_2018 == 5)             if !missing(welfare_quintile_2018)
gen byte loc_dakar     = (location_2018 == 1)                     if !missing(location_2018)
gen byte loc_thies     = (location_2018 == 2)                     if !missing(location_2018)
gen byte loc_otherurb  = (location_2018 == 3)                     if !missing(location_2018)
gen byte loc_rural     = (location_2018 == 4)                     if !missing(location_2018)
gen byte recv_remit    = hh_received_remittances_2018
gen byte has_bank      = has_bank_2018
gen byte has_elec      = has_electricity_2018
gen byte has_int       = has_internet_2018
gen byte neg_shock     = neg_shock_2018

* Enterprise-level baseline characteristics (already in the file)
* profit_2018, value_total_2018, num_emp_2018, num_emp_tot_2018 are already there.
* Family employees = num_emp_tot - num_emp
gen num_hhemp_2018 = num_emp_tot_2018 - num_emp_2018

* Sector at 2018 (s10q17a is the branch code - already labelled)
* Create broad sector groups
* Retail (matches "Commerce de gros, détail")
gen byte sec_retail = (s10q17a == 6) if !missing(s10q17a)

* Manufacturing (matches "Activités de fabrication")
gen byte sec_manuf = (s10q17a == 3) if !missing(s10q17a)

* Personal services (matches the "17% personal services" in the report)
gen byte sec_pers_serv = (s10q17a == 17) if !missing(s10q17a)

* Broader services bucket (finance, real estate, education, health, other services)
gen byte sec_other_serv = inlist(s10q17a, 9, 10, 12, 13, 14, 15, 16) if !missing(s10q17a)

* Hotel/restaurant
gen byte sec_hotel = (s10q17a == 7) if !missing(s10q17a)

* Transport/communication
gen byte sec_transport = (s10q17a == 8) if !missing(s10q17a)

* Construction
gen byte sec_construction = (s10q17a == 5) if !missing(s10q17a)

*------------------------------------------------------------------------------
* Diagnostic: verify gazelle counts and sample sizes before running t-tests
*------------------------------------------------------------------------------
di as text _n "=== Gazelle count in comparison sample ==="
tab gazelle_ent [aw=hhweight_2021]
count if !missing(gazelle_ent)
di as result "Unweighted enterprises with valid gazelle status: `= r(N)'"

*------------------------------------------------------------------------------
* Weighted comparison: gazelle vs non-gazelle enterprises
* Uses 2021 household weights (matching the headline gazelle share of ~5.0%)
*------------------------------------------------------------------------------

* Set up the output spreadsheet
putexcel set "$output\Gazelle_Enterprise_Comparison.xlsx", replace
putexcel A1 = "Baseline characteristic"
putexcel B1 = "Non-gazelle enterprises (mean)"
putexcel C1 = "Gazelle enterprises (mean)"
putexcel D1 = "Difference"
putexcel E1 = "p-value"
putexcel F1 = "N non-gazelle"
putexcel G1 = "N gazelle"

local row = 2

* Loop over all comparison variables
local vars_prop  "female edu_none edu_lesssec edu_secplus married_mono q1_poorest q5_richest loc_dakar loc_thies loc_otherurb loc_rural recv_remit has_bank has_elec has_int neg_shock age_2018 hhsize_2018 dep_ratio_2018"
local vars_ent   "profit_2018 value_total_2018 num_emp_2018 num_hhemp_2018 num_emp_tot_2018 sec_retail sec_manuf sec_pers_serv sec_other_serv sec_hotel sec_transport sec_construction"

foreach v in `vars_prop' `vars_ent' {
    di as text _n "--- `v' (weighted, 2021 hh weights) ---"
    * svy-style weighted mean by gazelle group
    quietly mean `v' [pw=hhweight_2021] if !missing(gazelle_ent), over(gazelle_ent)
    matrix M = e(b)
    local mean_ng = M[1,1]
    local mean_g  = M[1,2]

    * Unweighted t-test for significance (weighted t-tests need svyset structure)
    quietly ttest `v', by(gazelle_ent)
    local pval = r(p)
    local n_ng = r(N_1)
    local n_g  = r(N_2)
    local diff = `mean_g' - `mean_ng'

    di as result "  Non-gazelle mean: " %10.3f `mean_ng'
    di as result "  Gazelle mean:     " %10.3f `mean_g'
    di as result "  Difference:       " %10.3f `diff'
    di as result "  p-value:          " %6.4f `pval'
    di as result "  N non-gazelle:    `n_ng'    N gazelle: `n_g'"

    * Write to Excel
    putexcel A`row' = "`v'"
    putexcel B`row' = `mean_ng'
    putexcel C`row' = `mean_g'
    putexcel D`row' = `diff'
    putexcel E`row' = `pval'
    putexcel F`row' = `n_ng'
    putexcel G`row' = `n_g'
    local ++row
}

di as text _n "=== Written to Gazelle_Enterprise_Comparison.xlsx ==="

log close


* 1. increase employees 
cd "D:\david\SPJ_microenterprises\Programs"
local table "Table6" 
use "../intermediate_data/SEN_entrepreneurs", replace
 




gen demp=num_emp_2021-num_emp  
 

gen demp_cat=1 if demp<0 
replace demp_cat=2 if demp==0 
replace demp_cat=3 if demp>0 & demp<.  
label define demp_cat 1 "<0" 2 "0" 3 ">0"
label val demp_cat demp_cat 
drop if age_2018<15 


recode age_2018 (15/29=1 "15-29") (30/44=2 "30-44") (45/64=3 "45-64") (64/120=4 "65+"), gen(age_cat)

recode educ_hi_2018 (1=1 "Less than primary") (3=2 "Less than Secondary") (4/9 = 3 "Secondary+"), gen(educ)
replace educ=1 if educ_scol_2018==1 
replace educ=3 if educ_scol_2018>1 & educ_scol_2018<. 

xtile pcexpQ=pcexp [aw=hhweight], nq(5)

recode year_est (1940/1999.5=1 "<2000") (2000/2009=2 "2000-2009") (2010/2014 = 3 "2010-2014") (2015/2019 = 4 "2015-2019"), gen(firm_age)

recode num_emp (0=0 "0") (1=1 "1") (2/100=2 "2+"), gen(emp_cat)

recode num_hhemp (0=0 "0") (1=1 "1") (2/100=2 "2+"), gen(emphh_cat)

replace ethnie=99 if ethnie==. 


gen ln_num_emp_2021=log(num_emp_2021)
gen ln_num_emp=log(num_emp)

gen lnprofit_2021=max(log(profit_2021),0) if profit_2021<. 
gen lnprofit=max(log(profit),0) if profit<. 
gen lnvalue_total_2021=max(log(value_total_2021),0) if value_total_2021<. 
gen lnvalue_total=max(log(value_total),0) if value_total<. 

sum num_emp_2021 [aw=hhweight], d
sum num_emp [aw=hhweight], d

regress num_emp_2021 num_emp lnprofit lnvalue_total i.sexe i.age_cat i.milieu i.zae i.ethnie i.alfab_2018 i.educ i.internet i.elec_ac i.pcexpQ i.firm_age i.emphh_cat ib5.sector i.place i.financing ib2.s10q45? i.firm_keeps_accounts i. firm_has_fisc_id i.firm_in_trade_register [aw=hhweight], robust baselevels cluster(grappe)
xx

putexcel set ../output/Coefficients.xlsx, modify sheet("num_emp")
putexcel B1 = "Variable"
putexcel C1 = "Coefficient" 
putexcel D1 = "Std Error"

matrix results = r(table)'
matrix coef = results[1..., 1]      // First column is coefficients
matrix se = results[1..., 2]        // Second column is standard errors

 
putexcel C2 = matrix(coef), rownames
putexcel E2 = matrix(se) 

* oprobit demp_cat i.sexe_2018 i.age_cat i.milieu i.zae i.ethnie i.alfa2 i.educ i.internet i.elec_ac i.pcexpQ i.firm_age i.emp_cat i.emphh_cat i.sector i.place i.financing i.s10q45* [aw=hhweight], robust 
*margins, dydx(*) vce(unconditional) post 
* estimates save oprobit_dempcat_margins, replace 



* profit  
* gen lnprofit_2021=max(log(profit_2021),5.2) if profit_2021<. 

su lnprofit [aw=hhweight], d
su lnprofit_2021 [aw=hhweight], d


* qreg lnprofit_2021 lnprofit lnvalue_total i.sexe_2018 i.age_cat i.milieu i.zae i.ethnie i.alfab_2018  i.educ i.internet i.elec_ac i.pcexpQ i.firm_age i.emp_cat i.emphh_cat ib5.sector i.place i.financing ib2.s10q45? i.firm_keeps_accounts i. firm_has_fisc_id i.firm_in_trade_register [iw=hhweight], vce(robust) baselevels iterate(2000)


regress lnprofit_2021 lnprofit lnvalue_total i.sexe_2018 i.age_cat i.milieu i.zae i.ethnie i.alfab_2018  i.educ i.internet i.elec_ac i.pcexpQ i.firm_age i.emp_cat i.emphh_cat ib5.sector i.place i.financing ib2.s10q45? i.firm_keeps_accounts i. firm_has_fisc_id i.firm_in_trade_register [aw=hhweight], robust baselevels cluster(grappe)

putexcel set ../output/Coefficients.xlsx, modify sheet("profit")
putexcel B1 = "Variable"
putexcel C1 = "Coefficient" 
putexcel D1 = "Std Error"

matrix results = r(table)'
matrix coef = results[1..., 1]      // First column is coefficients
matrix se = results[1..., 2]        // Second column is standard errors



putexcel C2 = matrix(coef), rownames
putexcel E2 = matrix(se) 


tab sexe_2018 [aw=hhweight] if e(sample)
tab age_cat [aw=hhweight] if e(sample)
tab milieu [aw=hhweight] if e(sample)
tab internet [aw=hhweight] if e(sample)
tab elec_ac [aw=hhweight] if e(sample)
tab sector [aw=hhweight] if e(sample)
tab firm_age [aw=hhweight] if e(sample)
tab place [aw=hhweight] if e(sample)
tab sector [aw=hhweight] if e(sample)

foreach var of varlist s10q45? {
	tab `var' [aw=hhweight] if e(sample) 
} 

tab firm_keeps_accounts [aw=hhweight] if e(sample)
tab firm_has_fisc_id [aw=hhweight] if e(sample)
tab firm_in_trade_register [aw=hhweight] if e(sample)



* regress value_total_2021 value_total i.sexe i.age_cat i.milieu i.zae i.ethnie i.alfa2 i.educ i.internet i.elec_ac i.pcexpQ i.firm_age i.emp_cat i.emphh_cat i.sector i.place i.financing i.s10q45* [aw=hhweight], robust baselevels

su lnvalue_total [aw=hhweight], d
su lnvalue_total_2021 [aw=hhweight], d

* qreg lnvalue_total_2021 lnvalue_total lnprofit i.sexe_2018 i.age_cat i.milieu i.zae i.ethnie i.alfab_2018  i.educ i.internet i.elec_ac i.pcexpQ i.firm_age i.emp_cat i.emphh_cat ib5.sector i.place i.financing ib2.s10q45? i.firm_keeps_accounts i. firm_has_fisc_id i.firm_in_trade_register [iw=hhweight], vce(robust) iterate(2000)


regress lnvalue_total_2021 lnvalue_total lnprofit i.sexe_2018 i.age_cat i.milieu i.zae i.ethnie i.alfab_2018  i.educ i.internet i.elec_ac i.pcexpQ i.firm_age i.emp_cat i.emphh_cat ib5.sector i.place i.financing ib2.s10q45? i.firm_keeps_accounts i. firm_has_fisc_id i.firm_in_trade_register [aw=hhweight], robust baselevels cluster(grappe)





putexcel set ../output/Coefficients.xlsx, modify sheet("capital")
putexcel C1 = "Variable"
putexcel D1 = "Coefficient" 
putexcel E1 = "Std Error"

matrix results = r(table)'
matrix coef = results[1..., 1]      // First column is coefficients
matrix se = results[1..., 2]        // Second column is standard errors

putexcel C2 = matrix(coef), rownames
putexcel E2 = matrix(se) 

*gen positive_value_total_2021=value_total_2021>0 
*regress positive_value_total_2021 value_total i.sexe_2018 i.age_cat i.milieu i.zae i.ethnie i.alfa2 i.educ i.internet i.elec_ac i.pcexpQ i.firm_age i.emp_cat i.emphh_cat i.sector i.place i.financing i.s10q45* [aw=hhweight], robust baselevels
*regress lnvalue_total_2021 lnvalue_total i.sexe_2018 i.age_cat i.milieu i.zae i.ethnie i.alfa2 i.educ i.internet i.elec_ac i.pcexpQ i.firm_age i.emp_cat i.emphh_cat i.sector i.place i.financing i.s10q45* [aw=hhweight] if positive_value_total_2021==1, robust baselevels

gen exit_ent=0 if ent_2021==1 // remain enterpreneurs  
replace exit_ent=1 if ent_2021==0 & activ7j_2021==1 & hcsp_2018<=6
replace exit_ent=2 if ent_2021==0 & activ7j_2021==1 & hcsp_2018>=7 & hcsp<=11 
replace exit_ent=3 if ent_2021==0 & activ7j_2021!=1
label define exit_ent 0 "Remain enterpreneurs" 1 "Working in wage job" 2 "Working in non-wage job" 3 "Not working"
label val exit_ent exit_ent 
recode year_est_2021 (1920/1999.5=1 "<2000") (2000/2009=2 "2000-2009") (2010/2014 = 3 "2010-2014") (2015/2022 = 4 "2015-2022"), gen(firm_age_21)
recode num_emp_2021 (0=0 "0") (1=1 "1") (2/100=2 "2+"), gen(emp_cat_21)
recode num_hhemp_2021 (0=0 "0") (1=1 "1") (2/100=2 "2+"), gen(emphh_cat_21)


mlogit exit_ent i.sexe_2018 i.age_cat i.milieu i.zae i.ethnie i.alfab_2018  i.educ i.internet i.elec_ac i.pcexpQ i.firm_age i.emp_cat i.emphh_cat ib5.sector i.place i.financing ib2.s10q45? i.firm_keeps_accounts i.firm_has_fisc_id i.firm_in_trade_register [pw=hhweight], robust baselevels cluster(grappe)


tab sexe_2018 [aw=hhweight] if e(sample)
tab milieu [aw=hhweight] if e(sample)
tab age_cat [aw=hhweight] if e(sample)
tab internet [aw=hhweight] if e(sample)
tab elec_ac [aw=hhweight] if e(sample)
tab sector [aw=hhweight] if e(sample)
foreach var of varlist s10q45? {
tab `var' [aw=hhweight] if e(sample) 
}

tab firm_keeps_accounts [aw=hhweight] if e(sample)
tab firm_has_fisc_id [aw=hhweight] if e(sample)
tab firm_in_trade_register [aw=hhweight] if e(sample)

tab  sector sexe_2018 [aw=hhweight] if e(sample), col nofreq 



estimates store mlogit 
*margins, dydx(*) vce(unconditional) post 
*estimates save exit_ent_margins, replace 

// Get margins without post
margins, dydx(*) predict(outcome(0)) vce(unconditional)
matrix m1 = r(table)'

margins, dydx(*) predict(outcome(1)) vce(unconditional)
matrix m2 = r(table)'

margins, dydx(*) predict(outcome(2)) vce(unconditional)
matrix m3 = r(table)'

margins, dydx(*) predict(outcome(3)) vce(unconditional)
matrix m4 = r(table)'


// Now export using putexcel
putexcel set ../output/Coefficients.xlsx, modify sheet("remain_entrepreneur")
putexcel D1 = "Remain enterpreneur" E1 = "SE"
putexcel F1 = "Working in wage job" G1 = "SE"
putexcel H1 = "Working in non-wage job" I1 = "SE"
putexcel J1 = "Not working" K1 = "SE"

putexcel C2 = matrix(m1[1..., 1..2]), rownames
putexcel F2 = matrix(m2[1..., 1..2])
putexcel H2 = matrix(m3[1..., 1..2])
putexcel J2 = matrix(m4[1..., 1..2])



gen enter_ent=0 if ent_2021==1 & ent_2018==1 // were entrepreneur before 
replace enter_ent=1 if ent_2021==1 & ent_2018==0 & activ7j_2018==1 & hcsp_2018<=6
replace enter_ent=2 if ent_2021==1 & ent_2018==0 & activ7j_2018==1 & hcsp_2018>=7 & hcsp_2018<=11 
replace enter_ent=3 if ent_2021==1 & ent_2018==0 & activ7j_2018!=1 


mlogit enter_ent i.sexe_2018 i.age_cat i.milieu i.zae i.ethnie i.alfab_2018  i.educ i.internet i.elec_ac i.pcexpQ i.firm_age_21 i.emp_cat_21 i.emphh_cat_21 ib5.sector_2021 i.place_2021 i.financing_2021 ib2.s10q45?_2021 i.firm_keeps_accounts_2021 i. firm_has_fisc_id_2021 i.firm_in_trade_register_2021 [pw=hhweight], robust baselevels cluster(grappe)

estimates store mlogit_enter  

// Get margins without post
margins, dydx(*) predict(outcome(0)) vce(unconditional)
matrix m1 = r(table)'

margins, dydx(*) predict(outcome(1)) vce(unconditional)
matrix m2 = r(table)'

margins, dydx(*) predict(outcome(2)) vce(unconditional)
matrix m3 = r(table)'

margins, dydx(*) predict(outcome(3)) vce(unconditional)
matrix m4 = r(table)'



putexcel set ../output/Coefficients.xlsx, modify sheet("become_entrepreneur")

putexcel D1 = "Was enterpreneur" E1 = "SE"
putexcel F1 = "Was working in wage job" G1 = "SE"
putexcel H1 = "Was working in non-wage job" I1 = "SE"
putexcel J1 = "Was not working" K1 = "SE"

putexcel C2 = matrix(m1[1..., 1..2]), rownames
putexcel F2 = matrix(m2[1..., 1..2])
putexcel H2 = matrix(m3[1..., 1..2])
putexcel J2 = matrix(m4[1..., 1..2])

** exit sample profile 
tab sexe [aw=hhweight] if e(sample)
tab milieu [aw=hhweight] if e(sample)
tab internet [aw=hhweight] if e(sample)
tab elec_ac [aw=hhweight] if e(sample)
tab sector [aw=hhweight] if e(sample)


foreach var of varlist s10q45?_2021 {
	tab `var' [aw=hhweight] if e(sample) 
} 

tab firm_keeps_accounts [aw=hhweight] if e(sample)
tab firm_has_fisc_id [aw=hhweight] if e(sample)
tab firm_in_trade_register [aw=hhweight] if e(sample)
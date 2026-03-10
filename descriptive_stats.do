use "../intermediate_data/SEN_entrepreneurs", replace
gen lnprofit_2021=max(log(profit_2021),0) if profit_2021<. 
gen lnprofit=max(log(profit),0) if profit<. 
gen lnvalue_total_2021=max(log(value_total_2021),0) if value_total_2021<. 
gen lnvalue_total=max(log(value_total),0) if value_total<. 
keep if ent_2018==1 | ent_2021==1 


local varlist "lnprofit_2021 lnprofit lnvalue_total_2021 lnvalue_total num_emp_2021 num_emp i2.sexe i2.milieu i1.internet i1.elec_ac i1.s10q45? i1.firm_keeps_accounts i1.firm_has_fisc_id i1.firm_in_trade_register"

table [aw=hhweight], statistic(p10 `varlist')    ///
       statistic(p50 `varlist')    ///
       statistic(p90 `varlist')    ///
       statistic(mean `varlist')   ///
       statistic(sd `varlist')     ///
       statistic(count `varlist')

collect layout (var) (result)
collect style cell result[mean sd], nformat(%9.2f)
collect style cell result[p10 p50 p90], nformat(%9.1f)
collect style cell result[count], nformat(%9.0f)
collect export "D:\david\SPJ_microenterprises\output\descriptive_stats.xlsx", replace sheet("descriptive_stats") cell(C2) modify

use "../intermediate_data/SEN_entrepreneurs", replace
keep if ent_2018==1 
summarize profit [aw=hhweight], d
replace profit=r(p99) if profit>r(p99) & profit<. 
replace profit=r(p1) if profit<r(p1) 
replace num_emp=10 if num_emp>10 

summarize value_total [aw=hhweight], d
replace value_total=1000000 if value_total>1000000 & value_total<. 

replace value_total=value_total/1000 
replace profit=profit/1000 


histogram profit [fw=int(hhweight)], bins(20) percent xlabel(-500(200)1000 0) ylabel(0(5)55) xtitle("") saving(hist_profit, replace) name(hist_profit, replace)
histogram num_emp [fw=int(hhweight)], bins(40) percent ylabel(0(5)80) saving(hist_num_emp, replace) xtitle("") name(hist_num_emp, replace)
histogram value_total [fw=int(hhweight)], bins(20) percent xlabel(0(100)1000) ylabel(0(5)80) saving(hist_value_total, replace) xtitle("") name(hist_value_total,replace)
 

keep if ent_2021==1 

gen dprofit=profit_2021-(profit*114.5/107.4) // use WDI CPI 
su dprofit [aw=hhweight], d
replace dprofit=r(p99) if dprofit>r(p99) & dprofit<. 
replace dprofit=r(p1) if dprofit<r(p1)
su profit, d
replace dprofit=dprofit/1000 

histogram dprofit [fw=int(hhweight)], bins(20) percent xlabel(-800(200)2000 0) ylabel(0(5)55) xtitle("") saving(hist_dprofit, replace) name(hist_dprofit, replace) 
gen dnum_emp=num_emp_2021-num_emp
replace dnum_emp=-10 if dnum_emp<-10 
replace dnum_emp=10 if dnum_emp>10  & dnum_emp<. 
su dnum_emp [aw=hhweight]
histogram dnum_emp [fw=int(hhweight)], bins(40) percent xlabel(-10(1)10 0) ylabel(0(5)75) xtitle("") saving(hist_dnum_emp, replace) name(hist_dnum_emp, replace) 

gen dvalue_total=value_total_2021-value_total*114.5/107.4

su dvalue_total [aw=hhweight], d 
replace dvalue_total=2000000 if dvalue_total>2000000 & dvalue_total<. 
replace dvalue_total=dvalue_total/1000 
histogram dvalue_total [fw=int(hhweight)], bins(20) percent xlabel(0(200)2000) ylabel(0(5)80) xtitle("") saving(hist_dvalue_emp, replace) name(hist_dvalue_emp, replace) 

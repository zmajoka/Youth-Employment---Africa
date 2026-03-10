********************************************************************************
* EHCVM SENEGAL - HOUSEHOLD ENTERPRISE ANALYSIS
* MASTER DO-FILE
********************************************************************************
* Purpose: Run all cleaning and analysis do-files in sequence
* Author: Zaineb Majoka (mzaineb@worldbank.org). 
* Based on do-files shared by David Newhouse and Joseph
* Date: March 2026

* INSTRUCTIONS:
* 1. Update the project path in Section 1 below
* 2. Set which files to run in Section 2
* 3. Run this file - it will execute all selected do-files
********************************************************************************

clear all
set more off
set maxvar 10000
version 19.5  // Adjust to your Stata version

********************************************************************************
* SECTION 1: SET YOUR PROJECT PATH
********************************************************************************

* Project folder path
global project "C:\Users\WB461621\OneDrive - WBG\SPJ\West Africa\Regional HH Enterprise Work"

* Log files directory 
global log "C:\Users\WB461621\OneDrive - WBG\SPJ\West Africa\Regional HH Enterprise Work\Logs\SEN"

*Do-files directory 
global dos "C:\Users\WB461621\OneDrive - WBG\SPJ\West Africa\Regional HH Enterprise Work\Do files\SEN"


********************************************************************************
* SECTION 2: CHOOSE WHICH STEPS TO RUN
********************************************************************************

* Set to 1 to run, 0 to skip
global run_config      = 1  // Load configuration (ALWAYS run this)
global run_clean_2018  = 1  // Clean 2018 data
global run_clean_2021  = 1  // Clean 2021 data
global run_panel       = 1  // Create panel dataset & match individuals
global run_construct   = 1  // Construct all analysis variables
global run_descriptive = 1  // Generate descriptive statistics
global run_regressions = 1  // Run all regressions
global run_graphs      = 1  // Create all graphs
global run_export      = 1  // Export results to Excel

********************************************************************************
* SECTION 3: RUN THE DO-FILES
********************************************************************************

* Start log file
log using "${log}/master_log_$S_DATE.log", replace text

di as result _newline(2) "{hline 80}"
di as result "EHCVM HOUSEHOLD ENTERPRISE ANALYSIS - MASTER DO-FILE"
di as result "Started: $S_DATE $S_TIME"
di as result "{hline 80}" _newline

* --- Configuration (REQUIRED) ---
if $run_config {
    di as result _newline ">>> Running 01_config.do..."
    do "${dos}/01_config.do"
    di as result ">>> 01_config.do completed" _newline
}
else {
    di as error "ERROR: Configuration file must be run!"
    di as error "Set global run_config = 1"
    exit
}

* --- Clean 2018 Data ---
if $run_clean_2018 {
    di as result _newline(2) "{hline 80}"
    di as result ">>> Running 02_clean_2018.do..."
    di as result "{hline 80}"
    do "${dos}/02_clean_2018.do"
    di as result _newline ">>> 02_clean_2018.do completed" _newline
}

* --- Clean 2021 Data ---
if $run_clean_2021 {
    di as result _newline(2) "{hline 80}"
    di as result ">>> Running 03_clean_2021.do..."
    di as result "{hline 80}"
    do "${dos}/03_clean_2021.do"
    di as result _newline ">>> 03_clean_2021.do completed" _newline
}

* --- Create Panel Dataset ---
if $run_panel {
    di as result _newline(2) "{hline 80}"
    di as result ">>> Running 04_panel_construction.do..."
    di as result "{hline 80}"
    do "${dos}/04_panel_construction.do"
    di as result _newline ">>> 04_panel_construction.do completed" _newline
}

* --- Construct Analysis Variables ---
if $run_construct {
    di as result _newline(2) "{hline 80}"
    di as result ">>> Running 05_variable_construction.do..."
    di as result "{hline 80}"
    do "${dos}/05_variable_construction.do"
    di as result _newline ">>> 05_variable_construction.do completed" _newline
}

* --- Descriptive Statistics ---
if $run_descriptive {
    di as result _newline(2) "{hline 80}"
    di as result ">>> Running 06_descriptive_stats.do..."
    di as result "{hline 80}"
    do "${dos}/06_descriptive_stats.do"
    di as result _newline ">>> 06_descriptive_stats.do completed" _newline
}

* --- Regressions ---
if $run_regressions {
    di as result _newline(2) "{hline 80}"
    di as result ">>> Running 07_regressions.do..."
    di as result "{hline 80}"
    do "${dos}/07_regressions.do"
    di as result _newline ">>> 07_regressions.do completed" _newline
}

* --- Graphs ---
if $run_graphs {
    di as result _newline(2) "{hline 80}"
    di as result ">>> Running 08_graphs.do..."
    di as result "{hline 80}"
    do "${dos}/08_graphs.do"
    di as result _newline ">>> 08_graphs.do completed" _newline
}

* --- Export Results ---
if $run_export {
    di as result _newline(2) "{hline 80}"
    di as result ">>> Running 09_export_results.do..."
    di as result "{hline 80}"
    do "${dos}/09_export_results.do"
    di as result _newline ">>> 09_export_results.do completed" _newline
}

********************************************************************************
* COMPLETION MESSAGE
********************************************************************************

di as result _newline(2) "{hline 80}"
di as result "ALL SELECTED DO-FILES COMPLETED SUCCESSFULLY!"
di as result "Completed: $S_DATE $S_TIME"
di as result "{hline 80}" _newline

log close

********************************************************************************
* END OF MASTER DO-FILE
********************************************************************************

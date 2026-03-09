********************************************************************************
* EHCVM SENEGAL - EXTRACT VARIABLE CODEBOOK TO EXCEL
********************************************************************************
* Purpose: Extract variable metadata (names, types, labels, value labels)
*          from all raw datasets used in the 2018 and 2021 cleaning do-files
*          and export to Excel following the codebook_template.xlsx format.
*
* Author:  Auto-generated for Zaineb Majoka
* Date:    March 2026
*
* OUTPUT:  ${output}/SEN_codebook_2018.xlsx
*          ${output}/SEN_codebook_2021.xlsx
*
* INSTRUCTIONS:
*   1. Set your project path in PART 0 below
*   2. Run this entire do-file in Stata
*   3. The output Excel files will have two sheets each:
*      - "Variable Codebook" with all variable metadata
*      - "Value Label Definitions" with all value-label mappings
*
* NOTE: This do-file only READS data — it does not modify any files.
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
global output        "${project}/Output/SEN"

* Create output directory if needed
capture mkdir "${output}"

********************************************************************************
* PROGRAM: EXTRACT CODEBOOK FROM A SINGLE DATASET
********************************************************************************
* This program loads a dataset, extracts all variable metadata, and appends
* it to a running codebook file.
*
* Arguments:
*   1 = full file path to dataset (without .dta)
*   2 = dataset short name (e.g., "s10_2_me_sen2018")
*   3 = questionnaire section (e.g., "Section 10")
*   4 = path to codebook tempfile
*   5 = path to value labels tempfile

capture program drop extract_codebook
program define extract_codebook
    args filepath dataname section codebook_file vallabel_file

    di as text _n "=============================================="
    di as text "Processing: `dataname'"
    di as text "=============================================="

    * Load the dataset
    capture use "`filepath'", clear
    if _rc != 0 {
        di as error "WARNING: Could not load `filepath' — skipping."
        exit
    }

    * Get number of variables
    qui describe, short
    local nvars = r(k)
    local nobs  = r(N)

    di as text "  Variables: `nvars'  |  Observations: `nobs'"

    *--------------------------------------------------------------------------
    * STEP 1: Extract variable-level metadata
    *--------------------------------------------------------------------------

    * Store variable info in locals
    local varnames ""
    local vartypes ""
    local varlabels ""
    local valuelabelnames ""

    foreach v of varlist * {
        local varnames   "`varnames' `v'"
        local type_`v' : type `v'
        local label_`v' : variable label `v'
        local vallbl_`v' : value label `v'
    }

    *--------------------------------------------------------------------------
    * STEP 2: Extract value label definitions BEFORE clearing data
    *--------------------------------------------------------------------------

    * Capture all value labels currently in memory
    * We use label dir to get label names, then label list to get values

    qui label dir
    local all_labels `r(names)'

    * For each label, extract value-label pairs
    * We'll store them temporarily and write after

    * Count total value-label pairs for pre-allocation
    local total_pairs = 0
    foreach lbl of local all_labels {
        capture label list `lbl'
        if _rc == 0 {
            * Count lines in the label
            * We'll process this properly below
            local total_pairs = `total_pairs' + 50  // generous pre-allocation
        }
    }

    * Create a temporary dataset for value labels from this file
    preserve
        clear
        local pair_count = 0

        foreach lbl of local all_labels {
            * Get the min and max values for this label
            capture label list `lbl'
            if _rc == 0 {
                * Use a mata approach to extract label values
                * First, find what values have labels
                mata: st_local("lbl_text", "")
            }
        }
    restore

    * --- Write value labels using a reliable method ---
    preserve
        clear

        * We'll build the value label dataset row by row
        * Start with an empty dataset
        gen str80 label_name = ""
        gen int value = .
        gen str244 label_text = ""
        gen str80 source_dataset = ""
        gen str80 notes = ""
        local obs_counter = 0

        foreach lbl of local all_labels {
            * Try values from -100 to 200 (covers most survey codes)
            * Also try larger values up to 999 for region/district codes
            forvalues val = -10/999 {
                local this_text : label `lbl' `val', strict
                if `"`this_text'"' != "" {
                    local ++obs_counter
                    qui set obs `obs_counter'
                    qui replace label_name = "`lbl'" in `obs_counter'
                    qui replace value = `val' in `obs_counter'
                    qui replace label_text = `"`this_text'"' in `obs_counter'
                    qui replace source_dataset = "`dataname'" in `obs_counter'
                }
            }
        }

        if `obs_counter' > 0 {
            * Append to running value label file
            capture confirm file "`vallabel_file'"
            if _rc == 0 {
                append using "`vallabel_file'"
            }
            * Remove duplicate label definitions (same label_name + value)
            * Keep only unique definitions
            bysort label_name value (source_dataset): keep if _n == 1
            qui save "`vallabel_file'", replace
            di as text "  Value labels extracted: `obs_counter' pairs"
        }
        else {
            di as text "  No value labels found in this dataset"
        }
    restore

    *--------------------------------------------------------------------------
    * STEP 3: Build codebook dataset for this file
    *--------------------------------------------------------------------------

    * Now create the codebook entries
    clear
    local nvars_list : word count `varnames'
    qui set obs `nvars_list'

    * Initialize all columns from the template
    gen str80  variable_name   = ""
    gen str40  section         = ""
    gen str244 source_question = ""
    gen str20  type            = ""
    gen str244 label           = ""
    gen str244 value_labels    = ""
    gen str40  valid_range     = ""
    gen str80  skip_logic      = ""
    gen str80  missing_codes   = ""
    gen str244 notes           = ""
    gen str80  source_dataset  = ""

    local i = 0
    foreach v of local varnames {
        local ++i

        * Variable name
        qui replace variable_name = "`v'" in `i'

        * Section
        qui replace section = "`section'" in `i'

        * Type
        qui replace type = "`type_`v''" in `i'

        * Variable label → goes into both "label" and "source_question"
        * The variable label often contains the original question text
        local clean_label = subinstr(`"`label_`v''"', `"""', "", .)
        qui replace label = `"`clean_label'"' in `i'

        * Source question: use variable label (often contains question number)
        qui replace source_question = `"`clean_label'"' in `i'

        * Value labels: store the label name so user knows which label applies
        if "`vallbl_`v''" != "" {
            qui replace value_labels = "`vallbl_`v''" in `i'
        }

        * Source dataset
        qui replace source_dataset = "`dataname'" in `i'

        * Notes: flag ID variables
        if inlist("`v'", "grappe", "menage", "hhid", "numind", "membres__id", "vague") {
            qui replace notes = "Identifier variable" in `i'
        }
    }

    * Append to running codebook file
    capture confirm file "`codebook_file'"
    if _rc == 0 {
        append using "`codebook_file'"
    }
    qui save "`codebook_file'", replace

    di as text "  Codebook entries added: `nvars_list'"

end


********************************************************************************
* PART 1: EXTRACT CODEBOOK FOR 2018 DATASETS
********************************************************************************

di as text _n "***********************************************************"
di as text "EXTRACTING 2018 CODEBOOK"
di as text "***********************************************************"

* Create tempfiles for accumulating results
tempfile codebook_2018 vallabels_2018

* --- Dataset 1: Enterprise data (Section 10) ---
extract_codebook "${data_2018}/s10_2_me_sen2018" ///
    "s10_2_me_sen2018" "Section 10 - Enterprise" ///
    "`codebook_2018'" "`vallabels_2018'"

* --- Dataset 2: Individual-level data ---
extract_codebook "${data_2018}/ehcvm_individu_sen2018" ///
    "ehcvm_individu_sen2018" "Individual characteristics" ///
    "`codebook_2018'" "`vallabels_2018'"

* --- Dataset 3: Section 1 roster (ethnicity) ---
extract_codebook "${data_2018}/s01_me_sen2018" ///
    "s01_me_sen2018" "Section 1 - Household roster" ///
    "`codebook_2018'" "`vallabels_2018'"

* --- Dataset 4: Section 4 employment ---
extract_codebook "${data_2018}/s04_me_sen2018" ///
    "s04_me_sen2018" "Section 4 - Employment" ///
    "`codebook_2018'" "`vallabels_2018'"

* --- Dataset 5: Household-level data ---
extract_codebook "${data_2018}/ehcvm_menage_sen2018" ///
    "ehcvm_menage_sen2018" "Household characteristics" ///
    "`codebook_2018'" "`vallabels_2018'"

* --- Dataset 6: Welfare/socioeconomic data ---
extract_codebook "${data_2018}/ehcvm_welfare_sen2018" ///
    "ehcvm_welfare_sen2018" "Welfare/poverty" ///
    "`codebook_2018'" "`vallabels_2018'"

* --- Dataset 7: Section 6 credit ---
extract_codebook "${data_2018}/s06_me_sen2018" ///
    "s06_me_sen2018" "Section 6 - Credit" ///
    "`codebook_2018'" "`vallabels_2018'"

* --- Dataset 8: Section 13 remittances ---
extract_codebook "${data_2018}/s13a_2_me_sen2018" ///
    "s13a_2_me_sen2018" "Section 13 - Remittances" ///
    "`codebook_2018'" "`vallabels_2018'"

*--------------------------------------------------------------------------
* Export 2018 codebook to Excel
*--------------------------------------------------------------------------

di as text _n "Exporting 2018 codebook to Excel..."

* Export Variable Codebook sheet
use "`codebook_2018'", clear

* Order columns to match template
order variable_name section source_question type label value_labels ///
      valid_range skip_logic missing_codes notes source_dataset

* Sort by source dataset and variable name
sort source_dataset variable_name

export excel using "${output}/SEN_codebook_2018.xlsx", ///
    sheet("Variable Codebook") sheetreplace firstrow(variables)

* Export Value Label Definitions sheet
capture confirm file "`vallabels_2018'"
if _rc == 0 {
    use "`vallabels_2018'", clear
    sort label_name value
    export excel using "${output}/SEN_codebook_2018.xlsx", ///
        sheet("Value Label Definitions") sheetreplace firstrow(variables)
}

di as result "2018 codebook saved to: ${output}/SEN_codebook_2018.xlsx"


********************************************************************************
* PART 2: EXTRACT CODEBOOK FOR 2021 DATASETS
********************************************************************************

di as text _n "***********************************************************"
di as text "EXTRACTING 2021 CODEBOOK"
di as text "***********************************************************"

* Create new tempfiles for 2021
tempfile codebook_2021 vallabels_2021

* --- Dataset 1: Enterprise data (Section 10b) ---
extract_codebook "${data_2021}/s10b_me_sen2021" ///
    "s10b_me_sen2021" "Section 10 - Enterprise" ///
    "`codebook_2021'" "`vallabels_2021'"

* --- Dataset 2: Individual-level data ---
extract_codebook "${data_2021}/ehcvm_individu_sen2021" ///
    "ehcvm_individu_sen2021" "Individual characteristics" ///
    "`codebook_2021'" "`vallabels_2021'"

* --- Dataset 3: Section 4a employment status ---
extract_codebook "${data_2021}/s04a_me_sen2021" ///
    "s04a_me_sen2021" "Section 4a - Employment status" ///
    "`codebook_2021'" "`vallabels_2021'"

* --- Dataset 4: Section 4b primary job details ---
extract_codebook "${data_2021}/s04b_me_sen2021" ///
    "s04b_me_sen2021" "Section 4b - Primary job" ///
    "`codebook_2021'" "`vallabels_2021'"

* --- Dataset 5: Section 4c secondary job details ---
extract_codebook "${data_2021}/s04c_me_sen2021" ///
    "s04c_me_sen2021" "Section 4c - Secondary job" ///
    "`codebook_2021'" "`vallabels_2021'"

* --- Dataset 6: Household-level data ---
extract_codebook "${data_2021}/ehcvm_menage_sen2021" ///
    "ehcvm_menage_sen2021" "Household characteristics" ///
    "`codebook_2021'" "`vallabels_2021'"

* --- Dataset 7: Welfare/socioeconomic data ---
extract_codebook "${data_2021}/ehcvm_welfare_sen2021" ///
    "ehcvm_welfare_sen2021" "Welfare/poverty" ///
    "`codebook_2021'" "`vallabels_2021'"

* --- Dataset 8: Section 6 credit ---
extract_codebook "${data_2021}/s06_me_sen2021" ///
    "s06_me_sen2021" "Section 6 - Credit" ///
    "`codebook_2021'" "`vallabels_2021'"

* --- Dataset 9: Section 13 remittances ---
extract_codebook "${data_2021}/s13_2_me_sen2021" ///
    "s13_2_me_sen2021" "Section 13 - Remittances" ///
    "`codebook_2021'" "`vallabels_2021'"

*--------------------------------------------------------------------------
* Export 2021 codebook to Excel
*--------------------------------------------------------------------------

di as text _n "Exporting 2021 codebook to Excel..."

* Export Variable Codebook sheet
use "`codebook_2021'", clear

* Order columns to match template
order variable_name section source_question type label value_labels ///
      valid_range skip_logic missing_codes notes source_dataset

* Sort by source dataset and variable name
sort source_dataset variable_name

export excel using "${output}/SEN_codebook_2021.xlsx", ///
    sheet("Variable Codebook") sheetreplace firstrow(variables)

* Export Value Label Definitions sheet
capture confirm file "`vallabels_2021'"
if _rc == 0 {
    use "`vallabels_2021'", clear
    sort label_name value
    export excel using "${output}/SEN_codebook_2021.xlsx", ///
        sheet("Value Label Definitions") sheetreplace firstrow(variables)
}

di as result "2021 codebook saved to: ${output}/SEN_codebook_2021.xlsx"


********************************************************************************
* DONE
********************************************************************************

di as text _n "=============================================="
di as result "CODEBOOK EXTRACTION COMPLETE"
di as text "=============================================="
di as text "Output files:"
di as text "  1. ${output}/SEN_codebook_2018.xlsx"
di as text "  2. ${output}/SEN_codebook_2021.xlsx"
di as text ""
di as text "Each file has two sheets:"
di as text "  - 'Variable Codebook': variable_name, section, source_question,"
di as text "     type, label, value_labels, valid_range, skip_logic,"
di as text "     missing_codes, notes, source_dataset"
di as text "  - 'Value Label Definitions': label_name, value, label_text,"
di as text "     source_dataset, notes"
di as text ""
di as text "NEXT STEPS:"
di as text "  - Review the Excel files"
di as text "  - Fill in valid_range, skip_logic, and missing_codes"
di as text "    columns using the questionnaire PDFs"
di as text "  - The value_labels column shows which label name applies"
di as text "    to each variable; full definitions are in the second sheet"
di as text "=============================================="

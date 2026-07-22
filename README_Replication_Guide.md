# Replication Guide: Adapting Senegal EHCVM Do-Files for Other Countries

This document provides instructions for replicating the cleaning, panel creation, and analysis do-files for countries other than Senegal. It catalogs the types of errors encountered during the Senegal analysis, how to avoid them, and what information is needed to fix them.

---

## Table of Contents

1. [Overview of the Pipeline](#1-overview-of-the-pipeline)
2. [Error Category 1: Variable Name Mismatches](#2-error-category-1-variable-name-mismatches)
3. [Error Category 2: Employment and Formality Classification Errors](#3-error-category-2-employment-and-formality-classification-errors)
4. [Error Category 3: Excel Export Bugs (putexcel / tabout)](#4-error-category-3-excel-export-bugs-putexcel--tabout)
5. [Error Category 4: Dataset Structure Differences Across Waves](#5-error-category-4-dataset-structure-differences-across-waves)
6. [Error Category 5: Panel Matching and ID Construction](#6-error-category-5-panel-matching-and-id-construction)
7. [Error Category 6: File Paths and Naming Conventions](#7-error-category-6-file-paths-and-naming-conventions)
8. [Error Category 7: Country-Specific Coding Schemes](#8-error-category-7-country-specific-coding-schemes)
9. [Pre-Replication Checklist](#9-pre-replication-checklist)
10. [Quick Reference: What to Change per File](#10-quick-reference-what-to-change-per-file)

---

## 1. Overview of the Pipeline

The analysis pipeline consists of these steps:

| Step | File | Purpose |
|------|------|---------|
| 0 | `00_master.do` | Sets paths, runs all scripts |
| 1 | `01_extract_codebook.do` | Extracts variable labels from raw .dta files to Excel |
| 2 | `02_clean_2018.do` | Cleans wave 1 (2018) survey data |
| 3 | `03_clean_2021.do` | Cleans wave 2 (2021) survey data |
| 4 | `04_create_panel.do` | Matches individuals/enterprises across waves |
| 5 | `05_analysis_without graphs.do` | Produces all tables, regressions, and Excel output |

Supporting files: `regressions.do`, `descriptive_stats.do`, `Add_gov_measures_and_TFP_estimates.do`, `consumption_smoothing_enterprise.do`.

---

## 2. Error Category 1: Variable Name Mismatches

### What happened (Senegal)
The EHCVM survey uses section-based variable naming (e.g., `s10q29` for "keeps accounts"). Even within the same survey program (EHCVM), **variable names can differ across countries** due to:
- Different questionnaire versions or section numbering
- Country-specific modules added or removed
- Variables split into sub-parts in one country but not another

### How to avoid
1. **Before writing any code**, run `01_extract_codebook.do` on the new country's raw datasets to generate a full variable inventory.
2. Compare the new codebook against the Senegal codebook (`ehcvm_all_variables2018.xlsx`, `ehcvm_all_variables2021.xlsx`) to build a mapping table.
3. Search for every `s10q`, `s04q`, `s06q`, `s13aq`, `s01q`, and `s20bq` reference in the cleaning and analysis files and verify each one exists in the new country's data.

### Information needed to fix
- The new country's raw .dta files (to run codebook extraction)
- The questionnaire documentation (PDF) for the new country
- A variable-by-variable mapping: Senegal variable -> New country variable

### Key Senegal variables to map

| Senegal Variable | Description | Where Used |
|-----------------|-------------|------------|
| `s10q15__0` | Enterprise proprietor ID | Cleaning, panel creation |
| `s10q17a` | Enterprise sector (ISIC) | Cleaning, analysis |
| `s10q23` | Place of business | Cleaning, analysis |
| `s10q29` | Keeps written accounts | Formality definition |
| `s10q30` | Has fiscal ID (NIF) | Formality definition |
| `s10q31` | Trade register | Formality definition |
| `s10q32` | CNPS registered | Formality definition |
| `s10q33` | Legal form | Enterprise classification |
| `s10q34` | Source of initial financing | Enterprise characteristics |
| `s10q36-s10q42` | Asset values | Capital measurement |
| `s10q45a-s10q45o` | Enterprise problems | Constraint analysis |
| `s10q46-s10q57` | Revenue and expense items | Profit calculation |
| `s10q58` | Enterprise activity status | Filtering inactive enterprises |
| `s10q61a_1-s10q61a_14` | HH member engagement | Labor measurement |
| `s10q62a_1-s10q62a_4` | Hired workers by type | Employment counts |
| `s10q62d_1-s10q62d_4` | Salaries by worker type | Labor cost |
| `s04q29b` | Occupation code | Employment classification |
| `s04q30b` | Industry sector | Sector of employment |
| `s04q38` | Pension contribution | Formality (2021) |
| `s04q39` | Socio-professional category | Employment type |
| `s06q05` | Got credit last 12 months | Credit analysis |
| `s06q12` | Credit source | Formal/informal credit |
| `s06q14` | Credit amount | Credit analysis |
| `s13aq14` | Remittance sender location | Domestic vs. abroad |
| `s13aq17b` | Remittance frequency | Annualization |
| `s01q16` | Ethnicity | Demographics |

---

## 3. Error Category 2: Employment and Formality Classification Errors

### What happened (Senegal)
The original 2021 cleaning file had **incorrect employment type categorization**. The socio-professional category codes (hcsp/s04q39) were mapped as:
- OLD (wrong): 1-7 = Wage, 9 = Self-employed, 10 = Employer, 8 = Family worker
- NEW (correct): 1-6 = Paid work, 7 = Unpaid intern, 8 = Family worker, 9 = Self-employed, 10 = Employer

The 2021 file also initially **missed formality indicators** (`s04q38` for pension, `s04q31` for employer type) that were needed for the formal employment definition.

### How to avoid
1. Obtain the questionnaire for the new country and read the exact wording and response codes for the socio-professional category question.
2. Cross-check by tabulating `s04q39` (or equivalent) against labels in the raw data: `tab s04q39, nolabel` vs. `tab s04q39`.
3. Check whether formality-related questions exist in the employment section (pension contributions, written contracts, social security).
4. Do not assume codes mean the same thing across countries -- even within EHCVM, category boundaries may shift.

### Information needed to fix
- The employment section of the questionnaire for the new country
- The value labels attached to the socio-professional category variable in the raw data
- The list of formality-related questions available in the new country's survey

---

## 4. Error Category 3: Excel Export Bugs (putexcel / tabout)

### What happened (Senegal)
Two critical bugs were found in the analysis file:

**Bug 1: Missing `putexcel set` causing sheet collision**
Section 2b data was written without first calling `putexcel set` to select the correct sheet. This caused output to silently overwrite data on the wrong sheet (S1_Introduction instead of S2_Profile).

**Bug 2: `r(table)` cleared by `putexcel set`**
`putexcel set` is an r-class command that **clears all r() stored results**. When `matrix results = r(table)'` was placed after `putexcel set`, the matrix was empty because the regression results had been wiped. This affected both the TFP section and the `export_reg_results` helper program.

### How to avoid
1. **Always call `putexcel set` before writing to a new sheet.** Every block of putexcel output must begin with a `putexcel set` call specifying the target sheet.
2. **Capture `r(table)` and `e()` results immediately after the estimation command**, before any `putexcel set` call. The correct order is:

```stata
* Run regression
xtreg y x1 x2 [pw=weight], fe vce(cluster clustervar)

* IMMEDIATELY capture results
matrix results = r(table)'
local _eN = e(N)
local _er2 = e(r2)

* NOW set the Excel sheet (this clears r())
putexcel set "output.xlsx", sheet("Results") modify

* Use the saved matrix and locals
putexcel B4 = matrix(results), rownames nformat("0.000")
```

3. **Track which sheet is "active"** at every point in the code. Add a comment noting the active sheet whenever `putexcel set` is called.
4. **Test Excel output** by opening the file after each section runs, not just at the end.

### Information needed to fix
- Which sheet each putexcel block is supposed to target
- Whether any estimation command output is needed after a putexcel set call

---

## 5. Error Category 4: Dataset Structure Differences Across Waves

### What happened (Senegal)
The 2018 and 2021 surveys had structural differences:

| Element | 2018 | 2021 |
|---------|------|------|
| Enterprise data file | `s10_2_me_sen2018` | `s10b_me_sen2021` |
| Employment data | Single file `s04_me_sen2018` | Split into 3: `s04a`, `s04b`, `s04c` |
| HH members in enterprise | Up to 14 (`s10q61a_1` to `_14`) | Up to 8 (`s10q61a_1` to `_8`) |
| Remittance section | `s13a_2_me_sen2018` | `s13_2_me_sen2021` |
| Governance module | Not available | `s20b`, `s20c` sections |

### How to avoid
1. List all raw .dta files for each wave in the new country. Compare file names and counts.
2. For each file, extract variable lists (`describe using "file.dta"`) and compare across waves.
3. Pay special attention to:
   - Whether employment data is split or combined
   - Maximum number of household members tracked in enterprise module
   - Whether governance/perception modules exist
   - File naming pattern (`_me_COUNTRY_YEAR` may vary)

### Information needed to fix
- Complete list of raw .dta files for both waves in the new country
- Variable lists from each file (`describe` output)
- Questionnaire PDFs showing section structure for both waves

---

## 6. Error Category 5: Panel Matching and ID Construction

### What happened (Senegal)
Enterprise and individual IDs are constructed from survey identifiers:
- `hhid = grappe * 1000 + menage` (household ID)
- `nonag_id = "grappe_menage_proprietor_id"` (enterprise ID, string)

Panel matching relies on `grappe`, `menage`, and `numind` being consistent across waves. An age-difference check (`age_diff` between 2 and 4 years) is used to validate matches.

### How to avoid
1. Verify that the geographic/cluster identifiers (`grappe` equivalent) are consistent across waves. Some countries re-draw clusters between survey rounds.
2. Check whether household IDs (`menage`) are stable across waves. In some countries, households are re-numbered.
3. Confirm the individual identifier (`numind` equivalent) within households is tracked consistently.
4. Run the age-difference validation: if `age_2021 - age_2018` is not between 2 and 4 for most matched individuals, the matching is unreliable.
5. Check whether the new country provides a pre-built panel tracking file.

### Information needed to fix
- Survey documentation on panel tracking methodology
- Whether cluster/household/individual IDs are consistent across waves
- Any official panel-matching datasets or tracking files provided by the survey team
- Expected time gap between waves (for age validation bounds)

---

## 7. Error Category 6: File Paths and Naming Conventions

### What happened (Senegal)
All paths use a Windows-style structure with the country code "SEN":
```
${project}/Data/SEN/2018/
${project}/Data/SEN/2021/
${project}/Data/SEN/Intermediate/
${project}/Data/SEN/Final/
${project}/Output/SEN/
```

Dataset files follow the pattern: `section_me_senYEAR.dta`

### How to avoid
1. In `00_master.do` and each cleaning file, update all path globals to replace "SEN" with the new country code.
2. Update all `use` statements to reference the new country's actual .dta filenames.
3. Verify the folder structure exists before running.

### Checklist of paths to update

| Global | Senegal Value | Change to |
|--------|--------------|-----------|
| `$data_2018` | `${project}/Data/SEN/2018` | `${project}/Data/COUNTRY/YEAR1` |
| `$data_2021` | `${project}/Data/SEN/2021` | `${project}/Data/COUNTRY/YEAR2` |
| `$intermediate` | `${project}/Data/SEN/Intermediate` | `${project}/Data/COUNTRY/Intermediate` |
| `$final` | `${project}/Data/SEN/Final` | `${project}/Data/COUNTRY/Final` |
| `$output` | `${project}/Output/SEN` | `${project}/Output/COUNTRY` |
| Dataset names | `*_sen2018.dta`, `*_sen2021.dta` | `*_COUNTRY_YEAR.dta` |

---

## 8. Error Category 7: Country-Specific Coding Schemes

### Elements that are Senegal-specific and MUST be reviewed

**Sector recoding** (ISIC to analysis categories):
```stata
* Senegal mapping -- verify ISIC codes are the same in new country
recode s10q17a (1/2=1 "Ag and extractives") (3=2 "Manufacturing") ...
```

**Credit source categories** (s06q12):
- Code 5 = Cooperative, Code 6 = Tontine (rotating savings)
- Tontines are specific to West Africa; other countries may have different informal credit mechanisms
- The formal/informal credit split must be redefined based on local institutions

**Remittance sender location** (s13aq14):
- Domestic location codes (1-3, 10 = within Senegal) are country-specific
- International codes (4-9, 11-14) also differ

**CPI adjustment factor**:
- Senegal uses 114.5/107.4 for 2018-2021 inflation adjustment
- Each country needs its own CPI values from national statistics

**Social security registration** (formality):
- Senegal uses CNPS (Caisse Nationale de Prevoyance Sociale)
- Other countries have different social security institutions and variable names

**Socio-professional categories** (s04q39):
- The 10-category classification may differ across countries
- The boundary between "paid work" and other categories is country-specific

### Information needed to fix
- National CPI data for the relevant years
- Names of formal institutions (social security, business registration, tax authority)
- Credit market structure (what counts as formal vs. informal)
- ISIC-to-sector mapping appropriate for the country's economy
- Domestic geography codes for the remittance analysis

---

## 9. Pre-Replication Checklist

Before adapting the do-files for a new country, gather the following:

### Required Documents
- [ ] Raw .dta files for both survey waves
- [ ] Questionnaire PDFs for both waves (in the survey language)
- [ ] Variable codebooks or data dictionaries
- [ ] Survey methodology report (sampling, weighting, panel tracking)
- [ ] National CPI data for both survey years

### Required Decisions
- [ ] Country code to use in file paths (e.g., BFA for Burkina Faso)
- [ ] Wave years (may not be 2018/2021)
- [ ] Which formality indicators are available
- [ ] How to classify formal vs. informal credit for this country
- [ ] Sector recoding scheme (verify ISIC mapping)
- [ ] Whether governance/perception modules exist in the survey

### Recommended First Steps
1. Run `01_extract_codebook.do` (adapted for new file paths) to inventory all variables
2. Build a variable mapping spreadsheet: Senegal variable -> New country variable
3. Identify variables that exist in Senegal but not in the new country (will require code deletion or substitution)
4. Identify variables in the new country that don't exist in Senegal (potential additions)
5. Run `02_clean` on a small test sample first to catch variable-name errors early

---

## 10. Quick Reference: What to Change per File

### 02_clean_2018.do / 03_clean_2021.do
- [ ] File paths and dataset names
- [ ] All `s10q*`, `s04q*`, `s06q*`, `s13aq*`, `s01q*` variable references
- [ ] Socio-professional category code mappings
- [ ] Formality indicator definitions
- [ ] Credit source classifications (formal/informal boundary)
- [ ] Remittance location codes (domestic vs. abroad)
- [ ] Sector recoding values
- [ ] Enterprise problem variable list (`s10q45a` through `s10q45o` -- count may differ)
- [ ] Household member count in enterprise module (14 vs. 8 vs. other)
- [ ] Weight variable name (`hhweight` -- verify it exists and is named the same)
- [ ] Geographic identifiers (`grappe`, `menage`, `numind`, `zae`, `milieu`)

### 04_create_panel.do
- [ ] ID construction formula (verify `grappe * 1000 + menage` doesn't overflow)
- [ ] Panel matching identifiers
- [ ] Age-difference validation bounds (adjust for gap between waves)
- [ ] Enterprise status variable and codes
- [ ] Year suffixes on all panel variables (`_2018`, `_2021` -> `_YEAR1`, `_YEAR2`)

### 05_analysis_without graphs.do
- [ ] All putexcel sheet names and row references
- [ ] Ensure every putexcel block starts with `putexcel set`
- [ ] Capture `r(table)` BEFORE `putexcel set` after regressions
- [ ] CPI adjustment factor
- [ ] Cluster variable for standard errors (`grappe` -> equivalent)
- [ ] All constructed variable names that embed year (`_2018`, `_2021`)
- [ ] Tabout output file path (uses `$output\Results.xls`)
- [ ] TFP specification variables
- [ ] Governance variables (may not exist for all countries)

---

## Summary of Bugs Found and Fixed During Senegal Analysis

| # | Bug | Root Cause | Fix Applied | Lesson |
|---|-----|-----------|-------------|--------|
| 1 | Employment type miscategorized in 2021 | Wrong code-to-category mapping for s04q39 | Corrected: 1-6=Paid, 7=Intern, 8=Family, 9=Self-emp, 10=Employer | Always verify category codes against questionnaire |
| 2 | Missing formality variables in 2021 | s04q38 and s04q31 not extracted from raw data | Added variable extraction and formal/public_employer creation | Run codebook extraction first to identify all available variables |
| 3 | putexcel writing to wrong sheet | Missing `putexcel set` before Section 2b | Added `putexcel set "${xlout}", sheet("S2_Profile") modify` | Every putexcel output block needs its own `putexcel set` |
| 4 | Empty regression matrices in Excel | `putexcel set` clears r() results including r(table) | Moved `matrix results = r(table)'` before `putexcel set` | Capture estimation results immediately after estimation command |

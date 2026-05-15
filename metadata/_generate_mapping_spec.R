# Generates metadata/mapping_spec.xlsx — CDASH -> SDTM mapping for DM, AE, LB.
# Run: Rscript metadata/_generate_mapping_spec.R
suppressPackageStartupMessages({
  library(openxlsx)
  library(here)
})

row <- function(dom, var, label, form, field, deriv, ct) {
  data.frame(SDTM_Domain = dom, SDTM_Variable = var,
             SDTM_VariableLabel = label,
             CDASH_Form = form, CDASH_Field = field,
             Derivation = deriv, ControlledTerm = ct,
             stringsAsFactors = FALSE)
}

map <- rbind(
  # ---- DM (13) ----
  row("DM","STUDYID","Study Identifier","-","-",
      "Constant: 'IMM-PSO-3001'","-"),
  row("DM","DOMAIN","Domain Abbreviation","-","-",
      "Constant: 'DM'","DM"),
  row("DM","USUBJID","Unique Subject Identifier","DM","SUBJID",
      "USUBJID = STUDYID || '-' || SUBJID","-"),
  row("DM","SUBJID","Subject Identifier for the Study","DM","SUBJID",
      "Pass through","-"),
  row("DM","SITEID","Study Site Identifier","DM","SUBJID",
      "Extracted from SUBJID prefix (S### in 'S###-####')","-"),
  row("DM","BRTHDTC","Date/Time of Birth","DM","BRTHDAT",
      "Format BRTHDAT as ISO 8601 (YYYY-MM-DD)","-"),
  row("DM","AGE","Age","DM","AGE",
      "Pass through (computed at entry from BRTHDAT to RFSTDTC)","-"),
  row("DM","AGEU","Age Units","DM","AGEU",
      "Pass through; default 'YEARS'","AGEU"),
  row("DM","SEX","Sex","DM","SEX",
      "Pass through","SEX (M/F)"),
  row("DM","RACE","Race","DM","RACE",
      "Pass through; multi-value flatten with separator","RACE"),
  row("DM","ETHNIC","Ethnicity","DM","ETHNIC",
      "Pass through","ETHNIC"),
  row("DM","COUNTRY","Country","DM","COUNTRY",
      "Pass through (ISO 3166 alpha-3)","COUNTRY"),
  row("DM","ARM","Description of Planned Arm","IxRS/EX","ARMCD",
      "Derived from randomization (IxRS) and EX records","ARM"),
  row("DM","RFSTDTC","Subject Reference Start Date/Time","EX","EXSTDT",
      "First EXSTDT for the subject (first study drug dose)","-"),
  row("DM","RFENDTC","Subject Reference End Date/Time","EX","EXENDT",
      "Last EXENDT for the subject","-"),

  # ---- AE (15) ----
  row("AE","STUDYID","Study Identifier","-","-",
      "Constant: 'IMM-PSO-3001'","-"),
  row("AE","DOMAIN","Domain Abbreviation","-","-",
      "Constant: 'AE'","AE"),
  row("AE","USUBJID","Unique Subject Identifier","DM","SUBJID",
      "Joined from DM on SUBJID","-"),
  row("AE","AESEQ","Sequence Number","AE","-",
      "Within-subject sequential integer; sort by AESTDAT","-"),
  row("AE","AETERM","Reported Term for the Adverse Event","AE","AETERM",
      "Pass through (verbatim)","-"),
  row("AE","AEDECOD","Dictionary-Derived Term","AE","AEDECOD",
      "MedDRA PT from internal lookup (see R/01_cdash_to_sdtm.R MedDRA table)","MedDRA PT"),
  row("AE","AEBODSYS","Body System or Organ Class","AE","AESOC",
      "MedDRA SOC mapped from AEDECOD","MedDRA SOC"),
  row("AE","AESTDTC","Start Date/Time of AE","AE","AESTDAT",
      "Format AESTDAT as ISO 8601","-"),
  row("AE","AEENDTC","End Date/Time of AE","AE","AEENDAT",
      "Format AEENDAT as ISO 8601; blank if ongoing","-"),
  row("AE","AESEV","Severity/Intensity","AE","AESEV",
      "Pass through (controlled term)","AESEV (MILD/MODERATE/SEVERE)"),
  row("AE","AESER","Serious Event","AE","AESER",
      "Pass through","NY"),
  row("AE","AEREL","Causality","AE","AEREL",
      "Pass through","AEREL"),
  row("AE","AEACN","Action Taken with Study Treatment","AE","AEACN",
      "Pass through","AEACN"),
  row("AE","AEOUT","Outcome of AE","AE","AEOUT",
      "Pass through","AEOUT"),
  row("AE","AETOXGR","Standard Toxicity Grade","AE","AETOXGR",
      "Pass through; blank if not graded","TOXGR (1-5)"),

  # ---- LB (12) ----
  row("LB","STUDYID","Study Identifier","-","-",
      "Constant: 'IMM-PSO-3001'","-"),
  row("LB","DOMAIN","Domain Abbreviation","-","-",
      "Constant: 'LB'","LB"),
  row("LB","USUBJID","Unique Subject Identifier","DM","SUBJID",
      "Joined from DM on SUBJID","-"),
  row("LB","LBSEQ","Sequence Number","LB","-",
      "Within-subject sequential; sort by LBDAT,LBTESTCD","-"),
  row("LB","LBTESTCD","Lab Test Short Name","LB","LBTESTCD",
      "Pass through","LBTESTCD (WBC,HGB,PLT,ALT,AST,CREAT)"),
  row("LB","LBTEST","Lab Test Name","LB","LBTEST",
      "Derived from LBTESTCD via standard lookup","LBTEST"),
  row("LB","LBCAT","Category for Lab Test","-","-",
      "Constant per test: 'HEMATOLOGY' (WBC,HGB,PLT) or 'CHEMISTRY' (ALT,AST,CREAT)","LBCAT"),
  row("LB","LBORRES","Result or Finding (Original Units)","LB","LBORRES",
      "Pass through (character)","-"),
  row("LB","LBORRESU","Original Units","LB","LBORRESU",
      "Pass through","UNIT"),
  row("LB","LBSTRESC","Result Standardized (Character)","LB","LBORRES",
      "Unit-converted standardized value as character","-"),
  row("LB","LBSTRESN","Result Standardized (Numeric)","LB","LBORRES",
      "Unit-converted standardized value as numeric","-"),
  row("LB","LBSTNRLO","Reference Range Lower Limit","LB","LBORNRLO",
      "From central lab reference table per test","-"),
  row("LB","LBSTNRHI","Reference Range Upper Limit","LB","LBORNRHI",
      "From central lab reference table per test","-"),
  row("LB","LBDTC","Date/Time of Specimen Collection","LB","LBDAT",
      "Format LBDAT as ISO 8601","-")
)

out <- here("metadata", "mapping_spec.xlsx")
write.xlsx(map, out, overwrite = TRUE)
message(sprintf("Wrote %s (%d rows across %d domains)",
                out, nrow(map), length(unique(map$SDTM_Domain))))

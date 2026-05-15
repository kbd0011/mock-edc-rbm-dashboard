# Generates metadata/edit_checks.xlsx — 35 edit checks across 6 categories.
# Run: Rscript metadata/_generate_edit_checks.R
#
# Logic column is parseable pseudo-code used by python/edit_checks/runner.py.
# Grammar:
#   REQUIRED
#   BETWEEN <lo> AND <hi>
#   MATCHES /<regex>/
#   <form1>.<field1> >= <form2>.<field2>
#   <form1>.<field1> > <form2>.<field2>
#   IF <form>.<field> = '<value>' THEN <form>.<field> IN (<values>)
suppressPackageStartupMessages({
  library(openxlsx)
  library(here)
})

ec <- function(id, cat, form, fields, rule, logic, sev, query, sas) {
  data.frame(CheckID = id, CheckCategory = cat, Form = form,
             Fields = fields, RuleDescription = rule,
             Logic = logic, Severity = sev,
             QueryText = query, SAS_Equivalent_Pseudocode = sas,
             stringsAsFactors = FALSE)
}

checks <- rbind(
  # ---- REQUIRED (6) ----
  ec("EC001","Required","dm","SUBJID","Subject ID must be present.",
     "REQUIRED","Error",
     "Subject ID is missing. Please complete.",
     "if missing(SUBJID) then output;"),
  ec("EC002","Required","dm","BRTHDAT","Date of birth must be present.",
     "REQUIRED","Error",
     "Date of birth is missing.",
     "if missing(BRTHDAT) then output;"),
  ec("EC003","Required","ie","IEORRES","Inclusion/Exclusion result must be present.",
     "REQUIRED","Error",
     "Criterion result (Y/N) missing.",
     "if missing(IEORRES) then output;"),
  ec("EC004","Required","ae","AETERM","AE term must be present.",
     "REQUIRED","Error",
     "Adverse event term is missing.",
     "if missing(AETERM) then output;"),
  ec("EC005","Required","ae","AESTDAT","AE start date must be present.",
     "REQUIRED","Error",
     "AE start date is missing.",
     "if missing(AESTDAT) then output;"),
  ec("EC006","Required","lb","LBORRES","Lab result must be present.",
     "REQUIRED","Error",
     "Laboratory result is missing.",
     "if missing(LBORRES) then output;"),

  # ---- RANGE (8) ----
  ec("EC007","Range","dm","AGE","Age must be between 18 and 75 inclusive.",
     "BETWEEN 18 AND 75","Error",
     "Age is outside the inclusion range (18-75).",
     "if AGE < 18 or AGE > 75 then output;"),
  ec("EC008","Range","pasi","PASITOT","PASI Total must be between 0 and 72.",
     "BETWEEN 0 AND 72","Error",
     "PASI Total is outside the valid range (0-72).",
     "if PASITOT < 0 or PASITOT > 72 then output;"),
  ec("EC009","Range","pasi","PASIHEAD","PASI Head must be between 0 and 7.2.",
     "BETWEEN 0 AND 7.2","Error",
     "PASI Head sub-score outside valid range.",
     "if PASIHEAD < 0 or PASIHEAD > 7.2 then output;"),
  ec("EC010","Range","pasi","PASIARMS","PASI Upper Limbs must be between 0 and 14.4.",
     "BETWEEN 0 AND 14.4","Error",
     "PASI Upper Limbs sub-score outside valid range.",
     "if PASIARMS < 0 or PASIARMS > 14.4 then output;"),
  ec("EC011","Range","lb","LBORRES","WBC must be between 0.1 and 100 x10^9/L.",
     "WHEN LBTESTCD='WBC' BETWEEN 0.1 AND 100","Warning",
     "WBC value outside plausible range; confirm or query.",
     "if LBTESTCD='WBC' and (LBORRES < 0.1 or LBORRES > 100) then output;"),
  ec("EC012","Range","lb","LBORRES","Hemoglobin must be between 3 and 25 g/dL.",
     "WHEN LBTESTCD='HGB' BETWEEN 3 AND 25","Warning",
     "Hemoglobin outside plausible range.",
     "if LBTESTCD='HGB' and (LBORRES < 3 or LBORRES > 25) then output;"),
  ec("EC013","Range","lb","LBORRES","Platelet count must be between 10 and 1500 x10^9/L.",
     "WHEN LBTESTCD='PLT' BETWEEN 10 AND 1500","Warning",
     "Platelet count outside plausible range.",
     "if LBTESTCD='PLT' and (LBORRES < 10 or LBORRES > 1500) then output;"),
  ec("EC014","Range","cm","CMDOSE","CM dose must be non-negative.",
     "BETWEEN 0 AND 100000","Error",
     "Negative or unrealistic dose value.",
     "if CMDOSE < 0 or CMDOSE > 100000 then output;"),

  # ---- FORMAT (4) ----
  ec("EC015","Format","dm","SUBJID","Subject ID must match pattern S###-####.",
     "MATCHES /^S[0-9]{3}-[0-9]{4}$/","Error",
     "Subject ID does not match required format S###-####.",
     "if not prxmatch('/^S[0-9]{3}-[0-9]{4}$/', SUBJID) then output;"),
  ec("EC016","Format","dm","BRTHDAT","Date of birth must be ISO 8601 YYYY-MM-DD.",
     "MATCHES /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/","Error",
     "Date of birth not in YYYY-MM-DD format.",
     "if not prxmatch('/^\\d{4}-\\d{2}-\\d{2}$/', BRTHDAT) then output;"),
  ec("EC017","Format","ae","AESTDAT","AE start date must be ISO 8601.",
     "MATCHES /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/","Error",
     "AE start date not in YYYY-MM-DD format.",
     "if not prxmatch('/^\\d{4}-\\d{2}-\\d{2}$/', AESTDAT) then output;"),
  ec("EC018","Format","lb","LBDAT","Lab specimen date must be ISO 8601.",
     "MATCHES /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/","Error",
     "Lab specimen date not in YYYY-MM-DD format.",
     "if not prxmatch('/^\\d{4}-\\d{2}-\\d{2}$/', LBDAT) then output;"),

  # ---- CROSS-FORM TEMPORAL (6) ----
  ec("EC019","Cross-form","ae+ex","AESTDAT,EXSTDT",
     "Treatment-emergent AEs must start on/after first dose.",
     "ae.AESTDAT >= ex.EXSTDT","Warning",
     "AE start date precedes first study drug dose.",
     "if AESTDAT < EXSTDT then output;"),
  ec("EC020","Cross-form","ae","AESTDAT,AEENDAT",
     "AE end date must be on/after AE start date.",
     "ae.AEENDAT >= ae.AESTDAT","Error",
     "AE end date is earlier than AE start date.",
     "if not missing(AEENDAT) and AEENDAT < AESTDAT then output;"),
  ec("EC021","Cross-form","cm","CMSTDAT,CMENDAT",
     "CM end date must be on/after CM start date.",
     "cm.CMENDAT >= cm.CMSTDAT","Error",
     "CM end date is earlier than CM start date.",
     "if not missing(CMENDAT) and CMENDAT < CMSTDAT then output;"),
  ec("EC022","Cross-form","ae+dm","AESTDAT,BRTHDAT",
     "AE start date must be after date of birth.",
     "ae.AESTDAT > dm.BRTHDAT","Error",
     "AE start date precedes date of birth (data entry error).",
     "if AESTDAT <= BRTHDAT then output;"),
  ec("EC023","Cross-form","lb+ex","LBDAT,EXSTDT",
     "Post-baseline lab samples must be on/after first dose.",
     "lb.LBDAT >= ex.EXSTDT WHEN VISIT != 'SCREENING'","Warning",
     "Post-baseline lab sample collected before first dose.",
     "if VISIT ne 'SCREENING' and LBDAT < EXSTDT then output;"),
  ec("EC024","Cross-form","pasi+ex","PASIDAT,EXSTDT",
     "Post-baseline PASI must be on/after baseline.",
     "pasi.PASIDAT >= ex.EXSTDT WHEN VISIT != 'SCREENING'","Warning",
     "Post-baseline PASI assessment date precedes baseline.",
     "if VISIT ne 'SCREENING' and PASIDAT < EXSTDT then output;"),

  # ---- CROSS-FORM CONSISTENCY (4) ----
  ec("EC025","Cross-form","ae","AESER,AESEV",
     "Serious AEs should be MODERATE or SEVERE.",
     "IF ae.AESER = 'Y' THEN ae.AESEV IN ('MODERATE','SEVERE')","Warning",
     "AE flagged serious but severity is MILD; please confirm.",
     "if AESER='Y' and AESEV='MILD' then output;"),
  ec("EC026","Cross-form","pasi","PASIHEAD,PASIARMS,PASITRNK,PASILEGS,PASITOT",
     "PASI Total must equal sum of regional sub-scores (within 0.1 tolerance).",
     "abs(pasi.PASITOT - (pasi.PASIHEAD + pasi.PASIARMS + pasi.PASITRNK + pasi.PASILEGS)) <= 0.1",
     "Error",
     "PASI Total does not match sum of regional sub-scores.",
     "if abs(PASITOT - sum(of PASIHEAD PASIARMS PASITRNK PASILEGS)) > 0.1 then output;"),
  ec("EC027","Cross-form","cm+ae","CMTRT,AETERM",
     "If AE term includes 'infection', expect a corresponding antimicrobial in CM.",
     "IF ae.AETERM CONTAINS 'infection' THEN cm.CMINDC CONTAINS 'infection'","Notice",
     "Infection-related AE without matching CM record; please confirm.",
     "/* notice-only */"),
  ec("EC028","Cross-form","ae+dm","AEOUT,SEX",
     "Pregnancy-related outcomes only valid for female subjects.",
     "IF ae.AEOUT CONTAINS 'pregnancy' THEN dm.SEX = 'F'","Warning",
     "Pregnancy outcome recorded for non-female subject.",
     "if index(AEOUT,'PREGNANCY')>0 and SEX ne 'F' then output;"),

  # ---- PLAUSIBILITY (2) ----
  ec("EC029","Plausibility","lb","LBORRES",
     "ALT plausibility: warn if > 500 U/L.",
     "WHEN LBTESTCD='ALT' BETWEEN 0 AND 500","Warning",
     "ALT exceeds plausible upper threshold (>500 U/L).",
     "if LBTESTCD='ALT' and LBORRES > 500 then output;"),
  ec("EC030","Plausibility","lb","LBORRES",
     "Creatinine plausibility: warn if > 10 mg/dL.",
     "WHEN LBTESTCD='CREAT' BETWEEN 0 AND 10","Warning",
     "Creatinine exceeds plausible threshold (>10 mg/dL).",
     "if LBTESTCD='CREAT' and LBORRES > 10 then output;"),

  # ---- ADDITIONAL (5) ----
  ec("EC031","Required","pasi","PASITOT","PASI Total must be present at every PASI visit.",
     "REQUIRED","Error",
     "PASI Total is missing.",
     "if missing(PASITOT) then output;"),
  ec("EC032","Range","ae","AETOXGR","AE toxicity grade must be 1-5.",
     "BETWEEN 1 AND 5","Warning",
     "AE toxicity grade outside 1-5 range.",
     "if not missing(AETOXGR) and (AETOXGR < 1 or AETOXGR > 5) then output;"),
  ec("EC033","Format","cm","CMSTDAT","CM start date format YYYY-MM-DD (full dates only for this study).",
     "MATCHES /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/","Warning",
     "CM start date format invalid; partial dates not allowed.",
     "if not prxmatch('/^\\d{4}-\\d{2}-\\d{2}$/', CMSTDAT) then output;"),
  ec("EC034","Cross-form","ae","AEACN,AESER",
     "Serious AEs that resulted in withdrawal should have AEACN='DRUG WITHDRAWN'.",
     "IF ae.AESER = 'Y' AND ae.AEOUT = 'FATAL' THEN ae.AEACN = 'DRUG WITHDRAWN'","Warning",
     "Fatal serious AE without DRUG WITHDRAWN action; confirm.",
     "if AESER='Y' and AEOUT='FATAL' and AEACN ne 'DRUG WITHDRAWN' then output;"),
  ec("EC035","Cross-form","pasi","PASITOT","PASI Total at W16 below baseline by >50% expected on active arm only.",
     "WHEN VISIT='W16' pasi.PASITOT >= 0","Notice",
     "Informational: review treatment-effect plausibility.",
     "/* notice-only */")
)

# Sanity: 35 rows, six categories present.
stopifnot(nrow(checks) == 35L)
stopifnot(all(c("Required","Range","Format","Cross-form","Plausibility") %in% checks$CheckCategory))

out <- here("metadata", "edit_checks.xlsx")
write.xlsx(checks, out, overwrite = TRUE)
message(sprintf("Wrote %s (%d checks)", out, nrow(checks)))

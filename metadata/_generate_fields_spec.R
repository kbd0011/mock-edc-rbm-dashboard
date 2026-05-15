# Generates metadata/fields_spec.xlsx — field-level CDASHIG 2.2 metadata.
# Run: Rscript metadata/_generate_fields_spec.R
suppressPackageStartupMessages({
  library(openxlsx)
  library(here)
})

rows <- list(
  # ---- DM (8) ----
  c("F-DM-001","F-DM",1, "SUBJID","Subject ID","Char",10,NA, "Y","text",
    "Format: S###-####","SUBJID","DM"),
  c("F-DM-002","F-DM",2, "BRTHDAT","Date of Birth","Date",10,NA, "Y","date",
    "ISO 8601 (YYYY-MM-DD)","BRTHDTC","DM"),
  c("F-DM-003","F-DM",3, "AGE","Age at Screening","Num",3,NA, "Y","number",
    "Computed from BRTHDAT; 18-75 inclusive","AGE","DM"),
  c("F-DM-004","F-DM",4, "AGEU","Age Units","Char",10,"YEARS,MONTHS","Y","dropdown",
    "Set to YEARS at entry","AGEU","DM"),
  c("F-DM-005","F-DM",5, "SEX","Sex","Char",1,"M,F","Y","radio",
    "Biological sex at birth","SEX","DM"),
  c("F-DM-006","F-DM",6, "RACE","Race","Char",60,"AMERICAN INDIAN OR ALASKA NATIVE,ASIAN,BLACK OR AFRICAN AMERICAN,NATIVE HAWAIIAN OR OTHER PACIFIC ISLANDER,WHITE,MULTIPLE,UNKNOWN,NOT REPORTED","Y","checkbox",
    "Per FDA guidance; multiple allowed","RACE","DM"),
  c("F-DM-007","F-DM",7, "ETHNIC","Ethnicity","Char",30,"HISPANIC OR LATINO,NOT HISPANIC OR LATINO,NOT REPORTED,UNKNOWN","Y","radio",
    "","ETHNIC","DM"),
  c("F-DM-008","F-DM",8, "COUNTRY","Country","Char",3,"USA","Y","dropdown",
    "ISO 3166 alpha-3","COUNTRY","DM"),

  # ---- IE (4) ----
  c("F-IE-001","F-IE",1, "IECAT","Category","Char",20,"INCLUSION,EXCLUSION","Y","radio",
    "","IECAT","IE"),
  c("F-IE-002","F-IE",2, "IETESTCD","Criterion Code","Char",8,NA,"Y","text",
    "INCL01-INCL07, EXCL01-EXCL08","IETESTCD","IE"),
  c("F-IE-003","F-IE",3, "IETEST","Criterion Text","Char",200,NA,"Y","text",
    "Full criterion text","IETEST","IE"),
  c("F-IE-004","F-IE",4, "IEORRES","Criterion Met (Y/N)","Char",1,"Y,N","Y","radio",
    "Y=criterion met (subject passes)","IEORRES","IE"),

  # ---- AE (12) ----
  c("F-AE-001","F-AE",1, "AETERM","AE Reported Term","Char",200,NA,"Y","text",
    "Verbatim from source","AETERM","AE"),
  c("F-AE-002","F-AE",2, "AEDECOD","MedDRA Preferred Term","Char",100,NA,"N","text",
    "Coded post-entry by central coding","AEDECOD","AE"),
  c("F-AE-003","F-AE",3, "AESTDAT","AE Start Date","Date",10,NA,"Y","date",
    "ISO 8601","AESTDTC","AE"),
  c("F-AE-004","F-AE",4, "AEENDAT","AE End Date","Date",10,NA,"N","date",
    "Blank if ongoing","AEENDTC","AE"),
  c("F-AE-005","F-AE",5, "AESEV","Severity","Char",10,"MILD,MODERATE,SEVERE","Y","radio",
    "Investigator assessment","AESEV","AE"),
  c("F-AE-006","F-AE",6, "AESER","Serious (Y/N)","Char",1,"Y,N","Y","radio",
    "Per ICH E2A definitions","AESER","AE"),
  c("F-AE-007","F-AE",7, "AEREL","Relationship to Study Drug","Char",20,"RELATED,NOT RELATED,UNKNOWN","Y","radio",
    "Investigator assessment","AEREL","AE"),
  c("F-AE-008","F-AE",8, "AEACN","Action Taken with Study Drug","Char",30,"DOSE NOT CHANGED,DOSE REDUCED,DRUG INTERRUPTED,DRUG WITHDRAWN,NOT APPLICABLE","Y","dropdown",
    "","AEACN","AE"),
  c("F-AE-009","F-AE",9, "AEOUT","Outcome","Char",30,"RECOVERED/RESOLVED,RECOVERING/RESOLVING,NOT RECOVERED/NOT RESOLVED,RECOVERED/RESOLVED WITH SEQUELAE,FATAL,UNKNOWN","Y","dropdown",
    "","AEOUT","AE"),
  c("F-AE-010","F-AE",10,"AESOC","System Organ Class","Char",100,NA,"N","text",
    "Auto-populated from MedDRA after AEDECOD coding","AESOC","AE"),
  c("F-AE-011","F-AE",11,"AETOXGR","Toxicity Grade","Char",1,"1,2,3,4,5","N","dropdown",
    "Per CTCAE v5.0 when applicable","AETOXGR","AE"),
  c("F-AE-012","F-AE",12,"AENONST","Non-Serious Treatment-Emergent","Char",1,"Y,N","N","radio",
    "Derived flag","AENONST","AE"),

  # ---- CM (8) ----
  c("F-CM-001","F-CM",1, "CMTRT","Medication Name","Char",200,NA,"Y","text",
    "Verbatim; coded post-entry to WHO-DD","CMTRT","CM"),
  c("F-CM-002","F-CM",2, "CMINDC","Indication","Char",200,NA,"Y","text",
    "Free text","CMINDC","CM"),
  c("F-CM-003","F-CM",3, "CMDOSE","Dose","Num",6,NA,"Y","number",
    "Numeric dose value","CMDOSE","CM"),
  c("F-CM-004","F-CM",4, "CMDOSU","Dose Unit","Char",10,"mg,g,mL,IU,mcg,unit","Y","dropdown",
    "","CMDOSU","CM"),
  c("F-CM-005","F-CM",5, "CMSTDAT","Start Date","Date",10,NA,"Y","date",
    "Partial dates allowed (YYYY or YYYY-MM)","CMSTDTC","CM"),
  c("F-CM-006","F-CM",6, "CMENDAT","End Date","Date",10,NA,"N","date",
    "Blank if ongoing","CMENDTC","CM"),
  c("F-CM-007","F-CM",7, "CMROUTE","Route","Char",30,"ORAL,IV,IM,SC,TOPICAL,OTHER","Y","dropdown",
    "","CMROUTE","CM"),
  c("F-CM-008","F-CM",8, "CMONGO","Ongoing at EOS (Y/N)","Char",1,"Y,N","Y","radio",
    "","CMONGO","CM"),

  # ---- PASI (9) ----
  c("F-PASI-001","F-PASI",1,"PASIDAT","Assessment Date","Date",10,NA,"Y","date",
    "ISO 8601","PASIDTC","EFF"),
  c("F-PASI-002","F-PASI",2,"PASIHEAD","PASI Head Region Score","Num",4,NA,"Y","number",
    "0-7.2 (severity 0-4 x area 0-6 x 0.1 weight)","PASIHEAD","EFF"),
  c("F-PASI-003","F-PASI",3,"PASIARMS","PASI Upper Limbs Score","Num",4,NA,"Y","number",
    "0-14.4 (weight 0.2)","PASIARMS","EFF"),
  c("F-PASI-004","F-PASI",4,"PASITRNK","PASI Trunk Score","Num",4,NA,"Y","number",
    "0-21.6 (weight 0.3)","PASITRNK","EFF"),
  c("F-PASI-005","F-PASI",5,"PASILEGS","PASI Lower Limbs Score","Num",4,NA,"Y","number",
    "0-28.8 (weight 0.4)","PASILEGS","EFF"),
  c("F-PASI-006","F-PASI",6,"PASITOT","PASI Total","Num",5,NA,"Y","number",
    "Sum of regions; range 0-72","PASITOT","EFF"),
  c("F-PASI-007","F-PASI",7,"PASISBT","BSA Trunk %","Num",4,NA,"N","number",
    "0-100","PASISBT","EFF"),
  c("F-PASI-008","F-PASI",8,"PASISBA","BSA Arms %","Num",4,NA,"N","number",
    "0-100","PASISBA","EFF"),
  c("F-PASI-009","F-PASI",9,"PASISBL","BSA Legs %","Num",4,NA,"N","number",
    "0-100","PASISBL","EFF"),

  # ---- LB (8) ----
  c("F-LB-001","F-LB",1, "LBTESTCD","Lab Test Code","Char",8,"WBC,HGB,PLT,ALT,AST,CREAT","Y","dropdown",
    "","LBTESTCD","LB"),
  c("F-LB-002","F-LB",2, "LBTEST","Lab Test Name","Char",40,NA,"Y","text",
    "Derived from LBTESTCD","LBTEST","LB"),
  c("F-LB-003","F-LB",3, "LBORRES","Result (Original)","Num",10,NA,"Y","number",
    "As reported by lab","LBORRES","LB"),
  c("F-LB-004","F-LB",4, "LBORRESU","Original Unit","Char",20,NA,"Y","text",
    "E.g., 10^9/L, g/dL","LBORRESU","LB"),
  c("F-LB-005","F-LB",5, "LBORNRLO","Normal Range Low","Num",10,NA,"N","number",
    "Lab-reported lower limit","LBSTNRLO","LB"),
  c("F-LB-006","F-LB",6, "LBORNRHI","Normal Range High","Num",10,NA,"N","number",
    "Lab-reported upper limit","LBSTNRHI","LB"),
  c("F-LB-007","F-LB",7, "LBDAT","Specimen Date","Date",10,NA,"Y","date",
    "ISO 8601","LBDTC","LB"),
  c("F-LB-008","F-LB",8, "LBNAM","Central Lab Name","Char",60,NA,"N","text",
    "Vendor name","LBNAM","LB")
)

fields <- as.data.frame(do.call(rbind, rows), stringsAsFactors = FALSE)
names(fields) <- c("FieldID", "FormID", "FieldOrder", "CDASH_Variable",
                   "FieldLabel", "DataType", "Length", "Codelist",
                   "RequiredYN", "ControlType", "HelpText",
                   "SDTM_Variable", "SDTM_Domain")
fields$FieldOrder <- as.integer(fields$FieldOrder)
fields$Length     <- as.integer(fields$Length)

out <- here("metadata", "fields_spec.xlsx")
write.xlsx(fields, out, overwrite = TRUE)
message(sprintf("Wrote %s (%d fields across %d forms)",
                out, nrow(fields), length(unique(fields$FormID))))

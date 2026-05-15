# Generates metadata/forms_spec.xlsx — top-level form metadata for IMM-PSO-3001.
# Run: Rscript metadata/_generate_forms_spec.R
suppressPackageStartupMessages({
  library(openxlsx)
  library(here)
})

forms <- data.frame(
  FormID         = c("F-DM", "F-IE", "F-AE", "F-CM", "F-PASI", "F-LB"),
  FormName       = c("Demographics",
                     "Inclusion/Exclusion Criteria",
                     "Adverse Events",
                     "Concomitant Medications",
                     "PASI Assessment",
                     "Laboratory Results"),
  FormShortName  = c("DM", "IE", "AE", "CM", "PASI", "LB"),
  CDASH_Domain   = c("DM", "IE", "AE", "CM", "EFF", "LB"),
  VisitSchedule  = c("Screening",
                     "Screening",
                     "Continuous from BL to EOS",
                     "Scr, BL, W4, W8, W12, W16, W24, W36, W52",
                     "Scr, BL, W4, W8, W12, W16, W24, W36, W52",
                     "Scr, BL, W4, W12, W24, W52"),
  RequiredYN     = c("Y", "Y", "N", "N", "Y", "Y"),
  EstimatedFields = c(8L, 4L, 12L, 8L, 9L, 8L),
  Comments       = c("One row per subject; demographic and disposition anchors.",
                     "One row per criterion (long format).",
                     "One row per AE per subject; non-required (some subjects have none).",
                     "One row per concomitant medication per subject.",
                     "Six regional sub-scores plus computed total.",
                     "One row per analyte per visit per subject."),
  stringsAsFactors = FALSE
)

out <- here("metadata", "forms_spec.xlsx")
write.xlsx(forms, out, overwrite = TRUE)
message(sprintf("Wrote %s (%d forms)", out, nrow(forms)))

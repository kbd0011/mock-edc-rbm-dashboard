# Map cleaned CDASH CSVs to SDTM datasets for DM, AE, LB.
#
# Inputs:  synthetic/raw/{dm,ae,ex,lb}.csv, metadata/mapping_spec.xlsx
# Outputs: data/sdtm/{dm,ae,lb}.rds + .xpt (via xportr)
#
# Usage:   Rscript R/01_cdash_to_sdtm.R

source(here::here("R", "00_setup.R"))

suppressPackageStartupMessages({
  library(haven)
  # xportr is optional locally but always available in CI per renv.lock.
  if (requireNamespace("xportr", quietly = TRUE)) library(xportr)
})

# ---- Reference tables ---------------------------------------------------

# MedDRA verbatim -> Preferred Term + System Organ Class.
# Hand-curated lookup for the AE terms that appear in synthetic data, with
# extra rows so the table is robust against minor variants. Real submissions
# would use a full MedDRA dictionary via Adminer/MedDRA Coder.
meddra_lookup <- tibble::tribble(
  ~verbatim,                               ~AEDECOD,                              ~AEBODSYS,
  "nasopharyngitis",                       "Nasopharyngitis",                     "Infections and infestations",
  "upper respiratory tract infection",     "Upper respiratory tract infection",   "Infections and infestations",
  "urinary tract infection",               "Urinary tract infection",             "Infections and infestations",
  "COVID-19",                              "COVID-19",                            "Infections and infestations",
  "headache",                              "Headache",                            "Nervous system disorders",
  "dizziness",                             "Dizziness",                           "Nervous system disorders",
  "injection site reaction",               "Injection site reaction",             "General disorders and administration site conditions",
  "fatigue",                               "Fatigue",                             "General disorders and administration site conditions",
  "arthralgia",                            "Arthralgia",                          "Musculoskeletal and connective tissue disorders",
  "back pain",                             "Back pain",                           "Musculoskeletal and connective tissue disorders",
  "hypertension",                          "Hypertension",                        "Vascular disorders",
  "diarrhea",                              "Diarrhoea",                           "Gastrointestinal disorders",
  "nausea",                                "Nausea",                              "Gastrointestinal disorders",
  "rash",                                  "Rash",                                "Skin and subcutaneous tissue disorders",
  "pruritus",                              "Pruritus",                            "Skin and subcutaneous tissue disorders",
  # Synonyms / minor variants
  "common cold",                           "Nasopharyngitis",                     "Infections and infestations",
  "URI",                                   "Upper respiratory tract infection",   "Infections and infestations",
  "UTI",                                   "Urinary tract infection",             "Infections and infestations",
  "stomach pain",                          "Abdominal pain",                      "Gastrointestinal disorders",
  "abdominal pain",                        "Abdominal pain",                      "Gastrointestinal disorders",
  "vomiting",                              "Vomiting",                            "Gastrointestinal disorders",
  "constipation",                          "Constipation",                        "Gastrointestinal disorders",
  "insomnia",                              "Insomnia",                            "Psychiatric disorders",
  "anxiety",                               "Anxiety",                             "Psychiatric disorders",
  "depression",                            "Depression",                          "Psychiatric disorders",
  "pyrexia",                               "Pyrexia",                             "General disorders and administration site conditions",
  "fever",                                 "Pyrexia",                             "General disorders and administration site conditions",
  "cough",                                 "Cough",                               "Respiratory, thoracic and mediastinal disorders",
  "dyspnoea",                              "Dyspnoea",                            "Respiratory, thoracic and mediastinal disorders",
  "shortness of breath",                   "Dyspnoea",                            "Respiratory, thoracic and mediastinal disorders",
  "asthma",                                "Asthma",                              "Respiratory, thoracic and mediastinal disorders",
  "myalgia",                               "Myalgia",                             "Musculoskeletal and connective tissue disorders",
  "muscle pain",                           "Myalgia",                             "Musculoskeletal and connective tissue disorders",
  "neck pain",                             "Neck pain",                           "Musculoskeletal and connective tissue disorders",
  "anaemia",                               "Anaemia",                             "Blood and lymphatic system disorders",
  "anemia",                                "Anaemia",                             "Blood and lymphatic system disorders",
  "lymphopenia",                           "Lymphocyte count decreased",          "Investigations",
  "neutropenia",                           "Neutrophil count decreased",          "Investigations",
  "alt increased",                         "Alanine aminotransferase increased",  "Investigations",
  "ast increased",                         "Aspartate aminotransferase increased","Investigations",
  "weight gain",                           "Weight increased",                    "Investigations",
  "weight loss",                           "Weight decreased",                    "Investigations",
  "skin infection",                        "Skin infection",                      "Infections and infestations",
  "cellulitis",                            "Cellulitis",                          "Infections and infestations",
  "folliculitis",                          "Folliculitis",                        "Infections and infestations",
  "tinea",                                 "Tinea pedis",                         "Infections and infestations",
  "psoriasis flare",                       "Psoriasis",                           "Skin and subcutaneous tissue disorders",
  "alopecia",                              "Alopecia",                            "Skin and subcutaneous tissue disorders",
  "acne",                                  "Acne",                                "Skin and subcutaneous tissue disorders",
  "eczema",                                "Eczema",                              "Skin and subcutaneous tissue disorders",
  "MACE",                                  "Cardiovascular event",                "Cardiac disorders",
  "myocardial infarction",                 "Myocardial infarction",               "Cardiac disorders"
)

# Lab reference ranges by test code. Used to populate LBSTNRLO/HI when the
# vendor LBORNRLO/HI is missing or differs (in a real study, vendor wins).
lb_ref_ranges <- tibble::tribble(
  ~LBTESTCD,  ~LBTEST,                                ~LBSTNRLO, ~LBSTNRHI, ~LBCAT,
  "WBC",      "Leukocytes",                            4.0,       11.0,      "HEMATOLOGY",
  "HGB",      "Hemoglobin",                           12.0,       17.0,      "HEMATOLOGY",
  "PLT",      "Platelets",                           150.0,      400.0,      "HEMATOLOGY",
  "ALT",      "Alanine Aminotransferase",             10.0,       40.0,      "CHEMISTRY",
  "AST",      "Aspartate Aminotransferase",           10.0,       40.0,      "CHEMISTRY",
  "CREAT",    "Creatinine",                            0.6,        1.3,      "CHEMISTRY"
)


# ---- Domain builders ----------------------------------------------------

build_dm <- function(cdash_dm, cdash_ex) {
  ex_first_last <- cdash_ex %>%
    mutate(
      EXSTDT = as_iso_date(EXSTDT),
      EXENDT = as_iso_date(EXENDT)
    ) %>%
    group_by(SUBJID) %>%
    summarise(
      RFSTDTC = as.character(min(EXSTDT, na.rm = TRUE)),
      RFENDTC = as.character(max(EXENDT, na.rm = TRUE)),
      EXTRT   = first(EXTRT),
      .groups = "drop"
    )

  cdash_dm %>%
    left_join(ex_first_last, by = "SUBJID") %>%
    mutate(
      STUDYID = STUDY_ID,
      DOMAIN  = "DM",
      USUBJID = paste0(STUDYID, "-", SUBJID),
      BRTHDTC = BRTHDAT,                              # already ISO from synth
      AGE     = suppressWarnings(as.integer(AGE)),
      AGEU    = AGEU,
      SITEID  = ifelse(is.na(SITEID) | SITEID == "",
                       site_from_subjid(SUBJID), SITEID),
      ARM     = ifelse(EXTRT == "Placebo", "Placebo", "IP-301 100 mg")
    ) %>%
    select(STUDYID, DOMAIN, USUBJID, SUBJID, SITEID,
           BRTHDTC, AGE, AGEU, SEX, RACE, ETHNIC, COUNTRY,
           ARM, RFSTDTC, RFENDTC)
}


build_ae <- function(cdash_ae, sdtm_dm) {
  cdash_ae %>%
    filter(!is.na(AETERM) & AETERM != "") %>%
    # Drop the empty CDASH placeholders before the MedDRA join to avoid
    # AEDECOD.x / AEDECOD.y column collisions.
    select(-any_of(c("AEDECOD", "AESOC"))) %>%
    left_join(sdtm_dm %>% select(SUBJID, USUBJID), by = "SUBJID") %>%
    left_join(meddra_lookup, by = c("AETERM" = "verbatim")) %>%
    mutate(
      STUDYID  = STUDY_ID,
      DOMAIN   = "AE",
      AESTDTC  = AESTDAT,
      AEENDTC  = AEENDAT,
      AETOXGR  = suppressWarnings(as.integer(AETOXGR)),
      AEDECOD  = coalesce(AEDECOD, AETERM),       # fallback to verbatim if unmapped
      AEBODSYS = coalesce(AEBODSYS, "Investigations")
    ) %>%
    group_by(SUBJID) %>%
    arrange(AESTDTC, .by_group = TRUE) %>%
    mutate(AESEQ = row_number()) %>%
    ungroup() %>%
    select(STUDYID, DOMAIN, USUBJID, SITEID, AESEQ,
           AETERM, AEDECOD, AEBODSYS, AESTDTC, AEENDTC,
           AESEV, AESER, AEREL, AEACN, AEOUT, AETOXGR)
}


build_lb <- function(cdash_lb, sdtm_dm) {
  cdash_lb %>%
    filter(!is.na(LBORRES) & LBORRES != "") %>%
    left_join(sdtm_dm %>% select(SUBJID, USUBJID), by = "SUBJID") %>%
    left_join(lb_ref_ranges %>% select(LBTESTCD, LBSTNRLO, LBSTNRHI, LBCAT),
              by = "LBTESTCD") %>%
    mutate(
      STUDYID  = STUDY_ID,
      DOMAIN   = "LB",
      LBDTC    = LBDAT,
      LBSTRESN = suppressWarnings(as.numeric(LBORRES)),
      LBSTRESC = as.character(LBSTRESN)
    ) %>%
    group_by(SUBJID) %>%
    arrange(LBDTC, LBTESTCD, .by_group = TRUE) %>%
    mutate(LBSEQ = row_number()) %>%
    ungroup() %>%
    select(STUDYID, DOMAIN, USUBJID, SITEID, LBSEQ,
           LBTESTCD, LBTEST, LBCAT, LBORRES, LBORRESU,
           LBSTRESC, LBSTRESN, LBSTNRLO, LBSTNRHI, LBDTC)
}


# ---- Main ---------------------------------------------------------------

main <- function() {
  cli_h1("CDASH -> SDTM mapping for IMM-PSO-3001")

  dm_in <- read_form("dm")
  ae_in <- read_form("ae")
  ex_in <- read_form("ex")
  lb_in <- read_form("lb")

  cli_alert_info("Building DM...")
  dm <- build_dm(dm_in, ex_in)
  saveRDS(dm, file.path(PATH_SDTM, "dm.rds"))

  cli_alert_info("Building AE...")
  ae <- build_ae(ae_in, dm)
  saveRDS(ae, file.path(PATH_SDTM, "ae.rds"))

  cli_alert_info("Building LB...")
  lb <- build_lb(lb_in, dm)
  saveRDS(lb, file.path(PATH_SDTM, "lb.rds"))

  # Also write SAS transport (xpt) when haven is available.
  write_xpt(dm, file.path(PATH_SDTM, "dm.xpt"), version = 5, name = "DM")
  write_xpt(ae, file.path(PATH_SDTM, "ae.xpt"), version = 5, name = "AE")
  write_xpt(lb, file.path(PATH_SDTM, "lb.xpt"), version = 5, name = "LB")

  cli_alert_success(sprintf("Wrote DM (%d), AE (%d), LB (%d) to %s",
                            nrow(dm), nrow(ae), nrow(lb), PATH_SDTM))
}

if (!interactive()) main()

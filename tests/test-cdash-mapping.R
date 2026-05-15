# testthat: CDASH -> SDTM mapping correctness.
#
# Run from repo root via:
#   Rscript -e "testthat::test_dir('tests')"

library(testthat)
suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
  library(here)
})

source(here("R", "00_setup.R"))
source(here("R", "01_cdash_to_sdtm.R"))


# ---- DM -----------------------------------------------------------------

test_that("build_dm derives USUBJID correctly", {
  dm <- tibble(SITEID = "S001", SUBJID = "S001-0042",
               BRTHDAT = "1975-01-01", AGE = "50", AGEU = "YEARS",
               SEX = "M", RACE = "WHITE", ETHNIC = "NOT HISPANIC OR LATINO",
               COUNTRY = "USA")
  ex <- tibble(SITEID = "S001", SUBJID = "S001-0042",
               EXTRT = "IP-301 100 mg", EXSTDT = "2025-01-15",
               EXENDT = "2026-01-15", EXDOSE = "100", EXDOSU = "mg",
               EXROUTE = "SC")
  out <- build_dm(dm, ex)
  expect_equal(out$USUBJID, "IMM-PSO-3001-S001-0042")
  expect_equal(out$STUDYID, STUDY_ID)
  expect_equal(out$DOMAIN, "DM")
  expect_equal(out$AGE, 50L)
})


test_that("build_dm pulls RFSTDTC and RFENDTC from EX", {
  dm <- tibble(SITEID = "S001", SUBJID = "S001-0001",
               BRTHDAT = "1980-06-15", AGE = "44", AGEU = "YEARS",
               SEX = "F", RACE = "WHITE", ETHNIC = "NOT HISPANIC OR LATINO",
               COUNTRY = "USA")
  ex <- tibble(SITEID = "S001", SUBJID = "S001-0001",
               EXTRT = "Placebo", EXSTDT = "2025-02-01",
               EXENDT = "2026-02-01", EXDOSE = "0", EXDOSU = "mg",
               EXROUTE = "SC")
  out <- build_dm(dm, ex)
  expect_equal(out$RFSTDTC, "2025-02-01")
  expect_equal(out$RFENDTC, "2026-02-01")
  expect_equal(out$ARM, "Placebo")
})


# ---- AE -----------------------------------------------------------------

test_that("build_ae assigns within-subject sequential AESEQ", {
  dm <- tibble(SITEID = "S001", SUBJID = "S001-0001",
               USUBJID = "IMM-PSO-3001-S001-0001")
  ae <- tibble(
    SITEID = c("S001", "S001", "S001"),
    SUBJID = c("S001-0001", "S001-0001", "S001-0001"),
    AETERM = c("headache", "nausea", "rash"),
    AESTDAT = c("2025-04-01", "2025-04-05", "2025-04-03"),
    AEENDAT = c("2025-04-02", NA, "2025-04-04"),
    AESEV = c("MILD", "MILD", "MILD"),
    AESER = c("N", "N", "N"),
    AEREL = c("RELATED", "NOT RELATED", "RELATED"),
    AEACN = c("DOSE NOT CHANGED", "DOSE NOT CHANGED", "DOSE NOT CHANGED"),
    AEOUT = c("RECOVERED/RESOLVED", "RECOVERING/RESOLVING", "RECOVERED/RESOLVED"),
    AETOXGR = c("1", "1", "2"),
    AENONST = c("", "", "")
  )
  out <- build_ae(ae, dm)
  expect_equal(nrow(out), 3)
  expect_equal(out$AESEQ, c(1L, 2L, 3L))
  # Sorted by AESTDTC ascending within subject
  expect_equal(out$AETERM, c("headache", "rash", "nausea"))
})


test_that("build_ae maps verbatim AETERM to MedDRA PT", {
  dm <- tibble(SITEID = "S001", SUBJID = "S001-0001",
               USUBJID = "IMM-PSO-3001-S001-0001")
  ae <- tibble(SITEID = "S001", SUBJID = "S001-0001",
               AETERM = "diarrhea", AESTDAT = "2025-04-01",
               AEENDAT = NA, AESEV = "MILD", AESER = "N",
               AEREL = "NOT RELATED", AEACN = "DOSE NOT CHANGED",
               AEOUT = "RECOVERED/RESOLVED", AETOXGR = "1", AENONST = "")
  out <- build_ae(ae, dm)
  expect_equal(out$AEDECOD, "Diarrhoea")
  expect_equal(out$AEBODSYS, "Gastrointestinal disorders")
})


# ---- LB -----------------------------------------------------------------

test_that("build_lb attaches reference ranges from lookup", {
  dm <- tibble(SITEID = "S001", SUBJID = "S001-0001",
               USUBJID = "IMM-PSO-3001-S001-0001")
  lb <- tibble(SITEID = "S001", SUBJID = "S001-0001",
               VISIT = "BASELINE", LBTESTCD = "WBC",
               LBTEST = "Leukocytes", LBORRES = "7.2",
               LBORRESU = "10^9/L", LBORNRLO = "4.0", LBORNRHI = "11.0",
               LBDAT = "2025-02-01", LBNAM = "Central Lab Services Inc.")
  out <- build_lb(lb, dm)
  expect_equal(out$LBSTNRLO, 4.0)
  expect_equal(out$LBSTNRHI, 11.0)
  expect_equal(out$LBCAT, "HEMATOLOGY")
  expect_equal(out$LBSTRESN, 7.2)
})


test_that("build_lb drops rows with blank LBORRES", {
  dm <- tibble(SITEID = "S001", SUBJID = "S001-0001",
               USUBJID = "IMM-PSO-3001-S001-0001")
  lb <- tibble(SITEID = c("S001","S001"),
               SUBJID = c("S001-0001","S001-0001"),
               VISIT = c("BASELINE","BASELINE"),
               LBTESTCD = c("WBC","HGB"),
               LBTEST = c("Leukocytes","Hemoglobin"),
               LBORRES = c("7.2", ""),
               LBORRESU = c("10^9/L","g/dL"),
               LBORNRLO = c("4.0","12.0"),
               LBORNRHI = c("11.0","17.0"),
               LBDAT = c("2025-02-01","2025-02-01"),
               LBNAM = c("Central","Central"))
  out <- build_lb(lb, dm)
  expect_equal(nrow(out), 1)
})

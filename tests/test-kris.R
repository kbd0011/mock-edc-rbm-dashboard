# testthat: KRI computation correctness.
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
source(here("R", "02_compute_kris.R"))


# ---- flag() helper ------------------------------------------------------

test_that("flag classifies HIGH/LOW/NORMAL correctly", {
  expect_equal(flag(0.3, low = 0.5, high = 2.0), "LOW")
  expect_equal(flag(1.0, low = 0.5, high = 2.0), "NORMAL")
  expect_equal(flag(2.5, low = 0.5, high = 2.0), "HIGH")
  expect_true(is.na(flag(NA, low = 0.5, high = 2.0)))
})


# ---- KRI-01 Enrollment rate ---------------------------------------------

test_that("kri_enrollment_rate counts subjects in 90d window", {
  snap <- as.Date("2025-04-01")
  dm <- tibble(
    SITEID = c("S001", "S001", "S001", "S002"),
    SUBJID = c("S001-0001", "S001-0002", "S001-0003", "S002-0001"),
    RFSTDTC = as.character(c(snap - 30, snap - 60, snap - 120, snap - 5))
  )
  out <- kri_enrollment_rate(dm, snap)
  s001 <- out %>% filter(site == "S001")
  expect_equal(s001$value, 2 / 3)         # only 2 of 3 within 90d / 3 months
  s002 <- out %>% filter(site == "S002")
  expect_equal(s002$value, 1 / 3)
})


# ---- KRI-02 Query rate --------------------------------------------------

test_that("kri_query_rate divides open queries by site n_subjects", {
  snap <- as.Date("2025-04-01")
  dm <- tibble(SITEID = c("S001","S001","S002"),
               SUBJID = c("S001-0001","S001-0002","S002-0001"),
               RFSTDTC = "2025-01-01")
  queries <- tibble(site = c("S001","S001","S001","S002"),
                    status = c("Open","Open","Closed","Open"))
  out <- kri_query_rate(queries, dm, snap)
  expect_equal(out %>% filter(site == "S001") %>% pull(value), 1.0)  # 2 open / 2 subj
  expect_equal(out %>% filter(site == "S002") %>% pull(value), 1.0)  # 1 open / 1 subj
})


test_that("kri_query_rate flags HIGH above threshold 5", {
  snap <- as.Date("2025-04-01")
  dm <- tibble(SITEID = "S001", SUBJID = "S001-0001",
               RFSTDTC = "2025-01-01")
  queries <- tibble(site = rep("S001", 6), status = rep("Open", 6))
  out <- kri_query_rate(queries, dm, snap)
  expect_equal(out$threshold_flag, "HIGH")
  expect_equal(out$value, 6)
})


# ---- KRI-03 AE latency --------------------------------------------------

test_that("kri_ae_latency computes median lag in days", {
  snap <- as.Date("2025-04-01")
  ae_raw <- tibble(
    SITEID = c("S001", "S001", "S001"),
    SUBJID = c("S001-0001", "S001-0001", "S001-0001"),
    AESTDAT = as.character(c(snap - 60, snap - 50, snap - 40)),
    AE_ENTRY_DTC = as.character(c(snap - 58, snap - 47, snap - 30))
  )
  # lags = 2, 3, 10 days; median = 3
  out <- kri_ae_latency(ae_raw, snap)
  expect_equal(out$value, 3)
})


# ---- KRI-04 Protocol deviations -----------------------------------------

test_that("kri_protocol_deviations computes per-10-subject rate", {
  snap <- as.Date("2025-04-01")
  dm <- tibble(SITEID = rep("S001", 20),
               SUBJID = paste0("S001-", sprintf("%04d", 1:20)),
               RFSTDTC = "2025-01-01")
  pdev <- tibble(SITEID = rep("S001", 8),
                 SUBJID = paste0("S001-", sprintf("%04d", 1:8)),
                 deviation_date = "2025-03-01",
                 category = "missed assessment")
  out <- kri_protocol_deviations(pdev, dm, snap)
  expect_equal(out$value, 4)   # 8 dev / (20/10) = 4
  expect_equal(out$threshold_flag, "HIGH")   # > 3
})


# ---- KRI-06 Lab OOR -----------------------------------------------------

test_that("kri_lab_oor computes percentage out-of-range", {
  snap <- as.Date("2025-04-01")
  lb <- tibble(
    SITEID = rep("S001", 4),
    LBORRES = c(7.0, 100.0, 6.5, 0.001),
    LBSTNRLO = rep(4.0, 4),
    LBSTNRHI = rep(11.0, 4)
  )
  # 2 of 4 are OOR (100, 0.001)
  out <- kri_lab_oor(lb, snap)
  expect_equal(out$value, 50)
  expect_equal(out$threshold_flag, "NORMAL")  # info-only KRI
})

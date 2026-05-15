# Compute 6 RBQM KRIs per site for the Shiny dashboard.
#
# Inputs:
#   data/sdtm/{dm,ae,lb}.rds       (mapped clinical data)
#   synthetic/raw/{ae,protocol_deviations,...}.csv (operational metadata)
#   data/queries/query_log.csv     (open queries from edit-check engine)
#   metadata/fields_spec.xlsx      (required-field accounting for KRI-05)
#
# Outputs:
#   data/kris.rds            long tibble: site, kri_name, value, date,
#                             threshold_flag, denominator
#   data/kris_timeseries.rds long tibble: site, kri_name, week_start,
#                             value, threshold_flag
#
# Definitions and thresholds: see docs/kri_definitions.md.

source(here::here("R", "00_setup.R"))

# ---- Snapshot date helper -----------------------------------------------

# Snapshot is set to max(RFSTDTC) + 30 days — i.e., the point just after the
# last subject was enrolled. This puts the trial in active monitoring (most
# subjects mid-treatment, enrollment recently active, AE accrual ongoing),
# which is when RBQM dashboards are actually consulted. Using max of all
# dates would land at end-of-study with no enrollment and few recent AEs.
snapshot_from_rfstdtc <- function(rfstdtc) {
  d <- suppressWarnings(as.Date(rfstdtc))
  d <- d[!is.na(d)]
  if (!length(d)) Sys.Date() else max(d) + 30
}

# Generic threshold flagger.
flag <- function(value, low = NA_real_, high = NA_real_) {
  if (is.na(value)) return(NA_character_)
  if (!is.na(low)  && value < low)  return("LOW")
  if (!is.na(high) && value > high) return("HIGH")
  "NORMAL"
}


# ---- KRI-01: Enrollment Rate ---------------------------------------------

kri_enrollment_rate <- function(dm, snapshot_date) {
  window_start <- snapshot_date - 90
  dm_rf <- dm %>%
    mutate(RFSTDTC = as_iso_date(RFSTDTC)) %>%
    filter(!is.na(RFSTDTC),
           RFSTDTC >= window_start,
           RFSTDTC <= snapshot_date)
  per_site <- dm_rf %>%
    count(SITEID, name = "n_subjects") %>%
    mutate(value           = n_subjects / 3,  # 3 months in 90d window
           threshold_flag  = vapply(value, flag, character(1), low = 0.5, high = 2.0),
           kri_name        = "enrollment_rate",
           date            = snapshot_date,
           denominator     = 3L) %>%
    select(site = SITEID, kri_name, value, date, threshold_flag, denominator)

  all_sites <- sort(unique(dm$SITEID))
  missing_sites <- setdiff(all_sites, per_site$site)
  if (length(missing_sites)) {
    per_site <- bind_rows(per_site, tibble(
      site = missing_sites, kri_name = "enrollment_rate",
      value = 0, date = snapshot_date, threshold_flag = "LOW", denominator = 3L
    ))
  }
  per_site
}


# ---- KRI-02: Query Rate --------------------------------------------------

kri_query_rate <- function(queries, dm, snapshot_date) {
  open_per_site <- queries %>%
    filter(status == "Open") %>%
    count(site, name = "n_open")
  subj_per_site <- dm %>% distinct(SITEID, SUBJID) %>% count(SITEID, name = "n_subj")

  dm_sites <- sort(unique(dm$SITEID))
  open_per_site <- open_per_site %>% right_join(tibble(site = dm_sites), by = "site")
  open_per_site$n_open[is.na(open_per_site$n_open)] <- 0

  subj_per_site %>%
    rename(site = SITEID) %>%
    left_join(open_per_site, by = "site") %>%
    mutate(value          = n_open / pmax(n_subj, 1),
           threshold_flag = vapply(value, flag, character(1), high = 5.0),
           kri_name       = "query_rate",
           date           = snapshot_date,
           denominator    = n_subj) %>%
    select(site, kri_name, value, date, threshold_flag, denominator)
}


# ---- KRI-03: AE Reporting Latency ----------------------------------------

kri_ae_latency <- function(ae_raw, snapshot_date) {
  window_start <- snapshot_date - 90
  ae_window <- ae_raw %>%
    mutate(AESTDAT      = as_iso_date(AESTDAT),
           AE_ENTRY_DTC = as_iso_date(AE_ENTRY_DTC),
           lag_days     = as.numeric(AE_ENTRY_DTC - AESTDAT)) %>%
    filter(!is.na(lag_days),
           AESTDAT >= window_start,
           AESTDAT <= snapshot_date)
  per_site <- ae_window %>%
    group_by(site = SITEID) %>%
    summarise(value = median(lag_days, na.rm = TRUE),
              n     = n(),
              .groups = "drop") %>%
    mutate(threshold_flag = vapply(value, flag, character(1), high = 5.0),
           kri_name       = "ae_latency_days",
           date           = snapshot_date,
           denominator    = n) %>%
    select(site, kri_name, value, date, threshold_flag, denominator)

  # Ensure all sites appear, even if no AEs in window.
  all_sites <- sort(unique(ae_raw$SITEID))
  miss <- setdiff(all_sites, per_site$site)
  if (length(miss)) {
    per_site <- bind_rows(per_site, tibble(
      site = miss, kri_name = "ae_latency_days",
      value = NA_real_, date = snapshot_date,
      threshold_flag = NA_character_, denominator = 0L
    ))
  }
  per_site
}


# ---- KRI-04: Protocol Deviation Rate -------------------------------------

kri_protocol_deviations <- function(pdev, dm, snapshot_date) {
  dev_counts <- pdev %>% count(site = SITEID, name = "n_dev")
  subj_counts <- dm %>% distinct(SITEID, SUBJID) %>%
    count(site = SITEID, name = "n_subj")

  subj_counts %>%
    left_join(dev_counts, by = "site") %>%
    mutate(n_dev          = coalesce(n_dev, 0L),
           value          = n_dev / (n_subj / 10),
           threshold_flag = vapply(value, flag, character(1), high = 3.0),
           kri_name       = "protocol_deviation_rate",
           date           = snapshot_date,
           denominator    = n_subj) %>%
    select(site, kri_name, value, date, threshold_flag, denominator)
}


# ---- KRI-05: Missing Data Rate -------------------------------------------

# Computed against the curated set of fields susceptible to entry-time blanks
# (listed in error_profile.yml::missing_required_fields.fields), not against
# every required field. Industry RBQM dashboards monitor a curated KRI field
# set rather than all-or-nothing required-completeness — hard-coded constants
# like AGEU and COUNTRY would dilute the signal otherwise. See docs/kri_definitions.md.
kri_missing_data <- function(snapshot_date) {
  cfg <- yaml::read_yaml(file.path(PATH_METADATA, "error_profile.yml"))
  tracked <- strsplit(cfg$error_injection$missing_required_fields$fields, ".",
                      fixed = TRUE)
  tracked <- do.call(rbind, lapply(tracked, function(x)
    data.frame(form_key = tolower(x[[1]]), field = x[[2]],
               stringsAsFactors = FALSE)))

  per_form <- function(form_key) {
    flds <- tracked$field[tracked$form_key == form_key]
    if (!length(flds)) return(tibble())
    df <- read_form(form_key)
    keep <- intersect(flds, names(df))
    if (!length(keep)) return(tibble())
    df %>%
      select(SITEID, all_of(keep)) %>%
      pivot_longer(cols = -SITEID, names_to = "field", values_to = "value") %>%
      mutate(is_blank = is.na(value) | trimws(value) == "") %>%
      group_by(SITEID) %>%
      summarise(blank = sum(is_blank),
                total = n(),
                .groups = "drop") %>%
      mutate(form_key = form_key)
  }

  long <- bind_rows(lapply(unique(tracked$form_key), per_form))
  long %>%
    group_by(site = SITEID) %>%
    summarise(blank = sum(blank), total = sum(total), .groups = "drop") %>%
    mutate(value          = ifelse(total > 0, 100 * blank / total, 0),
           threshold_flag = vapply(value, flag, character(1), high = 10.0),
           kri_name       = "missing_data_pct",
           date           = snapshot_date,
           denominator    = total) %>%
    select(site, kri_name, value, date, threshold_flag, denominator)
}


# ---- KRI-06: Lab Out-of-Range Rate ---------------------------------------

kri_lab_oor <- function(lb, snapshot_date) {
  lb %>%
    mutate(num = suppressWarnings(as.numeric(LBORRES)),
           lo  = suppressWarnings(as.numeric(LBSTNRLO)),
           hi  = suppressWarnings(as.numeric(LBSTNRHI)),
           oor = !is.na(num) & !is.na(lo) & !is.na(hi) & (num < lo | num > hi)) %>%
    group_by(site = SITEID) %>%
    summarise(oor = sum(oor), total = n(), .groups = "drop") %>%
    mutate(value          = ifelse(total > 0, 100 * oor / total, 0),
           threshold_flag = "NORMAL",          # info-only KRI per definitions doc
           kri_name       = "lab_oor_pct",
           date           = snapshot_date,
           denominator    = total) %>%
    select(site, kri_name, value, date, threshold_flag, denominator)
}


# ---- Weekly time-series wrapper -----------------------------------------

# For sparklines: re-compute snapshot KRIs at the END of each ISO week between
# the earliest treatment start and snapshot_date. Cheap and correct enough.
weekly_timeseries <- function(dm, ae_raw, lb, pdev, queries, snapshot_date) {
  starts <- as_iso_date(dm$RFSTDTC)
  first  <- min(starts, na.rm = TRUE)
  if (!is.finite(as.numeric(first))) first <- snapshot_date - 90
  # Mondays from first onwards.
  weeks <- seq.Date(first, snapshot_date, by = "1 week")

  ts <- lapply(weeks, function(w) {
    bind_rows(
      kri_enrollment_rate(dm, w),
      kri_query_rate(queries, dm, w),
      kri_ae_latency(ae_raw, w),
      kri_lab_oor(lb, w)
    ) %>% mutate(week_start = w)
  })
  bind_rows(ts) %>%
    select(site, kri_name, week_start, value, threshold_flag)
}


# ---- Main ---------------------------------------------------------------

main <- function() {
  cli_h1("Compute RBQM KRIs for IMM-PSO-3001")

  dm  <- readRDS(file.path(PATH_SDTM, "dm.rds"))
  ae_sdtm <- readRDS(file.path(PATH_SDTM, "ae.rds"))
  lb  <- readRDS(file.path(PATH_SDTM, "lb.rds"))
  ae_raw <- read_form("ae")
  pdev <- read_csv(file.path(PATH_SYNTH, "protocol_deviations.csv"),
                   show_col_types = FALSE)
  queries <- read_csv(file.path(PATH_QUERIES, "query_log.csv"),
                      show_col_types = FALSE)

  snap <- snapshot_from_rfstdtc(dm$RFSTDTC)
  cli_alert_info(sprintf("Snapshot date: %s (last enrollment + 30d)", snap))

  kris <- bind_rows(
    kri_enrollment_rate(dm,  snap),
    kri_query_rate(queries, dm, snap),
    kri_ae_latency(ae_raw, snap),
    kri_protocol_deviations(pdev, dm, snap),
    kri_missing_data(snap),
    kri_lab_oor(lb, snap)
  )
  saveRDS(kris, here::here("data", "kris.rds"))

  cli_alert_info("Computing weekly time series (this is the slow step)...")
  ts <- weekly_timeseries(dm, ae_raw, lb, pdev, queries, snap)
  saveRDS(ts, here::here("data", "kris_timeseries.rds"))

  # Brief summary to stdout
  cli_h2("KRI snapshot")
  summary_tbl <- kris %>%
    group_by(kri_name) %>%
    summarise(n_HIGH = sum(threshold_flag == "HIGH", na.rm = TRUE),
              n_LOW  = sum(threshold_flag == "LOW",  na.rm = TRUE),
              median = round(median(value, na.rm = TRUE), 2),
              .groups = "drop")
  print(summary_tbl)
  cli_alert_success(sprintf("Wrote data/kris.rds (%d rows) and data/kris_timeseries.rds (%d rows)",
                            nrow(kris), nrow(ts)))
}

if (!interactive()) main()

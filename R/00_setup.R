# Shared setup: libraries, paths, constants. Sourced by 01_cdash_to_sdtm.R,
# 02_compute_kris.R, and the Shiny app's helpers.

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(purrr)
  library(stringr)
  library(lubridate)
  library(here)
  library(fs)
  library(cli)
  library(openxlsx)
})

# ---- Constants ----------------------------------------------------------

STUDY_ID <- "IMM-PSO-3001"

# ---- Paths --------------------------------------------------------------

PATH_SYNTH    <- here("synthetic", "raw")
PATH_SDTM     <- here("data",      "sdtm")
PATH_QUERIES  <- here("data",      "queries")
PATH_METADATA <- here("metadata")
PATH_DOCS     <- here("docs")

dir_create(PATH_SDTM)
dir_create(PATH_QUERIES)

# ---- Small utilities ----------------------------------------------------

# Read a CSV from synthetic/raw, with character coercion to preserve blanks
# and date strings as-is (downstream code parses dates explicitly).
read_form <- function(name) {
  path <- file.path(PATH_SYNTH, paste0(name, ".csv"))
  read_csv(path, col_types = cols(.default = "c"), show_col_types = FALSE)
}

# Parse an ISO date string column, returning Date (NA for blank/bad).
as_iso_date <- function(x) as.Date(x, format = "%Y-%m-%d")

# Site ID extracted from SUBJID prefix (format S###-####).
site_from_subjid <- function(subjid) str_extract(subjid, "^S[0-9]{3}")

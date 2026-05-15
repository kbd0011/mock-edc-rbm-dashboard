# IMM-PSO-3001 — RBQM Dashboard (Shiny entry point)

suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(plotly)
  library(DT)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(here)
  library(stringr)
  library(lubridate)
  library(ggplot2)
})

# ---- Module sources ----------------------------------------------------

source("R/ui_overview.R")
source("R/ui_kri_detail.R")
source("R/ui_query_log.R")
source("R/server_overview.R")
source("R/server_kri_detail.R")
source("R/server_query_log.R")


# ---- Data load (once at startup) ---------------------------------------

# Locate the directory that holds data/ and synthetic/. Locally the app runs
# from shiny/ so the data lives at ../data; on shinyapps.io we stage data
# into shiny/data before deploy so it lives at ./data. Try both.
.find_root <- function() {
  for (cand in c(".", "..")) {
    if (file.exists(file.path(cand, "data", "kris.rds"))) return(cand)
  }
  stop("Cannot locate data/ directory from working dir: ", getwd())
}
ROOT <- .find_root()

load_data <- function() {
  list(
    kris      = readRDS(file.path(ROOT, "data", "kris.rds")),
    kris_ts   = readRDS(file.path(ROOT, "data", "kris_timeseries.rds")),
    queries   = readr::read_csv(file.path(ROOT, "data", "queries", "query_log.csv"),
                                show_col_types = FALSE),
    dm        = readRDS(file.path(ROOT, "data", "sdtm", "dm.rds")),
    ae        = readRDS(file.path(ROOT, "data", "sdtm", "ae.rds")),
    lb        = readRDS(file.path(ROOT, "data", "sdtm", "lb.rds"))
  )
}

state <- load_data()


# ---- KRI display metadata ----------------------------------------------

KRI_META <- tibble::tribble(
  ~kri_name,                ~label,                    ~unit,         ~format,
  "enrollment_rate",        "Enrollment rate",         "subj/site/mo", "%.2f",
  "query_rate",             "Query rate",              "queries/subj", "%.1f",
  "ae_latency_days",        "AE reporting latency",    "days (median)", "%.1f",
  "protocol_deviation_rate","Protocol deviation rate", "per 10 subj",  "%.2f",
  "missing_data_pct",       "Missing-data rate",       "% blank",      "%.1f",
  "lab_oor_pct",            "Lab out-of-range rate",   "% (info)",     "%.1f"
)


# ---- UI ----------------------------------------------------------------

ui_about <- function() {
  div(class = "about-pane",
    h3("About this dashboard"),
    p("This is a portfolio demonstration of a Risk-Based Quality Management ",
      "(RBQM) dashboard for a fictional Phase III plaque psoriasis trial ",
      "(IMM-PSO-3001). All subjects, sites, and events are synthetic."),
    p("Built per ICH E6(R3) Annex E centralized monitoring guidance and the ",
      "TransCelerate RBQM framework. CDASH 2.2 / SDTMIG 3.3 aligned."),
    h4("Stack"),
    tags$ul(
      tags$li("Synthetic data: Python (pandas, faker), seeded for reproducibility"),
      tags$li("Edit-check engine: Python (declarative YAML/Excel-driven)"),
      tags$li("CDASH → SDTM mapping: R (dplyr, metacore, xportr)"),
      tags$li("KRI compute: R")
    ),
    p(tags$a(href = "https://github.com/kbd0011/mock-edc-rbm-dashboard",
             target = "_blank", "Source code on GitHub"))
  )
}

ui <- page_navbar(
  title = "IMM-PSO-3001 — RBQM Dashboard",
  theme = bs_theme(version = 5, bootswatch = "flatly",
                   primary = "#0b3d91", "navbar-bg" = "#0b3d91"),
  header = tags$head(
    tags$link(rel = "stylesheet", href = "style.css"),
    tags$meta(name = "viewport", content = "width=device-width,initial-scale=1")
  ),
  nav_panel("Overview",   ui_overview()),
  nav_panel("KRI Detail", ui_kri_detail(KRI_META)),
  nav_panel("Query Log",  ui_query_log()),
  nav_panel("About",      ui_about())
)


# ---- Server ------------------------------------------------------------

server <- function(input, output, session) {
  server_overview(input, output, session, state, KRI_META)
  server_kri_detail(input, output, session, state, KRI_META)
  server_query_log(input, output, session, state)
}

shinyApp(ui, server)

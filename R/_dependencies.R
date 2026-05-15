# Dependency hints for renv's static analyzer.
#
# renv::snapshot() walks R source files and records packages it sees in
# library()/require() calls. Some of our packages are loaded only at runtime
# from non-scanned locations (tests/, Quarto YAML, rsconnect via Makefile),
# so we list them here behind `if (FALSE)` to keep the lockfile complete
# without executing anything.

if (FALSE) {
  library(testthat)     # used by tests/test-*.R
  library(rsconnect)    # used by make deploy
  library(rmarkdown)    # used by Quarto rendering
  library(knitr)        # used by Quarto chunks
  library(quarto)       # used by R wrapper around quarto render
  library(patchwork)    # potential plot composition (utility)
  library(scales)       # ggplot scale helpers (utility)
  library(shinyWidgets) # optional Shiny extras
  library(shinyalert)
  library(reactable)
  library(rhandsontable)
  library(simstudy)     # available for synthetic data work
  library(wakefield)
  library(metatools)
  library(haven)        # used by R/01_cdash_to_sdtm.R for write_xpt
  library(janitor)
  library(bsicons)      # icons in Shiny value_box
  library(yaml)         # error_profile.yml loader
  library(flextable)    # CRF and DMP tables
  library(plotly)       # explicit pin
  library(DT)
}

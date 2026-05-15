# Phase 0 bootstrap: install all R packages, initialize renv, snapshot.
# Run once after cloning, BEFORE any pipeline scripts.
#
# Usage from repo root:
#   Rscript R/install_packages.R

# 0. Native build env (macOS) ----------------------------------------------
# Force Homebrew's pkg-config and libraries ahead of any Anaconda install.
# Without this, packages like xml2 link against /opt/anaconda3/lib with an
# @rpath that R cannot resolve at dyn.load time.
if (Sys.info()[["sysname"]] == "Darwin") {
  brew_pkgcfg <- c(
    "/opt/homebrew/opt/libxml2/lib/pkgconfig",
    "/opt/homebrew/opt/openssl@3/lib/pkgconfig",
    "/opt/homebrew/opt/freetype/lib/pkgconfig",
    "/opt/homebrew/opt/harfbuzz/lib/pkgconfig",
    "/opt/homebrew/lib/pkgconfig",
    "/opt/homebrew/share/pkgconfig"
  )
  Sys.setenv(PKG_CONFIG_PATH = paste(brew_pkgcfg, collapse = ":"))
  brew_bin <- c(
    "/opt/homebrew/opt/libxml2/bin",
    "/opt/homebrew/opt/openssl@3/bin",
    "/opt/homebrew/bin"
  )
  Sys.setenv(PATH = paste(c(brew_bin, Sys.getenv("PATH")), collapse = ":"))
}

# 1. CRAN mirror -----------------------------------------------------------
options(repos = c(CRAN = "https://packagemanager.posit.co/cran/latest"))

# 2. Build mode: Homebrew R has no CRAN binaries, must compile from source.
is_homebrew_r <- grepl("homebrew", R.home(), ignore.case = TRUE) ||
                 grepl("/opt/homebrew", R.home())
if (is_homebrew_r) {
  options(pkgType = "source")
} else {
  options(pkgType = "both")
  options(install.packages.compile.from.source = "never")
}

# 3. Package list ----------------------------------------------------------
pkgs <- c(
  # bootstrap
  "renv", "remotes",
  # Shiny + dashboard
  "shiny", "shinydashboard", "bslib", "DT", "plotly", "shinyWidgets",
  "shinyalert", "reactable", "rhandsontable",
  # tidyverse / IO
  "dplyr", "tidyr", "purrr", "readr", "lubridate", "stringr", "janitor",
  # visualization
  "ggplot2", "patchwork", "scales",
  # reporting
  "knitr", "rmarkdown", "quarto", "flextable",
  # synthetic data
  "simstudy", "wakefield",
  # CDISC tooling
  "metacore", "metatools", "xportr",
  # reproducibility / utilities
  "here", "fs", "cli", "yaml", "openxlsx",
  # deployment
  "rsconnect",
  # testing
  "testthat"
)

to_install <- setdiff(pkgs, rownames(installed.packages()))
if (length(to_install) > 0) {
  message(sprintf("Installing %d packages ...", length(to_install)))
  install.packages(to_install, quiet = TRUE)
}

still_missing <- setdiff(pkgs, rownames(installed.packages()))
if (length(still_missing) > 0) {
  message(sprintf("Retrying %d from source: %s",
                  length(still_missing), paste(still_missing, collapse = ", ")))
  install.packages(still_missing, type = "source", quiet = TRUE)
}

# 4. Verify everything loads -----------------------------------------------
message("\n--- Verifying installs ---")
missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0) {
  stop("Packages failed to install: ", paste(missing, collapse = ", "))
}
message(sprintf("OK: all %d packages load.", length(pkgs)))

# 5. renv init + snapshot --------------------------------------------------
if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv")
if (!file.exists("renv.lock")) {
  message("Initializing renv (bare mode) ...")
  renv::init(bare = TRUE, restart = FALSE)
  message("Hydrating renv library from user library ...")
  renv::hydrate(packages = pkgs, prompt = FALSE)
}
renv::snapshot(prompt = FALSE)

# 6. Smoke test ------------------------------------------------------------
message("\n--- Smoke test: shiny + simstudy + metacore ---")
suppressPackageStartupMessages({
  library(shiny)
  library(simstudy)
  library(metacore)
})
# simstudy quick sanity: generate a tiny dataset
def <- defData(varname = "age", dist = "normal", formula = 50, variance = 100)
dd <- genData(10, def)
stopifnot(nrow(dd) == 10, "age" %in% names(dd))
message(sprintf("OK: simstudy generated %d rows.", nrow(dd)))

message("\nPhase 0 bootstrap complete.")

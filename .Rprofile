# Use Posit Public Package Manager so renv::restore() can find historical
# package versions pinned in renv.lock. "latest" serves binaries appropriate
# to the client OS (macOS local, Linux CI).
options(repos = c(CRAN = "https://packagemanager.posit.co/cran/latest"))

# Only source renv/activate.R if it exists — the bootstrap script
# (R/install_packages.R) runs before renv is initialized.
if (file.exists("renv/activate.R")) {
  source("renv/activate.R")
}

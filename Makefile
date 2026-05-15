# Reproducibility contract for mock-edc-rbm-dashboard.
#
# Override the Python interpreter via PYTHON=... for venv users:
#   PYTHON=.venv/bin/python make synth
#
# Order matters: synth -> checks -> sdtm -> kris -> docs. `make all` runs
# the full pipeline; `make clean && make all` reproduces every artifact.

PYTHON ?= python
PIP    ?= pip

.PHONY: setup metadata synth checks sdtm kris app deploy test docs all clean

setup:
	$(PIP) install -r requirements.txt
	Rscript -e "renv::restore()"

metadata:
	Rscript metadata/_generate_forms_spec.R
	Rscript metadata/_generate_fields_spec.R
	Rscript metadata/_generate_edit_checks.R
	Rscript metadata/_generate_mapping_spec.R

synth:
	$(PYTHON) python/synth_generator.py

checks:
	$(PYTHON) -m python.edit_checks.runner

sdtm:
	Rscript R/01_cdash_to_sdtm.R

kris:
	Rscript R/02_compute_kris.R

app:
	Rscript -e "shiny::runApp('shiny')"

deploy:
	Rscript -e "rsconnect::deployApp('shiny', appName='mock-edc-rbm-dashboard')"

test:
	$(PYTHON) -m pytest tests/
	Rscript -e "testthat::test_dir('tests', stop_on_failure = TRUE)"

docs:
	quarto render crf/annotated_crf.qmd
	quarto render docs/dmp.qmd

# Build everything in dependency order.
all: metadata synth checks sdtm kris docs test

clean:
	rm -f synthetic/raw/*.csv \
	      data/queries/*.csv data/queries/*.json \
	      data/sdtm/*.rds data/sdtm/*.xpt \
	      data/kris.rds data/kris_timeseries.rds \
	      crf/annotated_crf.pdf docs/dmp.pdf

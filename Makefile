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
	# Stage data + synthetic into shiny/ so the deployed bundle is self-contained.
	mkdir -p shiny/data/sdtm shiny/data/queries shiny/synthetic/raw
	cp data/kris.rds data/kris_timeseries.rds shiny/data/
	cp data/sdtm/*.rds shiny/data/sdtm/
	cp data/queries/query_log.csv shiny/data/queries/
	cp synthetic/raw/*.csv shiny/synthetic/raw/
	Rscript -e "rsconnect::deployApp('shiny', appName='mock-edc-rbm-dashboard', forceUpdate=TRUE)"
	# Cleanup staged copies
	rm -rf shiny/data shiny/synthetic

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

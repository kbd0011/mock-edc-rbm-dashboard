.PHONY: setup metadata synth checks sdtm kris app deploy test docs all clean

setup:
	pip install -r requirements.txt
	Rscript -e "renv::restore()"

metadata:
	Rscript metadata/_generate_forms_spec.R
	Rscript metadata/_generate_fields_spec.R
	Rscript metadata/_generate_edit_checks.R
	Rscript metadata/_generate_mapping_spec.R

synth:
	python python/synth_generator.py

checks:
	python -m python.edit_checks.runner

sdtm:
	Rscript R/01_cdash_to_sdtm.R

kris:
	Rscript R/02_compute_kris.R

app:
	Rscript -e "shiny::runApp('shiny')"

deploy:
	Rscript -e "rsconnect::deployApp('shiny', appName='mock-edc-rbm-dashboard')"

test:
	pytest tests/
	Rscript -e "testthat::test_dir('tests')"

docs:
	quarto render crf/annotated_crf.qmd
	quarto render docs/dmp.qmd

all: setup metadata synth checks sdtm kris docs test

clean:
	rm -rf synthetic/raw/*.csv data/queries/*.csv data/queries/*.json data/sdtm/*.rds data/sdtm/*.xpt

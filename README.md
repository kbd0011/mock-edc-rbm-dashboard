# mock-edc-rbm-dashboard

Mock end-to-end EDC + Risk-Based Monitoring dashboard for a fictional Phase III plaque psoriasis trial (IMM-PSO-3001).

> Work in progress. Full README with live demo link, screenshots, and resume bullet will land once the pipeline is complete.

## Stack

- **Python** — synthetic data generation, edit-check engine (pandas, faker, click, pyyaml)
- **R** — CDASH→SDTM mapping, KRI computation, Shiny dashboard (dplyr, metacore, xportr, shiny, bslib, plotly, DT)
- **Quarto** — annotated CRF + Data Management Plan

## Standards

- CDISC CDASHIG 2.2 (eCRF design)
- CDISC SDTMIG 3.3 (downstream mapping)
- ICH E6(R3) Annex E + TransCelerate framework (RBQM KRIs)
- SCDM GCDMP (Data Management Plan)

## Run locally

```
make all
```

See `Makefile` for individual targets.

## License

MIT. See `LICENSE`.

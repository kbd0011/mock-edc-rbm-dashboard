server_kri_detail <- function(input, output, session, state, KRI_META) {

  # Populate site dropdown from data
  observe({
    sites <- sort(unique(state$kris$site))
    updateSelectInput(session, "kd_site", choices = sites,
                      selected = sites[1])
  })

  cur_meta <- reactive({
    req(input$kd_kri)
    KRI_META[KRI_META$kri_name == input$kd_kri, ]
  })

  # Snapshot bar chart across sites
  output$kd_bar <- renderPlotly({
    req(input$kd_kri)
    m <- cur_meta()
    d <- state$kris %>%
      filter(kri_name == input$kd_kri) %>%
      mutate(color = case_when(threshold_flag == "HIGH" ~ "#c0392b",
                               threshold_flag == "LOW"  ~ "#1e8449",
                               TRUE                     ~ "#7f8c8d"))
    plot_ly(d,
            x = ~site, y = ~value, type = "bar",
            marker = list(color = ~color),
            text = ~sprintf(m$format, value), textposition = "outside",
            hoverinfo = "text",
            hovertext = ~sprintf("%s<br>%s: %s<br>flag: %s",
                                 site, m$label,
                                 sprintf(m$format, value), threshold_flag)) %>%
      layout(yaxis = list(title = m$unit),
             xaxis = list(title = ""),
             margin = list(t = 20, b = 50)) %>%
      config(displayModeBar = FALSE)
  })

  # Time series for chosen site
  output$kd_ts <- renderPlotly({
    req(input$kd_kri, input$kd_site)
    m <- cur_meta()
    d <- state$kris_ts %>%
      filter(kri_name == input$kd_kri, site == input$kd_site)
    if (!nrow(d)) {
      return(plotly_empty(type = "scatter", mode = "lines") %>%
               layout(title = "No time-series data for this KRI/site"))
    }
    plot_ly(d, x = ~week_start, y = ~value,
            type = "scatter", mode = "lines+markers",
            line = list(color = "#0b3d91", width = 2),
            marker = list(color = "#0b3d91", size = 6)) %>%
      layout(yaxis = list(title = m$unit),
             xaxis = list(title = ""),
             margin = list(t = 20, b = 50)) %>%
      config(displayModeBar = FALSE)
  })

  # Subject-level drill: depends on KRI
  output$kd_subjects <- renderDT({
    req(input$kd_kri, input$kd_site)
    kn <- input$kd_kri
    site <- input$kd_site

    tbl <- switch(kn,
      enrollment_rate = state$dm %>%
        filter(SITEID == site) %>%
        select(SUBJID, SITEID, ARM, AGE, SEX, RFSTDTC),
      query_rate = state$queries %>%
        filter(site == !!site) %>%
        select(subjid, form, field, check_id, severity, message),
      ae_latency_days = {
        ae_raw <- readr::read_csv(file.path(ROOT, "synthetic", "raw", "ae.csv"),
                                  show_col_types = FALSE)
        ae_raw %>%
          filter(SITEID == site) %>%
          mutate(lag_days = as.numeric(as.Date(AE_ENTRY_DTC) - as.Date(AESTDAT))) %>%
          select(SUBJID, AETERM, AESEV, AESTDAT, AE_ENTRY_DTC, lag_days) %>%
          arrange(desc(lag_days))
      },
      protocol_deviation_rate = {
        pdev <- readr::read_csv(file.path(ROOT, "synthetic", "raw", "protocol_deviations.csv"),
                                show_col_types = FALSE)
        pdev %>% filter(SITEID == site)
      },
      missing_data_pct = state$queries %>%
        filter(site == !!site,
               check_id %in% c("EC001","EC002","EC003","EC004","EC005","EC006","EC031")) %>%
        select(subjid, form, field, message),
      lab_oor_pct = state$lb %>%
        filter(SITEID == site) %>%
        mutate(num = suppressWarnings(as.numeric(LBORRES)),
               lo  = suppressWarnings(as.numeric(LBSTNRLO)),
               hi  = suppressWarnings(as.numeric(LBSTNRHI)),
               oor = !is.na(num) & !is.na(lo) & !is.na(hi) & (num < lo | num > hi)) %>%
        filter(oor) %>%
        select(USUBJID, LBTESTCD, LBTEST, LBORRES, LBORRESU, LBSTNRLO, LBSTNRHI, LBDTC),
      tibble::tibble(message = "No drill-down configured for this KRI.")
    )
    datatable(tbl, rownames = FALSE, options = list(pageLength = 10, scrollX = TRUE))
  })
}

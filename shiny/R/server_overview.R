server_overview <- function(input, output, session, state, KRI_META) {

  output$ov_snapshot_text <- renderUI({
    snap <- unique(state$kris$date)[1]
    div(strong("Snapshot:"), tags$br(), format(snap, "%Y-%m-%d"))
  })

  # Counts of HIGH sites per KRI.
  flag_n <- function(kn, flag = "HIGH") {
    sum(state$kris$kri_name == kn & state$kris$threshold_flag == flag, na.rm = TRUE)
  }
  output$ov_box_enroll <- renderText({
    high <- flag_n("enrollment_rate", "HIGH")
    low  <- flag_n("enrollment_rate", "LOW")
    sprintf("%d / %d", high, low)
  })
  output$ov_box_query  <- renderText(sprintf("%d", flag_n("query_rate")))
  output$ov_box_ae     <- renderText(sprintf("%d", flag_n("ae_latency_days")))
  output$ov_box_pdev   <- renderText(sprintf("%d", flag_n("protocol_deviation_rate")))
  output$ov_box_miss   <- renderText(sprintf("%d", flag_n("missing_data_pct")))
  output$ov_box_lb     <- renderText("—")  # info-only

  # Heatmap data: site x kri with threshold_flag color.
  output$ov_heatmap <- renderPlotly({
    z_color <- c("LOW" = 1, "NORMAL" = 2, "HIGH" = 3)
    info_only <- "lab_oor_pct"

    df <- state$kris %>%
      left_join(KRI_META, by = "kri_name") %>%
      mutate(
        color_val = ifelse(kri_name == info_only, 2L, z_color[threshold_flag]),
        color_val = ifelse(is.na(color_val), 2L, color_val),
        label_txt = sprintf(paste0("%s: ", format), label, value)
      ) %>%
      arrange(site, kri_name)

    sites  <- sort(unique(df$site))
    kris_o <- KRI_META$kri_name      # canonical order
    labels <- KRI_META$label

    mat   <- matrix(NA_integer_, nrow = length(kris_o), ncol = length(sites),
                    dimnames = list(labels, sites))
    htext <- matrix("", nrow = length(kris_o), ncol = length(sites),
                    dimnames = list(labels, sites))
    for (i in seq_len(nrow(df))) {
      rname <- df$label[i]
      cname <- df$site[i]
      mat[rname, cname] <- df$color_val[i]
      htext[rname, cname] <- sprintf("Site: %s<br>%s: %s",
                                     cname, rname,
                                     sprintf(df$format[i], df$value[i]))
    }

    plot_ly(
      x = sites, y = labels, z = mat,
      type = "heatmap",
      text = htext, hoverinfo = "text",
      colorscale = list(c(0, "#1e8449"),    # LOW = green
                        c(0.5, "#f1c40f"),  # NORMAL = yellow
                        c(1, "#c0392b")),   # HIGH  = red
      zmin = 1, zmax = 3, showscale = FALSE,
      xgap = 2, ygap = 2,
      source = "overview_heatmap"
    ) %>%
      layout(
        margin = list(l = 200, t = 30, b = 50, r = 20),
        xaxis = list(title = "", side = "top"),
        yaxis = list(title = "", autorange = "reversed"),
        plot_bgcolor = "#fafafa", paper_bgcolor = "#fafafa"
      ) %>%
      config(displayModeBar = FALSE)
  })

  # When user clicks a tile, jump to KRI Detail tab.
  observeEvent(event_data("plotly_click", source = "overview_heatmap"), {
    ev <- event_data("plotly_click", source = "overview_heatmap")
    if (is.null(ev)) return()
    clicked_kri <- ev$y
    kri_row <- KRI_META[KRI_META$label == clicked_kri, "kri_name", drop = TRUE]
    if (length(kri_row)) {
      updateNavbarPage <- NULL  # ignore — page_navbar uses nav_select
      nav_select("navbar", "KRI Detail")
      updateSelectInput(session, "kd_kri", selected = kri_row)
      updateSelectInput(session, "kd_site", selected = ev$x)
    }
  })
}

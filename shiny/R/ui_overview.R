ui_overview <- function() {
  layout_sidebar(
    sidebar = sidebar(
      title = "Filters",
      open = TRUE,
      width = 240,
      helpText("Snapshot view. Each tile is one site × one KRI."),
      uiOutput("ov_snapshot_text"),
      hr(),
      helpText("Click a tile to drill into KRI Detail.")
    ),
    layout_columns(
      col_widths = c(2, 2, 2, 2, 2, 2),
      value_box(
        title = "Enrollment HIGH/LOW",
        value = textOutput("ov_box_enroll"),
        showcase = bsicons::bs_icon("people"),
        theme = "secondary"
      ),
      value_box(
        title = "Query rate HIGH",
        value = textOutput("ov_box_query"),
        showcase = bsicons::bs_icon("chat-square-text"),
        theme = "danger"
      ),
      value_box(
        title = "AE latency HIGH",
        value = textOutput("ov_box_ae"),
        showcase = bsicons::bs_icon("clock-history"),
        theme = "warning"
      ),
      value_box(
        title = "Protocol dev HIGH",
        value = textOutput("ov_box_pdev"),
        showcase = bsicons::bs_icon("exclamation-triangle"),
        theme = "warning"
      ),
      value_box(
        title = "Missing data HIGH",
        value = textOutput("ov_box_miss"),
        showcase = bsicons::bs_icon("file-earmark-x"),
        theme = "danger"
      ),
      value_box(
        title = "Lab OOR (info)",
        value = textOutput("ov_box_lb"),
        showcase = bsicons::bs_icon("droplet"),
        theme = "primary"
      )
    ),
    card(
      card_header("Site × KRI heatmap"),
      plotlyOutput("ov_heatmap", height = "420px")
    )
  )
}

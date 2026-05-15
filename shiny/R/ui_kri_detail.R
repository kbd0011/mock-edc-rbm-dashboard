ui_kri_detail <- function(KRI_META) {
  kri_choices <- setNames(KRI_META$kri_name, KRI_META$label)
  layout_sidebar(
    sidebar = sidebar(
      title = "KRI selection",
      width = 260,
      selectInput("kd_kri",  "KRI",  choices = kri_choices),
      selectInput("kd_site", "Site (for drill-down)",
                  choices = NULL, multiple = FALSE),
      helpText("Bar chart compares all sites; time series follows the chosen site.")
    ),
    layout_columns(
      col_widths = c(7, 5),
      card(
        card_header("Sites — current snapshot"),
        plotlyOutput("kd_bar", height = "320px")
      ),
      card(
        card_header("Time series (weekly)"),
        plotlyOutput("kd_ts", height = "320px")
      )
    ),
    card(
      card_header("Subject-level drill-down"),
      DTOutput("kd_subjects")
    )
  )
}

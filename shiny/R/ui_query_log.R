ui_query_log <- function() {
  layout_sidebar(
    sidebar = sidebar(
      title = "Filters",
      width = 240,
      selectInput("ql_site",     "Site",     choices = NULL, multiple = TRUE),
      selectInput("ql_form",     "Form",     choices = NULL, multiple = TRUE),
      selectInput("ql_severity", "Severity", choices = NULL, multiple = TRUE),
      selectInput("ql_status",   "Status",   choices = c("Open", "Closed"),
                  selected = "Open", multiple = TRUE),
      hr(),
      downloadButton("ql_download", "Download filtered (CSV)")
    ),
    layout_columns(
      col_widths = c(3, 3, 3, 3),
      value_box(title = "Total queries", value = textOutput("ql_total"),
                showcase = bsicons::bs_icon("clipboard-data"),
                theme = "secondary"),
      value_box(title = "Open queries", value = textOutput("ql_open"),
                showcase = bsicons::bs_icon("envelope-exclamation"),
                theme = "danger"),
      value_box(title = "Errors", value = textOutput("ql_errors"),
                showcase = bsicons::bs_icon("x-octagon"),
                theme = "danger"),
      value_box(title = "Warnings + Notices", value = textOutput("ql_warn"),
                showcase = bsicons::bs_icon("info-circle"),
                theme = "warning")
    ),
    card(
      card_header("Query log"),
      DTOutput("ql_table")
    )
  )
}

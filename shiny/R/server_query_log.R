server_query_log <- function(input, output, session, state) {

  observe({
    updateSelectInput(session, "ql_site",
                      choices = sort(unique(state$queries$site)))
    updateSelectInput(session, "ql_form",
                      choices = sort(unique(state$queries$form)))
    updateSelectInput(session, "ql_severity",
                      choices = sort(unique(state$queries$severity)))
  })

  filtered <- reactive({
    df <- state$queries
    if (length(input$ql_site))     df <- df %>% filter(site %in% input$ql_site)
    if (length(input$ql_form))     df <- df %>% filter(form %in% input$ql_form)
    if (length(input$ql_severity)) df <- df %>% filter(severity %in% input$ql_severity)
    if (length(input$ql_status))   df <- df %>% filter(status %in% input$ql_status)
    df
  })

  output$ql_total  <- renderText(format(nrow(state$queries), big.mark = ","))
  output$ql_open   <- renderText(format(sum(state$queries$status == "Open"), big.mark = ","))
  output$ql_errors <- renderText(format(sum(state$queries$severity == "Error"), big.mark = ","))
  output$ql_warn   <- renderText({
    n <- sum(state$queries$severity %in% c("Warning", "Notice"))
    format(n, big.mark = ",")
  })

  output$ql_table <- renderDT({
    datatable(
      filtered() %>%
        select(timestamp, site, subjid, form, field, check_id, severity, message, status),
      rownames = FALSE,
      filter = "top",
      options = list(pageLength = 25, scrollX = TRUE, order = list(list(0, "desc")))
    )
  })

  output$ql_download <- downloadHandler(
    filename = function() sprintf("query_log_%s.csv", format(Sys.Date(), "%Y%m%d")),
    content  = function(file) readr::write_csv(filtered(), file)
  )
}

# -----------------------------
# Used libraries
# -----------------------------
library(shiny)
library(dplyr)
library(shinydashboard)
library(plotly)
library(DT)

# -----------------------------
# Distributions
# -----------------------------
cust_per_day_counts <- c(8, 10, 12, 14)
cust_per_day_probs  <- c(0.35, 0.30, 0.25, 0.10)

dozen_order_per_cust <- c(1, 2, 3, 4)
dozen_order_per_cust_probs <- c(0.40, 0.30, 0.20, 0.10)

# -----------------------------
# Helper sampling
# -----------------------------
sample_customers <- function() {
  sample(cust_per_day_counts, size = 1, prob = cust_per_day_probs)
}

sample_orders <- function(n) {
  # dozen count per customer
  sample(dozen_order_per_cust, size = n, replace = TRUE, prob = dozen_order_per_cust_probs)
}

# -----------------------------
# Simulate one day for a given production level (in dozens)
# -----------------------------
simulate_day <- function(dozen_count,
                         price   = 80000,
                         cost    = 55000,
                         salvage = 40000) {
  n_cust  <- sample_customers()
  demand  <- sum(sample_orders(n_cust))  # Total demand in dozens
  sold    <- min(demand, dozen_count)
  leftover <- max(dozen_count - demand, 0)
  revenue  <- price * sold + salvage * leftover
  profit   <- revenue - cost * dozen_count
  
  data.frame(
    n_customers = n_cust,
    demand_dozens = demand,
    produced_dozens = dozen_count,
    sold_dozens = sold,
    leftover_dozens = leftover,
    revenue = revenue,
    cost = cost * dozen_count,
    profit = profit
  )
}

# -----------------------------
# Simulate N days (default 5)
# -----------------------------
simulate_days <- function(dozen_count, days = 5,
                          price   = 80000,
                          cost    = 55000,
                          salvage = 40000) {
  do.call(rbind, lapply(1:days, function(d) {
    out <- simulate_day(dozen_count, price, cost, salvage)
    out$day <- d
    out
  }))
}

# -----------------------------
# Monte Carlo to evaluate production levels
# -----------------------------
evaluate_dozens <- function(dozen_count,
                            days = 5,
                            trials = 200,
                            price = 80000,
                            cost = 55000,
                            salvage = 40000) {
  # Kembalikan metrik rata-rata (profit, komponen pendapatan/biaya, dan leftover harian)
  profits <- numeric(trials)
  left_avg <- numeric(trials)
  total_revenue_totals <- numeric(trials)
  regular_revenue_totals <- numeric(trials)
  salvage_revenue_totals <- numeric(trials)
  total_cost_totals <- numeric(trials)
  
  for (r in 1:trials) {
    df <- simulate_days(dozen_count, days, price, cost, salvage)
    profits[r] <- sum(df$profit)
    total_revenue_totals[r] <- sum(df$revenue)
    regular_revenue_totals[r] <- price * sum(df$sold_dozens)
    salvage_revenue_totals[r] <- salvage * sum(df$leftover_dozens)
    total_cost_totals[r] <- sum(df$cost)
    left_avg[r] <- mean(df$leftover_dozens)
  }
  data.frame(
    dozen_count = dozen_count,
    mean_profit = mean(profits),
    sd_profit   = sd(profits),
    mean_total_revenue = mean(total_revenue_totals),
    mean_regular_revenue = mean(regular_revenue_totals),
    mean_salvage_revenue = mean(salvage_revenue_totals),
    mean_total_cost = mean(total_cost_totals),
    mean_avg_leftover = mean(left_avg)
  )
}

# -----------------------------
# UI
# -----------------------------
ui <- dashboardPage(
  skin = "black",
  dashboardHeader(title = tags$span(style = "font-size: 16px;", "Donut 🍩 Stock Simulation")),
  dashboardSidebar(
    sidebarMenu(
      id = "sidebar_tabs",
      menuItem("Simulation", tabName = "sim", icon = icon("chart-line")),
      menuItem("README", tabName = "readme", icon = icon("book-open"))
    ),
    conditionalPanel(
      condition = "input.sidebar_tabs === 'sim'",
      br(),
      sliderInput("max_dozens", "Max stock to test (in dozens)", min = 5, max = 200, value = 100, step = 5),
      sliderInput("trials", "Monte Carlo trials per test", min = 50, max = 1000, value = 100, step = 50),
      numericInput("days", "Horizon (days)", value = 5, min = 1, max = 30, step = 1),
      numericInput("price", "Price per dozen (IDR)", value = 80000, min = 0, step = 5000),
      numericInput("cost", "Production cost per dozen (IDR)", value = 55000, min = 0, step = 5000),
      numericInput("salvage", "Salvage price per dozen (IDR)", value = 40000, min = 0, step = 5000),
      tags$div(
        class = "btn-group",
        actionButton("reset_params", NULL, icon = icon("undo"), class = "btn-secondary", title = "Reset to defaults"),
        actionButton("run", "Run Simulation", icon = icon("play"), class = "btn-primary")
      )
    )
  ),
  dashboardBody(
    tabItems(
      tabItem(
        tabName = "sim",
        fluidRow(
          valueBoxOutput("vb_bestProduction", width = 4),
          valueBoxOutput("vb_bestProfit", width = 4),
          valueBoxOutput("vb_bestLeftover", width = 4)
        ),
        fluidRow(
          box(
            width = 12,
            title = "Profit vs Production",
          status = "primary",
          solidHeader = TRUE,
          plotlyOutput("plot_profit")
          )
        ),
        fluidRow(
        box(
          width = 12,
          title = "Monte Carlo Averages per Stock Alternative",
          status = "primary",
          solidHeader = TRUE,
          collapsible = TRUE,
          p("Each row displays the Monte Carlo averages for a tested stock level (in dozens)."),
          div(
            style = "overflow-x: auto;",
            DTOutput("table_summary")
          )
        )
        )
      ),
      tabItem(
        tabName = "readme",
        fluidRow(
          box(
            title = "Project README",
            width = 12,
            status = "primary",
            solidHeader = TRUE,
            collapsible = TRUE,
            div(
              style = "padding: 0 24px;",
              includeMarkdown("README.md")
            )
          )
        )
      )
    )
  )
)

# -----------------------------
# Server
# -----------------------------
server <- function(input, output, session) {
  active_days <- reactiveVal(NULL)
  observeEvent(input$reset_params, {
    updateSliderInput(session, "max_dozens", value = 100)
    updateSliderInput(session, "trials", value = 100)
    updateNumericInput(session, "days", value = 5)
    updateNumericInput(session, "price", value = 80000)
    updateNumericInput(session, "cost", value = 55000)
    updateNumericInput(session, "salvage", value = 40000)
  })
  
  results <- eventReactive(input$run, {
    # grid of stock levels (dozens) in multiples of 5 to test
    dozens_grid <- seq(5, input$max_dozens, by = 5)
    active_days(input$days)
    out <- do.call(rbind, lapply(dozens_grid, function(dozens) {
      evaluate_dozens(dozens,
                      days = input$days,
                      trials = input$trials,
                      price = input$price,
                      cost = input$cost,
                      salvage = input$salvage)
    }))
    out
  }, ignoreInit = TRUE)
  
  best_row <- reactive({
    req(results())
    # choose the production level with the highest mean profit; tie-breaker uses the smallest dozen count
    res <- results()
    res[order(-res$mean_profit, res$dozen_count), ][1, , drop = FALSE]
  })
  
  output$vb_bestProduction <- renderValueBox({
    req(best_row())
    valueBox(
      value = paste0(best_row()$dozen_count, " dozens"),
      subtitle = "Recommended stock",
      icon = icon("thumbs-up"),
      color = "teal"
    )
  })
  
  output$vb_bestProfit <- renderValueBox({
    req(best_row())
    days_label <- active_days()
    req(!is.null(days_label))
    valueBox(
      value = paste0("IDR ", format(round(best_row()$mean_profit, 0), big.mark = ",", decimal.mark = ".", trim = TRUE)),
      subtitle = paste0("Mean ", days_label, "-day Profit"),
      icon = icon("money-bill-wave"),
      color = "olive"
    )
  })

  output$vb_bestLeftover <- renderValueBox({
    req(best_row())
    days_label <- active_days()
    req(!is.null(days_label))
    valueBox(
      value = paste0(round(best_row()$mean_avg_leftover, 0), " dozens"),
      subtitle = paste0("Mean ", days_label, "-day leftover"),
      icon = icon("boxes-stacked"),
      color = "purple"
    )
  })
  
  output$plot_profit <- renderPlotly({
    req(results(), best_row())
    res <- results()
    days_label <- active_days()
    req(!is.null(days_label))
    hover_text <- sprintf(
      "Stock: %d dozens<br>Mean %d-day profit: IDR %s<br>Avg leftover per day: %s dozens",
      res$dozen_count,
      days_label,
      format(round(res$mean_profit, 0), big.mark = ",", decimal.mark = ".", trim = TRUE),
      format(round(res$mean_avg_leftover, 0), nsmall = 0, big.mark = ",")
    )
    best_stock <- best_row()$dozen_count
    highlight_data <- res[res$dozen_count == best_stock, , drop = FALSE]
    highlight_text <- hover_text[res$dozen_count == best_stock]
    if (length(highlight_text) == 0) {
      highlight_text <- sprintf(
        "Stock: %d dozens<br>Mean %d-day profit: IDR %s<br>Avg leftover per day: %s dozens",
        best_stock,
        days_label,
        format(round(best_row()$mean_profit, 0), big.mark = ",", decimal.mark = ".", trim = TRUE),
        format(round(best_row()$mean_avg_leftover, 0), nsmall = 0, big.mark = ",")
      )
    }
    
    plot <- plot_ly(
      res,
      x = ~dozen_count,
      y = ~mean_profit,
      type = "scatter",
      mode = "lines+markers",
      text = hover_text,
      hoverinfo = "text",
      line = list(color = "#2C7BB6"),
      marker = list(color = "#2C7BB6", size = 6),
      name = "Stock alternatives"
    )
    
    if (nrow(highlight_data) > 0) {
      plot <- plot %>%
        add_trace(
          data = highlight_data,
          x = ~dozen_count,
          y = ~mean_profit,
          type = "scatter",
          mode = "markers",
          text = highlight_text,
          hoverinfo = "text",
          marker = list(color = "#1B9E77", size = 10, symbol = "circle", line = list(color = "white", width = 1.5)),
          showlegend = FALSE
        )
    }
    
    plot %>%
      layout(
        title = "Profit vs Production (Monte Carlo Average)",
        xaxis = list(
          title = "Stock (dozens)",
          dtick = 5,
          tick0 = min(res$dozen_count)
        ),
        yaxis = list(
          title = paste0("Mean ", days_label, "-day Profit (IDR)")
        ),
        hovermode = "closest",
        hoverlabel = list(bgcolor = "white"),
        margin = list(l = 70, r = 30, b = 60, t = 60),
        shapes = list(list(
          type = "line",
          x0 = best_stock,
          x1 = best_stock,
          y0 = min(res$mean_profit),
          y1 = max(res$mean_profit),
          xref = "x",
          yref = "y",
          line = list(color = "#1B9E77", dash = "dash")
        ))
      )
  })
  
  output$table_summary <- renderDT({
    req(results())
    df <- results()
   df_display <- df
   days_label <- active_days()
   req(!is.null(days_label))
    best_stock_value <- best_row()$dozen_count
    df_display$stock_candidate <- df_display$dozen_count
    df_display$mean_profit <- round(df_display$mean_profit, 0)
    df_display$sd_profit   <- round(df_display$sd_profit, 0)
    df_display$mean_total_revenue <- round(df_display$mean_total_revenue, 0)
    df_display$mean_regular_revenue <- round(df_display$mean_regular_revenue, 0)
    df_display$mean_salvage_revenue <- round(df_display$mean_salvage_revenue, 0)
    df_display$mean_total_cost <- round(df_display$mean_total_cost, 0)
    df_display$mean_avg_leftover <- round(df_display$mean_avg_leftover, 0)
    df_display <- df_display[, c(
      "stock_candidate",
      "mean_profit",
      "sd_profit",
      "mean_total_revenue",
      "mean_regular_revenue",
      "mean_salvage_revenue",
      "mean_total_cost",
      "mean_avg_leftover"
    )]
    colnames(df_display) <- c(
      "stock_candidate",
      sprintf("mean_%s_day_profit", days_label),
      sprintf("sd_%s_day_profit", days_label),
      sprintf("mean_%s_day_total_revenue", days_label),
      sprintf("mean_%s_day_regular_revenue", days_label),
      sprintf("mean_%s_day_salvage_revenue", days_label),
      sprintf("mean_%s_day_total_cost", days_label),
      sprintf("mean_%s_day_avg_leftover", days_label)
    )
    currency_cols <- colnames(df_display)[c(2,4,5,6,7)]
    leftover_col <- tail(colnames(df_display), 1)
    datatable(
      df_display,
      rownames = FALSE,
      options = list(
        dom = "ftp",
        paging = TRUE,
        pageLength = 10,
        searching = FALSE,
        order = list(list(0, "asc")),
        scrollX = TRUE
      )
    ) %>%
      formatCurrency(currency_cols, currency = "", digits = 0, interval = 3, mark = ",") %>%
      formatRound(leftover_col, digits = 0) %>%
      formatStyle(
        columns = "stock_candidate",
        target = "row",
        backgroundColor = styleEqual(
          levels = c(best_stock_value),
          values = c("#e0f3db")
        )
      )
  })
}

shinyApp(ui = ui, server = server)

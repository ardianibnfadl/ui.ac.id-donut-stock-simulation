# -----------------------------
# Used libraries
# -----------------------------
library(shiny)
library(shinydashboard)

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
  # dozen of donuts count per customer
  sample(dozen_order_per_cust, size = n, replace = TRUE, prob = dozen_order_per_cust_probs)
}

# -----------------------------
# Simulate one day for a given Q
# -----------------------------
simulate_day <- function(Q,
                         price   = 80000,
                         cost    = 55000,
                         salvage = 40000) {
  n_cust  <- sample_customers()
  demand  <- sum(sample_orders(n_cust))  # Total demand in dozen
  sold    <- min(demand, Q)
  leftover <- max(Q - demand, 0)
  revenue  <- price * sold + salvage * leftover
  profit   <- revenue - cost * Q
  
  data.frame(
    n_customers = n_cust,
    demand_dozens = demand,
    produced_Q = Q,
    sold_dozens = sold,
    leftover_dozens = leftover,
    revenue = revenue,
    cost = cost * Q,
    profit = profit
  )
}

# -----------------------------
# Simulate N days (default 5)
# -----------------------------
simulate_days <- function(Q, days = 5,
                          price   = 80000,
                          cost    = 55000,
                          salvage = 40000) {
  do.call(rbind, lapply(1:days, function(d) {
    out <- simulate_day(Q, price, cost, salvage)
    out$day <- d
    out
  }))
}

# -----------------------------
# Monte Carlo to evaluate Q
# -----------------------------
evaluate_Q <- function(Q,
                       days = 5,
                       replications = 200,
                       price = 80000,
                       cost = 55000,
                       salvage = 40000) {
  # Return mean total profit across 5 days, service level, expected leftover per day
  profits <- numeric(replications)
  svc_hit <- numeric(replications)  # proportion of days where D <= Q
  left_avg <- numeric(replications)
  
  for (r in 1:replications) {
    df <- simulate_days(Q, days, price, cost, salvage)
    profits[r] <- sum(df$profit)
    # daily service level (D <= Q)
    svc_hit[r] <- mean(df$demand_dozens <= Q)
    left_avg[r] <- mean(df$leftover_dozens)
  }
  data.frame(
    Q = Q,
    mean_profit_5d = mean(profits),
    sd_profit_5d   = sd(profits),
    service_level  = mean(svc_hit),
    avg_leftover_per_day = mean(left_avg)
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
      sliderInput("Qmax", "Max Q (dozens)", min = 20, max = 200, value = 120, step = 5),
      sliderInput("rep", "Monte Carlo replications", min = 50, max = 1000, value = 300, step = 50),
      numericInput("days", "Horizon (days)", value = 5, min = 1, max = 30, step = 1),
      numericInput("price", "Price per dozen (IDR)", value = 80000, min = 0, step = 5000),
      numericInput("cost", "Production cost per dozen (IDR)", value = 55000, min = 0, step = 5000),
      numericInput("salvage", "Salvage price per dozen (IDR)", value = 40000, min = 0, step = 5000),
      numericInput("seed", "Seed (optional)", value = 123, min = 0, step = 1),
      actionButton("run", "Run Simulation", icon = icon("play"))
    )
  ),
  dashboardBody(
    tabItems(
      tabItem(
        tabName = "sim",
        fluidRow(
          valueBoxOutput("vb_bestQ", width = 4),
          valueBoxOutput("vb_bestProfit", width = 4),
          valueBoxOutput("vb_bestSvc", width = 4)
        ),
        tabBox(
          width = 12,
          id = "tabsim",
          tabPanel(
            "Profit vs Q",
            plotOutput("plot_profit"),
            br(),
            tableOutput("table_best_row")
          ),
          tabPanel(
            "Representative Run (5 days)",
            p("This table shows a single representative run for Q* (not the Monte Carlo average)."),
            tableOutput("table_run")
          )
        )
      ),
      tabItem(
        tabName = "readme",
        fluidRow(
          box(
            title = NULL,
            width = 12,
            status = "primary",
            column(includeMarkdown("README.md"), width = 12)
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
  observeEvent(input$run, {
    if (!is.na(input$seed)) set.seed(input$seed)
  })
  
  results <- eventReactive(input$run, {
    if (!is.na(input$seed)) set.seed(input$seed)
    # Q grid in multiples of 5
    Qs <- seq(0, input$Qmax, by = 5)
    out <- do.call(rbind, lapply(Qs, function(Q) {
      evaluate_Q(Q,
                 days = input$days,
                 replications = input$rep,
                 price = input$price,
                 cost = input$cost,
                 salvage = input$salvage)
    }))
    out
  }, ignoreInit = TRUE)
  
  best_row <- reactive({
    req(results())
    # choose the Q with the highest 5-day mean profit; tie-breaker uses the smallest Q
    res <- results()
    res[order(-res$mean_profit_5d, res$Q), ][1, , drop = FALSE]
  })
  
  output$vb_bestQ <- renderValueBox({
    req(best_row())
    valueBox(
      value = paste0(best_row()$Q, " dozens"),
      subtitle = "Q* (multiples of 5) - Recommended",
      icon = icon("thumbs-up"),
      color = "teal"
    )
  })
  
  output$vb_bestProfit <- renderValueBox({
    req(best_row())
    valueBox(
      value = paste0("IDR ", format(round(best_row()$mean_profit_5d, 0), big.mark = ".")),
      subtitle = paste0("Total Mean Profit for ", input$days, " days"),
      icon = icon("money-bill-wave"),
      color = "olive"
    )
  })
  
  output$vb_bestSvc <- renderValueBox({
    req(best_row())
    valueBox(
      value = paste0(round(100 * best_row()$service_level, 1), "%"),
      subtitle = "Service Level (P[D <= Q] per day)",
      icon = icon("check-circle"),
      color = "purple"
    )
  })
  
  output$plot_profit <- renderPlot({
    req(results(), best_row())
    res <- results()
    plot(res$Q, res$mean_profit_5d,
         type = "b", xlab = "Q (dozens, multiples of 5)",
         ylab = paste0("Total Mean Profit for ", input$days, " days"),
         main = "Profit vs Q (Monte Carlo)")
    abline(v = best_row()$Q, lty = 2)
  })
  
  output$table_best_row <- renderTable({
    req(best_row())
    br <- best_row()
    br$mean_profit_5d <- round(br$mean_profit_5d, 0)
    br$sd_profit_5d   <- round(br$sd_profit_5d, 0)
    br$service_level  <- round(br$service_level, 4)
    br$avg_leftover_per_day <- round(br$avg_leftover_per_day, 2)
    br
  })
  
  output$table_run <- renderTable({
    req(best_row())
    if (!is.na(input$seed)) set.seed(input$seed + 999)  # representative run separate from the evaluation
    df <- simulate_days(
      Q       = best_row()$Q,
      days    = input$days,
      price   = input$price,
      cost    = input$cost,
      salvage = input$salvage
    )
    df[, c("day","n_customers","demand_dozens","produced_Q",
           "sold_dozens","leftover_dozens","revenue","cost","profit")]
  })
}

shinyApp(ui, server)

cat("\014") # Clear your console
rm(list = ls()) #clear your environment

########################## Load in header file ######################## #
setwd("~/git/of_dollars_and_data")
source(file.path(paste0(getwd(),"/header.R")))

########################## Load in Libraries ########################## #

library(dplyr)
library(ggplot2)
library(reshape2)
library(scales)
library(lubridate)
library(grid)
library(gridExtra)
library(gtable)
library(RColorBrewer)
library(stringr)
library(ggrepel)

folder_name <- "xxxx_worlds_worst_market_timer"
out_path <- paste0(exportdir, folder_name)
dir.create(file.path(paste0(out_path)), showWarnings = FALSE)

########################## Start Program Here ######################### #

# Read in data for individual stocks and sp500 Shiller data
sp500_ret_pe    <- readRDS(paste0(localdir, "0009_sp500_ret_pe.Rds")) %>%
                    filter(date >= "1972-11-01",
                           date <= "2013-12-31")


# Purchases for the world's market timer
purchases <- data.frame(date = c("1972-12-01", "1987-08-01", "1999-12-01", "2007-10-01"),
                        amount = c(6000, 46000, 68000, 64000)) %>%
  mutate(date = as.Date(date))

# Change the Date to a Date type for plotting the S&P data
df <- select(sp500_ret_pe, date, price_plus_div) %>%
                  left_join(purchases) %>%
                  mutate(amount = ifelse(is.na(amount), 0, amount),
                         ret_sp500 = price_plus_div/lag(price_plus_div, 1) - 1,
                         decade = year(date) - (year(date) %% 10),
                         dca_amount = case_when(
                           decade == 1970 ~ 2000/12,
                           decade == 1980 ~ 4000/12,
                           decade == 1990 ~ 6000/12,
                           decade == 2000 ~ 8000/12,
                           TRUE ~ 0
                         )) %>%
                  filter(!is.na(ret_sp500))
              
for(i in 1:nrow(df)){
  if(i == 1){
    df[i, "value"] <- df[i, "amount"] * (1 + df[i, "ret_sp500"])
    df[i, "value_dca"] <- df[i, "amount"] * (1 + df[i, "ret_sp500"])
  } else { 
    df[i, "value"] <- (df[(i-1), "value"] + df[i, "amount"]) * (1 + df[i, "ret_sp500"])
    df[i, "value_dca"] <- (df[(i-1), "value_dca"] + df[i, "dca_amount"]) * (1 + df[i, "ret_sp500"])
  }
}

# Calculate the money weighted return by determing each individual return and weighting it.  
for (i in 1:nrow(purchases)){
  dt <- purchases[i, "date"]
  at <- purchases[i, "amount"]
  
  temp <- df %>%
            filter(date >= dt) %>%
            mutate(ret = 1 + ret_sp500) %>%
            pull(ret)
  
  print(prod(temp) - 1)
  
  purchases[i, "final_value"]  <- prod(temp) * at
  purchases[i, "total_return"] <- (purchases[i, "final_value"]/at)^(12/length(temp)) - 1

}

# Weight each purchases and then find the total attribution for each and sum
money_wt_ret <- purchases %>%
              mutate(weight = amount/sum(purchases$amount) * total_return) %>%
              pull(weight) %>%
              sum()

time_wt_ret <- purchases[1, "total_return"]

# Set the file_path based on the function input 
file_path <- paste0(out_path, "/portfolio_value_over_time.jpeg")

# Set note and source string
source_string <- str_wrap("Source: Simulated data, http://www.econ.yale.edu/~shiller/data.htm (OfDollarsAndData.com)",
                          width = 85)

total_purchases <- sum(purchases$amount)

note_string <- str_wrap(paste0("Note: Assumes 4 purchases totaling $", formatC(total_purchases, format="f", big.mark=",", digits=0), ".  Real returns include reinvested dividends for the S&P 500."),
                          width = 85)
col_plot <- "green"

plot <- ggplot(df, aes(x=date, y=value)) +
          geom_line() +
          geom_point(data=filter(df, amount > 0 | row_number() == nrow(df)), col = col_plot) +
          geom_text_repel(data = filter(df, amount > 0),
                          aes(x=date, y=value),
                          col = col_plot,
                          label = paste0("+$", formatC(purchases$amount, format="f", big.mark=",", digits=0)),
                          nudge_y = 3000,
                          max.iter= 3000) +
          geom_text_repel(data = df[nrow(df), ],
                          aes(x=date, y=value),
                          col = col_plot,
                          label = paste0("$", formatC(as.numeric(df[nrow(df), "value"]), format="f", big.mark=",", digits=0)),
                          nudge_x = -1500,
                          nudge_y = 3000,
                          max.iter= 3000) +
          scale_y_continuous(label = dollar) +
          of_dollars_and_data_theme +
          ggtitle("Even the World's Worst Market Timer\nCan Be A Successful Investor") +
          labs(x = "Date" , y = "Portfolio Value ($)",
            caption = paste0("\n", source_string, "\n", note_string))

# Save the plot
ggsave(file_path, plot, width = 15, height = 12, units = "cm")

# ############################  End  ################################## #

  

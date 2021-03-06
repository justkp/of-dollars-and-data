cat("\014") # Clear your console
rm(list = ls()) #clear your environment

########################## Load in header file ######################## #
setwd("~/git/of_dollars_and_data")
source(file.path(paste0(getwd(),"/header.R")))

########################## Load in Libraries ########################## #

library(scales)
library(readxl)
library(lubridate)
library(ggrepel)
library(gganimate)
library(tidylog)
library(zoo)
library(tidyverse)

folder_name <- "0162_epidemics_vs_dow"
out_path <- paste0(exportdir, folder_name)
dir.create(file.path(paste0(out_path)), showWarnings = FALSE)

########################## Start Program Here ######################### #

plot_flu_data <- function(flu_name, flu_title, flu_label, ret_data, source_in1, source_in2){

  epi_data <- read.csv(paste0(importdir, "0162_epidemics_vs_dow_data/", flu_name, "_webplotdigi.csv"),
                       col.names = c("date", "epi_count")) %>%
                  mutate(date = as.Date(date, "%Y/%m/%d")) %>%
                  arrange(date) %>%
                  mutate(daily_diff = (lead(epi_count,1) - epi_count)/as.numeric(lead(date,1) - date))
  
  min_date <- min(epi_data$date)
  max_date <- max(epi_data$date)
  
  all_dates <- data.frame(date = seq.Date(min_date, max_date + days(365), 1))
  
  if(ret_data == "Dow"){
  ret_daily <- read_excel(paste0(importdir, "0162_epidemics_vs_dow_data/daily_dow_bloomberg.xlsx"), sheet="Sheet1",
                          col_names = c("date", "index")) %>%
                mutate(date = as.Date(date)) %>%
                filter(date >= min_date, date <= max_date + days(365))
  } else if (ret_data == "EM"){
    ret_daily <- read.csv(paste0(importdir, "0162_epidemics_vs_dow_data/daily_global_ycharts.csv"),
                          col.names = c("date", "em", "sp500")) %>%
                  mutate(date = as.Date(date, format = "%Y-%m-%d")) %>%
                  rename(index = em) %>%
                  select(date, index)
  } else if (ret_data == "S&P 500"){
    ret_daily <- read.csv(paste0(importdir, "0162_epidemics_vs_dow_data/daily_global_ycharts.csv"),
                          col.names = c("date", "em", "sp500")) %>%
      mutate(date = as.Date(date, format = "%Y-%m-%d")) %>%
      rename(index = sp500) %>%
      select(date, index)
  }
  
  df <- all_dates %>%
          left_join(ret_daily) %>%
          left_join(epi_data) %>%
          arrange(date) %>%
          mutate(index = ifelse(is.na(index), lead(index), index))
  
  for(i in 2:nrow(df)){
    if(is.na(df[i, "daily_diff"])){
      df[i, "daily_diff"] <- df[(i-1), "daily_diff"]
    }
    if(is.na(df[i, "index"])){
      df[i, "index"] <- df[(i-1), "index"]
    }
    
    if(df[i, "date"] <= max_date){
      df[i, "epi_count"] <-  df[(i-1), "epi_count"] + df[i, "daily_diff"]
    } else{
      df[i, "epi_count"] <- NA
      df[i, "daily_diff"] <- NA
    }
  }
  
  # Plot deaths per 1,000 over time
  file_path <- paste0(out_path, "/incidents_time_", flu_name, ".jpeg")
  source_string <- str_wrap(paste0("Source:   ", source_in1, " (OfDollarsAndData.com)"),
                            width = 85)
  note_string <-  str_wrap(paste0("Note:  Days with missing data were filled using linear extrapolation.  ",
                                  "Epidemic data starts on ", format.Date(min_date, "%m/%d/%Y"), 
                                  " and ends on ", format.Date(max_date, "%m/%d/%Y"), "."), 
                           width = 85)
  
  epi_peak_date <- df %>%
                    filter(epi_count == max(df$epi_count, na.rm = TRUE)) %>%
                    pull(date)
  
  to_plot <- df %>%
    filter(date <= max_date) %>%
    mutate(pre_post = ifelse(date < epi_peak_date, "Pre-Peak", "Post-Peak"))
  
  plot <- ggplot(to_plot, aes(x=date, y=epi_count, col = pre_post, group = 1)) +
    geom_line() +
    scale_y_continuous(label = comma) +
    scale_x_date(date_labels = "%m/%d/%Y") +
    scale_color_manual(guide = FALSE, values = c("green", "red")) +
    of_dollars_and_data_theme +
    ggtitle(paste0(flu_title)) +
    labs(x=paste0("Date"), y=paste0(flu_label),
         caption = paste0(source_string, "\n", note_string))
  
  # Save the plot
  ggsave(file_path, plot, width = 15, height = 12, units = "cm")
  
  # Plot same thing in black
  file_path <- paste0(out_path, "/incidents_time_", flu_name, "_black.jpeg")
  
  plot <- ggplot(to_plot, aes(x=date, y=epi_count)) +
    geom_line() +
    scale_y_continuous(label = comma) +
    scale_x_date(date_labels = "%m/%d/%Y") +
    of_dollars_and_data_theme +
    ggtitle(paste0(flu_title)) +
    labs(x=paste0("Date"), y=paste0(flu_label),
         caption = paste0(source_string, "\n", note_string))
  
  # Save the plot
  ggsave(file_path, plot, width = 15, height = 12, units = "cm")
  
  # Plot index vs. epidemic peak
  file_path <- paste0(out_path, "/", ret_data, "_", flu_name, "_index_colored.jpeg")
  
  source_string <- str_wrap(paste0("Source:   ", source_in1, ", ", source_in2," (OfDollarsAndData.com)"),
                            width = 85)
  
  if(flu_name == "sars"){
    flu_title <- "SARS"
  } else {
    flu_title <- proper_case(str_replace_all(flu_name, "_", " "))
  }
  
  plot <- ggplot(to_plot, aes(x=date, y=index, col = pre_post, group = 1)) +
    geom_line() +
    scale_color_manual(guide = FALSE, values = c("green", "red")) +
    scale_y_continuous(label = comma) +
    scale_x_date(date_labels = "%m/%d/%Y") +
    of_dollars_and_data_theme +
    ggtitle(paste0(ret_data, " Index During ", flu_title)) +
    labs(x=paste0("Date"), y=paste0("Index Value"),
         caption = paste0(source_string, "\n", note_string))
  
  # Save the plot
  ggsave(file_path, plot, width = 15, height = 12, units = "cm")
  
}

all_epidemics <- c("spanish_flu", "swine_flu", "ebola", "sars")
for(epi in all_epidemics){
  print(epi)
  
  if(epi == "spanish_flu"){
    title <- "Spanish Flu Per-Capita Deaths in UK"
    label <- "Deaths Per 1,000 People"
    source_epi <- "Wikimedia Commons"
  } else if(epi == "swine_flu"){
    title <- "Weekly Reported Swine Flu Cases"
    label <- "Number of Reported Cases"
    source_epi <- "Center for Disease Control and Prevention"
  } else if(epi == "ebola"){
    title <- "Total Ebola Cases in West Africa"
    label <- "Number of Cases"
    source_epi <- "Disaster Health"
  } else if(epi == "sars"){
    title <- "Probable Worldwide SARS Cases"
    label <- "Number of Cases"
    source_epi <- "World Health Organization"
  } 
  
  ret_data_source <- c("Dow", "EM", "S&P 500")
  
  for(rds in ret_data_source){
    if(rds == "Dow" & epi == "spanish_flu"){
      source_ret <- "Bloomberg"
      plot_flu_data(epi, title, label, rds, source_epi, source_ret)
    } else{
      source_ret <- "YCharts"
      if(epi != "spanish_flu"){
        plot_flu_data(epi, title, label, rds, source_epi, source_ret)
      }
    }
  }
}








# ############################  End  ################################## #
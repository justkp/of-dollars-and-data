cat("\014") # Clear your console
rm(list = ls()) #clear your environment

# Import the Orion data to ensure we have the most updated Orion data
setwd("~/git/of_dollars_and_data")
rm(list = ls()) #clear your environment

########################## Load in header file ######################## #
source(file.path(paste0(getwd(),"/header.R")))

########################## Load in Libraries ########################## #

library(lubridate)
library(stringr)
library(tidyverse)

folder_name <- "xxxx_hot_hand_replication"
out_path <- paste0(exportdir, folder_name)
dir.create(file.path(paste0(out_path)), showWarnings = FALSE)

########################## Start Program Here ######################### #

initial_strings <- c("H", "T")

flips_df <- data.frame(streak = c(1, 1),
                flip_string = initial_strings,
                 flip_num = seq(1, length(initial_strings)))

streaks <- seq(2, 10)

for(s in streaks){
  tmp <- flips_df %>%
          filter(streak == (s - 1)) 
  
  tmp <- tmp %>%
            bind_rows(tmp)
  
  for(i in 1:nrow(tmp)){
    
    if(i <= nrow(tmp)/2){
      new_flip <- "H"
    } else{
      new_flip <- "T"
    }
    
    tmp[i, "streak"] <- s
    tmp[i, "flip_string"] <- paste0(tmp[i, "flip_string"], new_flip)
    tmp[i, "flip_num"] <- i
  }
  
  flips_df <- flips_df %>%
          bind_rows(tmp)
}

count_all_occurences <- function(input_string, find_string){
  count <- 0
  for(i in 1:nchar(input_string)-1){
    if(substr(input_string, i, i+1) == find_string){
      count <- count + 1
    }
  }
  return(count)
}

flips_df <- flips_df %>%
      mutate(n_heads_after_first_flip = str_count(substr(flip_string, 2, streak), "H"),
             n_heads_after_heads = sapply(X = flip_string, FUN = count_all_occurences,
                                            find_string = "HH"),
             final_pct = n_heads_after_heads/n_heads_after_first_flip)

flip_results <- flips_df %>%
                  filter(!is.na(final_pct)) %>%
                  group_by(streak) %>%
                  summarize(prob_h = sum(final_pct, na.rm = TRUE)/n())

#Create fake data
set.seed(12345)

rands <- data.frame(rand = runif(10^4, 0, 1))

df <- rands %>%
          mutate(pos = ifelse(rand > 0.5, 1, 0)) %>%
          select(pos)


for (i in 1:nrow(df)){
  print(i)
  pos <- df[i, "pos"]
  
  if(i == 1){
    df[i, "pos_streak"] <- pos
    df[i, "neg_streak"] <- (1 - pos)
  } else {
    prior_pos <- df[(i-1), "pos"]
    prior_pos_streak <- df[(i-1), "pos_streak"]
    prior_neg_streak <- df[(i-1), "neg_streak"]
    
    if(prior_pos == 1 & pos == 1){
      df[i, "pos_streak"] <- prior_pos_streak + 1
      df[i, "neg_streak"] <- 0
    } else if (prior_pos == 1 & pos == 0){
      df[i, "pos_streak"] <- 0
      df[i, "neg_streak"] <- 1
    } else if (prior_pos == 0 & pos == 0){
      df[i, "pos_streak"] <- 0
      df[i, "neg_streak"] <- prior_neg_streak + 1
    } else if (prior_pos == 0 & pos == 1){
      df[i, "pos_streak"] <- 1
      df[i, "neg_streak"] <- 0
    }
  }
}

df <- df %>%
  mutate(pos_next = lead(pos)) %>%
  filter(!is.na(pos_next))

final_results <- data.frame(pos_neg = c(), streak_length = c(),
                            pct_next_day_same = c(),
                            t_pval = c(), n_days = c())

counter <- 1
for (i in 1:max(df$pos_streak, df$neg_streak)){
  tmp_s <- df %>%
    filter(pos_streak >= i)
  
  final_results[counter, "pos_neg"]             <- "Positive"
  final_results[counter, "streak_length"]       <- i
  final_results[counter, "pct_next_day_same"]   <- mean(tmp_s$pos_next)
  
  final_results[counter, "n_days"]              <- nrow(tmp_s)
  
  if (final_results[counter, "n_days"] >= 100){
    final_results[counter, "t_pval"]  <- t.test(df$pos, tmp_s$pos_next)$p.value
  } else {
    final_results[counter, "t_pval"]  <- NA
  }
  counter <- counter + 1
  
  tmp_s <- df %>%
    filter(neg_streak >= i)
  
  final_results[counter, "pos_neg"]             <- "Negative"
  final_results[counter, "streak_length"]       <- i
  final_results[counter, "pct_next_day_same"]   <- 1-mean(tmp_s$pos_next)
  final_results[counter, "n_days"]              <- nrow(tmp_s)
  
  if (final_results[counter, "n_days"] >= 100){
    final_results[counter, "t_pval"]  <- t.test(df$pos, tmp_s$pos_next)$p.value
  } else {
    final_results[counter, "t_pval"]  <- NA
  }
  
  counter <- counter + 1
}
              


# ############################  End  ################################## #
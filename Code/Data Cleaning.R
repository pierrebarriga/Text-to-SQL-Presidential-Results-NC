library(dplyr)
library(tidyverse)
library(stringr)
library(lubridate)

#reading data 
df.2024 <- read_tsv("~/Github/Voter Registration RAG Pipeline/Data/results_pct_20241105.txt")
df.2020 <- read_tsv("~/Github/Voter Registration RAG Pipeline/Data/results_pct_20201103.txt")
df.2016 <- read_tsv("~/Github/Voter Registration RAG Pipeline/Data/results_pct_20161108.txt")

#filtering through contests 
contest.2024 <- distinct(df.2024, `Contest Name`)
contest.2020 <- distinct(df.2020, `Contest Name`)
contest.2016 <- distinct(df.2016, `Contest Name`)

#US President in Contest Name is to find presidential records 
pres.2024 <- df.2024 %>% 
  filter(`Contest Name` == 'US PRESIDENT')

pres.2020 <- df.2020 %>% 
  filter(`Contest Name` == 'US PRESIDENT')

pres.2016 <- df.2016 %>% 
  filter(`Contest Name` == 'US PRESIDENT')


#Validated Figures against the NCSBE Dashboard 
pres.2024 %>% group_by(`Choice`) %>% summarise(total_votes = sum(`Total Votes`))
pres.2020 %>% group_by(`Choice`) %>% summarise(total_votes = sum(`Total Votes`))
pres.2016 %>% group_by(`Choice`) %>% summarise(total_votes = sum(`Total Votes`))

#Cleaning Data for 2016 - Jill Stein 
pres.2016 <- pres.2016 %>%
  mutate(
    Choice = str_squish(Choice), 
    Choice = case_when(
      str_detect(Choice, "JIll Stein") ~ "Jill Stein (Write-In)",
      TRUE ~ Choice
    )
  )

#Standardizing Data For Ingestion into Supabase 

#Extracting Election Year 
pres.cleaned.2024 <- pres.2024 %>%
  mutate(
    `Election Date` = mdy(`Election Date`),
    'Election_Year' = year(`Election Date`)
  )

pres.cleaned.2020 <- pres.2020 %>%
  mutate(
    `Election Date` = mdy(`Election Date`),
    'Election_Year' = year(`Election Date`)
  )


pres.cleaned.2016 <- pres.2016 %>%
  mutate(
    `Election Date` = mdy(`Election Date`),
    'Election_Year' = year(`Election Date`)
  )


# Dropping Columns
pres.cleaned.2024 <- pres.cleaned.2024 %>% 
  select(-'...16', 
         -`Real Precinct`, 
         -`Contest Group ID`, 
         -'Precinct', 
         -`Contest Type`,
         -`Contest Name`,
         -`Vote For`,
         - `Election Date`)

pres.cleaned.2020 <- pres.cleaned.2020 %>% 
  select(-'...16', 
         -`Real Precinct`, 
         -`Contest Group ID`, 
         -'Precinct', 
         -`Contest Type`,
         -`Contest Name`,
         -`Vote For`,
         - `Election Date`)

pres.cleaned.2016 <- pres.cleaned.2016 %>% 
  select(-'...15', 
         -`Contest Group ID`, 
         -'Precinct', 
         -`Contest Type`,
         -`Contest Name`,
         -`Vote For`,
         - `Election Date`)


#Renaming Columns 
pres.cleaned.2024 <- pres.cleaned.2024 %>% 
  rename(
    Candidate = 'Choice',
    Candidate_Party = `Choice Party`,
    Provisional_votes = 'Provisional',
    Absentee_by_mail = `Absentee by Mail`,
    Election_day_votes = `Election Day`,
    Total_votes = `Total Votes`,
    Early_voting = `Early Voting`
  )

pres.cleaned.2020 <- pres.cleaned.2020 %>% 
  rename(
    Candidate = 'Choice',
    Candidate_Party = `Choice Party`,
    Provisional_votes = 'Provisional',
    Absentee_by_mail = `Absentee by Mail`,
    Election_day_votes = `Election Day`,
    Total_votes = `Total Votes`,
    Early_voting = `One Stop`
  )

pres.cleaned.2016 <- pres.cleaned.2016 %>% 
  rename(
    Candidate = 'Choice',
    Candidate_Party = `Choice Party`,
    Provisional_votes = 'Provisional',
    Absentee_by_mail = `Absentee by Mail`,
    Election_day_votes = `Election Day`,
    Total_votes = `Total Votes`,
    Early_voting = `One Stop`
  )

#Combining Data Frames 
pres.cleaned <- bind_rows(pres.cleaned.2016, pres.cleaned.2020, pres.cleaned.2024)

#Validating Rows / Combinations 
pres.cleaned %>% 
  group_by(Election_Year) %>% 
  summarise(count = n())

##Adding on 2008 & 2012 Election Results to Database 

df_2008 <- read_csv('nov_2008_data.txt')
df_2012 <- read_csv('nov_2012_data.txt')

cleaned_data <- function(df, contest_col, year_input, choice_col) {
  df %>% 
    filter({{ contest_col }} == 'PRESIDENT AND VICE PRESIDENT OF THE UNITED STATES') %>% 
    mutate(
      Election_year = year_input,
      Candidate = case_when(
        Election_year == 2008 & {{ choice_col }} == 'Obama/Biden' ~ "Barack Obama",
        Election_year == 2008 & {{ choice_col }} == 'McCain/Palin' ~ "John McCain",
        Election_year == 2008 & {{ choice_col }} == 'WRITE-IN' ~ 'Write-In',
        Election_year == 2008 & {{ choice_col }} == 'Barr/Root' ~ 'Bob Barr',
        Election_year == 2012 & {{ choice_col }} == 'Johnson/Gray' ~ 'Gary Johnson',
        Election_year == 2012 & {{ choice_col }} == 'Obama/Biden' ~ "Barack Obama",
        Election_year == 2012 & {{ choice_col }} == 'Romney/Ryan' ~ "Mitt Romney",
        Election_year == 2012 & {{ choice_col }} == 'Write-in (miscellaneous)' ~ "Write-In",
        Election_year == 2012 & {{ choice_col }} == 'Virgil Goode (Write-in)' ~ "Virgil Goode (Write-In)",
        TRUE ~ NA_character_
      )
    )
  }
  
# Running Functions
cleaned_2008 <- cleaned_data(df_2008, contest_col = contest, year_input = 2008, choice_col = choice)
cleaned_2012 <- cleaned_data(df_2012, contest_col = contest, year_input = 2012, choice_col = choice)

#Script to validate against NCSBE Dashboard
cleaned_2008 %>% group_by(Candidate) %>% summarise(ballot_count = sum(`total votes`))
cleaned_2012 %>% group_by(Candidate) %>% summarise(ballot_count = sum(`total votes`))

# Renaming Columns & Selecting Relevant Columns for 2012 
cleaned_2012 <- cleaned_2012 %>% 
  rename(
           Candidate_Party = `party`,
           Provisional_votes = 'Provisional',
           Absentee_by_mail = `Absentee by Mail`,
           Election_day_votes = `Election Day`,
           Total_votes = `total votes`,
           Early_voting = `One Stop`,
           County = county,
           Election_Year = Election_year
         ) %>% 
   select(
         County,
         Candidate,
         Candidate_Party,
         Election_day_votes,
         Early_voting,
         Absentee_by_mail,
         Provisional_votes,
         Total_votes,
         Election_Year
       )

#Creating total_absentee_early 
cleaned_2012 <- cleaned_2012 %>% 
  mutate(
    total_absentee_early = Absentee_by_mail + Early_voting
  )

#Creating final df for 2008

cleaned_2008 <- cleaned_2008 %>% 
  rename(
    Candidate_Party = `party`,
    Provisional_votes = 'Provisional',
#    Absentee_by_mail = `Absentee by Mail`,
    Election_day_votes = `Election Day`,
    Total_votes = `total votes`,
#    Early_voting = `One Stop`,
    County = county,
    Election_Year = Election_year
  ) %>% 
  mutate(
    Absentee_by_mail = NA,
    Early_voting = NA,
    total_absentee_early = `Absentee / One Stop`
  ) %>% 
  select(
    County,
    Candidate,
    Candidate_Party,
    Election_day_votes,
    Early_voting,
    Absentee_by_mail,
    Provisional_votes,
    Total_votes,
    Election_Year,
    total_absentee_early
  )

pres.2008.2012 <- bind_rows(cleaned_2008, cleaned_2012)

#Script to validate against NCSBE Dashboard 
pres.2008.2012 %>% 
  filter(Election_Year == 2008) %>% 
  group_by(Candidate_Party) %>% 
  summarise(Ballot_count = sum(Total_votes))

pres.2008.2012 %>% 
  filter(Election_Year == 2012) %>% 
  group_by(Candidate_Party) %>% 
  summarise(Ballot_count = sum(Total_votes))

pres.2008.2012 <- pres.2008.2012 %>% 
  mutate(
    County                = as.character(County),
    Candidate             = as.character(Candidate),
    Candidate_Party       = as.character(Candidate_Party),
    Election_day_votes    = as.integer(Election_day_votes),
    Early_voting          = as.integer(Early_voting),
    Absentee_by_mail      = as.integer(Absentee_by_mail),
    Provisional_votes     = as.integer(Provisional_votes),
    Total_votes           = as.integer(Total_votes),
    Election_Year         = as.integer(Election_Year),
    total_absentee_early  = as.integer(total_absentee_early)
  )

#Exporting to CSV to Upload to Supabase 
write.csv(pres.2008.2012, 'results_2008_2012', row.names = FALSE, na = "")

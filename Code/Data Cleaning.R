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

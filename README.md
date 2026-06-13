# Text-to-SQL Product: NC Presidential Election Results Explorer  
Access the App here: https://nc-pres.streamlit.app

A generative AI data product empowering non-technical stakeholders to interactively query historical NC presidential election results. 
---

## Problem Statement & Solution
Data teams in large or fast-moving organizations may be inundated with data requests from non-technical stakeholders. In turn, this could result in a significant lag in time-to-insight.
This prototype leverages Google Gemini to convert questions into structured PostgreSQL queries, which are securely executed against a cloud-hosted Supabase backend to serve rapid, interactive data summaries in a lightweight Streamlit UI.

---

## About the Data & Technologies Used  
Data used in the product are from Presidential election results in North Carolina between 2016 - 2024. Data was validated via the NCSBE Dashboard prior to ingestion to Supabase.   
  
Each row in the database is how a county voted for a specific candidate in a given presidential election. Accordingly, there is no underlying information about the characteristics of voters like age, gender, or party affiliation of the individual. 
  
Data was cleaned & wrangled using R. Python was used to connect to Supabase and to create the Streamlit frontend.  
  
---

## Technical Architecture
The tool bypasses complex orchestration packages to maintain a lean, highly readable, script-based architecture optimized for cloud performance.

```text
[User Prompt via Streamlit] 
        │
        ▼
[Gemini 3.5 Flash] ──► (Validates scope & writes SQL)
        │
        ▼
[Supabase Backend] 
        │
        ▼
[Interactive UI Dataframe] ──► (Results rendered instantly for user)
```

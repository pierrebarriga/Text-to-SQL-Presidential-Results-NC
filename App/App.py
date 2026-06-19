
import os
import streamlit as st
#from dotenv import load_dotenv
from supabase import create_client, Client
from google import genai

#Loading API Keys 
#load_dotenv()
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")
LLM_API_KEY = os.environ.get("LLM_API_KEY")

# Initialize Clients
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
ai_client = genai.Client(api_key=LLM_API_KEY)

# ==========================================
# 2. DATABASE & LLM LOGIC
# ==========================================
def execute_llm_sql(generated_sql: str):
    """Executes the LLM-generated SQL query via the Supabase RPC function."""
    try:
        response = supabase.rpc("rpc_execute_sql", {"query": generated_sql}).execute()
        return response.data
    except Exception as e:
        return f"Error executing query: {str(e)}"

def generate_sql_with_gemini(user_prompt: str, target_table: str, allowed_years: list, analysis_mode: str) -> str:
    """Uses LLM to convert a question into a SQL query."""
    prompt = f"""
    Convert the user's prompt into a PostgreSQL query.

    [QUERY CONSTRAINTS]
    - The target database table to query is explicitly: '{target_table}'
    - You MUST restrict your query to only include the following years: {allowed_years} by applying an appropriate WHERE or HAVING clause filtering the "Election_Year" column.
    - Current UI Analysis Mode: {analysis_mode}
    - Explicitly alias all tables in the FROM clause (e.g., FROM "county_aggregate_results" AS c) and prepend all column references with their respective table alias (e.g., c."Election_Year") to avoid column access ambiguity.
    - If using window functions like LAG() or LEAD(), ensure the argument inside the function references the original base table column name, NOT a newly created column alias.
    - Do not prepend queries with a database name prefix unless explicitly asked.
    - Return the SQL query formatted beautifully with clean line breaks and indentation.
    - Place major clauses (SELECT, FROM, WHERE, HAVING, GROUP BY, ORDER BY) on their own separate lines.
    - Wrap the table name "NC_Pres_Results" and all column names in double quotes to prevent PostgreSQL case-sensitivity errors. Also ensure that no SQL query executes with a semicolon at the end ';'. 
    - "Candidate_Party" only has the first three letters of the party abbreviation in capital letters, Democrats are stored as "DEM"; Republicans are stored as "REP"; Independents are stored as "IND".
    - Use ILIKE for string comparisons. Apply wildcards (%) deliberately based on the input context:
     * Use a single leading wildcard ('%Name') if searching for a specific last name.
     * Use standard wrapping ('%Name%') ONLY when matching a broad substring.
     * Avoid trailing wildcards if they risk capturing unwanted variations or null results from structural formatting.    
    - If a user asks a question that can't be derived from the table, do not generate SQL queries. Instead, start your response with the exact word 'REFUSAL:' and then explain why, listing the columns of the table in the output so that they can reframe their question. 
    - If it is valid, return ONLY the raw SQL query executable in PostgreSQL. Do not include markdown code blocks, backticks, or the word 'sql'.

    [ABOUT THE TABLES]
    There are two tables in the DB called 'NC_Pres_Results' & 'county_aggregate_results'. 
    Here is more information about the table: 
    - Data is election results from North Carolina between 2008 - 2024. 
    - Columns in the "NC_Pres_Results table include: County, Candidate, Candidate_Party, Early_voting, Absentee_by_mail, Provisional_votes, Total_votes, Election_Year
    - Columns in the "county_aggregate_results" table include: Election_Year, County, county_total_votes, Rep_total_votes, Dem_total_votes, Ind_total_votes, Perc_Rep_votes, Perc_Dem_votes, Perc_Ind_votes.
    - Rows in the "NC_Pres_results" are at the County-Candidate level. 
    - Rows in the "county_aggregate_results" table is about election results at the county-level, this does not have information about the voting method but gives more information on how political a county was over elections. 
    - There is no information related to voter characteristics (age, race, gender, income) listed in the table.

    User Question: {user_prompt}
    """
    try:
        response = ai_client.models.generate_content(
            model="gemini-3.5-flash",
            contents=prompt
        )
        return response.text.strip()
    except Exception as e:
        st.error(f"LLM Error: {str(e)}")
        return ""

# ==========================================
# 3. STREAMLIT FRONT-END UI
# ==========================================
st.set_page_config(page_title="Text-to-SQL Presidential Election Results Explorer", layout="wide")
st.title("NC Presidential Election Results Explorer")
st.divider()
st.subheader("About the Data & How to Use")
st.write("""
    - Data from the North Carolina State Board of Elections for Presidential elections between 2008 - 2024. Data about voters including race, political affiliation, and income is not included in this product.
    - The "Insight Type" filter allows users to query a database of either granular county-candidate level data or county-level summaries. County level summaries include information about the number of votes or the percentage of total votes based on the candidate's political party. Figures on voter turnout methods are excluded from the county-level summary table.  
    - To ask about changes across election cycles, select "Time Series" in the "Analysis Type" filter.
    - Prompt in your desired language!""")
st.divider()

st.subheader("Filters")
col1, col2, col3 = st.columns(3)
with col1:
    # Type of Analysis (Single select & Required)
    analysis_type = st.selectbox(
        "Analysis Type",
        options=["Descriptive", "Time Series", "Exploratory"],
        index=0
    )
with col2:
    # Election Year Filter 
    years_options = [2008, 2012, 2016, 2020, 2024]
    selected_years = st.multiselect(
       "Select Elections Years to Include",
       options=years_options,
       default=years_options
       )
with col3:
    # Insight Type Filter 
    insight_options = ['Detailed County-Candidate Level Data', 'County Level Summaries']
    
    if analysis_type == "Time Series":
        insight_type = st.selectbox(
            "Insight Type",
            options=['County Level Summaries'],
            index=0,
            disabled=True,
            help="Time Series analysis is restricted to County Level Summaries."
        )
    else:
        insight_type = st.selectbox(
            "Insight Type",
            options=insight_options,
            index=1 
        )

if insight_type == "Detailed County-Candidate Level Data":
    target_table = "NC_Pres_Results"  
else:
    target_table = "county_aggregate_results"


# Placeholder displaying the state of the filters to verify logic
#st.json({
 #   "Analysis Type": analysis_type,
  #  "Selected Year(s)": selected_years,
   # "Insight Type": insight_type
#})

user_prompt = st.text_input(
    "Enter your question:", 
    placeholder="e.g., Which county had the highest election day votes for Donald Trump in 2024?"
)

#Generating Query & Running
if st.button("Generate & Run Query"):
    if user_prompt:
        with st.spinner("Generating SQL and fetching results..."):
         
                llm_output = generate_sql_with_gemini(
                user_prompt=user_prompt,
                target_table=target_table,
                allowed_years=selected_years,
                analysis_mode=analysis_type
            )
            
        if llm_output:
                if llm_output.startswith("REFUSAL:"):
                    clean_refusal = llm_output.replace("REFUSAL:", "").strip()
                    st.warning(clean_refusal)
                
                else:
                    generated_sql = llm_output
                    results = execute_llm_sql(generated_sql)
                    
                    #Display results
                    st.success("Query Executed Successfully!")
                    st.subheader("Generated SQL:")
                    st.code(generated_sql, language="sql")
                    
                    st.subheader("Results:")
                    if isinstance(results, list):
                        if len(results) > 0:
                            st.dataframe(results)
                        else:
                            st.info("No records matched the criteria.")
                    else:
                        st.error(results)
    else:
        st.warning("Please enter a question first.")
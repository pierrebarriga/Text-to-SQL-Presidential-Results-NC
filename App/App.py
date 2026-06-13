
import os
import streamlit as st
from dotenv import load_dotenv
from supabase import create_client, Client
from google import genai

#Loading API Keys 
load_dotenv()
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

def generate_sql_with_gemini(user_prompt: str) -> str:
    """Uses LLM to convert a question into a SQL query."""
    prompt = f"""
    Convert the user's prompt into a PostgreSQL query.
    The database table is called 'NC_Pres_Results'. 
    Here is more information about the table: 
    - Scope of data is Presidential Elections for 2016, 2020 and 2024. 
    - Do not generate SQL for questions that require comparisons across presidential election cycles. 
    - Each row is the results for each county and the candidate in that specific election. 
    - Rows in the table include: 
    1. County 
    2. Candidate 
    3. Candidate_Party
    4. Election_day_votes 
    5. Early_voting
    6. Absentee_by_mail
    7. Provisional_votes
    8. Total_votes
    9. Election_Year
    - Wrap the table name "NC_Pres_Results" and all column names in double quotes to prevent PostgreSQL case-sensitivity errors.
    - There is no information related to voter characteristics (age, race, gender, income) listed in the table.
    - If a user asks a question that can't be derived from the table, do not generate SQL queries. Instead, start your response with the exact word 'REFUSAL:' and then explain why, listing the columns of the table in the output so that they can reframe their question. 
    - If it is valid, return ONLY the raw SQL query executable in PostgreSQL. Do not include markdown code blocks, backticks, or the word 'sql'.
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
st.set_page_config(page_title="NC Presidential Election Results - Text to SQL", layout="centered")

st.title("NC Presidential Election Results Explorer (2016 - 2024)")
st.subheader("Transform your question into a SQL query with Gemini.")

user_prompt = st.text_input(
    "Enter your question:", 
    placeholder="e.g., Which county had the highest election day votes for Donald Trump in 2024?"
)

if st.button("Generate & Run Query"):
    if user_prompt:
        with st.spinner("Generating SQL and fetching results..."):
            
            # Step 1: Generate response from Gemini
            llm_output = generate_sql_with_gemini(user_prompt)
            
            if llm_output:
                # FIX 2: Check if the LLM flagged an out-of-scope refusal
                if llm_output.startswith("REFUSAL:"):
                    # Strip the prefix and show a clean, user-friendly warning message
                    clean_refusal = llm_output.replace("REFUSAL:", "").strip()
                    st.warning(clean_refusal)
                
                else:
                    # It's a valid SQL statement, pass it safely to the database
                    generated_sql = llm_output
                    results = execute_llm_sql(generated_sql)
                    
                    # Step 3: Display results
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
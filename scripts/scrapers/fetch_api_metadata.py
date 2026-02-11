import os
import json
import requests
from requests.auth import HTTPBasicAuth

# 1. SETUP CREDENTIALS
# We check if they exist to avoid silent failures
API_USER = os.getenv("UNICONTA_USER") 
API_PASS = os.getenv("UNICONTA_PASS")
BASE_URL = "https://odata.uniconta.com/odata/32515/"

print("--- STARTING TABLE SCOUT ---")

# SAFETY CHECK: Are credentials actually loaded?
if not API_USER or not API_PASS:
    print("ERROR: Credentials not found!")
    print("Solution: Replace os.getenv(...) with your actual strings for this test.")
    # Stop the script here if no login details
    exit()

try:
    # 2. THE CALL
    # We MUST ask for 'application/json', otherwise Uniconta sends XML.
    res = requests.get(
        BASE_URL, 
        auth=HTTPBasicAuth(API_USER, API_PASS),
        headers={'Accept': 'application/json'}
    )
    
    # Check for HTTP errors (404, 401, etc.)
    res.raise_for_status()
    
    # 3. PARSE AND SAVE TO FILE
    data = res.json()
    table_list = data.get('value', [])

    print(f"SUCCESS! Found {len(table_list)} available tables.")
    
    # Save as JSON for better readability and structure
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(table_list, f, indent=4, ensure_ascii=False)
            
    print(f"Done! Open '{OUTPUT_FILE}' to see the list.")

except Exception as e:
    print(f"Error: {e}")
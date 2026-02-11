# ==============================================================================
# SCRIPT:   UNICONTA DATA PIPELINE (flush_and_fill)
# AUTHOR:   Vasilije Niko Nikolic
# DATE:     2026-02-11
# ==============================================================================
"""
CORE LOGIC EXPLAINED ("FLUSH AND FILL"):
----------------------------------------
1. FLUSH (Erase):
   Every time this script runs (via "Refresh"), Power BI completely erases
   the existing tables in memory. There is no "Incremental Refresh" here.
   
2. FILL (Fresh Download):
   The script connects to the Uniconta API and downloads a FRESH COPY of
   the data from scratch. 
   - If a row was deleted in Uniconta yesterday, it disappears here today.
   - If a row was changed, the new version replaces the old one instantly.

3. DATE FILTERING (The Time Machine):
   To keep performance high, "Heavy Tables" (Invoices, Ledger, Stock) are 
   explicitly filtered to start from 2020-01-01.
   
   !!! WARNING !!!
   Data older than 2020-01-01 is NOT retrieved. It is effectively "deleted" 
   from this report. To retrieve older history, modify 'DATE_FILTER_TABLES' below.
"""

import os
import pandas as pd
import requests
from requests.auth import HTTPBasicAuth
from concurrent.futures import ThreadPoolExecutor
from dotenv import load_dotenv

# Load local .env file if it exists
load_dotenv()

# ==============================================================================
# 1. CONFIGURATION & CREDENTIALS
# ==============================================================================
# Credentials must be set as System Environment Variables on the PC/Server.
API_USER = os.getenv("UNICONTA_USER")
API_PASS = os.getenv("UNICONTA_PASS")

if not API_USER or not API_PASS:
    raise ValueError(
        "CRITICAL ERROR: Uniconta credentials not found. "
        "Please set UNICONTA_USER and UNICONTA_PASS environment variables."
    )

BASE_URL = "https://odata.uniconta.com/odata/32515/"

# ------------------------------------------------------------------------------
# TABLE MAPPING (Friendly Name -> API Endpoint)
# ------------------------------------------------------------------------------
URLS = {
    # === ZONE 1: MASTER DATA (FULL HISTORY) ===
    # These datasets are relatively small and critical for referential integrity.
    # They are always loaded in full (No Date Filter).
    "Customers":        f"{BASE_URL}DebtorClientUser",
    "Vendors":          f"{BASE_URL}CreditorClientUser",
    "Items":            f"{BASE_URL}InvItemClientUser",
    "Employees":        f"{BASE_URL}EmployeeClientUser",
    "Warehouses":       f"{BASE_URL}InvWarehouseClient",

    # === ZONE 2: TRANSACTIONAL DATA (FILTERED > 2020) ===
    # These datasets grow continuously. To prevent performance degradation,
    # a strict date filter (>= 2020-01-01) is applied.
    
    # -- Finance --
    "GeneralLedger":    f"{BASE_URL}GLTransClientUser",
    "GLAccounts":       f"{BASE_URL}GLAccountClientUser",

    # -- Purchasing --
    "PurchaseOrders":   f"{BASE_URL}CreditorOrderClientUser",
    "PurchaseLines":    f"{BASE_URL}CreditorOrderLineClientUser",

    # -- Production --
    "ProductionOrders": f"{BASE_URL}ProductionOrderClientUser",
    "ProductionLines":  f"{BASE_URL}ProductionOrderLineClientUser",
    "ProductionPosted": f"{BASE_URL}ProductionPostedClientUser",
    "BOMs":             f"{BASE_URL}InvBOMClientUser",

    # -- Sales --
    "SalesInvoices":    f"{BASE_URL}DebtorInvoiceClientUser",
    "InvoiceLines":     f"{BASE_URL}DebtorInvoiceLinesUser",
    "StockMovements":   f"{BASE_URL}InvTransClient",
    "SerialNumbers":    f"{BASE_URL}InvSerieBatchClientUser",

    # -- Pipeline --
    "SalesOffers":      f"{BASE_URL}DebtorOfferClientUser",
    "SalesOrders":      f"{BASE_URL}DebtorOrderClientUser",
    "OrderLines":       f"{BASE_URL}DebtorOrderLineClientUser",
}

# ------------------------------------------------------------------------------
# DATE FILTER CONFIGURATION
# Purpose: Prevent timeout/crash by ignoring ancient history.
# Logic:   Only fetch rows where Date >= 2020-01-01.
# ------------------------------------------------------------------------------
DATE_FILTER_TABLES = {
    "GeneralLedger":    "2020-01-01",
    "StockMovements":   "2020-01-01",
    "SalesInvoices":    "2020-01-01",
    "InvoiceLines":     "2020-01-01"
}

# ------------------------------------------------------------------------------
# DATA TYPE DEFINITIONS (For Hardening)
# ------------------------------------------------------------------------------
# Columns that must ALWAYS be Text (prevents "100" becoming 100.0)
FORCE_TEXT_COLS = [
    'Account', 'DCAccount', 'Item', 'Warehouse', 'Location',
    'Project', 'Employee', 'OrderNumber', 'InvoiceNumber', 'Voucher',
    'ProductionNumber', 'RequisitionNumber', 'Settlement', 'Value',
    'Cost', 'Margin', 'Volume', 'Amount', 'Price', 'Qty', 'Total',
    'Weight', 'Rate'
]

# Date columns to parse safely
DATE_COLS = ['Date', 'DeliveryDate', 'DueDate', 'PaymentDate', 'ShipmentDate']

# Numeric columns to scan for "Danish Formatting" (e.g., 1.250,50)
NUM_KEYWORDS = [
    'Price', 'Cost', 'Qty', 'Amount', 'Total',
    'Weight', 'Volume', 'Margin', 'Rate', 
    'Value', 'Balance', 'Debit', 'Credit'
]


# ==============================================================================
# 2. DATA CLEANING ENGINE
# ==============================================================================
def clean_data(df: pd.DataFrame) -> pd.DataFrame:
    """
    Applies strict data typing and cleaning to prevent Power BI crashes.
    
    1. Text IDs: Forces IDs (e.g. Account numbers) to String.
    2. Safe Dates: Converts '0001-01-01' to NaT (Blank) to prevent errors.
    3. Danish Numbers: Intellectually detects '1.000,00' vs '1,000.00' and 
       standardizes everything to Python Floats.
    """
    if df.empty:
        return df

    # --- A. Force IDs to String ---
    for col in df.columns:
        if col in FORCE_TEXT_COLS or col.endswith("ID") or col.endswith("Number"):
            df[col] = df[col].astype(str).replace('nan', '')

    # --- B. Safe Date Parsing ---
    for col in DATE_COLS:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col], errors='coerce')

    # --- C. Advanced Numeric Cleanup (Danish/US Logic) ---
    for col in df.columns:
        if any(keyword in col for keyword in NUM_KEYWORDS):
            
            def fix_danish_number(val):
                s = str(val).strip()
                if not s or s == 'nan' or s == 'None':
                    return 0.0
                
                # Case 1: Danish Format (e.g. "100.000,88")
                # Look for BOTH dot and comma, where comma is at the end.
                if '.' in s and ',' in s and s.rfind(',') > s.rfind('.'):
                    s = s.replace('.', '')  # Remove thousands separator (dot)
                    s = s.replace(',', '.') # Turn decimal comma into dot
                
                # Case 2: Simple Danish Decimal (e.g. "50,88")
                elif ',' in s and '.' not in s:
                     s = s.replace(',', '.')
                
                # Case 3: Standard US/Code Format (e.g. "100000.88") -> Keep as is.
                
                return s

            # Apply the fix row-by-row
            df[col] = df[col].apply(fix_danish_number)
            # Convert to actual Float (crashing values become 0.0)
            df[col] = pd.to_numeric(df[col], errors='coerce').fillna(0.0)

    return df


# ==============================================================================
# 3. FETCH ENGINE (WORKER FUNCTION)
# ==============================================================================
def fetch_one_table(entry: tuple, session: requests.Session) -> tuple:
    """
    Connects to API, handles Pagination (Next Page), and applies filters.
    Returns: (Table Name, Cleaned DataFrame, Error Message)
    """
    name, url = entry
    all_records = []

    # 1. Apply Date Filter (if this table is in the filter list)
    params = {}
    if name in DATE_FILTER_TABLES:
        cutoff = DATE_FILTER_TABLES[name]
        # OData Syntax: "Date greater than or equal to YYYY-MM-DDT00:00:00"
        params = {"$filter": f"Date ge datetime'{cutoff}T00:00:00'"}

    try:
        # 2. Pagination Loop (Keep asking until 'nextLink' is gone)
        while url:
            resp = session.get(
                url,
                auth=HTTPBasicAuth(API_USER, API_PASS),
                headers={'Accept': 'application/json'},
                params=params,
                timeout=60 # Timeout after 60s to prevent hanging
            )
            resp.raise_for_status()
            payload = resp.json()

            if 'value' in payload:
                all_records.extend(payload['value'])

            # Check if there is another page of data
            url = payload.get('@odata.nextLink')
            
            # CLEAR PARAMS: The 'nextLink' already contains the filter.
            # If we send params again, the API might error out.
            params = {}

        # 3. Convert to DataFrame and Clean
        raw_df = pd.DataFrame(all_records)
        clean_df = clean_data(raw_df)
        return name, clean_df, None

    except Exception as exc:
        error_msg = f"{type(exc).__name__}: {str(exc)}"
        return name, pd.DataFrame(), error_msg


# ==============================================================================
# 4. MAIN EXECUTION (THREAD POOL)
# ==============================================================================
"""
ORCHESTRATION LOGIC:
This section manages the parallel execution of the data extraction.

1. Session Reuse: A single HTTP session is established to persist authentication 
   headers, reducing overhead (TCP handshakes) for repeated API calls.
   
2. ThreadPoolExecutor: 
   - Instead of fetching tables one by one (Sequential), we fetch 5 tables 
     simultaneously (Parallel).
   - 'max_workers=5' is the safe limit to avoid hitting Uniconta API Rate Limits.
   
3. Result Collection:
   - As each thread finishes, we separate successful DataFrames into 'data_results'
     and failed attempts into 'error_log'.
"""

# Single session for efficiency
session = requests.Session()
session.auth = HTTPBasicAuth(API_USER, API_PASS)

data_results = {}
error_log = []

# Fetch 5 tables at a time (Parallel Processing)
with ThreadPoolExecutor(max_workers=5) as executor:
    futures = [
        executor.submit(fetch_one_table, entry, session)
        for entry in URLS.items()
    ]

    for fut in futures:
        name, df, err_msg = fut.result()
        if err_msg:
            error_log.append({"Table": name, "Error": err_msg})
            data_results[name] = pd.DataFrame() # Return empty table on error
        else:
            data_results[name] = df


# ==============================================================================
# 5. EXPORT TO POWER BI
# ==============================================================================
# These variables are automatically picked up by Power Query.

# Master Data
Customers   = data_results.get("Customers", pd.DataFrame())
Vendors     = data_results.get("Vendors", pd.DataFrame())
Items       = data_results.get("Items", pd.DataFrame())
Employees   = data_results.get("Employees", pd.DataFrame())
Warehouses  = data_results.get("Warehouses", pd.DataFrame())

# Finance
GeneralLedger = data_results.get("GeneralLedger", pd.DataFrame())
GLAccounts    = data_results.get("GLAccounts", pd.DataFrame())

# Purchasing
PurchaseOrders = data_results.get("PurchaseOrders", pd.DataFrame())
PurchaseLines  = data_results.get("PurchaseLines", pd.DataFrame())

# Production
ProductionOrders = data_results.get("ProductionOrders", pd.DataFrame())
ProductionLines  = data_results.get("ProductionLines", pd.DataFrame())
ProductionPosted = data_results.get("ProductionPosted", pd.DataFrame())
BOMs             = data_results.get("BOMs", pd.DataFrame())

# Sales & Operations
SalesInvoices = data_results.get("SalesInvoices", pd.DataFrame())
InvoiceLines  = data_results.get("InvoiceLines", pd.DataFrame())
StockMovements = data_results.get("StockMovements", pd.DataFrame())
SerialNumbers  = data_results.get("SerialNumbers", pd.DataFrame())
SalesOffers    = data_results.get("SalesOffers", pd.DataFrame())
SalesOrders    = data_results.get("SalesOrders", pd.DataFrame())
OrderLines     = data_results.get("OrderLines", pd.DataFrame())

# --- DIAGNOSTICS & HEALTH CHECK ---
"""
DIAGNOSTIC TABLES EXPLAINED:
These tables are generated by the script to help you monitor data health.

1. LogTable (The Receipt):
   - Shows the exact Row Count for every loaded table.
   - USE CASE: If 'SalesInvoices' shows 0 rows, check if the Date Filter is too strict.

2. ErrorLog (The Debugger):
   - Captures any Python crashes or API errors (e.g., Timeout, 401 Unauthorized).
   - USE CASE: If a table is empty, check this log for the specific error message.
"""

# --- LOGGING TABLES ---
# LogTable: Summary of how many rows were loaded per table.
log_data = []
for name, df in data_results.items():
    log_data.append({
        "Table Name": name,
        "Row Count": len(df),
        "Status": "Loaded" if not df.empty else "Empty/Failed"
    })
LogTable = pd.DataFrame(log_data)

# ErrorLog: Detailed error messages for debugging.
ErrorLog = pd.DataFrame(error_log)
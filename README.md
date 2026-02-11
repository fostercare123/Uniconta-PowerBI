# Uniconta-PowerBI
This repository contains the end-to-end data pipeline for extracting, cleaning, and transforming Uniconta ERP data for Power BI reporting.

📂 Project Structure
/scripts: Python-based data extraction engine.

main/flush_and_fill.py: The core script that fetches transactional and master data via OData API.

scrapers/fetch_api_metadata.py: Utility to scout available Uniconta tables.

/powerquery: Power Query (M) scripts for data transformation.

SalesInvoices.m: Standardized transformation for invoice data with Danish labels.

/docs: Documentation and logic flow diagrams.

⚙️ Core Logic: "Flush and Fill"
The pipeline follows a strict Flush and Fill methodology to ensure data integrity:

Flush: Every refresh completely clears the existing data in the Power BI model.

Fill: A fresh copy of all data (filtered from 2020-01-01 onwards) is downloaded from the Uniconta API.

Accuracy: This eliminates issues with deleted or modified records in the ERP, as the report always reflects the current state of Uniconta.

🚀 Getting Started
1. Prerequisites
Ensure you have Python installed and the required libraries:

Bash
pip install -r requirements.txt
2. Environment Variables
To secure API credentials, create a .env file in the root directory (this file is ignored by Git):

Plaintext
UNICONTA_USER=your_username
UNICONTA_PASS=your_password
3. Usage
Run the Python script to fetch raw data: python scripts/main/flush_and_fill.py.

Open Power BI and refresh to apply the transformations located in /powerquery.

🛠 Technical Standards
Renaming Logic: We use a Hybrid Approach. Internal Power Query steps and comments are in English for IT maintenance, while final column headers are in Danish for business user clarity.

Performance: Transactional tables (Invoices, Ledger, Stock) are filtered to start from 2020-01-01 to ensure fast refresh times.

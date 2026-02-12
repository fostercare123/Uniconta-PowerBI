# Uniconta ↔ Power BI Data Pipeline

An automated solution for extracting, cleaning, and transforming Uniconta ERP data for Power BI reporting.

## 📁 Project Structure
```
/Project-Root
|-- scripts/
|   |-- main/
|   |   `-- flush_and_fill.py             # Core Python "Flush & Fill" engine
|   `-- scrapers/
|       `-- fetch_api_metadata.py         # Helper to discover Uniconta tables
|-- powerquery/
|   |-- Uniconta_Labels_Standard.m        # M Script - Standard Label loader
|   |-- Uniconta_Labels_Custom.m          # M Script - Custom Label loader
|   |-- Uniconta_Dictionary.m             # M Script - Merged mapping engine
|   |-- InvoiceLines.m                    # M Script - (Fakturalinjer) dynamic renaming
|   `-- SalesInvoices.m                   # M Script - (Fakturaer) dynamic renaming
|-- docs/
|   |-- Uniconta_Labels_Standard.xlsx     # Standard API translations
|   `-- Uniconta_Labels_Custom.xlsx       # User-defined custom renames
|-- .gitignore                            # Project exclusion rules
`-- requirements.txt                      # Python dependencies
```

## ⚙️ Core Logic: "Flush and Fill"
The pipeline follows a strict **Flush and Fill** methodology to guarantee data integrity:

- **Flush**  
  Every refresh **completely clears** the existing data in the Power BI model.

- **Fill**  
  A fresh copy of **all relevant data** is downloaded directly from the Uniconta OData API.

- **Why?**  
  This approach eliminates problems with deleted, modified or partially synced records — the report always shows **the current true state** of Uniconta.

### 2. Dynamic Label Mapping
This project uses a metadata-driven approach to renaming columns. Instead of hard-coding translations in Power BI, we use a "Dictionary" logic:
- **Standard Labels**: Default Uniconta technical-to-Danish mappings.
- **Custom Labels (Egne Labels)**: User-defined renames that take priority.
- **Portability**: All file paths are relative to the `ProjectPath` parameter, making the project portable between office and home environments.  

## 🚀 Getting Started

### 1. Prerequisites
- Python 3.x
- Power BI Desktop
- Access to Uniconta API

Install required Python packages:
```bash
pip install -r requirements.txt
```

### 2. Environment Variables
Create a `.env` file in the root directory (remember to add it to `.gitignore`):

```plaintext
UNICONTA_USER=your_username
UNICONTA_PASS=your_password
```

### 3. Deployment
1. Clone the repository.
2. Open `Uniconta-PowerBI.pbix`.
3. Update the `ProjectPath` parameter to match your local folder.

# Uniconta ↔ Power BI Data Pipeline

An end-to-end solution for extracting, cleaning, and transforming Uniconta ERP data for Power BI reporting.

## 📁 Project Structure
```
├─ scripts/
│   ├─ main/
│   │   └─ flush_and_fill.py       # Core “Flush & Fill” engine
│   └─ scrapers/
│       └─ fetch_api_metadata.py   # Helper to discover Uniconta tables
├─ powerquery/
│   └─ SalesInvoices.m             # M script – Danish-labelled invoices
├─ docs/
│   └─ …                           # Diagrams, docs, flowcharts
└─ requirements.txt                # Python dependencies
```

## ⚙️ Core Logic: "Flush and Fill"

The pipeline follows a strict **Flush and Fill** methodology to guarantee data integrity:

- **Flush**  
  Every refresh **completely clears** the existing data in the Power BI model.

- **Fill**  
  A fresh copy of **all relevant data** is downloaded directly from the Uniconta OData API.

- **Why?**  
  This approach eliminates problems with deleted, modified or partially synced records — the report always shows **the current true state** of Uniconta.

## 🚀 Getting Started

### 1. Prerequisites
- Python
- Power BI Desktop
- Uniconta user with API access

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

### 3. Usage
Paste the Python code `flush_and_fill.py` into Power BI.

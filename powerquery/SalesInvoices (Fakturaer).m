// =============================================================================
// POWER QUERY CLEAN‑UP SCRIPT
// =============================================================================
//
//  Description
//  -----------
//  Loads the raw *SalesInvoices* table, renames every column to the Danish
//  terminology used inside the company, cleans text, converts numbers,
//  fixes percentages, normalises dates, discards unused columns and finally
//  re‑orders the remaining fields for a friendly reporting view.
//
//  Author      : Vasilije Niko Nikolic
//  Created on  : 2026‑01‑28
//  Last update : 2026‑02‑11
//  Prerequisite: A data model that contains a table named “SalesInvoices”
//                inside the query “MASTER_DATA”.
//
 // Usage
 // -----
 // 1. Open Power BI Desktop → Home → Transform data → Advanced Editor.
 // 2. Replace the existing code with the block below.
 // 3. Click **Done**, then **Close & Apply**.
 // 4. Build visualisations using the columns that appear in the final table.
//
// =============================================================================

let
    // ---------------------------------------------------------------------
    // 0 GLOBAL SETTINGS
    // ---------------------------------------------------------------------
    // Locale used when converting numbers that contain a dot as decimal separator.
    localeUS   = "en-US",

    // List of columns that must survive to the final report.
    // Everything else is removed in step 7.
    keepColumns = {
        "Dato","FakturaNummer","OrdreNummer","Bilag","Konto","KontoNavn",
        "TotalBeløb","NettoBeløb","MomsBeløb","Moms","Valuta","ValutaKurs",
        "KostVærdi","SalgsVærdi","DB","DG-procent","ForfaldsDato",
        "FristDato","UdløbsDato","Betaling","BetalingsTekst","FIKkode",
        "LeveringsNavn","LeveringsLand","LeveringsLandenavn","KontaktPerson",
        "Medarbejder","Oprettet","EmailSendt","Tilbud",
        "LinjeBeløb","MomsBeløb1","MomsProcent"
    },

    // ---------------------------------------------------------------------
    // 1 LOAD RAW DATA
    // ---------------------------------------------------------------------
    // MASTER_DATA is the data model that contains the original table.
    // We pick the table named “SalesInvoices”.
    Source        = MASTER_DATA,
    SalesInvoices = Source{[Name = "SalesInvoices"]}[Value],

    // ---------------------------------------------------------------------
    // 2 ONE‑TIME RENAME OF EVERY SOURCE COLUMN
    // ---------------------------------------------------------------------
    // The company works with Danish column names, but the source uses English.
    // This list maps every source column to its Danish counterpart.
    renameAll = {
        {"Account",               "Konto"},
        {"InvoiceNumber",         "FakturaNummer"},
        {"OrderNumber",           "OrdreNummer"},
        {"Date",                  "Dato"},
        {"Payment",               "Betaling"},
        {"TotalAmount",           "TotalBeløb"},
        {"NetAmount",             "NettoBeløb"},
        {"VatTotal",              "MomsBeløb1"},
        {"VatAmount",             "MomsBeløb"},
        {"VatPct",                "MomsProcent"},
        {"Vat",                   "Moms"},
        {"DeliveryName",          "LeveringsNavn"},
        {"DeliveryAddress1",      "LeveringsAdresse1"},
        {"DeliveryAddress2",      "LeveringsAdresse2"},
        {"DeliveryAddress3",      "LeveringsAdresse3"},
        {"DeliveryZipCode",       "LeveringsPostnummer"},
        {"DeliveryCity",          "LeveringsBy"},
        {"DeliveryContactPerson", "KontaktPersonForLevering"},
        {"DeliveryPhone",         "LeveringsTelefon"},
        {"DeliveryContactEmail",  "LeveringsEmail"},
        {"DeliveryCountry",       "LeveringsLand"},
        {"DeliveryCountryName",   "LeveringsLandenavn"},
        {"YourRef",               "DeresRef"},
        {"OurRef",                "VoresRef"},
        {"Shipment",              "Forsendelse"},
        {"ShipmentText",          "ForsendelseNavn"},
        {"DeliveryTerm",          "LeveringsBetingelse"},
        {"DeliveryTermText",      "LeveringsBetingelseNavn"},
        {"VoucherX",              "EkstraBilag"},
        {"DeliveryTime",          "LeveringsTid"},
        {"Employee",              "Medarbejder"},
        {"Requisition",           "Rekvisition"},
        {"DeliveryDate",          "LeveringsDato"},
        {"OrderCreated",          "Oprettet"},
        {"FIKCode",               "FIKkode"},
        {"Weight",                "Vægt"},
        {"DeliveryIsInvoiceAddress","FakturaAdresseLigLeveringsAdresse"},
        {"PrimaryKeyId",          "RowID"},
        {"AmountLocalCur",        "BeløbiLokalValuta"},
        {"PaymentText",           "BetalingsTekst"},
        {"DueDate",               "ForfaldsDato"},
        {"CostValue",             "KostVærdi"},
        {"LayoutGroup",           "LayoutGruppe"},
        {"PackNote",              "Følgeseddel"},
        {"Margin",                "DB"},
        {"MarginRatio",           "DG-procent"},
        {"SalesValue",            "SalgsVærdi"},
        {"Name",                  "KontoNavn"},
        {"GraceDate",             "FristDato"},
        {"JournalPostedId",       "BogføringsNummer"},
        {"LineAmount",            "LinjeBeløb"},
        {"Offer",                 "Tilbud"},
        {"Voucher",               "Bilag"},
        {"Currency",              "Valuta"},
        {"ExchangeRate",          "ValutaKurs"},
        {"Udloeb",                "UdløbsDato"},
        {"SendTime",              "EmailSendt"},
        {"ContactName",           "KontaktPerson"}
    },

    // Apply the renaming. All columns now have Danish names.
    Renamed = Table.RenameColumns(
        SalesInvoices,
        renameAll,
        MissingField.Ignore
    ),

    // ---------------------------------------------------------------------
    // 3️ BASIC TEXT CLEANING
    // ---------------------------------------------------------------------
    // • Trim whitespace from the account field (helps with joins).  
    // • Some date columns arrive as ISO strings like “2023‑04‑01T00:00:00”.
    //   We strip the “T…” part so the later date conversion works.
    CleanedText = Table.TransformColumns(
        Renamed,
        {
            {"Konto", Text.Trim, type text},
            {"UdløbsDato", each if _ <> null then Text.BeforeDelimiter(_, "T") else _, type text}
        }
    ),

    // ---------------------------------------------------------------------
    // 4 CONVERT TEXT TO NUMBERS (US locale)
    // ---------------------------------------------------------------------
    // The source stores numbers as text with a dot decimal separator.
    // We coerce them to proper numeric types.
    NumbersFixed = Table.TransformColumnTypes(
        CleanedText,
        {
            {"KostVærdi",          type number},
            {"DB",                 type number},
            {"SalgsVærdi",         type number},
            {"DG-procent",         type number},
            {"MomsBeløb",          type number},
            {"LinjeBeløb",         type number},
            {"NettoBeløb",         type number},
            {"TotalBeløb",         type number},
            {"MomsBeløb1",         type number},
            {"BeløbiLokalValuta",  type number},
            {"ValutaKurs",         type number},
            {"MomsProcent",        type number}
        },
        localeUS
    ),

    // ---------------------------------------------------------------------
    // 5 TURN RAW PERCENT VALUES INTO REAL PERCENTAGES
    // ---------------------------------------------------------------------
    // Source stores 15 % as “15”. Power BI expects 0.15 for a percentage.
    Percentages = Table.TransformColumns(
        NumbersFixed,
        {
            {"DG-procent", each _ / 100, Percentage.Type},
            {"MomsProcent", each _ / 100, Percentage.Type}
        }
    ),

    // ---------------------------------------------------------------------
    // 6 DATE‑TIME → DATE (drop the time part)
    // ---------------------------------------------------------------------
    // First force everything to datetime (some columns are still text).
    // Then convert to plain date – the time component is irrelevant for reporting.
    DatesTyped = Table.TransformColumnTypes(
        Percentages,
        {
            {"FristDato",      type datetime},
            {"EmailSendt",     type datetime},
            {"Oprettet",       type datetime},
            {"Dato",           type datetime},
            {"LeveringsDato",  type datetime},
            {"ForfaldsDato",  type datetime},
            {"UdløbsDato",    type datetime}
        }
    ),
    DatesOnly = Table.TransformColumnTypes(
        DatesTyped,
        {
            {"FristDato",      type date},
            {"EmailSendt",     type date},
            {"Oprettet",       type date},
            {"Dato",           type date},
            {"LeveringsDato",  type date},
            {"ForfaldsDato",  type date},
            {"UdløbsDato",    type date}
        }
    ),

    // ---------------------------------------------------------------------
    // 7 KEEP ONLY THE COLUMNS THAT MATTER (whitelist)
    // ---------------------------------------------------------------------
    // Anything not listed in *keepColumns* is removed here.
    // MissingField.UseNull ensures the step won’t crash if a column is absent.
    Selected = Table.SelectColumns(
        DatesOnly,
        keepColumns,
        MissingField.UseNull
    ),

    // ---------------------------------------------------------------------
    // 8 REORDER COLUMNS FOR FRIENDLY REPORT VIEW
    // ---------------------------------------------------------------------
    // The order below matches the way the business expects to see data.
    Ordered = Table.ReorderColumns(
        Selected,
        {
            "Dato","FakturaNummer","OrdreNummer","Bilag","Konto","KontoNavn",
            "TotalBeløb","NettoBeløb","MomsBeløb","Moms","Valuta","ValutaKurs",
            "KostVærdi","SalgsVærdi","DB","DG-procent","ForfaldsDato",
            "FristDato","UdløbsDato","Betaling","BetalingsTekst","FIKkode",
            "LeveringsNavn","LeveringsLand","LeveringsLandenavn","KontaktPerson",
            "Medarbejder","Oprettet","EmailSendt","Tilbud",
            "LinjeBeløb","MomsBeløb1","MomsProcent"
        }
    )
in
    // The final table that will be loaded into the Power BI model.
    Ordered
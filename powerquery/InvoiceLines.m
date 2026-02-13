/*
    Author: Vasilije Niko Nikolic
    Description: Fetches raw InvoiceLines data and applies dynamic renaming 
    based on the Uniconta_Dictionary mapping.
*/
let
    /* Fetch raw data from the Python pipeline */
    Source = MASTER_DATA,
    RawData = Source{[Name="InvoiceLines"]}[Value],

    /* Generate the dynamic mapping list of {TechnicalID, DisplayName} pairs */
    RenameMapping = List.Zip({
        Table.Column(Uniconta_Dictionary, "TechnicalID"), 
        Table.Column(Uniconta_Dictionary, "DisplayName")
    }),

    /* Execute dynamic renaming. Skips fields not found in the dictionary */
    #"Dynamic Rename" = Table.RenameColumns(RawData, RenameMapping, MissingField.Ignore),

    /* Apply locale-aware data typing for Danish standards */
    #"Final Types" = Table.TransformColumnTypes(#"Dynamic Rename", {
        {"Dato", type date},
        {"Nettobeløb", type number}
    }, "da-DK"),

    /* Removed junk columns */
    #"Removed Columns" = Table.RemoveColumns(#"Final Types",{"EAN", "CreditorGroup", "Mærkegruppe", "Artsgruppe", "Statistikgruppe", "Opgave", "UrlLink", "PhotoLink", "Link til faktura", "Referencenummer", "Uge", "Lagersted", "WarehouseName", "Placering", "Variant", "VariantName", "DateOnOrder", "Deres varenummer", "UnitGroup", "Rabat", "Slutrabat %", "Produktionens bekræftet dato", "Requested dlv. date", "Forventet lev. dato", "Bogføringskonto", "PhotoBuffer", "PhotoUrl", "FormattedSerieBatchNumbers", "Resterende", "QtyInvoiced", "Bestilt antal", "Nettovægt", "Karton", "xConfirmableDate", "Confirmed", "Rumfang", "TjekiC5", "Moms %", "VatAmount", "Varebevægelse", "Regulering af kostbeløb", "SubTotal", "Importerede", "Kostbeløb bogført", "Lageropdatering", "InvJournalPostedId", "PartOfBOM", "Leveringstid"}),

    /* SORT COLUMNS: Removed trailing comma and mismatched columns */
    #"Reordered Columns" = Table.ReorderColumns(#"Removed Columns", {
        "Dato", "Fakturanummer", "Ordrenummer", "Kontonavn", "Varenavn", "Antal", "Nettobeløb", "DB", "DG-procent",
        "Produktionsnummer", "NetAmountInv", "GrossAmountInv", "Vægt", "UnitStr", "InvoiceQty", "InvoicePrice", 
        "InvoiceTotal", "InvoiceNetAmount", "Beløb inkl. moms", "FormattedInvoiceQty", "Forventet dato", "Vores varenummer", 
        "Linjenummer", "Vare", "DCAccount", "Bruttobeløb", "I alt", "Margin", "MarginRatio", "Kostpris", "Kostværdi", 
        "Salgspris", "Valuta", "SalesPriceCur", "Sum valuta", "Rabatprocent", "NetDiscount", "Moms", "Tekst", "Enhed", 
        "Medarbejder", "Medarbejdernavn", "Bogføringsnummer", "Notat", "Batch- eller serienummer", "Gruppe", "DebtorGroup"
    }, MissingField.Ignore)
in
    #"Reordered Columns"
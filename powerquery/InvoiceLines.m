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
    }, "da-DK")
in
    #"Final Types"

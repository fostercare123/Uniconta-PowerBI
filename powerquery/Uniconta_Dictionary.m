/*
    The 'Brain' of the renaming system. 
    Combines Standard and Custom labels, ensuring Custom renames 
    take precedence over Standard ones.
*/
let
    /* Access your two queries that the ProjectPath parameter */
    Standard = Uniconta_Labels_Standard,
    Custom = Uniconta_Labels_Custom,

    /* Combine both lists. Custom comes first to take priority */
    Combined = Table.Combine({Custom, Standard}),

    /* Select the technical API ID and the business Display Name */
    SelectedColumns = Table.SelectColumns(Combined, {"TechnicalID", "DisplayName"}),

    /* FIX: Remove any rows where IDs or Names are null or empty. 
       This prevents the 'RenameOperations' error. */
    CleanRows = Table.SelectRows(SelectedColumns, each 
        ([TechnicalID] <> null and [TechnicalID] <> "") and 
        ([DisplayName] <> null and [DisplayName] <> "")
    ),

    /* Remove duplicates based on the technical ID. 
       This ensures custom renames are preserved over standard ones. */
    FinalDictionary = Table.Distinct(CleanRows, {"TechnicalID"})
in
    FinalDictionary
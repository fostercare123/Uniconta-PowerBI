/*
    Fetches custom user-defined labels (Egne Labels) from the local Excel file.
    Uses the ProjectPath parameter for portability.
*/
let
    /* Load custom labels using ProjectPath */
    Source = Excel.Workbook(File.Contents(ProjectPath & "\docs\Uniconta_Labels_Custom.xlsx"), null, true),
    
    /* Target shee called 'Sheet1' */
    Data_Sheet = Source{[Item="Sheet1",Kind="Sheet"]}[Data],
    
    /* Process headers and data types */
    #"Promoted Headers" = Table.PromoteHeaders(Data_Sheet, [PromoteAllScalars=true]),
    #"Final Schema" = Table.TransformColumnTypes(#"Promoted Headers",{{"TechnicalID", type text}, {"DisplayName", type text}})
in
    #"Final Schema"
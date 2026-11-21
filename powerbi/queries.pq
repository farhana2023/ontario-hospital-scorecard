// queries.pq - Power Query (M) for every table in the model.
// In Power BI Desktop: Transform data > New Source > Blank Query > Advanced Editor,
// paste ONE block per query and name the query as in the header comment.
// Or skip this file: Get Data > SQL Server > select the 5 mart.* views (same result).

// ===== Query name: SqlServer  (parameter) =====
"localhost" meta [IsParameterQuery = true, Type = "Text", IsParameterQueryRequired = true]
// use "(localdb)\MSSQLLocalDB" or ".\SQLEXPRESS" if that is your instance

// ===== Query name: SqlDatabase  (parameter) =====
"OntarioScorecard" meta [IsParameterQuery = true, Type = "Text", IsParameterQueryRequired = true]

// ===== Query name: dim_hospital =====
let
    Source = Sql.Database(SqlServer, SqlDatabase),
    Data   = Source{[Schema = "mart", Item = "dim_hospital"]}[Data],
    Typed  = Table.TransformColumnTypes(Data, {
        {"hospital_id", Int64.Type}, {"hospital_name", type text}, {"region", type text},
        {"size_band", type text}, {"size_band_sort", Int64.Type}})
in
    Typed

// ===== Query name: dim_indicator =====
let
    Source = Sql.Database(SqlServer, SqlDatabase),
    Data   = Source{[Schema = "mart", Item = "dim_indicator"]}[Data],
    Typed  = Table.TransformColumnTypes(Data, {
        {"indicator_code", type text}, {"short_name", type text}, {"indicator_name", type text},
        {"domain", type text}, {"metric", type text}, {"unit_label", type text},
        {"has_ci", type logical}, {"lower_is_better", type logical}, {"sort_order", Int64.Type}})
in
    Typed

// ===== Query name: dim_year =====
let
    Source = Sql.Database(SqlServer, SqlDatabase),
    Data   = Source{[Schema = "mart", Item = "dim_year"]}[Data],
    Typed  = Table.TransformColumnTypes(Data, {
        {"fiscal_year_start", Int64.Type}, {"fiscal_year_label", type text}, {"is_latest", type logical}})
in
    Typed

// ===== Query name: fact_scorecard =====
let
    Source = Sql.Database(SqlServer, SqlDatabase),
    Data   = Source{[Schema = "mart", Item = "fact_scorecard"]}[Data],
    Typed  = Table.TransformColumnTypes(Data, {
        {"hospital_id", Int64.Type}, {"indicator_code", type text}, {"fiscal_year_start", Int64.Type},
        {"value", type number}, {"ci_lower", type number}, {"ci_upper", type number},
        {"diff_from_ontario", type number}, {"pct_diff_from_ontario", type number},
        {"flag", type text}, {"is_worse", Int64.Type}, {"is_better", Int64.Type}, {"is_suppressed", Int64.Type}})
in
    Typed

// ===== Query name: ontario_benchmark =====
let
    Source = Sql.Database(SqlServer, SqlDatabase),
    Data   = Source{[Schema = "mart", Item = "ontario_benchmark"]}[Data],
    Typed  = Table.TransformColumnTypes(Data, {
        {"indicator_code", type text}, {"fiscal_year_start", Int64.Type},
        {"ontario_value", type number}, {"ontario_ci_lower", type number}, {"ontario_ci_upper", type number}})
in
    Typed

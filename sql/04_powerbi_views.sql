/* 04_powerbi_views.sql
   Star schema views that Power BI imports (schema 'mart').
     dim_hospital, dim_indicator, dim_year     -> dimensions
     fact_scorecard                            -> one row per hospital x indicator x year, with flag
     ontario_benchmark                         -> one row per indicator x year
     fact_scorecard_export                     -> flat version for data/processed/scorecard.csv
   Run after 02_clean.sql and 03_analysis.sql (needs clean.v_scorecard_flags).
*/
USE OntarioScorecard;
GO

CREATE OR ALTER VIEW mart.dim_hospital AS
SELECT hospital_id, hospital_name, region, size_band,
       CASE size_band WHEN N'Large' THEN 1 WHEN N'Medium' THEN 2 ELSE 3 END AS size_band_sort
FROM clean.hospital;
GO

CREATE OR ALTER VIEW mart.dim_indicator AS
SELECT indicator_code, short_name, indicator_name, domain, metric, unit_label,
       has_ci, lower_is_better, sort_order
FROM clean.indicator;
GO

CREATE OR ALTER VIEW mart.dim_year AS
SELECT fiscal_year_start, fiscal_year_label, is_latest
FROM clean.fiscal_year;
GO

CREATE OR ALTER VIEW mart.fact_scorecard AS
SELECT
    hospital_id,
    indicator_code,
    fiscal_year_start,
    CAST(value    AS DECIMAL(9,2)) AS value,
    CAST(ci_lower AS DECIMAL(9,2)) AS ci_lower,
    CAST(ci_upper AS DECIMAL(9,2)) AS ci_upper,
    CAST(diff_from_ontario AS DECIMAL(9,2)) AS diff_from_ontario,
    pct_diff_from_ontario,
    flag,
    CASE WHEN flag = 'Worse'  THEN 1 ELSE 0 END AS is_worse,
    CASE WHEN flag = 'Better' THEN 1 ELSE 0 END AS is_better,
    CAST(is_suppressed AS INT)                  AS is_suppressed
FROM clean.v_scorecard_flags;
GO

CREATE OR ALTER VIEW mart.ontario_benchmark AS
SELECT indicator_code, fiscal_year_start,
       CAST(ontario_value    AS DECIMAL(9,2)) AS ontario_value,
       CAST(ontario_ci_lower AS DECIMAL(9,2)) AS ontario_ci_lower,
       CAST(ontario_ci_upper AS DECIMAL(9,2)) AS ontario_ci_upper
FROM clean.ontario_value;
GO

CREATE OR ALTER VIEW mart.fact_scorecard_export AS
SELECT
    h.hospital_name, h.region, h.size_band,
    f.indicator_code, i.short_name AS indicator, i.unit_label AS unit,
    y.fiscal_year_label AS fiscal_year,
    f.value, f.ci_lower, f.ci_upper, f.ontario_value, f.diff_from_ontario,
    f.pct_diff_from_ontario, f.flag
FROM clean.v_scorecard_flags f
JOIN clean.hospital    h ON h.hospital_id       = f.hospital_id
JOIN clean.indicator   i ON i.indicator_code    = f.indicator_code
JOIN clean.fiscal_year y ON y.fiscal_year_start = f.fiscal_year_start;
GO

/* Checks */
SELECT 'dim_hospital' AS view_name, COUNT(*) AS rows FROM mart.dim_hospital          -- 65
UNION ALL SELECT 'dim_indicator',   COUNT(*) FROM mart.dim_indicator                -- 3
UNION ALL SELECT 'dim_year',        COUNT(*) FROM mart.dim_year                     -- 5
UNION ALL SELECT 'fact_scorecard',  COUNT(*) FROM mart.fact_scorecard               -- 975
UNION ALL SELECT 'ontario_benchmark', COUNT(*) FROM mart.ontario_benchmark          -- 15
UNION ALL SELECT 'fact_scorecard_export', COUNT(*) FROM mart.fact_scorecard_export; -- 975

/* 01_load.sql
   Step 1: load the CIHI CSV into raw.cihi_indicator (all NVARCHAR, no changes).
   Step 2: copy into stg.cihi_indicator with proper types. No rows removed.

   Requires SQL Server 2017+ (BULK INSERT ... FORMAT = 'CSV').
   The path is read by the SQL Server service, not SSMS. Put the file somewhere the
   service can read, e.g. C:\data\cihi_ontario_5_indicators.csv.
   If BULK INSERT is blocked, use SSMS > Tasks > Import Flat File into raw.cihi_indicator
   (all columns nvarchar) and run from Step 2.
*/
USE OntarioScorecard;
GO

/* ---------- Step 1: raw ---------- */
DROP TABLE IF EXISTS raw.cihi_indicator;
CREATE TABLE raw.cihi_indicator (
    place_or_organization NVARCHAR(200),
    province_territory    NVARCHAR(100),
    region                NVARCHAR(200),
    reporting_level       NVARCHAR(100),
    indicator             NVARCHAR(200),
    measure_type          NVARCHAR(100),
    indicator_segment     NVARCHAR(200),
    segment_value         NVARCHAR(200),
    time_scale            NVARCHAR(50),
    time_frame            NVARCHAR(50),
    metric                NVARCHAR(100),
    main_metric           NVARCHAR(10),
    metric_value          NVARCHAR(50),
    unit_of_measure       NVARCHAR(100),
    ci_lower              NVARCHAR(50),
    ci_upper              NVARCHAR(50),
    refresh_date          NVARCHAR(50)
);

DECLARE @path NVARCHAR(400) = N'C:\Farhana\scorecard-project\data\raw\cihi_ontario_5_indicators.csv';  -- <-- change me
DECLARE @sql  NVARCHAR(MAX) = N'
BULK INSERT raw.cihi_indicator
FROM ''' + @path + N'''
WITH (
    FORMAT          = ''CSV'',      -- handles "4,629.7" quoted values
    FIRSTROW        = 2,            -- skip header
    FIELDQUOTE      = ''"'',
    FIELDTERMINATOR = '','',
    ROWTERMINATOR   = ''0x0a'',     -- file uses LF
    CODEPAGE        = ''65001'',    -- UTF-8 (keeps the en dash in 2025–2026)
    TABLOCK
);';
EXEC sys.sp_executesql @sql;

-- Expect 6,836
SELECT COUNT(*) AS raw_rows FROM raw.cihi_indicator;
GO

/* ---------- Step 2: staging (typed, nothing filtered) ---------- */
DROP TABLE IF EXISTS stg.cihi_indicator;
SELECT
    LTRIM(RTRIM(place_or_organization))                       AS place_or_organization,
    province_territory,
    region,
    reporting_level,
    indicator,
    metric,
    CASE main_metric WHEN N'Yes' THEN 1 ELSE 0 END             AS is_main_metric,
    time_frame,                                                -- e.g. 2025–2026
    TRY_CAST(LEFT(time_frame, 4) AS INT)                       AS fiscal_year_start,
    metric_value                                               AS metric_value_text,
    TRY_CONVERT(DECIMAL(12,3), REPLACE(metric_value, N',', N'')) AS metric_value,
    CASE WHEN metric_value = N'Suppressed' THEN 1 ELSE 0 END   AS is_suppressed,
    unit_of_measure,
    TRY_CONVERT(DECIMAL(12,3), REPLACE(ci_lower, N',', N''))   AS ci_lower,
    TRY_CONVERT(DECIMAL(12,3), REPLACE(ci_upper, N',', N''))   AS ci_upper,
    TRY_CONVERT(DATE, REPLACE(refresh_date, CHAR(13), N''), 23) AS refresh_date
INTO stg.cihi_indicator
FROM raw.cihi_indicator;
GO

/* ---------- Checks ---------- */
-- 1. Same row count as raw (6,836)
SELECT COUNT(*) AS stg_rows FROM stg.cihi_indicator;

-- 2. Values that did not convert and are not 'Suppressed'.
--    Expect one row: '-' (not reported), 231 rows, all on non-main metrics.
SELECT metric_value_text, COUNT(*) AS n, SUM(is_main_metric) AS on_main_metric
FROM stg.cihi_indicator
WHERE metric_value IS NULL AND is_suppressed = 0 AND metric_value_text IS NOT NULL AND metric_value_text <> N''
GROUP BY metric_value_text;

-- 3. Years parsed (expect 2014..2025, no NULL)
SELECT fiscal_year_start, COUNT(*) AS n FROM stg.cihi_indicator GROUP BY fiscal_year_start ORDER BY 1;

-- 4. En dash survived (expect '2025–2026', not '2025â€“2026'; if garbled, CODEPAGE was ignored)
SELECT TOP (1) time_frame FROM stg.cihi_indicator WHERE fiscal_year_start = 2025;

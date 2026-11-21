/* 02_clean.sql
   Builds the tidy scorecard tables from stg.cihi_indicator.

   Decisions (each one is logged in docs/cleaning-log.md):
     1. Keep Ontario, Reporting level = Corporation (hospitals) or Province/territory (benchmark).
     2. Keep 3 indicators: 30-day readmission, total ED time for admitted patients, in-hospital sepsis.
     3. Keep Main metric = Yes (the published rate / percentile; drops 'Expected' counts).
     4. Keep fiscal years 2021–22 to 2025–26 (the years all 3 indicators share).
     5. Drop Centre for Addiction and Mental Health: specialty mental health hospital,
        reports only ED time, not comparable to acute care hospitals.
     6. Keep suppressed values as rows with value = NULL and is_suppressed = 1.
     7. Size band (Large / Medium / Small) = terciles of expected readmissions in 2025–26.
        This is a volume proxy, NOT CIHI's official hospital peer group.
   Safe to re-run.
*/
USE OntarioScorecard;
GO

DROP VIEW  IF EXISTS mart.fact_scorecard_export, mart.fact_scorecard, mart.dim_hospital, mart.dim_indicator, mart.dim_year, mart.ontario_benchmark;
DROP VIEW  IF EXISTS clean.v_scorecard_flags;
DROP TABLE IF EXISTS clean.scorecard_fact, clean.ontario_value, clean.hospital, clean.indicator, clean.fiscal_year;
GO

/* ---------- Reference: indicators ---------- */
CREATE TABLE clean.indicator (
    indicator_code  VARCHAR(10)   NOT NULL PRIMARY KEY,
    indicator_name  NVARCHAR(200) NOT NULL,   -- exact CIHI name, used for joining
    short_name      NVARCHAR(60)  NOT NULL,
    domain          NVARCHAR(30)  NOT NULL,
    metric          NVARCHAR(60)  NOT NULL,
    unit_label      NVARCHAR(40)  NOT NULL,
    has_ci          BIT           NOT NULL,
    lower_is_better BIT           NOT NULL,
    sort_order      TINYINT       NOT NULL
);
INSERT INTO clean.indicator VALUES
 ('READMIT', N'All Patients Readmitted to Hospital',                            N'30-day readmission',        N'Outcomes',       N'Risk-adjusted rate', N'per 100 patients',     1, 1, 1),
 ('ED90',    N'Total Time Spent in Emergency Department for Admitted Patients', N'ED time, admitted patients', N'Access',         N'90th percentile',    N'hours',                0, 1, 2),
 ('SEPSIS',  N'In-Hospital Sepsis',                                             N'In-hospital sepsis',        N'Patient safety', N'Risk-adjusted rate', N'per 1,000 discharges', 1, 1, 3);

/* ---------- Reference: fiscal years ---------- */
CREATE TABLE clean.fiscal_year (
    fiscal_year_start INT         NOT NULL PRIMARY KEY,   -- 2025 = April 2025 to March 2026
    fiscal_year_label VARCHAR(7)  NOT NULL,               -- '2025-26'
    is_latest         BIT         NOT NULL
);
INSERT INTO clean.fiscal_year (fiscal_year_start, fiscal_year_label, is_latest)
SELECT y, CONCAT(y, '-', RIGHT(y + 1, 2)), CASE WHEN y = 2025 THEN 1 ELSE 0 END
FROM (VALUES (2021),(2022),(2023),(2024),(2025)) v(y);

/* ---------- Hospitals (corporations) ---------- */
;WITH corp AS (
    SELECT DISTINCT s.place_or_organization, s.region
    FROM stg.cihi_indicator s
    JOIN clean.indicator i ON i.indicator_name = s.indicator
    WHERE s.province_territory = N'Ontario'
      AND s.reporting_level    = N'Corporation'
      AND s.place_or_organization NOT LIKE N'Centre for Addiction%'     -- decision 5
),
volume AS (   -- expected readmissions, latest year = size proxy
    SELECT s.place_or_organization, s.metric_value AS expected_readmissions
    FROM stg.cihi_indicator s
    WHERE s.reporting_level = N'Corporation'
      AND s.indicator = N'All Patients Readmitted to Hospital'
      AND s.metric = N'Expected'
      AND s.fiscal_year_start = 2025
)
SELECT
    ROW_NUMBER() OVER (ORDER BY c.place_or_organization)                       AS hospital_id,
    c.place_or_organization                                                    AS cihi_name,
    REPLACE(c.place_or_organization, N' (Ont.)', N'')                          AS hospital_name,
    REPLACE(c.region, N' Region (Ont.)', N'')                                  AS region,
    v.expected_readmissions,
    CASE NTILE(3) OVER (ORDER BY v.expected_readmissions DESC)
         WHEN 1 THEN N'Large' WHEN 2 THEN N'Medium' ELSE N'Small' END          AS size_band
INTO clean.hospital
FROM corp c
LEFT JOIN volume v ON v.place_or_organization = c.place_or_organization;

ALTER TABLE clean.hospital ALTER COLUMN hospital_id BIGINT NOT NULL;
ALTER TABLE clean.hospital ADD CONSTRAINT PK_clean_hospital PRIMARY KEY (hospital_id);
GO

/* ---------- Fact: one row per hospital x indicator x year ---------- */
SELECT
    h.hospital_id,
    i.indicator_code,
    y.fiscal_year_start,              -- from the NOT NULL reference table so the PK works
    s.metric_value      AS value,
    s.ci_lower,
    s.ci_upper,
    s.is_suppressed,
    s.refresh_date
INTO clean.scorecard_fact
FROM stg.cihi_indicator s
JOIN clean.indicator   i ON i.indicator_name     = s.indicator
JOIN clean.hospital    h ON h.cihi_name          = s.place_or_organization
JOIN clean.fiscal_year y ON y.fiscal_year_start  = s.fiscal_year_start
WHERE s.province_territory = N'Ontario'
  AND s.reporting_level    = N'Corporation'
  AND s.is_main_metric     = 1;

ALTER TABLE clean.scorecard_fact ADD CONSTRAINT PK_clean_scorecard_fact
    PRIMARY KEY (hospital_id, indicator_code, fiscal_year_start);   -- fails loudly if duplicates exist

/* ---------- Ontario benchmark: one row per indicator x year ---------- */
SELECT
    i.indicator_code,
    y.fiscal_year_start,
    s.metric_value AS ontario_value,
    s.ci_lower     AS ontario_ci_lower,
    s.ci_upper     AS ontario_ci_upper
INTO clean.ontario_value
FROM stg.cihi_indicator s
JOIN clean.indicator   i ON i.indicator_name    = s.indicator
JOIN clean.fiscal_year y ON y.fiscal_year_start = s.fiscal_year_start
WHERE s.reporting_level       = N'Province/territory'
  AND s.place_or_organization = N'Ontario'
  AND s.is_main_metric        = 1;

ALTER TABLE clean.ontario_value ADD CONSTRAINT PK_clean_ontario_value
    PRIMARY KEY (indicator_code, fiscal_year_start);
GO

/* ---------- Checks (expected values from the 2026-08/09 CIHI refresh) ---------- */
SELECT COUNT(*) AS hospitals FROM clean.hospital;                        -- 65
SELECT size_band, COUNT(*) AS n FROM clean.hospital GROUP BY size_band;  -- 22 / 22 / 21
SELECT COUNT(*) AS fact_rows,                                            -- 975
       SUM(CAST(is_suppressed AS INT)) AS suppressed                     -- 4
FROM clean.scorecard_fact;
SELECT indicator_code, COUNT(*) AS n FROM clean.scorecard_fact GROUP BY indicator_code;  -- 325 each
SELECT COUNT(*) AS ontario_rows FROM clean.ontario_value;                -- 15
-- Hospitals missing an indicator-year (expect 0 rows)
SELECT h.hospital_name, i.indicator_code, y.fiscal_year_start
FROM clean.hospital h CROSS JOIN clean.indicator i CROSS JOIN clean.fiscal_year y
WHERE NOT EXISTS (SELECT 1 FROM clean.scorecard_fact f
                  WHERE f.hospital_id = h.hospital_id AND f.indicator_code = i.indicator_code
                    AND f.fiscal_year_start = y.fiscal_year_start);

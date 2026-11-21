/* 03_analysis.sql
   Part A: clean.v_scorecard_flags, the flag logic every later step (and Power BI) reuses.
   Part B: the analysis queries behind the findings in docs/findings.md.

   Flag rules (lower is better on all 3 indicators):
     Readmission, sepsis (have a 95% CI):
        Worse  = hospital CI lower limit > Ontario rate for the same year
        Better = hospital CI upper limit < Ontario rate
     ED time (no CI in the CIHI file):
        Worse  = above the 75th percentile of Ontario corporations that year (slowest quarter)
        Better = below the 25th percentile
     This ED rule is descriptive (relative position), not a statistical test or a CIHI method.
*/
USE OntarioScorecard;
GO

/* =========================== Part A: flag view =========================== */
CREATE OR ALTER VIEW clean.v_scorecard_flags AS
WITH ed_cut AS (
    SELECT DISTINCT
        fiscal_year_start,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY value) OVER (PARTITION BY fiscal_year_start) AS p25,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY value) OVER (PARTITION BY fiscal_year_start) AS p75
    FROM clean.scorecard_fact
    WHERE indicator_code = 'ED90' AND value IS NOT NULL
)
SELECT
    f.hospital_id,
    f.indicator_code,
    f.fiscal_year_start,
    f.value,
    f.ci_lower,
    f.ci_upper,
    f.is_suppressed,
    o.ontario_value,
    f.value - o.ontario_value                                          AS diff_from_ontario,
    CAST(100.0 * (f.value - o.ontario_value) / NULLIF(o.ontario_value, 0) AS DECIMAL(9,1)) AS pct_diff_from_ontario,
    CASE WHEN i.has_ci = 0 THEN e.p75 END                              AS ed_p75,
    CASE
        WHEN f.value IS NULL                                     THEN 'Suppressed'
        WHEN i.has_ci = 1 AND f.ci_lower > o.ontario_value       THEN 'Worse'
        WHEN i.has_ci = 1 AND f.ci_upper < o.ontario_value       THEN 'Better'
        WHEN i.has_ci = 0 AND f.value    > e.p75                 THEN 'Worse'
        WHEN i.has_ci = 0 AND f.value    < e.p25                 THEN 'Better'
        ELSE 'Similar'
    END                                                                AS flag
FROM clean.scorecard_fact f
JOIN clean.indicator     i ON i.indicator_code = f.indicator_code
JOIN clean.ontario_value o ON o.indicator_code = f.indicator_code
                          AND o.fiscal_year_start = f.fiscal_year_start
LEFT JOIN ed_cut         e ON e.fiscal_year_start = f.fiscal_year_start;
GO

/* =========================== Part B: analysis =========================== */
DECLARE @latest INT = (SELECT fiscal_year_start FROM clean.fiscal_year WHERE is_latest = 1);   -- 2025
DECLARE @first  INT = (SELECT MIN(fiscal_year_start) FROM clean.fiscal_year);                  -- 2021

/* Q1. Ontario benchmark by year (context for every other result) */
SELECT y.fiscal_year_label, o.indicator_code, o.ontario_value, o.ontario_ci_lower, o.ontario_ci_upper
FROM clean.ontario_value o
JOIN clean.fiscal_year y ON y.fiscal_year_start = o.fiscal_year_start
ORDER BY o.indicator_code, o.fiscal_year_start;

/* Q2. Current snapshot: one row per hospital, latest year, all 3 indicators */
SELECT
    h.hospital_name, h.region, h.size_band,
    MAX(CASE WHEN v.indicator_code = 'READMIT' THEN v.value END) AS readmit_per_100,
    MAX(CASE WHEN v.indicator_code = 'READMIT' THEN v.flag  END) AS readmit_flag,
    MAX(CASE WHEN v.indicator_code = 'ED90'    THEN v.value END) AS ed_hours_p90,
    MAX(CASE WHEN v.indicator_code = 'ED90'    THEN v.flag  END) AS ed_flag,
    MAX(CASE WHEN v.indicator_code = 'SEPSIS'  THEN v.value END) AS sepsis_per_1000,
    MAX(CASE WHEN v.indicator_code = 'SEPSIS'  THEN v.flag  END) AS sepsis_flag,
    SUM(CASE WHEN v.flag = 'Worse' THEN 1 ELSE 0 END)            AS worse_flags
FROM clean.v_scorecard_flags v
JOIN clean.hospital h ON h.hospital_id = v.hospital_id
WHERE v.fiscal_year_start = @latest
GROUP BY h.hospital_name, h.region, h.size_band
ORDER BY worse_flags DESC, h.hospital_name;

/* Q3. Flag counts per indicator, latest year */
SELECT
    v.indicator_code,
    SUM(CASE WHEN v.flag = 'Worse'      THEN 1 ELSE 0 END) AS worse,
    SUM(CASE WHEN v.flag = 'Similar'    THEN 1 ELSE 0 END) AS similar,
    SUM(CASE WHEN v.flag = 'Better'     THEN 1 ELSE 0 END) AS better,
    SUM(CASE WHEN v.flag = 'Suppressed' THEN 1 ELSE 0 END) AS suppressed
FROM clean.v_scorecard_flags v
WHERE v.fiscal_year_start = @latest
GROUP BY v.indicator_code;

/* Q4. Headline: hospitals worse than Ontario on 2+ indicators, latest year */
WITH n AS (
    SELECT hospital_id,
           SUM(CASE WHEN flag = 'Worse' THEN 1 ELSE 0 END) AS worse_flags,
           STRING_AGG(CASE WHEN flag = 'Worse' THEN indicator_code END, ', ')
               WITHIN GROUP (ORDER BY indicator_code) AS flagged_on
    FROM clean.v_scorecard_flags
    WHERE fiscal_year_start = @latest
    GROUP BY hospital_id
)
SELECT h.hospital_name, h.region, h.size_band, n.worse_flags, n.flagged_on
FROM n JOIN clean.hospital h ON h.hospital_id = n.hospital_id
WHERE n.worse_flags >= 2
ORDER BY n.worse_flags DESC, h.hospital_name;

-- ...and how many hospitals have at least one / two / three
SELECT worse_flags, COUNT(*) AS hospitals
FROM (SELECT hospital_id, SUM(CASE WHEN flag = 'Worse' THEN 1 ELSE 0 END) AS worse_flags
      FROM clean.v_scorecard_flags WHERE fiscal_year_start = @latest GROUP BY hospital_id) t
GROUP BY worse_flags ORDER BY worse_flags;

/* Q5. Size band comparison: median by band vs Ontario, and share flagged worse */
SELECT DISTINCT
    v.indicator_code, h.size_band,
    CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY v.value)
        OVER (PARTITION BY v.indicator_code, h.size_band) AS DECIMAL(9,2))      AS band_median,
    v.ontario_value,
    SUM(CASE WHEN v.flag = 'Worse' THEN 1 ELSE 0 END)
        OVER (PARTITION BY v.indicator_code, h.size_band)                       AS worse_count,
    COUNT(*) OVER (PARTITION BY v.indicator_code, h.size_band)                  AS hospitals
FROM clean.v_scorecard_flags v
JOIN clean.hospital h ON h.hospital_id = v.hospital_id
WHERE v.fiscal_year_start = @latest
ORDER BY v.indicator_code, h.size_band;

/* Q6. Persistent problems: worse than Ontario in 3+ of the 5 years, per indicator */
SELECT h.hospital_name, h.size_band, v.indicator_code,
       SUM(CASE WHEN v.flag = 'Worse' THEN 1 ELSE 0 END) AS years_worse
FROM clean.v_scorecard_flags v
JOIN clean.hospital h ON h.hospital_id = v.hospital_id
GROUP BY h.hospital_name, h.size_band, v.indicator_code
HAVING SUM(CASE WHEN v.flag = 'Worse' THEN 1 ELSE 0 END) >= 3
ORDER BY v.indicator_code, years_worse DESC, h.hospital_name;

/* Q7. Trend: change from first to latest year per hospital and indicator.
       'Real change' for CI indicators = the two years' CIs do not overlap. */
WITH t AS (
    SELECT
        a.hospital_id, a.indicator_code,
        a.value AS first_value, b.value AS latest_value,
        b.value - a.value AS change,
        CAST(100.0 * (b.value - a.value) / NULLIF(a.value, 0) AS DECIMAL(9,1)) AS pct_change,
        CASE WHEN a.ci_lower IS NULL OR b.ci_lower IS NULL THEN NULL
             WHEN b.ci_upper < a.ci_lower THEN 'Improved'
             WHEN b.ci_lower > a.ci_upper THEN 'Worsened'
             ELSE 'No clear change' END AS ci_change
    FROM clean.scorecard_fact a
    JOIN clean.scorecard_fact b
      ON b.hospital_id = a.hospital_id AND b.indicator_code = a.indicator_code
     AND a.fiscal_year_start = @first AND b.fiscal_year_start = @latest
    WHERE a.value IS NOT NULL AND b.value IS NOT NULL
),
ranked AS (
    SELECT t.*,
           -- rank on change in the indicator's own units, not %: small hospitals with
           -- near-zero rates swing by hundreds of percent on a handful of cases
           ROW_NUMBER() OVER (PARTITION BY indicator_code ORDER BY change ASC,  hospital_id) AS rank_improved,
           ROW_NUMBER() OVER (PARTITION BY indicator_code ORDER BY change DESC, hospital_id) AS rank_worsened
    FROM t
)
SELECT r.indicator_code, h.hospital_name, h.size_band, r.first_value, r.latest_value, r.change, r.pct_change, r.ci_change,
       CASE WHEN r.rank_improved <= 5 THEN 'Top 5 improved' ELSE 'Top 5 worsened' END AS list
FROM ranked r JOIN clean.hospital h ON h.hospital_id = r.hospital_id
WHERE r.rank_improved <= 5 OR r.rank_worsened <= 5
ORDER BY r.indicator_code, list, r.change;

-- Count of real (CI-based) changes per indicator
SELECT a.indicator_code,
       SUM(CASE WHEN b.ci_upper < a.ci_lower THEN 1 ELSE 0 END) AS improved,
       SUM(CASE WHEN b.ci_lower > a.ci_upper THEN 1 ELSE 0 END) AS worsened,
       COUNT(*) AS hospitals_compared
FROM clean.scorecard_fact a
JOIN clean.scorecard_fact b
  ON b.hospital_id = a.hospital_id AND b.indicator_code = a.indicator_code
 AND a.fiscal_year_start = @first AND b.fiscal_year_start = @latest
WHERE a.ci_lower IS NOT NULL AND b.ci_lower IS NOT NULL
GROUP BY a.indicator_code;

/* Q8. Relationship check: ED time vs readmission, latest year (Pearson r).
       Association only; it does not show that one causes the other. */
WITH p AS (
    SELECT e.value AS x, r.value AS y
    FROM clean.scorecard_fact e
    JOIN clean.scorecard_fact r
      ON r.hospital_id = e.hospital_id AND r.fiscal_year_start = e.fiscal_year_start
    WHERE e.indicator_code = 'ED90' AND r.indicator_code = 'READMIT'
      AND e.fiscal_year_start = @latest AND e.value IS NOT NULL AND r.value IS NOT NULL
)
SELECT COUNT(*) AS n,
       CAST((COUNT(*) * SUM(x*y) - SUM(x) * SUM(y)) /
            (SQRT(COUNT(*) * SUM(x*x) - SQUARE(SUM(x))) * SQRT(COUNT(*) * SUM(y*y) - SQUARE(SUM(y))))
            AS DECIMAL(5,3)) AS pearson_r
FROM (SELECT CAST(x AS FLOAT) AS x, CAST(y AS FLOAT) AS y FROM p) q;

/* Q9. Tidy export -> data/processed/scorecard.csv
   From a Windows command prompt (one line):
   bcp "SELECT * FROM OntarioScorecard.mart.fact_scorecard_export ORDER BY hospital_name, indicator_code, fiscal_year" queryout data\processed\scorecard.csv -c -t, -T -S localhost
   (Run 04_powerbi_views.sql first; it creates mart.fact_scorecard_export.)
*/

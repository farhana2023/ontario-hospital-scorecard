# Data dictionary: `data/processed/scorecard.csv`

One row per hospital corporation × indicator × fiscal year. 65 hospitals × 3 indicators × 5 years = 975 rows.
Built by `mart.fact_scorecard_export` (`sql/04_powerbi_views.sql`).

| Column | Type | Description |
|---|---|---|
| hospital_name | text | CIHI corporation name without ` (Ont.)` |
| region | text | Ontario Health region (Central, East, North East, North West, Toronto, West) |
| size_band | text | Large / Medium / Small: terciles of expected readmissions in 2025–26. Volume proxy, not CIHI peer group |
| indicator_code | text | `READMIT`, `ED90`, `SEPSIS` |
| indicator | text | Short indicator name |
| unit | text | `per 100 patients`, `hours`, `per 1,000 discharges` |
| fiscal_year | text | `2025-26` = April 1, 2025 to March 31, 2026 |
| value | decimal | CIHI published value: risk-adjusted rate (READMIT, SEPSIS) or 90th percentile hours (ED90). Blank = suppressed by CIHI |
| ci_lower, ci_upper | decimal | CIHI 95% confidence interval. Blank for ED90 (not published) |
| ontario_value | decimal | Ontario provincial value, same indicator and year |
| diff_from_ontario | decimal | value − ontario_value (positive = worse; lower is better on all 3) |
| pct_diff_from_ontario | decimal | diff as % of ontario_value |
| flag | text | `Worse` / `Similar` / `Better` / `Suppressed`. READMIT, SEPSIS: whole CI above (below) the Ontario value. ED90: above the 75th (below the 25th) percentile of Ontario corporations that year |

## Indicators
| Code | CIHI indicator | Metric | Domain |
|---|---|---|---|
| READMIT | All Patients Readmitted to Hospital | Risk-adjusted 30-day rate per 100 | Outcomes |
| ED90 | Total Time Spent in Emergency Department for Admitted Patients | 90th percentile, hours | Access |
| SEPSIS | In-Hospital Sepsis | Risk-adjusted rate per 1,000 discharges | Patient safety |

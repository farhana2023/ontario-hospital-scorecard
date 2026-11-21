# Cleaning log

Every step that changes the data, in order, with row counts. Counts are from the CIHI refresh
of 2026-08-25 to 2026-09-21 and are re-checked by the queries at the bottom of each SQL script.

| # | Step | Script | Rows after | Why |
|---|---|---|---|---|
| 0 | Raw CIHI export, Ontario, 5 indicators, all levels and metrics | `data/raw` | 6,836 | Starting point |
| 1 | Load as text into `raw.cihi_indicator` | `01_load.sql` | 6,836 | Load first, judge later; nothing lost on type errors |
| 2 | Type conversion into `stg.cihi_indicator`: strip thousands commas from `Metric value` and CI limits, parse fiscal year start from `2025–2026`, `Suppressed` → NULL + `is_suppressed = 1` | `01_load.sql` | 6,836 | `Metric value` is text (`"4,629.7"`). 231 values are `-` (not reported); all are on non-main metrics and are dropped in step 4 |
| 3 | Keep Reporting level = Corporation (hospitals) and Province/territory = Ontario (benchmark) | `02_clean.sql` | — | Corporations are the level all 3 indicators share. Facility level is incomplete for ED time |
| 4 | Keep Main metric = Yes | `02_clean.sql` | — | Each indicator also has an `Expected` count row; the main metric is the published rate / percentile |
| 5 | Keep 3 indicators: All Patients Readmitted to Hospital, Total Time Spent in ED for Admitted Patients, In-Hospital Sepsis | `02_clean.sql` | — | One per domain: outcomes, access, safety. Hospital Harm is not in the file, so In-Hospital Sepsis is the safety measure |
| 6 | Keep fiscal years 2021–22 to 2025–26 | `02_clean.sql` | — | ED time starts in 2021–22; these are the years all 3 share |
| 7 | Drop Centre for Addiction and Mental Health | `02_clean.sql` | 975 hospital rows (65 × 3 × 5) + 15 Ontario rows | Specialty mental health hospital; reports only ED time, so it cannot be scored on 3 indicators and is not comparable to acute care |
| 8 | Keep 4 suppressed sepsis values as rows with NULL value | `02_clean.sql` | 975 | Dropping them would hide that the hospital exists; flag = `Suppressed`, excluded from counts and ranks |
| 9 | Clean names: drop ` (Ont.)` from hospital names and ` Region (Ont.)` from regions | `02_clean.sql` | 975 | Readability in the dashboard; original name kept in `clean.hospital.cihi_name` |
| 10 | Size band = terciles of expected readmissions in 2025–26 (Large 22, Medium 22, Small 21) | `02_clean.sql` | 975 | The file has no hospital-to-peer-group mapping. Expected readmissions is a volume proxy. It is **not** CIHI's peer group: e.g. Sinai Health (teaching) lands in Medium |

## Suppressed values kept as NULL
| Hospital | Indicator | Year |
|---|---|---|
| North Shore Health Network | Sepsis | 2021–22, 2025–26 |
| North of Superior Healthcare Group | Sepsis | 2024–25 |
| Weeneebayko Area Health Authority | Sepsis | 2024–25 |

## Integrity checks (all pass)
- Primary keys on `clean.scorecard_fact (hospital_id, indicator_code, fiscal_year_start)` and `clean.ontario_value`: no duplicates.
- Every hospital has every indicator for every year (cross-join check returns 0 rows).
- Results re-computed independently in Python/pandas from the raw CSV: same flag counts (16 / 11 / 8 worse) and same 2+ flag list (7 hospitals).

# Ontario hospital quality scorecard

Which Ontario hospital corporations perform worse than the province on readmission, emergency
department time and in-hospital sepsis, and how has that changed from 2021–22 to 2025–26?

**Tools:** SQL Server (T-SQL), Power BI (Power Query, DAX). **Data:** CIHI Indicator Library, public aggregate data.

![Scorecard page](powerbi/screenshots/page1-scorecard.png)

## Headline findings (2025–26)
- **7 of 65** hospital corporations are worse than Ontario on 2 or more of the 3 indicators; **27** on at least one. All 7 are teaching hospitals; The Ottawa Hospital is flagged on all 3.
- **Readmission is rising:** Ontario 9.5 → 10.2 per 100 since 2021–22; 11 hospitals clearly worse, none clearly better.
- **Sepsis is falling:** Ontario 5.3 → 3.7 per 1,000; 17 hospitals clearly improved.
- **ED time for admitted patients** peaked at 45.0 hours (90th percentile) in 2022–23 and is now 38.3. Five hospitals were in the slowest quarter every year.
- ED time and readmission are **not** related across hospitals (r = −0.09).

Full write-up and limitations: [docs/findings.md](docs/findings.md).

## Indicators
| Domain | CIHI indicator | Metric |
|---|---|---|
| Outcomes | All Patients Readmitted to Hospital | Risk-adjusted 30-day rate per 100 |
| Access | Total Time Spent in Emergency Department for Admitted Patients | 90th percentile, hours |
| Patient safety | In-Hospital Sepsis | Risk-adjusted rate per 1,000 discharges |

**Worse than Ontario** means: for readmission and sepsis, the hospital's whole 95% confidence interval
is above the Ontario rate; for ED time (no CI published), the hospital is in the slowest quarter of
Ontario corporations that year.

## Repository layout
```
data/raw/            CIHI export (git-ignored; see data/raw/README.md to re-download)
data/processed/      scorecard.csv: tidy output, one row per hospital x indicator x year
sql/                 00_setup → 01_load → 02_clean → 03_analysis → 04_powerbi_views (+ run_all.sql)
powerbi/             Power Query, DAX measures, theme, report layout, .pbix, screenshots
docs/                cleaning log, data dictionary, findings
```

## Pipeline
| Layer | Schema | Built by | Contents |
|---|---|---|---|
| Raw | `raw` | `01_load.sql` | CSV loaded as text (6,836 rows) |
| Staging | `stg` | `01_load.sql` | Same rows, typed: numbers, years, suppressed flag |
| Clean | `clean` | `02_clean.sql` | Hospitals, indicators, years, fact (975 rows), Ontario benchmark (15 rows) |
| Analysis | `clean` | `03_analysis.sql` | Flag view + 8 analysis queries |
| Mart | `mart` | `04_powerbi_views.sql` | Star schema views Power BI imports |

## Run it
Requires SQL Server 2017+ (Express or Developer is fine) and Power BI Desktop (Windows).
1. Download the CIHI file as described in `data/raw/README.md` and copy it to `C:\data\` (or edit the path at the top of `sql/01_load.sql`).
2. In SSMS run the scripts in `sql/` in number order (or `run_all.sql` in SQLCMD mode). Each script ends with checks and the expected counts.
3. Power BI Desktop: see [powerbi/README.md](powerbi/README.md).

## Limitations
- Public aggregate data: rates are CIHI's risk-adjusted values, not recalculated. The analysis shows where a hospital differs, not why.
- Teaching hospitals treat more complex patients; risk adjustment may not remove all of that.
- The ED flag is a relative rule, not a statistical test. Size bands are a volume proxy, not CIHI peer groups.
- The Centre for Addiction and Mental Health is excluded (specialty hospital, ED time only).

## Data source and disclaimer
Canadian Institute for Health Information, Indicator Library / Your Health System, data refreshed August–September 2026.
This is an independent portfolio project. It is not produced or endorsed by CIHI or any hospital.

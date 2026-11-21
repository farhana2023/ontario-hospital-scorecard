# Raw data

| File | Source | Rows |
|---|---|---|
| `cihi_ontario_5_indicators.csv` | CIHI Indicator Library export (Your Health System), refreshed 2026-08-25 to 2026-09-21 | 6,836 + header |

**How it was made:** full Indicator Library table exported from
https://yourhealthsystem.cihi.ca (interactive table → Download data), then filtered to
Province/territory = Ontario and these 5 indicators: All Patients Readmitted to Hospital,
In-Hospital Sepsis, Total Time Spent in Emergency Department for Admitted Patients,
Hospital Deaths (HSMR), Patient Days in Alternate Level of Care (Percentage).
All reporting levels and all metrics are kept; nothing else was changed.

**Format:** UTF-8, comma-separated, LF line endings, quoted fields. `Time frame` uses an
en dash (`2025–2026`). `Metric value` is text (`"4,629.7"`, `Suppressed`).

The CSV is git-ignored by default. Before committing it, check CIHI's terms of use for
redistribution; otherwise keep it out of the repo and point readers to the source.

# Power BI report

| File | What it is |
|---|---|
| `queries.pq` | Power Query (M) for the 2 parameters and 5 tables (all from the `mart` views) |
| `measures.dax` | Every measure, as one DAX query view script ("Update model: Add new measures") |
| `theme/scorecard-theme.json` | Colours and fonts (View > Themes > Browse for themes) |
| `ontario-hospital-scorecard.pbix` | The report (add after you save it in Power BI Desktop) |
| `screenshots/` | `target-preview.png` (the look to aim for) and `dashboard.png` (your own screenshot once built; copy it to the portfolio site as `images/scorecard.png`) |

A `.pbix` is a binary file that only Power BI Desktop can write, so the report itself is assembled
there from the files above. Assembly order: load queries (if you used Get Data > SQL Server, rename the
tables to drop the `mart ` prefix, since the DAX uses plain names) → set relationships (listed at the top of
`measures.dax`) → run `measures.dax` → apply theme → build the two pages below.

> **Ready-made project:** the finished dashboard is in `pbip/`. Open `pbip/ontario-hospital-scorecard.pbip` in Power BI
> Desktop (PBIP format, Desktop 2025+), update the file path in the `queries` (Power Query) if your CSV/SQL location differs,
> then Refresh. The steps below describe how it was built and how to recreate it by hand.
> Layout as built: 4 KPI cards (value, change vs previous year, sparkline), hospital table, 3 trend charts. The cards show the
> Ontario benchmark and do not change when a hospital is clicked; the table and trend charts do.

## One-page dashboard, v2 (1280 x 720)

Target look: `screenshots/target-preview.png` (drawn from the real data; Power BI will be very close,
except cell colours are rectangles, not rounded pills).

The background image draws the header, white panels, shadows, captions and legends. You only place
visuals on top. Delete the old Headline card; the "Hospitals flagged" KPI replaces it.

### Steps

1. **Re-run `measures.dax`** (adds `Flagged Sub Label`, `... Bg`, `Flags Color`).
2. **Theme:** View > Themes > Browse for themes > `theme/scorecard-theme.json`.
3. **Background:** click empty canvas > Format page > Canvas settings: 16:9. Canvas background: image
   `theme/dashboard-background.png`, Image fit = **Fit**, transparency **0%**. Wallpaper colour `#EEF2F7`.
4. **Position every visual** with Format visual > General > Properties (numbers below). Turn off each
   visual's own background, border and title (the theme already does this; check if one looks boxed).
5. **Edit interactions** (Format ribbon > Edit interactions): select the table, set every KPI card and
   sparkline to **None**. Trend charts stay **Filter**.

| # | Visual | Type | Fields | X | Y | W | H |
|---|---|---|---|---|---|---|---|
| 1 | Region slicer | Slicer (dropdown) | `region` | 800 | 16 | 220 | 32 |
| 2 | Size slicer | Slicer (dropdown) | `size_band` | 1030 | 16 | 220 | 32 |
| 3 | KPI flagged | Card (new) | `[Hospitals Flagged 2+]`, ref. label `[Flagged Sub Label]` | 26 | 112 | 160 | 72 |
| 4 | KPI readmission | Card (new) | `[Ontario Value]`, ref. label `[Ontario Change Label]` | 342 | 112 | 160 | 72 |
| 5 | KPI ED time | Card (new) | same as 4 | 658 | 112 | 160 | 72 |
| 6 | KPI sepsis | Card (new) | same as 4 | 974 | 112 | 160 | 72 |
| 7-10 | 4 sparklines | Area chart | X `fiscal_year_label`; Y same measure as the card next to it | 202 / 518 / 834 / 1150 | 118 | 100 | 66 |
| 11 | Hospital table | Table | `hospital_name`, `region`, `size_band`, `[Readmission]`, `[ED Hours]`, `[Sepsis]`, `[Total Worse Flags]` | 24 | 256 | 684 | 440 |
| 12-14 | 3 trend charts | Line chart | X `fiscal_year_label`; Y `[Hospital Line]`, `[Ontario Value]` | 740 | 232 / 400 / 568 | 516 | 130 |

**Filters (Filters pane > this visual):**
- Cards 3-6 and the table: `dim_year[is_latest]` = True.
- Cards 4-6, their sparklines and the trend charts: `dim_indicator[short_name]` = that indicator (readmission, ED, sepsis, left to right / top to bottom).
- Sparklines and trend charts: **no** `is_latest` filter, so all 5 years show.

**Formatting, per visual type:**
- **KPI cards:** Callout value Segoe UI Bold 28, colour `#0F2A44`, 1 decimal (flagged card: 0 decimals). Category label Off.
  Reference label: Title Off, Value font 10 bold; card 3 colour `#64748B`; cards 4-6 colour = fx > Field value `[Ontario Change Color]`.
- **Sparklines:** Lines > colour: flagged `#B42318`, readmission `#2563EB`, ED `#E08A00`, sepsis `#7C3AED`. Shade area transparency 80%.
- **Table:** rename columns (double-click the field): Hospital, Region, Size, Readmit, ED hrs, Sepsis, Flags. Sort by Flags descending.
  Cell elements > Readmit: Background colour fx > Field value `[Readmission Bg]`; Font colour fx > Field value `[Readmission Color]`.
  Same for ED hrs (`[ED Hours Bg]` / `[ED Hours Color]`) and Sepsis (`[Sepsis Bg]` / `[Sepsis Color]`). Flags: font colour `[Flags Color]`.
  Specific column > Readmit, ED hrs, Sepsis, Flags: Alignment Right; Values bold.
- **Trend charts:** Lines > `Hospital Line` colour = indicator colour (as above), width 3; `Ontario Value` colour `#94A3B8`, style **Dashed**, width 2, markers off.
  Readmission and sepsis only: Analytics > Error bars on `Hospital Line`, upper `[Hospital CI Upper]`, lower `[Hospital CI Lower]`, Error band On, bar Off, band colour = indicator colour at 85% transparency.
  Data labels: Series `Hospital Line` only, "Show for last point" if your version has it.

**Check:** click The Ottawa Hospital. Readmission ends 10.8 vs Ontario 10.2, ED 45.2 vs 38.3, sepsis 4.6 vs 3.7.
KPI cards should read 7, 10.2, 38.3, 3.7 and not change when you click a row.

There is no page-level filter: `is_latest` is applied per visual so the trend charts keep all years.
With no row clicked the trend charts show only the dashed Ontario line.

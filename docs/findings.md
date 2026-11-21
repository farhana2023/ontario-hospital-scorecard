# Findings (fiscal 2025–26 unless stated)

Source queries: `sql/03_analysis.sql` (Q-numbers below). Lower is better on all 3 indicators.

1. **7 of 65 hospital corporations are worse than Ontario on 2 or more indicators; 27 on at least one.** (Q4)
   The Ottawa Hospital is the only one flagged on all three. The other six are Hamilton Health Sciences,
   London Health Sciences Centre, Sinai Health, Sunnybrook, Unity Health Toronto and University Health Network.
   All seven are academic/teaching hospitals.
2. **Readmission is rising province-wide.** Ontario went from 9.5 to 10.2 per 100 (2021–22 to 2025–26), and
   11 hospitals got clearly worse (CIs do not overlap); none got clearly better. (Q1, Q7)
3. **Sepsis is falling province-wide.** Ontario went from 5.3 to 3.7 per 1,000; 17 hospitals clearly improved,
   1 clearly worsened (Georgian Bay General). (Q1, Q7)
4. **ED time for admitted patients peaked in 2022–23** (45.0 hours at the 90th percentile) and is down to 38.3.
   Five hospitals were in the slowest quarter every year: Lakeridge, Niagara, Peterborough Regional,
   Trillium and William Osler. (Q1, Q6)
5. **Flags concentrate in large hospitals.** Large band: 7 of 22 worse on readmission, 6 on sepsis; small band:
   2 and 0. Small hospitals have wide CIs, so a flag there is harder to earn. (Q5)
6. **No meaningful link between ED time and readmission across hospitals** (Pearson r = −0.09, n = 65). (Q8)

## Limitations
- CIHI risk-adjusts the rates, but teaching hospitals still treat more complex patients. A flag says where to look, not why.
- The ED flag is relative (slowest quarter), so about 16 hospitals are flagged every year by design. It is not a statistical test.
- Size band is a volume proxy, not CIHI's peer groups.
- Aggregate public data; no patient-level analysis or recalculation of rates.

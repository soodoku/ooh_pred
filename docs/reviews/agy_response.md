# Response to the agy audit

The completed output is preserved verbatim in `agy_review.txt`, including its
progress messages. The final report begins at its independent-audit heading.
The reviewer executed R checks, verified source hashes, ran 67 assertions and the
linter, and judged the manuscript ready after synchronization and clarification.

1. **Rendered outputs lagging active edits.** Confirmed: the review overlapped
   the implementation of Claude's follow-up repairs. The PDF and HTML had not yet
   been regenerated for those in-progress changes. Re-rendered both from the
   final source and generated tables, then checked the pages and embedded tables.
2. **Interval-method wording.** The reviewer caught the transitional state
   between implementing exact classification-rate intervals and updating their
   description. Confirmed the final methods and Table 3 caption distinguish
   percentile-bootstrap AUC/Brier intervals from exact binomial rate intervals.
   The older degenerate-interval wording is removed.
3. **Missingness indicators.** Directly verified that the two race-missingness
   indicators are identical in development and test, and that no field has
   missingness only in the actual primary test set. Identical columns are allowed
   by the penalized model; no prediction defect was demonstrated, and separate
   missingness coefficients are not substantively interpreted. Defining a new
   indicator from test-only missingness would violate training-only preprocessing;
   an indicator constant in training cannot have an estimated effect. The current
   code correctly imputes such test values using the training median. Added a
   regression test verifying the fixed schema and imputed value for this edge case.

## Numerical qualifications to the external report

The report is preserved as received, but its incidental numbers are not adopted
without checking. The current analytic cohort has **1,205**, not 1,218, missing or
declined race values. The generated total of valid pre-origin CYBER rows discarded
by the historical filter is **549,596**; the report's reference to 500,455 October–
December rows is not the total used by the audit. The local verification output is
`agy_verification.txt`. Neither qualification changes the manuscript, whose
numbers already come from the verified generated outputs.

The report's nine-item disposition is consistent with the implemented repairs and
explicit remaining data limitations. No additional headline-estimate correction
was demonstrated. Final build and visual checks are documented in
`../verification.md`.

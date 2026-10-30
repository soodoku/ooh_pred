# Rolling forecast extension

Retrospective design recorded before fitting the new models. Existing source
summaries and the fixed-origin results have already been inspected. This is an
exploratory extension, not a preregistered analysis.

Question: among members of the supplied cohort with a recent available CANS
assessment, can an earlier model predict a recorded admission start for different
youth at a later date? The outcome is any recorded start, including a subsequent
start; it is not discharge-indexed readmission or first-ever placement.

Timing uses three distinct quantities: a 365-day lookback ending immediately
before an information cutoff; a 30-day lead gap after that cutoff; and a 180-day
outcome window beginning after the gap. Quarterly target starts run from January
2015 through April 2016. Alternatives change one quantity at a time: 180-day
lookback, zero-day gap, 90-day outcome, 365-day outcome. Retain only windows ending
by November 3, 2016 and training histories beginning no earlier than the first
medication creation date (November 14, 2012). Do not pick a setting by test results.

For each target start T, cutoff C = T - gap. Use one earlier training landmark U =
C - 30 - horizon; its outcome interval [U, U + horizon) ends 30 days before C.
Training features use their own cutoff U - gap and the same lookback. Training
labels use only admission starts entered before C. This extra 30 days allows some
recording delay but cannot establish complete reporting. Test labels use the
archived admission starts. The incomplete completed-placement extract remains a
limitation, including missing ongoing stays and possibly delayed records.

Make a fresh seed-fixed 80/20 split of all member IDs without using outcomes.
Keep members on the same side at every date. Training uses earlier snapshots of
development youth, and evaluation uses later snapshots of held-out youth.
Each fitted model has one row per training youth, so ordinary stratified five-fold
internal tuning has no repeated-person leakage. All imputation, missingness
indicators and record vocabulary selection occur within each internal training
fold using the existing audited lasso functions. No test youth enter training or
tuning. Use rsample for the person split and the rolling date indices.

Eligibility requires at least one CANS assessment finished in the lookback with
finish, creation and submission before the cutoff. Features are CANS domain means,
assessment count, demographics with age at the cutoff, recent diagnosis,
medication and eligibility entries, and prior admission starts known by the cutoff.
Recent records use creation date (eligibility uses start date, whose entry date is
unknown). Prior starts are counted only within the lookback and only if created
before the cutoff. An admission during the lead gap does not enter predictors or
the target. We do not remove youth based on events after the cutoff, nor restrict
the sample to those later known to have remained out of care.

Report held-out events, denominators, ROC AUC, PR-AUC, prevalence, Brier score,
mean predicted risk, and the training-prevalence Brier benchmark at each date.
Person-level conditional bootstrap intervals are computed within each date.
Do not pool overlapping dates into an independent sample or select a favorable
calendar period. Describe temporal transport and cohort changes separately from
sampling uncertainty. The existing fixed-origin analysis remains intact pending
the author's preference about which question should lead the report.

Additional descriptive exhibits use the fixed-origin cohort, not model residuals:
placement frequency by CANS score bands, recent documented placement history,
assessment frequency, and common medication records. Display denominators and
missing categories. Select medications by development-set prevalence, not by
association with outcomes. Do not infer effects of medications or CANS domains.

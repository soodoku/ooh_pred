# Analysis audit

The archive supports a reproducible analysis of recorded behavioral health
placements in a selected historical cohort. It does not establish a prospective
population sample, complete placement ascertainment, or clinical post-discharge
readmission risk. The corrected pipeline computes all reported results locally.

## Claim ledger

| Claim | Unit, population, and target | Source and calculation | Interpretation and uncertainty |
|---|---|---|---|
| Placement prediction | One youth with pre-origin CANS in the supplied selected cohort; any recorded start within the stated window | `prepare.R`, `build_outcomes()`, held-out logistic lasso in `estimate.R` | Within-cohort predictive discrimination; conditional test-person bootstrap, not prospective transport |
| Multiple-placement prediction | Same youth; at least two distinct recorded start dates in the window | Same admission source and split | A repeated-start endpoint, not a discharge-indexed readmission probability |
| Occupied-day prediction | Youth with usable durations; union of recorded intervals intersecting the window | `union_days()`, clipped intervals, Gaussian lasso, training-mean squared-loss baseline | Recorded occupancy including carryover; not eventual stay length or complete utilization |
| CANS differences | Equally weighted youth-level means of pre-origin assessment averages | `summarize_cans()`, `tabs/descriptive.csv` | Descriptive association in the selected cohort; special-code rule documented; no causal or population inference |
| Original model accuracy | Original CANS cohort; binary outcomes from historical code | `scripts/audit.R`, `tabs/audit_counts.csv` | No-event baselines match rounded headline accuracy; archived fitting code is resubstitution |

For each headline, the substantive quantity and purpose are given above. The
reasonable design is a fixed landmark with person-level holdout and development-
only preprocessing, conditional on the supplied cohort and recorded outcomes.
Implementation is tested at date boundaries, overlap handling, train/test
separation, imputation and vocabulary selection, and independently checked against
raw-source counts. Interpretation is restricted to the corresponding recorded
outcome; selection, ascertainment, and historical-value limitations remain.

## Verified findings and repairs

`tabs/audit_counts.csv` supplies exact values, regenerated from raw records. Historical old/new comparisons remain in the supporting audit outputs;
the manuscript presents the new analysis with standard table libraries. No historical fitted-model performance is claimed to be reproduced:
model artifacts, a reproducible historical split, and a historical seed are absent.

1. **CYBER date filter.** Character-to-Date comparison misparses month/day/year
   strings, retaining future records and discarding eligible historical records.
   Correct parsing is explicit. The current pre-origin count and leaked historical
   count have permanent regression checks.
2. **Evaluation.** Cross-validation in the old code tunes lambda but predictions
   used for headline performance are fitted-sample predictions. The entire model
   chunk is disabled in normal rendering. The final report describes an 80/20
   split, but no executable implementation or saved predictions substantiate it.
   New person-level validation is independently generated and identified as new.
3. **Forecasting horizon.** Last admission and last discharge differ. Neither is
   an ascertainment guarantee. Calendar windows and endpoint conventions are
   explicit, with shorter horizons and the last-discharge horizon reported.
4. **Feature timing.** Medication cutoff is commented out; claims are retained
   regardless of date. All claims creation/payment dates are in 2016. Claims are
   excluded; medication and diagnosis dates are parsed before filtering. One CANS
   record with an early finish but late creation/submission is excluded.
5. **Outcome construction.** Multiple dates within a window is not discharge-
   indexed readmission. Historical prior admissions change its interpretation.
   Full durations of post-origin starts are not occupancy within the window.
   Invalid durations, duplicates, overlap, and carryovers are handled explicitly.
6. **Denominators.** Original eligibility tables weight records; tests use person
   counts. `eligibility_audit.csv` contrasts record shares with member prevalence.
   Original presence summaries require more than one record; production indicators
   require at least one record and use the same definition across displays/models.
7. **Missingness and constructs.** Calendar-dependent item availability does not
   establish MCAR. Special -1/4 recoding is retained because project notes support
   it, and alternative scoring is reported. CANS prefix labels are corrected.
8. **LOS baseline.** The training mean is the squared-error comparator; the
   training median is the absolute-error comparator. Historical median-zero MSE
   was easier to beat than mean-based MSE and was evaluated in-sample.
9. **Prose provenance.** All revised analytical numbers are generated. Historical
   claims are explicitly attributed and separated from new estimates. The
   original report's count of six invalid source stays is eight in the supplied
   file (six are pre-origin, two post-origin).

## Check matrix

| Audit area | Evidence or result |
|---|---|
| Tier 1: denominator/unit | Member-level predictors, cohort flow, record-versus-member eligibility comparison; no record-weighted prevalence mislabeled as youth prevalence |
| Tier 1: missing versus zero | Unknown demographics and CANS preserved; special scores documented; no-record feature zeros mean recorded absence only; invalid duration is unavailable |
| Tier 1: row loss | Unique member keys, declared join cardinalities, conserved cohort, train/test coverage, outcome-specific missing-duration counts |
| Tier 1: provenance | Original byte hashes, source hashes, generated inline numbers and tables, `make check` regeneration |
| Tier 1: consistency | Same origin/end and outcome builder for all consumers; original claims and new estimates distinguished |
| Tier 2: EDA | Source sizes/date ranges; cohort events; monthly admission decline; CANS missingness by year; metrics and calibration by outcome |
| Tier 2: joins | Explicit one-to-one or many-to-one joins; intentional person-term long form deduplicated before pivot |
| Tier 2: construction | Parsed dates; CANS item map; special-code sensitivity; unique interval union; record presence rather than count >1 |
| Tier 2: estimand | Separate recorded start, multiple starts, occupied days; historical episode length and clinical readmission not conflated |
| Tier 2: inference | Outcome-stratified outer holdout; five inner folds, stratified for binary models; training-only selection/imputation; person bootstrap and exact binomial rate intervals conditional on the fitted model; no lasso p-values |
| Tier 2: skew | Binary prevalence and precision; zero-inflated days; squared and absolute losses with matching baselines; bounded nonnegative predictions |
| Tier 3: measurement/design | Outcome-dependent cohort and facility exclusions explicit; retrospective snapshot caveat; no unmeasured causal mechanism asserted |
| Tier 3: experiments | Inapplicable: no randomized treatment or assignment mechanism |
| Tier 4: prediction | Honest person holdout, calibration, discrimination, training-chosen threshold; all horizon/coding settings reported |
| Tier 4: causal branches | IV, RD, DiD, ITT/TOT, and treatment-effect inference inapplicable; no causal effect estimated |
| Tier 4: index reliability | Descriptive averages across heterogeneous needs, not asserted reflective latent scales; item map and missingness retained; no unsupported alpha/validity claim |
| Paper: floors/baseline | Always-negative accuracies and training-prevalence probabilities; mean/median baselines for the relevant losses |
| Paper: mechanisms/dose response | No intervention or mechanism identified; original policy-benefit claims narrowed |
| Paper: fragility | Six disclosed specifications, paired comparisons, and 20 stratified splits; no selection of best test specification |
| Paper: generalizability | Selected cohort, historical years, exclusion of facility types, unknown complete registry coverage |
| Adversarial validation | Independent re-derivation of source counts and date bug; 1,000 random interval-union comparisons; training-median check with a held-out age of 999 |

## Limits that remain

- The source extraction query and the complete population sampling frame are not
  present. The described selection rule is documented in the final report, not
  independently reconstructed from the population registry.
- All admission rows have discharges, but the file cannot identify unrecorded
  ongoing episodes or the exact extraction rule. No complete-follow-up assumption
  is smuggled into the event labels.
- Historical predictor versions are absent. Eligibility has effective dates but
  no entry dates. Some diagnosis/member snapshots were updated after the origin.
- The claims row count is consistent with a spreadsheet ceiling. Truncation is a
  candidate requiring source confirmation; it is not treated as a proven defect.
- Household dependence, prospective calibration, external validity, intervention
  effects, and clinical readmission cannot be verified from these data alone.
- Conditional bootstrap intervals omit training variability and selection errors.
  The random split is not a forward-calendar external validation.

## Rejected candidates

The low optional-module means do not by themselves prove scoring errors: source
notes support special codes mapped to zero. The larger means under missing-code
scoring answer a conditional-observation question. A single source maximum is not
proof of complete follow-up. Exact spreadsheet-length claims are not proof of
truncation. Multiple admissions are not necessarily readmissions because records
can overlap and transfer rules are unavailable.

## Mechanical checks and their limits

The `audit-analysis` skill's `audit_data.py` was run on the member-level analytical
CSV with a member key and placement grouping. It found no duplicate keys, type
failures, or logical-range failures. It flagged skewed occupied days and
calendar/group differences in missingness. These are diagnostics, not automatic
bias findings: the mean and median loss targets are separated, and unknown race
is preserved with training-fitted imputation and missingness indicators. Declined
race is also unavailable; the source's other-ethnicity category is retained as a
separate predictor rather than interpreted as recorded non-Hispanic identity.

The generic LaTeX provenance resolver was tried on the rendered manuscript. It
cannot resolve these inline knitr-generated tables into separate input files, so
its scoped comparison did not run and is not counted as a pass. The actual
provenance mechanism is executable R Markdown: tables and inline analytical
values read the same generated outputs. Literal years, seeds, thresholds, and
resampling counts specify the design; historical claims are confined to these
supporting audit notes.


## Sampling descriptions and the 2016 decline

The final supplied report, `archive/dstamp_report/New Jersey Predictive Analyses -
ODH-FINAL v3.pdf`, describes admissions beginning in 2014–2015 (or CMO involvement
without such admission). The two BRS documents in that directory instead describe
youth who stayed OOH in 2014–2015, with admission before the end and/or discharge
after the beginning of that period. Their literal wording does not recover a
unique SQL selection rule. The public report now states the common service-based
2014–2015 anchor and the start-versus-overlap ambiguity. It no longer claims that
an exact admission-start inclusion rule is established.

The fixed cohort is not a year-by-year enumeration of the service population.
Available data do not supply a verified active-service denominator over time.
All recorded admissions have discharge dates; later admission cohorts have shorter
recorded durations. These facts are consistent with, but do not prove, exclusion
of ongoing stays. Cohort aging/exit and real changes in utilization are alternatives.
The CMO authorization change mentioned in pc_notes.md concerns authorization
records, not a demonstrated break in the admission extract, and is not asserted
as the cause of the decline. No unsupported extraction date or service-policy
story is introduced. Calendar-year 2015 results are reported as a sensitivity,
not as proof that earlier ascertainment is complete.

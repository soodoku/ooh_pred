# Editorial changes

The original writing remains byte-for-byte under `archive/`; the ZIP also remains
untouched beside the project. `archive_inventory.csv` records every original
file, its SHA-256 hash, and its preserved location. The main manuscript takes the
opening questions, account of the available data, descriptions of CANS, rationale
for penalization, and causal-caution discussion from `archive/ooh_analysis.Rmd`.
The final collaborative report supplies the sampling definition and the claim
about historical 80/20 validation. Neither historical source is silently replaced.

Changes to prose have a substantive or factual reason:

- Replace approximate observation/prediction years with the January 1, 2015 origin
  and an explicit 672-day primary outcome window; expose alternative horizons.
- Call the original repeated-start outcome multiple recorded placements. Its
  code did not implement post-discharge readmission.
- Replace full post-origin episode durations with clipped, non-overlapping
  occupied days including carryovers. This is an explicitly different estimand,
  not a newly computed version of the old length-of-stay claim.
- Correct the CANS expansion to Child and Adolescent Needs and Strengths; correct
  the caregiver/youth and sexuality-module labels using the source items.
- Preserve documented -1/4-to-zero guidance, but remove the unsupported MCAR
  conclusion and retain an alternative scoring analysis.
- Replace leaked or record-weighted diagnostic, medication, and eligibility
  comparisons with pre-origin member-level indicators. Unsupported original
  direction/significance claims and coefficient rankings are not carried forward.
- Replace historical accuracy, MSE, and deployment claims with newly computed
  held-out performance, relevant baselines, conditional uncertainty, and a clear
  boundary between prediction and intervention effects.
- Retain the original causal-caution paragraph and completed next-steps sentence.
  The unfinished final sentence is omitted rather than completed speculatively.
- Correct the claim that the analytic sample required complete data across all
  years: the executable selection was a pre-origin CANS assessment.

Additional methods and limitations describe changes required by this audit. They
are new prose, not attributed quotations from the original author. The manuscript
is an unpublished research product, not a published-paper correction or a claim
that the original investigators used the reconstructed workflow.

The author's subsequent clarification makes this a fresh analysis, not a forensic
replication. New splits and new fitted results are the intended product. Missing
historical split assignments, seeds, or model objects are therefore not listed as
requirements or scientific limitations in the paper. Historical numerical checks
remain supporting development notes. The paper's limitations concern the actual
cohort, historical feature availability, and outcome ascertainment.

Independent review prompted disclosure of the assessment-count predictor,
expanded sensitivity metrics and intervals, a Gaussian penalty grid including
zero, and name-based alignment of model matrices. At the author's direction,
the new analysis uses one fixed-seed outcome-stratified development/test split
and outcome-stratified binary tuning folds. Every model and sensitivity is
rerun; the prior split is not selected or retained based on performance.

At the author's request, remove the entire reproduction-and-uncertainty appendix
section, repository paths and build-tool chatter from the public report. Retain
one necessary dependence caveat in Methods. Give References and Appendix separate,
unnumbered sections, with the appendix on its own page. Add a concise related-
research subsection and verified BibTeX citations. Preserve existing author prose.
Correct the admissions plot's extra 2017 tick; the last admission is in November
2016, so this presentation repair excludes no observations.

Add descriptive relationships and medication comparisons to the main report.
CANS bands use common cutpoints of 0.5 and 1, combining the sparse upper tail;
prior starts require both admission and creation dates before the forecast origin.
Medications are selected by development prevalence, not outcome association.
The requested rolling extension is a separate supplementary report, retaining the
fixed-origin question and results in the main report.

## Capacity, earlier endpoint, and public prose

At the author's request, add an abstract centered on the problem, data/design,
fixed-capacity findings and economic interpretation. Replace the 0.5 operating-point
table with equal-capacity case-finding comparisons and translate the Youden
threshold into selected, identified and missed youth. Preserve the original
Introduction, CANS descriptions, and causal-caution Discussion paragraph.

Add a calendar-year 2015 sensitivity to the SI with identical cohort, predictors,
and original split; show both annual-refitted scores and frozen long-window scores
against annual outcomes. Explain plausible reasons for the late decline without
claiming a recovered extraction mechanism or a population admission-rate trend.
Correct the overly specific cohort description: the final report specifies starts
in 2014–2015, whereas the requirements documents describe overlapping stays.
The public text states the common 2014–2015 service-selection anchor and ambiguity.

Remove random seeds, split rounding, seed-search commentary, archive/project-note
references, unused Excel row-limit diagnostics, label-lookup implementation, and
bootstrap-computation checks from visible prose. Keep scientific design details,
source-availability rules and inferential limits. Seeds and other execution choices
remain in code/private documentation. Change the rolling description to a separate
split, specify the capacity of the abstract's annual comparison, and report the
annual capacity-50 reversal. These are presentational clarifications of computed
results, not changes to outcomes, estimators or the model-selection rule.


The author's Table 4 question prompted a clearer caption: columns count youth,
not episodes or percentages, and each method selects its own equally sized list.
Add a generated capacity-200 comparison alongside the top-100 interpretation to
show how incremental yield changes with assessment capacity. The repository
landing page now leads with the research questions and findings rather than the
development/audit history. Necessary reproduction instructions remain in the
software documentation, outside the public report and SI.

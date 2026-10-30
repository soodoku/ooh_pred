# Capacity-based targeting evaluation

This extension answers the author's top-100 question after the existing model
and holdout performance have been inspected. It evaluates the existing ranking;
it does not retune or select a model or capacity on the test outcomes.

Estimand: number of held-out youth with at least one recorded admission in the
672-day primary window among K selected youth, for K = 50, 100, 200 and 500 from
the same 3,067-person test set. This is identification of recorded outcomes,
not admissions prevented or a welfare/cost estimate.

Comparators, fixed without inspecting their capacity results:
- Uniform random selection of K youth, evaluated by its exact conditional
  expectation K times the test event prevalence.
- Existing CANS-plus-demographics lasso, fitted with the original development
  sample, internal tuning and preprocessing. Recheck its existing held-out AUC.
- A transparent history rule: more distinct recorded pre-origin admission dates
  first, then more recent starts. Require both admission and record creation
  before the origin. This is a specified heuristic, not observed clinical practice.

Resolve remaining score ties with one seed-fixed random permutation independent
of outcomes. Report all capacities. Person-bootstrap the held-out youth jointly
across rankings and rerank within each resample at the same K. Use 1,000 resamples
and percentile intervals for paired yield differences; condition on fitted models,
split and documented tie rule. These intervals do not estimate training variability
or prospectively representative sampling. Duplicate resampled youth are bootstrap
observations, not additional individuals in the original top-K list.

Economic interpretation: compare case-finding yield at equal screening capacity;
compare the richer model with the simpler model to assess the incremental value of
additional record sources. Selecting higher-risk people need not maximize the
benefit of an intervention. Benefits, costs, heterogeneous treatment responses,
and the current allocation policy are not observed, so no prevented admissions,
welfare gain, or monetary saving can be estimated from the predictive exercise.

## Calendar-year 2015 extension

At the author's request, repeat the same fixed-origin design with exclusive end
2016-01-01. Hold the original cohort, split, features and capacity grid fixed;
retune each model within development for the annual outcome. Check its full-model
AUC against the existing days_365 sensitivity. Also evaluate the frozen 672-day
ranking against annual labels to distinguish relabeling from refitting. Bootstrap
the paired annual-minus-frozen yield using the same test observations. The initial
request concerned top 100; independent review prompted reporting all four existing
capacities to make the capacity dependence visible. No capacity is selected as best.
This is an exploratory endpoint comparison, not selection of a best horizon.

Implementation record: the primary split uses seed 20261029 and floors 80% within
strata. Ranking ties use seed + 200, as do paired bootstrap resamples. These details
are retained in code and this private design record rather than the public report.

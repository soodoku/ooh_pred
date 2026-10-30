# Capacity and public-prose review response

Claude Code independently recomputed top-K yields using base-R ordering, verified
threshold counts, frozen-score identity, core-model equivalence, date rules and
paired resampling. agy checked public prose and generated tables. Both found the
capacity calculations consistent and no remaining seeds, paths, build commands,
or audit-process chatter in visible prose.

## Accepted clarifications

- Scope the abstract's annual result and uncertain incremental yield to the stated
  capacity of 100. The annual full model ties core and trails history at 50.
- State the capacity-50 reversal in the SI, not only its table.
- Replace “new” with “separate” for the exploratory rolling person split.
- Use one decimal for expected random yields in both prose and tables.
- Attribute the frozen-score result to the longer-window model evaluated against
  2015 outcomes, rather than saying an endpoint retains information.
- Extend the frozen-versus-refitted comparison to every reported capacity, with
  paired intervals, and verify the frozen-score identity and yield calculations
  in tests. The additional capacities are descriptive comparisons, not a basis
  for choosing a model or horizon.
- Clarify that the one-year window lies within the period used for cohort selection.

## Findings that are not correctness defects

- Percentile endpoints such as 16.025 reflect quantile interpolation and floating-
  point serialization. Preserve full precision in CSV; public tables round them.
- Rounding stay-length medians to whole days is deliberate display precision,
  not truncation or a changed estimate. No substantive claim depends on half days.
- Rounded “about 6” and lift 4.7 were numerically compatible. Matching decimal
  precision is a presentation refinement rather than an arithmetic repair.
- An interval excluding zero at a larger capacity does not establish policy
  welfare gains. Public interpretations remain about conditional case-finding
  yields, with no claims about prevented placements, treatment effects or costs.

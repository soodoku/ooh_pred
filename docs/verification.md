# Verification

The complete stratified `make check` run rebuilt the data, audit, all six settings
for three outcomes, descriptive tables, figures, and PDF/HTML, and passed its then
56 expectations. That run is preserved in `reviews/stratified_build.log`.

After external review, the changed estimation stage was rerun for all 18
specifications, including exact binomial rate intervals. The new stability stage
was run for 20 fixed-seed stratified splits of both binary outcomes with both
feature sets (80 fitted models, each tuned within development). It independently
reproduces the primary predictions and generates paired comparisons and Brier
skill intervals. Figures, linting, tests, and both manuscript formats were rerun.
The final tests pass **69 expectations, zero failures, warnings, or skips**. The
final execution logs are collected in `check.log`. Both external reviews and
verified responses are indexed in `reviews/status.md`.

The outer split has 142 development and 36 test multiple-placement cases. Binary
inner folds are stratified. All selected positive penalties are interior; the
reduced occupied-day model selects zero, the natural unpenalized limit. Full
searches are retained in `tabs/tuning.csv`.

All 120 package versions recorded in `renv.lock` match the project library;
`parallel` is supplied with the pinned R installation. The native R workflow was
executed. The optional Docker target was not executed.

The source inventory verifies all 175 original files byte-for-byte. Source hashes
are checked during construction; agy independently verified all 20 raw data files.
No duplicate analytical member keys or logical-range failures were found.

All **14 PDF pages** were rendered and visually inspected, with detailed checks
of the calibration, sensitivity, and paired-comparison tables. The final numeric
format preserves small nonzero Brier differences and interval endpoints. Labels
are unique and extracted text stays inside page boundaries. The HTML contains
**15 tables and three embedded figures**, with no external image requirements.

These checks do not remove cohort-selection or ascertainment uncertainty, recover
historical predictor snapshots, or establish prospective clinical validity.
Repeated splits measure stability within the same cohort and are not independent
external validations.


## Report and rolling supplement update

The complete `make check` pipeline was rerun after the rolling and descriptive
extensions: data construction, audit, 18 fixed-origin specifications, 20 repeated
splits, 27 rolling forecasts, descriptions, figures, tests, lint and both report
renders. It passed 97 expectations. A subsequent source-set regression test,
small timeline-label correction and roster clarification were followed by figure
regeneration and `make lint test paper`: 100 passed, zero failures, warnings or
skips. The full run and final checks are retained in `check.log`.

The main `performance.csv` and `split_stability.csv` are byte-identical to the
pre-extension copies. The rolling analysis has 189 metric rows (27 windows by
seven metrics); every conditional bootstrap has 1,000 defined draws. Training
and test member sets are disjoint at every date. Actual CANS recency, delayed
training positives, recorded outcome-window counts and stay-duration summaries
are included in the separate supplement.

All six BibTeX entries were parsed with Pandoc and checked against verified DOI
metadata for titles, author order, publication year, volume and issue. Publisher
abstracts/full text support the cited claims. Both renderings have resolved
citations: four references in the main report and three in the supplement, with
one shared source. The R lockfile now pins 128 packages; `renv::status()` reports
no inconsistency.

The main report is 17 pages with 15 tables and five figures; the supplement is
seven pages with 11 tables and one timing figure. All pages were rasterized and
visually checked, with detailed checks of the new figures and supplement tables.
The timeline's clipped final date tick was corrected. PDF text remains within
page boundaries; HTML images are embedded. References and the main Appendix and
its subsections are unnumbered. The appendix begins on its own page. The rejected
reproduction section, build commands and repository paths are absent from the
visible research artifacts.

The main plot retains all observed 2016 admissions and removes the misleading
2017 axis tick. No admission is recorded in 2017. Ongoing-stay ascertainment remains
unknown; neither the rolling design nor an arbitrary follow-up cutoff repairs
missing source records. The six-month outcome and 30-day lead gap are explicit
planning choices evaluated with alternatives, not a claimed optimal clinical rule.


## Combined delivery PDF

At the author's request, `scripts/render.R` now uses the standard R qpdf package
to append the SI to the report on every build. `ms/main.pdf` is the 24-page
combined delivery file; the 17-page body is retained as `ms/report.pdf` and the
seven-page SI remains available separately. SI starts on physical page 18.
`make lint paper` passed. Every combined page has identical extracted text and
raster pixels to its corresponding source page; all 15 PDF links are preserved,
including correctly offset internal SI destinations. The SI opening page was
also visually inspected. No analytical results changed.

## Forecast timing in Figure 1

The admissions figure now shades available pre-origin predictor history and the
672-day admission outcome window, labels the January 1, 2015 information cutoff,
and explicitly reports a zero-day lead gap. Its note identifies the 80/20 split
as a split of youth using common calendar windows; gray shading is not mislabeled
as the entire model-training period. The SI timeline legend now displays its
365-day history, 30-day gap and 180-day outcome duration directly. Durations and
dates come from analysis configuration and generated rolling windows.

Regenerated figures and both reports; `make lint paper` passed. Visually inspected
both Figure 1 pages in the combined PDF. It remains 24 pages, with SI starting on
page 18. All page text remains within bounds and combined-document internal links
retain their correct targets. No data, model, sample or forecast definition changed.


## Capacity, annual endpoint, and public-prose revision

The complete `make check` pipeline passed after the targeting extension: source
construction and audit, all 18 fixed-origin specifications, capacity evaluation,
80 repeated-split fits, 27 rolling forecasts, descriptions, figures, 134 test
expectations, linting and report rendering. The final frozen-versus-annual
comparison was expanded to all four capacities, rerun and checked, followed by
`make lint test paper` after the presentation and PDF-merge repairs. Final tests:
**134 passed, zero failures, warnings or skips**. Logs are in
`reviews/capacity_full_check.log`, `capacity_horizon_check.log` and
`capacity_final_check.log`.

The full rerun reproduced `performance.csv`, `targeting.csv`,
`split_stability.csv` and `rolling_performance.csv` byte-for-byte. The only
intentional change to the frozen-score table is its expansion from one to four
capacities. The top-100 estimates and intervals are unchanged. Tests independently
verify score identity, annual event bounds, equal-capacity yields and paired
differences. Both independent reviews and dispositions are linked in
`reviews/status.md`.

Final delivery: **27 pages**, comprising a **19-page report and eight-page SI**.
SI starts on physical page **20**. The main HTML has 15 tables, five embedded
figures and six references; the SI has 14 tables, one embedded timing figure and
three references. The shared bibliography contains eight distinct cited entries,
all parsed by Pandoc and checked against DOI metadata. The project library agrees
with all 132 locked packages. The native workflow was tested; Docker was not run.

Visible PDF text, HTML and captions were checked for seeds, repository paths,
archive/build/audit chatter and the removed unpublished-manuscript label. None
remain. An obsolete generated `ms/main.tex` still contained an older seed sentence
and was deleted; the current generated body is `ms/report.tex`. All final pages
were rasterized and visually inspected, including the expanded Table 4 explanation,
annual comparison, timing figures and reference sections. No extracted page text
extends outside its page.

### PDF link repair

The final destination-level check found that qpdf combination retained citation
annotations but dropped their named destinations. Earlier statements that links
were preserved were insufficient: annotation counts alone did not verify target
resolution. Replace that conclusion with this verification. The R render stage now
uses standard Ghostscript pdfwrite to combine the documents; qpdf still verifies
page counts. Ghostscript is a declared build prerequisite and is included by the
standard rocker/verse installation script.

Every final combined page has identical extracted text to its source. All **22**
links retain their external URLs or resolve to the correct source bibliography
page, including SI offsets and the repeated Friedman citation. Ghostscript
re-expresses the page drawing operations, so raster pixels are not asserted to be
byte-identical; the final rendered pages were checked visually. No PDF parsing or
link-reconstruction code was introduced into the research pipeline.

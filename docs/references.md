# Reference verification

Bibliographic records were checked on October 30, 2026 against publisher article
pages, PubMed article metadata, Crossref deposits, and the installed glmnet
package citation. The Crossref records used are preserved in
`reviews/reference_metadata.json`. The report and supplement use ordinary
BibTeX and Pandoc citeproc; no reference list is manually typeset.

- Chor et al. (2012), DOI 10.1016/j.childyouth.2012.08.016: Elsevier abstract,
  authors, journal, volume, issue and pages verified. Associations with clinical
  improvement and absence of a length-of-stay difference come from its abstract.
- Chor et al. (2015), DOI 10.1007/s10488-014-0545-5: Springer abstract and citation
  verified. Use the 2015 volume year; online publication was in March 2014.
- Friedman, Hastie and Tibshirani (2010), DOI 10.18637/jss.v033.i01: JSS publisher
  metadata and `citation("glmnet")` verify the article, including pages 1–22.
- Saito and Rehmsmeier (2015), DOI 10.1371/journal.pone.0118432: PLOS full text and
  metadata verified; article identifier e0118432.
- Taquet, Fazel and Rush (2025), DOI 10.1136/bmjment-2025-301622: the full article retrieved from Europe PMC and publisher-indexed
  methods describe the 180-day measurement and subsequent outcome periods;
  Crossref verifies the authors, journal, volume, issue and article identifier.
- Poweleit et al. (2026), DOI 10.1177/10445463261466534: PubMed abstract and citation
  verified against Crossref. The study predicts readmission 30, 90 and 180 days
  after discharge; that target is explicitly distinguished from this report's
  calendar-origin recorded admission starts.

- Kleinberg, Ludwig, Mullainathan and Obermeyer (2015), DOI
  10.1257/aer.p20151023: AEA article page and Crossref verify author order, title,
  AER 105(5), pages 491–495. The abstract supports distinguishing prediction
  policy problems from causal estimation; it does not establish benefits here.
- Kitagawa and Tetenov (2018), DOI 10.3982/ECTA13288: Wiley article page and
  Crossref verify Econometrica 86(2), pages 591–616. The abstract discusses
  treatment allocation, capacity constraints and welfare. The report invokes
  this distinction without claiming to estimate an optimal treatment policy.

These are research sources, not evidence of clinical validity of the current
model. Source metadata and citation resolution are checked separately from the
claims each source supports.

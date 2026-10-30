# Source data

The raw clinical and administrative files were extracted without modification
from `ooh_pred-20261030T013707Z-1-001.zip`. They remain in this directory using the
archive's original names. Metadata and codebooks remain under `metadata/`.

`docs/source_hashes.csv` records SHA-256 hashes for top-level input tables;
`docs/archive_inventory.csv` verifies every original archived file. The pipeline
reads the member, admission, CANS, CYBER diagnosis, medication and eligibility
files, and audits claims separately. Claims are excluded from forecasting because
none of their creation/payment dates precede January 1, 2015.

`derived/` contains generated member-level features, outcomes, split membership,
and fitted-model predictions. Raw and derived individual-level data, the original
archive contents, and connection files are excluded from version control. No
permission to redistribute them is inferred from their presence in this archive.

Dates are month/day/four-digit-year except claims dates, which use two-digit years.
Source values are preserved; cleanup happens in R. Missing values, special CANS
codes and absence of a record have separate documented meanings in the paper.

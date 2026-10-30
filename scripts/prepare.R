source("scripts/config.R")
members <- read_source("member_mob.txt")
stopifnot(!anyDuplicated(members$member_id))
admissions_raw <- read_source("admission.txt")
admissions <- admissions_raw |>
  dplyr::distinct() |>
  dplyr::transmute(member_id,
    admission_date = parse_date(admitdate),
    discharge_date = parse_date(dischargedate), created_date = parse_date(createdate),
    site_type = dplyr::recode(sitetype, DAT = "DAP")
  )
stopifnot(!anyNA(admissions$admission_date), !anyNA(admissions$discharge_date))
cans_raw <- read_source("assessment_sna.txt")
cans <- cans_raw |>
  dplyr::filter(
    parse_date(datesubmittedtocsa) < origin,
    parse_date(createddate) < origin, parse_date(finishdate) < origin
  )
features <- summarize_cans(cans)
features_missing <- summarize_cans(cans, special_zero = FALSE)
demographics <- members |>
  dplyr::transmute(member_id,
    age = as.numeric(origin - as.Date(sprintf("%s-%02d-01", yob, as.integer(mob)))) / 365.25,
    female = as.numeric(gender == "F"),
    white = dplyr::if_else(is.na(race) | race %in% c("UNKNOWN", "DECLINED"), NA_real_,
      as.numeric(race == "CAUCASIAN/WHITE")
    ),
    black = dplyr::if_else(is.na(race) | race %in% c("UNKNOWN", "DECLINED"), NA_real_,
      as.numeric(race == "AFRICAN AMERICAN/BLACK")
    ),
    hispanic = as.numeric(ethnicitycode == "Hispanic or Latino"),
    ethnicity_other = as.numeric(ethnicitycode == "Other")
  )
features <- dplyr::left_join(features, demographics, by = "member_id", relationship = "one-to-one")
features_missing <- dplyr::left_join(features_missing, demographics,
  by = "member_id", relationship = "one-to-one"
)
stopifnot(nrow(features) == dplyr::n_distinct(cans$member_id))
diagnoses <- read_source("member_diag.txt", c("member_id", "diagcode", "createdate", "updatedate"))
medications <- read_source("member_medication.txt", c("member_id", "txtmedicationname", "createddate"))
eligibility <- read_source("eligibility.txt", c("member_id", "eligtype", "startdate"))
records <- dplyr::bind_rows(
  diagnoses |>
    dplyr::filter(parse_date(createdate) < origin, !is.na(diagcode)) |>
    dplyr::transmute(member_id, term = paste0("diagnosis_", diagcode)),
  medications |>
    dplyr::filter(parse_date(createddate) < origin, !is.na(txtmedicationname)) |>
    dplyr::transmute(member_id, term = paste0("medication_", tolower(txtmedicationname))),
  eligibility |>
    dplyr::filter(
      parse_date(startdate) < origin,
      !is.na(eligtype), !eligtype %in% c("NotValid", "3560", "DDD", "GAFC")
    ) |>
    dplyr::transmute(member_id, term = paste0("eligibility_", eligtype))
) |>
  dplyr::distinct()
outcomes <- build_outcomes(features, admissions, origin, end)
stopifnot(all(outcomes$recorded_days >= 0 & outcomes$recorded_days <= as.numeric(end - origin), na.rm = TRUE))
prepared <- list(
  features = features, features_missing = features_missing,
  records = records, outcomes = outcomes, admissions = admissions,
  origin = origin, end = end
)
saveRDS(prepared, "data/derived/prepared.rds")
analysis <- dplyr::left_join(
  features, outcomes,
  by = "member_id", relationship = "one-to-one"
)
readr::write_csv(analysis, "data/derived/analysis.csv")

flow <- tibble::tibble(
  stage = c(
    "Members in extract", "Members with pre-origin CANS", "Excluded without pre-origin CANS",
    "Recorded placement", "Multiple recorded placements", "Unusable occupied-day outcome"
  ),
  n = c(
    nrow(members), nrow(features), nrow(members) - nrow(features),
    sum(outcomes$placement), sum(outcomes$repeat_placement), sum(is.na(outcomes$recorded_days))
  )
)
readr::write_csv(flow, "tabs/cohort.csv")
coverage <- tibble::tibble(
  source = c("CANS", "CYBER diagnoses", "Medications", "Eligibility"),
  rows = c(nrow(cans_raw), nrow(diagnoses), nrow(medications), nrow(eligibility)),
  pre_origin = c(
    nrow(cans), sum(parse_date(diagnoses$createdate) < origin, na.rm = TRUE),
    sum(parse_date(medications$createddate) < origin, na.rm = TRUE),
    sum(parse_date(eligibility$startdate) < origin, na.rm = TRUE)
  )
)
readr::write_csv(coverage, "tabs/source_coverage.csv")
missingness <- cans_raw |>
  dplyr::mutate(year = lubridate::year(parse_date(datesubmittedtocsa))) |>
  dplyr::group_by(year) |>
  dplyr::summarise(
    n = dplyr::n(),
    dplyr::across(c(rbldf_sleep, rbcrb_bulliedbyothers, rbcrb_gambling), ~ mean(is.na(.x))),
    .groups = "drop"
  )
readr::write_csv(missingness, "tabs/cans_missingness.csv")
module_map <- tibble::tibble(item = names(cans)) |>
  dplyr::filter(grepl("^rb(ldf|cgn|cgs|jj|sud|dnm|tm|cs|crb|acc|srp|sd)_", item)) |>
  dplyr::mutate(prefix = sub("_.*", "", item))
readr::write_csv(module_map, "docs/cans_items.csv")
summary <- features |>
  dplyr::left_join(outcomes, by = "member_id", relationship = "one-to-one") |>
  tidyr::pivot_longer(
    cols = c(life_functioning:sex_related_problems, age:female),
    names_to = "variable", values_to = "value"
  ) |>
  dplyr::group_by(variable, placement) |>
  dplyr::summarise(
    n = sum(!is.na(value)), mean = mean(value, na.rm = TRUE),
    sd = stats::sd(value, na.rm = TRUE), missing = sum(is.na(value)), .groups = "drop"
  )
readr::write_csv(summary, "tabs/descriptive.csv")
months <- admissions |>
  dplyr::count(month = lubridate::floor_date(admission_date, "month"), name = "admissions")
readr::write_csv(months, "tabs/admission_months.csv")
source_files <- list.files("data", pattern = "[.](txt|csv)$", full.names = TRUE)
manifest <- tibble::tibble(
  file = source_files,
  sha256 = vapply(source_files, digest::digest, character(1), file = TRUE, algo = "sha256")
)
if (file.exists("docs/source_hashes.csv")) {
  expected <- readr::read_csv("docs/source_hashes.csv", show_col_types = FALSE)
  stopifnot(
    identical(manifest$file, expected$file),
    identical(unname(manifest$sha256), expected$sha256)
  )
} else {
  readr::write_csv(manifest, "docs/source_hashes.csv")
}

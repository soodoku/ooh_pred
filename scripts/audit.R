source("scripts/config.R")
data <- readRDS("data/derived/prepared.rds")
admissions <- read_source("admission.txt") |>
  dplyr::mutate(
    start = parse_date(admitdate), finish = parse_date(dischargedate),
    days = as.numeric(finish - start)
  )
cans <- read_source("assessment_sna.txt")
old_cohort <- cans |>
  dplyr::filter(parse_date(finishdate) < origin) |>
  dplyr::distinct(member_id)
old_outcomes <- admissions |>
  dplyr::filter(start >= origin) |>
  dplyr::group_by(member_id) |>
  dplyr::summarise(
    days = sum(dplyr::if_else(days < 0, NA_real_, days)),
    starts = dplyr::n_distinct(start), .groups = "drop"
  )
old_outcomes <- old_cohort |>
  dplyr::left_join(old_outcomes, by = "member_id", relationship = "one-to-one") |>
  dplyr::mutate(
    placement = as.integer(!is.na(days)),
    repeat_placement = as.integer(tidyr::replace_na(starts, 0L) > 1),
    days = tidyr::replace_na(days, 0)
  )
diagnoses <- read_source("member_diag.txt", c("member_id", "diagcode", "createdate"))
# This deliberately reproduces the source defect; production uses parse_date().
old_filter <- diagnoses$createdate < origin
correct_dates <- parse_date(diagnoses$createdate)
medications <- read_source("member_medication.txt", c("member_id", "txtmedicationname", "createddate"))
claims <- read_source("member_claims.csv", c("member_id", "startdate", "enddate", "paiddate", "createdate"))
claims_paid <- parse_date(claims$paiddate, TRUE)
stopifnot(!anyNA(claims_paid), all(format(claims_paid, "%Y") == "2016"))
old_post <- admissions |>
  dplyr::filter(start >= origin, member_id %in% old_cohort$member_id)
prior_members <- admissions |>
  dplyr::filter(start < origin) |>
  dplyr::pull(member_id)
missed_repeat <- old_post |>
  dplyr::group_by(member_id) |>
  dplyr::summarise(starts = dplyr::n_distinct(start), .groups = "drop") |>
  dplyr::filter(starts == 1, member_id %in% prior_members)
counts <- tibble::tibble(
  quantity = c(
    "original_cohort", "original_placement_events", "original_repeat_events",
    "always_no_placement_accuracy", "always_no_repeat_accuracy", "original_mean_days",
    "original_median_days", "median_baseline_mse", "mean_baseline_mse",
    "diagnosis_old_retained", "diagnosis_correct_retained", "diagnosis_future_retained",
    "diagnosis_pre_origin_dropped", "medications_pre_origin", "medications_post_origin",
    "medications_missing_date", "claims_rows", "claims_pre_origin_service", "claims_pre_origin_created",
    "negative_stays", "duplicate_rows", "same_person_start_duplicates", "historical_repeat_additional",
    "carryover_stays", "admissions_after_origin", "people_after_origin",
    "discharges_after_last_admission", "last_admission_horizon", "last_discharge_horizon",
    "cans_finish_cutoff", "cans_available_cutoff"
  ),
  value = c(
    nrow(old_cohort), sum(old_outcomes$placement), sum(old_outcomes$repeat_placement),
    mean(old_outcomes$placement == 0), mean(old_outcomes$repeat_placement == 0),
    mean(old_outcomes$days), stats::median(old_outcomes$days),
    mlr3measures::mse(old_outcomes$days, rep(stats::median(old_outcomes$days), nrow(old_outcomes))),
    mlr3measures::mse(old_outcomes$days, rep(mean(old_outcomes$days), nrow(old_outcomes))),
    sum(old_filter, na.rm = TRUE), sum(correct_dates < origin),
    sum(old_filter & correct_dates >= origin, na.rm = TRUE),
    sum(correct_dates < origin & (is.na(old_filter) | !old_filter)),
    sum(parse_date(medications$createddate) < origin, na.rm = TRUE),
    sum(parse_date(medications$createddate) >= origin, na.rm = TRUE),
    sum(is.na(parse_date(medications$createddate))), nrow(claims),
    sum(parse_date(claims$startdate, TRUE) < origin),
    sum(parse_date(claims$createdate, TRUE) < origin),
    sum(admissions$days < 0), sum(duplicated(admissions)),
    nrow(admissions) - nrow(dplyr::distinct(admissions, member_id, start)),
    nrow(missed_repeat), sum(admissions$start < origin & admissions$finish >= origin & admissions$days >= 0),
    sum(admissions$start >= origin), dplyr::n_distinct(admissions$member_id[admissions$start >= origin]),
    sum(admissions$finish > max(admissions$start)), as.numeric(max(admissions$start) - origin) + 1,
    as.numeric(max(admissions$finish) - origin) + 1,
    sum(parse_date(cans$finishdate) < origin),
    sum(
      parse_date(cans$finishdate) < origin &
        parse_date(cans$datesubmittedtocsa) < origin &
        parse_date(cans$createddate) < origin
    )
  )
)
readr::write_csv(counts, "tabs/audit_counts.csv")
eligibility <- read_source("eligibility.txt") |>
  dplyr::filter(
    parse_date(startdate) < origin,
    !is.na(eligtype), !eligtype %in% c("NotValid", "3560", "DDD", "GAFC")
  ) |>
  dplyr::inner_join(dplyr::select(old_outcomes, member_id, placement),
    by = "member_id", relationship = "many-to-one"
  )
record_shares <- eligibility |>
  dplyr::count(placement, eligtype) |>
  dplyr::group_by(placement) |>
  dplyr::mutate(record_share = n / sum(n)) |>
  dplyr::ungroup()
member_shares <- eligibility |>
  dplyr::distinct(member_id, placement, eligtype) |>
  dplyr::group_by(placement) |>
  dplyr::mutate(denominator = dplyr::n_distinct(member_id)) |>
  dplyr::group_by(placement, eligtype) |>
  dplyr::summarise(
    members = dplyr::n(), denominator = dplyr::first(denominator),
    member_prevalence = members / denominator, .groups = "drop"
  )
eligibility_comparison <- dplyr::left_join(
  record_shares, member_shares,
  by = c("placement", "eligtype"), relationship = "one-to-one"
)
readr::write_csv(eligibility_comparison, "tabs/eligibility_audit.csv")
source_ranges <- tibble::tibble(
  field = c(
    "Admission", "Discharge", "CANS submitted", "CANS finish", "Claims service start",
    "Claims service end", "Claims creation", "Claims payment", "Medication creation"
  ),
  first = as.character(c(
    min(admissions$start), min(admissions$finish),
    min(parse_date(cans$datesubmittedtocsa)), min(parse_date(cans$finishdate)),
    min(parse_date(claims$startdate, TRUE)), min(parse_date(claims$enddate, TRUE)),
    min(parse_date(claims$createdate, TRUE)), min(claims_paid),
    min(parse_date(medications$createddate), na.rm = TRUE)
  )),
  last = as.character(c(
    max(admissions$start), max(admissions$finish),
    max(parse_date(cans$datesubmittedtocsa)), max(parse_date(cans$finishdate)),
    max(parse_date(claims$startdate, TRUE)), max(parse_date(claims$enddate, TRUE)),
    max(parse_date(claims$createdate, TRUE)), max(claims_paid),
    max(parse_date(medications$createddate), na.rm = TRUE)
  ))
)
readr::write_csv(source_ranges, "tabs/date_ranges.csv")
stopifnot(
  nrow(data$features) == 15332, sum(data$outcomes$placement) == 907,
  sum(old_filter & correct_dates >= origin, na.rm = TRUE) == 208842,
  sum(correct_dates < origin) == 917452
)

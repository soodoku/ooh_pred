source("scripts/config.R")
prepared <- readRDS("data/derived/prepared.rds")
raw <- read_source("assessment_sna.txt")
cans <- dplyr::bind_cols(
  score_cans(raw),
  tibble::tibble(
    finish = parse_date(raw$finishdate), submitted = parse_date(raw$datesubmittedtocsa),
    created = parse_date(raw$createddate)
  )
)
rm(raw)
members <- read_source("member_mob.txt")
demographics <- members |>
  dplyr::transmute(member_id,
    birth_date = as.Date(sprintf("%s-%02d-01", yob, as.integer(mob))),
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
diagnoses <- read_source("member_diag.txt", c("member_id", "diagcode", "createdate"))
medications <- read_source("member_medication.txt", c("member_id", "txtmedicationname", "createddate"))
eligibility <- read_source("eligibility.txt", c("member_id", "eligtype", "startdate"))
records <- dplyr::bind_rows(
  diagnoses |>
    dplyr::filter(!is.na(diagcode)) |>
    dplyr::transmute(member_id, term = paste0("diagnosis_", diagcode), date = parse_date(createdate)),
  medications |>
    dplyr::filter(!is.na(txtmedicationname)) |>
    dplyr::transmute(member_id,
      term = paste0("medication_", tolower(txtmedicationname)),
      date = parse_date(createddate)
    ),
  eligibility |>
    dplyr::filter(!is.na(eligtype), !eligtype %in% c("NotValid", "3560", "DDD", "GAFC")) |>
    dplyr::transmute(member_id, term = paste0("eligibility_", eligtype), date = parse_date(startdate))
)
sources <- list(cans = cans, demographics = demographics, records = records, admissions = prepared$admissions)
set.seed(seed + 100L)
partition <- rsample::initial_split(dplyr::select(members, member_id), prop = 0.8)
training_members <- rsample::training(partition)$member_id
testing_members <- rsample::testing(partition)$member_id
stopifnot(length(intersect(training_members, testing_members)) == 0)
saveRDS(list(training = training_members, testing = testing_members), "data/derived/rolling_split.rds")
settings <- tibble::tribble(
  ~setting, ~lookback, ~gap, ~horizon,
  "rolling_main", 365L, 30L, 180L,
  "history_180", 180L, 30L, 180L,
  "gap_zero", 365L, 0L, 180L,
  "outcome_90", 365L, 30L, 90L,
  "outcome_365", 365L, 30L, 365L
)
windows <- dplyr::bind_rows(lapply(seq_len(nrow(settings)), function(i) {
  rolling_windows(
    seq(as.Date("2015-01-01"), as.Date("2016-04-01"), by = "3 months"),
    settings$lookback[i], settings$gap[i], settings$horizon[i],
    min(parse_date(medications$createddate), na.rm = TRUE), end
  ) |>
    dplyr::mutate(setting = settings$setting[i])
}))
readr::write_csv(windows, "tabs/rolling_windows.csv")
results <- list()
predictions <- list()
checks <- list()
for (i in seq_len(nrow(windows))) {
  window <- windows[i, ]
  message(window$setting, ": ", window$target_start)
  training <- landmark_snapshot(sources, window$train_cutoff, window$lookback, training_members)
  testing <- landmark_snapshot(sources, window$cutoff, window$lookback, testing_members)
  features <- dplyr::bind_rows(training$features, testing$features)
  train_ids <- seq_len(nrow(training$features))
  test_ids <- nrow(training$features) + seq_len(nrow(testing$features))
  outcome <- c(
    landmark_labels(
      training$features$member_id, sources$admissions,
      window$train_start, window$train_end, window$cutoff
    ),
    landmark_labels(testing$features$member_id, sources$admissions, window$target_start, window$target_end)
  )
  stopifnot(!anyDuplicated(features$member_id), sum(outcome[train_ids]) >= 10, sum(outcome[test_ids]) >= 2)
  fit <- fit_lasso(features, outcome, train_ids, test_ids,
    dplyr::bind_rows(training$records, testing$records),
    seed = seed + 100L
  )
  metrics <- bootstrap_metrics(fit$predictions, rolling_metrics, seed + 100L)
  results[[i]] <- dplyr::bind_cols(window[rep(1, nrow(metrics)), ], metrics) |>
    dplyr::mutate(
      n_train = length(train_ids), n_test = length(test_ids),
      train_events = sum(outcome[train_ids]), events = sum(outcome[test_ids]), lambda = fit$lambda
    )
  predictions[[i]] <- dplyr::mutate(fit$predictions, setting = window$setting, target_start = window$target_start)
  recency <- sources$cans |>
    dplyr::filter(
      member_id %in% testing$features$member_id,
      finish >= window$cutoff - window$lookback, finish < window$cutoff,
      submitted < window$cutoff, created < window$cutoff
    ) |>
    dplyr::group_by(member_id) |>
    dplyr::summarise(days = as.numeric(window$target_start - max(finish)), .groups = "drop")
  checks[[i]] <- dplyr::bind_cols(window, tibble::tibble(
    assessment_lag_median = stats::median(recency$days),
    assessment_lag_q25 = unname(stats::quantile(recency$days, 0.25)),
    assessment_lag_q75 = unname(stats::quantile(recency$days, 0.75)),
    recorded_starts_in_target = sum(
      sources$admissions$admission_date >= window$target_start &
        sources$admissions$admission_date < window$target_end
    ),
    days_after_target_to_last_discharge = as.numeric(max(sources$admissions$discharge_date) + 1 - window$target_end),
    n_train = length(train_ids), n_test = length(test_ids),
    overlapping_members = length(intersect(training$features$member_id, testing$features$member_id)),
    late_training_positives = sum(landmark_labels(
      training$features$member_id,
      sources$admissions, window$train_start, window$train_end
    )) - sum(outcome[train_ids])
  ))
}
readr::write_csv(dplyr::bind_rows(results), "tabs/rolling_performance.csv")
readr::write_csv(dplyr::bind_rows(checks), "tabs/rolling_checks.csv")
saveRDS(dplyr::bind_rows(predictions), "data/derived/rolling_predictions.rds")

ascertainment <- sources$admissions |>
  dplyr::mutate(
    year = lubridate::year(admission_date),
    recorded_stay_days = as.numeric(discharge_date - admission_date)
  ) |>
  dplyr::group_by(year) |>
  dplyr::summarise(
    recorded_starts = dplyr::n(),
    valid_durations = sum(recorded_stay_days >= 0),
    median_stay = stats::median(recorded_stay_days[recorded_stay_days >= 0]),
    p90_stay = unname(stats::quantile(recorded_stay_days[recorded_stay_days >= 0], 0.9)),
    .groups = "drop"
  )
readr::write_csv(ascertainment, "tabs/admission_ascertainment.csv")

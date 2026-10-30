source("scripts/config.R")
data <- readRDS("data/derived/prepared.rds")
last_discharge_end <- max(data$admissions$discharge_date) + 1
stopifnot(end == max(data$admissions$admission_date) + 1, last_discharge_end - origin == 699)
set.seed(seed)
strata <- data$outcomes |>
  dplyr::mutate(row_id = dplyr::row_number(), stratum = placement + repeat_placement)
train_ids <- strata |>
  dplyr::group_by(stratum) |>
  dplyr::slice_sample(prop = 0.8) |>
  dplyr::pull(row_id) |>
  sort()
test_ids <- setdiff(seq_len(nrow(data$features)), train_ids)
split_counts <- strata |>
  dplyr::mutate(sample = dplyr::if_else(row_id %in% train_ids, "Development", "Test")) |>
  dplyr::count(stratum, sample, name = "youth")
readr::write_csv(split_counts, "tabs/split_counts.csv")
saveRDS(list(
  training = data$features$member_id[train_ids],
  testing = data$features$member_id[test_ids]
), "data/derived/split.rds")
settings <- list(
  main = list(features = data$features, records = data$records, end = end),
  core = list(features = data$features, records = NULL, end = end),
  special_missing = list(features = data$features_missing, records = data$records, end = end),
  days_180 = list(features = data$features, records = data$records, end = origin + 180),
  days_365 = list(features = data$features, records = data$records, end = origin + 365),
  days_699 = list(features = data$features, records = data$records, end = last_discharge_end)
)
results <- list()
tuning <- list()
for (setting in names(settings)) {
  specification <- settings[[setting]]
  outcomes <- build_outcomes(specification$features, data$admissions, origin, specification$end)
  for (outcome in c("placement", "repeat_placement", "recorded_days")) {
    message(setting, ": ", outcome)
    family <- if (outcome == "recorded_days") "gaussian" else "binomial"
    fit <- fit_lasso(specification$features, outcomes[[outcome]], train_ids, test_ids,
      specification$records,
      family = family, seed = seed
    )
    predictions <- fit$predictions
    statistic <- if (family == "binomial") {
      function(data) classification_metrics(data, fit$threshold)
    } else {
      regression_metrics
    }
    metrics <- if (family == "binomial") {
      classification_intervals(predictions, fit$threshold, seed)
    } else {
      bootstrap_metrics(predictions, statistic, seed)
    }
    metrics <- dplyr::mutate(metrics,
      setting = setting, outcome = outcome,
      horizon_days = as.numeric(specification$end - origin),
      n_train = length(fit$train_ids), n_test = nrow(predictions),
      events = if (family == "binomial") sum(predictions$truth) else NA_real_,
      threshold = fit$threshold, lambda = fit$lambda
    )
    results[[paste(setting, outcome)]] <- metrics
    tuning[[paste(setting, outcome)]] <- dplyr::mutate(fit$tuning,
      setting = setting, outcome = outcome, selected = lambda == fit$lambda
    )
    if (setting == "main") {
      saveRDS(fit, file.path("data/derived", paste0(outcome, "_fit.rds")))
      readr::write_csv(fit$coefficients, file.path("tabs", paste0(outcome, "_coefficients.csv")))
      readr::write_csv(fit$tuning, file.path("tabs", paste0(outcome, "_tuning.csv")))
      if (family == "binomial") {
        baseline <- predictions
        baseline$prediction <- predictions$baseline_mean
        baseline_metrics <- classification_metrics(baseline, 0.5)
        default_metrics <- classification_metrics(predictions, 0.5)
        comparison <- tibble::tibble(
          metric = names(baseline_metrics),
          training_prevalence = unname(baseline_metrics),
          lasso_at_half = unname(default_metrics)
        )
        readr::write_csv(comparison, file.path("tabs", paste0(outcome, "_baselines.csv")))
        calibration <- predictions |>
          dplyr::mutate(bin = dplyr::ntile(prediction, 10)) |>
          dplyr::group_by(bin) |>
          dplyr::summarise(
            n = dplyr::n(), events = sum(truth),
            predicted = mean(prediction), observed = mean(truth), .groups = "drop"
          )
        intervals <- t(vapply(seq_len(nrow(calibration)), function(i) {
          stats::binom.test(calibration$events[i], calibration$n[i])$conf.int
        }, numeric(2)))
        calibration$lower <- intervals[, 1]
        calibration$upper <- intervals[, 2]
        calibration$outcome <- outcome
        readr::write_csv(calibration, file.path("tabs", paste0(outcome, "_calibration.csv")))
      }
    }
  }
}
readr::write_csv(dplyr::bind_rows(results), "tabs/performance.csv")
readr::write_csv(dplyr::bind_rows(tuning), "tabs/tuning.csv")
writeLines(capture.output(sessionInfo()), "docs/session_info.txt")

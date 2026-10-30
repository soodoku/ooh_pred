source("scripts/config.R")
data <- readRDS("data/derived/prepared.rds")
split <- readRDS("data/derived/split.rds")
full <- readRDS("data/derived/placement_fit.rds")
prior <- data$admissions |>
  dplyr::filter(admission_date < origin, created_date < origin) |>
  dplyr::group_by(member_id) |>
  dplyr::summarise(
    prior_starts = dplyr::n_distinct(admission_date),
    latest_prior_start = as.numeric(max(admission_date)), .groups = "drop"
  )
capacities <- c(50L, 100L, 200L, 500L)
results <- list()
ranked_data <- list()
for (setting in c("main", "days_365")) {
  outcomes <- if (setting == "main") {
    data$outcomes
  } else {
    build_outcomes(data$features, data$admissions, origin, as.Date("2016-01-01"))
  }
  training <- match(split$training, data$features$member_id)
  testing <- match(split$testing, data$features$member_id)
  fitted <- if (setting == "main") {
    full
  } else {
    fit_lasso(data$features, outcomes$placement, training, testing, data$records, seed = seed)
  }
  core <- fit_lasso(data$features, outcomes$placement, training, testing, records = NULL, seed = seed)
  performance <- readr::read_csv("tabs/performance.csv", show_col_types = FALSE)
  expected <- dplyr::filter(
    performance, .data$setting == .env$setting,
    outcome == "placement", metric == "roc_auc"
  )$estimate
  observed_auc <- unname(classification_metrics(fitted$predictions, fitted$threshold)["roc_auc"])
  stopifnot(isTRUE(all.equal(observed_auc, expected)))
  rankings <- fitted$predictions |>
    dplyr::left_join(dplyr::select(core$predictions, member_id, core_prediction = prediction),
      by = "member_id", relationship = "one-to-one"
    ) |>
    dplyr::left_join(prior, by = "member_id", relationship = "one-to-one") |>
    dplyr::left_join(dplyr::select(full$predictions, member_id, long_prediction = prediction),
      by = "member_id", relationship = "one-to-one"
    ) |>
    dplyr::mutate(prior_starts = tidyr::replace_na(prior_starts, 0L)) |>
    dplyr::arrange(member_id)
  stopifnot(!anyNA(rankings$core_prediction), !anyDuplicated(rankings$member_id))
  set.seed(seed + 200L)
  rankings$tie_order <- sample.int(nrow(rankings))
  results[[setting]] <- dplyr::bind_rows(lapply(capacities, function(capacity) {
    bootstrap_metrics(rankings, function(x) capacity_metrics(x, capacity), seed + 200L) |>
      dplyr::mutate(
        setting = setting, capacity = capacity,
        n_test = nrow(rankings), total_events = sum(rankings$truth)
      )
  }))
  ranked_data[[setting]] <- rankings
}
readr::write_csv(dplyr::bind_rows(results), "tabs/targeting.csv")
saveRDS(ranked_data, "data/derived/targeting_rankings.rds")
horizon_comparison <- dplyr::bind_rows(lapply(capacities, function(capacity) {
  bootstrap_metrics(ranked_data$days_365, function(x) {
    annual <- x |>
      dplyr::arrange(dplyr::desc(prediction), tie_order) |>
      dplyr::slice_head(n = capacity)
    frozen <- x |>
      dplyr::arrange(dplyr::desc(long_prediction), tie_order) |>
      dplyr::slice_head(n = capacity)
    c(
      annual_events = sum(annual$truth), frozen_events = sum(frozen$truth),
      gain_retuning = sum(annual$truth) - sum(frozen$truth)
    )
  }, seed + 200L) |>
    dplyr::mutate(capacity = capacity)
}))
readr::write_csv(horizon_comparison, "tabs/horizon_targeting.csv")
confusion <- dplyr::bind_rows(lapply(c("placement", "repeat_placement"), function(outcome) {
  fit <- readRDS(file.path("data/derived", paste0(outcome, "_fit.rds")))
  p <- fit$predictions
  selected <- p$prediction >= fit$threshold
  tibble::tibble(
    outcome = outcome, threshold = fit$threshold, n_test = nrow(p),
    events = sum(p$truth), flagged = sum(selected), found = sum(p$truth[selected]),
    no_event_flagged = sum(selected & p$truth == 0), missed = sum(!selected & p$truth == 1)
  )
}))
readr::write_csv(confusion, "tabs/threshold_counts.csv")
summary <- dplyr::bind_rows(results) |>
  dplyr::filter(metric %in% c("full_events", "core_events", "history_events", "random_events")) |>
  dplyr::select(setting, capacity, metric, estimate) |>
  tidyr::pivot_wider(names_from = metric, values_from = estimate)
print(summary)

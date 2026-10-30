rolling_windows <- function(target_starts, lookback, gap, horizon,
                            source_start, source_end, label_delay = 30L) {
  calendar <- tibble::tibble(date = seq(
    min(target_starts) - horizon - gap - label_delay,
    max(target_starts),
    by = "day"
  ))
  distance <- horizon + gap + label_delay
  splits <- rsample::sliding_index(calendar, date,
    lookback = 0L,
    assess_start = distance, assess_stop = distance
  )
  windows <- dplyr::bind_rows(lapply(splits$splits, function(split) {
    tibble::tibble(
      train_start = rsample::analysis(split)$date,
      target_start = rsample::assessment(split)$date
    )
  })) |>
    dplyr::filter(target_start %in% target_starts) |>
    dplyr::mutate(
      train_cutoff = train_start - gap, train_end = train_start + horizon,
      cutoff = target_start - gap, target_end = target_start + horizon,
      lookback = lookback, gap = gap, horizon = horizon, label_delay = label_delay
    ) |>
    dplyr::filter(train_cutoff - lookback >= source_start, target_end <= source_end)
  stopifnot(all(windows$train_end <= windows$cutoff - label_delay))
  windows
}

landmark_snapshot <- function(sources, cutoff, lookback, members) {
  start <- cutoff - lookback
  cans <- sources$cans |>
    dplyr::filter(
      member_id %in% members, finish >= start, finish < cutoff,
      submitted < cutoff, created < cutoff
    ) |>
    dplyr::select(-finish, -submitted, -created) |>
    dplyr::group_by(member_id) |>
    dplyr::summarise(dplyr::across(dplyr::everything(), mean_observed),
      cans_records = dplyr::n(), .groups = "drop"
    )
  demographics <- sources$demographics |>
    dplyr::mutate(age = as.numeric(cutoff - birth_date) / 365.25) |>
    dplyr::select(-birth_date)
  prior <- sources$admissions |>
    dplyr::filter(admission_date >= start, admission_date < cutoff, created_date < cutoff) |>
    dplyr::group_by(member_id) |>
    dplyr::summarise(
      prior_placements = dplyr::n_distinct(admission_date),
      days_since_placement = as.numeric(cutoff - max(admission_date)), .groups = "drop"
    )
  features <- cans |>
    dplyr::left_join(demographics, by = "member_id", relationship = "one-to-one") |>
    dplyr::left_join(prior, by = "member_id", relationship = "one-to-one") |>
    dplyr::mutate(prior_placements = tidyr::replace_na(prior_placements, 0L))
  records <- sources$records |>
    dplyr::filter(member_id %in% features$member_id, date >= start, date < cutoff) |>
    dplyr::select(member_id, term) |>
    dplyr::distinct()
  list(features = features, records = records)
}

landmark_labels <- function(members, admissions, start, end, available_before = as.Date("9999-01-01")) {
  events <- admissions |>
    dplyr::filter(admission_date >= start, admission_date < end, created_date < available_before) |>
    dplyr::distinct(member_id)
  as.integer(members %in% events$member_id)
}

rolling_metrics <- function(data) {
  truth <- factor(data$truth, levels = c(0, 1))
  c(
    roc_auc = mlr3measures::auc(truth, data$prediction, positive = "1"),
    pr_auc = mlr3measures::prauc(truth, data$prediction, positive = "1"),
    brier = mlr3measures::bbrier(truth, data$prediction, positive = "1"),
    baseline_brier = mlr3measures::bbrier(truth, data$baseline_mean, positive = "1"),
    brier_gain = mean((data$truth - data$baseline_mean)^2 - (data$truth - data$prediction)^2),
    prevalence = mean(data$truth), mean_prediction = mean(data$prediction)
  )
}

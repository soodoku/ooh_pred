capacity_metrics <- function(data, capacity) {
  stopifnot(capacity >= 1, capacity <= nrow(data))
  full <- data |>
    dplyr::arrange(dplyr::desc(prediction), tie_order) |>
    dplyr::slice_head(n = capacity)
  core <- data |>
    dplyr::arrange(dplyr::desc(core_prediction), tie_order) |>
    dplyr::slice_head(n = capacity)
  history <- data |>
    dplyr::arrange(dplyr::desc(prior_starts), dplyr::desc(latest_prior_start), tie_order) |>
    dplyr::slice_head(n = capacity)
  full_events <- sum(full$truth)
  core_events <- sum(core$truth)
  history_events <- sum(history$truth)
  random_events <- capacity * mean(data$truth)
  c(
    full_events = full_events, core_events = core_events, history_events = history_events,
    random_events = random_events, precision = full_events / capacity,
    recall = full_events / sum(data$truth), lift = full_events / random_events,
    gain_random = full_events - random_events, gain_core = full_events - core_events,
    gain_history = full_events - history_events
  )
}

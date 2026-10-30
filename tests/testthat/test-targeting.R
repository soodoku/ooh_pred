testthat::test_that("capacity comparisons select equal-sized lists and compare paired yields", {
  data <- tibble::tibble(
    truth = c(1, 0, 1, 0, 1), prediction = c(0.9, 0.8, 0.7, 0.6, 0.5),
    core_prediction = c(0.1, 0.2, 0.3, 0.4, 0.5),
    prior_starts = c(2, 2, 1, 0, 0), latest_prior_start = c(1, 2, 3, NA, NA),
    tie_order = seq_len(5)
  )
  results <- capacity_metrics(data, 3L)
  testthat::expect_equal(unname(results[c("full_events", "core_events", "history_events")]), c(2, 2, 2))
  testthat::expect_equal(unname(results["random_events"]), 3 * 3 / 5)
  testthat::expect_equal(unname(results[c("precision", "recall")]), c(2 / 3, 2 / 3))
  testthat::expect_equal(unname(results[c("gain_core", "gain_history")]), c(0, 0))
  testthat::expect_equal(unname(results["gain_random"]), 0.2)
  census <- capacity_metrics(data, nrow(data))
  testthat::expect_equal(unname(census[c("gain_core", "gain_history", "gain_random")]), c(0, 0, 0))
  testthat::expect_error(capacity_metrics(data, 6L))
})

testthat::test_that("score ties do not use outcomes and history ranks count before recency", {
  data <- tibble::tibble(
    truth = c(0, 1, 1, 0), prediction = rep(0.2, 4), core_prediction = rep(0.2, 4),
    prior_starts = c(2, 1, 2, 0), latest_prior_start = c(1, 100, 2, NA),
    tie_order = c(1, 2, 4, 3)
  )
  results <- capacity_metrics(data, 1L)
  testthat::expect_equal(unname(results[c("full_events", "core_events", "history_events")]), c(0, 0, 1))
  testthat::expect_equal(capacity_metrics(data[c(4, 3, 2, 1), ], 1L), results)
})

testthat::test_that("capacity results use the original holdout and correctly bounded annual labels", {
  root <- testthat::test_path("..", "..")
  rankings <- readRDS(file.path(root, "data/derived/targeting_rankings.rds"))
  split <- readRDS(file.path(root, "data/derived/split.rds"))
  prepared <- readRDS(file.path(root, "data/derived/prepared.rds"))
  results <- readr::read_csv(file.path(root, "tabs/targeting.csv"), show_col_types = FALSE)
  testthat::expect_equal(nrow(results), 2 * 4 * 10)
  testthat::expect_identical(rankings$main$member_id, rankings$days_365$member_id)
  testthat::expect_setequal(rankings$main$member_id, split$testing)
  testthat::expect_true(all(rankings$days_365$truth <= rankings$main$truth))
  annual_ids <- prepared$admissions |>
    dplyr::filter(admission_date >= as.Date("2015-01-01"), admission_date < as.Date("2016-01-01")) |>
    dplyr::pull(member_id)
  testthat::expect_equal(rankings$days_365$truth, as.integer(rankings$days_365$member_id %in% annual_ids))
  for (setting_name in names(rankings)) {
    x <- rankings[[setting_name]]
    testthat::expect_false(anyDuplicated(x$member_id) > 0)
    testthat::expect_true(all(x$latest_prior_start < as.numeric(as.Date("2015-01-01")), na.rm = TRUE))
    for (capacity_n in c(50L, 100L, 200L, 500L)) {
      expected <- capacity_metrics(x, capacity_n)
      actual <- dplyr::filter(results, setting == setting_name, capacity == capacity_n)
      testthat::expect_equal(actual$estimate, unname(expected[actual$metric]))
    }
  }
  prior <- prepared$admissions |>
    dplyr::filter(admission_date < as.Date("2015-01-01"), created_date < as.Date("2015-01-01")) |>
    dplyr::distinct(member_id, admission_date) |>
    dplyr::count(member_id, name = "starts")
  expected <- dplyr::left_join(rankings$main, prior, by = "member_id")
  testthat::expect_equal(expected$prior_starts, tidyr::replace_na(expected$starts, 0L))
})

testthat::test_that("frozen long-window scores and paired annual yields are preserved", {
  root <- testthat::test_path("..", "..")
  rankings <- readRDS(file.path(root, "data/derived/targeting_rankings.rds"))$days_365
  fit <- readRDS(file.path(root, "data/derived/placement_fit.rds"))
  comparison <- readr::read_csv(file.path(root, "tabs/horizon_targeting.csv"), show_col_types = FALSE)
  expected <- fit$predictions$prediction[match(rankings$member_id, fit$predictions$member_id)]
  testthat::expect_equal(rankings$long_prediction, expected)
  testthat::expect_equal(nrow(comparison), 4 * 3)
  for (capacity_n in c(50L, 100L, 200L, 500L)) {
    annual_order <- order(-rankings$prediction, rankings$tie_order)
    frozen_order <- order(-rankings$long_prediction, rankings$tie_order)
    annual_events <- sum(rankings$truth[head(annual_order, capacity_n)])
    frozen_events <- sum(rankings$truth[head(frozen_order, capacity_n)])
    expected <- c(
      annual_events = annual_events, frozen_events = frozen_events,
      gain_retuning = annual_events - frozen_events
    )
    actual <- dplyr::filter(comparison, capacity == capacity_n)
    testthat::expect_equal(actual$estimate, unname(expected[actual$metric]))
  }
  testthat::expect_true(all(comparison$valid_draws == comparison$draws))
})

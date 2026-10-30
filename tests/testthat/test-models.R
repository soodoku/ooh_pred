testthat::test_that("feature selection and imputation use only training youth", {
  training <- tibble::tibble(member_id = c("a", "b", "c"), age = c(1, 3, NA_real_))
  testing <- tibble::tibble(member_id = c("d", "e"), age = c(NA_real_, 999))
  matrix <- prepare_matrix(training, testing)
  testthat::expect_equal(unname(matrix$test[, "age"]), c(2, 999))
  testthat::expect_equal(unname(matrix$test[, "age_missing"]), c(1, 0))
  reordered <- prepare_matrix(
    dplyr::mutate(training, score = c(10, 20, 30)),
    dplyr::select(dplyr::mutate(testing, score = c(40, 50)), score, age, member_id)
  )
  testthat::expect_equal(unname(reordered$test[, "age"]), c(2, 999))
  testthat::expect_equal(unname(reordered$test[, "score"]), c(40, 50))
  records <- tibble::tibble(member_id = c("a", "b", "d"), term = c("known", "known", "future"))
  encoded <- record_features(records, training, min_members = 2)
  testthat::expect_equal(encoded$vocabulary, "known")
  testthat::expect_equal(record_features(records, testing, encoded$vocabulary)$data$known, c(0, 0))
})

testthat::test_that("probability metrics recognize a rare-event baseline", {
  data <- tibble::tibble(truth = c(rep(0, 9), 1), prediction = rep(0.1, 10))
  metric <- classification_metrics(data, 0.5)
  testthat::expect_equal(unname(metric["accuracy"]), 0.9)
  testthat::expect_equal(unname(metric["sensitivity"]), 0)
  testthat::expect_equal(unname(metric["brier"]), 0.09)
})

testthat::test_that("test-only missingness cannot change the fitted feature schema", {
  training <- tibble::tibble(member_id = c("a", "b"), age = c(1, 3))
  testing <- tibble::tibble(member_id = "c", age = NA_real_)
  matrix <- prepare_matrix(training, testing)
  testthat::expect_equal(colnames(matrix$test), "age")
  testthat::expect_equal(unname(matrix$test[, "age"]), 2)
})

testthat::test_that("source cohort and holdout remain disjoint and exhaustive", {
  prepared <- readRDS(testthat::test_path("..", "..", "data/derived/prepared.rds"))
  split <- readRDS(testthat::test_path("..", "..", "data/derived/split.rds"))
  testthat::expect_length(intersect(split$training, split$testing), 0)
  testthat::expect_setequal(c(split$training, split$testing), prepared$features$member_id)
  testthat::expect_equal(nrow(prepared$features), 15332)
  testthat::expect_false(anyDuplicated(prepared$features$member_id) > 0)
  testthat::expect_true(all(prepared$outcomes$recorded_days <= 672, na.rm = TRUE))
  counts <- prepared$outcomes |>
    dplyr::mutate(
      stratum = placement + repeat_placement,
      training = member_id %in% split$training
    ) |>
    dplyr::group_by(stratum) |>
    dplyr::summarise(total = dplyr::n(), training = sum(training), .groups = "drop")
  testthat::expect_equal(counts$training, floor(0.8 * counts$total))
})

testthat::test_that("model outputs refer only to test youth and usable outcomes", {
  root <- testthat::test_path("..", "..")
  split <- readRDS(file.path(root, "data/derived/split.rds"))
  for (outcome in c("placement", "repeat_placement", "recorded_days")) {
    fit <- readRDS(file.path(root, "data/derived", paste0(outcome, "_fit.rds")))
    testthat::expect_true(all(fit$predictions$member_id %in% split$testing))
    testthat::expect_false(any(fit$predictions$member_id %in% split$training))
    testthat::expect_false(anyNA(fit$predictions$truth))
    testthat::expect_true(all(is.finite(fit$predictions$prediction)))
    if (outcome != "recorded_days") {
      testthat::expect_true(all(fit$predictions$prediction >= 0 & fit$predictions$prediction <= 1))
    }
  }
})

testthat::test_that("all sensitivity specifications and uncertainty draws are reported", {
  data <- readr::read_csv(testthat::test_path("..", "..", "tabs/performance.csv"), show_col_types = FALSE)
  testthat::expect_equal(dplyr::n_distinct(data$setting), 6)
  testthat::expect_equal(nrow(dplyr::distinct(data, setting, outcome)), 18)
  main <- dplyr::filter(data, setting == "main")
  testthat::expect_true(all(main$valid_draws[main$interval_method == "percentile_bootstrap"] == 1000))
  testthat::expect_true(all(main$lower <= main$estimate & main$estimate <= main$upper))
  tuning <- readr::read_csv(testthat::test_path("..", "..", "tabs/tuning.csv"), show_col_types = FALSE)
  testthat::expect_equal(sum(tuning$selected), 18)
  testthat::expect_true(all(tuning$lambda[tuning$outcome == "recorded_days"] >= 0))
  testthat::expect_equal(sum(tuning$lambda == 0), 6)
  testthat::expect_true(all(data$draws[data$interval_method == "percentile_bootstrap"] == 1000))
  testthat::expect_true(all(is.finite(data$lower) & is.finite(data$upper)))
})

testthat::test_that("perfect observed sensitivity retains binomial uncertainty", {
  data <- tibble::tibble(truth = c(rep(1, 16), rep(0, 20)), prediction = c(rep(0.8, 16), rep(0.1, 20)))
  intervals <- classification_intervals(data, 0.5, seed = 42)
  sensitivity <- dplyr::filter(intervals, metric == "sensitivity")
  testthat::expect_equal(sensitivity$estimate, 1)
  testthat::expect_equal(sensitivity$lower, 0.7940928, tolerance = 1e-7)
  testthat::expect_equal(sensitivity$upper, 1)
  testthat::expect_equal(sensitivity$interval_method, "exact_binomial")
})

testthat::test_that("descriptive denominators and missingness refer to youth", {
  root <- testthat::test_path("..", "..")
  prepared <- readRDS(file.path(root, "data/derived/prepared.rds"))
  characteristics <- readr::read_csv(file.path(root, "tabs/member_characteristics.csv"), show_col_types = FALSE)
  testthat::expect_equal(
    characteristics$value[characteristics$variable == "unknown_race"],
    mean(is.na(prepared$features$white))
  )
  features <- readr::read_csv(file.path(root, "tabs/feature_descriptive.csv"), show_col_types = FALSE)
  testthat::expect_true(all(features$n_0 == sum(prepared$outcomes$placement == 0)))
  testthat::expect_true(all(features$n_1 == sum(prepared$outcomes$placement == 1)))
  testthat::expect_true(all(features$events_0 <= features$n_0 & features$events_1 <= features$n_1))
})

testthat::test_that("repeated splits and paired comparisons use matched evaluations", {
  root <- testthat::test_path("..", "..")
  stability <- readr::read_csv(file.path(root, "tabs/split_stability.csv"), show_col_types = FALSE)
  performance <- readr::read_csv(file.path(root, "tabs/performance.csv"), show_col_types = FALSE)
  paired <- readr::read_csv(file.path(root, "tabs/paired_comparison.csv"), show_col_types = FALSE)
  testthat::expect_equal(nrow(stability), 240)
  testthat::expect_equal(sort(unique(stability$split_seed)), 20261029 + 0:19)
  testthat::expect_true(all(stability$events[stability$outcome == "placement"] == 182))
  testthat::expect_true(all(stability$events[stability$outcome == "repeat_placement"] == 36))
  primary <- stability |>
    dplyr::filter(split_seed == 20261029, model == "full") |>
    dplyr::inner_join(dplyr::filter(performance, setting == "main"),
      by = c("outcome", "metric"), relationship = "one-to-one"
    )
  testthat::expect_equal(primary$estimate.x, primary$estimate.y)
  direct <- stability |>
    dplyr::filter(split_seed == 20261029) |>
    dplyr::select(outcome, metric, model, estimate) |>
    tidyr::pivot_wider(names_from = model, values_from = estimate) |>
    dplyr::mutate(gain = dplyr::if_else(metric == "brier", core - full, full - core)) |>
    dplyr::inner_join(paired, by = c("outcome", "metric"), relationship = "one-to-one")
  testthat::expect_equal(direct$gain, direct$estimate)
  testthat::expect_true(all(paired$valid_draws == 1000))
})

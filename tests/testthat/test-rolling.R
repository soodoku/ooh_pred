testthat::test_that("rolling windows separate history, gap, outcomes, and label maturation", {
  windows <- rolling_windows(
    as.Date(c("2015-01-01", "2016-04-01")),
    365L, 30L, 180L, as.Date("2012-11-14"), as.Date("2016-11-03")
  )
  testthat::expect_equal(nrow(windows), 2)
  testthat::expect_equal(as.integer(windows$target_start - windows$cutoff), rep(30L, 2))
  testthat::expect_equal(as.integer(windows$target_end - windows$target_start), rep(180L, 2))
  testthat::expect_equal(as.integer(windows$cutoff - windows$train_end), rep(30L, 2))
  annual <- rolling_windows(
    as.Date(c("2015-01-01", "2015-04-01", "2016-04-01")),
    365L, 30L, 365L, as.Date("2012-11-14"), as.Date("2016-11-03")
  )
  testthat::expect_equal(annual$target_start, as.Date("2015-04-01"))
})

testthat::test_that("landmark predictors exclude future, stale, and unavailable records", {
  cutoff <- as.Date("2015-01-01")
  sources <- list(
    cans = tibble::tibble(
      member_id = c("a", "a", "a", "a", "b"),
      life_functioning = c(1, 3, 3, 3, 2), finish = cutoff + c(-10, -366, -1, 1, -5),
      submitted = cutoff + c(-9, -365, 1, 2, -4), created = cutoff + c(-10, -366, -2, 1, -5)
    ),
    demographics = tibble::tibble(member_id = c("a", "b"), birth_date = cutoff - c(3650, 4000), female = c(1, 0)),
    admissions = tibble::tibble(
      member_id = rep("a", 5),
      admission_date = cutoff + c(-10, -20, -366, 10, 30),
      created_date = cutoff + c(-9, 1, -365, 11, 31)
    ),
    records = tibble::tibble(
      member_id = rep("a", 4), term = c("old", "recent", "boundary", "future"),
      date = cutoff + c(-366, -1, 0, 1)
    )
  )
  snapshot <- landmark_snapshot(sources, cutoff, 365L, "a")
  testthat::expect_equal(snapshot$features$member_id, "a")
  testthat::expect_equal(snapshot$features$life_functioning, 1)
  testthat::expect_equal(snapshot$features$cans_records, 1)
  testthat::expect_equal(snapshot$features$prior_placements, 1)
  testthat::expect_equal(snapshot$features$days_since_placement, 10)
  testthat::expect_equal(snapshot$records$term, "recent")
  testthat::expect_equal(landmark_labels("a", sources$admissions, cutoff, cutoff + 30), 1L)
  gap_only <- dplyr::filter(sources$admissions, admission_date == cutoff + 10)
  testthat::expect_equal(landmark_labels("a", gap_only, cutoff + 30, cutoff + 210), 0L)
  testthat::expect_equal(landmark_labels("a", sources$admissions, cutoff + 30, cutoff + 210), 1L)
  testthat::expect_equal(landmark_labels("a", sources$admissions, cutoff + 30, cutoff + 210, cutoff + 31), 0L)
})

testthat::test_that("paired Brier improvement uses the same test observations", {
  predictions <- tibble::tibble(
    truth = c(0, 1, 0, 1), prediction = c(0.1, 0.8, 0.3, 0.6),
    baseline_mean = rep(0.4, 4)
  )
  metrics <- rolling_metrics(predictions)
  testthat::expect_equal(
    unname(metrics["brier_gain"]),
    unname(metrics["baseline_brier"] - metrics["brier"])
  )
})

testthat::test_that("descriptive group counts partition the cohort", {
  root <- testthat::test_path("..", "..")
  groups <- readr::read_csv(file.path(root, "tabs/descriptive_relationships.csv"), show_col_types = FALSE)
  prepared <- readRDS(file.path(root, "data/derived/prepared.rds"))
  counts <- groups |>
    dplyr::group_by(variable) |>
    dplyr::summarise(n = sum(n), events = sum(events), .groups = "drop")
  testthat::expect_equal(counts$n, rep(nrow(prepared$features), nrow(counts)))
  testthat::expect_equal(counts$events, rep(sum(prepared$outcomes$placement), nrow(counts)))
})

testthat::test_that("rolling outputs retain each date and prevent person or temporal overlap", {
  root <- testthat::test_path("..", "..")
  checks <- readr::read_csv(file.path(root, "tabs/rolling_checks.csv"), show_col_types = FALSE)
  performance <- readr::read_csv(file.path(root, "tabs/rolling_performance.csv"), show_col_types = FALSE)
  predictions <- readRDS(file.path(root, "data/derived/rolling_predictions.rds"))
  split <- readRDS(file.path(root, "data/derived/rolling_split.rds"))
  testthat::expect_equal(nrow(checks), 27)
  testthat::expect_true(all(checks$overlapping_members == 0))
  testthat::expect_true(all(checks$train_end <= checks$cutoff - checks$label_delay))
  testthat::expect_true(all(checks$target_end <= as.Date("2016-11-03")))
  testthat::expect_length(intersect(split$training, split$testing), 0)
  testthat::expect_true(all(predictions$member_id %in% split$testing))
  testthat::expect_equal(nrow(dplyr::distinct(predictions, setting, target_start, member_id)), nrow(predictions))
  testthat::expect_equal(nrow(performance), 27 * 7)
  testthat::expect_true(all(performance$valid_draws == performance$draws))
  recomputed <- predictions |>
    dplyr::group_by(setting, target_start) |>
    dplyr::summarise(gain = mean((truth - baseline_mean)^2 - (truth - prediction)^2), .groups = "drop") |>
    dplyr::inner_join(dplyr::filter(performance, metric == "brier_gain"),
      by = c("setting", "target_start"), relationship = "one-to-one"
    )
  testthat::expect_equal(recomputed$gain, recomputed$estimate)
})

testthat::test_that("the fixed-origin cohort is a subset of the member roster", {
  root <- testthat::test_path("..", "..")
  prepared <- readRDS(file.path(root, "data/derived/prepared.rds"))
  roster <- readr::read_delim(file.path(root, "data/member_mob.txt"),
    delim = "|",
    col_types = readr::cols(.default = "c"), show_col_types = FALSE
  )
  names(roster) <- tolower(names(roster))
  ids <- roster[[intersect(c("member_id", "memberid"), names(roster))]]
  cohort <- readr::read_csv(file.path(root, "tabs/cohort.csv"), show_col_types = FALSE)
  testthat::expect_true(all(prepared$features$member_id %in% ids))
  testthat::expect_equal(cohort$n[cohort$stage == "Members in extract"], length(unique(ids)))
  testthat::expect_equal(
    cohort$n[cohort$stage == "Excluded without pre-origin CANS"],
    sum(!ids %in% prepared$features$member_id)
  )
})

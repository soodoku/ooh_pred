testthat::test_that("source-specific dates respect the forecasting boundary", {
  testthat::expect_equal(
    parse_date(c("12/31/2014", "1/1/2015")),
    as.Date(c("2014-12-31", "2015-01-01"))
  )
  testthat::expect_equal(parse_date("1/2/16", short_year = TRUE), as.Date("2016-01-02"))
  testthat::expect_true(parse_date("9/9/2015") > as.Date("2015-01-01"))
})

testthat::test_that("occupied days merge overlaps and count half-open intervals", {
  testthat::expect_equal(union_days(
    as.Date(c("2015-01-01", "2015-01-05", "2015-01-10")),
    as.Date(c("2015-01-10", "2015-01-08", "2015-01-12"))
  ), 11)
  testthat::expect_equal(union_days(as.Date("2015-01-01"), as.Date("2015-01-01")), 0)
})

testthat::test_that("outcomes include carryover days but only new starts", {
  members <- tibble::tibble(member_id = c("a", "b", "c", "d"))
  admissions <- tibble::tibble(
    member_id = c("a", "a", "b", "c", "d"),
    admission_date = as.Date(c("2014-12-30", "2015-01-05", "2015-01-11", "2015-01-02", "2015-01-01")),
    discharge_date = as.Date(c("2015-01-07", "2015-01-20", "2015-01-15", "2015-01-01", "2015-01-02"))
  )
  result <- build_outcomes(members, admissions, as.Date("2015-01-01"), as.Date("2015-01-11"))
  testthat::expect_equal(result$placement, c(1L, 0L, 1L, 1L))
  testthat::expect_equal(result$recorded_days, c(10, 0, NA, 1))
  testthat::expect_equal(result$repeat_placement, rep(0L, 4))
})

testthat::test_that("same-date admissions are not multiple starts", {
  members <- tibble::tibble(member_id = "a")
  admissions <- tibble::tibble(
    member_id = c("a", "a"),
    admission_date = as.Date(c("2015-01-01", "2015-01-01")),
    discharge_date = as.Date(c("2015-01-03", "2015-01-04"))
  )
  result <- build_outcomes(members, admissions, as.Date("2015-01-01"), as.Date("2015-01-05"))
  testthat::expect_equal(result$repeat_placement, 0L)
  testthat::expect_equal(result$recorded_days, 3)
})

testthat::test_that("module scoring preserves unknown versus documented special values", {
  items <- tibble::tibble(a = c(-1, NA, 2), b = c(4, NA, 3))
  testthat::expect_equal(score_module(items), c(0, NA, 2.5))
  testthat::expect_equal(score_module(items, FALSE), c(NA, NA, 2.5))
  testthat::expect_error(score_module(tibble::tibble(a = 9)))
})

testthat::test_that("interval unions agree with an independent day enumeration", {
  set.seed(73)
  matched <- replicate(1000, {
    start <- sample(0:30, 10, replace = TRUE)
    end <- start + sample(0:15, 10, replace = TRUE)
    enumerated <- unique(unlist(Map(function(a, b) {
      if (a == b) integer() else seq.int(a, b - 1)
    }, start, end)))
    union_days(start, end) == length(enumerated)
  })
  testthat::expect_true(all(matched))
})

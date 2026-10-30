prepare_matrix <- function(training, testing, records = NULL) {
  if (!is.null(records)) {
    encoded <- record_features(records, training,
      min_members = max(25, ceiling(nrow(training) * 0.005))
    )
    training <- dplyr::left_join(training, encoded$data,
      by = "member_id", relationship = "one-to-one"
    )
    testing <- dplyr::left_join(testing,
      record_features(records, testing, encoded$vocabulary)$data,
      by = "member_id", relationship = "one-to-one"
    )
  }
  train <- dplyr::select(training, -member_id)
  test <- dplyr::select(testing, -member_id)
  stopifnot(setequal(names(train), names(test)))
  test <- dplyr::select(test, dplyr::all_of(names(train)))
  names(train) <- janitor::make_clean_names(names(train))
  names(test) <- names(train)
  stopifnot(all(vapply(train, is.numeric, logical(1))))
  usable <- vapply(train, function(x) any(!is.na(x)), logical(1))
  train <- train[, usable, drop = FALSE]
  test <- test[, usable, drop = FALSE]
  for (column in names(train)) {
    if (anyNA(train[[column]])) {
      train[[paste0(column, "_missing")]] <- as.numeric(is.na(train[[column]]))
      test[[paste0(column, "_missing")]] <- as.numeric(is.na(test[[column]]))
    }
    training_median <- stats::median(train[[column]], na.rm = TRUE)
    train[[column]] <- as.numeric(Hmisc::impute(train[[column]], training_median))
    test[[column]] <- as.numeric(Hmisc::impute(test[[column]], training_median))
  }
  variable <- vapply(train, function(x) stats::sd(x) > 0, logical(1))
  list(
    train = as.matrix(train[, variable, drop = FALSE]),
    test = as.matrix(test[, variable, drop = FALSE])
  )
}

fit_lasso <- function(features, outcome, train_ids, test_ids, records = NULL,
                      family = "binomial", seed = 20261029L) {
  train_ids <- train_ids[!is.na(outcome[train_ids])]
  test_ids <- test_ids[!is.na(outcome[test_ids])]
  training <- features[train_ids, ]
  testing <- features[test_ids, ]
  y_train <- outcome[train_ids]
  y_test <- outcome[test_ids]
  set.seed(seed)
  fold <- sample(rep(seq_len(5), length.out = length(train_ids)))
  if (family == "binomial") {
    fold <- tibble::tibble(row_id = seq_along(y_train), truth = y_train) |>
      dplyr::group_by(truth) |>
      dplyr::mutate(fold = sample(rep(seq_len(5), length.out = dplyr::n()))) |>
      dplyr::ungroup() |>
      dplyr::arrange(row_id) |>
      dplyr::pull(fold)
  }
  penalties <- if (family == "binomial") {
    10^seq(0, -4, length.out = 50)
  } else {
    c(10^seq(2, -3, length.out = 50), 10^seq(-3.25, -7, by = -0.25), 0)
  }
  validation_predictions <- matrix(NA_real_, length(y_train), length(penalties))
  for (i in seq_len(5)) {
    validation <- which(fold == i)
    development <- which(fold != i)
    matrix <- prepare_matrix(training[development, ], training[validation, ], records)
    fitted <- glmnet::glmnet(matrix$train, y_train[development],
      family = family,
      alpha = 1, lambda = penalties, standardize = TRUE
    )
    validation_predictions[validation, ] <- predict(fitted,
      newx = matrix$test,
      s = penalties, type = "response"
    )
  }
  if (family == "binomial") {
    validation_loss <- apply(validation_predictions, 2, function(p) {
      -mean(stats::dbinom(y_train, size = 1, prob = p, log = TRUE))
    })
  } else {
    validation_predictions <- pmax(validation_predictions, 0)
    validation_loss <- apply(validation_predictions, 2, function(p) mlr3measures::mse(y_train, p))
  }
  selected <- which.min(validation_loss)
  matrix <- prepare_matrix(training, testing, records)
  fitted <- glmnet::glmnet(matrix$train, y_train,
    family = family,
    alpha = 1, lambda = penalties, standardize = TRUE
  )
  prediction <- as.numeric(predict(fitted, newx = matrix$test, s = penalties[selected], type = "response"))
  threshold <- NA_real_
  if (family == "binomial") {
    roc <- pROC::roc(y_train, validation_predictions[, selected],
      levels = c(0, 1),
      direction = "<", quiet = TRUE
    )
    threshold <- pROC::coords(roc, "best",
      best.method = "youden",
      ret = "threshold", transpose = FALSE
    )$threshold[1]
  } else {
    prediction <- pmax(0, prediction)
  }
  coefficients <- as.matrix(stats::coef(fitted, s = penalties[selected]))
  list(
    predictions = tibble::tibble(
      member_id = testing$member_id, truth = y_test,
      prediction = prediction, baseline_mean = mean(y_train),
      baseline_median = stats::median(y_train)
    ),
    threshold = threshold, lambda = penalties[selected],
    tuning = tibble::tibble(lambda = penalties, loss = validation_loss),
    coefficients = tibble::tibble(term = rownames(coefficients), coefficient = coefficients[, 1]),
    train_ids = train_ids, test_ids = test_ids
  )
}

classification_metrics <- function(data, threshold) {
  truth <- factor(data$truth, levels = c(0, 1))
  response <- factor(as.integer(data$prediction >= threshold), levels = c(0, 1))
  c(
    roc_auc = mlr3measures::auc(truth, data$prediction, positive = "1"),
    pr_auc = mlr3measures::prauc(truth, data$prediction, positive = "1"),
    brier = mlr3measures::bbrier(truth, data$prediction, positive = "1"),
    accuracy = mlr3measures::acc(truth, response),
    sensitivity = mlr3measures::tpr(truth, response, positive = "1"),
    specificity = mlr3measures::tnr(truth, response, positive = "1"),
    precision = mlr3measures::ppv(truth, response, positive = "1"),
    mean_prediction = mean(data$prediction), prevalence = mean(data$truth)
  )
}

regression_metrics <- function(data) {
  c(
    rmse = mlr3measures::rmse(data$truth, data$prediction),
    mae = mlr3measures::mae(data$truth, data$prediction),
    mean_baseline_rmse = mlr3measures::rmse(data$truth, data$baseline_mean),
    median_baseline_mae = mlr3measures::mae(data$truth, data$baseline_median),
    mse_improvement = 1 - mlr3measures::mse(data$truth, data$prediction) /
      mlr3measures::mse(data$truth, data$baseline_mean)
  )
}

bootstrap_metrics <- function(data, statistic, seed, draws = 1000) {
  point <- statistic(data)
  set.seed(seed)
  samples <- boot::boot(data, statistic = function(data, indices) statistic(data[indices, ]), R = draws)
  interval <- apply(samples$t, 2, stats::quantile, probs = c(0.025, 0.975), na.rm = TRUE)
  tibble::tibble(
    metric = names(point), estimate = unname(point),
    lower = interval[1, ], upper = interval[2, ],
    valid_draws = colSums(is.finite(samples$t)), draws = draws,
    interval_method = "percentile_bootstrap"
  )
}

classification_intervals <- function(data, threshold, seed) {
  result <- bootstrap_metrics(data, function(x) classification_metrics(x, threshold), seed)
  positive <- data$truth == 1
  flagged <- data$prediction >= threshold
  successes <- c(
    accuracy = sum(positive == flagged), sensitivity = sum(positive & flagged),
    specificity = sum(!positive & !flagged), precision = sum(positive & flagged),
    prevalence = sum(positive)
  )
  trials <- c(
    accuracy = nrow(data), sensitivity = sum(positive), specificity = sum(!positive),
    precision = sum(flagged), prevalence = nrow(data)
  )
  for (metric in names(successes)) {
    row <- match(metric, result$metric)
    interval <- if (trials[[metric]] > 0) {
      stats::binom.test(successes[[metric]], trials[[metric]])$conf.int
    } else {
      c(NA_real_, NA_real_)
    }
    result$lower[row] <- interval[1]
    result$upper[row] <- interval[2]
    result$valid_draws[row] <- NA_integer_
    result$draws[row] <- NA_integer_
    result$interval_method[row] <- "exact_binomial"
  }
  result
}

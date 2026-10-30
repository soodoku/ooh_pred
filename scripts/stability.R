source("scripts/config.R")
data <- readRDS("data/derived/prepared.rds")
metrics <- c("roc_auc", "pr_auc", "brier")
split_seeds <- seed + 0:19

evaluate_split <- function(split_seed) {
  set.seed(split_seed)
  training <- data$outcomes |>
    dplyr::mutate(row_id = dplyr::row_number(), stratum = placement + repeat_placement) |>
    dplyr::group_by(stratum) |>
    dplyr::slice_sample(prop = 0.8) |>
    dplyr::pull(row_id) |>
    sort()
  testing <- setdiff(seq_len(nrow(data$features)), training)
  stopifnot(length(intersect(training, testing)) == 0)
  results <- list()
  skills <- list()
  differences <- list()
  for (outcome in c("placement", "repeat_placement")) {
    fits <- lapply(c("full", "core"), function(model) {
      fit_lasso(data$features, data$outcomes[[outcome]], training, testing,
        records = if (model == "full") data$records else NULL,
        seed = split_seed
      )
    })
    names(fits) <- c("full", "core")
    for (model in names(fits)) {
      fit <- fits[[model]]
      values <- classification_metrics(fit$predictions, fit$threshold)[metrics]
      results[[paste(outcome, model)]] <- tibble::tibble(
        split_seed = split_seed, outcome = outcome, model = model,
        metric = names(values), estimate = unname(values),
        n_train = length(training), n_test = length(testing),
        events = sum(fit$predictions$truth)
      )
    }
    if (split_seed == seed) {
      saved <- readRDS(file.path("data/derived", paste0(outcome, "_fit.rds")))
      stopifnot(isTRUE(all.equal(saved$predictions, fits$full$predictions)))
      skills[[outcome]] <- bootstrap_metrics(fits$full$predictions, function(x) {
        model_brier <- mlr3measures::mse(x$truth, x$prediction)
        baseline_brier <- mlr3measures::mse(x$truth, x$baseline_mean)
        c(brier_skill = 1 - model_brier / baseline_brier)
      }, seed) |>
        dplyr::mutate(outcome = outcome)
      paired <- fits$full$predictions |>
        dplyr::left_join(
          dplyr::select(fits$core$predictions, member_id, core_prediction = prediction),
          by = "member_id", relationship = "one-to-one"
        )
      differences[[outcome]] <- bootstrap_metrics(paired, function(x) {
        full <- classification_metrics(x, 0.5)[metrics]
        x$prediction <- x$core_prediction
        core <- classification_metrics(x, 0.5)[metrics]
        (full - core) * c(1, 1, -1)
      }, seed) |>
        dplyr::mutate(outcome = outcome)
    }
  }
  list(
    performance = dplyr::bind_rows(results), skill = dplyr::bind_rows(skills),
    differences = dplyr::bind_rows(differences)
  )
}

cores <- if (.Platform$OS.type == "windows") 1L else 2L
message("Evaluating 20 fixed stratified splits using ", cores, " workers")
results <- parallel::mclapply(split_seeds, evaluate_split, mc.cores = cores, mc.set.seed = FALSE)
stopifnot(!any(vapply(results, inherits, logical(1), "try-error")))
performance <- dplyr::bind_rows(lapply(results, `[[`, "performance"))
readr::write_csv(performance, "tabs/split_stability.csv")
readr::write_csv(dplyr::bind_rows(lapply(results, `[[`, "skill")), "tabs/brier_skill.csv")
readr::write_csv(dplyr::bind_rows(lapply(results, `[[`, "differences")), "tabs/paired_comparison.csv")
comparison <- performance |>
  dplyr::select(split_seed, outcome, model, metric, estimate) |>
  tidyr::pivot_wider(names_from = model, values_from = estimate) |>
  dplyr::mutate(gain = dplyr::if_else(metric == "brier", core - full, full - core))
summary <- comparison |>
  dplyr::group_by(outcome, metric) |>
  dplyr::summarise(
    splits = dplyr::n(), median_gain = stats::median(gain),
    min_gain = min(gain), max_gain = max(gain), full_better = sum(gain > 0),
    .groups = "drop"
  )
readr::write_csv(summary, "tabs/split_comparison.csv")

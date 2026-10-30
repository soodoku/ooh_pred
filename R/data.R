read_source <- function(file, columns = NULL) {
  path <- file.path("data", file)
  delim <- if (grepl("csv$", file)) "," else "|"
  header <- readr::read_delim(
    path,
    delim = delim, n_max = 0, col_types = readr::cols(.default = "c"),
    show_col_types = FALSE, name_repair = "minimal"
  )
  source_names <- names(header)
  clean_names <- tolower(source_names)
  clean_names[clean_names == "memberid"] <- "member_id"
  selected <- if (is.null(columns)) source_names else source_names[clean_names %in% columns]
  if (!is.null(columns)) stopifnot(all(columns %in% clean_names))
  data <- readr::read_delim(
    path,
    delim = delim, col_types = readr::cols(.default = "c"),
    col_select = dplyr::all_of(selected),
    na = c("", "NA", "NULL"), show_col_types = FALSE, progress = FALSE,
    name_repair = "minimal"
  )
  stopifnot(nrow(readr::problems(data)) == 0)
  names(data) <- tolower(names(data))
  names(data)[names(data) == "memberid"] <- "member_id"
  if (!is.null(columns)) data <- dplyr::select(data, dplyr::all_of(columns))
  data
}

parse_date <- function(x, short_year = FALSE) {
  as.Date(x, format = if (short_year) "%m/%d/%y" else "%m/%d/%Y")
}

mean_observed <- function(x) {
  if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
}

score_module <- function(data, special_zero = TRUE) {
  values <- as.matrix(dplyr::mutate(data, dplyr::across(dplyr::everything(), as.numeric)))
  special <- values %in% c(-1, 4)
  values[special] <- if (special_zero) 0 else NA_real_
  stopifnot(all(is.na(values) | values %in% 0:3))
  score <- rowMeans(values, na.rm = TRUE)
  score[is.nan(score)] <- NA_real_
  score
}

score_cans <- function(data, special_zero = TRUE) {
  module_prefixes <- c(
    life_functioning = "rbldf_", caregiver_youth_needs = "rbcgn_",
    caregiver_strengths = "rbcgs_", juvenile_justice = "rbjj_",
    substance_use = "rbsud_", developmental_needs = "rbdnm_",
    trauma = "rbtm_", youth_strengths = "rbcs_", youth_risk = "rbcrb_",
    acculturation = "rbacc_", sexual_development = "rbsrp_",
    sex_related_problems = "rbsd_"
  )
  scores <- data["member_id"]
  for (module in names(module_prefixes)) {
    items <- dplyr::select(data, dplyr::starts_with(module_prefixes[[module]]))
    scores[[module]] <- score_module(items, special_zero)
  }
  scores
}

summarize_cans <- function(data, special_zero = TRUE) {
  score_cans(data, special_zero) |>
    dplyr::group_by(member_id) |>
    dplyr::summarise(dplyr::across(dplyr::everything(), mean_observed),
      cans_records = dplyr::n(), .groups = "drop"
    )
}

union_days <- function(start, end) {
  keep <- !is.na(start) & !is.na(end) & end >= start
  start <- as.numeric(start[keep])
  end <- as.numeric(end[keep])
  if (!length(start)) {
    return(0)
  }
  order <- order(start, end)
  start <- start[order]
  end <- end[order]
  previous_end <- c(-Inf, head(cummax(end), -1))
  sum(pmax(0, end - pmax(start, previous_end)))
}

build_outcomes <- function(members, admissions, origin, end) {
  stopifnot(end > origin, !anyDuplicated(members$member_id))
  admissions <- admissions |>
    dplyr::mutate(valid_stay = discharge_date >= admission_date)
  starts <- admissions |>
    dplyr::filter(admission_date >= origin, admission_date < end) |>
    dplyr::group_by(member_id) |>
    dplyr::summarise(
      placement = 1L,
      repeat_placement = as.integer(dplyr::n_distinct(admission_date) >= 2),
      .groups = "drop"
    )
  days <- admissions |>
    dplyr::filter(
      admission_date < end,
      discharge_date > origin | !valid_stay
    ) |>
    dplyr::group_by(member_id) |>
    dplyr::summarise(
      invalid_stay = any(!valid_stay),
      recorded_days = union_days(
        pmax(admission_date, origin),
        pmin(discharge_date, end)
      ), .groups = "drop"
    )
  members |>
    dplyr::select(member_id) |>
    dplyr::left_join(starts, by = "member_id", relationship = "one-to-one") |>
    dplyr::left_join(days, by = "member_id", relationship = "one-to-one") |>
    dplyr::mutate(
      placement = tidyr::replace_na(placement, 0L),
      repeat_placement = tidyr::replace_na(repeat_placement, 0L),
      invalid_stay = tidyr::replace_na(invalid_stay, FALSE),
      recorded_days = dplyr::if_else(invalid_stay, NA_real_,
        tidyr::replace_na(recorded_days, 0)
      )
    )
}

record_features <- function(records, members, vocabulary = NULL, min_members = 25) {
  records <- records |>
    dplyr::filter(!is.na(term), nzchar(term)) |>
    dplyr::distinct(member_id, term)
  if (is.null(vocabulary)) {
    vocabulary <- records |>
      dplyr::filter(member_id %in% members$member_id) |>
      dplyr::count(term) |>
      dplyr::filter(n >= min_members) |>
      dplyr::arrange(term) |>
      dplyr::pull(term)
  }
  # Absence here means no matching record in this extract, not clinical absence.
  selected <- records |>
    dplyr::filter(term %in% vocabulary) |>
    dplyr::mutate(value = 1) |>
    tidyr::pivot_wider(names_from = term, values_from = value, values_fill = 0)
  result <- members |>
    dplyr::select(member_id) |>
    dplyr::left_join(selected, by = "member_id", relationship = "one-to-one")
  for (term in vocabulary) {
    if (!term %in% names(result)) result[[term]] <- 0
  }
  result <- result |>
    dplyr::mutate(dplyr::across(-member_id, ~ tidyr::replace_na(.x, 0)))
  list(data = result, vocabulary = vocabulary)
}

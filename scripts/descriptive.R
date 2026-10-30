source("scripts/config.R")
data <- readRDS("data/derived/prepared.rds")
split <- readRDS("data/derived/split.rds")
training <- dplyr::filter(data$features, member_id %in% split$training)
selected <- record_features(data$records, training,
  min_members = max(25, ceiling(nrow(training) * 0.005))
)
features <- record_features(data$records, data$features, selected$vocabulary)$data |>
  dplyr::left_join(data$outcomes, by = "member_id", relationship = "one-to-one") |>
  dplyr::select(member_id, placement, dplyr::all_of(selected$vocabulary)) |>
  tidyr::pivot_longer(-c(member_id, placement), names_to = "term", values_to = "present")
summary <- features |>
  dplyr::group_by(term, placement) |>
  dplyr::summarise(n = dplyr::n(), events = sum(present), proportion = mean(present), .groups = "drop") |>
  tidyr::pivot_wider(names_from = placement, values_from = c(n, events, proportion)) |>
  dplyr::mutate(
    difference = proportion_1 - proportion_0,
    prevalence = (events_0 + events_1) / (n_0 + n_1),
    source = sub("_.*", "", term), code = sub("^[^_]+_", "", term)
  )
lookup <- read_source("lookup_diagnosis.txt") |>
  dplyr::mutate(code_key = gsub(".", "", diagcode, fixed = TRUE)) |>
  dplyr::filter(!is.na(diagdesc)) |>
  dplyr::group_by(code_key) |>
  dplyr::summarise(
    description = if (dplyr::n_distinct(diagdesc) == 1) dplyr::first(diagdesc) else NA_character_,
    .groups = "drop"
  )
source_labels <- read_source("member_diag.txt", c("diagcode", "diagdesc", "createdate")) |>
  dplyr::filter(parse_date(createdate) < origin, !is.na(diagdesc)) |>
  dplyr::count(diagcode, diagdesc, name = "records") |>
  dplyr::arrange(diagcode, dplyr::desc(records), diagdesc) |>
  dplyr::group_by(diagcode) |>
  dplyr::slice_head(n = 1) |>
  dplyr::ungroup() |>
  dplyr::transmute(code = diagcode, source_label = diagdesc)
summary <- summary |>
  dplyr::left_join(source_labels, by = "code", relationship = "many-to-one") |>
  dplyr::mutate(code_key = gsub(".", "", code, fixed = TRUE)) |>
  dplyr::left_join(lookup, by = "code_key", relationship = "many-to-one") |>
  dplyr::mutate(
    description = dplyr::coalesce(description, source_label),
    label = dplyr::if_else(
      source == "diagnosis" & !is.na(description),
      paste0(code, ": ", description), code
    )
  )
readr::write_csv(summary, "tabs/feature_descriptive.csv")
demographics <- data$features |>
  dplyr::summarise(
    unknown_race = mean(is.na(white)),
    age = mean(age), female = mean(female), white = mean(white, na.rm = TRUE),
    black = mean(black, na.rm = TRUE),
    hispanic = mean(hispanic),
    ethnicity_other = mean(ethnicity_other)
  ) |>
  tidyr::pivot_longer(dplyr::everything(), names_to = "variable", values_to = "value")
readr::write_csv(demographics, "tabs/member_characteristics.csv")

prior <- data$admissions |>
  dplyr::filter(admission_date < origin, created_date < origin) |>
  dplyr::group_by(member_id) |>
  dplyr::summarise(prior_placements = dplyr::n_distinct(admission_date), .groups = "drop")
relationships <- data$features |>
  dplyr::left_join(data$outcomes, by = "member_id", relationship = "one-to-one") |>
  dplyr::left_join(prior, by = "member_id", relationship = "one-to-one") |>
  dplyr::mutate(prior_placements = tidyr::replace_na(prior_placements, 0L))
score_bands <- c("0 to <0.5", "0.5 to <1", "1 to 3")
groups <- dplyr::bind_rows(
  relationships |>
    dplyr::select(placement, life_functioning, youth_risk, youth_strengths) |>
    tidyr::pivot_longer(-placement, names_to = "variable") |>
    dplyr::mutate(group = cut(value,
      breaks = c(0, 0.5, 1, Inf), right = FALSE, labels = score_bands
    )) |>
    dplyr::mutate(group = as.character(group)) |>
    dplyr::select(variable, group, placement),
  relationships |>
    dplyr::transmute(
      variable = "prior_placements", placement,
      group = dplyr::case_when(prior_placements == 0 ~ "0", prior_placements == 1 ~ "1", TRUE ~ "2 or more")
    ),
  relationships |>
    dplyr::transmute(
      variable = "cans_records", placement,
      group = dplyr::case_when(cans_records == 1 ~ "1", cans_records <= 4 ~ "2 to 4", TRUE ~ "5 or more")
    ),
  relationships |>
    dplyr::transmute(
      variable = "age", placement,
      group = as.character(cut(age,
        breaks = c(-Inf, 12, 16, Inf), right = FALSE,
        labels = c("Under 12", "12 to <16", "16 or older")
      ))
    )
) |>
  dplyr::mutate(group = tidyr::replace_na(group, "Missing")) |>
  dplyr::group_by(variable, group) |>
  dplyr::summarise(n = dplyr::n(), events = sum(placement), risk = mean(placement), .groups = "drop")
intervals <- t(vapply(seq_len(nrow(groups)), function(i) {
  stats::binom.test(groups$events[i], groups$n[i])$conf.int
}, numeric(2)))
groups$lower <- intervals[, 1]
groups$upper <- intervals[, 2]
readr::write_csv(groups, "tabs/descriptive_relationships.csv")
medication_order <- data$records |>
  dplyr::filter(member_id %in% split$training, grepl("^medication_", term)) |>
  dplyr::count(term, sort = TRUE) |>
  dplyr::filter(term %in% selected$vocabulary) |>
  dplyr::arrange(dplyr::desc(n), term) |>
  dplyr::slice_head(n = 8) |>
  dplyr::transmute(term, development_youth = n)
medication_display <- summary |>
  dplyr::inner_join(medication_order, by = "term", relationship = "one-to-one") |>
  dplyr::arrange(dplyr::desc(development_youth), term) |>
  dplyr::mutate(display_order = dplyr::row_number())
readr::write_csv(medication_display, "tabs/medication_descriptive.csv")

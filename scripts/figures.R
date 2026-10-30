source("scripts/config.R")
months <- readr::read_csv("tabs/admission_months.csv", show_col_types = FALSE)
peak <- max(months$admissions)
short_date <- function(x) sub(" 0", " ", format(x, "%b %d, %Y"), fixed = TRUE)
p <- ggplot2::ggplot(months, ggplot2::aes(month, admissions)) +
  ggplot2::annotate("rect",
    xmin = min(months$month), xmax = origin,
    ymin = -Inf, ymax = Inf, fill = "grey94"
  ) +
  ggplot2::annotate("rect",
    xmin = origin, xmax = end,
    ymin = -Inf, ymax = Inf, fill = "#e6f0f8"
  ) +
  ggplot2::geom_line(colour = "grey25", linewidth = 0.6) +
  ggplot2::geom_vline(xintercept = origin, linetype = "dashed", colour = "#08519c") +
  ggplot2::geom_vline(xintercept = end, colour = "#08519c", linewidth = 0.4) +
  ggplot2::annotate("text",
    x = min(months$month) + as.numeric(origin - min(months$month)) / 2,
    y = peak * 1.34,
    label = paste0(
      "Available predictor history\nBefore ", short_date(origin),
      "\nLength varies by source and youth"
    ),
    size = 3.2, colour = "grey20", lineheight = 1.15
  ) +
  ggplot2::annotate("text",
    x = origin + as.numeric(end - origin) / 2, y = peak * 1.34,
    label = paste0(
      "Admission outcome window\n", as.integer(end - origin), " days\n",
      short_date(origin), " - ", short_date(end - 1)
    ),
    size = 3.2, colour = "#08519c", lineheight = 1.15
  ) +
  ggplot2::annotate("text",
    x = origin - 35, y = peak * 1.12,
    label = "Information cutoff / forecast origin\nLead gap = 0 days", hjust = 1,
    size = 3, colour = "#08519c", lineheight = 1.15
  ) +
  ggplot2::scale_x_date(
    breaks = seq(as.Date(paste0(format(min(months$month), "%Y"), "-01-01")),
      end,
      by = "year"
    ),
    date_labels = "%Y", limits = c(min(months$month), end),
    expand = ggplot2::expansion(mult = 0.01)
  ) +
  ggplot2::scale_y_continuous(
    breaks = scales::breaks_pretty(n = 4)(c(0, peak)), limits = c(0, peak * 1.52),
    expand = ggplot2::expansion(mult = 0)
  ) +
  ggplot2::labs(
    x = "Admission month", y = "Recorded admissions",
    caption = "80% development / 20% test youth; both groups use the same calendar windows."
  ) +
  theme_paper() +
  ggplot2::theme(plot.caption = ggplot2::element_text(size = 9))
save_figure(p, "admissions", height = 4.2)
calibration <- dplyr::bind_rows(lapply(c("placement", "repeat_placement"), function(outcome) {
  readr::read_csv(file.path("tabs", paste0(outcome, "_calibration.csv")), show_col_types = FALSE)
})) |>
  dplyr::mutate(outcome = factor(outcome,
    levels = c("placement", "repeat_placement"),
    labels = unname(outcome_labels[c("placement", "repeat_placement")])
  ))
panel_limits <- calibration |>
  dplyr::group_by(outcome) |>
  dplyr::summarise(limit = ceiling(max(upper, predicted) / 0.01) * 0.01, .groups = "drop")
p <- ggplot2::ggplot(calibration, ggplot2::aes(predicted, observed)) +
  ggplot2::geom_abline(slope = 1, intercept = 0, colour = "grey60", linetype = "dashed") +
  ggplot2::geom_errorbar(ggplot2::aes(ymin = lower, ymax = upper), width = 0, colour = "grey30") +
  ggplot2::geom_point(colour = "#08519c", size = 2) +
  ggplot2::geom_blank(data = panel_limits, ggplot2::aes(limit, limit), inherit.aes = FALSE) +
  ggplot2::facet_wrap(~outcome, nrow = 1, scales = "free") +
  ggplot2::scale_x_continuous(labels = scales::label_percent(accuracy = 0.1), limits = c(0, NA)) +
  ggplot2::scale_y_continuous(labels = scales::label_percent(accuracy = 0.1), limits = c(0, NA)) +
  ggplot2::labs(x = "Mean predicted probability", y = "Observed event proportion") +
  theme_paper() +
  ggplot2::theme(aspect.ratio = 1)
plotted <- ggplot2::ggplot_build(p)
stopifnot(!anyNA(plotted$data[[2]]$ymax), nrow(plotted$data[[2]]) == nrow(calibration))
save_figure(p, "calibration", height = 3.8)
descriptive <- readr::read_csv("tabs/descriptive.csv", show_col_types = FALSE) |>
  dplyr::filter(variable %in% names(module_labels)) |>
  dplyr::mutate(
    variable = unname(module_labels[variable]),
    group = factor(placement, levels = c(0, 1), labels = c("No recorded placement", "Recorded placement"))
  )
p <- ggplot2::ggplot(descriptive, ggplot2::aes(mean, reorder(variable, mean), colour = group)) +
  ggplot2::geom_line(ggplot2::aes(group = variable), colour = "grey70") +
  ggplot2::geom_point(size = 2) +
  ggplot2::scale_colour_manual(values = c("grey35", "#08519c")) +
  ggplot2::labs(x = "Mean CANS module score (0-3)", y = NULL, colour = NULL) +
  theme_paper()
save_figure(p, "cans", height = 5)

relationships <- readr::read_csv("tabs/descriptive_relationships.csv", show_col_types = FALSE)
relationship_labels <- c(
  life_functioning = "Life domain functioning", youth_risk = "Youth risk behavior",
  youth_strengths = "Youth strengths", prior_placements = "Prior recorded admission starts",
  cans_records = "Pre-origin CANS assessments", age = "Age at forecast origin"
)
group_order <- c(
  "0 to <0.5", "0.5 to <1", "1 to 3", "Missing",
  "0", "1", "2 or more", "2 to 4", "5 or more", "Under 12", "12 to <16", "16 or older"
)
relationships <- relationships |>
  dplyr::mutate(
    variable = factor(variable, levels = names(relationship_labels), labels = unname(relationship_labels)),
    group = factor(group, levels = group_order)
  ) |>
  dplyr::arrange(variable, group) |>
  dplyr::mutate(
    label = paste0(group, " (n = ", scales::comma(n), ")"),
    label = factor(label, levels = rev(unique(label)))
  )
p <- ggplot2::ggplot(relationships, ggplot2::aes(risk, label)) +
  ggplot2::geom_errorbar(ggplot2::aes(xmin = lower, xmax = upper), width = 0, orientation = "y") +
  ggplot2::geom_point(size = 2, colour = "#08519c") +
  ggplot2::facet_wrap(~variable, scales = "free_y", ncol = 2) +
  ggplot2::scale_x_continuous(labels = scales::label_percent(accuracy = 1), limits = c(0, NA)) +
  ggplot2::labs(x = "Youth with a recorded placement in the prediction window", y = NULL) +
  theme_paper() +
  ggplot2::theme(axis.text.y = ggplot2::element_text(size = 8))
save_figure(p, "descriptive_relationships", height = 7, width = 8)
medications <- readr::read_csv("tabs/medication_descriptive.csv", show_col_types = FALSE) |>
  dplyr::left_join(readr::read_csv("docs/medication_display.csv", show_col_types = FALSE),
    by = "code", relationship = "one-to-one"
  ) |>
  dplyr::mutate(label = dplyr::coalesce(display_label, label)) |>
  dplyr::arrange(display_order) |>
  dplyr::mutate(
    label = vapply(label, function(x) paste(strwrap(x, width = 40), collapse = "\n"), character(1)),
    label = factor(label, levels = rev(unique(label)))
  ) |>
  tidyr::pivot_longer(c(proportion_0, proportion_1), names_to = "group", values_to = "proportion") |>
  dplyr::mutate(group = factor(group,
    levels = c("proportion_0", "proportion_1"),
    labels = c("No recorded placement", "Recorded placement")
  ))
p <- ggplot2::ggplot(medications, ggplot2::aes(proportion, label, colour = group)) +
  ggplot2::geom_line(ggplot2::aes(group = label), colour = "grey70") +
  ggplot2::geom_point(size = 2) +
  ggplot2::scale_colour_manual(values = c("grey35", "#08519c")) +
  ggplot2::scale_x_continuous(labels = scales::label_percent(accuracy = 1), limits = c(0, NA)) +
  ggplot2::labs(x = "Youth with a matching pre-origin medication record", y = NULL, colour = NULL) +
  theme_paper() +
  ggplot2::theme(axis.text.y = ggplot2::element_text(size = 9))
save_figure(p, "medications", height = 5.5, width = 8)

window <- readr::read_csv("tabs/rolling_windows.csv", show_col_types = FALSE) |>
  dplyr::filter(setting == "rolling_main") |>
  dplyr::slice_head(n = 1)
timeline <- tibble::tibble(
  sample = rep(c("Earlier development youth", "Later test youth"), each = 3),
  period = rep(c("History", "Lead gap", "Outcome window"), 2),
  start = c(
    window$train_cutoff - window$lookback, window$train_cutoff, window$train_start,
    window$cutoff - window$lookback, window$cutoff, window$target_start
  ),
  end = c(
    window$train_cutoff, window$train_start, window$train_end,
    window$cutoff, window$target_start, window$target_end
  )
) |>
  dplyr::mutate(
    sample = factor(sample, levels = c("Later test youth", "Earlier development youth")),
    period = factor(period, levels = c("History", "Lead gap", "Outcome window"))
  )
p <- ggplot2::ggplot(timeline, ggplot2::aes(x = start, xend = end, y = sample, yend = sample, colour = period)) +
  ggplot2::geom_segment(linewidth = 10, lineend = "butt") +
  ggplot2::geom_vline(xintercept = window$cutoff, linetype = "dotted", colour = "grey30") +
  ggplot2::annotate("text",
    x = window$cutoff, y = 2.45,
    label = "Later information cutoff", hjust = 1.05, size = 3
  ) +
  ggplot2::scale_colour_manual(
    values = c("grey55", "#d8892a", "#08519c"),
    labels = c(
      paste0(window$lookback, "-day history"), paste0(window$gap, "-day gap"),
      paste0(window$horizon, "-day outcome")
    )
  ) +
  ggplot2::scale_x_date(
    breaks = seq(lubridate::ceiling_date(min(timeline$start), "month"), max(timeline$end), by = "6 months"),
    date_labels = "%b %Y", limits = range(c(timeline$start, timeline$end)),
    expand = ggplot2::expansion(mult = 0.02)
  ) +
  ggplot2::scale_y_discrete(expand = ggplot2::expansion(add = c(0.5, 0.8))) +
  ggplot2::labs(x = NULL, y = NULL, colour = NULL) +
  theme_paper()
save_figure(p, "rolling_timeline", height = 2.6, width = 8)

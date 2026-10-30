theme_paper <- function() {
  ggplot2::theme_minimal(base_size = 11, base_family = "sans") +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.y = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold"),
      legend.position = "top", axis.text = ggplot2::element_text(colour = "grey15"),
      plot.caption = ggplot2::element_text(hjust = 0)
    )
}

save_figure <- function(plot, name, width = 6.5, height = 4) {
  for (extension in c("pdf", "png")) {
    ggplot2::ggsave(file.path("figs", paste0(name, ".", extension)), plot,
      width = width, height = height, dpi = 180, bg = "white"
    )
  }
}

paper_table <- function(data, caption = NULL, digits = 2, label = NULL) {
  if (knitr::is_latex_output()) {
    knitr::kable(data,
      format = "latex", booktabs = TRUE, digits = digits,
      format.args = list(big.mark = ","),
      caption = caption, label = label, linesep = "", longtable = nrow(data) > 20
    ) |>
      kableExtra::kable_styling(
        font_size = 9,
        latex_options = if (nrow(data) > 20) "repeat_header" else c("HOLD_position", "scale_down")
      )
  } else {
    knitr::kable(data,
      format = "html", digits = digits, caption = caption, label = label,
      format.args = list(big.mark = ",")
    ) |>
      kableExtra::kable_styling(full_width = FALSE, font_size = 14)
  }
}

outcome_labels <- c(
  placement = "Recorded placement", repeat_placement = "Multiple recorded placements",
  recorded_days = "Recorded occupied days"
)
module_labels <- c(
  life_functioning = "Life domain functioning",
  caregiver_youth_needs = "Caregiver and youth needs", caregiver_strengths = "Caregiver strengths",
  juvenile_justice = "Juvenile justice", substance_use = "Substance use",
  developmental_needs = "Developmental needs", trauma = "Trauma",
  youth_strengths = "Youth strengths", youth_risk = "Youth risk behavior",
  acculturation = "Acculturation", sexual_development = "Sexual development",
  sex_related_problems = "Sex-related problems"
)

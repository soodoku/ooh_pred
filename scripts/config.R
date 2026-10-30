options(stringsAsFactors = FALSE, readr.show_col_types = FALSE)
origin <- as.Date("2015-01-01")
end <- as.Date("2016-11-03")
seed <- 20261029L
for (path in c("data/derived", "tabs", "figs", "docs")) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
}
for (file in list.files("R", pattern = "[.]R$", full.names = TRUE)) source(file)

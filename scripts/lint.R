files <- c(
  list.files("R", pattern = "[.]R$", full.names = TRUE),
  list.files("scripts", pattern = "[.]R$", full.names = TRUE),
  list.files("tests", pattern = "[.]R$", full.names = TRUE, recursive = TRUE)
)
files <- c(files, list.files("ms", pattern = "[.]Rmd$", full.names = TRUE))
issues <- unlist(lapply(files, lintr::lint), recursive = FALSE)
if (length(issues)) {
  print(issues)
  stop("R lint failed")
}

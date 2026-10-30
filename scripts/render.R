source("scripts/config.R")
for (document in c("main", "supplement")) {
  for (format in c("pdf_document", "html_document")) {
    rmarkdown::render(file.path("ms", paste0(document, ".Rmd")),
      output_format = format,
      output_file = if (document == "main" && format == "pdf_document") "report.pdf" else NULL,
      knit_root_dir = normalizePath("."), envir = new.env(), quiet = TRUE
    )
  }
}
pdf_parts <- file.path("ms", c("report.pdf", "supplement.pdf"))
ghostscript <- Sys.which("gs")
if (!nzchar(ghostscript)) stop("Install Ghostscript to build the combined report PDF.")
status <- system2(ghostscript, c(
  "-q", "-dNOPAUSE", "-dBATCH", "-sDEVICE=pdfwrite", "-dAutoRotatePages=/None",
  "-sOutputFile=ms/main.pdf", shQuote(pdf_parts)
))
stopifnot(status == 0L)
stopifnot(qpdf::pdf_length("ms/main.pdf") == sum(vapply(pdf_parts, qpdf::pdf_length, integer(1))))

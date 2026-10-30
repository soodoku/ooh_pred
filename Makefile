RSCRIPT ?= Rscript
.NOTPARALLEL:
.PHONY: all analysis paper check test lint format restore ci-docker
all: check
analysis:
	$(RSCRIPT) scripts/prepare.R
	$(RSCRIPT) scripts/audit.R
	$(RSCRIPT) scripts/estimate.R
	$(RSCRIPT) scripts/targeting.R
	$(RSCRIPT) scripts/stability.R
	$(RSCRIPT) scripts/rolling.R
	$(RSCRIPT) scripts/descriptive.R
	$(RSCRIPT) scripts/figures.R
paper:
	$(RSCRIPT) scripts/render.R
test:
	$(RSCRIPT) scripts/test.R
lint:
	$(RSCRIPT) scripts/lint.R
format:
	$(RSCRIPT) -e 'styler::cache_deactivate(); styler::style_dir("R"); styler::style_dir("scripts"); styler::style_dir("tests"); styler::style_file("ms/main.Rmd"); styler::style_file("ms/supplement.Rmd")'
check: analysis test lint paper
restore:
	$(RSCRIPT) -e 'renv::restore(prompt = FALSE)'
ci-docker:
	docker run --rm -v "$(CURDIR):/project" -w /project rocker/verse:4.6.0 Rscript -e 'renv::restore(prompt = FALSE); quit(status = system("make check"))'

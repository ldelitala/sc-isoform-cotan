# Only register the styler transformer when styler is actually installed: this file is
# sourced by Rscript in every working directory, including CI and minimal containers.
if (requireNamespace("styler", quietly = TRUE)) {
  options(styler.addins_style_transformer = styler::tidyverse_style(indent_by = 2))
}

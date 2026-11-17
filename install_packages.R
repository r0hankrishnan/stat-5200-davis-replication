# Installs the R packages this replication needs.
# Tested with R 4.3.3, haven 2.5.4, dplyr 1.1.4, fixest 0.14.2, ggplot2 3.4.4.
# systemfonts is optional: 05_slide_figures.R uses it to find Times New Roman.
pkgs <- c("haven", "dplyr", "fixest", "ggplot2")
missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")

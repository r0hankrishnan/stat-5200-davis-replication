# =============================================================================
# 00_setup.R
# Packages, paths and helper functions shared by every script.
# All scripts assume the working directory is the repository root.
# =============================================================================

suppressPackageStartupMessages({
  library(haven)
  library(dplyr)
  library(fixest)
  library(ggplot2)
})
setFixest_notes(FALSE)

RAW     <- file.path("data", "raw")
DERIVED <- file.path("data", "derived")
TABLES  <- file.path("output", "tables")
FIGURES <- file.path("output", "figures")
for (d in c(DERIVED, TABLES, FIGURES)) dir.create(d, showWarnings = FALSE, recursive = TRUE)

# Read a Stata file as a plain data frame without value labels
read_raw <- function(f) as.data.frame(zap_labels(read_dta(file.path(RAW, f))))

# Stata treats a missing value as larger than every number. These helpers copy
# that behavior so filters keep or drop exactly the rows Stata would.
gt <- function(x, v) is.na(x) | x > v     # x >  v  (missing counts as true)
ne <- function(x, v) is.na(x) | x != v    # x != v  (missing counts as true)
eq <- function(x, v) !is.na(x) & x == v   # x == v
lt <- function(x, v) !is.na(x) & x < v    # x <  v

# Stata's round(x, y): round x to the nearest multiple of y
sround <- function(x, y) floor(x / y + 0.5) * y

# Build a regression formula from a response and a vector of regressors
fml <- function(y, x) as.formula(paste(y, "~", paste(x, collapse = " + ")))

# Coefficient and standard error, optionally scaled (Stata's lincom k*_b[v])
est <- function(m, v, k = 1) {
  c(b = k * unname(coef(m)[v]), se = abs(k) * unname(se(m)[v]))
}

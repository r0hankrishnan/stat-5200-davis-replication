# =============================================================================
# 04_check_against_paper.R
# Compares every reproduced number with the published value in Davis (2004)
# and stops with an error if any differs by more than its rounding tolerance.
#
# Input : output/tables/table1.csv ... table5.csv, tests/paper_targets.csv
# Output: output/tables/comparison_with_paper.csv
# =============================================================================

source(file.path("R", "00_setup.R"))
targets <- read.csv(file.path("tests", "paper_targets.csv"), stringsAsFactors = FALSE)

# Normalize labels so table rows can be matched to target rows
norm <- function(x) tolower(gsub("[^A-Za-z0-9]", "", x))

lookup <- function(table, row, stat) {
  t <- read.csv(file.path(TABLES, paste0(table, ".csv")), stringsAsFactors = FALSE)
  id <- switch(table,
    table1 = t$county,
    table2 = ifelse(is.na(t$estimate), paste(t$county, t$period), t$period),
    table3 = paste(t$measure, gsub(",", "", t$model)),
    table4 = t$size_sqft,
    table5 = t$prior)
  hit <- which(norm(id) == norm(row))
  if (length(hit) == 0) stop("No row '", row, "' in ", table)
  t[[stat]][hit[1]]
}

targets$replicated <- mapply(lookup, targets$table, targets$row, targets$statistic)
targets$difference <- round(targets$replicated - targets$paper_value, 4)
targets$match      <- abs(targets$difference) <= targets$tolerance + 1e-9

write.csv(targets, file.path(TABLES, "comparison_with_paper.csv"), row.names = FALSE)
cat(sprintf("\nChecked %d published numbers: %d match, %d do not.\n",
            nrow(targets), sum(targets$match), sum(!targets$match)))
if (any(!targets$match)) {
  print(targets[!targets$match, ], row.names = FALSE)
  stop("Replication does not match the paper.")
}
cat("All reproduced numbers match the published paper.\n")

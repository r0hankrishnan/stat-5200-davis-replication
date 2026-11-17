# =============================================================================
# 02_tables.R
# Reproduces Tables 1-5 of Davis (2004).
# Translation of Davis's Results.do (original_code/Results.do).
#
# Input : data/derived/analysis_data.rds
# Output: output/tables/table1.csv ... table5.csv
# =============================================================================

source(file.path("R", "00_setup.R"))
df <- readRDS(file.path(DERIVED, "analysis_data.rds"))

# Regressors used throughout (Results.do wildcards acres* sqft* age* class* t* m*)
tvars <- paste0("t", 1990:2002)
mvars <- paste0("m", 1:12)
cvars <- sprintf("class%02d", c(5, 10, 15, 20, 25, 30, 35, 40, 45))
ctrl  <- c("acres", "acres2", "sqft", "age", "age2")      # house characteristics
full  <- c(ctrl, "cc", cvars, tvars, mvars)               # + county, class, year, month
fe    <- c(paste0("d", tvars), paste0("d", mvars))        # demeaned year and month dummies
cl    <- ~group   # robust SEs clustered by county-month (Stata: robust cluster(group))

# Davis multiplied fixed-effects SEs by 1.34 to correct the degrees of freedom
# (note at the end of Results.do). Both versions are reported.
FE_SE_ADJ <- 1.34

save_table <- function(x, name) {
  write.csv(x, file.path(TABLES, paste0(name, ".csv")), row.names = FALSE)
  cat("\n====", toupper(name), "====\n"); print(x, row.names = FALSE)
}

# --- Table 1: descriptive statistics, sales before 1999 (Results.do 9-12) ----
desc <- function(s, county) {
  v <- c("realsales", "acres", "sqft", "age", "class")
  data.frame(county = county, variable = v,
             mean = sapply(df[s, v], mean, na.rm = TRUE),
             sd   = sapply(df[s, v], sd,   na.rm = TRUE),
             n    = sum(s))
}
table1 <- rbind(desc(df$cc == 1 & df$year < 1999, "Churchill"),
                desc(df$lc == 1 & df$year < 1999, "Lyon"))
table1[, c("mean", "sd")] <- round(table1[, c("mean", "sd")], 2)
save_table(table1, "table1")

df$sqft <- df$sqft / 100   # regressions use floor space in 100s of sq ft

# --- Table 2: difference in differences of mean log price (Results.do 14-22) --
df$post <- as.integer(df$year > 1999)
df$did  <- df$cc * df$post
cells <- df %>%
  group_by(county = ifelse(cc == 1, "Churchill", "Lyon"),
           period = ifelse(post == 1, "2000-2002", "1990-1999")) %>%
  summarise(mean_log_price = mean(logrealsales), sd = sd(logrealsales),
            n = n(), .groups = "drop") %>% as.data.frame()
m2 <- feols(logrealsales ~ cc + post + did, df, vcov = "iid")
table2 <- rbind(
  transform(cells, estimate = NA, se = NA),
  data.frame(county = "Churchill - Lyon", period = "difference in differences",
             mean_log_price = NA, sd = NA, n = nrow(df),
             estimate = coef(m2)["did"], se = se(m2)["did"]))
num <- sapply(table2, is.numeric); table2[num] <- round(table2[num], 3)
save_table(table2, "table2")

# --- Table 3: principal results (Results.do 24-39) ----------------------------
# Effects are scaled to the full rise in each risk measure, as with Davis's
# lincom: 16 leukemia cases, 96 newspaper articles, 0.00003587 Bayesian risk.
ols <- function(v, k = 1) est(feols(fml("logrealsales", c(v, full)), df, cluster = cl), v, k)
fem <- function(v, k = 1) est(feols(fml("dlogrealsales", c(paste0("d", v), fe)), df, cluster = cl),
                              paste0("d", v), k)
rows <- list(
  c(measure = "Linear spline", model = "OLS, house characteristics only",
    est(feols(fml("logrealsales", c("spline", ctrl)), df, cluster = cl), "spline")),
  c(measure = "Linear spline",      model = "OLS, full controls", ols("spline")),
  c(measure = "Linear spline",      model = "Fixed effects",      fem("spline")),
  c(measure = "Leukemia cases",     model = "OLS, full controls", ols("cases", 16)),
  c(measure = "Leukemia cases",     model = "Fixed effects",      fem("cases", 16)),
  c(measure = "Newspaper articles", model = "OLS, full controls", ols("news", 96)),
  c(measure = "Newspaper articles", model = "Fixed effects",      fem("news", 96)),
  c(measure = "Bayesian risk",      model = "OLS, full controls", ols("risk1", .00003587)),
  c(measure = "Bayesian risk",      model = "Fixed effects",      fem("risk1", .00003587)))
table3 <- as.data.frame(do.call(rbind, rows))
table3$b  <- round(as.numeric(table3$b), 3)
table3$se <- round(as.numeric(table3$se), 3)
table3$se_paper_adjusted <- ifelse(table3$model == "Fixed effects",
                                   round(table3$se * FE_SE_ADJ, 3), NA)
save_table(table3, "table3")

# --- Table 4: results by house size (Results.do 41-52) -------------------------
df$size <- cut(df$sqft * 100, c(-Inf, 1250, 1500, 2000, Inf), right = FALSE,
               labels = c("under 1,250", "1,250-1,500", "1,500-2,000", "2,000 and over"))
table4 <- do.call(rbind, lapply(levels(df$size), function(g) {
  s <- df[df$size == g, ]
  o <- est(feols(fml("logrealsales", c("spline", full)), s, cluster = cl), "spline")
  w <- est(feols(fml("dlogrealsales", c("dspline", fe)), s, cluster = cl), "dspline")
  data.frame(size_sqft = g, n = nrow(s), ols_b = o[["b"]], ols_se = o[["se"]],
             fe_b = w[["b"]], fe_se = w[["se"]], fe_se_paper_adjusted = w[["se"]] * FE_SE_ADJ)
}))
num <- sapply(table4, is.numeric); table4[num] <- round(table4[num], 3)
save_table(table4, "table4")

# --- Table 5: lifetime risk and value of pediatric leukemia (Results.do 54-61) -
# Value ($ millions) = -b x mean house price $119,966 / household size 2.64 x 10,000
VPL <- -119966 / 2.64 / 1e6 * 10000
priors <- c("Standard prior", "Low mean", "High mean", "Low variance", "High variance")
table5 <- do.call(rbind, lapply(1:5, function(x) {
  lr <- paste0("liferisk", x)
  jan <- function(y) mean(df[df$cc == 1 & df$year == y & df$month == 1 & df$day < 8, lr])
  o <- est(feols(fml("logrealsales", c(lr, full)), df, cluster = cl), lr, VPL)
  w <- est(feols(fml("dlogrealsales", c(paste0("d", lr), fe)), df, cluster = cl),
           paste0("d", lr), VPL)
  data.frame(prior = priors[x], risk_jan1997 = jan(1997), risk_jan2002 = jan(2002),
             value_ols = o[["b"]], value_ols_se = o[["se"]],
             value_fe = w[["b"]], value_fe_se = w[["se"]])
}))
num <- sapply(table5, is.numeric); table5[num] <- round(table5[num], 2)
save_table(table5, "table5")

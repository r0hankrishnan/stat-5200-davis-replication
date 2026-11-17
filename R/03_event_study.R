# =============================================================================
# 03_event_study.R
# Extension (not in the paper): year-by-year event study of the
# Churchill-Lyon price gap, used to check parallel pre-trends.
#
# Input : data/derived/analysis_data.rds
# Output: output/tables/event_study.csv, output/figures/event_study.png
# =============================================================================

source(file.path("R", "00_setup.R"))
df <- readRDS(file.path(DERIVED, "analysis_data.rds"))
df$sqft <- df$sqft / 100

cvars <- sprintf("class%02d", c(5, 10, 15, 20, 25, 30, 35, 40, 45))
ctrl  <- c("acres", "acres2", "sqft", "age", "age2")

# Churchill x year interactions, 1999 omitted.
# (1) Davis's OLS controls with year, month and county effects
# (2) House (parcel) fixed effects with year and month effects
es_ols <- feols(as.formula(paste("logrealsales ~ i(year, cc, ref = 1999) +",
                                 paste(c(ctrl, cvars), collapse = " + "),
                                 "| year + month + cc")),
                df, cluster = ~group)
es_fe <- feols(logrealsales ~ i(year, cc, ref = 1999) | parcel + year + month,
               df, cluster = ~group)

tidy_es <- function(m, label) {
  k <- grepl("^year::", names(coef(m)))
  out <- data.frame(year = as.integer(sub("^year::(\\d+):cc$", "\\1", names(coef(m))[k])),
                    estimate = unname(coef(m)[k]), se = unname(se(m)[k]), model = label)
  rbind(out, data.frame(year = 1999L, estimate = 0, se = 0, model = label))
}
es <- rbind(tidy_es(es_ols, "OLS with controls"), tidy_es(es_fe, "House fixed effects"))
es <- es[order(es$model, es$year), ]
es$ci_low  <- es$estimate - 1.96 * es$se
es$ci_high <- es$estimate + 1.96 * es$se

out <- es; out[, 2:3] <- round(out[, 2:3], 4); out[, 5:6] <- round(out[, 5:6], 4)
write.csv(out, file.path(TABLES, "event_study.csv"), row.names = FALSE)

p <- ggplot(es, aes(year, estimate, colour = model)) +
  geom_hline(yintercept = 0, colour = "grey60") +
  geom_vline(xintercept = 1999.5, linetype = "dashed", colour = "grey40") +
  geom_pointrange(aes(ymin = ci_low, ymax = ci_high),
                  position = position_dodge(width = 0.4), size = 0.3) +
  annotate("text", x = 1999.6, y = 0.12, label = "Cancer cluster\nemerges",
           hjust = 0, size = 3.2, colour = "grey30") +
  scale_x_continuous(breaks = 1990:2002) +
  scale_colour_manual(values = c("House fixed effects" = "#1f6f8b",
                                 "OLS with controls"   = "#d1495b")) +
  labs(x = NULL, y = "Churchill minus Lyon, log real price", colour = NULL,
       title = "House prices in Churchill County relative to Lyon County",
       subtitle = "Year-by-year difference, 1999 = 0, with 95% confidence intervals") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "top", panel.grid.minor = element_blank())

ggsave(file.path(FIGURES, "event_study.png"), p, width = 8, height = 4.8, dpi = 200)
cat("Saved", file.path(FIGURES, "event_study.png"), "and event_study.csv\n")

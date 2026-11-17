# =============================================================================
# 05_slide_figures.R
# Figures used in the presentation slides, in a plain academic style:
# white background, Times-style serif font, black and gray only.
#
# Input : output/tables/event_study.csv (from 03_event_study.R)
# Output: output/figures/slides/risk_measure.png    (the RISK spline, Section III)
#         output/figures/slides/event_study_bw.png  (event study, black and white)
#         output/figures/slides/equations.png       (equations (1) and (2) of the paper)
# =============================================================================

source(file.path("R", "00_setup.R"))

SLIDES <- file.path(FIGURES, "slides")
dir.create(SLIDES, showWarnings = FALSE, recursive = TRUE)

# Use Times New Roman when installed, else a metric-compatible clone, else
# R's generic serif font.
pick_serif <- function() {
  wanted <- c("Times New Roman", "Liberation Serif", "Tinos", "Times")
  have <- if (requireNamespace("systemfonts", quietly = TRUE)) {
    unique(systemfonts::system_fonts()$family)
  } else character(0)
  hit <- wanted[wanted %in% have]
  if (length(hit)) hit[1] else "serif"
}
FAM <- pick_serif()
cat("Slide figures use font family:", FAM, "\n")

theme_paper <- function(size) {
  theme_classic(base_size = size, base_family = FAM) +
    theme(plot.background   = element_rect(fill = "white", colour = NA),
          panel.background  = element_rect(fill = "white", colour = NA),
          axis.text         = element_text(colour = "black"),
          axis.title        = element_text(colour = "black"),
          axis.line         = element_line(colour = "black", linewidth = 0.4),
          axis.ticks        = element_line(colour = "black", linewidth = 0.4),
          legend.background = element_rect(fill = "white", colour = NA),
          legend.key        = element_rect(fill = "white", colour = NA))
}

# --- 1. The risk measure ------------------------------------------------------
# Davis (2004), Section III: zero through 1999, rises by 1/24 each month during
# 2000 and 2001, then one. Always zero in the control county.
d <- seq(1996, 2003, by = 1 / 120)
risk <- data.frame(
  date   = c(d, d),
  value  = c(pmin(pmax((d - 2000) / 2, 0), 1), rep(0, length(d))),
  county = rep(c("Churchill County", "Lyon County (control)"), each = length(d)))

p_risk <- ggplot(risk, aes(date, value, linetype = county)) +
  geom_line(linewidth = 1.8) +
  scale_linetype_manual(values = c("Churchill County" = "solid",
                                   "Lyon County (control)" = "dashed")) +
  scale_x_continuous(breaks = 1996:2003, expand = expansion(add = c(0.05, 0.2))) +
  scale_y_continuous(breaks = c(0, 0.5, 1), limits = c(-0.02, 1.05)) +
  labs(x = "Date of sale", y = expression(RISK[ct]), linetype = NULL) +
  theme_paper(28) +
  theme(legend.position = c(0.02, 0.98), legend.justification = c(0, 1),
        legend.key.width = unit(2.4, "cm"))

ggsave(file.path(SLIDES, "risk_measure.png"), p_risk, width = 8.2, height = 4.6, dpi = 200)

# --- 2. Event study in black and white ------------------------------------------
# Series are told apart by marker and line type, not colour.
es <- read.csv(file.path(TABLES, "event_study.csv"))
es$model <- factor(es$model, levels = c("OLS with controls", "House fixed effects"))
MINUS <- intToUtf8(8722)  # the true minus sign, built from its code point so any locale reads it
minus <- function(x) ifelse(abs(x) < 1e-9, "0", sub("-", MINUS, sprintf("%.1f", x), fixed = TRUE))

p_es <- ggplot(es, aes(year, estimate, shape = model, linetype = model)) +
  geom_hline(yintercept = 0, colour = "grey45", linewidth = 0.4) +
  geom_vline(xintercept = 1999.5, colour = "grey45", linewidth = 0.4, linetype = "dotted") +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high), width = 0.15, linewidth = 0.7,
                position = position_dodge(width = 0.45)) +
  geom_point(size = 4, fill = "white", stroke = 0.9,
             position = position_dodge(width = 0.45)) +
  annotate("text", x = 1999.6, y = 0.19, label = "2000: 8 new cases", hjust = 0,
           family = FAM, size = 7) +
  scale_shape_manual(values = c("OLS with controls" = 16, "House fixed effects" = 21)) +
  scale_linetype_manual(values = c("OLS with controls" = "solid",
                                   "House fixed effects" = "dashed")) +
  scale_x_continuous(breaks = 1990:2002) +
  scale_y_continuous(breaks = seq(-0.2, 0.2, 0.1), labels = minus) +
  labs(x = "Year of sale", y = "Churchill minus Lyon,\nlog price (1999 = 0)",
       shape = NULL, linetype = NULL) +
  theme_paper(20) +
  theme(legend.position = "top", legend.justification = "left",
        legend.key.width = unit(1.8, "cm"))

ggsave(file.path(SLIDES, "event_study_bw.png"), p_es, width = 12.48, height = 4.2, dpi = 200)

# --- 3. Equations (1) and (2) in the paper's notation -----------------------------
# Drawn with R's plotmath. The cairo device lets Greek letters and operators use
# the same serif font as the text; other devices fall back to the default symbols.
open_png <- function(file, ...) {
  ok <- tryCatch({
    png(file, type = "cairo", family = FAM,
        symbolfamily = grDevices::cairoSymbolFont(FAM, usePUA = FALSE), ...)
    TRUE
  }, error = function(e) FALSE)
  if (!ok) png(file, family = FAM, ...)
}
open_png(file.path(SLIDES, "equations.png"), width = 1900, height = 300, res = 200, bg = "white")
par(mar = c(0, 0, 0, 0), family = FAM)
plot.new(); plot.window(c(0, 1), c(0, 1))
text(0.005, 0.74, "(1)  OLS", adj = 0, cex = 1.9)
text(0.20, 0.74, expression(italic(PRICE)[italic(jct)] == beta[1] * italic(X)[italic(jct)] +
                              beta[2] * italic(RISK)[italic(ct)] + eta[italic(ct)] + epsilon[italic(jct)]),
     adj = 0, cex = 1.9)
text(0.005, 0.24, "(2)  FE", adj = 0, cex = 1.9)
text(0.20, 0.24, expression(italic(PRICE)[italic(jct)] == beta[1] * italic(X)[italic(jct)] +
                              beta[2] * italic(RISK)[italic(ct)] + italic(a)[italic(j)] + eta[italic(ct)] + xi[italic(jct)]),
     adj = 0, cex = 1.9)
invisible(dev.off())

cat("Saved slide figures to", SLIDES, "\n")

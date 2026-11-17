# =============================================================================
# 01_build_data.R
# Builds the analysis dataset from the raw county assessor files.
# Line-by-line translation of Davis's MergeData.do (original_code/MergeData.do).
# Comments give the matching Stata line numbers.
#
# Input : data/raw/{cc,cc2,lc,lc2,price,datesold}.dta, data/raw/riskvars.raw
# Output: data/derived/analysis_data.rds (10,204 house sales)
# =============================================================================

source(file.path("R", "00_setup.R"))

keep <- c("parcel", "date", "usecode", "sales", "acres", "sqft",
          "constryr", "class", "cc", "lc")

# --- Churchill County, spring 2002 file (MergeData.do lines 11-24) -----------
cc <- read_raw("cc.dta") %>%
  rename(parcel = var1, date = var3, usecode = var10, sales = var16,
         acres = var17, sqft = var19, constryr = var20, class = var23)
cc$cc <- 1; cc$lc <- 0
cc <- cc[eq(cc$usecode, 20), ]
cc <- cc[!gt(cc$date, 20001300), keep]

# --- Churchill County, fall 2002 update (lines 26-43) -------------------------
cc2 <- read_raw("cc2.dta") %>%
  rename(parcel = parcel__, date = sale_date, usecode = land_use,
         acres = acreage, sqft = sq_ft, constryr = yr_blt, sales = sales_price)
cc2$cc <- 1; cc2$lc <- 0
cc2 <- cc2[!is.na(cc2$date), ]
m <- sround(cc2$date, 10000) / 10000                 # dates stored as MDDYY
d <- sround(cc2$date - m * 10000, 100) / 100
y <- 2000 + cc2$date - m * 10000 - d * 100
cc2$date <- y * 10000 + m * 100 + d
# In Stata, cc2's date variable is stored as a float (single precision).
# Floats can't hold an odd 8-digit number like 20020225 exactly; it is
# rounded to the nearest even value (20020224). This shifts odd days by one
# and is why MergeData.do later fixes day==0 and day==32. Copy it here so
# the sample and dates match Davis exactly.
cc2$date <- 2 * round(cc2$date / 2)     # R rounds .5 to even, like a float
cc2 <- cc2[!lt(cc2$date, 20001300), keep]

# --- Lyon County, spring 2002 file (lines 45-59) ------------------------------
lc <- read_raw("lc.dta") %>%
  rename(parcel = var1, date = var2, usecode = var3, sales = var4,
         acres = var5, sqft = var6, constryr = var7, class = var11)
lc$cc <- 0; lc$lc <- 1
lc <- lc[!gt(lc$date, 20001300) & eq(lc$usecode, 20), keep]

# --- Lyon County, fall 2002 update (lines 61-73) ------------------------------
lc2 <- read_raw("lc2.dta") %>%
  rename(parcel = var1, date = var2, sales = var3, acres = var4,
         sqft = var5, constryr = var6, class = var8)
lc2$usecode <- 20; lc2$cc <- 0; lc2$lc <- 1
lc2 <- lc2[!lt(lc2$date, 20001300), keep]

df <- bind_rows(lc2, lc, cc2, cc)     # same stacking order as the appends

# --- Discretize class (lines 75-81) -------------------------------------------
cl <- df$class
df$class[!is.na(cl) & cl > 1.5 & cl < 2]   <- 2
df$class[!is.na(cl) & cl > 2   & cl < 2.5] <- 2.5
df$class[!is.na(cl) & cl > 2.5 & cl < 3]   <- 3
df$class[!is.na(cl) & cl > 3   & cl < 3.5] <- 3.5
df$class[!is.na(cl) & cl > 3.5 & cl < 4]   <- 4
df$class[gt(df$class, 5)] <- 0
df$parcel <- 2e8 * df$cc + 3e8 * df$lc + df$parcel   # unique ids (line 82)

# --- Impute missing house characteristics from other sales of the same
#     parcel (lines 85-103). Stata processes rows top to bottom, so this is
#     done with loops to copy that behavior. Davis notes results are the
#     same without it.
df <- df[order(df$parcel), ]
impute_pass <- function(df, dir) {
  n <- nrow(df); p <- df$parcel
  idx <- if (dir == 1) 1:(n - 1) else 2:n
  for (v in c("acres", "sqft", "class", "constryr")) {
    x <- df[[v]]
    for (i in idx) {
      j <- i + dir
      if (p[j] != p[i]) next
      bad <- switch(v,
        acres    = eq(x[i], 0),
        sqft     = eq(x[i], 0) | gt(x[i], 5000),
        class    = eq(x[i], 0),
        constryr = eq(x[i], 0) | lt(x[i], 1850))
      if (bad && ne(x[j], 0)) x[i] <- x[j]
    }
    df[[v]] <- x
  }
  df
}
for (k in 1:3) df <- impute_pass(df, +1)   # three passes using the next sale
df <- impute_pass(df, -1)                  # one pass using the previous sale

# --- Dates, age and logs (lines 105-115) ---------------------------------------
df$year  <- sround(df$date, 10000) / 10000
df$month <- sround(df$date - df$year * 10000, 100) / 100
df$day   <- df$date - df$year * 10000 - df$month * 100
df$day[eq(df$day, 0)]  <- 1
df$day[eq(df$day, 32)] <- 31
df$age <- df$year - df$constryr
df$age[lt(df$age, 0)] <- 0
df$age2   <- df$age^2
df$acres2 <- df$acres^2
df$lognomsales <- ifelse(gt(df$sales, 0) & !is.na(df$sales), log(df$sales), NA)

# --- Drop miscoded and missing observations (lines 117-126) --------------------
df <- df[!eq(df$sales, 0), ]
df <- df[!gt(df$age, 150), ]
df <- df[!eq(df$sqft, 0), ]
df <- df[!gt(df$sqft, 10000), ]
df <- df[!(eq(df$year, 2002) & gt(df$month, 9)), ]
df <- df[order(df$parcel, df$date, df$sales), ]
df <- df[!duplicated(df[, c("parcel", "date")]), ]
df <- df[!duplicated(df[, c("sales", "date", "cc", "acres")]), ]
df <- df[!eq(df$month, 0), ]

# --- Deflate with the Nevada HPI (lines 128-139) --------------------------------
df$quarter <- ceiling(df$month / 3)
price <- read_raw("price.dta")
df <- inner_join(df, price[, c("year", "quarter", "nvhpi")],
                 by = c("year", "quarter"))
df$realsales    <- df$sales * 100 / df$nvhpi
df$logrealsales <- log(df$realsales)

# --- Risk measures (lines 141-285) -----------------------------------------------
# Cumulative leukemia cases: case dates (16 cases; two on 2000-06-01)
case_dates <- c(19970601, 19990401, 19991201, 20000201, 20000301, 20000501,
                20000601, 20000601, 20000701, 20001101, 20001201, 20010101,
                20010401, 20010501, 20011201, 20020728)
df$cases <- sapply(df$date, function(x) sum(x > case_dates)) * df$cc

# Cumulative ProQuest newspaper articles (dates from lines 163-278)
news_dates <- c(20000726,20000810,20000831,20001118,20001231,20010101,20010103,
  20010106,20010110,20010118,20010119,20010123,20010124,20010126,20010126,
  20010205,20010205,20010205,20010205,20010206,20010211,20010213,20010215,
  20010218,20010221,20010222,20010223,20010223,20010224,20010303,20010303,
  20010306,20010309,20010310,20010412,20010413,20010413,20010414,20010415,
  20010419,20010428,20010508,20010522,20010526,20010603,20010604,20010605,
  20010606,20010606,20010608,20010611,20010612,20010612,20010613,20010624,
  20010628,20010711,20010713,20010719,20010725,20010823,20010826,20010826,
  20010827,20011008,20011128,20011213,20011225,20011228,20011228,20020102,
  20020126,20020215,20020307,20020321,20020403,20020418,20020421,20020503,
  20020503,20020503,20020503,20020517,20020608,20020730,20020730,20020821,
  20020822,20020822,20020823,20020906,20020906,20020906,20020916,20020919,
  20020928,20021002,20021003,20021015,20021117,20021117,20021117,20021117,
  20021225,20021229,20021231,20030201,20030207,20030207,20030207,20030213,
  20030213,20030214,20030302,20030309,20030617)
df$news <- sapply(df$date, function(x) sum(x > news_dates)) * df$cc

# Linear spline: 0 before 2000, rises linearly over 2000-2001, 1 after
ds <- df$year + (df$month - 1) / 12 + (df$day - 1) / 365
df$spline <- pmin(pmax((ds - 2000) / 2, 0), 1)
df$spline[df$lc == 1] <- 0

# --- Merge Bayesian risk estimates from the MATLAB program (lines 295-303) -------
rv <- read.table(file.path(RAW, "riskvars.raw"))
names(rv) <- c("parcel", "cc", "year", "month", "day",
               paste0("risk", 1:5), paste0("var", 1:5))
n_before_merge <- nrow(df)
df <- inner_join(df, rv, by = c("parcel", "cc", "year", "month", "day"))
for (x in 1:5) {
  df[[paste0("liferisk", x)]]    <- 10000 * df[[paste0("risk", x)]] / (1 - 1/1.03)
  df[[paste0("liferiskvar", x)]] <- 10000 * sqrt(df[[paste0("var", x)]]) / (1 - 1/1.03)
}

# --- Dummies and within-parcel demeaning (lines 305-361) -------------------------
for (x in 1990:2002) df[[paste0("t", x)]] <- as.integer(df$year == x)
for (x in 1:12)      df[[paste0("m", x)]] <- as.integer(df$month == x)
for (cv in c(0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5))
  df[[sprintf("class%02d", round(cv * 10))]] <- as.integer(eq(df$class, cv))
df$group <- df$cc * 1e6 + df$year * 100 + df$month    # county-month cluster

demean <- c("logrealsales", "cases", "news", "spline", paste0("risk", 1:5),
            paste0("liferisk", 1:5), paste0("t", 1990:2002), paste0("m", 1:12))
for (v in demean)
  df[[paste0("d", v)]] <- df[[v]] - ave(df[[v]], df$parcel,
                                        FUN = function(z) mean(z, na.rm = TRUE))

# --- Check the sample against Davis's own final sample (data/raw/datesold.dta) -
# datesold.dta lists every sale in Davis's estimation sample. The build must
# reproduce it exactly, or the script stops.
davis_sample <- read_raw("datesold.dta")
key <- function(z) paste(z$parcel, z$cc, z$year, z$month, z$day)
n_match <- sum(key(df) %in% key(davis_sample))
cat(sprintf("Sample check: %d sales built (%d before the risk merge); %d of Davis's %d matched\n",
            nrow(df), n_before_merge, n_match, nrow(davis_sample)))
stopifnot(nrow(df) == nrow(davis_sample), n_match == nrow(davis_sample))

saveRDS(df, file.path(DERIVED, "analysis_data.rds"))
cat("Saved", file.path(DERIVED, "analysis_data.rds"), "\n")

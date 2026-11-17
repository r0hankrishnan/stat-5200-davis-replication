# Raw data

All files come unchanged from the replication package for Davis (2004), published by the American Economic Association under CC BY 4.0 (see [`../../original_code/LICENSE_AEA.txt`](../../original_code/LICENSE_AEA.txt)). The assessor files have no variable labels; the names below come from the author's `MergeData.do`.

| File | Contents | Rows |
|---|---|---|
| `cc.dta` | Churchill County assessor sales records, received spring 2002 (sales through 2000) | 8,882 |
| `cc2.dta` | Churchill County update, received fall 2002 (sales from 2001). Dates are MDDYY floats | 538 |
| `lc.dta` | Lyon County assessor sales records, spring 2002 | 16,774 |
| `lc2.dta` | Lyon County update, fall 2002 | 1,748 |
| `price.dta` | Nevada house price index by year and quarter (base 2000 Q1 = 100) | 53 |
| `HPI.dta` | Nevada OFHEO index used for Figure 2 (not used here) | |
| `riskvars.raw` | Bayesian risk estimates for each sale, output of `STATArisk.m` | 10,204 |
| `datesold.dta`, `datesold.mat` | The author's final sample (parcel, county, sale date), used to check the build | 10,204 |

## Variables used

| Variable | `cc.dta` | `cc2.dta` | `lc.dta` | `lc2.dta` |
|---|---|---|---|---|
| Parcel ID | `var1` | `parcel__` | `var1` | `var1` |
| Sale date | `var3` (YYYYMMDD) | `sale_date` (MDDYY) | `var2` | `var2` |
| Land use (20 = single-family) | `var10` | `land_use` | `var3` | all single-family |
| Sale price | `var16` | `sales_price` | `var4` | `var3` |
| Lot size (acres) | `var17` | `acreage` | `var5` | `var4` |
| Floor space (sq ft) | `var19` | `sq_ft` | `var6` | `var5` |
| Year built | `var20` | `yr_blt` | `var7` | `var6` |
| Building class (quality grade) | `var23` | `class` | `var11` | `var8` |

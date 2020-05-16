# Clear memory.
rm(list = ls())

# Define packages required by this script.
#library(foreign)
library(xlsx)
library(readr)
library(dplyr)
library(RPostgres)
library(gginference)
# library(GGally)
library(ggplot2)
# library(randomcoloR)
# library(directlabels)
# library(reshape2)

# Reset graphical parameters and save the defaults.
plot.new()
.pardefault <- par(no.readonly = TRUE)
dev.off()

# Helper functions.

# Define a more comfy paste():
p <- function(..., sep='') {
  paste(..., sep=sep)
}

# Connect to the DB (required params depend about the connection).
dbc = dbConnect(
  Postgres(), 
  user = 'pinjaliina',
  dbname = 'tt',
  host = 'vm0448.kaj.pouta.csc.fi',
  port = 5432,
  sslmode = 'verify-full'
)

# List DB tables.
# dbListTables(dbc)

# TTM–journey year pairs.
ttm_y <- c(2013, 2015,2018)
jdata_y <- c(2012, 2014, 2015, 2016)

get_cols_20132015 <- p('"gid","nimi","MunID","AreaID","DistID",',
                       '"C1","F1","C2","F2","FChange",',
                       '"T1","T2","TChange","Pop2012","Pop2016","PopChange"')
get_cols_20152018 <- p('"gid","nimi","MunID","AreaID","DistID",',
                      '"C1","F1","C2","F2","FChange",',
                      '"T1","T2","TChange","Pop2016","Pop2018","PopChange"')

# Return an all-data SQL query for a given journey type.
# Convert totals to double due to ggplot2 problems with integer64
# Also make sure that all region identifiers are imported as text.
query_fortable_20132015 <- function(table) {
  query <- p('SELECT ', get_cols_20132015, 
             'FROM "', table, '" ',
             'ORDER BY "MunID", "AreaID", "DistID"')
  return(query)
}
query_fortable_20152018 <- function(table) {
  query <- p('SELECT ', get_cols_20152018, 
             'FROM "', table, '" ',
             'ORDER BY "MunID", "AreaID", "DistID"')
  return(query)
}

# # # # # # # # # # # # # # #
# Get the data from the DB. #
# # # # # # # # # # # # # # #

# All change data for PT, 2013-2015
pt_chg_all_20132015 <- dbGetQuery(dbc, query_fortable_20132015("res_agg_j_all_reg_pt_changes_2013_2015"))
names(pt_chg_all_20132015)[names(pt_chg_all_20132015) == "Pop2012"] <- "P1"
names(pt_chg_all_20132015)[names(pt_chg_all_20132015) == "Pop2016"] <- "P2"
# All change data for PT, 2015-2018
pt_chg_all_20152018 <- dbGetQuery(dbc, query_fortable_20152018("res_agg_j_all_reg_pt_changes_2015_2018"))
names(pt_chg_all_20152018)[names(pt_chg_all_20132015) == "Pop2016"] <- "P1"
names(pt_chg_all_20152018)[names(pt_chg_all_20132015) == "Pop2018"] <- "P2"
# All change data for car, 2013-2015
car_chg_all_20132015 <- dbGetQuery(dbc, query_fortable_20132015("res_agg_j_all_reg_car_changes_2013_2015"))
names(car_chg_all_20132015)[names(car_chg_all_20132015) == "Pop2012"] <- "P1"
names(car_chg_all_20132015)[names(car_chg_all_20132015) == "Pop2016"] <- "P2"
# All change data for car, 2015-2018
car_chg_all_20152018 <- dbGetQuery(dbc, query_fortable_20152018("res_agg_j_all_reg_car_changes_2015_2018"))
names(car_chg_all_20152018)[names(car_chg_all_20132015) == "Pop2016"] <- "P1"
names(car_chg_all_20152018)[names(car_chg_all_20132015) == "Pop2018"] <- "P2"

# # # # # # # # # # # # # # # # # # # # # # # # # # 
# Get QGIS attribute data from spreadsheet files. #
# # # # # # # # # # # # # # # # # # # # # # # # # #
qgisdatafn <- '/Users/Shared/pCloud/HY/Maantiede/FM/MScThesisText/TabularData/all_qgis_data.xlsx'
qgisdatacompfn <- '/Users/Shared/pCloud/HY/Maantiede/FM/MScThesisText/TabularData/all_qgis_data_comp.xlsx'
pt_comp_20132015 <- read.xlsx(qgisdatafn, sheetName = "PT 2013–2015")
pt_comp_20152018 <- read.xlsx(qgisdatafn, sheetName = "PT 2015–2018")
car_comp_20132015 <- read.xlsx(qgisdatafn, sheetName = "Car 2013–2015")
car_comp_20152018 <- read.xlsx(qgisdatafn, sheetName = "Car 2015–2018")
comp_comp_PT <- read.xlsx(qgisdatacompfn, sheetName = "Comp_PT")
comp_comp_Car <- read.xlsx(qgisdatacompfn, sheetName = "Comp_Car")

# # Calculate population-weighted total values
# p_diff <- max(pt_chg_all_20132015$P1, na.rm = TRUE)-min(pt_chg_all_20132015$P1, na.rm = TRUE)
# pt_chg_all_20132015 <- pt_chg_all_20132015 %>% mutate(W_T1 = round(P1/p_diff*T1))

# Calculate descriptives and run two-sample independent t-tests for individual TTM years
desc_pt_chg_all_20132015_T1 <- c(summary(pt_chg_all_20132015$T1), sd(pt_chg_all_20132015$T1))
names(desc_pt_chg_all_20132015_T1)[7] <- "St. Dev."
desc_pt_chg_all_20132015_T2 <- c(summary(pt_chg_all_20132015$T2), sd(pt_chg_all_20132015$T2))
names(desc_pt_chg_all_20132015_T2)[7] <- "St. Dev."
desc_pt_chg_all_20152018_T1 <- c(summary(pt_chg_all_20152018$T1), sd(pt_chg_all_20152018$T1))
names(desc_pt_chg_all_20152018_T1)[7] <- "St. Dev."
desc_pt_chg_all_20152018_T2 <- c(summary(pt_chg_all_20152018$T2), sd(pt_chg_all_20152018$T2))
names(desc_pt_chg_all_20152018_T2)[7] <- "St. Dev."
tt_pt_chg_all_20132015 <- t.test(pt_chg_all_20132015$T1, pt_chg_all_20132015$T2, var.equal = TRUE)
tt_pt_chg_all_20152018 <- t.test(pt_chg_all_20152018$T1, pt_chg_all_20152018$T2, var.equal = TRUE)
desc_car_chg_all_20132015_T1 <- c(summary(car_chg_all_20132015$T1), sd(car_chg_all_20132015$T1))
names(desc_car_chg_all_20132015_T1)[7] <- "St. Dev."
desc_car_chg_all_20132015_T2 <- c(summary(car_chg_all_20132015$T2), sd(car_chg_all_20132015$T2))
names(desc_car_chg_all_20132015_T2)[7] <- "St. Dev."
desc_car_chg_all_20152018_T1 <- c(summary(car_chg_all_20152018$T1), sd(car_chg_all_20152018$T1))
names(desc_car_chg_all_20152018_T1)[7] <- "St. Dev."
desc_car_chg_all_20152018_T2 <- c(summary(car_chg_all_20152018$T2), sd(car_chg_all_20152018$T2))
names(desc_car_chg_all_20152018_T2)[7] <- "St. Dev."
tt_car_chg_all_20132015 <- t.test(car_chg_all_20132015$T1, car_chg_all_20132015$T2, var.equal = TRUE)
tt_car_chg_all_20152018 <- t.test(car_chg_all_20152018$T1, car_chg_all_20152018$T2, var.equal = TRUE)

# For comparison, fit linear models to check if changes in
# aggregated travel times are explained by population changes
pt_comp_20132015_lm <- lm(TChange ~ PopChange, data = pt_comp_20132015, na.action = na.omit)
pt_comp_20152018_lm <- lm(TChange ~ PopChange, data = pt_comp_20152018, na.action = na.omit)
car_comp_20132015_lm <- lm(TChange ~ PopChange, data = car_comp_20132015, na.action = na.omit)
car_comp_20152018_lm <- lm(TChange ~ PopChange, data = car_comp_20152018, na.action = na.omit)

# Calculate descriptives and run two-sample independent t-tests for TTM year pairs,
# for both absolute and population-weighted data
desc_comp_comp_PT_1 <- c(summary(comp_comp_PT$TChange_1), sd(comp_comp_PT$TChange_1))
names(desc_comp_comp_PT_1)[7] <- "St. Dev."
desc_comp_comp_PT_2 <- c(summary(comp_comp_PT$TChange_2), sd(comp_comp_PT$TChange_2))
names(desc_comp_comp_PT_2)[7] <- "St. Dev."
desc_comp_comp_PT_1_W <- c(summary(comp_comp_PT$W_TChange_1), sd(comp_comp_PT$W_TChange_1))
names(desc_comp_comp_PT_1_W)[7] <- "St. Dev."
desc_comp_comp_PT_2_W <- c(summary(comp_comp_PT$W_TChange_2), sd(comp_comp_PT$W_TChange_2))
names(desc_comp_comp_PT_2_W)[7] <- "St. Dev."
tt_comp_comp_PT <- t.test(comp_comp_PT$TChange_1, comp_comp_PT$TChange_2, var.equal = TRUE)
tt_comp_comp_PT_W <- t.test(comp_comp_PT$W_TChange_1, comp_comp_PT$W_TChange_2, var.equal = TRUE)
desc_comp_comp_Car_1 <- c(summary(comp_comp_Car$TChange_1), sd(comp_comp_Car$TChange_1))
names(desc_comp_comp_Car_1)[7] <- "St. Dev."
desc_comp_comp_Car_2 <- c(summary(comp_comp_Car$TChange_2), sd(comp_comp_Car$TChange_2))
names(desc_comp_comp_Car_2)[7] <- "St. Dev."
desc_comp_comp_Car_1_W <- c(summary(comp_comp_Car$W_TChange_1), sd(comp_comp_Car$W_TChange_1))
names(desc_comp_comp_Car_1_W)[7] <- "St. Dev."
desc_comp_comp_Car_2_W <- c(summary(comp_comp_Car$W_TChange_2), sd(comp_comp_Car$W_TChange_2))
names(desc_comp_comp_Car_2_W)[7] <- "St. Dev."
tt_comp_comp_Car <- t.test(comp_comp_Car$TChange_1, comp_comp_Car$TChange_2, var.equal = TRUE)
tt_comp_comp_Car_W <- t.test(comp_comp_Car$W_TChange_1, comp_comp_Car$W_TChange_2, var.equal = TRUE)

# Plot kernel densities of unweighted changes
plot(density(comp_comp_PT$TChange_1),
     main='Kernel densities, unweighted changes', col='darkseagreen3')
lines(density(comp_comp_PT$TChange_2), col='gold')
lines(density(comp_comp_Car$TChange_1), col='firebrick1')
lines(density(comp_comp_Car$TChange_2), col='blue')
legend('topright', c(
  'Car, 2013–2015',
  'Car, 2015–2018',
  'PT, 2013–2015',
  'PT, 2015–2018'),
  fill = c('firebrick1','blue','darkseagreen3','gold'))

# Plot kernel densities of unweighted changes in relative frequencies
plot(density(comp_comp_PT$FChange_1),
     main='Kernel densities, changes in unweighted relative frequencies', col='darkseagreen3')
lines(density(comp_comp_PT$FChange_2), col='gold')
lines(density(comp_comp_Car$FChange_1), col='firebrick1')
lines(density(comp_comp_Car$FChange_2), col='blue')
legend('topright', c(
  'Car, 2013–2015',
  'Car, 2015–2018',
  'PT, 2013–2015',
  'PT, 2015–2018'),
  fill = c('firebrick1','blue','darkseagreen3','gold'))

# Plot kernel densities of weighted changes
plot(density(comp_comp_PT$W_TChange_1),
     main='Kernel densities, weighted changes', col='darkseagreen3')
lines(density(comp_comp_PT$W_TChange_2), col='gold')
lines(density(comp_comp_Car$W_TChange_1), col='firebrick1')
lines(density(comp_comp_Car$W_TChange_2), col='blue')
legend('topright', c(
  'Car, 2013–2015',
  'Car, 2015–2018',
  'PT, 2013–2015',
  'PT, 2015–2018'),
  fill = c('firebrick1','blue','darkseagreen3','gold'))

"Plot: PT, t-test, 2013-2015"
ggttest(tt_pt_chg_all_20132015) +
  labs(title="PT, 2013 vs 2015, two-sided t-test",
       subtitle = p('p-value: ', round(tt_pt_chg_all_20132015$p.value, 4)))
qqplot(pt_chg_all_20132015$T1, pt_chg_all_20132015$T2,
       main = "Q–Q plot, PT 2013 vs 2015", xlab="2013", ylab="2015")
abline(0,1)

"Plot: PT, t-test, 2015-2018"
ggttest(tt_pt_chg_all_20132015) +
  labs(title="PT, 2015 vs 2018, two-sided t-test",
       subtitle = p('p-value: ', round(tt_pt_chg_all_20152018$p.value, 4)))
qqplot(pt_chg_all_20152018$T1, pt_chg_all_20152018$T2,
       main = "Q–Q plot, PT 2015 vs 2018", xlab="2015", ylab="2018")
abline(0,1)

"Plot: car, t-test, 2013-2015"
ggttest(tt_car_chg_all_20132015) +
  labs(title="Car, 2013 vs 2015, two-sided t-test",
       subtitle = p('p-value: ', round(tt_car_chg_all_20132015$p.value, 4)))
qqplot(car_chg_all_20132015$T1, car_chg_all_20132015$T2,
       main = "Q–Q plot, car 2013 vs 2015", xlab="2013", ylab="2015")
abline(0,1)

"Plot: car, t-test, 2015-2018"
ggttest(tt_car_chg_all_20132015) +
  labs(title="Car, 2015 vs 2018, two-sided t-test",
       subtitle = p('p-value: ', round(tt_car_chg_all_20152018$p.value, 4)))
qqplot(car_chg_all_20152018$T1, car_chg_all_20152018$T2,
       main = "Q–Q plot, car 2015 vs 2018", xlab="2015", ylab="2018")
abline(0,1)

"Plot: TTM Pairs, unweighted t-test for PT"
ggttest(tt_comp_comp_PT) +
  labs(title="Change comparison, unweighted PT, 2013–2015 vs 2015–2018, two-sided t-test",
       subtitle = p('p-value: ', round(tt_comp_comp_PT$p.value, 4)))
qqplot(comp_comp_PT$TChange_1, comp_comp_PT$TChange_2,
       main = "Q–Q plot, PT change 2013–2015 vs 2015–2018, unweighted", xlab = '2013–2015', ylab = '2015–2018')
abline(0,1)

"Plot: TTM Pairs, weighted t-test for PT"
ggttest(tt_comp_comp_PT_W) +
  labs(title="Change comparison, population-weighted PT, 2013–2015 vs 2015–2018, two-sided t-test",
       subtitle = p('p-value: ', round(tt_comp_comp_PT_W$p.value, 4)))
qqplot(comp_comp_PT$W_TChange_1, comp_comp_PT$W_TChange_2,
       main = "Q–Q plot, PT change 2013–2015 vs 2015–2018, population-weighted", xlab = '2013–2015', ylab = '2015–2018')
abline(0,1)

"Plot: TTM Pairs, unweighted t-test for car"
ggttest(tt_comp_comp_Car) +
  labs(title="Change comparison, unweighted car, 2013–2015 vs 2015–2018, two-sided t-test",
       subtitle = p('p-value: ', round(tt_comp_comp_Car$p.value, 4)))
qqplot(comp_comp_Car$TChange_1, comp_comp_Car$TChange_2,
       main = "Q–Q plot, car change 2013–2015 vs 2015–2018, unweighted", xlab = '2013–2015', ylab = '2015–2018')
abline(0,1)

"Plot: TTM Pairs, weighted t-test for car"
ggttest(tt_comp_comp_Car) +
  labs(title="Change comparison, population-weighted car, 2013–2015 vs 2015–2018, two-sided t-test",
       subtitle = p('p-value: ', round(tt_comp_comp_Car_W$p.value, 4)))
qqplot(comp_comp_Car$W_TChange_1, comp_comp_Car$W_TChange_2,
       main = "Q–Q plot, car change 2013–2015 vs 2015–2018, population-weighted", xlab = '2013–2015', ylab = '2015–2018')
abline(0,1)

"Plot: TTM Pairs, RF t-test for car"
# This is sort of a bonus; I don't think that the relative frequencies should be subjected to t-tests.
# tt_comp_comp_Car_F <- t.test(comp_comp_Car$FChange_1, comp_comp_Car$FChange_2, var.equal = TRUE)
# ggttest(tt_comp_comp_Car_F) +
#   labs(title="Change comparison, relative car frequencies, 2013–2015 vs 2015–2018, two-sided t-test",
#        subtitle = p('p-value: ', round(tt_comp_comp_Car_F$p.value, 4)))

# Print descriptives and t-test results
"PT, 2013 (T1)"
desc_pt_chg_all_20132015_T1
"PT, 2015 (T2)"
desc_pt_chg_all_20132015_T2
"PT, 2015 (T1)"
desc_pt_chg_all_20152018_T1
"PT, 2018 (T2)"
desc_pt_chg_all_20152018_T2
"PT, t-test, 2013-2015"
tt_pt_chg_all_20132015
"PT, t-test, 2015-2018"
tt_pt_chg_all_20152018
"Car, 2013 (T1)"
desc_car_chg_all_20132015_T1
"Car, 2015 (T2)"
desc_car_chg_all_20132015_T2
"Car, 2015 (T1)"
desc_car_chg_all_20152018_T1
"Car, 2018 (T2)"
desc_car_chg_all_20152018_T2
"Car, t-test, 2013-2015"
tt_car_chg_all_20132015
"Car, t-test, 2015-2018"
tt_car_chg_all_20152018
"LM Summary, PT 2013-2015"
summary(pt_comp_20132015_lm)
"LM Summary, PT 2015-2018"
summary(pt_comp_20152018_lm)
"LM Summary, car 2013-2015"
summary(car_comp_20132015_lm)
"LM Summary, car 2015-2018"
summary(car_comp_20152018_lm)
"TTM Pairs, unweighted PT (1)"
desc_comp_comp_PT_1
"TTM Pairs, unweighted PT (2)"
desc_comp_comp_PT_2
"TTM Pairs, unweighted t-test for PT"
tt_comp_comp_PT
"TTM Pairs, weighted PT (1)"
desc_comp_comp_PT_2_W
"TTM Pairs, weighted PT (2)"
desc_comp_comp_PT_2_W
"TTM Pairs, weighted t-test for PT"
tt_comp_comp_PT_W
"TTM Pairs, unweighted Car (1)"
desc_comp_comp_Car_1
"TTM Pairs, unweighted Car (2)"
desc_comp_comp_Car_2
"TTM Pairs, unweighted t-test for Car"
tt_comp_comp_Car
"TTM Pairs, weighted car (1)"
desc_comp_comp_Car_1_W
"TTM Pairs, weighted car (2)"
desc_comp_comp_Car_2_W
"TTM Pairs, weighted t-test for PT"
tt_comp_comp_Car_W

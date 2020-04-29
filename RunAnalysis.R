# Clear memory.
rm(list = ls())

# Define packages required by this script.
#library(foreign)
library(dplyr)
library(RPostgres)
#library(GGally)
library(ggplot2)
library(randomcoloR)
library(directlabels)
library(reshape2)

# Reset graphical parameters and save the defaults.
plot.new()
.pardefault <- par(no.readonly = TRUE)
dev.off()

# Helper functions.

# Define a more comfy paste():
p <- function(..., sep='') {
  paste(..., sep=sep)
}

# Get relative share
pct <- function(x) {
  ifelse(x > 0, round(100 * x/sum(x), 1), 0)
}

# Get relative row share
shr <- function(df) {
  df <- round(df / t(df[1]) * 100, 1)
  df[] <- lapply(df, function(x) replace(x, is.nan(x), 0))
}

# Divide by 60 (minutes to hours etc.)
div60 <- function(x) x/60

# Travel habits in the Helsinki Region 2018: relative share of public
# transport journeys of all motorised journeys (Brandt et al. 2018: pp. 59-69):
metshr_title_methods <- c("Other", "Walk", "Bike", "PT", "Car")
metshr_title_years <- c("2012", "2018")
metshr_title_muns <- c("000", "049", "091", "235", "092")
metshr_titles <- list(metshr_title_methods, metshr_title_years, metshr_title_muns)
method_share <- array(c(
  "HCR_avg (000)" <- matrix(c(2.7,26.9,7.3,27.1,36.1,0.4,30.5,9.2,25.4,34.0), nrow = 5),
  "Espoo (049)" <- matrix(c(3.0,22.5,8.3,20.3,45.9,1.2,26.1,9.2,17.8,45.6), nrow = 5),
  "Helsinki (091)" <- matrix(c(2.7,29.3,6.2,33.7,28.1,0.9,33.8,9.8,30.8,24.8), nrow = 5),
  "Kauniainen (235)" <- matrix(c(0.3,28.0,9.0,16.6,45.0,0.3,28.0,9.0,16.6,45.0), nrow = 5),
  "Vantaa (092)" <- matrix(c(2.5,25.4,8.8,17.7,45.5,1.0,26.6,7.3,20.0,45.1), nrow = 5)
), dim = c(5,2,5), dimnames = metshr_titles)
method_share

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

# Return query constraints for a given journey type.
where_clause <- function(measure) {
  clause <- p("WHERE ",
  "measure = '", measure, "' AND (",
  "(ttm_year = ", ttm_y[1]," AND journey_year = ", jdata_y[1], ") ",
  "OR (ttm_year = ", ttm_y[2], " AND journey_year = ", jdata_y[3], ") ",
  "OR (ttm_year = ", ttm_y[3], " AND journey_year = ", jdata_y[4], ")",
  ")")
  return(clause)
}

# Return an all-data SQL query for a given journey type.
# Convert totals to double due to ggplot2 problems with integer64
# Also make sure that all region identifiers are imported as text.
query_all <- function(measure) {
  query <- p("SELECT measure, ttm_year, journey_year, count, total::double precision ",
             "FROM hcr_journeys_aggregated_all ",
             where_clause(measure), " ORDER BY measure")
  return(query)
}
# Return an industry-constrained SQL query for a given journey type.
query_ic <- function(measure) {
  query <- p("SELECT measure, ttm_year, journey_year, count, total::double precision, ",
             "a_alkut, b_kaivos, c_teoll, d_infra1, e_infra2, f_rakent, g_kauppa, h_kulj, ",
             "i_majrav, j_info, k_raha, l_kiint, m_tekn, n_halpa, o_julk, p_koul, q_terv, ",
             "r_taide, s_muupa, t_koti, u_kvjarj, x_tuntem FROM hcr_journeys_aggregated_ic ",
             where_clause(measure), " ORDER BY measure")
  return(query)
}

# Return a region-classified all-data SQL query for a given journey type.
query_allreg <- function(measure) {
  query <- p("SELECT measure, ttm_year, journey_year, mun::text, area::text, dist::text, ",
             "reg_id::text, count, total::double precision ",
             "FROM hcr_journeys_aggregated_all_byreg ",
             where_clause(measure), " ORDER BY measure")
  return(query)
}

# Return an industry-constrained, region-classified SQL query for a given journey type.
query_icreg <- function(measure) {
  query <- p("SELECT measure, ttm_year, journey_year, mun::text, area::text, dist::text, ",
             "reg_id::text, count, total::double precision, a_alkut, b_kaivos, c_teoll, ",
             "d_infra1, e_infra2, f_rakent, g_kauppa, h_kulj, i_majrav, j_info, k_raha, ",
             "l_kiint, m_tekn, n_halpa, o_julk, p_koul, q_terv, r_taide, s_muupa, t_koti, ",
             "u_kvjarj, x_tuntem FROM hcr_journeys_aggregated_ic_byreg ",
             where_clause(measure), " ORDER BY measure")
  return(query)
}

# Return field names identifying the underlying data
res_varnames_id <- function() {
  names = c(
    "Measure",
    "TTM",
    "JourneyYear"
  )
  return(names)
}

# Return field names identifying regions
res_varnames_reg <- function() {
  names = c(
    "MunID",
    "AreaID",
    "DistID",
    "RegID"
  )
  return(names)
}

# Return field names of the common variables
res_varnames_common <- function() {
  names = c(
    "Count",
    "Total"
  )
  return(names)
}

# Return field names of the IC variables
res_varnames_ic <- function() {
  names = c(
    # Give the columns new names in English.
    # The classification is based on the 2008 industry classification of Statistics Finland:
    # https://www.stat.fi/meta/luokitukset/toimiala/001-2008/index_en.html
    # Referenced 2020-03-04
    "PriProd",   #Agriculture, forestry and fishing
    "Mining",    #Mining and quarrying
    "Manuf",     #Manufacturing
    "ElAC",      #Electricity, gas, steam and air conditioning supply
    "WaterEnv",  #Water supply; sewerage, waste management and remediation activities
    "Construct", #Construction
    "Trade",     #Wholesale and retail trade; repair of motor vehicles and motorcycles
    "Logistics", #Transportation and storage
    "HoReCa",    #Accommodation and food service activities
    "InfoComm",  #Information and communication
    "FinIns",    #Financial and insurance activities
    "RealEst",   #Real estate activities
    "SpecProf",  #Professional, scientific and technical activities
    #(speciality professions, e.g. law, architecture, accounting, marketing, research, vets)
    "AdminSupp", #Administrative and support service activities
    #(e.g. leasing, office services, employment agencies, security, travel agencies)
    "PubAdmDef", #Public administration and defence; compulsory social security
    "Education", #Education
    "HealthSoc", #Human health and social work activities
    "ArtsEnt",   #Arts, entertainment and recreation
    "OtherServ", #Other service activities (e.g. NGOs, appliance repair services, laundry services, spas) 
    "HomeEmp",   #Activities of households as employers; undifferentiated goods- and services-producing
    #activities of households for own use
    "IntOrgs",   #Activities of extraterritorial organisations and bodies
    "UnknownInd" #Unknown industry
  )
  return(names)
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Get the data from the DB, create frequency tables,    #
# and write the new tables back to the DB               #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# All data, no regions, PT, summary table
agg_j_all_pt <- dbGetQuery(dbc, query_all("pt_m_tt"))
colnames(agg_j_all_pt) <- c(res_varnames_id(), res_varnames_common())
dbWriteTable(dbc, "res_agg_j_all_pt", agg_j_all_pt, row.names=FALSE, overwrite=TRUE, copy=TRUE)

# All data, no regions, PT, relative TTM share (makes little sense)
agg_j_all_pt_freq <- mutate(agg_j_all_pt, Total = pct(Total))
dbWriteTable(dbc, "res_agg_j_all_pt_freq",
             agg_j_all_pt_freq, row.names=FALSE, overwrite=TRUE, copy=TRUE)

# All data, no regions, car, summary table
agg_j_all_car <- dbGetQuery(dbc, query_all("car_m_t"))
colnames(agg_j_all_car) <- c(res_varnames_id(), res_varnames_common())
dbWriteTable(dbc, "res_agg_j_all_car", agg_j_all_car, row.names=FALSE, overwrite=TRUE, copy=TRUE)

# All data, no regions, car, relative TTM share (makes little sense)
agg_j_all_car_freq <- mutate(agg_j_all_car, Total = pct(Total))
dbWriteTable(dbc, "res_agg_j_all_car_freq",
             agg_j_all_car_freq, row.names=FALSE, overwrite=TRUE, copy=TRUE)

# IC data, no regions, PT, summary table
agg_j_ic_pt <- dbGetQuery(dbc, query_ic("pt_m_tt"))
colnames(agg_j_ic_pt) <- c(res_varnames_id(), res_varnames_common(), res_varnames_ic())
dbWriteTable(dbc, "res_agg_j_ic_pt", agg_j_ic_pt, row.names=FALSE, overwrite=TRUE, copy=TRUE)

# IC data, no regions, PT, relative TTM share (makes little sense)
agg_j_ic_pt_freq <- data.frame(
  agg_j_ic_pt[1:4], mutate_all(agg_j_ic_pt[5:length(agg_j_ic_pt)], pct))
dbWriteTable(dbc, "res_agg_j_ic_pt_freq",
             agg_j_ic_pt_freq, row.names=FALSE, overwrite=TRUE, copy=TRUE)

# IC data, no regions, car
agg_j_ic_car <- dbGetQuery(dbc, query_ic("car_m_t"))
colnames(agg_j_ic_car) <- c(res_varnames_id(), res_varnames_common(), res_varnames_ic())
dbWriteTable(dbc, "res_agg_j_ic_car", agg_j_ic_car, row.names=FALSE, overwrite=TRUE, copy=TRUE)

# IC data, no regions, car, relative TTM share (makes little sense)
agg_j_ic_car_freq <- data.frame(
  agg_j_ic_car[1:4], mutate_all(agg_j_ic_car[5:length(agg_j_ic_car)], pct))
dbWriteTable(dbc, "res_agg_j_ic_car_freq",
             agg_j_ic_car_freq, row.names=FALSE, overwrite=TRUE, copy=TRUE)

# All data with regions, PT
agg_j_all_reg_pt <- dbGetQuery(dbc, query_allreg("pt_m_tt"))
colnames(agg_j_all_reg_pt) <- c(res_varnames_id(), res_varnames_reg(), res_varnames_common())
dbWriteTable(dbc, "res_agg_j_all_reg_pt",
             agg_j_all_reg_pt, row.names=FALSE, overwrite=TRUE, copy=TRUE)

# All data with regions, PT frequencies by TTM year (i.e. data grouped by TTM year)
agg_j_all_reg_pt_ttyfreq <- (agg_j_all_reg_pt %>% group_by(TTM) %>% mutate(Total = pct(Total)))
dbWriteTable(dbc, "res_agg_j_all_reg_pt_ttyfreq",
             agg_j_all_reg_pt_ttyfreq, row.names=FALSE, overwrite=TRUE, copy=TRUE)

# All data with regions, car
agg_j_all_reg_car <- dbGetQuery(dbc, query_allreg("car_m_t"))
colnames(agg_j_all_reg_car) <- c(res_varnames_id(), res_varnames_reg(), res_varnames_common())
dbWriteTable(dbc, "res_agg_j_all_reg_car",
             agg_j_all_reg_car, row.names=FALSE, overwrite=TRUE, copy=TRUE)

# All data with regions, car frequencies by TTM year (i.e. data grouped by TTM year)
agg_j_all_reg_car_ttyfreq <- (agg_j_all_reg_car %>% group_by(TTM) %>% mutate(Total = pct(Total)))
dbWriteTable(dbc, "res_agg_j_all_reg_car_ttyfreq",
             agg_j_all_reg_car_ttyfreq, row.names=FALSE, overwrite=TRUE, copy=TRUE)

# IC data with regions, PT
agg_j_ic_reg_pt <- dbGetQuery(dbc, query_icreg("pt_m_tt"))
colnames(agg_j_ic_reg_pt) <- c(res_varnames_id(),
                               res_varnames_reg(),
                               res_varnames_common(),
                               res_varnames_ic())
dbWriteTable(dbc, "res_agg_j_ic_reg_pt",
             agg_j_ic_reg_pt, row.names=FALSE, overwrite=TRUE, copy=TRUE)

# IC data with regions, PT frequencies by TTM year (i.e. data grouped by TTM year)
agg_j_ic_reg_pt_ttyfreq <- (agg_j_ic_reg_pt %>% group_by(TTM) %>% mutate_at(
  vars(-Measure, -TTM, -JourneyYear, -MunID, -AreaID, -DistID, -RegID, -Count), pct))
dbWriteTable(dbc, "res_agg_j_ic_reg_pt_ttyfreq",
             agg_j_ic_reg_pt_ttyfreq, row.names=FALSE, overwrite=TRUE, copy=TRUE)

# IC data with regions, PT frequencies by industry (i.e. frequencies by row)
agg_j_ic_reg_pt_icfreq <- data.frame(agg_j_ic_reg_pt[1:8],
                                     shr(agg_j_ic_reg_pt[9:length(agg_j_ic_reg_pt)]))
dbWriteTable(dbc, "res_agg_j_ic_reg_pt_icfreq",
             agg_j_ic_reg_pt_icfreq, row.names=FALSE, overwrite=TRUE, copy=TRUE)

# IC data with regions, car
agg_j_ic_reg_car <- dbGetQuery(dbc, query_icreg("car_m_t"))
colnames(agg_j_ic_reg_car) <- c(res_varnames_id(),
                               res_varnames_reg(),
                               res_varnames_common(),
                               res_varnames_ic())
dbWriteTable(dbc, "res_agg_j_ic_reg_car",
             agg_j_ic_reg_car, row.names=FALSE, overwrite=TRUE, copy=TRUE)

# IC data with regions, car frequencies by TTM year (i.e. data grouped by TTM year)
agg_j_ic_reg_car_ttyfreq <- (agg_j_ic_reg_car %>% group_by(TTM) %>% mutate_at(
  vars(-Measure, -TTM, -JourneyYear, -MunID, -AreaID, -DistID, -RegID, -Count), pct))
dbWriteTable(dbc, "res_agg_j_ic_reg_car_ttyfreq",
             agg_j_ic_reg_car_ttyfreq, row.names=FALSE, overwrite=TRUE, copy=TRUE)

# IC data with regions, car frequencies by industry (i.e. frequencies by row)
agg_j_ic_reg_car_icfreq <- data.frame(agg_j_ic_reg_car[1:8],
                                     shr(agg_j_ic_reg_car[9:length(agg_j_ic_reg_car)]))
dbWriteTable(dbc, "res_agg_j_ic_reg_car_icfreq",
             agg_j_ic_reg_car_icfreq, row.names=FALSE, overwrite=TRUE, copy=TRUE)

# Filter the variable values by MunID and multiple the values of each municipality
# with the relevant travel method share factor. 
calc_munshare <- function(df, method_code) {
  ret_df <- df[0,]
  for(mun in metshr_title_muns[-1]) {
    for(y in ttm_y) {
      multiplier = 0
      if(y == 2018) multiplier = method_share[method_code,"2018",mun]
      else multiplier = method_share[method_code,"2012",mun]
      res_df <- df %>%
        filter(MunID == mun, TTM == y) %>% mutate_at(vars(
          -Measure, -TTM, -JourneyYear, -MunID, -AreaID, -DistID, -RegID, -Count),
          function(x) round(x * multiplier / 100, 1))
      res_df %<>% mutate(Count = round(Count * multiplier / 100 ,0))
      ret_df <- rbind(ret_df, res_df)
    }
  }
  return(ret_df)
}

# Multiply all PT times and counts with municipal travel method factors.
agg_j_all_reg_pt_mun <- calc_munshare(agg_j_all_reg_pt, "PT")
dbWriteTable(dbc, "res_agg_j_all_reg_pt_mun",
             agg_j_all_reg_pt_mun, row.names=FALSE, overwrite=TRUE, copy=TRUE)

# All data with regions, PT frequencies by TTM year (i.e. data grouped by TTM year)
# data multiplied with municipal travel method factors
agg_j_all_reg_pt_ttyfreq_mun <- (agg_j_all_reg_pt_mun %>% group_by(TTM) %>% mutate(Total = pct(Total)))
dbWriteTable(dbc, "res_agg_j_all_reg_pt_ttyfreq_mun",
             agg_j_all_reg_pt_ttyfreq_mun, row.names=FALSE, overwrite=TRUE, copy=TRUE)

# Multiply IC PT times and counts with municipal travel method factors.
agg_j_ic_reg_pt_mun <- calc_munshare(agg_j_ic_reg_pt, "PT")
dbWriteTable(dbc, "res_agg_j_ic_reg_pt_mun",
             agg_j_ic_reg_pt_mun, row.names=FALSE, overwrite=TRUE, copy=TRUE)

# IC data with regions, PT frequencies by industry (i.e. frequencies by row),
# data multiplied with municipal travel method factors
agg_j_ic_reg_pt_icfreq_mun <- data.frame(agg_j_ic_reg_pt_mun[1:8],
                                     shr(agg_j_ic_reg_pt_mun[9:length(agg_j_ic_reg_pt_mun)]))
dbWriteTable(dbc, "res_agg_j_ic_reg_pt_icfreq_mun",
             agg_j_ic_reg_pt_icfreq_mun, row.names=FALSE, overwrite=TRUE, copy=TRUE)

# Multiply all car times and counts with municipal travel method factors.
agg_j_all_reg_car_mun <- calc_munshare(agg_j_all_reg_car, "Car")
dbWriteTable(dbc, "res_agg_j_all_reg_car_mun",
             agg_j_all_reg_car_mun, row.names=FALSE, overwrite=TRUE, copy=TRUE)

# All data with regions, car frequencies by TTM year (i.e. data grouped by TTM year)
# data multiplied with municipal travel method factors
agg_j_all_reg_car_ttyfreq_mun <- (agg_j_all_reg_car_mun %>% group_by(TTM) %>% mutate(Total = pct(Total)))
dbWriteTable(dbc, "res_agg_j_all_reg_car_ttyfreq_mun",
             agg_j_all_reg_car_ttyfreq_mun, row.names=FALSE, overwrite=TRUE, copy=TRUE)

# Multiply IC car times and counts with municipal travel method factors.
agg_j_ic_reg_car_mun <- calc_munshare(agg_j_ic_reg_car, "Car")
dbWriteTable(dbc, "res_agg_j_ic_reg_car_mun",
             agg_j_ic_reg_car_mun, row.names=FALSE, overwrite=TRUE, copy=TRUE)

# IC data with regions, car frequencies by industry (i.e. frequencies by row),
# data multiplied with municipal travel method factors
agg_j_ic_reg_car_icfreq_mun <- data.frame(agg_j_ic_reg_car_mun[1:8],
                                         shr(agg_j_ic_reg_car_mun[9:length(agg_j_ic_reg_car_mun)]))
dbWriteTable(dbc, "res_agg_j_ic_reg_car_icfreq_mun",
             agg_j_ic_reg_car_icfreq_mun, row.names=FALSE, overwrite=TRUE, copy=TRUE)

# # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Function to plot non-region classified data.
plot_not_reg <- function(df, vars, legend = FALSE) {
  # Plot values. If the legend is not false, show it for the vars. Else show directlabels.
  df_long <- melt(df[vars], id=names(df[which(colnames(df) == "TTM")]))
  plot <- ggplot(df_long, aes(x=factor(TTM), group=variable, y=value, colour=variable)) +
    geom_line(size=1.3) +
    xlab("Year of the Time Travel Matrix") +
    ylab("Aggregated travel time spent (hours)")
    if(legend == FALSE) {
      plot <- plot +
      geom_dl(aes(label = variable), method = list(dl.trans(x = x + 0.2), "last.qp", cex = 0.8)) +
      geom_dl(aes(label = variable), method = list(dl.trans(x = x - 0.2), "first.qp", cex = 0.8)) +
      theme(legend.position = "none")
    }
    else {
      plot <- plot + labs(colour = legend)
    }
    return(plot)
}

# Convert minutes to hours and plot total non-region data.
plot_all_df <- data.frame(agg_j_all_pt[2],lapply(agg_j_all_pt[5], div60))
plot_not_reg(plot_all_df, c(1:length(plot_all_df)), "Total") # Plot total data.
# Convert minutes to hours and plot IC non-region-data.
plot_ic_df <- data.frame(agg_j_ic_pt[2],lapply(agg_j_ic_pt[8], div60),
                         lapply(agg_j_ic_pt[10:23], div60))
plot_not_reg(plot_ic_df, c(1:length(plot_ic_df))) # Plot IC data.

# Plot total data classified by region.
plot_reg <- function(df, vars, variable, value) {
  # Plot values classified by region.
  plot <- ggplot(df[vars], aes(x=factor(TTM), group=variable, y=value, colour="red")) +
  geom_line() +
  xlab("Year of the Time Travel Matrix") +
  ylab("Aggregated travel time spent (hours)") +
  theme(legend.position = "none")
  return(plot)
}
plot_reg_df <- data.frame(agg_j_all_reg_pt[c(2,7)], lapply(agg_j_all_reg_pt[9], div60))
colnames(plot_reg_df)[which(colnames(plot_reg_df) == "RegID")] <- "variable"
colnames(plot_reg_df)[which(colnames(plot_reg_df) == "Total")] <- "value"
# Plot regional data
plot_reg(plot_reg_df, c(1:length(plot_reg_df)))

# Get regions from the IC data:
regs <- distinct(agg_j_ic_reg_pt[c("RegID")])
# Plot each region separately (slow!)
for(reg in 1:nrow(regs)) {
  crit <- regs[reg,]
  newdf <- filter(agg_j_ic_reg_pt, RegID == crit)
  if(nrow(newdf) < 3) {
    print(p("Data from the region ", crit, " is not complete; can't plot!"))
  }
  else {
    if(reg < 6) {
    print(p("Plotting ", crit, "…"))
    # Convert minutes to hours and plot the data of the region.
    plot_df <- data.frame(newdf[2],lapply(newdf[10:31], div60))
    print(plot_not_reg(plot_df, c(1:length(plot_df))), legend = TRUE)
  }}
}

# Clear memory.
rm(list = ls())

# Define packages required by this script.
#library(foreign)
#library(dplyr)
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
query_all <- function(measure) {
  query <- p("SELECT * FROM hcr_journeys_aggregated_all ",
             where_clause(measure), " ORDER BY measure")
  return(query)
}
# Return an industry-constrained SQL query for a given journey type.
query_ic <- function(measure) {
  query <- p("SELECT * FROM hcr_journeys_aggregated_ic ",
             where_clause(measure), " ORDER BY measure")
  return(query)
}

# Return a region-constrained SQL query for a given journey type.
query_reg <- function(measure) {
  query <- p("SELECT * FROM hcr_journeys_aggregated_regions ",
             where_clause(measure), " ORDER BY measure")
  return(query)
}

# Get data from the DB.
agg_j_all_pt <- dbGetQuery(dbc, query_all("pt_m_tt"))
agg_j_all_varnames <- c(
  "Measure",
  "TTM",
  "JourneyYear",
  "Total"
)
colnames(agg_j_all_pt) <- agg_j_all_varnames
agg_j_ic_pt <- dbGetQuery(dbc, query_ic("pt_m_tt"))
agg_j_ic_varnames <- c(
  # Give the columns new names in English.
  # The classification is based on the 2008 industry classification of Statistics Finland:
  # https://www.stat.fi/meta/luokitukset/toimiala/001-2008/index_en.html
  # Referenced 2020-03-04
  "Measure",
  "TTM",
  "JourneyYear",
  "Total",
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
  "SpecProf",  #Professional, scientific and technical activities (speciality professions, e.g. law, architecture, accounting, marketing, research, vets)
  "AdminSupp", #Administrative and support service activities (e.g. leasing, office services, employment agencies, security, travel agencies)
  "PubAdmDef", #Public administration and defence; compulsory social security
  "Education", #Education
  "HealthSoc", #Human health and social work activities
  "ArtsEnt",   #Arts, entertainment and recreation
  "OtherServ", #Other service activities (e.g. NGOs, appliance repair services, laundry services, spas) 
  "HomeEmp",   #Activities of households as employers; undifferentiated goods- and services-producing activities of households for own use
  "IntOrgs",   #Activities of extraterritorial organisations and bodies
  "UnknownInd" #Unknown industry
)
colnames(agg_j_ic_pt) <- agg_j_ic_varnames
agg_j_reg_pt <- dbGetQuery(dbc, query_reg("pt_m_tt"))
agg_j_reg_varnames <- c(
  "Measure",
  "TTM",
  "JourneyYear",
  "MunID",
  "AreaID",
  "DistID",
  "RegID",
  "Total"
)
colnames(agg_j_reg_pt) <- (agg_j_reg_varnames)

# Travel habits in the Helsinki Region 2018: relative share of public
# transport journeys of all motorised journeys (Brandt et al. 2018: appendix 4, p. 10):
method_titles <- list(c("Other", "Walk", "Bike", "PT", "Car"), c("2012", "2018"))
method_share <- matrix(c(2,26.8,7.2,27.2,36.1,0.4,30.5,9.2,25.4,34.0), nrow = 5, dimnames = method_titles)
method_share

# Try to plot something… this plotting method will most likely be redundant.
# agg_j_plot <- function(df, vars, legend) {
#   plot <- ggplot(df, aes(x = factor(TTM), group=1))
#   for(ind in variable.names(df)[vars]) {
#     plot <- plot + geom_line(aes_string(y=ind, colour=p('"', ind, '"')), size=2)
#   }
#   plot <- plot + xlab("Year") + ylab("Aggregated journey time (min)")
#   plot <- plot + labs(colour = legend)
#   return(plot)
# }

agg_j_plot <- function(df, vars, legend = FALSE) {
  # Plot values. If the legend is not false, show it for the vars. Else show directlabels.
  df_long <- df
  if(!(names(df[7]) == "RegID")) { #FIXME! Does not work, the num of cols is not known!
     df_long <- melt(df[vars], id=names(df[2]))
  }
  else {
    1 == 1
  }
  plot <- ggplot(df_long, aes(x=factor(TTM), group=variable, y=value, colour=variable)) +
    geom_line(size=1.3) +
    xlab("Year of the Time Travel Matrix") +
    ylab("Aggregated time spend by all journeys")
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

agg_j_plot(agg_j_ic_pt, c(2,7,10:23))
agg_j_plot(agg_j_all_pt, c(2,4), "Total")

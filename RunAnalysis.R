# Clear memory.
rm(list = ls())

# Define packages required by this script.
#library(foreign)
#library(dplyr)
library(RPostgres)
#library(GGally)
library(ggplot2)

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
agg_j_ic <- dbGetQuery(dbc, query_ic("pt_m_tt"))
agg_j_reg <- dbGetQuery(dbc, query_reg("pt_m_tt"))


# Travel habits in the Helsinki Region 2018: relative share of public
# transport journeys of all motorised journeys (Brandt et al. 2018: appendix 4, p. 10):
method_titles <- list(c("Other", "Walk", "Bike", "PT", "Car"), c("2012", "2018"))
method_share <- matrix(c(2,26.8,7.2,27.2,36.1,0.4,30.5,9.2,25.4,34.0), nrow = 5, dimnames = method_titles)
method_share

# Try to plot something…
# ggplot(agg_j_all_pt, aes(x = factor(year), y=as.double(total), group=1)) + geom_point() +
#   stat_summary(fun.y=sum, geom="line") + xlab("Year") + ylab("Aggregated journey time (min)")

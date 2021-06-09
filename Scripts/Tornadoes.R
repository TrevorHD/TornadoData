##### Load libraries --------------------------------------------------------------------------------------

# Load libraries
library(RSQLite)
library(tidyverse)
library(grid)
library(gridBase)
library(XML)
library(usmap)
library(xlsx)





##### Load database ---------------------------------------------------------------------------------------

# Begin connection to database
CN <- dbConnect(SQLite(), dbname = "D:/StormData/DB/StormEvents.db")

# Select tornado events
results <- dbSendQuery(conn = CN, "SELECT * FROM TornadoDetails
                                   ORDER BY YEAR")

# Write tornado events to table; clear search results and close connection
tableB <- fetch(results, -1)
dbClearResult(results)
dbDisconnect(conn = CN)

# Clear residual SQLite stuff from environment
remove(CN, results)

# Remove tornado events with no county-level location data
tableB <- subset(tableB, nchar(CZ_NAME) > 0)





##### Visualise tornado movement directions ---------------------------------------------------------------

# Function to find tornado travel direction
angle <- function(x0, y0, x1, y1){

  # Calculate changes in x and y coordinates
  xdist <- x1 - x0
  ydist <- y1 - y0
  
  # Calculate angle in radians, from 0 to 2*pi
  # Calculate for different quadrants since atan cannot tell -y/x from y/-x, or y/x from -y/-x
  if(xdist >= 0 && ydist >= 0){
    rad <- atan(ydist/xdist)}
  if(xdist < 0 && ydist >= 0){
    rad <- pi + atan(ydist/xdist)}
  if(xdist < 0 && ydist < 0){
    rad <- pi + atan(ydist/xdist)}
  if(xdist >= 0 && ydist < 0){
    rad <- 2*pi + atan(ydist/xdist)}
  if(x0 == x1 && y0 == y1){
    rad <- NA}
  
  # Return angle in degrees
  return(rad*180/pi)}

# Find direction of travel for each tornado using latitude and longitude
tableB_coord <- data.frame(t(apply(tableB[, c("BEGIN_LON", "BEGIN_LAT", "END_LON", "END_LAT")], 1, as.numeric)))
tableB_angle <- apply(na.omit(tableB_coord), 1, function(x) angle(x[1], x[2], x[3], x[4]))
tableB_angle <- as.data.frame(na.omit(tableB_angle))
names(tableB_angle) = "Angle"

# Prepare graphics device
jpeg(filename = "Figure 1.jpeg", width = 1400, height = 400, units = "px")

# Create blank page
grid.newpage()
plot.new()

# Set grid layout and activate it
gly <- grid.layout(400, 1400)
pushViewport(viewport(layout = gly))

# Plot data in radial histogram
print(ggplot(data = tableB_angle, aes(x = Angle)) +
        geom_hline(yintercept = seq(0, 0.15, by = 0.05), colour = "grey90", size = 0.2) +
        geom_hline(yintercept = 0.2, colour = "black", size = 0.2) +
        geom_vline(xintercept = seq(0, 359, by = 45), colour = "grey90", size = 0.2) +
        geom_histogram(aes(y = ..count../sum(..count..)), fill = "grey", colour = "black", breaks = c((0:36)*10)) +
        coord_polar(theta = "x", start = 3*pi/2, direction = -1) +
        theme_bw() +
        theme(panel.border = element_blank(),
              panel.grid.major = element_blank(),
              panel.grid.minor = element_blank(),
              axis.text.x = element_blank(),
              axis.text.y = element_blank(),
              axis.ticks.y = element_blank(),
              plot.margin = unit(c(0.01, 0.01, 0.01, 0.01), "cm")) +
        ylab("") +
        xlab("") +
        annotate("text", size = 4, x = 270, y = seq(0, 0.15, 0.05), label = seq(0, 0.15, 0.05)) +
        annotate("text", y = 0.22, x = seq(0, 315, 45),
                 label = c("E", "NE", "N", "NW", "W", "SW", "S", "SE")),
      vp = viewport(layout.pos.row = 1:400, layout.pos.col = 1000:1400))

# Plot data in regular histogram
# Note that local maxima tend to occur at cardinal and intermediate directions
# Tornado movement may be reported at low resolution when more precise movement data cannot be obtained
print(ggplot(data = tableB_angle, aes(x = Angle)) +
        geom_histogram(aes(y = ..count../sum(..count..)), fill = "grey", colour = "black", breaks = c((0:360)*1)) +
        geom_vline(xintercept = 0.5, colour = "grey90", linetype = "dashed", size = 0.2) +
        geom_vline(xintercept = seq(44.5, 359.5, by = 45), colour = "grey90", linetype = "dashed", size = 0.2) +
        geom_hline(yintercept = seq(0, 0.15, by = 0.05), colour = "grey90", size = 0.2) +
        scale_x_continuous(breaks = seq(0, 360, 45), labels = seq(0, 360, 45)) +
        theme_bw() +
        theme(panel.grid.major = element_blank(),
              panel.grid.minor = element_blank(),
              axis.title.x = element_text(size = 18),
              axis.title.y = element_text(size = 18, margin = margin(t = 0, r = 10, b = 0, l = 0)),
              axis.text.x = element_text(size = 14),
              axis.text.y = element_text(size = 14)) +
        annotate("text", y = 0.17, x = seq(0, 315, 45),
                 label = c("E", "NE", "N", "NW", "W", "SW", "S", "SE")) +
        ylab("Proportion of Tornadoes") +
        xlab("Angle (Degrees)"),
      vp = viewport(layout.pos.row = 25:385, layout.pos.col = 50:1000))

# Deactivate grid layout; finalise graphics save
popViewport()
dev.off()


                      


##### Visualise occurrence and death by tornado strength ---------------------------------------------------

# Function to estimate occurrence and lethality as a function of tornado strength
scale.stats <- function(data, rank, type){

  # Get data for a particular tornado strength rank
  rankMatches <- subset(data, TOR_F_SCALE == rank)
  
  # Number of tornadoes
  if(type == "count"){
    out <- nrow(rankMatches)}
  
  # Total deaths
  if(type == "deaths"){
    out <- sum(as.numeric(rankMatches$DEATHS_DIRECT)) +
           sum(as.numeric(rankMatches$DEATHS_INDIRECT))}
  
  # Mean number of deaths per tornado
  if(type == "meanD"){
    out <- (sum(as.numeric(rankMatches$DEATHS_DIRECT)) +
            sum(as.numeric(rankMatches$DEATHS_INDIRECT)))/nrow(rankMatches)}
  
  # Standard error of deaths per tornado
  if(type == "seD"){
    out <- sd(as.numeric(rankMatches$DEATHS_DIRECT) +
              as.numeric(rankMatches$DEATHS_INDIRECT))/sqrt(nrow(rankMatches))}
  
  # Output value
  return(out)}

# Remove blank F-scale factor
# Group based on whether scale is F (Fujita) or EF (Enhanced Fujita)
unique(tableB$TOR_F_SCALE)
tableB_ScaleF <- subset(tableB, grepl("E", TOR_F_SCALE) == FALSE & TOR_F_SCALE != "")
tableB_ScaleEF <- subset(tableB, grepl("E", TOR_F_SCALE) == TRUE)

# Set up character vector of F and EF labels
labels.f <- c("F0", "F1", "F2", "F3", "F4", "F5")
labels.ef <- c("EF0", "EF1", "EF2", "EF3", "EF4", "EF5")

# Calculate total and mean number of deaths for each F tornado strength
tableB_StatsF <- data.frame(sapply(labels.f, scale.stats, data = tableB_ScaleF, type = "count"),
                            sapply(labels.f, scale.stats, data = tableB_ScaleF, type = "deaths"),
                            sapply(labels.f, scale.stats, data = tableB_ScaleF, type = "meanD"),
                            sapply(labels.f, scale.stats, data = tableB_ScaleF, type = "seD"))
tableB_StatsF <- data.frame(cbind(labels.f, tableB_StatsF))
names(tableB_StatsF) <- c("Strength", "Count", "TotalDeaths", "MeanDeaths", "SEDeaths")

# Calculate total and mean number of deaths for each EF tornado strength
tableB_StatsEF <- data.frame(sapply(labels.ef, scale.stats, data = tableB_ScaleEF, type = "count"),
                             sapply(labels.ef, scale.stats, data = tableB_ScaleEF, type = "deaths"),
                             sapply(labels.ef, scale.stats, data = tableB_ScaleEF, type = "meanD"),
                             sapply(labels.ef, scale.stats, data = tableB_ScaleEF, type = "seD"))
tableB_StatsEF <- data.frame(cbind(labels.ef, tableB_StatsEF))
names(tableB_StatsEF) <- c("Strength", "Count", "TotalDeaths", "MeanDeaths", "SEDeaths")

# Create plotting function
plot.statsEF <- function(data, yvar, yvarName, upper){
  
  # Create base plot
  ggplot(data) +
    geom_bar(aes(x = Strength, y = yvar), stat = "identity") +
    coord_cartesian(ylim = c(0, upper)) +
    xlab("Tornado Strength") +
    scale_y_continuous(breaks = seq(0, upper, length.out = 5)) +
    theme_bw() +
    theme(panel.grid.major.x = element_blank(),
          panel.grid.major.y = element_line(),
          panel.grid.minor.x = element_blank(),
          panel.grid.minor.y = element_line(),
          axis.title.x = element_text(size = 18),
          axis.title.y = element_text(size = 18),
          axis.text.x = element_text(size = 14),
          axis.text.y = element_text(size = 14)) -> p
  
  # Add additional options to plot based on data type
  if(yvarName == "Count"){
    p + ylab("Total Number of Tornadoes") -> p}
  if(yvarName == "TotalDeaths"){
    p + ylab("Total Number of Deaths") -> p}
  if(yvarName == "MeanDeaths"){
    p + ylab("Mean Deaths Per Tornado") +
        geom_errorbar(aes(x = Strength, ymin = MeanDeaths - SEDeaths,
                      ymax = MeanDeaths + SEDeaths), width = 0.4) -> p}
  
  # Output plot
  return(p)}

# Prepare graphics device
jpeg(filename = "Figure 2.1.jpeg", width = 1800, height = 600, units = "px")

# Create blank page
grid.newpage()
plot.new()

# Set grid layout and activate it
gly <- grid.layout(600, 1800)
pushViewport(viewport(layout = gly))

print(plot.statsEF(tableB_StatsF, tableB_StatsF$Count, "Count", 25000),
      vp = viewport(layout.pos.row = 21:580, layout.pos.col = 21:590))
print(plot.statsEF(tableB_StatsF, tableB_StatsF$TotalDeaths, "TotalDeaths", 2500),
      vp = viewport(layout.pos.row = 21:580, layout.pos.col = 611:1190))
print(plot.statsEF(tableB_StatsF, tableB_StatsF$MeanDeaths, "MeanDeaths", 12),
      vp = viewport(layout.pos.row = 21:580, layout.pos.col = 1211:1780))

# Deactivate grid layout; finalise graphics save
popViewport()
dev.off()

# Prepare graphics device
jpeg(filename = "Figure 2.2.jpeg", width = 1800, height = 600, units = "px")

# Create blank page
grid.newpage()
plot.new()

# Set grid layout and activate it
gly <- grid.layout(600, 1800)
pushViewport(viewport(layout = gly))

print(plot.statsEF(tableB_StatsEF, tableB_StatsEF$Count, "Count", 4000),
      vp = viewport(layout.pos.row = 21:580, layout.pos.col = 21:590))
print(plot.statsEF(tableB_StatsEF, tableB_StatsEF$TotalDeaths, "TotalDeaths", 200),
      vp = viewport(layout.pos.row = 21:580, layout.pos.col = 611:1190))
print(plot.statsEF(tableB_StatsEF, tableB_StatsEF$MeanDeaths, "MeanDeaths", 12),
      vp = viewport(layout.pos.row = 21:580, layout.pos.col = 1211:1780))

# Deactivate grid layout; finalise graphics save
popViewport()
dev.off()





##### Visualise state-level tornado data ------------------------------------------------------------------

# Function to grab tornado count or deaths for a given state (and county, if specified)
data.state <- function(state, county = NULL, type, level){
    
  # State only
  if(level == "state"){
    stateMatches <- subset(tableB, STATE == state)}
    
  # State and county
  if(level == "county"){
    stateMatches <- subset(tableB, STATE == state & CZ_NAME == county)}
    
  # Grab tornado count
  if(type == "count"){
    val <- nrow(stateMatches)}
    
  # Grab tornado deaths
  if(type == "deaths"){
    val <- sum(as.numeric(stateMatches$DEATHS_DIRECT)) + sum(as.numeric(stateMatches$DEATHS_INDIRECT))}
    
  # Output value
  return(val)}

# Grab total tornado occurrence and deaths for each state
tableB_state <- data.frame(sapply(unique(tableB$STATE), data.state, type = "count", level = "state"),
                           sapply(unique(tableB$STATE), data.state, type = "deaths", level = "state"))
tableB_state <- cbind(rownames(tableB_state), tableB_state)
names(tableB_state) <- c("state", "Count", "Deaths")
rownames(tableB_state) <- NULL

# Remove DC and PR since they are not states
tableB_state <- subset(tableB_state, state != "DISTRICT OF COLUMBIA" & state != "PUERTO RICO")

# Make state names to lowercase before capitalising first letter
tableB_state$state <- tolower(tableB_state$state)

# Function to capitalise first letter of state
first.cap <- function(string){
  s <- strsplit(string, " ")[[1]]
  paste(toupper(substring(s, 1, 1)), substring(s, 2), sep = "", collapse = " ")}

# Capitalise first letters in states
tableB_state$state <- sapply(tableB_state$state, first.cap)

# Download page of land area (sq. km) by state, as HTML
download.file("https://en.wikipedia.org/wiki/List_of_U.S._states_and_territories_by_area",
              destfile = "C:\\Users/Trevor Drees/Documents/test.html")

# Parse HTML document
page <- htmlParse("C:\\Users/Trevor Drees/Documents/test.html")

# Read selected instances of <table> into data frame
data <- data.frame(readHTMLTable(page, header = TRUE, which = 1))
data <- data[2:51, c(1, 7)]
names(data) <- c("state", "Land")

# Merge area data with count data
tableB_state <- merge(tableB_state, data, by = "state")

# Calculate tornadoes per year per sq. km, tornadoes per year, and tornado deaths per year
tableB_state$Land <- as.numeric(sapply(tableB_state$Land, str_remove_all, pattern = ","))
tableB_state <- mutate(tableB_state, "Count/Year/Land" = Count/Land/(as.numeric(max(tableB$YEAR)) -
                                                                     as.numeric(min(tableB$YEAR))),
                                     "Count/Year" = Count/(as.numeric(max(tableB$YEAR)) -
                                                           as.numeric(min(tableB$YEAR))),
                                     "Deaths/Year" = Deaths/(as.numeric(max(tableB$YEAR)) -
                                                             as.numeric(min(tableB$YEAR))))

# Prepare graphics device
jpeg(filename = "Figure 3.jpeg", width = 2100, height = 750, units = "px")

# Create blank page
grid.newpage()
plot.new()

# Set grid layout and activate it
gly <- grid.layout(500, 1400)
pushViewport(viewport(layout = gly))

# Plot mean number of tornadoes per year
print(plot_usmap(data = tableB_state, values = "Count/Year", color = "black") +
        scale_fill_gradientn(colours = c("white", "red"), breaks = c(0, 10, 25, 50, 150), limits = c(0, 150),
                             labels = c(0, 10, 25, 50, "150+"), name = NULL, rescaler = function(x, ...) x/150,
                             na.value = "white") +
        theme(legend.position = c(0.58, 0.05),
              legend.direction = "horizontal",
              legend.key.width = unit(2.2, "cm"),
              legend.key.height = unit(0.85, "cm"),
              legend.text = element_text(size = 13),
              plot.margin = unit(c(0.01, 0.01, 0.01, 0.01), "cm")),
      vp = viewport(layout.pos.row = 21:500, layout.pos.col = 1:700))

# Plot mean number of tornadoes per year per sq. km
print(plot_usmap(data = tableB_state, values = "Count/Year/Land", color = "black") +
        scale_fill_gradientn(colours = c("white", "red"), breaks = c(0, 0.0001, 0.0002, 0.0004),
                             limits = c(0, 0.0004), labels = c(0, "0.0001", "0.0002", "0.0004+"),
                             name = NULL, rescaler = function(x, ...) x/0.0004, na.value = "white") +
        theme(legend.position = c(0.58, 0.05),
              legend.direction = "horizontal",
              legend.key.width = unit(2.2, "cm"),
              legend.key.height = unit(0.85, "cm"),
              legend.text = element_text(size = 13),
              plot.margin = unit(c(0.01, 0.01, 0.01, 0.01), "cm")),
      vp = viewport(layout.pos.row = 21:500, layout.pos.col = 701:1400))

 # Add titles
grid.text(label = c("Mean Tornadoes Per Year", "Mean Tornadoes Per Year, Per sq. km"),
x = c(0.25, 0.75), y = rep(0.95, 2), gp = gpar(fontsize = 40))

# Deactivate grid layout; finalise graphics save
popViewport()
dev.off()





##### Visualise county-level tornado data -----------------------------------------------------------------

# County names across U.S. are not unique (e.g. Orange County in CA, TX, and several other states)
# Will need to get 5 digit FIPS code (first 2 digits state, last 3 digits county)
# Function to convert state and county FIPS into one 5-digit code
get.fips <- function(stateFips, countyFips){
  
  # State and county FIPS
  sf <- stateFips
  cf <- countyFips

  # Add preceding zero to state (e.g. 6 -> 06)
  if(nchar(stateFips) == 1){
    sf <- paste0("0", stateFips)}

  # Add preceding zero(es) to county (e.g. 6 -> 006, 56 -> 056)
  if(nchar(countyFips) == 1){
    cf <- paste0("00", countyFips)}
  if(nchar(countyFips) == 2){
    cf <- paste0("0", countyFips)}

  # Combine codes and output
  return(paste0(sf, cf))}

# Get state and county FIPS data
tableB_fips <- unique(subset(tableB, select = c(STATE, CZ_NAME, STATE_FIPS, CZ_FIPS)))

# Get 5-digit FIPS for each unique combination of state and county
tableB_county <- data.frame(mapply(FUN = data.state, state = tableB_fips$STATE, county = tableB_fips$CZ_NAME,
                                   type = "count", level = "county"),
                            mapply(FUN = data.state, state = tableB_fips$STATE, county = tableB_fips$CZ_NAME,
                                   type = "deaths", level = "county"))
tableB_county <- cbind(tableB_fips$STATE, tableB_fips$CZ_NAME, tableB_fips$STATE_FIPS, tableB_fips$CZ_FIPS,
                       mapply(FUN = get.fips, stateFips = tableB_fips$STATE_FIPS, tableB_fips$CZ_FIPS),
                       tableB_county)
names(tableB_county) <- c("state", "county", "stateFips", "countyFips", "fips", "Count", "Deaths")

# Load census data for land area by county
data <- read.xlsx("C:\\Users/Trevor Drees/Downloads/LND01.xls", 1)
data <- subset(data, select = c(STCOU, LND110210D))
names(data) <- c("fips", "Area")

# Convert land area from sq. mi to sq. km
data$Area <- data$Area*2.58999

# Merge land area data with the rest of the county data
tableB_county <- merge(data, tableB_county, by = "fips")

# Calculate  tornadoes per year and tornado deaths per year
tableB_county <- mutate(tableB_county, "Count/Year/Land" = Count/Area/(as.numeric(max(tableB$YEAR)) -
                                                                       as.numeric(min(tableB$YEAR))),
                                       "Count/Year" = Count/(as.numeric(max(tableB$YEAR)) -
                                                             as.numeric(min(tableB$YEAR))),
                                       "Deaths/Year" = Deaths/(as.numeric(max(tableB$YEAR)) -
                                                               as.numeric(min(tableB$YEAR))),
                                       "Deaths/Count" = Deaths/Count)

# Prepare graphics device
jpeg(filename = "Figure 4.jpeg", width = 2100, height = 750, units = "px")

# Create blank page
grid.newpage()
plot.new()

# Set grid layout and activate it
gly <- grid.layout(500, 1400)
pushViewport(viewport(layout = gly))

# Plot mean number of tornadoes per year
layer_s <- plot_usmap("states", color = "black", fill = alpha(0.01))
layer_c <- plot_usmap(data = tableB_county, values = "Count/Year", color = "white", size = 0.1)
print(ggplot() +
  layer_c$layers[[1]] +
  layer_s$layers[[1]] +
  layer_c$theme +
  coord_equal() +
  scale_fill_gradientn(colours = c("white", "red"), breaks = c(0, 0.5, 1, 2, 4), limits = c(0, 4),
                       labels = c(0, 0.5, 1, 2, "4+"), name = NULL, rescaler = function(x, ...) x/4,
                       na.value = "white") +
  theme(legend.position = c(0.58, 0.05),
        legend.direction = "horizontal",
        legend.key.width = unit(2.2, "cm"),
        legend.key.height = unit(0.85, "cm"),
        legend.text = element_text(size = 13),
        plot.margin = unit(c(0.01, 0.01, 0.01, 0.01), "cm")),
        vp = viewport(layout.pos.row = 21:500, layout.pos.col = 1:700))

# Plot mean number of tornadoes per year per sq. km
layer_s <- plot_usmap("states", color = "black", fill = alpha(0.01))
layer_c <- plot_usmap(data = tableB_county, values = "Count/Year/Land", color = "white", size = 0.1)
print(ggplot() +
  layer_c$layers[[1]] +
  layer_s$layers[[1]] +
  layer_c$theme +
  coord_equal() +
  scale_fill_gradientn(colours = c("white", "red"), breaks = c(0, 0.0002, 0.0005, 0.001),
                       limits = c(0, 0.001), labels = c(0, "0.0002", "0.0005", "0.001+"), name = NULL,
                       rescaler = function(x, ...) x/0.001, na.value = "white") +
  theme(legend.position = c(0.58, 0.05),
        legend.direction = "horizontal",
        legend.key.width = unit(2.2, "cm"),
        legend.key.height = unit(0.85, "cm"),
        legend.text = element_text(size = 13),
        plot.margin = unit(c(0.01, 0.01, 0.01, 0.01), "cm")),
        vp = viewport(layout.pos.row = 21:500, layout.pos.col = 701:1400))

# Add titles
grid.text(label = c("Mean Tornadoes Per Year", "Mean Tornadoes Per Year, Per sq. km"),
          x = c(0.25, 0.75), y = rep(0.95, 2), gp = gpar(fontsize = 40))

# Deactivate grid layout; finalise graphics save
popViewport()
dev.off()

# Remove plotting objects
remove(layer_c, layer_s)





##### Plot all tornado events on map ----------------------------------------------------------------------

# Prepare graphics device
jpeg(filename = "Figure 5.jpeg", width = 1600, height = 950, units = "px")

# Create blank page
grid.newpage()
plot.new()

# Set grid layout and activate it
gly <- grid.layout(950, 1600)
pushViewport(viewport(layout = gly))

# Get latitudes of each tornado
# Remove erroneous entries with latitudes or longitudes that make no sense, then transform coordinates
tableB_coord2 <- subset(tableB, STATE != "PUERTO RICO", select = c(BEGIN_LON, BEGIN_LAT))
tableB_coord2 <- na.omit(data.frame(apply(X = tableB_coord2, MARGIN = 2, FUN = as.numeric))) %>%
  subset(., abs(BEGIN_LON) < 180 & abs(BEGIN_LAT) < 180) %>%
  usmap_transform(.) -> tableB_coord2

# Remove problematic points where transformations failed, or are likely misreported
tableB_coord2 <- tableB_coord2[-c(18442, 33741, 34094, 10798, 10793, 4448, 8145, 12959, 3178,
                                  9746, 10129, 12831, 666, 5236, 2313, 10316, 52438, 52440, 39370), ]

# Plot points
plot_usmap("states", color = "black") +
  geom_point(data = tableB_coord2, aes(x = BEGIN_LON.1, y = BEGIN_LAT.1), alpha = 0.05, colour = "red") +
  scale_shape_manual(values = 19) +
  theme(plot.margin = unit(c(1.2, 0.01, 0.01, 0.01), "cm"))

# Add title
grid.text(label = "All Reported Tornado Events, 1950 - 2011", x = 0.5, y = 0.95, gp = gpar(fontsize = 40))

# Deactivate grid layout; finalise graphics save
popViewport()
dev.off()


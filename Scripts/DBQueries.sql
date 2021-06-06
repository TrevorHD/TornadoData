/* Create table of tornado events from storm database -------------------------------------------------- */

/* Note: the code in this file uses MySQL */

/* Load database */
USE StormEvents

/* Create table of tornado events only */
CREATE TABLE TornadoDetails AS
	SELECT *
	FROM StormEvents
	WHERE EVENT_TYPE = "Tornado"

/* Drop unnecessary columns from tornado table */
ALTER TABLE TornadoDetails	
	DROP COLUMN WFO,
	DROP COLUMN SOURCE,
	DROP COLUMN MAGNITUDE,
	DROP COLUMN MAGNITUDE_TYPE,
	DROP COLUMN FLOOD_CAUSE,
	DROP COLUMN CATEGORY,
	DROP COLUMN TOR_OTHER_WFO,
	DROP COLUMN TOR_OTHER_CZ_STATE,
	DROP COLUMN TOR_OTHER_CZ_FIPS,
	DROP COLUMN TOR_OTHER_CZ_NAME,
	DROP COLUMN BEGIN_RANGE,
	DROP COLUMN BEGIN_AZIMUTH,
	DROP COLUMN BEGIN_LOCATION,
	DROP COLUMN END_RANGE,
	DROP COLUMN END_AZIMUTH,
	DROP COLUMN END_LOCATION
	
	
	
	
	
/* Create table of only tornado identifiers with locations, deaths, and damage ------------------------- */

/* Create the table with locations, deaths, and damage */
CREATE TABLE TornadoDamages AS
	SELECT STATE,
		   BEGIN_DATE_TIME,
		   END_DATE_TIME,
		   INJURIES_DIRECT,
		   INJURIES_INDIRECT,
		   DEATHS_DIRECT,
		   DEATHS_INDIRECT,
		   DAMAGE_PROPERTY,
		   DAMAGE_CROPS,
		   TOR_F_SCALE,
		   BEGIN_LAT,
		   BEGIN_LON,
		   END_LAT,
		   END_LON
	FROM StormEvents
	WHERE EVENT_TYPE = "Tornado"	

/* Add columns for total deaths and injuries */
ALTER TABLE TornadoDamages
	ADD COLUMN DEATHS_TOTAL INT NOT NULL,
	ADD COLUMN INJURIES_TOTAL INT NOT NULL

/* Populate new columns with totals */
UPDATE TornadoDamages
	SET DEATHS_TOTAL = DEATHS_DIRECT + DEATHS_INDIRECT,
	    INJURIES_TOTAL = INJURIES_DIRECT + INJURIES_INDIRECT
	
/* Drop indirect/direct death and injury columns */
ALTER TABLE TornadoDamages	
	DROP COLUMN DEATHS_DIRECT,
	DROP COLUMN DEATHS_INDIRECT,
	DROP COLUMN INJURIES_DIRECT,
	DROP COLUMN INJURIES_INDIRECT,





/* Queries on tornado counts, deaths, and injuries by month, year, and state --------------------------- */

/* Get list of total tornado injuries and deaths by month */
/* Then sort list in descending order by direct deaths */
SELECT DISTINCT MONTH_NAME,
	   SUM(DEATHS_DIRECT),
	   SUM(DEATHS_INDIRECT),
	   SUM(INJURIES_DIRECT),
	   SUM(INJURIES_INDIRECT)
	FROM StormDetails
	WHERE EVENT_TYPE = "Tornado"
	GROUP BY MONTH_NAME
	ORDER BY 2 DESC
	
/* Get list of number of tornadoes by month */
/* Then sort list in descending order by count */
SELECT MONTH_NAME,
	   COUNT(MONTH_NAME)
	FROM StormDetails
	WHERE EVENT_TYPE = "Tornado"
	GROUP BY MONTH_NAME
	ORDER BY 2 DESC

/* Get list of total tornado injuries and deaths by year */
/* Then sort list in descending order by direct deaths */
SELECT DISTINCT YEAR,
	   SUM(DEATHS_DIRECT),
	   SUM(DEATHS_INDIRECT),
	   SUM(INJURIES_DIRECT),
	   SUM(INJURIES_INDIRECT)
	FROM StormDetails
	WHERE EVENT_TYPE = "Tornado"
	GROUP BY YEAR
	ORDER BY 2 DESC
	
/* Get list of number of tornadoes by year */
/* Then sort list in descending order by count */	
SELECT YEAR,
       COUNT(YEAR)
	FROM StormDetails
	WHERE EVENT_TYPE = "Tornado"
	GROUP BY YEAR
	ORDER BY 2 DESC
	
/* Get list of total tornado injuries and deaths by state */
/* Then sort list in descending order by direct deaths */
SELECT DISTINCT STATE,
       SUM(DEATHS_DIRECT),
	   SUM(DEATHS_INDIRECT),
	   SUM(INJURIES_DIRECT),
	   SUM(INJURIES_INDIRECT)
	FROM StormDetails
	WHERE EVENT_TYPE = "Tornado"
	GROUP BY STATE
	ORDER BY 2 DESC
	
/* Get list of number of tornadoes by state */	
/* Then sort list in descending order by count */
SELECT STATE,
       COUNT(STATE)
	FROM StormDetails
	WHERE EVENT_TYPE = "Tornado"
	GROUP BY STATE
	ORDER BY 2 DESC
	
/* Get list of total tornado injuries and deaths by county */
/* Then sort list in descending order by direct deaths */
SELECT DISTINCT CZ_NAME, STATE,
       SUM(DEATHS_DIRECT),
	   SUM(DEATHS_INDIRECT),
	   SUM(INJURIES_DIRECT),
	   SUM(INJURIES_INDIRECT)
	FROM StormDetails
	WHERE EVENT_TYPE = "Tornado"
	GROUP BY CZ_NAME, STATE
	ORDER BY 3 DESC
	
/* Get list of number of tornadoes by county */	
/* Then sort list in descending order by count */
SELECT CZ_NAME, STATE,
       COUNT(CZ_NAME, STATE)
	FROM StormDetails
	WHERE EVENT_TYPE = "Tornado"
	GROUP BY CZ_NAME, STATE
	ORDER BY 3 DESC





/* Other possible queries ------------------------------------------------------------------------------ */

/* Here are some examples of other queries we can make on the database */

/* Get list of distinct storm event types */
SELECT DISTINCT EVENT_TYPE
	FROM StormEvents
	
/* Get list of events that occur everywhere but Texas and California, during April and May */
SELECT *
	FROM StormEvents
	WHERE NOT (STATE = "CALIFORNIA" OR STATE = "TEXAS")
		  AND (MONTH_NAME = "April" or MONTH_NAME = "May")

/* Get list of winter storm events that do not occur in December, January, or February */
SELECT *
	FROM StormEvents
	WHERE EVENT_TYPE = "Winter Weather"
		  AND NOT (MONTH_NAME = "December" OR MONTH_NAME = "January" OR MONTH_NAME = "February")
		  
/* Get list of events in which there was at least one death */
SELECT *
	FROM StormEvents
	WHERE (DEATHS_DIRECT + DEATHS_INDIRECT) > 0

/* Get list of May tornadoes in Texas between 2001 and 2011 */
SELECT *
	FROM StormEvents
	WHERE EVENT_TYPE = "Tornado"
		  AND STATE = "TEXAS"
		  AND MONTH_NAME = "May"
		  AND YEAR BETWEEN 2001 AND 2011

/* Get list of F5 tornadoes at least one death */
SELECT *
	FROM StormEvents
	WHERE EVENT_TYPE = "Tornado"
		  AND (DEATHS_DIRECT + DEATHS_INDIRECT) > 0
		  AND (TOR_F_SCale = "F5" OR TOR_F_SCale = "EF5")


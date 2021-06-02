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
		  
/* Get list of May tornadoes in Texas between 2001 and 2011 */
SELECT *
	FROM StormEvents
	WHERE EVENT_TYPE = "Tornado"
		  AND STATE = "TEXAS"
		  AND MONTH_NAME = "May"
		  AND YEAR BETWEEN 2001 AND 2011
		  
/* Get list of events in which there was at least one death */
SELECT *
	FROM StormEvents
	WHERE (DEATHS_DIRECT + DEATHS_INDIRECT) > 0
	
/* Get list of F5 tornadoes at least one death */
SELECT *
	FROM StormEvents
	WHERE EVENT_TYPE = "Tornado"
		  AND (DEATHS_DIRECT + DEATHS_INDIRECT) > 0
		  AND (TOR_F_SCale = "F5" OR TOR_F_SCale = "EF5")


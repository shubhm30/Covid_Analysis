-- Let's check all data in covid_deaths

SELECT
	*
FROM
	covid_analysis.public.covid_deaths cd
ORDER BY
	LOCATION,
	date_rec
	
-- Changing the date column from varchar to date format
-- In covid_deaths

ALTER TABLE covid_deaths ADD date_rec DATE;

UPDATE
	covid_deaths
SET
	date_rec = to_date(date,
	'DD/MM/YY') 

ALTER TABLE covid_deaths DROP date;

--In covid_vaccination

ALTER TABLE covid_vaccination ADD date_rec DATE;

UPDATE
	covid_vaccination
SET
	date_rec = to_date(date,
	'DD/MM/YY') 

ALTER TABLE covid_vaccination DROP date
	
-- Selecting the data we will be using for covid_deaths

SELECT
	LOCATION,
	date_rec,
	total_cases,
	new_cases,
	total_deaths,
	population
FROM
	covid_analysis.public.covid_deaths cd
ORDER BY
	LOCATION,
	date_rec
	
-- Lets look at Total cases VS Total total_deaths 

SELECT
	LOCATION,
	date_rec,
	total_cases,
	total_deaths,
	(total_deaths / total_cases)* 100.0 AS death_percentage
FROM
	covid_deaths cd
WHERE
	LOCATION = 'India'
ORDER BY
	"location" ,
	date_rec
	
-- Looking at Total_cases VS Population
-- Shows the percentage of population got covid

SELECT
	LOCATION,
	date_rec,
	population,
	total_cases,
	(total_cases / population)* 100.0 AS case_per_population
FROM
	covid_deaths cd
WHERE
	LOCATION = 'India'
ORDER BY
	"location" ,
	date_rec;

-- Countries with Highest Infection Rate compared to population

SELECT
	LOCATION,
	population,
	max(total_cases) AS HighestInfection_count,
	max((total_cases / population))* 100.0 AS case_per_population
FROM
	covid_deaths cd
GROUP BY
	"location",
	population
ORDER BY
	case_per_population DESC;

-- Countries with Highest Death count per population

SELECT
	LOCATION,
	max(total_deaths) AS HighestDeath_count
FROM
	covid_deaths cd
WHERE
	total_deaths IS NOT NULL
GROUP BY
	"location"
ORDER BY
	HighestDeath_count DESC
	
-- Since all the continents as well as other entities are also showing up in location column, lets see location with only countries

SELECT
	LOCATION,
	max(total_deaths) AS HighestDeath_count
FROM
	covid_deaths cd
WHERE
	total_deaths IS NOT NULL
	AND iso_code NOT LIKE '%OWID%'
GROUP BY
	"location"
ORDER BY
	HighestDeath_count DESC
	
--Let's filter by continents

SELECT 
	continent,
	max(total_deaths) AS HighestDeath_count
FROM
	covid_deaths cd
WHERE
	continent != ''
GROUP BY
	continent
ORDER BY
	highestdeath_count DESC
	
--Now let's look at the overall view of data 

SELECT	
	sum(new_cases) AS total_cases,
	sum(new_deaths) AS total_deaths,
	(sum(new_deaths)/ NULLIF(sum(new_cases),
	0))/ 100 AS Total_death_percentage
FROM
	covid_deaths cd
WHERE
	iso_code NOT LIKE '%OWID%'
ORDER BY
	1
	
--Datewise covid cases and deaths

SELECT	
	date_rec,
	sum(new_cases) AS total_cases,
	sum(new_deaths) AS total_deaths,
	(sum(new_deaths)/ NULLIF(sum(new_cases),		-- Here we have used NULLIF FUNCTION TO avoid Divide BY Zero Error
	0))* 100 AS Total_death_percentage
FROM
	covid_deaths cd
WHERE
	iso_code NOT LIKE '%OWID%'
GROUP BY
	date_rec
ORDER BY
	1
	
-- LOOKING AT DEATHS AND VACCINATION
-- Total Population VS Vaccinations

SELECT 
	cd.continent,
	cd."location",
	cd.date_rec ,
	cd.population ,
	cv.new_vaccinations
FROM
	covid_deaths cd
JOIN covid_vaccination cv 
	ON
	cd.LOCATION = cv.LOCATION
	AND cd.date_rec = cv.date_rec
WHERE
	cd.iso_code NOT LIKE '%OWID%'
ORDER BY
	2,
	3
	
-- Lets see another column which shows total vaccinations as a Rolling count of new vaccinations

SELECT 
	cd.continent,
	cd."location",
	cd.date_rec ,
	cd.population ,
	cv.new_vaccinations,
	sum(cv.new_vaccinations) OVER (PARTITION BY cd."location"
ORDER BY
	cd."location",
	cd.date_rec) AS rolling_count_vaccination
FROM
	covid_deaths cd
JOIN covid_vaccination cv
	ON
	cd.LOCATION = cv.LOCATION
	AND cd.date_rec = cv.date_rec
WHERE
	cd.iso_code NOT LIKE '%OWID%'
ORDER BY
	2,
	3
	
-- Using CTE to add one more column using the new column rolling_count_vaccination

WITH pop_vaccinated AS 
	(
	SELECT 
		cd.continent,
		cd."location",
		cd.date_rec ,
		cd.population ,
		cv.new_vaccinations,
		sum(cv.new_vaccinations) OVER (PARTITION BY cd."location"
	ORDER BY
		cd."location",
		cd.date_rec) AS rolling_count_vaccination
	FROM
		covid_deaths cd
	JOIN covid_vaccination cv
		ON
		cd.LOCATION = cv.LOCATION
		AND cd.date_rec = cv.date_rec
	WHERE
		cd.iso_code NOT LIKE '%OWID%'
)
SELECT
	*,
	(rolling_count_vaccination / population)* 100 AS vaccination_percentage
FROM
	pop_vaccinated
	
-- Now lets discover how many people from each country has been vaccinated. To do that, we need to obtain max value from the rolling count of vaccinations(Total vaccination count) and divide it by population. Though we can simply use total_vaccination, but we will use the roling count COLUMN 

WITH pop_vaccinated AS 
	(
	SELECT 
		cd.continent,
		cd."location",
		cd.date_rec ,
		cd.population ,
		cv.new_vaccinations,
		sum(cv.new_vaccinations) OVER (PARTITION BY cd."location"
	ORDER BY
		cd."location",
		cd.date_rec) AS rolling_count_vaccination
	FROM
		covid_deaths cd
	JOIN covid_vaccination cv
		ON
		cd.LOCATION = cv.LOCATION
		AND cd.date_rec = cv.date_rec
	WHERE
		cd.iso_code NOT LIKE '%OWID%'
)
SELECT
	continent,
	LOCATION,
	population,
	max(rolling_count_vaccination) AS total_vaccination,
	max((rolling_count_vaccination / population)* 100) AS vaccination_percentage
FROM
	pop_vaccinated
GROUP BY
	continent,
	"location",
	population
ORDER BY
	vaccination_percentage DESC
	
-- Lets create a temp table with above query

DROP TABLE IF EXISTS percent_population_vaccinated

CREATE TABLE percent_population_vaccinated
(
	continent varchar(255),
	country varchar(255),
	date_rec date,
	population NUMERIC,
	new_vaccinations NUMERIC,
	rolling_count_vaccination NUMERIC
)

INSERT
	INTO
	percent_population_vaccinated
	SELECT 
		cd.continent,
	cd."location",
	cd.date_rec ,
	cd.population ,
	cv.new_vaccinations,
		sum(cv.new_vaccinations) OVER (PARTITION BY cd."location"
ORDER BY
	cd."location",
	cd.date_rec) AS rolling_count_vaccination
FROM
	covid_deaths cd
JOIN covid_vaccination cv
		ON
	cd.LOCATION = cv.LOCATION
	AND cd.date_rec = cv.date_rec
WHERE
	cd.iso_code NOT LIKE '%OWID%'
	
SELECT
	*
FROM
	percent_population_vaccinated
	
-- CREATE VIEWS

CREATE VIEW population_vaccinated_view AS
	SELECT 
		cd.continent,
	cd."location",
	cd.date_rec ,
	cd.population ,
	cv.new_vaccinations,
		sum(cv.new_vaccinations) OVER (PARTITION BY cd."location"
ORDER BY
	cd."location",
	cd.date_rec) AS rolling_count_vaccination
FROM
	covid_deaths cd
JOIN covid_vaccination cv
		ON
	cd.LOCATION = cv.LOCATION
	AND cd.date_rec = cv.date_rec
WHERE
	cd.iso_code NOT LIKE '%OWID%'
	
	
CREATE VIEW continents_death_count AS
	SELECT 
		continent,
	max(total_deaths) AS HighestDeath_count
FROM
	covid_deaths cd
WHERE
	continent != ''
GROUP BY
	continent
ORDER BY
	highestdeath_count DESC
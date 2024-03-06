-- Just getting a feel for the data
SELECT location, date, total_cases, new_cases, total_deaths, population
FROM CovidDeaths
WHERE continent IS NOT NULL
ORDER BY 1,2

-- Looking at total cases vs. total deaths
-- I.e. the percentage of people that die after contracting COVID
SELECT location, date, total_cases, total_deaths, 
    (total_deaths/total_cases)*100 AS death_percentage
FROM CovidDeaths
WHERE location LIKE '%states%'
    AND total_deaths IS NOT NULL
    AND continent IS NOT NULL
ORDER BY 1,2

-- Looking at total cases vs. population
-- I.e. the percentage of the population that got COVID
SELECT location, date, population, total_cases, 
    (total_cases/population)*100 AS infection_percentage
FROM CovidDeaths
WHERE location LIKE '%states%'
    AND total_cases IS NOT NULL
    AND continent IS NOT NULL
ORDER BY 1,2

-- Looking at Countries with the Highest Infection Rate compared to Population
SELECT location, population, MAX(total_cases) AS highest_infection_count, 
    MAX((total_cases/population))*100 AS infection_percentage
FROM CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY highest_infection_count DESC

-- Countries with Highest Death Count per Population
SELECT location, MAX(total_deaths) AS total_death_count, MAX(population) AS total_population,
    MAX(total_deaths)/MAX(population)*100 AS death_percent_per_total_population 
FROM CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY total_death_count DESC

-- Breaking the data out by continent
SELECT location, MAX(total_deaths) AS total_death_count
FROM CovidDeaths
WHERE continent IS NULL
    AND location NOT LIKE '%World%'
    AND location NOT LIKE '%income%'
GROUP BY location
ORDER BY total_death_count DESC

-- Combining Europe and European Union 
SELECT 
    CASE 
        WHEN location = 'Europe' THEN 'Europe/European Union'
        ELSE location 
    END AS location,
    SUM(total_deaths) AS total_death_count
FROM CovidDeaths
WHERE continent IS NULL
    AND location NOT LIKE '%World%'
    AND location NOT LIKE '%income%'
    AND location NOT LIKE 'European Union'
GROUP BY 
    CASE 
        WHEN location = 'Europe' THEN 'Europe/European Union'
        ELSE location 
    END
ORDER BY total_death_count DESC;

SELECT continent, MAX(total_deaths) AS total_death_count
FROM CovidDeaths
GROUP BY continent
ORDER BY total_death_count DESC

-- Global numbers (day)
SELECT date, 
    SUM(new_cases) AS total_cases,
    SUM(new_deaths) AS total_deaths,
    SUM(new_deaths)/SUM(new_cases)*100 AS death_percentage
FROM CovidDeaths
GROUP BY date 
HAVING SUM(new_cases) > 0;

-- Global numbers (overall)
SELECT
    SUM(new_cases) AS total_cases,
    SUM(new_deaths) AS total_deaths,
    SUM(new_deaths)/SUM(new_cases)*100 AS death_percentage
FROM CovidDeaths
HAVING SUM(new_cases) > 0;

-- VACCINATIONS --

Select dea.continent, dea.location, dea.date, dea.population,
    vac.new_vaccinations, SUM(vac.new_vaccinations) OVER (
        PARTITION BY dea.location 
        ORDER BY dea.location, dea.date
    ) AS rolling_vaccination_count
FROM CovidDeaths dea
JOIN CovidVaccinations vac
    ON dea.location = vac.location
    AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
    AND vac.new_vaccinations IS NOT NULL
ORDER BY 2, 3

-- Adding in the % of population vaccinated
WITH PopulationVaccinated (Continent, Location, Date, Population, 
    New_Vaccinations, Rolling_People_Vaccinated)
AS (
    Select dea.continent, dea.location, dea.date, dea.population,
        vac.new_vaccinations, SUM(vac.new_vaccinations) OVER (
            PARTITION BY dea.location 
            ORDER BY dea.location, dea.date
        ) AS rolling_vaccination_count
    FROM CovidDeaths dea
    JOIN CovidVaccinations vac
        ON dea.location = vac.location
        AND dea.date = vac.date
    WHERE dea.continent IS NOT NULL
        AND vac.new_vaccinations IS NOT NULL
)
SELECT *, (Rolling_People_Vaccinated/Population)*100 AS Percent_People_Vaccinated
FROM PopulationVaccinated

-- Create a Temp Table for this
DROP TABLE IF EXISTS #PopulationVaccinated

CREATE TABLE #PopulationVaccinated
(
    Continent NVARCHAR(255), 
    Location NVARCHAR(255),
    Date DATETIME,
    Population NUMERIC,
    New_Vaccinations NUMERIC,
    Rolling_People_Vaccinated NUMERIC
)

INSERT INTO #PopulationVaccinated
    Select dea.continent, dea.location, dea.date, dea.population,
        vac.new_vaccinations, SUM(vac.new_vaccinations) OVER (
            PARTITION BY dea.location 
            ORDER BY dea.location, dea.date
        ) AS rolling_vaccination_count
    FROM CovidDeaths dea
    JOIN CovidVaccinations vac
        ON dea.location = vac.location
        AND dea.date = vac.date

SELECT *, (Rolling_People_Vaccinated/Population)*100 AS Percent_People_Vaccinated
FROM #PopulationVaccinated

-- CREATING VIEWS --

-- Creating some Views for Visualizations
/*
CREATE VIEW PercentOfPopulationVaccinated AS
Select dea.continent, dea.location, dea.date, dea.population,
    vac.new_vaccinations, SUM(vac.new_vaccinations) OVER (
        PARTITION BY dea.location 
        ORDER BY dea.location, dea.date
    ) AS rolling_vaccination_count
FROM CovidDeaths dea
JOIN CovidVaccinations vac
    ON dea.location = vac.location
    AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
    AND vac.new_vaccinations IS NOT NULL

CREATE VIEW CovidDeathPercentage AS
SELECT location, date, total_cases, total_deaths, 
    (total_deaths/total_cases)*100 AS death_percentage
FROM CovidDeaths
WHERE continent IS NOT NULL


CREATE VIEW CovidDeathCountByContinent AS
SELECT 
    CASE 
        WHEN location = 'Europe' THEN 'Europe/European Union'
        ELSE location 
    END AS location,
    SUM(total_deaths) AS total_death_count
FROM CovidDeaths
WHERE continent IS NULL
    AND location NOT LIKE '%World%'
    AND location NOT LIKE '%income%'
    AND location NOT LIKE 'European Union'
GROUP BY 
    CASE 
        WHEN location = 'Europe' THEN 'Europe/European Union'
        ELSE location 
    END

CREATE VIEW CountriesWithHighestDeathRate AS
SELECT location, MAX(total_deaths) AS total_death_count, MAX(population) AS total_population,
    MAX(total_deaths)/MAX(population)*100 AS death_percent_per_total_population 
FROM CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location


CREATE VIEW CovidSpreadByDate AS
SELECT date, 
    SUM(new_cases) AS total_cases,
    SUM(new_deaths) AS total_deaths,
    SUM(new_deaths)/SUM(new_cases)*100 AS death_percentage
FROM CovidDeaths
GROUP BY date 
HAVING SUM(new_cases) > 0;


DROP VIEW IF EXISTS CovidSpreadByDate

-- Correction to CovidSpreadByDate View
CREATE VIEW CovidSpreadByDate AS
SELECT date, 
    COALESCE(SUM(new_cases), 0) AS total_cases,
    COALESCE(SUM(new_deaths), 0) AS total_deaths,
    COALESCE
    (
        CASE 
            WHEN COALESCE(SUM(new_cases), 0) = 0 THEN SUM(new_cases) * 100
            ELSE COALESCE(SUM(new_deaths), 0) / COALESCE(SUM(new_cases), 0) * 100 
        END,
        0 
    ) AS death_percentage
FROM CovidDeaths
GROUP BY date 
HAVING COALESCE(SUM(new_cases), 0) != 0 OR COALESCE(SUM(new_deaths), 0) != 0
*/

-- Verifying the View
SELECT *
FROM CovidSpreadByDateWorldwide

DROP VIEW IF EXISTS CovidSpreadByDateWorldwide

--CREATE VIEW TotalVaccinationsByDateWorldwide AS
SELECT 
    cv.iso_code, 
    cv.continent, 
    cv.location, 
    cv.date, 
    --cv.total_vaccinations,
    cv.new_vaccinations,
    SUM(cv.new_vaccinations) OVER (
        ORDER BY cv.date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS rolling_vaccination_count
FROM 
    CovidVaccinations cv
WHERE continent IS NOT NULL
AND new_vaccinations IS NOT NULL
ORDER BY date


select * from TotalVaccinationsByDateWorldwide
# COVID Data Project: Data Preparation
Prepared by **Chad Lines**
## The Goal
- My goal with this project is to analyze world-wide COVID data (as provided by [ourworldindata.org](https://ourworldindata.org/covid-deaths)), and then present that data in a format that is easy to understand.
- These notes serve to document my exploration of the data - along with some transformations - preparatory to loading that data into *Power BI* where I will present the data as an interactive Dashboard.
## Preparing and Loading the Data
### Splitting The File Into Deaths and Vaccinations
- I downloaded the COVID data in XLSX format [ourworldindata.org](https://ourworldindata.org/covid-deaths)
- I then opened the spreadsheet in Excel, and divided it into two separate files
    1. The first was *Covid_Deaths.csv*, which contained columns A-Z of the original document
    2. The second was *Covid_Vaccinations.csv*, which contained columns A-D and AA-BQ of the original document
    - **NOTE:** I saved as CSV because you **cannot** directly import an excel file into SQL Server using Azure Data Studio.
-   This split ensured the proper data split for the tables that I wanted to work with (which is self-explanatory, given the names)
### Loading the Data into Azure SQL
#### Preparing the Environment
- I had already set up a barebones instance of Azure SQL in [Microsoft Azure](portal.azure.com), and so I connected to the database using [Azure Data Studio](https://learn.microsoft.com/en-us/azure-data-studio).
- I then created the `CovidDaProject` database where I could work with the data.
#### Loading the Data
- In order to load the data, I installed the *SQL Server Import* extension (published by Microsoft)
- After a little additional cleanup, I imported *Covid_Deaths.csv* into table `CovidDeaths` and *Covid_Vaccinations.csv* into `CovidVaccinations`
#### Verifying Data Load
- Very basic verification of data load:
```SQL
-- View CovidDeaths Table Data
SELECT TOP 100 *
FROM CovidDeaths;

-- Ensure all rows are presnt
SELECT COUNT(*)
FROM CovidDeaths;

-- Repeat both checks for CovidVaccinations
SELECT TOP 100 *
FROM CovidVaccinations;

SELECT COUNT(*)
FROM CovidVaccinations;
```
## Exploring the Data 
With the data loaded, I decided to poke around a bit.
### Disclaimer
My purpose in exploring this data was to extract whatever meaningful insights I could from it. There are always questions - especially in the United States - about the *veracity* of the date. Addressing that is a bit outside the scope of this project. For the purpose of this project, I'm taking the data at face value and working with it as is.

---

### Getting a Feel for the Data
- Here's I'm just trying to get a feel for the data
```SQL
SELECT location, date, total_cases, new_cases, total_deaths, population
FROM CovidDeaths
ORDER BY 1,2
```
**Results:**
![Results Image](\image_container\results_1.png)

---

### COVID Death Percentage in the US
- Being from the United States I was curious to see the death percentage in the US
    - Keep in mind that there's no grouping at this point, so the percentage fluctuates day by day.
    - This is *not* a comprehensive view, just yet - I'm still just exploring the data
```SQL
SELECT location, date, total_cases, total_deaths, 
    (total_deaths/total_cases)*100 AS death_percentage
FROM CovidDeaths
WHERE location LIKE '%states%'
    AND total_deaths IS NOT NULL
ORDER BY 1,2
```
**Results:**
![alt text](\image_container\results_2.png)

---

### Percentage of US Population Infected
- Something else I was interested to know was how much of the US population was, at one point or another, infected with COVID
```SQL
SELECT location, date, population, total_cases, 
    (total_cases/population)*100 AS infection_percentage
FROM CovidDeaths
WHERE location LIKE '%states%'
    AND total_cases IS NOT NULL
ORDER BY 1,2
```
**Results:**
![alt text](\image_container\results_3.png)

---

### Countries with the Highest Infection Rate Relative to Population
- Having seen the infection rate in the United States, I decided to see what that looked like in the rest of the world. 
- It was at this point, that I learned something about the data that was *not* ideal: much of it is summarized. 
- For example, when I run the following:
```SQL
SELECT location, population, MAX(total_cases) AS highest_infection_count, 
    MAX((total_cases/population))*100 AS infection_percentage
FROM CovidDeaths
GROUP BY location, population
ORDER BY highest_infection_count DESC
```
- I get the following output:
![alt text](\image_container\error_1.png)
- Well that's not good...
#### Exploring the 'Continent' Data
- The following query revealed that the `continent` column is `NULL` for those generalized locations.
```SQL
SELECT * 
FROM CovidDeaths
WHERE location IN ('World', 'High Income', 'Asia')
```
- I confirmed that by running:
```SQL
SELECT DISTINCT location, continent 
FROM CovidDeaths
GROUP BY location, continent
```
#### Adjusting the Query
- With that knowledge, I could adjust my query and run it as follows:

```SQL
SELECT location, population, MAX(total_cases) AS highest_infection_count, 
    MAX((total_cases/population))*100 AS infection_percentage
FROM CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY highest_infection_count DESC
```
**Results:**
![alt text](\image_container\results_4.png)

---

### Countries with Highest Death Count per Population
- Now I could look at the countries with the most COVID deaths relative to population:
```SQL
SELECT location, MAX(total_deaths) AS total_death_count, MAX(population) AS total_population,
    MAX(total_deaths)/MAX(population)*100 AS death_percent_per_total_population 
FROM CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY total_death_count DESC
```
**Results:**
![alt text](\image_container\results_5.png)

---

### Death Count per Continent
- Knowing that `continent` is handled the way it is,  I could break down some of the data that way as well...
```SQL
SELECT location, MAX(total_deaths) AS total_death_count
FROM CovidDeaths
WHERE continent IS NULL
    AND location NOT LIKE '%World%'
    AND location NOT LIKE '%income%'
GROUP BY location
ORDER BY total_death_count DESC
```

**Results:**
![alt text](\image_container\results_6.png)
#### Combining Europe and European Union
- Frustratingly this is still not quite good enough because `Europe` and `European Union` are combined 
    - Let's see if I can fix that.
    - I'm a little rusty, so it took me a few minutes but...

```SQL
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
```
**Results:**
![alt text](\image_container\results_7.png)
- That's *okay*, but I did not sum the `total_death_count` of `Europe` and `European Union`, nor do I have any indication whether or not I *should*.
- My gut, just looking at the data, is that the `Europe` data probably includes the data from `European Union`
    - If this were a more formal project, I would need to confirm that assumption. But since I'm doing this for fun, I'm content to run with that. 

---

### Viewing World-Wide Cases and Deaths
- My goal with this query was to see if I could see the total cases, and total deaths reported, per day and overall, while also providing a mortality percentage.
#### Per Date
```SQL
SELECT date, 
    SUM(new_cases) AS total_cases,
    SUM(new_deaths) AS total_deaths,
    SUM(new_deaths)/SUM(new_cases)*100 AS death_percentage
FROM CovidDeaths
GROUP BY date 
HAVING SUM(new_cases) > 0;
```
**Results:**
![alt text](\image_container\results_8.png)
#### Overall
```SQL
SELECT
    SUM(new_cases) AS total_cases,
    SUM(new_deaths) AS total_deaths,
    SUM(new_deaths)/SUM(new_cases)*100 AS death_percentage
FROM CovidDeaths
HAVING SUM(new_cases) > 0;
```
**Results:**
![alt text](\image_container\results_9.png)

---

### Including New Vaccinations
- Finally I'm going to bring in the vaccination info.
- What I want, for now, is a list of locations and dates, and for each date I want the population of the location, how many new vaccinations there were on the given date, and then a rolling count of vaccinations for the location.
    - For the sake of the visual, I'm only going to include dates where at least one vaccination took place in the location.
```SQL
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
```
**Results:**
![alt text](\image_container\results_10.png)

---

### Track the Percentage of the Population Vaccinated
- This is a bit more complicated, and we're stretching my humble SQL skills a bit, but my next idea was to add another column that displayed the percentage of the total population who had been vaccinated
```SQL
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
```
**Results:**
![alt text](\image_container\results_11.png)

---

### Creating a Temp Table
- I wanted to keep that data available, and decided to create a temp table for it to live in.
```SQL
DROP TABLE IF EXISTS #PopulationVaccinated -- Use as needed :) 

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
```
**Results:**
![alt text](\image_container\results_12.png)

---

## Creating Some Views
### Adding the PopulationVaccinated as a View
```SQL
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

SELECT TOP 100 *
FROM PercentOfPopulationVaccinated
```
**Results:**
![alt text](\image_container\results_12.png)

---

### Creating the Rest of the Views
- I created the following views based on queries included earlier in this document:
    - CountriesWithHighestDeathRate
    - CovidDeathCountByContinent
    - CovidDeathPercentage
    - CovidSpreadByDate
    - PercentOfPopulationVaccinated

---

# COVID Data Project: Data Visualization
## The Goal
- My goal with this project is to analyze world-wide COVID data (as provided by [ourworldindata.org](https://ourworldindata.org/covid-deaths)), and then present that data in a format that is easy to understand.
- These notes serve to document my presentation of the data using *Power BI*, where I will present the data as an interactive Dashboard.
## Importing and Examining the Data
### Importing the Data into Power BI
- My first task, of course, was to import the views I made in earlier into *Power BI*
    - I did this simply by connecting to my Azure SQL instance, authenticating, and then choosing which data (views) to import
- The views I imported were:
    - `PercentOfPopulationVaccinated` (renamed to `PercentOfPopulationVaccinatedByDate`)
    - `CovidDeathCountByContinent`
    - `CountriesWithHighestDeathRate`
    - `CovidDeathPercentage` (renamed to `CovidDeathPercentageByDate`)
    - `CovidSpreadByDate` (renamed to `WorldwideCovidSpreadByDate`)
### Examining the Data
- As part of importing, I decided to, first, load the data via *Power Query Editor*
    - This gave me a chance to inspect the data a little closer before actually bringing it into *Power BI* for the visuals
- In *Power Query Editor* I enabled the viewing of *Column Quality*, *Column Profile*, and *Column Distribution*
- Doing so, I saw that there was some additional data cleanup required, that I had not noticed in my first exploration of the data.
    - So I had to jump back into SQL
#### Fixing CovidSpreadByDate
- The problem with this view is that the `new_cases` and `new_deaths` were only updated once a week:
![Results Image](\image_container\2-1.png)
- This is not helpful or - we might assume - *accurate*

- So going back into *Azure Data Studio*, I crafted the following query:
```SQL
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
ORDER BY date
```
**Results:**
- This yielded much more helpful information:
![Results Image](\image_container\2-2.png)
- *Of course, since the data starts in January 2020, we have an oddly high death-percentage for that first entry. I will probably omit that in Power BI*
- I went ahead and recreated the `CovidSpreadByDate` accordingly
#### Reconsidering PercentOfPopulationVaccinated
- Looking at the `PercentOfPopulationVaccinated` data in *Power Query* I recalled that I had grouped the data by location and date.
    - This means that the rolling totals were country specific rather than world-wide.
    - I took a moment to consider if that's what I really wanted...
        - I decided to be greedy; I wanted **both**.
- I renamed `PercentOfPopulationVaccinated` to `PercentOfPopulationVaccinatedByCountry`, and, back in SQL wrote the following query:
```SQL
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
```
**Results:**
- This is exactly what I'm looking for
![Results Image](\image_container\2-3.png)
- After manually verifying the `rolling_vaccination_count` was correct down to the 100th record, I created a new view called `TotalVaccinationsByDateWorldwide` based on the query.
#### Resolving `NULL` Values
- The following queries contained `null` values in the corresponding columns:
    - **CountriesWithHighestDeathRate** in 
        - total_death_count
        - death_percent_per_total_population
    - **CovidDeathPercentage** in
        - total_cases
        - total_deaths
        - death_percentage
- I was lucky that, in each case, I could (accurately) simply replace those `null` values with 0s.
## Creating a COVID Deaths Dashboard
- This Dashboard shows metrics related to COVID deaths

![Results Image](\image_container\2-4.png)
## Creating a COVID Vaccination Dashboard
- This Dashboard shows metrics related to COVID vaccinations
    
![Results Image](\image_container\2-5.png)
# Conclusion
- Through meticulous data preparation, including splitting and loading data into **Azure SQL**, and subsequent exploration, I gained some interesting insights into the pandemic's impact across continents and countries.
- By leveraging **SQL** queries, I examined various metrics such as total cases, deaths, death percentages, vaccination rates, and more, facilitating a nuanced understanding of the global situation.
- Transitioning to **Power BI**, we visualized the data through interactive dashboards, offering stakeholders a user-friendly platform to explore and comprehend the complex data landscape. 
    - Dashboards were meticulously designed to highlight key metrics, trends, and patterns, aiding decision-making processes and fostering data-driven insights
- Despite encountering challenges such as data cleanliness issues and the need for iterative refinement, the project underscored the importance of data analytics in understanding and addressing global health crises.
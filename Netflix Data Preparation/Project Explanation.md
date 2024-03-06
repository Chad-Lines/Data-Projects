# Netflix Data Project
Prepared by **Chad Lines**

---
## The Goal
I came across a **Netflix Dataset** and, being a casual fan of movies, I decided to take a look. After a very cursory review of the data, I thought I might try to construct some views that show the following:

1. **Content Distribution Analysis**
	1. Which genres are most common or growing in popularity over time
	2. Which directors have the most titles in the database and in which genres they primarily work
	3. Track the distribution of content production by country or region
2. **Release Patterns**
	1. Examine how the number of titles added to Netflix has changed over time
	2. Compare the release year of titles to the year they were added to Netflix to see how *fresh* the Netflix catalog is
3. **Content Rating Analysis**
	1. Investigate the distribution of content ratings to see if there's a trend towards more family-friendly or adult-oriented content
	2. Explore whether certain genres are more likely to have specific ratings
4. **Duration Insights**
	1. Calculate the average duration of movies over time to see if movies are getting longer or shorter.
	2. Look at the average number of seasons per TV show, identifying which genres tend to have longer-running series.
5. **Text Analysis**
	1. Perform text analysis on titles and descriptions to find commonly used words or phrases (perhaps an indication of popular themes)
	2. Use sentiment analysis on show descriptions to gauge the overall tone (positive, negative, neutral) of the content offered.
6. **Viewer Interests**
	1. Identify correlations between genres to see if fans of one genre might also like another, based on the co-occurrence of genres across titles
	2. Analyze whether certain actors frequently appear in specific genres and if their presence correlates with a higher number of titles in those genres.

Alright, that brainstorming actually got me pretty excited. So let's get started!

---

## Toolset
- The Netflix data came in `CSV` format
- I did my initial perusal with **Excel**, but did not do any data manipulation there
- I used **PostgresSQL v.16.2** and **pgAdmin 4** for SQL tasks
- I used **Python 3.11.2** for a few data transformation and analysis tasks; including the following libraries:
	- **Pandas**
	- **NLTK**
	- **Collections**
	- **TextBlob**

---

## Exploring the Data
### Creating the Table
- After reviewing the data in *Excel*, I created a table in *PostgreSQL* to hold the data raw data that I would be importing from the `CSV`
```SQL
CREATE TABLE raw_netflix_data (
    show_id VARCHAR(255) PRIMARY KEY,
    content_type VARCHAR(50),
    title VARCHAR(255),
    director VARCHAR(255),
    actors TEXT,
    country VARCHAR(255),
    date_added DATE,
    release_year INT,
    rating VARCHAR(50),
    duration VARCHAR(100),
    listed_in VARCHAR(255),
    description TEXT
);
```
### Importing the Data
- Then I imported the `CSV` into the table with `PSQL` as follows:
```sh
\copy netflix_data FROM 'C:\netflix_titles.csv' WITH (FORMAT csv, HEADER true);
```
#### Resolving Errors When Importing
##### The Error
- And, of course, I got an error: 
```
ERROR: character with byte sequence 0x81 in encoding "WIN1252" has no equivalent in encoding "UTF8"
```
- I had a heck of a solving this error. Most "solutions" found via Google did not work. I tried forcing encoding to UTF-8 using Excel, Notepad++, *and* Python, but I was unsuccessful.
##### The Solution
- Finally I stumbled upon [this solution](https://stackoverflow.com/questions/1565234/character-with-encoding-utf8-has-no-equivalent-in-win1252) by Stack Overflow user [airstrike](https://stackoverflow.com/users/447485/airstrike) 
    - "I solved by setting the encoding to UTF8 with `\encoding UTF8` in the client"
    - I did the same: I ran `\encoding UTF8` in `PSQL` and after that I re-ran my `\copy` statement without a hitch!
### Planning the Schema
- The table schema is as follows:
![alt text](https://github.com/Chad-Lines/Data-Projects/blob/main/Netflix%20Data%20Preparation/image_container/1.png)
- And here's a look at the data:

**QUERY:**
```SQL
SELECT *
FROM raw_netflix_data
LIMIT 5
```
**RESULT:**
![alt text](\image_container\2.png)

#### Problems
- This is just a flat file with a lot of semi-structured data
- I would like to organize it into a cohesive structure that I can derive some useful insights from
#### Proposed Solution
- So I'm going to break out some **dimension tables**, **linking tables** and a central **fact table** as follows:
    - **Fact Table** 
        - `Fact_Netflix_Shows`
    - **Dimension Tables**
        - `Dim_Content_Type`
        - `Dim_Director`
        - `Dim_Actor`
        - `Dim_Country`
        - `Dim_Date`
        - `Dim_Rating`
        - `Dim_Genre`
    - **Linking Tables**
        - `Shows_Directors_Link`
        - `Shows_Actors_Link`
        - `Shows_Countries_Link`
        - `Shows_Genre_Link` 

---

## Creating the New Schema
### Creating the Dimension Tables
#### The Dim_Date Table
- The Dim_Date Table would be the most complicated because I needed to normalize, and include dates for whatever range the data might require. My first step was thence to determine that range
##### Creating the Dim_Date Table
- My first step would be simply to create the table:

**QUERY:**
```SQL 
CREATE TABLE Dim_Date (
    Date_ID SERIAL PRIMARY KEY,
    Date DATE,
    Year INTEGER,
    Quarter INTEGER,
    Month INTEGER,
    Month_Name VARCHAR(50),
    Week INTEGER,
    Day INTEGER,
    Day_Of_Week INTEGER,
    Day_Name VARCHAR(50)
)
```
##### Determining the Range For the Date Table
- I had two sources of dates:
	1. `date_added` - the full date that the media was added to Netflix
	2. `release_year` - the year that the media was actually produced
- I since the `date_added` date was more precise, I grabbed that as the end of the range

**QUERY:**
```SQL 
SELECT MAX(date_added)
FROM raw_netflix_data
-- Returned: 2021-09-25
```
- Now, Netflix has only been around for a few decades. So I knew that the `release_year` would be the better column to query for the start of the range:

**QUERY:**
```SQL 
SELECT MIN(release_year)
FROM raw_netflix_data
-- Returned: 1925
```
- So I knew that my date rage was `1925-01-01` to `2021-09-25`
##### Populating the Dim_Date Table
- I then needed to populate the Dim_Date Table with those dates
	- I knew that I could do this programmatically, but I wasn't entirely sure how
    - I had to do a little research, but the correct syntax wasn't hard to find, and was (I thought) surprisingly intuitive...
 
**QUERY:**
```SQL
INSERT INTO Dim_Date (Date, Year, Quarter, Month, Month_Name, Week, Day, Day_Of_Week, Day_Name)
SELECT
	gen_date,
	EXTRACT(YEAR FROM gen_date) AS Year,
	EXTRACT(QUARTER FROM gen_date) AS Quarter,
	EXTRACT(MONTH FROM gen_date) AS Month,
	TO_CHAR(gen_date, 'Month') AS Month_Name,
	EXTRACT(WEEK FROM gen_date) AS Week,
	EXTRACT(DAY FROM gen_date) AS Day,
	EXTRACT(ISODOW FROM gen_date) AS Day_Of_Week,
	TO_CHAR(gen_date, 'Day') AS Day_Name	
FROM
	generate_series(
		'1925-01-01'::date, -- start date
		'2021-09-25'::date, -- end date
		'1 day'::interval   -- interval
	) AS gen_date;
```
- Then I checked to make sure it looked right:
```SQL
SELECT COUNT(*) FROM Dim_Date 	-- Returns: 35332
SELECT * FROM Dim_Date ORDER BY date_id DESC LIMIT 10
```
**RESULT:**
![alt text](\image_container\3.png)
#### The Other Dimension Tables
- The other dimension tables were pretty straightforward. I created them as follows:

**QUERY:**
```SQL
CREATE TABLE Dim_Content_Type (
    Content_Type_ID SERIAL PRIMARY KEY,
    Content_Type_Description VARCHAR(50) NOT NULL
);

CREATE TABLE Dim_Director (
    Director_ID SERIAL PRIMARY KEY,
    Director_Fname VARCHAR(255),
    Director_Lname VARCHAR(255)
);

CREATE TABLE Dim_Actor (
    Actor_ID SERIAL PRIMARY KEY,
    Actor_Fname VARCHAR(255),
    Actor_Lname VARCHAR(255)
);

CREATE TABLE Dim_Country (
    Country_ID SERIAL PRIMARY KEY,
    Country_Name VARCHAR(255)
);

CREATE TABLE Dim_Rating (
    Rating_ID SERIAL PRIMARY KEY,
    Rating_Description VARCHAR(50) NOT NULL
);

CREATE TABLE Dim_Genre (
    Genre_ID SERIAL PRIMARY KEY,
    Genre_Description VARCHAR(255) NOT NULL
);

```
- And I can doublecheck that everything looks good:

**QUERY:**
```SQL
SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'
```
**RESULT:**
![alt text](\image_container\4.png)

### Creating the Fact Table
- As I began putting together the `Fact_Netflix_Shows` table, I realized that I have a problem with the `Duration` field. It is an `INT` followed by a `STRING` and it's different:
    - 'min' for movies
    - 'Seasons' for TV-Shows
- I realized I needed to fix that. So I decided to split that into two columns:
    - `Duration` - the numeric value of the duration (e.g., 90 for movies, 3 for TV shows)
    - `Duration_Unit` -  'min' for movies, 'Seasons' for TV shows
- I created the table as follows

**QUERY:**
```SQL
CREATE TABLE Fact_Netflix_Shows (
	Show_ID VARCHAR(255) PRIMARY KEY,
	Content_Type_ID INTEGER REFERENCES Dim_Content_Type(Content_Type_ID),
	Title VARCHAR(255) NOT NULL,
	Date_Added_ID INTEGER REFERENCES Dim_Date(Date_ID),
	Release_Year INTEGER,
	Rating_ID INTEGER REFERENCES Dim_Rating(Rating_ID),
	Duration INTEGER,
	Duration_Unit VARCHAR(50),
	Description TEXT
)
```
### Creating the Link Tables
- With that out of the way, it was time to create my link tables
- I created the link tables as follows:

**QUERY:**
```SQL
CREATE TABLE Shows_Directors_Link (
    Show_ID VARCHAR(255),
    Director_ID INTEGER,
    PRIMARY KEY (Show_ID, Director_ID),
    FOREIGN KEY (Show_ID) REFERENCES Fact_Netflix_Shows(Show_ID),
    FOREIGN KEY (Director_ID) REFERENCES Dim_Director(Director_ID)
)

CREATE TABLE Shows_Actors_Link(
	Show_ID VARCHAR(255),
	Actor_ID INTEGER,
	PRIMARY KEY (Show_ID, Actor_ID),
	FOREIGN KEY (Show_ID) REFERENCES Fact_Netflix_Shows(Show_ID),
	FOREIGN KEY (Actor_ID) REFERENCES Dim_Actor(Actor_ID)	
)

CREATE TABLE Shows_Countries_Link (
    Show_ID VARCHAR(255),
    Country_ID INTEGER,
    PRIMARY KEY (Show_ID, Country_ID),
    FOREIGN KEY (Show_ID) REFERENCES Fact_Netflix_Shows(Show_ID),
    FOREIGN KEY (Country_ID) REFERENCES Dim_Country(Country_ID)
)

CREATE TABLE Shows_Genre_Link (
    Show_ID VARCHAR(255),
    Genre_ID INTEGER,
    PRIMARY KEY (Show_ID, Genre_ID),
    FOREIGN KEY (Show_ID) REFERENCES Fact_Netflix_Shows(Show_ID),
    FOREIGN KEY (Genre_ID) REFERENCES Dim_Genre(Genre_ID)
)
```
## Populating the Schema
- Each table that has a many-to-many relationship, will require a little more finesse to populate because, in the raw data, those fields contain multiple values within the same field, delimited by a comma.
- So I'll start with the most straight-forward tables
### The Easy Ones
- The easy tables to populate will be `Dim_Content_Type` and `Dim_Rating`
    - In reviewing the `rating` information, I saw that some of the `durataion` data had been placed in there by mistake. So I needed to filter that out.
- I populated the tables as follows

**QUERY:**
```SQL
-- Dim_Content_Type
INSERT INTO Dim_Content_Type(Content_Type_Description)
	SELECT DISTINCT content_type
	FROM raw_netflix_data

-- Dim_Content_Type
INSERT INTO Dim_Rating(Rating_Description)
	SELECT DISTINCT rating
	FROM raw_netflix_data
    -- Filter out nulls and durations:
	WHERE rating IS NOT NULL
		AND rating NOT LIKE '%min%'
```

### Separating Values by Commas
- The following columns (in `raw_netflix_data`) contain multiple values delimited by a comma:
    - `director`
    - `actors`
    - `country`
    - `listed_in` (renamed `genre` for our `Dim_Genre` table)
- The process of un-nesting those values turned out to be easier than I thought, thanks to two functions:
    1. `STRING_TO_ARRAY` - which converts a string to an array using a delimiter to separate array elements
    2. `UNNEST` - unpacks an array
- Using those functions I was able to populate the tables as follows:

**QUERY:**
```SQL
-- Dim_Director
INSERT INTO Dim_Director(Director_Name)
	SELECT DISTINCT
		UNNEST(STRING_TO_ARRAY(director, ', '))
	FROM raw_netflix_data
		WHERE director IS NOT NULL
	
-- Dim_Actors
INSERT INTO Dim_Actor(Actor_Name)
	SELECT DISTINCT 
		UNNEST(STRING_TO_ARRAY(actors,', '))
	FROM raw_netflix_data
		WHERE actors IS NOT NULL 

-- Dim_Country
INSERT INTO Dim_Country(Country_Name)
	SELECT DISTINCT 
		UNNEST(STRING_TO_ARRAY(country,', '))
	FROM raw_netflix_data
		WHERE country IS NOT NULL 
		
-- Dim_Genre
INSERT INTO Dim_Genre(Genre_Description)
	SELECT DISTINCT 
		UNNEST(STRING_TO_ARRAY(listed_in,', '))
	FROM raw_netflix_data
		WHERE listed_in IS NOT NULL 
```
### Populating the Fact Table
- Populating the fact table was a little tricky because of the way the `Duration` data was formatted. My solution is probably a bit inelegant, but it got the job done.
- Here's how I populated the `Fact_Netflix_Shows` table:

**QUERY:**
```SQL
INSERT INTO Fact_Netflix_Shows
(Show_ID, Content_Type_ID, Title_ID, Date_Added_ID, Release_Year, Rating_ID, Duration, Duration_Unit, Description)
	SELECT
		raw.show_id,
		ct.Content_Type_ID,
		raw.title,
		d.Date_ID,
		raw.release_year,
		r.Rating_ID,
		-- Getting the duration interger
		CASE WHEN raw.duration LIKE '% min' THEN REPLACE(raw.duration, ' min', '')::INTEGER
			WHEN raw.duration LIKE '% Seasons%' THEN REPLACE(raw.duration, ' Seasons', '')::INTEGER
			WHEN raw.duration LIKE '% Season%' THEN REPLACE(raw.duration, ' Season', '')::INTEGER		
			ELSE NULL 
			END AS Duration,
		-- Getting the duration unit
		CASE WHEN raw.duration LIKE '% min' THEN 'Minute'
			WHEN raw.duration LIKE '% Seasons%' THEN 'Season'
			WHEN raw.duration LIKE '% Season%' THEN 'Season'         
			ELSE NULL 
			END AS Duration_Unit,
		raw.description
	FROM raw_netflix_data raw
		JOIN Dim_Content_Type ct ON ct.Content_Type_Description = raw.content_type
		JOIN Dim_Rating r ON r.Rating_Description = raw.rating
		LEFT JOIN Dim_Date d ON d.Date = raw.date_added
```
- And now if I query:

**QUERY:**

```SQL
SELECT * FROM Fact_Netflix_Shows
```
**RESULT:**
![alt text](\image_container\5.png)


### Populating the Link Tables
#### Creating Indexes to Improve Performance
- I actually populated the `Shows_Directors_Link` table, but noticed some performance issues while working on the `Shows_Actors_Link` population (took over 4 minutes to complete the `SELECT` query)
    - And that's when I realized I should probably be creating some indexes
- So before continuing on I created the following indexes:

**QUERY:**
```SQL
CREATE INDEX idx_raw_netflix_data_show_id ON raw_netflix_data (show_id);
CREATE INDEX idx_fact_netflix_shows_show_id ON Fact_Netflix_Shows (Show_ID);
CREATE INDEX idx_dim_actor_name ON Dim_Actor (Actor_Name);
CREATE INDEX idx_dim_date ON Dim_Date (Date)
CREATE INDEX idx_dim_director_name ON Dim_Director (Director_Name);
```

#### Populating the Link Tables
- As mentioned, I did the `Shows_Directors_Link` table first, arbitrarily. It took me a while to figure that one out, but once again `STRING_TO_ARRAY` came to my rescue.
	- Figuring out the `Shows_Directors_Link` table gave me a simple template for doing the rest.
- I populated the link tables as follows:

**QUERY:**
```SQL
-- Shows_Directors_Link
INSERT INTO Shows_Directors_Link (Show_ID, Director_ID)
	SELECT fact.Show_ID, dir.Director_ID
	FROM raw_netflix_data raw
	JOIN Fact_Netflix_Shows fact ON raw.show_id = fact.Show_ID
	JOIN Dim_Director dir ON dir.Director_Name = ANY(STRING_TO_ARRAY(raw.director, ', '))
	WHERE raw.director IS NOT NULL

-- Shows_Actors_Link -- much faster after index creation - < 0.5 seconds
INSERT INTO Shows_Actors_Link (Show_ID, Actor_ID)
	SELECT fact.Show_ID, act.Actor_ID
	FROM raw_netflix_data raw
	JOIN Fact_Netflix_Shows fact ON raw.show_ID = fact.Show_ID
	JOIN Dim_Actor act ON act.Actor_Name = ANY(STRING_TO_ARRAY(raw.actors, ', '))
	WHERE raw.actors IS NOT NULL

-- Shows_Countries_Link
INSERT INTO Shows_Countries_Link (Show_ID, Country_ID)
	SELECT fact.Show_ID, act.Actor_ID
	FROM raw_netflix_data raw
	JOIN Fact_Netflix_Shows fact ON raw.show_ID = fact.Show_ID
	JOIN Dim_Actor act ON act.Actor_Name = ANY(STRING_TO_ARRAY(raw.actors, ', '))
	WHERE raw.actors IS NOT NULL

-- Shows_Genre_Link
INSERT INTO Shows_Genre_Link (Show_ID, Genre_ID)
	SELECT fact.Show_ID, genre.Genre_ID
	FROM raw_netflix_data raw
	JOIN Fact_Netflix_Shows fact ON raw.show_ID = fact.Show_ID
	JOIN Dim_Genre genre ON genre.Genre_Description = ANY(STRING_TO_ARRAY(raw.listed_in, ', '))
	WHERE raw.listed_in IS NOT NULL
```
---

## Creating The Views
- Now that the tables in the schema are created and populated, I'm ready to create the views. 
    - Since this data won't be updating at all (and since I haven't worked with them yet, and enjoy learning new things) I will be creating them as *Materialized Views*
### Content Distribution Analysis
#### A View for "Genre Popularity Over Time"
- **Original Idea:** Which genres are most common or growing in popularity over time
- **View:** I need a view that aggregates the number of shows by `genre` *and* `release_year`.

**QUERY:**
```SQL
CREATE MATERIALIZED VIEW Genre_Popularity_Over_Time AS
	SELECT g.Genre_Description, f.Release_Year, COUNT(*) AS Show_Count
	FROM Shows_Genre_Link sgl
	JOIN Dim_Genre g ON sgl.Genre_ID = g.Genre_ID
	JOIN Fact_Netflix_Shows f ON sgl.Show_ID = f.Show_ID
	WHERE f.Release_Year IS NOT NULL
	GROUP BY g.Genre_Description, f.Release_Year
	ORDER BY f.Release_Year, Show_Count DESC
```
**RESULT:**
![alt text](\image_container\6.png)
**OBSERVATION:**
- This view provides a great way to explore different genres. For example, using:
```SQL
SELECT * 
FROM Genre_Popularity_Over_Time 
WHERE genre_description LIKE '%Horror Movies%'
ORDER BY release_year DESC
```
![alt text](\image_container\22.png)

- This shows that there has been a sharp up-tick in horror movies produce (and added to Netflix) since 2013. 

#### A View for "Directors with Most Titles; With Genres"
- **Original Idea:** Which directors have the most titles on Netflix in which genres they primarily work
- **View:** I need a view that identifies directors with the most titles, along with the genres they're most involved in.

**QUERY:**
```SQL
CREATE MATERIALIZED VIEW Directors_Most_Titles AS
	SELECT d.Director_Name, g.Genre_Description, COUNT(f.Show_ID) AS Title_Count
	FROM Shows_Directors_Link sdl
	JOIN Dim_Director d ON sdl.Director_ID = d.Director_ID
	JOIN Shows_Genre_Link sgl ON sdl.Show_ID = sgl.Show_ID
	JOIN Dim_Genre g ON sgl.Genre_ID = g.Genre_ID
	JOIN Fact_Netflix_Shows f ON sdl.Show_ID = f.Show_ID
	GROUP BY d.Director_Name, g.Genre_Description
	ORDER BY Title_Count DESC;
```
**RESULT:**
![alt text](\image_container\7.png)
**OBSERVATION:**
- This one is pretty self explanatory. It shows us which directors tend to focus on which genres 
- We can narrow this down to an exploration of the works of a single director. For example, we can see what genres one of my personal favorite directors tends to work in:
```SQL
SELECT * FROM Directors_Most_Titles
WHERE director_name LIKE '%Sam Raimi%'
```
![alt text](\image_container\23.png)
- This actually piqued my curiosity. I was curious about how many movies Sam Raimi had on Netflix (it must only be a few), and what movies would span those genres. So I ran:
```SQL
SELECT d.Director_Name, f.Title
FROM Fact_Netflix_Shows f
JOIN Shows_Directors_Link sdl ON f.Show_ID = sdl.Show_ID
JOIN Dim_Director d ON sdl.Director_ID = d.Director_ID
WHERE d.Director_Name LIKE '%Sam Raimi%'
```
![alt text](\image_container\24.png)
- Yeah, that makes sense - although, I might argue there are **two** classics on that list :) 
- That also prompted me to create yet-another view
```SQL
CREATE MATERIALIZED VIEW production_by_director AS
	SELECT d.Director_Name, f.Title
	FROM Fact_Netflix_Shows f
	JOIN Shows_Directors_Link sdl ON f.Show_ID = sdl.Show_ID
	JOIN Dim_Director d ON sdl.Director_ID = d.Director_ID
	ORDER BY director_name
```
#### A View for "Content Production Distribution by Country"
- **Original Idea:** Track the distribution of content production by country
- **View:** I need a view that helps track the number of titles produced by each country

**QUERY:**
```SQL
CREATE MATERIALIZED VIEW Content_Production_By_Country AS
	SELECT c.Country_Name, COUNT(f.Show_ID) AS Production_Count
	FROM Shows_Countries_Link scl
	JOIN Dim_Country c ON scl.Country_ID = c.Country_ID
	JOIN Fact_Netflix_Shows f ON scl.Show_ID = f.Show_ID
	GROUP BY c.Country_Name
	ORDER BY Production_Count DESC;
```
**RESULT:**
![alt text](\image_container\8.png)
**OBSERVATION:**
- This is pretty self-explanatory.
### Release Pattern Analysis
#### A View for "Titles Added Over Time"
- **Original Idea:** Examine how the number of titles added to Netflix has changed over time
- **View:** I need a view that calculates the number of titles added to Netflix by year and month, which helps in examining trends over time in content addition.

**QUERY:**
```SQL
CREATE MATERIALIZED VIEW Titles_Added_Over_Time AS
	SELECT
		DATE_PART('year', d.Date) AS Year_Added,
		DATE_PART('month', d.Date) AS Month_Added,
		COUNT(*) AS Title_Count
	FROM Fact_Netflix_Shows f
	JOIN Dim_Date d ON f.Date_Added_ID = d.Date_ID
	GROUP BY Year_Added, Month_Added
	ORDER BY Year_Added, Month_Added;
```
**RESULT:**
![alt text](\image_container\9.png)
**OBSERVATIONS:**
- It's not surprising to see that, for the most part, more titles are added overtime. It could be helped by aggregating a bit further:
```SQL
SELECT year_added, SUM(title_count)
FROM Titles_Added_Over_Time
GROUP BY year_added
ORDER BY year_added DESC
```
![alt text](\image_container\25.png)
#### A View for "Catalog Freshness (Release Year vs. Year Added)"
- **Original Idea:** Compare the release year of titles to the year they were added to Netflix to see how fresh the Netflix catalog is
- **View:** I need a view that compares the release year of titles to the year they were added to Netflix, providing insights into the catalog's freshness.

**QUERY:**
```SQL
CREATE MATERIALIZED VIEW Catalog_Freshness AS
	SELECT
		f.Release_Year,
		DATE_PART('year', d.Date) AS Year_Added,
		COUNT(*) AS Title_Count,
		AVG(DATE_PART('year', d.Date) - f.Release_Year) AS Avg_Years_Between_Release_And_Added
	FROM Fact_Netflix_Shows f
	JOIN  Dim_Date d ON f.Date_Added_ID = d.Date_ID
	GROUP BY  f.Release_Year, Year_Added
	ORDER BY f.Release_Year, Year_Added;
```
**RESULT:**
![alt text](\image_container\10.png)
**OBSERVATIONS:**
- For the sake of illustration, it could help to aggregate this one a little further as well
```SQL
SELECT 
	year_added, 
	ROUND(AVG(avg_years_between_release_and_added)) AS avg_yrs_between_prod_and_release
FROM Catalog_Freshness 
GROUP BY year_added
ORDER BY year_added DESC
```
![alt text](\image_container\26.png)
### Content Rating Analysis
#### A View for "Distribution of Content Ratings Over Time"
- **Original Idea:** Investigate the distribution of content ratings to see if there's a trend towards more family-friendly or adult-oriented content
- **View:** I need a view that calculates the distribution of content ratings over time

**QUERY:**
```SQL
CREATE MATERIALIZED VIEW Content_Rating_Distribution AS
	SELECT
		r.Rating_Description,
		DATE_PART('year', d.Date) AS Year_Added,
		COUNT(*) AS Title_Count
	FROM Fact_Netflix_Shows f
	JOIN Dim_Rating r ON f.Rating_ID = r.Rating_ID
	JOIN Dim_Date d ON f.Date_Added_ID = d.Date_ID
	GROUP BY r.Rating_Description, Year_Added
	ORDER BY Year_Added, r.Rating_Description;
```
**RESULT:**
![alt text](\image_container\11.png)
**OBSERVATIONS:**
- At face value, this doesn't look like much, but it helps if we do some filtering. For example, we can see how much "adult" media has been added to Netflix over time with the following query:
```SQL
SELECT * FROM Content_Rating_Distribution 
WHERE rating_description IN ('TV-MA', 'R','NC-17')
ORDER BY year_added DESC, title_count
```
![alt text](\image_container\27.png)
#### A View for "Content Rating by Genre"
- **Original Idea:** Explore whether certain genres are more likely to have specific ratings
- **View:** I need a view that explores the relationship between genres and content ratings

**QUERY:**
```SQL
 CREATE MATERIALIZED VIEW Genre_Rating_Distribution AS
	SELECT
		g.Genre_Description,
		r.Rating_Description,
		COUNT(*) AS Title_Count
	FROM Shows_Genre_Link sgl
	JOIN Dim_Genre g ON sgl.Genre_ID = g.Genre_ID
	JOIN Fact_Netflix_Shows f ON sgl.Show_ID = f.Show_ID
	JOIN Dim_Rating r ON f.Rating_ID = r.Rating_ID
	GROUP BY g.Genre_Description, r.Rating_Description
	ORDER BY g.Genre_Description, r.Rating_Description;
```
**RESULT:**
![alt text](\image_container\12.png)\
**OBSERVATIONS:**
- This data is fine. We can probably do some aggregations or filtering to get a clearer view of things, but as a start, this is good, and - were this put into a visualization - we may want to allow the business user to do those operations on their own
### Duration Insights
#### A View for "Average Duration of Movies Over Time"
- **Original Idea:** Calculate the average duration of movies over time to see if movies are getting longer or shorter.
- **View:** I need a view that calculates the average duration of movies by release year

**QUERY:**
```SQL
CREATE MATERIALIZED VIEW Avg_Movie_Duration_Over_Time AS
	SELECT f.Release_Year, AVG(f.Duration) AS Avg_Duration_Minutes
	FROM Fact_Netflix_Shows f
	JOIN  Dim_Content_Type ct ON f.Content_Type_ID = ct.Content_Type_ID
	WHERE ct.Content_Type_Description = 'Movie'
		AND f.Duration_Unit = 'Minute'
	GROUP BY f.Release_Year
	ORDER BY f.Release_Year;
```
**RESULT:**
![alt text](\image_container\13.png)
**OBSERVATIONS:**
- This one is pretty self-explanatory.
#### A View for "Average Number of Seasons per TV Show by Genre"
- **Original Idea:** Look at the average number of seasons per TV show, identifying which genres tend to have longer-running series.
- **View:** I need a view that examines the average number of seasons per TV show, broken down by genre

**QUERY:**
```SQL
CREATE MATERIALIZED VIEW Avg_Seasons_Per_Genre AS
	SELECT
		g.Genre_Description,
		AVG(f.Duration) AS Avg_Number_of_Seasons
	FROM Shows_Genre_Link sgl
	JOIN Dim_Genre g ON sgl.Genre_ID = g.Genre_ID
	JOIN Fact_Netflix_Shows f ON sgl.Show_ID = f.Show_ID
	JOIN  Dim_Content_Type ct ON f.Content_Type_ID = ct.Content_Type_ID
	WHERE ct.Content_Type_Description = 'TV Show'
		AND f.Duration_Unit = 'Season'
	GROUP BY g.Genre_Description
	ORDER BY Avg_Number_of_Seasons DESC;
```
**RESULT:**
![alt text](\image_container\14.png)
**OBSERVATIONS:**
- `Classic & Cult TV` is the obvious stand-out here. 
### Text Analysis
#### Peculiarities of These Views
- These views were a bit more tricky as they required text analysis that cannot be done easily in PostgreSQL (or, if they can, I am unaware of *how*.)
    - Instead, I decided I would do that in **Python**
- So I ran the following query to extract the title and description of the shows:
```SQL
SELECT Title, Description FROM Fact_Netflix_Shows;
```
- I saved the results of that query to a file called `ta.csv` so that I could do the text analysis in Python
#### A View for "Commonly Used Words or Phrases in Titles and Descriptions"
- **Original Idea:** Perform text analysis on titles and descriptions to find commonly used words or phrases
- **View:** I need a view that examines and displays the top 100 used words in titles and descriptions
- I had to do a little research and brush up on my Python to get this, but I finally wrote the following script.
    - This script extracts the most commonly-used words from `ta.csv` file
```Python
import pandas as pd
import nltk
from nltk.corpus import stopwords
from collections import Counter
import csv

# Download necessary tools from nltk
nltk.download('stopwords')
nltk.download('punkt')

# Read csv into a dataframe
df = pd.read_csv('ta.csv')

# Combine all titles and descriptions into a single text
all_text = ' '.join(df['title']) + ' ' + ' '.join(df['description'])

# Tokenize and remove stop words
words = nltk.word_tokenize(all_text)
filtered_words = [word for word in words if word.isalnum() and word not in stopwords.words('english')]

# Count and display most common words
word_counts = Counter(filtered_words)
common_words_df = pd.DataFrame(word_counts.most_common(10), columns=['Word', 'Count'])

# Save to csv
common_words_df.to_csv('common_words.csv', index=False)
```
#### A View for "Sentiment Analysis on Show Descriptions"
- **Original Idea:** Use sentiment analysis on show descriptions to gauge the overall tone (positive, negative, neutral) of the content offered.
- **View:** I need a view which provides sentiment scores (polarity and subjectivity) for the titles and descriptions.
- This was even more tricky, but I found the `TextBlob` library, and it did the heavy lifting for me. 
```Python
from textblob import TextBlob
import pandas as pd

# Read the csv into a dataframe
df = pd.read_csv('ta.csv')

# Function to use TextBlob to get the sentiment
def get_sentiment(text):
    blob = TextBlob(text)
    return blob.sentiment.polarity, blob.sentiment.subjectivity

# Apply the get_sentiment function to each description
df[['Polarity', 'Subjectivity']] = df['description'].apply(
    lambda x: pd.Series(get_sentiment(x))
)

# Save to CSV
df.to_csv('sentiment_analysis.csv', columns=['title', 'description', 'Polarity', 'Subjectivity'], index=False)

```
#### Adding the CSVs Back into the Database
- The first thing I needed to do was create the tables for the csv data to live in:

```SQL
-- Creating the word_count table
CREATE TABLE ta_word_count(
	word VARCHAR(255) PRIMARY KEY NOT NULL,
	count INT NOT NULL
)

-- Creating the sentiment_analysis table
CREATE TABLE ta_sentiment_analysis(
	title VARCHAR(255) PRIMARY KEY NOT NULL,
	description TEXT NOT NULL,
	polarity NUMERIC,
	subjectivity NUMERIC
)
```
- Then I imported the csv data into the appropriate table using `PSQL`

```sh
\copy ta_word_count FROM 'C:\common_words.csv' WITH (FORMAT csv, HEADER true);
\copy ta_sentiment_analysis FROM 'C:\sentiment_analysis.csv' WITH (FORMAT csv, HEADER true);
```
#### Creating the Views
- I know this is redundant, but the tables are small, and I have an minor obsession with continuity. So I went ahead and created the following views:
```SQL

CREATE MATERIALIZED VIEW most_commonly_used_words AS
	SELECT * FROM ta_word_count

CREATE MATERIALIZED VIEW title_description_sentiment_analysis AS
	SELECT * FROM ta_sentiment_analysis
```
**RESULT: (most_commonly_used_words)**
![alt text](\image_container\15.png)
**RESULT: (title_description_sentiment_analysis)**
![alt text](\image_container\16.png)
**OBSERVATIONS:**
- This provides the information I wanted to include. It looks like "life", "family" and "love" are big themes among Netflix media
### Viewer Interests
#### Back into Python
- Hello Python, my old friend, I've come to talk with you again...
#### A View for the Correlations Between Genres
- **Original Idea:** Identify correlations between genres to see if fans of one genre might also like another, based on the co-occurrence of genres across titles
- **View:** I need a view that identifies (approximates) if fans of one genre might also like another, based on the co-occurrence of genres across titles.
##### The SQL
- I just need to extract all titles (`show_id`)and their associated genres to process in Python.
```SQL
SELECT f.Show_ID, g.Genre_Description
FROM Shows_Genre_Link sgl
JOIN Dim_Genre g ON sgl.Genre_ID = g.Genre_ID
JOIN Fact_Netflix_Shows f ON sgl.Show_ID = f.Show_ID;
```
##### The Python
- My goal is to calculate genre co-occurrence and correlations.
- I'll be using `pandas` and `itertools`
```Python
import pandas as pd
from itertools import combinations
from collections import Counter

# Read the csv exported from Postgresql
df = pd.read_csv('genre_associations.csv')

# Group data by Show_ID, aggregating genres into lists
grouped = df.groupby('show_id')['genre_description'].apply(list).reset_index()

# Generate all possible genre pairs for each title and count occurrences
genre_pairs = Counter([pair for sublist in grouped['genre_description'] for pair in combinations(sublist, 2)])

# Convert to DataFrame for export
genre_pairs_df = pd.DataFrame(genre_pairs.items(), columns=['genre_pair', 'count']).sort_values(by='count', ascending=False)

# Save to CSV
genre_pairs_df.to_csv('genre_correlations.csv', index=False)

```
##### Creating the Table, Importing Data, Creating the View
- Going to go fast, since we've done this several times now.
```SQL
CREATE TABLE genre_correlations(
	Genre_Pair TEXT,
	Count INTEGER
)
```
- Import:
```sh
\copy genre_correlations FROM 'C:\genre_correlations.csv' WITH (FORMAT csv, HEADER true);
```
- Create View
```SQL
CREATE MATERIALIZED VIEW genre_correlations_view AS
	SELECT * FROM genre_correlations
```
**RESULT: (genre_correlations_view)**
![alt text](\image_container\17.png)
**OBSERVATIONS:**
- The meaning of this table may not be immediately obvious. A question that it might answer is "If I like International Movies, what other genre might I like?" and the answer, per row 1, would be "Dramas"
- It's, admittedly, not a very robust recommendation solution, but it provides a general overview of the genre correlations
#### A View for Actor Frequency in Specific Genres
- **Original Idea:** Analyze whether certain actors frequently appear in specific genres and if their presence correlates with a higher number of titles in those genres.
- **View:** I need a view that analyzes whether certain actors appear frequently in specific genres and if their presence correlates with a higher number of titles in those genres (big surprise, eh?)
##### The SQL
```SQL
-- The only "complication" is that we're using the link table
SELECT a.Actor_Name, g.Genre_Description
FROM Shows_Actors_Link sal 
JOIN Dim_Actor a ON sal.Actor_ID = a.Actor_ID 
JOIN Shows_Genre_Link sgl ON sal.Show_ID = sgl.Show_ID
JOIN Dim_Genre g ON sgl.Genre_ID = g.Genre_ID;
```
##### The Python
```Python
import pandas as pd

# Read the CSV
df = pd.read_csv('actor_genre_associations.csv')

# Count how many times each actor appears in each genre
actor_genre_counts = df.groupby(['actor_name', 'genre_description']).size().unstack(fill_value=0)

# Get the most common genre for each actor
actor_genre_counts['most_common_genre'] = actor_genre_counts.idxmax(axis=1)

# Save to CSV
actor_genre_counts.to_csv('actor_genre_frequencies.csv')

```
##### Creating the Table, Importing Data, Creating the View
- This was a rather cumbersome table because it included, as columns, each of the 42 genres. I'll abbreviate it here for brevity.
```SQL
CREATE TABLE da_actor_genre_frequencies(
    actor_name VARCHAR(255),
    british_tv_shows INTEGER,
    children_and_family_movies INTEGER,
    -- OTHER COLUMNS/GENRES HERE...
    anime_series INTEGER,
    docuseries INTEGER,
    most_common_genre VARCHAR(255)
)
```
- Importing the data
```sh
\copy da_actor_genre_frequencies FROM 'C:\actor_genre_frequencies.csv' WITH (FORMAT csv, HEADER true);
```
- I decided to create two views - a full view and a partial view that only had the `actor_name` and their `most_common_genre`
```SQL
CREATE MATERIALIZED VIEW actors_and_genres_total AS
	SELECT * FROM da_actor_genre_frequencies

CREATE MATERIALIZED VIEW actors_and_genres_most_common AS
	SELECT actor_name, most_common_genre
	FROM da_actor_genre_frequencies
```
**RESULT: (actors_and_genres_total)**
![alt text](\image_container\18.png)
**OBSERVATIONS:**
- This table would certainly need to be filtered and aggregated to provide more meaningful insights. However, I'm happy with this table as a basis for those operations.

**RESULT: (actors_and_genres_most_common)**
![alt text](\image_container\19.png)
**OBSERVATIONS:**
- This table is great. It's interesting to look for specific actors/actresses. As in:
```SQL
SELECT * FROM actors_and_genres_most_common
WHERE actor_name IN ('Philip Seymour Hoffman', 'Jim Carrey')
```
![alt text](\image_container\28.png)
### Cleanup
#### Renaming Tables
- With some of the tables, especially those which I created for exporting for Python - I was a little haphazard in the naming. I mentioned before that I have a *light* obsession with continuity, so I'm going to go ahead and clean that up.
- For any tables created for the purpose of using with python, or importing *from* python, I'm going to add the prefix `da_`
```SQL
ALTER TABLE ta_sentiment_analysis
	RENAME TO da_sentiment_analysis
	
ALTER TABLE ta_word_count
	RENAME TO da_word_count
	
ALTER TABLE genre_correlations
	RENAME TO da_genre_correlations	
```
#### Finishing Up
- Because the views were created as **Materialized** Views it is not necessary to redo the views after renaming the tables.
- **However**, if I was going to be using this dataset beyond this one project, then I would go ahead and update the views based on those tables, even though it's not strictly necessary
- Here are our beautiful tables. For the sake of continuity, I should rename the `link` tables to have `link_` as a prefix rather than a suffix, but - as with the views - it's already "better than good; it's *good enough*."
![alt text](\image_container\20.png)
- And here are the final views:
![alt text](\image_container\21.png)

---

## Conclusion
### Thoughts on the Project
- This was a much longer, more complex project than I anticipated at the outset. But it was a lot of fun. 
- I've heard that many Data Analysts consider the *visuals* to be the "fun part". I disagree. Being able to organize, transform, and aggregate disorganized data into *meaningful insights* is the whole point, in my opinion.  
	- The visuals are important, of course, but most of the heavy lifting takes place on the back end.
- I was happy to be able to use Python to complete some of the tasks. It's been a while since I've worked in Python, and it was fun to jump back in. 
	- I'd never worked with the `nltk` or `TextBlob` libraries before, and so that was an enjoyable experience as well
### Things I Could Have Done Better
- At some points, additional summarizations could have been better. It's possible that with some views, like `actors_and_genres_total`, I'm expecting too much of the business users
- I ought to have rounded most, if not all, of the decimal values to two decimal. In some cases I could have just rounded to a whole number.
	- If this was a professional project, I would go back and fix that so that it didn't have to be done on the visualization side. But, since this *was* the project, I'm content to leave it as it is (for now)
### Going Forward
- I *may* come back to this project and do some visualizations.
- However, it was already longer than anticipated and I'm a bit burnt out on it. I would like to explore some other datasets first

/* =========================================

	DROP TABLES

   =========================================*/
-- Dimensions
DROP TABLE IF EXISTS Dim_Content_Type
DROP TABLE IF EXISTS Dim_Director
DROP TABLE IF EXISTS Dim_Actor
DROP TABLE IF EXISTS Dim_Country
-- DROP TABLE IF EXISTS Dim_Date
DROP TABLE IF EXISTS Dim_Rating
DROP TABLE IF EXISTS Dim_Genre

-- Fact
DROP TABLE IF EXISTS Fact_Netflix_Shows

-- Links
DROP TABLE IF EXISTS Shows_Directors_Link
DROP TABLE IF EXISTS Shows_Actors_Link
DROP TABLE IF EXISTS Shows_Countries_Link
DROP TABLE IF EXISTS Shows_Genre_Link

/* =========================================

	CREATE TABLES

   =========================================*/
 -- Date table
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

-- Other Dimension Tables
CREATE TABLE Dim_Content_Type (
    Content_Type_ID SERIAL PRIMARY KEY,
    Content_Type_Description VARCHAR(50) NOT NULL
);

CREATE TABLE Dim_Director (
    Director_ID SERIAL PRIMARY KEY,
    Director_Name VARCHAR(255)
);

CREATE TABLE Dim_Actor (
    Actor_ID SERIAL PRIMARY KEY,
    Actor_Name VARCHAR(255)
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

-- Fact Table
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

-- Link Tables
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
    Director_ID INTEGER,
    PRIMARY KEY (Show_ID, Director_ID),
    FOREIGN KEY (Show_ID) REFERENCES Fact_Netflix_Shows(Show_ID),
    FOREIGN KEY (Director_ID) REFERENCES Dim_Director(Director_ID)
)

CREATE TABLE Shows_Genre_Link (
    Show_ID VARCHAR(255),
    Genre_ID INTEGER,
    PRIMARY KEY (Show_ID, Genre_ID),
    FOREIGN KEY (Show_ID) REFERENCES Fact_Netflix_Shows(Show_ID),
    FOREIGN KEY (Genre_ID) REFERENCES Dim_Genre(Genre_ID)
)

/* =========================================

	CREATE INDEXES

   =========================================*/
CREATE INDEX idx_raw_netflix_data_show_id ON raw_netflix_data (show_id);
CREATE INDEX idx_fact_netflix_shows_show_id ON Fact_Netflix_Shows (Show_ID);
CREATE INDEX idx_dim_actor_name ON Dim_Actor (Actor_Name);
CREATE INDEX idx_dim_date ON Dim_Date (Date)
CREATE INDEX idx_dim_director_name ON Dim_Director (Director_Name);

/* =========================================

	POPULATE TABLES

   =========================================*/
-- Dim_Date
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

-- Dim_Content_Type
INSERT INTO Dim_Content_Type(Content_Type_Description)
	SELECT DISTINCT content_type
	FROM raw_netflix_data

-- Dim_Content_Type
INSERT INTO Dim_Rating(Rating_Description)
	SELECT DISTINCT rating
	FROM raw_netflix_data
	WHERE rating IS NOT NULL
		AND rating NOT LIKE '%min%'

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

-- Shows_Directors_Link
INSERT INTO Shows_Directors_Link (Show_ID, Director_ID)
	SELECT fact.Show_ID, dir.Director_ID
	FROM raw_netflix_data raw
	JOIN Fact_Netflix_Shows fact ON raw.show_id = fact.Show_ID
	JOIN Dim_Director dir ON dir.Director_Name = ANY(STRING_TO_ARRAY(raw.director, ', '))
	WHERE raw.director IS NOT NULL

-- Shows_Actors_Link
INSERT INTO Shows_Actors_Link (Show_ID, Actor_ID)
	SELECT fact.Show_ID, act.Actor_ID
	FROM raw_netflix_data raw
	JOIN Fact_Netflix_Shows fact ON raw.show_ID = fact.Show_ID
	JOIN Dim_Actor act ON act.Actor_Name = ANY(STRING_TO_ARRAY(raw.actors, ', '))
	WHERE raw.actors IS NOT NULL

-- Shows_Countries_Link
INSERT INTO Shows_Countries_Link (Show_ID, Country_ID)
	SELECT fact.Show_ID, country.Country_ID
	FROM raw_netflix_data raw
	JOIN Fact_Netflix_Shows fact ON raw.show_ID = fact.Show_ID
	JOIN Dim_Country country ON country.Country_Name = ANY(STRING_TO_ARRAY(raw.country, ', '))
	WHERE raw.country IS NOT NULL

-- Shows_Genre_Link
INSERT INTO Shows_Genre_Link (Show_ID, Genre_ID)
	SELECT fact.Show_ID, genre.Genre_ID
	FROM raw_netflix_data raw
	JOIN Fact_Netflix_Shows fact ON raw.show_ID = fact.Show_ID
	JOIN Dim_Genre genre ON genre.Genre_Description = ANY(STRING_TO_ARRAY(raw.listed_in, ', '))
	WHERE raw.listed_in IS NOT NULL

/* =========================================

	CREATING VIEWS

   =========================================*/
--- Aggregate the number of shows by genre and release_year
CREATE MATERIALIZED VIEW Genre_Popularity_Over_Time AS
	SELECT g.Genre_Description, f.Release_Year, COUNT(*) AS Show_Count
	FROM Shows_Genre_Link sgl
	JOIN Dim_Genre g ON sgl.Genre_ID = g.Genre_ID
	JOIN Fact_Netflix_Shows f ON sgl.Show_ID = f.Show_ID
	WHERE f.Release_Year IS NOT NULL
	GROUP BY g.Genre_Description, f.Release_Year
	ORDER BY f.Release_Year, Show_Count DESC;

SELECT * FROM Genre_Popularity_Over_Time 

-- Identify directors with the most titles, along with the genres they're most involved in.
CREATE MATERIALIZED VIEW Directors_Most_Titles AS
	SELECT d.Director_Name, g.Genre_Description, COUNT(f.Show_ID) AS Title_Count
	FROM Shows_Directors_Link sdl
	JOIN Dim_Director d ON sdl.Director_ID = d.Director_ID
	JOIN Shows_Genre_Link sgl ON sdl.Show_ID = sgl.Show_ID
	JOIN Dim_Genre g ON sgl.Genre_ID = g.Genre_ID
	JOIN Fact_Netflix_Shows f ON sdl.Show_ID = f.Show_ID
	GROUP BY d.Director_Name, g.Genre_Description
	ORDER BY Title_Count DESC;

SELECT * FROM Directors_Most_Titles 

-- Track the distribution of content production by country
CREATE MATERIALIZED VIEW Content_Production_By_Country AS
	SELECT c.Country_Name, COUNT(f.Show_ID) AS Production_Count
	FROM Shows_Countries_Link scl
	JOIN Dim_Country c ON scl.Country_ID = c.Country_ID
	JOIN Fact_Netflix_Shows f ON scl.Show_ID = f.Show_ID
	GROUP BY c.Country_Name
	ORDER BY Production_Count DESC;

SELECT * FROM Content_Production_By_Country 

-- Calculate the number of titles added to Netflix by year and month
CREATE MATERIALIZED VIEW Titles_Added_Over_Time AS
	SELECT
		DATE_PART('year', d.Date) AS Year_Added,
		DATE_PART('month', d.Date) AS Month_Added,
		COUNT(*) AS Title_Count
	FROM Fact_Netflix_Shows f
	JOIN Dim_Date d ON f.Date_Added_ID = d.Date_ID
	GROUP BY Year_Added, Month_Added
	ORDER BY Year_Added, Month_Added;
	
SELECT * FROM Titles_Added_Over_Time 

-- Compare the release year of titles to the year they were added to Netflix
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

SELECT * FROM Catalog_Freshness 

-- Calculate the distribution of content ratings over time
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

SELECT * FROM Content_Rating_Distribution 

-- Explore the relationship between genres and content ratings
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

SELECT * FROM Genre_Rating_Distribution 

-- Calculate the average duration of movies by release year
CREATE MATERIALIZED VIEW Avg_Movie_Duration_Over_Time AS
	SELECT f.Release_Year, AVG(f.Duration) AS Avg_Duration_Minutes
	FROM Fact_Netflix_Shows f
	JOIN  Dim_Content_Type ct ON f.Content_Type_ID = ct.Content_Type_ID
	WHERE ct.Content_Type_Description = 'Movie'
		AND f.Duration_Unit = 'Minute'
	GROUP BY f.Release_Year
	ORDER BY f.Release_Year;

SELECT * FROM Avg_Movie_Duration_Over_Time 

-- Examines the average number of seasons per TV show, broken down by genre
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

SELECT * FROM Avg_Seasons_Per_Genre 

CREATE MATERIALIZED VIEW production_by_director AS
	SELECT d.Director_Name, f.Title
	FROM Fact_Netflix_Shows f
	JOIN Shows_Directors_Link sdl ON f.Show_ID = sdl.Show_ID
	JOIN Dim_Director d ON sdl.Director_ID = d.Director_ID
	ORDER BY director_name

SELECT * FROM production_by_director WHERE director_name LIKE '%del Toro%'

/* =========================================
	TEXT ANALYSIS TABLES
   =========================================*/
SELECT Title, Description FROM Fact_Netflix_Shows;

-- Creating the word_count table
CREATE TABLE ta_word_count(
	word VARCHAR(255) PRIMARY KEY NOT NULL,
	count INT NOT NULL
)

-- DROP TABLE IF EXISTS ta_sentiment_analysis

-- Creating the sentiment_analysis table
CREATE TABLE ta_sentiment_analysis(
	title VARCHAR(255) NOT NULL,
	description TEXT NOT NULL,
	polarity NUMERIC,
	subjectivity NUMERIC
)

SELECT * FROM title_description_sentiment_analysis


CREATE MATERIALIZED VIEW most_commonly_used_words AS
	SELECT * FROM ta_word_count

CREATE MATERIALIZED VIEW title_description_sentiment_analysis AS
	SELECT * FROM ta_sentiment_analysis
	

/* =========================================
	VIEWER INTEST TABLES/VIEWS
   =========================================*/

-- GENRE ASSOCIATION
SELECT f.Show_ID, g.Genre_Description
FROM Shows_Genre_Link sgl
JOIN Dim_Genre g ON sgl.Genre_ID = g.Genre_ID
JOIN Fact_Netflix_Shows f ON sgl.Show_ID = f.Show_ID;


SELECT a.Actor_Name, g.Genre_Description
FROM Shows_Actors_Link sal
JOIN Dim_Actor a ON sal.Actor_ID = a.Actor_ID
JOIN Shows_Genre_Link sgl ON sal.Show_ID = sgl.Show_ID
JOIN Dim_Genre g ON sgl.Genre_ID = g.Genre_ID;

CREATE TABLE genre_correlations(
	Genre_Pair TEXT,
	Count INTEGER
)

CREATE MATERIALIZED VIEW genre_correlations_view AS
	SELECT * FROM genre_correlations

SELECT * FROM genre_correlations_view

-- Select for actor_genre_associations.csv export
SELECT a.Actor_Name, g.Genre_Description
FROM Shows_Actors_Link sal
JOIN Dim_Actor a ON sal.Actor_ID = a.Actor_ID
JOIN Shows_Genre_Link sgl ON sal.Show_ID = sgl.Show_ID
JOIN Dim_Genre g ON sgl.Genre_ID = g.Genre_ID;

CREATE TABLE da_actor_genre_frequencies(
    actor_name VARCHAR(255),
    british_tv_shows INTEGER,
    children_and_family_movies INTEGER,
    classic_and_cult_tv INTEGER,
    music_and_musicals INTEGER,
    tv_shows INTEGER,
    international_movies INTEGER,
    movies INTEGER,
    stand_up_comedy INTEGER,
    sci_fi_and_fantasy INTEGER,
    tv_comedies INTEGER,
    faith_and_spirituality INTEGER,
    comedies INTEGER,
    tv_horror INTEGER,
    stand_up_comedy_and_talk_shows INTEGER,
    dramas INTEGER,
    independent_movies INTEGER,
    thrillers INTEGER,
    documentaries INTEGER,
    tv_thrillers INTEGER,
    reality_tv INTEGER,
    tv_sci_fi_and_fantasy INTEGER,
    action_and_adventure INTEGER,
    tv_dramas INTEGER,
    international_tv_shows INTEGER,
    kids_tv INTEGER,
    science_and_nature_tv INTEGER,
    sports_movies INTEGER,
    spanish_language_tv_shows INTEGER,
    lgbtq_movies INTEGER,
    tv_action_and_adventure INTEGER,
    korean_tv_shows INTEGER,
    classic_movies INTEGER,
    teen_tv_shows INTEGER,
    crime_tv_shows INTEGER,
    horror_movies INTEGER,
    romantic_movies INTEGER,
    romantic_tv_shows INTEGER,
    tv_mysteries INTEGER,
    anime_features INTEGER,
    cult_movies INTEGER,
    anime_series INTEGER,
    docuseries INTEGER,
    most_common_genre VARCHAR(255)
)

CREATE MATERIALIZED VIEW actors_and_genres_total AS
	SELECT * FROM da_actor_genre_frequencies

CREATE MATERIALIZED VIEW actors_and_genres_most_common AS
	SELECT actor_name, most_common_genre
	FROM da_actor_genre_frequencies


SELECT DISTINCT * FROM Dim_Genre

/* =========================================
	CLEAN UP
   =========================================*/
   
-- FIX TABLE NAMES
ALTER TABLE ta_sentiment_analysis
	RENAME TO da_sentiment_analysis
	
ALTER TABLE ta_word_count
	RENAME TO da_word_count
	
ALTER TABLE genre_correlations
	RENAME TO da_genre_correlations	
	
-- FIX VIEWS
SELECT * FROM actors_and_genres_most_common

/* =========================================
	CREATE TABLES FROM VIEWS
   =========================================*/
	DO $$
	DECLARE
		r RECORD;
	BEGIN
		FOR r IN SELECT matviewname, schemaname FROM pg_matviews
		LOOP
			EXECUTE format('CREATE TABLE %I AS TABLE %I.%I', 
						   'mv_' || r.matviewname, 
						   r.schemaname, 
						   r.matviewname);
		END LOOP;
	END $$;

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
	AND table_name LIKE 'mv_%'
ORDER BY table_name;



--
--
--
--
--
/* =========================================
	ONE OFF QUERIES
   =========================================*/
SELECT * FROM raw_netflix_data LIMIT 10
SELECT * FROM Fact_Netflix_Shows LIMIT 10


SELECT * FROM actors_and_genres_most_common
WHERE actor_name IN ('Philip Seymour Hoffman', 'Jim Carrey')

SELECT * FROM Content_Rating_Distribution 
WHERE rating_description IN ('TV-MA', 'R','NC-17')
ORDER BY year_added DESC, title_count

SELECT release_year, ROUND(avg_duration_minutes, 2)
FROM Avg_Movie_Duration_Over_Time ORDER BY release_year DESC

SELECT * FROM Titles_Added_Over_Time ORDER BY year_added DESC, month_added DESC

SELECT title, polarity
FROM mv_title_description_sentiment_analysis
WHERE title IN (
	'The Bros', 
	'Batman: The Killing Joke',
	'P.S. I Love You',
	'The Indian Detective',
	'Life Sentence'
)

SELECT year_added, SUM(title_count)
FROM Titles_Added_Over_Time
GROUP BY year_added
ORDER BY year_added DESC

SELECT 
	year_added, 
	ROUND(AVG(avg_years_between_release_and_added)) AS avg_yrs_between_prod_and_release
FROM Catalog_Freshness 
GROUP BY year_added
ORDER BY year_added DESC


SELECT * 
FROM Genre_Popularity_Over_Time 
WHERE genre_description LIKE '%Horror Movies%'
ORDER BY release_year DESC

SELECT * FROM Directors_Most_Titles
WHERE director_name LIKE '%Sam Raimi%'

CREATE MATERIALIZED VIEW production_by_director
	SELECT d.Director_Name, f.Title
	FROM Fact_Netflix_Shows f
	JOIN Shows_Directors_Link sdl ON f.Show_ID = sdl.Show_ID
	JOIN Dim_Director d ON sdl.Director_ID = d.Director_ID
	ORDER BY director_name

WHERE d.Director_Name LIKE '%Sam Raimi%'

SELECT * FROM Shows_Directors_Link
SELECT * FROM Fact_Netflix_Shows WHERE content_type_id = 1 ORDER BY title_id
SELECT * FROM Fact_Netflix_Shows LIMIT 10


INSERT INTO Shows_Directors_Link (Show_ID, Director_ID)
	SELECT fact.Show_ID, dir.Director_ID
	FROM raw_netflix_data raw
	JOIN Fact_Netflix_Shows fact ON raw.show_id = fact.Show_ID
	JOIN Dim_Director dir ON dir.Director_Name = ANY(STRING_TO_ARRAY(raw.director, ', '))
	WHERE raw.director IS NOT NULL



ALTER TABLE Fact_Netflix_Shows RENAME COLUMN Title_ID to Title

INSERT INTO Fact_Netflix_Shows
(Show_ID, Content_Type_ID, Title_ID, Date_Added_ID, Release_Year, Rating_ID, Duration, Duration_Unit, Description)
	SELECT
		raw.show_id,
		ct.Content_Type_ID,
		raw.title,
		d.Date_ID,
		raw.release_year,
		r.Rating_ID,
		CASE WHEN raw.duration LIKE '% min' THEN REPLACE(raw.duration, ' min', '')::INTEGER
			 WHEN raw.duration LIKE '% Seasons%' THEN REPLACE(raw.duration, ' Seasons', '')::INTEGER
			 WHEN raw.duration LIKE '% Season%' THEN REPLACE(raw.duration, ' Season', '')::INTEGER		
			 ELSE NULL END AS Duration,
		CASE WHEN raw.duration LIKE '% min' THEN 'Minute'
			 WHEN raw.duration LIKE '% Seasons%' THEN 'Season'
			 WHEN raw.duration LIKE '% Season%' THEN 'Season'         
			 ELSE NULL END AS Duration_Unit,
		raw.description
	FROM raw_netflix_data raw
		JOIN Dim_Content_Type ct ON ct.Content_Type_Description = raw.content_type
		JOIN Dim_Rating r ON r.Rating_Description = raw.rating
		LEFT JOIN Dim_Date d ON d.Date = raw.date_added

SELECT raw.show_id, date.Date_ID
FROM raw_netflix_data raw
	LEFT JOIN Dim_Date date on date.Date = raw.date_added




INSERT INTO Fact_Netflix_Shows (
	Show_ID, 
	Content_Type_ID, 
	Title, 
	Director_ID, 
	Country_ID, 
	Date_Added_ID, 
	Release_Year, 
	Rating_ID, 
	Duration, 
	Duration_Unit, 
	Description
)
	SELECT
	  r.show_id::VARCHAR, -- Cast to VARCHAR if changing the data type later
	  (
		  SELECT Content_Type_ID 
		  FROM Dim_Content_Type 
		  WHERE Content_Type_Description = r.type
	  ),
	  r.title,
	  -- Additional fields and conversions as necessary
	FROM
	  raw_netflix_data r;
	  
-- Ensure show_id are all unique 
SELECT COUNT(*) FROM (
  SELECT show_id
  FROM raw_netflix_data
  GROUP BY show_id
  HAVING COUNT(*) > 1
) AS duplicates;


SELECT 
  f.Show_ID,
  d.Director_ID
FROM 
  raw_netflix_data r
CROSS JOIN LATERAL UNNEST(STRING_TO_ARRAY(r.director, ', ')) AS unnested(director_name)
JOIN 
  Dim_Director d ON TRIM(LOWER(d.Director_Name)) = LOWER(unnested.director_name)
JOIN 
  Fact_Netflix_Shows f ON f.Show_ID = r.show_id
WHERE 
  r.director IS NOT NULL;

SELECT * FROM Dim_Actor


SELECT DISTINCT 
	UNNEST(string_to_array(actors,', '))
FROM raw_netflix_data
	WHERE actors IS NOT NULL 
	
SELECT DISTINCT 
	UNNEST(STRING_TO_ARRAY(actors,', '))
FROM raw_netflix_data
	WHERE actors IS NOT NULL 

ALTER TABLE Fact_Netflix_Shows
	DROP COLUMN director_id,
	DROP COLUMN actor_id,
	DROP COLUMN country_id,
	DROP COLUMN genre_id;

SELECT String_To_Array(actors, ', ') FROM raw_netflix_data
SELECT * FROM Dim_Rating
SELECT * FROM raw_netflix_data LIMIT 10
SELECT DISTINCT content_type FROM raw_netflix_data
SELECT * FROM Dim_Date ORDER BY date DESC
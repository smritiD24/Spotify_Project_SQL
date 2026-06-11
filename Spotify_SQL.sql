--Spotify Project--

-- create table
-- DROP TABLE IF EXISTS spotify;
-- CREATE TABLE spotify (
--     artist VARCHAR(255),
--     track VARCHAR(255),
--     album VARCHAR(255),
--     album_type VARCHAR(50),
--     danceability FLOAT,
--     energy FLOAT,
--     loudness FLOAT,
--     speechiness FLOAT,
--     acousticness FLOAT,
--     instrumentalness FLOAT,
--     liveness FLOAT,
--     valence FLOAT,
--     tempo FLOAT,
--     duration_min FLOAT,
--     title VARCHAR(255),
--     channel VARCHAR(255),
--     views FLOAT,
--     likes BIGINT,
--     comments BIGINT,
--     licensed BOOLEAN,
--     official_video BOOLEAN,
--     stream BIGINT,
--     energy_liveness FLOAT,
--     most_played_on VARCHAR(50)
-- );

--EDA
SELECT COUNT(*) FROM spotify;
SELECT COUNT(DISTINCT artist) FROM spotify;
SELECT COUNT(DISTINCT album) FROM spotify;
SELECT DISTINCT album_type FROM spotify;
SELECT MAX(duration_min) FROM spotify;
SELECT MIN(duration_min) FROM spotify;

SELECT * FROM spotify
WHERE duration_min = 0;

DELETE FROM spotify
WHERE duration_min = 0;

SELECT * FROM spotify
WHERE duration_min = 0;

/*
Easy Level
Retrieve the names of all tracks that have more than 1 billion streams.
List all albums along with their respective artists.
Get the total number of comments for tracks where licensed = TRUE.
Find all tracks that belong to the album type single.
Count the total number of tracks by each artist.
*/

--1
SELECT * FROM spotify
WHERE stream>1000000000;

--2
SELECT album, artist FROM spotify
SELECT DISTINCT album FROM spotify;
SELECT DISTINCT album, artist FROM spotify ORDER BY 1;

--3
SELECT 
SUM(comments) as total_comments 
FROM spotify
WHERE licensed ='true';

SELECT COUNT(comments) FROM spotify
WHERE licensed ='true';

--4
SELECT track FROM spotify
WHERE album_type ILIKE 'single';

--5
SELECT
artist,
COUNT(*) as total_no_of_songs
FROM spotify
GROUP BY artist;

SELECT artist, COUNT(track) FROM spotify GROUP BY artist ORDER BY 1 DESC;

/*
Medium Level
Calculate the average danceability of tracks in each album.
Find the top 5 tracks with the highest energy values.
List all tracks along with their views and likes where official_video = TRUE.
For each album, calculate the total views of all associated tracks.
Retrieve the track names that have been streamed on Spotify more than YouTube.
Advanced Level
*/

--6
SELECT 
	album, 
	AVG(danceability) 
FROM spotify
GROUP BY 1
ORDER BY 2 DESC;

--7
SELECT track, AVG(energy) FROM spotify
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5;

--8
SELECT track, SUM(views), SUM(likes) FROM spotify
WHERE official_video = 'true'
GROUP BY 1
ORDER BY 2 DESC;

SELECT track, views, likes FROM spotify
WHERE official_video = 'true'

--9
SELECT album, SUM(views) as total_views
FROM spotify
GROUP BY 1
ORDER BY 2 DESC;


--10
SELECT 
	track	
FROM spotify
WHERE most_played_on.Spotify > most_played_on.Youtube;

SELECT * FROM 
(SELECT track, 
COALESCE(SUM(CASE WHEN most_played_on = 'Youtube' THEN stream END),0) as Streamed_on_Youtube, 
COALESCE(SUM(CASE WHEN most_played_on = 'Spotify' THEN stream END),0) as Streamed_on_Spotify 
FROM spotify 
GROUP BY 1 ) as t1
WHERE Streamed_on_Spotify>Streamed_on_Youtube AND Streamed_on_Youtube <> 0;

/*
Advanced Level
Find the top 3 most-viewed tracks for each artist using window functions.
Write a query to find tracks where the liveness score is above the average.
Use a WITH clause to calculate the difference between the highest and lowest energy values for tracks in each album.
Find tracks where the energy-to-liveness ratio is greater than 1.2.
Calculate the cumulative sum of likes for tracks ordered by the number of views, using window functions.
*/


--11
WITH ranking_artist
AS
(SELECT
	artist, 
	track, 
	SUM(views) as total_views, 
	DENSE_RANK() OVER(PARTITION BY artist ORDER BY SUM(views) DESC) as rank
FROM spotify
GROUP BY 1,2
ORDER BY 1,3 DESC
)
SELECT * FROM ranking_Artist
WHERE rank <= 3

--12
SELECT AVG(liveness) FROM spotify
SELECT track, liveness FROM spotify
WHERE liveness>0.19

--but data changes so,

SELECT track, liveness FROM spotify
WHERE liveness> (SELECT AVG(liveness) FROM spotify)

--13

WITH cte
AS
(SELECT
	album,
	MAX(energy) as HE,
	MIN(energy) as LE
FROM spotify
GROUP BY 1
)
SELECT
	album,
	HE - LE as energy_diff
FROM cte
ORDER BY 2 DESC;

--
EXPLAIN ANALYZE --Excecution time 9.734 ms, Planning time 0.298 ms, LATER FATER INDEXING 0.127 ms and 0.192
SELECT
	artist,
	track,
	views
FROM spotify
WHERE artist = 'Gorillaz' AND most_played_on = 'Youtube'
ORDER BY stream DESC LIMIT 25

CREATE INDEX artlist_index ON spotify (artist);
--

--14
SELECT
    track,
    energy,
    liveness,
    energy/NULLIF(liveness,0) AS ratio
FROM spotify
WHERE energy/NULLIF(liveness,0) > 1.2;

--15
SELECT
    track,
    views,
    likes,
    SUM(likes) OVER(ORDER BY views) AS cumulative_likes
FROM spotify
ORDER BY 3 DESC;

-- WINDOW: Running total
-- Cumulative sum
-- Running average
-- Moving average
-- Rank
-- Top N per group
<p align="center">
  <img src="spotify_logo.jpg" width="250" alt="Spotify Logo">
</p>

# Spotify Advanced SQL Analysis & Query Optimization

## About This Project

Spotify was the most technically interesting of my three SQL projects because the dataset is already flat — one table with 24 columns covering audio features, engagement metrics, and platform data all together. That meant no JOINs to worry about, but the questions get progressively harder in terms of window functions, CTEs, and subquery logic.

What also made this one different is the **query optimization** section — I actually ran `EXPLAIN ANALYZE` before and after adding an index and measured the difference. Execution time dropped from ~7ms to ~0.15ms. That's the kind of thing that matters in real analyst roles where you're querying millions of rows.

I used **PostgreSQL** for all queries.

---

## Dataset

- **Source:** [Spotify Dataset — Kaggle](https://www.kaggle.com/datasets/sanjanchaudhari/spotify-dataset)
- **Structure:** Single flat table, ~20,000+ rows
- **Covers:** Track-level audio features (danceability, energy, tempo etc.) + YouTube/Spotify engagement (views, likes, streams, comments)

---

## What's Inside

```
spotify-sql-analysis/
│
├── README.md                        -- you're reading it
├── spotify_logo.jpg                 -- Spotify logo
├── schema_setup.sql                 -- table creation
├── solutions.sql                    -- all 15 query solutions
├── additional_problems.sql          -- 5 extra questions I added
└── outputs/                         -- screenshots of query results
```

---

## Schema

```sql
DROP TABLE IF EXISTS spotify;

CREATE TABLE spotify (
    artist          VARCHAR(255),
    track           VARCHAR(255),
    album           VARCHAR(255),
    album_type      VARCHAR(50),
    danceability    FLOAT,
    energy          FLOAT,
    loudness        FLOAT,
    speechiness     FLOAT,
    acousticness    FLOAT,
    instrumentalness FLOAT,
    liveness        FLOAT,
    valence         FLOAT,
    tempo           FLOAT,
    duration_min    FLOAT,
    title           VARCHAR(255),
    channel         VARCHAR(255),
    views           FLOAT,
    likes           BIGINT,
    comments        BIGINT,
    licensed        BOOLEAN,
    official_video  BOOLEAN,
    stream          BIGINT,
    energy_liveness FLOAT,
    most_played_on  VARCHAR(50)
);
```

> **Note:** `views`, `likes`, and `streams` are on completely different scales — YouTube views can be in billions while comments stay in thousands. Worth keeping in mind when comparing engagement across platforms.

---

## Queries by Difficulty

---

### 🟢 Easy Level

---

### Q1. Tracks with More Than 1 Billion Streams

```sql
SELECT 
    artist,
    track,
    stream
FROM spotify
WHERE stream > 1000000000
ORDER BY stream DESC;
```

---

### Q2. All Albums with Their Artists

```sql
SELECT DISTINCT
    album,
    artist
FROM spotify
ORDER BY artist;
```

---

### Q3. Total Comments for Licensed Tracks

```sql
-- licensed = TRUE means the track has proper copyright clearance
SELECT 
    SUM(comments) AS total_comments
FROM spotify
WHERE licensed = TRUE;
```

---

### Q4. All Tracks from Single-Type Albums

```sql
SELECT 
    track,
    artist,
    album_type
FROM spotify
WHERE album_type = 'single';
```

---

### Q5. Total Track Count per Artist

```sql
SELECT 
    artist,
    COUNT(*) AS total_tracks
FROM spotify
GROUP BY artist
ORDER BY total_tracks DESC;
```

---

### 🟡 Medium Level

---

### Q6. Average Danceability per Album

```sql
SELECT 
    album,
    ROUND(AVG(danceability)::numeric, 4) AS avg_danceability
FROM spotify
GROUP BY album
ORDER BY avg_danceability DESC;
```

> Higher danceability = more rhythmically consistent and beat-driven tracks. Albums at the top here tend to be pop or hip-hop heavy.

---

### Q7. Top 5 Tracks by Energy

```sql
SELECT 
    track,
    artist,
    energy
FROM spotify
ORDER BY energy DESC
LIMIT 5;
```

---

### Q8. Tracks with Official Videos — Views and Likes

```sql
SELECT 
    track,
    artist,
    views,
    likes
FROM spotify
WHERE official_video = TRUE
ORDER BY views DESC;
```

---

### Q9. Total YouTube Views per Album

```sql
SELECT 
    album,
    SUM(views) AS total_views
FROM spotify
GROUP BY album
ORDER BY total_views DESC;
```

---

### Q10. Tracks Streamed More on Spotify Than YouTube

```sql
-- most_played_on column tells us which platform dominates for each track
SELECT 
    track,
    artist,
    most_played_on,
    stream
FROM spotify
WHERE most_played_on = 'Spotify'
ORDER BY stream DESC;
```

---

### 🔴 Advanced Level

---

### Q11. Top 3 Most-Viewed Tracks per Artist (Window Function)

Used `DENSE_RANK()` partitioned by artist — same logic as the Zomato city ranking problems but applied here to views.

```sql
WITH ranked_tracks AS (
    SELECT 
        artist,
        track,
        SUM(views) AS total_views,
        DENSE_RANK() OVER(PARTITION BY artist ORDER BY SUM(views) DESC) AS rank
    FROM spotify
    GROUP BY artist, track
)
SELECT 
    artist,
    track,
    total_views
FROM ranked_tracks
WHERE rank <= 3;
```

---

### Q12. Tracks with Above-Average Liveness

Liveness measures whether the track sounds like it was recorded in front of a live audience. Higher = more live feel.

```sql
SELECT 
    track,
    artist,
    liveness
FROM spotify
WHERE liveness > (SELECT AVG(liveness) FROM spotify)
ORDER BY liveness DESC;
```

> The subquery runs once and returns a single value — cleaner than hardcoding the average.

---

### Q13. Energy Range per Album (Highest - Lowest)

Which albums have the widest spread of energy levels? High spread = diverse tracklist; low spread = consistent mood throughout.

```sql
WITH energy_stats AS (
    SELECT 
        album,
        MAX(energy) AS highest_energy,
        MIN(energy) AS lowest_energy
    FROM spotify
    GROUP BY album
)
SELECT 
    album,
    highest_energy,
    lowest_energy,
    ROUND((highest_energy - lowest_energy)::numeric, 4) AS energy_diff
FROM energy_stats
ORDER BY energy_diff DESC;
```

---

### Q14. Tracks Where Energy-to-Liveness Ratio > 1.2

```sql
-- energy_liveness is a pre-computed column in the dataset
-- but we can also calculate it directly to verify
SELECT 
    track,
    artist,
    energy,
    liveness,
    ROUND((energy / liveness)::numeric, 4) AS energy_liveness_ratio
FROM spotify
WHERE liveness > 0  -- avoid division by zero
  AND (energy / liveness) > 1.2
ORDER BY energy_liveness_ratio DESC;
```

> Added a `liveness > 0` guard — dividing by zero would throw an error and is easy to miss.

---

### Q15. Cumulative Likes Ordered by Views (Window Function)

Running total of likes as we go from least-viewed to most-viewed tracks. Shows how engagement accumulates across the catalog.

```sql
SELECT 
    track,
    artist,
    views,
    likes,
    SUM(likes) OVER(ORDER BY views ASC) AS cumulative_likes
FROM spotify
ORDER BY views ASC;
```

---

## Query Optimization

This is the part I found most interesting — and most practical.

### The Problem

When filtering by `artist`, PostgreSQL was doing a full sequential scan across the entire table — reading every single row even if only a handful matched.

```sql
EXPLAIN ANALYZE
SELECT * FROM spotify WHERE artist = 'Gorillaz';
```

**Before index:**
- Execution time: **~7 ms**
- Planning time: **~0.17 ms**
- Scan type: Sequential Scan (reads entire table)

### The Fix — Creating an Index

```sql
CREATE INDEX idx_artist ON spotify(artist);
```

**After index:**
- Execution time: **~0.153 ms**
- Planning time: **~0.152 ms**
- Scan type: Index Scan (jumps directly to matching rows)

### Why This Matters

That's roughly a **45x speed improvement** on a ~20K row dataset. On a production database with millions of rows, the difference would be even more dramatic. Indexing frequently-filtered columns (especially VARCHAR fields used in WHERE clauses) is one of the first things to check when a query is slow.

> Screenshots of `EXPLAIN ANALYZE` output before and after are in the `/outputs/` folder.

---

## Additional Problems (Self-Added)

After the core 15, I added 5 more focused on areas I wanted to explore. Solutions in `additional_problems.sql`.

### Q16. Albums Where Average Energy Exceeds Average Valence
Energy = intensity/activity. Valence = musical positivity. Find albums that are high-energy but not necessarily happy — think intense workout music vs feel-good pop.

### Q17. Artists Who Appear in Both Singles and Full Albums
Some artists release standalone singles AND full albums on this dataset. Find artists present in both album types.

### Q18. Most "Speech-Heavy" Tracks (Speechiness Outliers)
Speechiness detects spoken word content. Tracks above 0.66 are likely podcasts or spoken word — find them and see which artists they belong to.

### Q19. Correlation Check — Do More Danceable Tracks Get More Streams?
Group tracks into danceability buckets (low/medium/high) and compare average streams per bucket. A simple way to check if danceability drives streaming numbers.

### Q20. Tracks That Are Popular on YouTube but Underperforming on Spotify
Find tracks with very high YouTube views but relatively low Spotify streams. These could be viral video tracks that haven't translated to audio-only listening.

---

## Key Learnings from This Project

- **Window functions** with `PARTITION BY` are the go-to for any "top N per group" problem — used in Q11 and it's the same pattern as Zomato's city ranking.
- **Scalar subqueries** inside WHERE (like Q12) are clean and readable when you just need one comparison value.
- **Division by zero** is a real risk in ratio calculations — always add a `WHERE denominator > 0` guard before dividing (Q14).
- **EXPLAIN ANALYZE** is not just a learning tool — it's how real analysts debug slow queries in production. Running it on this project gave me actual numbers to talk about.
- Single-table projects force you to get creative with the data you have — all the complexity comes from the columns themselves rather than relationships between tables.

---

## Tools Used

- PostgreSQL 15
- pgAdmin 4
- Dataset: Real data from Kaggle (public domain)

---

*This project was inspired by ZeroAnalyst (Najir H.) on YouTube. The original 15 problem statements are from his course. All SQL solutions, comments, notes, and additional questions (Q16–Q20) are written by me.*

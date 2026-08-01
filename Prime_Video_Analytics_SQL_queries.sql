-- ============================================================
-- Amazon Prime OTT — Full Project Script
-- Database: AmazonPrimeDB
-- ============================================================

-- ============================================================
-- 1. DATABASE + TABLE CREATION
-- ============================================================
CREATE DATABASE AmazonPrimeDB;
GO

USE AmazonPrimeDB;
GO

CREATE TABLE subscription_plans
(
    plan_id VARCHAR(5) PRIMARY KEY,
    plan_name VARCHAR(50) NOT NULL,
    price_inr INT NOT NULL,
    billing_cycle VARCHAR(20) NOT NULL,
    max_screens TINYINT NOT NULL,
    video_quality VARCHAR(20) NOT NULL,
    includes_ads BIT NOT NULL
);

CREATE TABLE users
(
    user_id VARCHAR(10) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    age TINYINT NOT NULL,
    gender VARCHAR(10) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,
    plan_id VARCHAR(5) NOT NULL,
    signup_date DATE NOT NULL,
    preferred_language VARCHAR(50) NOT NULL,
    is_active BIT NOT NULL,

    FOREIGN KEY (plan_id)
    REFERENCES subscription_plans(plan_id)
);

CREATE TABLE movies
(
    movie_id VARCHAR(10) PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    language VARCHAR(50) NOT NULL,
    genre VARCHAR(100) NOT NULL,
    release_year SMALLINT NOT NULL,
    decade VARCHAR(20) NOT NULL,
    running_time_minutes SMALLINT NOT NULL,
    imdb_rating DECIMAL(3,1) NOT NULL,
    rating_category VARCHAR(20) NOT NULL,
    maturity_rating VARCHAR(20) NOT NULL,
    plot VARCHAR(MAX) NOT NULL,
    plot_word_count SMALLINT NOT NULL,
    is_rating_imputed BIT NOT NULL,
    is_year_imputed BIT NOT NULL
);

CREATE TABLE watch_history
(
    interaction_id VARCHAR(15) PRIMARY KEY,
    user_id VARCHAR(10) NOT NULL,
    movie_id VARCHAR(10) NOT NULL,
    watch_date DATE NOT NULL,
    watch_duration_minutes SMALLINT NOT NULL,
    completed BIT NOT NULL,
    user_rating TINYINT NOT NULL,
    device_type VARCHAR(30) NOT NULL,

    FOREIGN KEY (user_id)
    REFERENCES users(user_id),

    FOREIGN KEY (movie_id)
    REFERENCES movies(movie_id)
);
GO

-- ============================================================
-- 2. INDEXES (on foreign key columns for join performance)
-- ============================================================
CREATE INDEX idx_watch_user ON watch_history(user_id);
CREATE INDEX idx_watch_movie ON watch_history(movie_id);
CREATE INDEX idx_users_plan ON users(plan_id);
GO

-- ============================================================
-- 3. BULK INSERT (load CSVs)
-- ============================================================
BULK INSERT subscription_plans
FROM 'I:\Prime_Video_Project\subscription_plans.csv'
WITH
(
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n'
);

BULK INSERT users
FROM 'I:\Prime_Video_Project\users.csv'
WITH
(
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n'
);

BULK INSERT movies
FROM 'I:\Prime_Video_Project\movies.csv'
WITH
(
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n'
);

BULK INSERT watch_history
FROM 'I:\Prime_Video_Project\watch_history.csv'
WITH
(
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n'
);
GO

-- ============================================================
-- 4. VERIFY DATA LOADED CORRECTLY
-- ============================================================
SELECT * FROM subscription_plans;
SELECT * FROM users;
SELECT * FROM watch_history;
SELECT * FROM movies;

SELECT COUNT(*) AS Total_Movies FROM movies;
SELECT COUNT(*) AS Total_Users FROM users;
SELECT COUNT(*) AS Total_Watch_History FROM watch_history;
SELECT COUNT(*) AS Total_Subscription_Plans FROM subscription_plans;
GO

-- ============================================================
-- 5. CONVERT BIT FLAGS TO READABLE TEXT (CASE statements)
-- ============================================================
UPDATE subscription_plans
SET includes_ads = CASE WHEN includes_ads = 0 THEN 'False'
                         WHEN includes_ads = 1 THEN 'True'
                    END;

UPDATE users
SET is_active = CASE WHEN is_active = 0 THEN 'False'
                      WHEN is_active = 1 THEN 'True'
                 END;

UPDATE movies
SET is_rating_imputed = CASE WHEN is_rating_imputed = 0 THEN 'False'
                              WHEN is_rating_imputed = 1 THEN 'True'
                         END,
    is_year_imputed = CASE WHEN is_year_imputed = 0 THEN 'False'
                            WHEN is_year_imputed = 1 THEN 'True'
                       END;
GO

-- ============================================================
-- 6. DASHBOARD METRICS QUERIES
-- ============================================================

-- 1 Average IMDb Rating
SELECT ROUND(AVG(imdb_rating), 2) AS Average_IMDb_Rating
FROM movies;

-- 2 Movies by Language
SELECT language, COUNT(*) AS Movie_Count
FROM movies
GROUP BY language
ORDER BY Movie_Count DESC;

-- 3 Movies by Genre
SELECT genre, COUNT(*) AS Movie_Count
FROM movies
GROUP BY genre
ORDER BY Movie_Count DESC;

-- 4 Movies by Decade
SELECT decade, COUNT(*) AS Movie_Count
FROM movies
GROUP BY decade
ORDER BY decade;

-- 5 Top 10 Highest Rated Movies
SELECT TOP 10 title, language, release_year, imdb_rating
FROM movies
ORDER BY imdb_rating DESC;

-- 6 Top 10 Most Watched Movies
SELECT TOP 10
    m.movie_id,
    m.title,
    COUNT(w.interaction_id) AS Watch_Count
FROM watch_history w
JOIN movies m ON w.movie_id = m.movie_id
GROUP BY m.movie_id, m.title
ORDER BY Watch_Count DESC;

-- 7 Top 10 Active Users (by total watch time)
SELECT TOP 10
    u.user_id,
    u.name,
    COUNT(w.interaction_id) AS Total_Watches,
    SUM(w.watch_duration_minutes) AS Total_Minutes_Watched
FROM watch_history w
JOIN users u ON w.user_id = u.user_id
GROUP BY u.user_id, u.name
ORDER BY Total_Minutes_Watched DESC;

-- 8 Watch Time by Device Type
SELECT
    device_type,
    COUNT(*) AS Total_Sessions,
    SUM(watch_duration_minutes) AS Total_Minutes_Watched,
    ROUND(AVG(CAST(watch_duration_minutes AS FLOAT)), 2) AS Avg_Minutes_Per_Session
FROM watch_history
GROUP BY device_type
ORDER BY Total_Minutes_Watched DESC;

-- 9 Completion Rate
SELECT
    ROUND(CAST(SUM(CASE WHEN completed = 'True' THEN 1 ELSE 0 END) AS FLOAT)
        * 100.0 / COUNT(*), 2) AS Completion_Rate_Percent
FROM watch_history;

-- 10 Active vs Inactive Users
SELECT
    CASE WHEN is_active = 'True' THEN 'Active' ELSE 'Inactive' END AS Status,
    COUNT(*) AS User_Count
FROM users
GROUP BY is_active;

-- 11 Users by State
SELECT state, COUNT(*) AS User_Count
FROM users
GROUP BY state
ORDER BY User_Count DESC;

-- 12 Users by Preferred Language
SELECT preferred_language, COUNT(*) AS User_Count
FROM users
GROUP BY preferred_language
ORDER BY User_Count DESC;

-- 13 Plan-wise User Count
SELECT
    p.plan_name,
    COUNT(u.user_id) AS User_Count
FROM subscription_plans p
LEFT JOIN users u ON p.plan_id = u.plan_id
GROUP BY p.plan_name
ORDER BY User_Count DESC;

-- 14 Plan-wise Revenue (price x number of subscribed users)
SELECT
    p.plan_name,
    p.price_inr,
    COUNT(u.user_id) AS User_Count,
    p.price_inr * COUNT(u.user_id) AS Total_Revenue_INR
FROM subscription_plans p
LEFT JOIN users u ON p.plan_id = u.plan_id
GROUP BY p.plan_name, p.price_inr
ORDER BY Total_Revenue_INR DESC;

-- 15 Monthly User Signups
SELECT
    FORMAT(signup_date, 'yyyy-MM') AS Signup_Month,
    COUNT(*) AS New_Signups
FROM users
GROUP BY FORMAT(signup_date, 'yyyy-MM')
ORDER BY Signup_Month;

-- 16 Monthly Watch Trend
SELECT
    FORMAT(watch_date, 'yyyy-MM') AS Watch_Month,
    COUNT(*) AS Watch_Count
FROM watch_history
GROUP BY FORMAT(watch_date, 'yyyy-MM')
ORDER BY Watch_Month;
GO

-- ============================================================
-- 7. ADVANCED ANALYSIS QUERIES (Window Functions etc.)
-- ============================================================

-- 1 Top 5 Genres by Average IMDb Rating
SELECT TOP 5
    genre,
    ROUND(AVG(imdb_rating), 2) AS Avg_IMDb_Rating
FROM movies
GROUP BY genre
ORDER BY Avg_IMDb_Rating DESC;

-- 2 Top 10 Longest Movies
SELECT TOP 10
    title, language, running_time_minutes
FROM movies
ORDER BY running_time_minutes DESC;

-- 3 Most Popular Language Based on Watch Count
SELECT TOP 1
    m.language,
    COUNT(*) AS Watch_Count
FROM watch_history w
JOIN movies m ON w.movie_id = m.movie_id
GROUP BY m.language
ORDER BY Watch_Count DESC;

-- 4 Top 10 Movies with Highest Completion Rate
SELECT TOP 10
    m.title,
    COUNT(*) AS Total_Watches,
    ROUND(CAST(SUM(CASE WHEN w.completed = 'True' THEN 1 ELSE 0 END) AS FLOAT) * 100.0 / COUNT(*), 2) AS Completion_Rate_Percent
FROM watch_history w
JOIN movies m ON w.movie_id = m.movie_id
GROUP BY m.title
HAVING COUNT(*) >= 5
ORDER BY Completion_Rate_Percent DESC;

-- 5 Average Watch Duration by Age Group
SELECT
    CASE
        WHEN u.age BETWEEN 15 AND 24 THEN '15-24'
        WHEN u.age BETWEEN 25 AND 34 THEN '25-34'
        WHEN u.age BETWEEN 35 AND 44 THEN '35-44'
        WHEN u.age BETWEEN 45 AND 54 THEN '45-54'
        ELSE '55+'
    END AS Age_Group,
    ROUND(AVG(CAST(w.watch_duration_minutes AS FLOAT)), 2) AS Avg_Watch_Duration_Minutes
FROM watch_history w
JOIN users u ON w.user_id = u.user_id
GROUP BY
    CASE
        WHEN u.age BETWEEN 15 AND 24 THEN '15-24'
        WHEN u.age BETWEEN 25 AND 34 THEN '25-34'
        WHEN u.age BETWEEN 35 AND 44 THEN '35-44'
        WHEN u.age BETWEEN 45 AND 54 THEN '45-54'
        ELSE '55+'
    END
ORDER BY Age_Group;

-- 6 Most Preferred Subscription Plan (by subscriber count)
SELECT TOP 1
    p.plan_name,
    COUNT(u.user_id) AS Subscriber_Count
FROM subscription_plans p
JOIN users u ON p.plan_id = u.plan_id
GROUP BY p.plan_name
ORDER BY Subscriber_Count DESC;

-- 7 Device Type with Highest Average Watch Time
SELECT TOP 1
    device_type,
    ROUND(AVG(CAST(watch_duration_minutes AS FLOAT)), 2) AS Avg_Watch_Time_Minutes
FROM watch_history
GROUP BY device_type
ORDER BY Avg_Watch_Time_Minutes DESC;

-- 8 Top 5 States by Total Watch Time
SELECT TOP 5
    u.state,
    SUM(w.watch_duration_minutes) AS Total_Watch_Time_Minutes
FROM watch_history w
JOIN users u ON w.user_id = u.user_id
GROUP BY u.state
ORDER BY Total_Watch_Time_Minutes DESC;

-- 9 Users Who Watched the Most Unique Movies (Top 10)
SELECT TOP 10
    u.user_id,
    u.name,
    COUNT(DISTINCT w.movie_id) AS Unique_Movies_Watched
FROM watch_history w
JOIN users u ON w.user_id = u.user_id
GROUP BY u.user_id, u.name
ORDER BY Unique_Movies_Watched DESC;

-- 10 Highest-Rated Movie in Each Genre
WITH RankedByGenre AS (
    SELECT
        genre, title, imdb_rating,
        RANK() OVER (PARTITION BY genre ORDER BY imdb_rating DESC) AS Rnk
    FROM movies
)
SELECT genre, title, imdb_rating
FROM RankedByGenre
WHERE Rnk = 1
ORDER BY genre;

-- 11 Rank Movies Within Each Language
SELECT
    title,
    language,
    imdb_rating,
    RANK() OVER (PARTITION BY language ORDER BY imdb_rating DESC) AS Rank_Within_Language
FROM movies
ORDER BY language, Rank_Within_Language;

-- 12 Dense Rank Users by Total Watch Time
WITH UserWatchTime AS (
    SELECT user_id, SUM(watch_duration_minutes) AS Total_Minutes
    FROM watch_history
    GROUP BY user_id
)
SELECT
    user_id,
    Total_Minutes,
    DENSE_RANK() OVER (ORDER BY Total_Minutes DESC) AS Watch_Time_Rank
FROM UserWatchTime
ORDER BY Watch_Time_Rank;

-- 13 Cumulative Monthly Watch Sessions
WITH MonthlySessions AS (
    SELECT
        FORMAT(watch_date, 'yyyy-MM') AS Watch_Month,
        COUNT(*) AS Session_Count
    FROM watch_history
    GROUP BY FORMAT(watch_date, 'yyyy-MM')
)
SELECT
    Watch_Month,
    Session_Count,
    SUM(Session_Count) OVER (ORDER BY Watch_Month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS Cumulative_Sessions
FROM MonthlySessions
ORDER BY Watch_Month;

-- 14 Percentage Contribution of Each Genre to Total Movies
SELECT
    genre,
    COUNT(*) AS Movie_Count,
    ROUND(CAST(COUNT(*) AS FLOAT) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS Pct_Of_Total_Movies
FROM movies
GROUP BY genre
ORDER BY Pct_Of_Total_Movies DESC;

-- 15 Movies Never Watched
SELECT m.movie_id, m.title, m.language, m.genre
FROM movies m
LEFT JOIN watch_history w ON m.movie_id = w.movie_id
WHERE w.interaction_id IS NULL;

-- 16 Active Users With No Watch History
SELECT u.user_id, u.name, u.signup_date
FROM users u
LEFT JOIN watch_history w ON u.user_id = w.user_id
WHERE u.is_active = 'True'
  AND w.interaction_id IS NULL;

-- 17 Most Watched Movie in Each State
WITH StateMovieCounts AS (
    SELECT
        u.state,
        w.movie_id,
        COUNT(*) AS Watch_Count,
        RANK() OVER (PARTITION BY u.state ORDER BY COUNT(*) DESC) AS Rnk
    FROM watch_history w
    JOIN users u ON w.user_id = u.user_id
    GROUP BY u.state, w.movie_id
)
SELECT
    smc.state,
    m.title,
    smc.Watch_Count
FROM StateMovieCounts smc
JOIN movies m ON smc.movie_id = m.movie_id
WHERE smc.Rnk = 1
ORDER BY smc.state;

-- 18 Monthly Revenue by Subscription Plan
SELECT
    FORMAT(u.signup_date, 'yyyy-MM') AS Signup_Month,
    p.plan_name,
    COUNT(u.user_id) AS New_Subscribers,
    COUNT(u.user_id) * p.price_inr AS Revenue_INR
FROM users u
JOIN subscription_plans p ON u.plan_id = p.plan_id
GROUP BY FORMAT(u.signup_date, 'yyyy-MM'), p.plan_name, p.price_inr
ORDER BY Signup_Month, p.plan_name;

-- 19 Average IMDb Rating by Decade
SELECT
    decade,
    ROUND(AVG(imdb_rating), 2) AS Avg_IMDb_Rating
FROM movies
GROUP BY decade
ORDER BY decade;

-- 20 Top 3 Movies in Each Genre
WITH RankedMovies AS (
    SELECT
        genre, title, imdb_rating,
        ROW_NUMBER() OVER (PARTITION BY genre ORDER BY imdb_rating DESC) AS Rn
    FROM movies
)
SELECT genre, title, imdb_rating, Rn AS Rank_In_Genre
FROM RankedMovies
WHERE Rn <= 3
ORDER BY genre, Rn;

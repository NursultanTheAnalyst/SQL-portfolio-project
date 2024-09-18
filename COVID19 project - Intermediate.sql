--iso_code must be three letters long. Is there an iso_code in the set that does not meet this criteria?

SELECT iso_code
FROM cases
WHERE LENGTH(iso_code) > 3;

--We need to know if our dataset includes islands. Find all country names that contain "Islands".

SELECT location, continent
FROM regions
WHERE location LIKE "%Islands%";


--We want to remove the text in brackets in country names. Write a query that will help us with this task.

SELECT REGEXP_REPLACE(location, '\\(.*\\)',) AS Country_list
FROM regions
ORDER BY Country_list;


-- In which country was the probability of an infected person dying the highest?
-- Probability of an infected person dying = (number of deaths \ number of confirmed cases) * 100
-- Please provide the country name, date of observation, probability of an infected person dying.

WITH CTE1 AS (SELECT
c.iso_code,
c.date,
c.total_deaths,
c.total_cases,
r.location AS country,
(c.total_deaths / c.total_cases) * 100 AS prob
FROM cases AS c
JOIN regions AS r
ON c.iso_code = r.iso_code
)
SELECT country, prob, date
FROM CTE1
WHERE prob = (
SELECT MAX(prob)
FROM CTE1);


--What is the proportion of the population infected and the proportion of the population that died from COVID-19 for each country?
-Probability of death of an infected person = (number of deaths \ number of confirmed cases) * 100
--Provide the country name, total number of confirmed cases, total number of deaths, population,
the proportion of the country's population infected, and the proportion of the country's population that died from COVID-19. The country with the highest proportion of the population infected should be displayed first.
  
  
WITH CTE1 AS (SELECT
r.location,
SUM(c.new_cases) AS all_cases,
SUM(c.new_deaths) AS all_deaths,
d.population,
ROUND((SUM(c.new_cases) / d.population) * 100, 2) AS prob_ill,
ROUND((SUM(c.new_deaths) / d.population) * 100, 2) AS prob_deaths
FROM cases AS c
JOIN regions AS r ON c.iso_code = r.iso_code
JOIN demography AS d ON c.iso_code = d.iso_code
GROUP BY r.location, d.population
)
SELECT
location,
all_cases,
all_deaths,
population,
prob_ill,
prob_deaths
FROM CTE1
ORDER BY prob_ill DESC;


-- What is the proportion of the population infected and the proportion of the population who died from COVID-19 in the world?
-- Provide the total number of confirmed cases worldwide, the total number of deaths, the world population, the proportion of the population infected, and the proportion of the population who died from COVID-19.  

WITH CTE1 AS ( SELECT
SUM(c.new_cases) AS all_cases,
SUM(c.new_deaths) AS all_deaths,
SUM(d.population) AS all_population
FROM cases AS c
JOIN demography AS d ON c.iso_code = d.iso_code
)
SELECT 
all_cases,
all_deaths,
all_population,
(all_cases / all_population) * 100 AS prob_ill,
ROUND((all_deaths / all_population) * 100, 2) AS prob_death
FROM CTE1;


--Which countries did well in treating cases?
--Please provide country names, first observation date of ED patients in the dataset, last observation date of ED patients in the dataset, and difference in ED patients.
  
WITH CTE1 AS (SELECT
r.location,
h.iso_code,
h.date,
h.icu_patients,
FIRST_VALUE(h.date) OVER (PARTITION BY h.iso_code ORDER BY h.date ROWS BETWEEN UNBOUNDED
PRECEDING AND UNBOUNDED FOLLOWING) AS first_date,
FIRST_VALUE(h.icu_patients) OVER (PARTITION BY h.iso_code ORDER BY h.date ROWS BETWEEN
UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS first_day,
LAST_VALUE(h.date) OVER (PARTITION BY h.iso_code ORDER BY h.date ROWS BETWEEN UNBOUNDED
PRECEDING AND UNBOUNDED FOLLOWING) AS last_date,
LAST_VALUE(h.icu_patients) OVER (PARTITION BY h.iso_code ORDER BY h.date ROWS BETWEEN
UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_day
FROM hospital AS h
JOIN regions AS r ON h.iso_code = r.iso_code
WHERE h.icu_patients IS NOT NULL
),
CTE2 AS (SELECT DISTINCT
location,
first_date,
last_date,
first_day,
last_day,
last_day - first_day AS diff
FROM CTE1
WHERE last_day < first_day
)
SELECT
location,
first_date,
first_day,
last_date,
last_day,
diff
FROM CTE2
ORDER BY diff ASC;


--How has the UK coped with COVID-19?
--Provide data on new confirmed cases and deaths, the number of new tests and new vaccine doses, the number of patients admitted to hospitals and intensive care units by month.

SELECT
EXTRACT(MONTH FROM c.date) AS month,
SUM(SAFE_CAST(c.new_cases AS INT64)) AS new_cases,
SUM(SAFE_CAST(c.new_deaths AS INT64)) AS new_deaths,
SUM(SAFE_CAST(t.new_tests AS INT64)) AS new_tests,
SUM(SAFE_CAST(v.new_vaccinations AS INT64)) AS new_vaccinations,
SUM(SAFE_CAST(h.weekly_hosp_admissions AS INT64)) AS new_hosp_patients,
SUM(SAFE_CAST(h.weekly_icu_admissions AS INT64)) AS new_icu_patients
FROM cases AS c
LEFT JOIN tests AS t ON c.iso_code = t.iso_code AND c.date = t.date
LEFT JOIN vaccinations AS v ON c.iso_code = v.iso_code AND c.date = v.date
LEFT JOIN hospital AS h ON c.iso_code = h.iso_code AND c.date = h.date
WHERE c.iso_code = 'GBR'
AND c.date BETWEEN 2021-01-01 AND 2021-12-31
GROUP BY month
ORDER BY month;


--How has the number of new confirmed cases changed on a daily basis within countries?
--To answer this question, use relative change. Relative change = (new cases - new cases on previous day) / new
cases on previous day * 100
--Provide country names, observation date, new confirmed cases, new cases on previous day, relative change. Also include a trend column,
which will contain the following information:
- ‘Increase’ if the relative change is positive;
- ‘Decrease’ if the relative change is negative;
- ‘No.change’ if there is no change.
  

WITH CTE1 AS (SELECT
r.location,
c.date,
c.new_cases,
LAG(c.new_cases, 1) OVER (PARTITION BY c.iso_code ORDER BY c.date) AS lagnew_cases,
SAFE_DIVIDE((c.new_cases - LAG(c.new_cases, 1) OVER (PARTITION BY c.iso_code ORDER BY c.date)),
NULLIF(LAG(c.new_cases, 1) OVER (PARTITION BY c.iso_code ORDER BY c.date), 0)) * 100 AS rel_diff
FROM cases AS c
JOIN regions AS r ON c.iso_code = r.iso_code
WHERE c.new_cases IS NOT NULL
)
SELECT
location,
date,
new_cases,
lagnew_cases,
rel_diff,
CASE
WHEN rel_diff > 0 THEN 'Increase'
WHEN rel_diff < 0 THEN 'Decrease'
WHEN rel_diff = 0 THEN 'No change'
END AS trend
FROM CTE1
ORDER BY location, date;



--Which countries have the most confirmed cases between March 20 and March 30, 2020?
--We want the country with the most confirmed cases on a given day to be rank 1, the second highest to be rank 2, and so on. You should
find the top 1 country for each day between March 20 and March 30.
--Provide data on country name, observation date, new confirmed cases (you can output the rank to check that you only selected the top 1 countries).

WITH CTE1 AS (SELECT
r.location,
c.date,
c.new_cases,
RANK() OVER (PARTITION BY c.date ORDER BY c.new_cases DESC) AS rn
FROM cases AS c
JOIN regions AS r ON c.iso_code = r.iso_code
WHERE c.date BETWEEN 2020-03-20 AND 2020-03-30
AND c.new_cases IS NOT NULL
)
SELECT
location,
date,
new_cases,
rn
FROM CTE1
WHERE rn = 1
ORDER BY date;


--Which 25 countries had the highest deaths during COVID-19?
--Deaths = (new deaths / population) * 100
--Provide data on country name, observation date, new deaths, population, and death rate.

WITH CTE1 AS (SELECT
r.location,
c.date,
c.new_deaths,
d.population,
(c.new_deaths / d.population) * 100 AS mort
FROM cases AS c
JOIN regions AS r ON c.iso_code = r.iso_code
JOIN demography AS d ON c.iso_code = d.iso_code
WHERE c.new_deaths IS NOT NULL
AND d.population IS NOT NULL
),
CTE2 AS (SELECT
location,
date,
new_deaths,
population,
mort,
RANK() OVER (ORDER BY mort DESC) AS ranking
FROM CTE1
)
SELECT
location,
date,
new_deaths,
population,
mort,
ranking
FROM CTE2
WHERE ranking <= 25
ORDER BY ranking;







  


--iso_code должен состоять из трех букв. Есть ли в наборе iso_code, который не соответствует данному критерию?

SELECT iso_code
FROM cases
WHERE LENGTH(iso_code) > 3;


--Нам нужно узнать включили ли в наш набор данных острова. Найдите все названия стран в котором есть “Islands”.

SELECT location, continent
FROM regions
WHERE location LIKE "%Islands%";


--Мы хотим убрать текст в скобках в названиях стран. Напишите запрос, который поможет нам с этой задачей.

SELECT REGEXP_REPLACE(location, '\\(.*\\)',) AS Country_list
FROM regions
ORDER BY Country_list;


-- В какой стране вероятность смерти инфицированного человека была самой высокой?
--Вероятность смерти инфицированного человека = (количество смертей \ количество подтвержденных случаев) * 100
--Предоставьте название страны, дату наблюдения, вероятность смерти инфицированного человека.

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


--Какова доля зараженного населения и доля населения умершего от COVID-19 для каждой страны?
--Вероятность смерти инфицированного человека = (количество смертей \ количество подтвержденных случаев) * 100
--Предоставьте название страны, общее количество подтвержденных случаев, общее количество смертей, численность населения, 
доля зараженного населения страны и доля населения страны умершего от COVID-19. Страна с наибольшей долей зараженного населения должна отображаться первой.

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

--Какова доля зараженного населения и доля населения умершего от COVID-19 в мире?
--Предоставьте общее количество подтвержденных случаев по всему миру, общее количество смертей, численность населения в мире, доля зараженного населения и доля
населения умершего от COVID-19.


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


--Какие страны хорошо справились с лечением?
--Предоставьте названия стран, первую дату наблюдения количество пациентов в неотложке в наборе данных, последнюю дату наблюдения количество пациентов в
неотложке в наборе данных и разницу в количестве пациентов.

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


--Как Великобритания справлялась с COVID-19?
--Предоставьте данные о новых подтвержденных случаях и смертей, о количестве новых тестов и новых доз вакцин, о количество пациентов, впервые поступивших в больницы и в
отделения интенсивной терапии по месяцам. 

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


--Как менялось количество новых подтвержденных случаев на ежедневной основе внутри стран?
Чтобы ответить на этот вопрос, воспользуйтесь относительным изменением. Относительное изменение = (новые случаи - новые случаи в предыдущий день) / новые
случаи в предыдущий день * 100
Предоставьте названия стран, дату наблюдения, новые подтвержденные случаи, новые случаи в предыдущий день, относительное изменение. Также добавьте столбец trend,
который будет содержать следующую информацию:
- ‘Increase’, если относительное изменение положительное;
- ‘Decrease’, если относительное изменение отрицательное;
- ‘No.change’, если нет изменении.


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



--В каких странах зафиксированы наибольшее количество подтвержденных случаев в период с 20 марта по 30 марта 2020 года?
--Мы хотим, чтобы страна с наибольшим количеством подтвержденных случаев в определенный день имела ранг 1, вторая по величине — ранг 2 и так далее. Вы должны
найти топ-1 страну для каждого дня в период с 20 по 30 марта.
--Предоставьте данные о названии стран, дату наблюдения, новые подтвержденные случаи (можно вывести ранк, чтобы проверить что вы выбрали только топ-1 стран).


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


--Какие 25 стран имели наибольшую смертность во время COVID-19?
--Смертность = (новые смерти / численность населения) * 100
--Предоставьте данные о названии стран, дату наблюдения, новые смерти, численность населения, и уровень смертности.

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







  


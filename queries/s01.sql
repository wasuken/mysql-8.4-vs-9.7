SELECT f.rating, COUNT(*) AS cnt, AVG(f.length) AS avg_length
FROM film f
JOIN language l ON f.language_id = l.language_id
GROUP BY f.rating;

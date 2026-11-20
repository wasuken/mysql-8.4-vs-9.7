SELECT d.rental_day, COUNT(r.rental_id) AS cnt
FROM (
    SELECT DATE('2005-05-01') + INTERVAL (film_id - 1) DAY AS rental_day
    FROM film
    WHERE film_id <= 120
) d
LEFT JOIN rental r ON DATE(r.rental_date) = d.rental_day
GROUP BY d.rental_day
ORDER BY d.rental_day;

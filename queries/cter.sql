WITH RECURSIVE rental_days (rental_day, day_number) AS (
    SELECT DATE('2005-05-01'), 1
    UNION ALL
    SELECT rental_day + INTERVAL 1 DAY, day_number + 1
    FROM rental_days
    WHERE day_number < 120
)
SELECT d.rental_day, COUNT(r.rental_id) AS cnt
FROM rental_days d
LEFT JOIN rental r ON r.rental_date >= d.rental_day
                  AND r.rental_date < d.rental_day + INTERVAL 1 DAY
GROUP BY d.rental_day
ORDER BY d.rental_day;

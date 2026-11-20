-- 期間中の貸出がなく、姓が A で始まる出演者もいない映画。
SELECT f.film_id, COUNT(r.rental_id) AS cnt
FROM film f
LEFT JOIN inventory i ON f.film_id = i.film_id
LEFT JOIN rental r ON i.inventory_id = r.inventory_id
                  AND r.rental_date >= '2005-08-01'
WHERE NOT EXISTS (
    SELECT 1
    FROM film_actor fa
    JOIN actor a ON fa.actor_id = a.actor_id
    WHERE fa.film_id = f.film_id AND a.last_name LIKE 'A%'
)
GROUP BY f.film_id
HAVING COUNT(r.rental_id) = 0;

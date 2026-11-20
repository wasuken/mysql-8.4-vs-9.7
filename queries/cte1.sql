WITH category_rentals AS (
    SELECT fc.category_id, COUNT(*) AS cnt
    FROM rental r
    JOIN inventory i ON r.inventory_id = i.inventory_id
    JOIN film_category fc ON i.film_id = fc.film_id
    GROUP BY fc.category_id
)
SELECT c.name AS category, cr.cnt
FROM category_rentals cr
JOIN category c ON cr.category_id = c.category_id;

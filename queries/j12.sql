SELECT co.country, c.name AS category, COUNT(*) AS cnt, SUM(p.amount) AS total_amount
FROM rental r
INNER JOIN customer cu ON r.customer_id = cu.customer_id
INNER JOIN address a ON cu.address_id = a.address_id
INNER JOIN city ci ON a.city_id = ci.city_id
INNER JOIN country co ON ci.country_id = co.country_id
INNER JOIN staff s ON r.staff_id = s.staff_id
INNER JOIN payment p ON p.rental_id = r.rental_id
INNER JOIN inventory i ON r.inventory_id = i.inventory_id
INNER JOIN film f ON i.film_id = f.film_id
INNER JOIN film_category fc ON f.film_id = fc.film_id
INNER JOIN category c ON fc.category_id = c.category_id
INNER JOIN language l ON f.language_id = l.language_id
GROUP BY co.country, c.name;

SELECT c.name AS category, ci.city, COUNT(*) AS cnt
FROM rental r
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film f ON i.film_id = f.film_id
JOIN film_category fc ON f.film_id = fc.film_id
JOIN category c ON fc.category_id = c.category_id
JOIN customer cu ON r.customer_id = cu.customer_id
JOIN address a ON cu.address_id = a.address_id
JOIN city ci ON a.city_id = ci.city_id
WHERE r.rental_date >= '2005-07-01'
GROUP BY c.name, ci.city
ORDER BY cnt DESC;

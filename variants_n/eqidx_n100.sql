SELECT c.customer_id, COUNT(r.rental_id) AS cnt
FROM customer c
LEFT JOIN rental r ON r.customer_id = c.customer_id
WHERE c.customer_id <= 100
GROUP BY c.customer_id
ORDER BY c.customer_id;

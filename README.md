# Домашнее задание к занятию "SQL. Часть 2`" - `Шаталов Леонид Юрьевич`

## Задание 1.

Одним запросом получите информацию о магазине, в котором обслуживается более 300 покупателей, и выведите в результат следующую информацию:

фамилия и имя сотрудника из этого магазина;
город нахождения магазина;
количество пользователей, закреплённых в этом магазине.

```
SELECT
    s.first_name AS имя,
    s.last_name  AS фамилия,
    ci.city      AS город,
    COUNT(c.customer_id) AS количество_покупателей
FROM store st
JOIN staff s    ON st.manager_staff_id = s.staff_id
JOIN address a  ON st.address_id = a.address_id
JOIN city ci    ON a.city_id = ci.city_id
JOIN customer c ON c.store_id = st.store_id
GROUP BY st.store_id, s.first_name, s.last_name, ci.city
HAVING COUNT(c.customer_id) > 300;
```

## Задание 2

Получите количество фильмов, продолжительность которых больше средней продолжительности всех фильмов.

```
SELECT COUNT(*) AS количество_фильмов
FROM film
WHERE length > (SELECT AVG(length) FROM film);
```


## Задание 3

Получите информацию, за какой месяц была получена наибольшая сумма платежей, и добавьте информацию по количеству аренд за этот месяц.

```
SELECT DATE_TRUNC('month', p.payment_date) AS месяц,
       SUM(p.amount)  AS сумма_платежей,
       COUNT(r.rental_id) AS количество_аренд
FROM payment p
JOIN rental r ON r.rental_id = p.rental_id
GROUP BY DATE_TRUNC('month', p.payment_date)
ORDER BY SUM(p.amount) DESC
LIMIT 1;
```

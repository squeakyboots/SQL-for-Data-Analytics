-- identifies bad payments matched to a single rental_id
SELECT * FROM 
	(SELECT rental_id,COUNT(rental_id) AS rental_count 
	 FROM payment inr 
	 GROUP BY rental_id) otr 
ORDER BY otr.rental_count DESC;

-- gives rental durations, rates, and amounts paid
SELECT inventory.store_id,film.film_id,rental.rental_id,film.rental_duration,return_date-rental_date AS time_rented,
film.rental_rate,payment.amount FROM payment
JOIN rental USING(rental_id)
JOIN inventory USING(inventory_id)
JOIN film USING(film_id)
ORDER BY inventory.store_id,film.film_id,rental_duration;

-- summary
SELECT SUM(payment.amount),film.film_id,film.title,inventory.store_id FROM payment
JOIN rental USING(rental_id)
JOIN inventory USING(inventory_id)
JOIN film USING(film_id)
GROUP BY film.film_id,inventory.store_id
ORDER BY sum desc,film_id,store_id;

-- detailed view
SELECT payment.payment_id,payment.amount,film.title,inventory.store_id FROM payment
JOIN rental USING(rental_id)
JOIN inventory USING(inventory_id)
JOIN film USING(film_id)
ORDER BY film.film_id,inventory.store_id;

-- create detailed table
DROP TABLE detailed;
CREATE TABLE detailed (payment_id integer,
					  amount numeric(5, 2) NOT NULL,
					  title character varying(255) NOT NULL,
					  store_id smallint NOT NULL,
					  store character varying(60),
					  PRIMARY KEY (payment_id));

-- create summary table
DROP TABLE summary;
CREATE TABLE summary (rank_id integer,
					 amount numeric(5, 2) NOT NULL,
					 title character varying(255) NOT NULL,
					 store_id smallint NOT NULL,
					 PRIMARY KEY (rank_id));

-- populate detailed table from DB, also transforming store ID into a store name
INSERT INTO detailed
(SELECT payment.payment_id,payment.amount,film.title,inventory.store_id
FROM payment
JOIN rental USING(rental_id)
JOIN inventory USING(inventory_id)
JOIN film USING(film_id)
ORDER BY film.film_id,inventory.store_id);

-- verify accuracy of the data by putting the tables side by side and looking at amount
SELECT * FROM payment
JOIN detailed USING(payment_id);
-- verify accuracy of the data by summing the totals of each table and counting the rows of each talbe and comparing
SELECT SUM(payment.amount) AS payment_table_amount,SUM(detailed.amount) AS detailed_table_amount,
COUNT(payment.*) AS payment_table_count,COUNT(detailed.*) AS detailed_table_amount
FROM payment
JOIN detailed USING(payment_id);

-- identifies store cities
SELECT store.store_id,address.address_id,city.* FROM store
JOIN address USING(address_id)
JOIN city USING (city_id);

-- function to perfrom transform from store_id to store name ##TEST ME A4###
CREATE FUNCTION store_id_to_name(integer) RETURNS character varying(60) AS $store$
DECLARE 
	store character varying(60);
BEGIN
	SELECT CONCAT(city.city,' Store') FROM store
	JOIN address USING(address_id)
	JOIN city USING (city_id) INTO store WHERE store_id=$1;
RETURN store;
END; $store$
LANGUAGE PLPGSQL;

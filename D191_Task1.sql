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

-- summary view
SELECT SUM(payment.amount),film.film_id,film.title,inventory.store_id FROM payment
JOIN rental USING(rental_id)
JOIN inventory USING(inventory_id)
JOIN film USING(film_id)
GROUP BY film.film_id,inventory.store_id
ORDER BY sum desc,film_id,store_id;

-- grab only top 10 from each store (summary view) #INCORRECT values
SELECT ROW_NUMBER() OVER (PARTITION BY inr.store_id) AS film_rank,total,title,store_id FROM (
SELECT ROW_NUMBER() OVER (PARTITION BY inventory.store_id) AS row_id,
SUM(payment.amount) AS total,film.film_id,film.title,inventory.store_id
FROM payment
JOIN rental USING(rental_id)
JOIN inventory USING(inventory_id)
JOIN film USING(film_id)
GROUP BY film.film_id,inventory.store_id
ORDER BY store_id,total DESC) as inr
WHERE row_id<=10;

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
CREATE TABLE summary (summary_id integer,
					 film_rank integer,
					 amount numeric(5, 2) NOT NULL,
					 film_title character varying(255) NOT NULL,
					 store_name character varying(60),
					 PRIMARY KEY (summary_id));

-- create summary table without PK
DROP TABLE summary;
CREATE TABLE summary (film_rank integer,
					 amount numeric(5, 2) NOT NULL,
					 film_title character varying(255) NOT NULL,
					 store_name character varying(60));

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

-- function to perfrom transform from store_id to store name
DROP FUNCTION store_id_to_name;
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

-- update the table using the function (D)
UPDATE detailed SET store=store_id_to_name(store_id);

-- summary view from detailed table
SELECT ROW_NUMBER() OVER (PARTITION BY inventory.store_id) AS row_id,
SUM(payment.amount) AS total,film.film_id,film.title,inventory.store_id
FROM payment
JOIN rental USING(rental_id)
JOIN inventory USING(inventory_id)
JOIN film USING(film_id)
GROUP BY film.film_id,inventory.store_id
ORDER BY store_id,total DESC

-- top 10 of each movie from detailed table
SELECT * FROM (
	SELECT ROW_NUMBER() OVER (PARTITION BY store) AS rank_id,inr.* FROM (
		SELECT SUM(amount) AS total,title,store 
		FROM detailed GROUP BY title,store ORDER BY store,total DESC
	) AS inr
) AS otr
WHERE rank_id<=10;

SELECT SUM(amount) FROM detailed GROUP BY title,store_id HAVING title='Telegraph Voyage' AND store_id=1

-- trigger function to update summary table when data is added to detailed table (E)
DROP FUNCTION update_summary;
CREATE FUNCTION update_summary() RETURNS TRIGGER AS $summary_trigger$
BEGIN
	TRUNCATE TABLE summary RESTART IDENTITY;
	INSERT INTO summary (
	SELECT * FROM (
	SELECT ROW_NUMBER() OVER (PARTITION BY store) AS rank_id,inr.* FROM (
		SELECT SUM(amount) AS total,title,store 
		FROM detailed GROUP BY title,store ORDER BY store,total DESC
		) AS inr
	) AS otr
	WHERE rank_id<=10
	);
	RETURN NEW;
END; $summary_trigger$
LANGUAGE PLPGSQL;

-- create summary table update trigger
DROP TRIGGER update_summary_trigger ON detailed;
CREATE TRIGGER update_summary_trigger AFTER INSERT ON detailed
FOR STATEMENT EXECUTE PROCEDURE update_summary();

-- to test trigger
INSERT INTO detailed VALUES (99999998,1.00,'Harry Idaho',1,'Lethbridge Store')
INSERT INTO detailed VALUES (99999999,10.00,'Harry Idaho',1,'Lethbridge Store')


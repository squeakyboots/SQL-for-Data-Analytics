-- create detailed table (B)
DROP TABLE IF EXISTS detailed;
CREATE TABLE detailed (payment_id integer,
					  amount numeric(5, 2) NOT NULL,
					  title character varying(255) NOT NULL,
					  store_id smallint NOT NULL,
					  store character varying(60),
					  PRIMARY KEY (payment_id));

-- create summary table (B cont'd)
DROP TABLE IF EXISTS summary;
CREATE TABLE summary (film_rank integer,
					 amount numeric(5, 2) NOT NULL,
					 film_title character varying(255) NOT NULL,
					 store_name character varying(60));

-- populate detailed table from DB (C)
INSERT INTO detailed
(SELECT payment.payment_id,payment.amount,film.title,inventory.store_id
FROM payment
JOIN rental USING(rental_id)
JOIN inventory USING(inventory_id)
JOIN film USING(film_id)
ORDER BY film.film_id,inventory.store_id);

-- verify accuracy of the data by putting the tables side by side and looking at amount (C cont'd)
SELECT * FROM payment
JOIN detailed USING(payment_id);
-- verify accuracy of the data by summing the totals of each table and counting the rows of each talbe and comparing (C cont'd)
SELECT SUM(payment.amount) AS payment_table_amount,SUM(detailed.amount) AS detailed_table_amount,
COUNT(payment.*) AS payment_table_count,COUNT(detailed.*) AS detailed_table_amount
FROM payment
JOIN detailed USING(payment_id);

-- function to perfrom transform from store_id to store name (D)
CREATE OR REPLACE FUNCTION store_id_to_name(integer) RETURNS character varying(60) AS $store$
DECLARE 
	store character varying(60);
BEGIN
	SELECT CONCAT(city.city,' Store') FROM store
	JOIN address USING(address_id)
	JOIN city USING (city_id) INTO store WHERE store_id=$1;
RETURN store;
END; $store$
LANGUAGE PLPGSQL;

-- trigger function to update summary table when data is added to detailed table (E)
CREATE OR REPLACE FUNCTION update_summary() RETURNS TRIGGER AS $summary_trigger$
BEGIN
	-- clear the summary table
	TRUNCATE TABLE summary RESTART IDENTITY;
	-- make sure store names are set in detailed table
	UPDATE detailed SET store=store_id_to_name(store_id);
	-- update data from detailed to summary table
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
END;$summary_trigger$
LANGUAGE PLPGSQL;

-- create summary table update trigger (E cont'd)
DROP TRIGGER IF EXISTS update_summary_trigger ON detailed;
CREATE TRIGGER update_summary_trigger 
	AFTER INSERT ON detailed
	FOR EACH STATEMENT EXECUTE PROCEDURE update_summary();

-- create a stored procedure that can be used to refresh the data in both tables (F)
CREATE OR REPLACE PROCEDURE refresh_data() AS $refresh_procedure$
BEGIN
DELETE FROM detailed;
DELETE FROM summary;
	-- refresh data into detailed table
INSERT INTO detailed
(SELECT payment.payment_id,payment.amount,film.title,inventory.store_id
FROM payment
JOIN rental USING(rental_id)
JOIN inventory USING(inventory_id)
JOIN film USING(film_id)
ORDER BY film.film_id,inventory.store_id);

END;$refresh_procedure$
LANGUAGE PLPGSQL;

-- refresh the data, recommended hourly
CALL refresh_data();

-- to test things
DROP TABLE detailed CASCADE;
DROP TABLE summary CASCADE;
SELECT * FROM detailed;
SELECT * FROM summary;
INSERT INTO detailed VALUES (99999997,1.00,'Harry Idaho',1,'Lethbridge Store')
INSERT INTO detailed VALUES (99999998,100.00,'Harry Idaho',1,'Lethbridge Store')
INSERT INTO detailed VALUES (99999999,100.00,'Hustler Party',1,'Lethbridge Store')

select version();

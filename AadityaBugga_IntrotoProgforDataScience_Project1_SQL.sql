/*Question 1 - What is the revenue earned (divided by quartiles)? What is the number of corresponding units in inventory for each quartile?*/


/* calculating revenue and no of copies in inventory by film */
   WITH film_revenue AS
 (SELECT
         f.film_id,
         f.title,
         SUM(p.amount) revenue,
         COUNT(i.inventory_id) copies_in_inventory
    FROM film f
    JOIN inventory i
      ON f.film_id = i.film_id
    JOIN rental r
      ON i.inventory_id = r.inventory_id
    JOIN payment p
      ON r.rental_id = p.rental_id
GROUP BY 1, 2
ORDER BY 3 DESC),

/* assigning quartiles based on revenue earned by each film*/
film_revenue_quartiles AS
 (SELECT
          film_id,
          title,
          revenue,
          copies_in_inventory,
    CASE  WHEN NTILE(4) OVER (ORDER BY revenue) = 1 THEN '1st'
          WHEN NTILE(4) OVER (ORDER BY revenue) = 2 THEN '2nd'
          WHEN NTILE(4) OVER (ORDER BY revenue) = 3 THEN '3rd'
          WHEN NTILE(4) OVER (ORDER BY revenue) = 4 THEN '4th'END AS revenue_quartile
    FROM  film_revenue
ORDER BY  3 DESC)

/* aggregating revenue and inventory items by quartile */
  SELECT
          revenue_quartile AS "Revenue quartile",  --I've used aliases with spaces and caps only because this will go into an Excel chart/PPT
          SUM(copies_in_inventory) AS "No of units in inventory",
          CAST(ROUND(SUM(revenue)) AS money) AS "Revenue ($)"
    FROM  film_revenue_quartiles
GROUP BY  1
ORDER BY  3 DESC;


---------------------------------------------------------------------------------------------------------------------------------------------------------------
/* Question 2 - How do Sakila’s stores compare in revenue earned each months for all years?*/

/*pivoting the data from the main data query into a format that can be charted in Excel*/

SELECT rental_month,
       CAST(SUM(CASE WHEN store = 1 THEN revenue ELSE NULL END) AS money) AS "Store 1",  --I've used aliases with spaces and caps only because this will go into an Excel chart/PPT
       CAST(SUM(CASE WHEN store = 2 THEN revenue ELSE NULL END) AS money) AS "Store 2"

  FROM
/*putting the main data together in the SQL below*/
    (     SELECT DATE_PART('year', r.rental_date) || '-' || DATE_PART('month', r.rental_date) AS rental_month,
                 sto.store_id store,
                 SUM(p.amount) revenue
            FROM store sto
            JOIN staff s
              ON sto.store_id = s.store_id
            JOIN payment p
              ON s.staff_id = p.staff_id
            JOIN rental r
              ON p.rental_id = r.rental_id
        GROUP BY 1, 2) AS sub
GROUP BY 1
ORDER BY 1;

---------------------------------------------------------------------------------------------------------------------------------------------------------------
/*Question 3 - How much does Sakila earn from our customers on average? Divide customers into deciles based on total payments, and show us the average for each decile to give us a useful spread.*/

WITH
--CTE1 for getting the total payments of all customers
all_cust_payment_details AS
( SELECT cu.customer_id, --using the IDs and not names since names may not always be unique
         cu.first_name || ' ' || cu.last_name full_name,
         SUM(p.amount) payment
    FROM customer cu
    JOIN payment p
      ON cu.customer_id = p.customer_id
GROUP BY 1, 2
ORDER BY 3 DESC),

--CTE2 for calculating revenue decile for each customer based on their total payment
calculating_revenue_deciles AS
(    SELECT customer_id,
            full_name,
            payment,
            CASE WHEN NTILE(10) OVER (ORDER BY payment) = 1 THEN '1st' --converting plain deciles into labels more suited for charting
            WHEN NTILE(10) OVER (ORDER BY payment) = 2 THEN '2nd'
            WHEN NTILE(10) OVER (ORDER BY payment) = 3 THEN '3rd'
            ELSE CAST((NTILE(10) OVER (ORDER BY payment)) AS text) || 'th' END AS revenue_decile
       FROM all_cust_payment_details
   ORDER BY 3 DESC)

--final query - calculating the average revenue per customer separately for each decile
  SELECT DISTINCT revenue_decile,
                  CAST(ROUND(AVG(payment) OVER (PARTITION BY revenue_decile), 0) AS money) AS avg_customer_spend
             FROM calculating_revenue_deciles
        ORDER BY  2 DESC;

---------------------------------------------------------------------------------------------------------------------------------------------------------------
/* Question 4 - How long after returning their films do our customers pay us? Divide our customers into quartiles based on their return date–payment date gap, and show the average payment interval, in days, for each quartile.*/

SELECT DISTINCT payment_interval_quartile,
                ROUND(AVG(payment_gap_days)) AS avg_payment_interval_days

           FROM

                    (SELECT customer_id,
                            total_cust_payment,
                            payment_gap_days,
                            CASE  WHEN NTILE(4) OVER (ORDER BY payment_gap_days) = 4 THEN '4th'
                                  WHEN NTILE(4) OVER (ORDER BY payment_gap_days) = 3 THEN '3rd'
                                  WHEN NTILE(4) OVER (ORDER BY payment_gap_days) = 2 THEN '2nd'
                                  ELSE '1st' END AS payment_interval_quartile

                    FROM
                          (SELECT
                                  cu.customer_id,
                                  ROUND(SUM(p.amount))::money AS total_cust_payment,
                                  ROUND(AVG(DATE_PART('day', p.payment_date-r.return_date)))::int AS payment_gap_days
                            FROM  country
                            JOIN  city
                              ON  country.country_id = city.country_id
                            JOIN  address add
                              ON  city.city_id = add.city_id
                            JOIN  customer cu
                              ON  add.address_id = cu.address_id
                            JOIN  payment p
                              ON  cu.customer_id = p.customer_id
                            JOIN  rental r
                              ON  p.rental_id = r.rental_id
                            GROUP BY 1
                            ORDER BY 2 DESC, 3 DESC) AS sub
                          ) AS sub2

          GROUP BY 1
          ORDER BY 1 DESC;

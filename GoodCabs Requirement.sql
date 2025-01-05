-- Business Request - 1: City Level Fare and Trip Summary Report 

SELECT 
	dc.city_name AS City, 
	COUNT(ft.trip_id) AS Total_Trips,
	ROUND((SUM(ft.fare_amount)/SUM(ft.distance_travelled_km)),2) AS Avg_Fare_Per_Km,
	ROUND((SUM(ft.fare_amount)/COUNT(ft.trip_id)),2) AS Avg_Fare_Per_Trip,
	CONCAT(ROUND((COUNT(ft.trip_id)*100.0/SUM(COUNT(ft.trip_id)) over()),2),"%")  AS Pct_Contribution_to_Total_Trips
FROM 
	dim_city dc 
JOIN 
	fact_trips ft 
ON
	dc.city_id = ft.city_id
GROUP BY City
ORDER BY Total_Trips;


-- Business Request - 2: Monthly City - Level Trips Target Performance Report

WITH cte1 AS (SELECT 
       c.city_id,
	   c.city_name, 
       dt.month_name, 
       dt.start_of_month, 
       count(t.trip_id) AS actual_trips  
       FROM
		fact_trips t 
       JOIN 
		dim_city c 
       ON 
		c.city_id = t.city_id
       JOIN 
		dim_date dt 
       ON
		dt.date = t.date
GROUP BY c.city_id, c.city_name, dt.month_name, dt.start_of_month),
cte2 AS (
          SELECT a.*,
                 tt.total_target_trips
          FROM
			cte1 a
          JOIN 
			targets_db.monthly_target_trips tt
          ON
			a.city_id = tt.city_id AND a.start_of_month = tt.month)

SELECT city_name AS City,
       month_name AS Month,
       actual_trips AS Total_Trip,
       total_target_trips AS Target_Trip,
       CASE WHEN actual_trips > total_target_trips THEN "Above Target"
            WHEN actual_trips < total_target_trips THEN "Below Target"
            ELSE "Same"
       END AS Status,
       ROUND((actual_trips - total_target_trips)*100/actual_trips,2) AS "%_Difference"
FROM cte2;


-- Business Request - 3: City-Level Repeat Passenger Trip Frequency Report
   
   WITH passenger_cnt AS ( 
    SELECT 
		city_id, 
		trip_count,  
		SUM(repeat_passenger_count) AS passenger_count
    FROM 
		trips_db.dim_repeat_trip_distribution 
    GROUP BY city_id, trip_count),
    
    repeat_trip AS (
    SELECT 
		city_id, 
		trip_count, 
		passenger_count, 
		CONCAT(CAST((passenger_count/SUM(passenger_count) OVER (PARTITION BY city_id))*100 AS DECIMAL(6,2)),"%") AS pct_contribution
    FROM 
		passenger_cnt
    GROUP BY city_id, trip_count)
    
    SELECT
		dc.city_name as City,
		MAX(CASE WHEN trip_count = "2-Trips" THEN pct_contribution ELSE 0 END) AS "2-Trips",
		MAX(CASE WHEN trip_count = "3-Trips" THEN pct_contribution ELSE 0 END) AS "3-Trips",
		MAX(CASE WHEN trip_count = "4-Trips" THEN pct_contribution ELSE 0 END) AS "4-Trips",
		MAX(CASE WHEN trip_count = "5-Trips" THEN pct_contribution ELSE 0 END) AS "5-Trips",
		MAX(CASE WHEN trip_count = "6-Trips" THEN pct_contribution ELSE 0 END) AS "6-Trips",
		MAX(CASE WHEN trip_count = "7-Trips" THEN pct_contribution ELSE 0 END) AS "7-Trips",
		MAX(CASE WHEN trip_count = "8-Trips" THEN pct_contribution ELSE 0 END) AS "8-Trips",
		MAX(CASE WHEN trip_count = "9-Trips" THEN pct_contribution ELSE 0 END) AS "9-Trips",
		MAX(CASE WHEN trip_count = "10-Trips" THEN pct_contribution ELSE 0 END) AS "10-Trips"
    FROM 
		repeat_trip rt 
	JOIN 
		trips_db.dim_city dc 
    ON
		rt.city_id = dc.city_id
    GROUP BY city_name;


-- Business Request - 4: Identify the cities with Highest and Lowest Total New Passengers 

WITH new_passenger AS (
	SELECT 
	dc.city_name, 
	SUM(fs.new_passengers) AS total_new_Passengers ,
	RANK() OVER(ORDER BY SUM(fs.new_passengers) DESC) AS Rank_desc,
	RANK() OVER(ORDER BY SUM(fs.new_passengers) ASC) AS Rank_asc
	FROM 
		trips_db.fact_passenger_summary fs 
	JOIN
		trips_db.dim_city dc 
	ON 
		fs.city_id = dc.city_id
	GROUP BY dc.city_id
	ORDER BY total_new_Passengers DESC)

SELECT 
	city_name AS City, 
	total_new_Passengers AS New_Passengers, 
CASE 
	WHEN Rank_desc <= 3 THEN "Top 3"
	WHEN Rank_asc <= 3 THEN "Bottom 3"
	END AS City_Type
FROM 
	new_passenger
WHERE Rank_desc <= 3 or Rank_asc <= 3;


-- Business Request - 5: Identify the Month with Highest Revenue for ach city 

WITH cte1 AS(SELECT 
     c.city_name,
	 SUM(fare_amount) AS revenue,
     MONTHNAME(t.date) AS highest_revenue_month,
     RANK() OVER( PARTITION BY c.city_name ORDER BY SUM(fare_amount) DESC) AS rank_revenue_month,
     SUM(SUM(fare_amount)) OVER(PARTITION BY c.city_name) AS monthwise_revenue
FROM 
     fact_trips t
JOIN 
	 dim_city c
ON 
     c.city_id = t.city_id
GROUP BY 
     c.city_name, highest_revenue_month)

SELECT city_name AS City, 
       Revenue, 
       Highest_Revenue_Month,
	   ROUND((revenue *100 /monthwise_revenue),2) AS Pct_Contribution
FROM
	cte1
WHERE rank_revenue_month=1
ORDER BY revenue DESC;


-- Business Request - 6: Repeat Passenger Rate Analysis - By City and Month Level

SELECT   
	dc.city_name AS City,
	monthname(fs.month) AS Month,
	SUM(fs.total_passengers) AS Total_Passengers,
	SUM(fs.repeat_passengers) AS Repeat_Passengers,
	CONCAT(ROUND(SUM(fs.repeat_passengers)/SUM(fs.total_passengers) *100,2),"%") AS Repeat_Passenger_Rate
FROM 
	trips_db.fact_passenger_summary fs
JOIN 
	trips_db.dim_city dc 
ON
	fs.city_id = dc.city_id
GROUP BY dc.city_name, month
;

-- by city

SELECT   
	dc.city_name AS City,
	SUM(fs.total_passengers) AS Total_Passengers,
	SUM(fs.repeat_passengers) AS Repeat_Passengers,
	CONCAT(ROUND(SUM(fs.repeat_passengers)/SUM(fs.total_passengers) *100,2),"%") AS Repeat_Passenger_Rate
FROM 
	trips_db.fact_passenger_summary fs 
JOIN 
	trips_db.dim_city dc 
ON 
	fs.city_id = dc.city_id
GROUP BY dc.city_name
;
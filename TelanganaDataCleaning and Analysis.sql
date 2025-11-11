 --CREATE DATABASE TelanganaGrowthAnalysis

--select * into Date_copy from dim_date
--select * into Districts from dim_districts
--select * into Transports from fact_transport
--select * into Stamps from fact_stamps
--select * into iPass from fact_TS_iPASS




----DISCREPANCY CHECKS

--1) iPass checking duplicated value
select dist_code, month,  sector , investment_in_cr , number_of_employees , count(*)
from iPass
group by dist_code, month,  sector , investment_in_cr , number_of_employees
having count(*) >1
-- no duplicated found


--2) Transports checking duplicated value

select dist_code, month, fuel_type_petrol ,fuel_type_diesel , fuel_type_electric , fuel_type_others, vehicleClass_MotorCycle , vehicleClass_MotorCar , vehicleClass_AutoRickshaw,
vehicleClass_Agriculture , vehicleClass_others , seatCapacity_1_to_3 , seatCapacity_4_to_6 , seatCapacity_above_6 , Brand_new_vehicles , 
Pre_owned_vehicles , category_Non_Transport , category_Transport , count(*)
from Transports
group by dist_code, month, fuel_type_petrol ,fuel_type_diesel , fuel_type_electric , fuel_type_others, vehicleClass_MotorCycle , vehicleClass_MotorCar , vehicleClass_AutoRickshaw,
vehicleClass_Agriculture , vehicleClass_others , seatCapacity_1_to_3 , seatCapacity_4_to_6 , seatCapacity_above_6 , Brand_new_vehicles , 
Pre_owned_vehicles , category_Non_Transport , category_Transport
having count(*) >1
-- no duplicated value found


select dist_code , count(*) 
from Transports
group by dist_code
having count(*) >1

select t.dist_code  , t.[month] , d.district
from Transports as t
left join Districts as d
on t.dist_code = d.dist_code
where t.dist_code = '21_3'
group by t.dist_code , [month] , d.district




--3) Stamps
SELECT dist_code, month, documents_registered_cnt , documents_registered_rev ,estamps_challans_cnt , estamps_challans_rev,COUNT(*)
FROM Stamps
GROUP BY dist_code, month , documents_registered_cnt , documents_registered_rev ,estamps_challans_cnt , estamps_challans_rev
HAVING COUNT(*) > 1
-- no dupliacted found

--4) Districts
select dist_code , district , count(*) 
from districts
group by dist_code , district
having count(*) >1
--not found

--5) Date
select month , Mmm ,  fiscal_year , count(*)
from Date_copy
group by month , Mmm ,  fiscal_year
having count(*) >1
-- not found


--6) Check for gaps in monthly sequence
WITH cte AS (
    SELECT month,
           LEAD(month, 1) OVER (ORDER BY month) AS next_month
    FROM Date_copy
)
SELECT *,
       DATEDIFF(MONTH, month, next_month) AS month_diff
FROM cte
WHERE DATEDIFF(MONTH, month, next_month) > 1


--7) Validate fiscal year logic
SELECT DISTINCT month, fiscal_year,
       CASE WHEN MONTH(month) >= 4 THEN YEAR(month) ELSE YEAR(month)-1 END AS expected_fiscal_year
FROM Date_copy
WHERE fiscal_year <> CASE WHEN MONTH(month) >= 4 THEN YEAR(month) ELSE YEAR(month)-1 END

--8) fact_stamps – Check for negative counts or revenue
SELECT *
FROM stamps
WHERE documents_registered_cnt < 0
   OR documents_registered_rev < 0
   OR estamps_challans_cnt < 0
   OR estamps_challans_rev < 0



---* Aggregate Stamps Data by Fiscal Year and Quarter
SELECT 
    d.fiscal_year,
    d.quarter,
    SUM(s.documents_registered_cnt) AS total_documents_registered,
    SUM(s.documents_registered_rev) AS total_revenue
FROM fact_stamps s
JOIN dim_date d ON s.month = d.month
GROUP BY d.fiscal_year, d.quarter
ORDER BY d.fiscal_year, d.quarter



-- * Missing Months in Fact Table Per District

-- All month-fiscal combinations from dim_date
WITH all_months AS (
    SELECT DISTINCT month, fiscal_year, quarter
    FROM dim_date
),
-- All dist_code + month combinations that exist in fact_stamps
existing_data AS (
    SELECT DISTINCT dist_code, month
    FROM fact_stamps
)
-- Find missing combinations
SELECT 
    d.month,
    d.fiscal_year,
    d.quarter,
    dc.dist_code
FROM all_months d
CROSS JOIN (SELECT DISTINCT dist_code FROM dim_districts) dc
WHERE NOT EXISTS (
    SELECT 1
    FROM existing_data ed
    WHERE ed.month = d.month AND ed.dist_code = dc.dist_code
)
ORDER BY d.month, dc.dist_code;

--DataType changes
ALTER TABLE Stamps
ALTER COLUMN documents_registered_cnt Float


ALTER TABLE Stamps
ALTER COLUMN documents_registered_rev Float

ALTER TABLE Stamps
ALTER COLUMN estamps_challans_cnt Float



ALTER TABLE Stamps
ALTER COLUMN estamps_challans_rev Float


--              ******------------------------------------ANALYSIS----------------------------------------******      


--1) Stamp Registrations Over Time

select d.fiscal_year, d.quarter,
    sum(s.documents_registered_cnt) as total_documents_registered ,
	sum(s.estamps_challans_cnt) as total_estamps_challans
from fact_stamps as s
left join dim_date d
on s.month = d.month
group by d.fiscal_year, d.quarter
order by d.fiscal_year, d.quarter


select * from fact_stamps

--2) Top 10 district by stamp revenue
SELECT TOP 10
    ds.district,
    SUM(s.documents_registered_rev) AS total_revenue
FROM fact_stamps s
JOIN dim_districts ds ON s.dist_code = ds.dist_code
GROUP BY ds.district
ORDER BY total_revenue DESC

--Bottom 10 district by stamp revenue
select TOP 10 ds.district,
    SUM(s.documents_registered_rev) AS total_revenue
FROM fact_stamps s
JOIN dim_districts ds 
ON s.dist_code = ds.dist_code
GROUP BY ds.district
ORDER BY total_revenue 

--3) Electric vehicle trends

SELECT d.fiscal_year, d.quarter,
    SUM(t.fuel_type_electric) AS electric_vehicles_registered
FROM fact_transport t
JOIN dim_date d 
ON t.month = d.month
GROUP BY d.fiscal_year, d.quarter
ORDER BY d.fiscal_year, d.quarter

--4)  Industrial Investment by Sector  :   Which sectors attract the most investment under TS-iPASS? 
SELECT sector,
    SUM(investment_in_cr) AS total_investment
FROM fact_TS_iPASS
GROUP BY sector
ORDER BY total_investment DESC

select * from iPass


-- 5) Job Creation by Sector : Which sectors are generating the most employment? 
SELECT sector, sum(number_of_employees) AS total_jobs_created
FROM iPASS
GROUP BY sector
ORDER BY total_jobs_created DESC

--6) District-wise Job Creation :   Which districts are leading in job creation?
select top 10 ds.district,
    SUM(ip.number_of_employees) as total_jobs_created
from iPASS as ip
left join dim_districts as ds 
on ip.dist_code = ds.dist_code
GROUP BY ds.district
ORDER BY total_jobs_created DESC

--7) Vehicle Class Distribution : What kind of vehicles dominate in Telangana? 
select 
    SUM(vehicleClass_MotorCycle) AS Motorcycles,
    SUM(vehicleClass_MotorCar) AS MotorCars,
    SUM(vehicleClass_AutoRickshaw) AS AutoRickshaws,
    SUM(vehicleClass_Agriculture) AS AgriculturalVehicles,
    SUM(vehicleClass_others) AS Others
from Transports

--8) Stamp Registration vs Industrial Investment Correlation : Is there a link between economic activity and industrial investments?
select d.fiscal_year, d.quarter,
    sum(s.documents_registered_cnt) as total_documents_registered,
    sum(ip.investment_in_cr) as total_investment
from stamps as s
left join iPASS as ip 
on s.dist_code = ip.dist_code and s.month = ip.month
left join dim_date d 
on s.month = d.month
group by d.fiscal_year, d.quarter
order by d.fiscal_year, d.quarter

--Metrics for Stamp and Documents

--1) Total Documents registered
SELECT SUM(documents_registered_cnt) AS Total_Documents_Registered
FROM Stamps

--2) Total reveunue from stamps 
SELECT 
    SUM(estamps_challans_rev) AS Total_Revenue_From_Stamps
FROM Stamps


--3)Document per district
SELECT 
  Top 1 dist_code,
    SUM(documents_registered_cnt) AS Documents_Per_District
FROM stamps
GROUP BY dist_code
order by dist_code desc

--4) Average revenue per stamps

SELECT 
    avg(estamps_challans_rev)  / NULLIF(avg(estamps_challans_cnt), 0) as Revenue_Per_Stamp
FROM stamps


--5 Average revenue per document 
SELECT 
    avg(documents_registered_rev)  / NULLIF(avg(documents_registered_cnt), 0) as Revenue_Per_document
FROM stamps

--6) Estamp penetration rate
SELECT
    SUM(estamps_challans_cnt) AS Total_eStamps,
    SUM(documents_registered_cnt) AS Total_Documents,
    CAST(SUM(estamps_challans_cnt) AS FLOAT) / NULLIF(SUM(documents_registered_cnt), 0) * 100 AS eStamp_Penetration_Rate_Percent
FROM stamps


--Metrics for transportation

--1) Total Fuel type vehicles
SELECT
    SUM(fuel_type_petrol + fuel_type_diesel + fuel_type_electric + fuel_type_others) AS total_vehicles_registered
FROM transports

--2) Total Vehciles class
SELECT 
    SUM(vehicleClass_MotorCycle) AS motorcycle_count,
    SUM(vehicleClass_MotorCar) AS motorcar_count,
    SUM(vehicleClass_AutoRickshaw) AS autorickshaw_count,
    SUM(vehicleClass_Agriculture) AS agriculture_count,
    SUM(vehicleClass_others) AS other_vehicle_count
FROM transports


--3) Percentage of brand-new vehicles

SELECT 
    SUM(Brand_new_vehicles) AS total_new_vehicles,
    SUM(Pre_owned_vehicles) AS total_used_vehicles,
    CASE 
        WHEN SUM(Brand_new_vehicles) + SUM(Pre_owned_vehicles) > 0 THEN 
            (SUM(Brand_new_vehicles) * 100.0 / (SUM(Brand_new_vehicles) + SUM(Pre_owned_vehicles)))
        ELSE 0
    END AS percentage_new_vehicles
FROM transports

--4) 

SELECT 
    SUM(category_Transport) AS total_transport_vehicles,
    SUM(category_Non_Transport) AS total_non_transport_vehicles,
    CASE 
    WHEN SUM(category_Transport) + SUM(category_Non_Transport) > 0 
	THEN (SUM(category_Transport) * 100.0 / (SUM(category_Transport) + SUM(category_Non_Transport))) else 0
	END AS percentage_transport_vehicles
	FROM transports

--5) 

SELECT 
    SUM(seatCapacity_1_to_3) AS seat_1_to_3,
    SUM(seatCapacity_4_to_6) AS seat_4_to_6,
    SUM(seatCapacity_above_6) AS seat_above_6,
	sum(seatCapacity_1_to_3 +seatCapacity_4_to_6+seatCapacity_above_6)
FROM fact_transport


--6) Average passengers per vehicles
WITH VehicleMetrics AS (
    SELECT 
        -- Total vehicles
        SUM(fuel_type_petrol + fuel_type_diesel + fuel_type_electric + fuel_type_others) AS total_vehicles,

        -- Passenger capacity based on seatCapacity assumptions
        SUM(seatCapacity_1_to_3 * 2) AS passengers_1_to_3,  -- Assume 2 passengers per vehicle
        SUM(seatCapacity_4_to_6 * 5) AS passengers_4_to_6,  -- Assume 5 passengers per vehicle
        SUM(seatCapacity_above_6 * 8) AS passengers_above_6  -- Assume 8 passengers per vehicle
    FROM fact_transport
)
SELECT 
    total_vehicles,
    (passengers_1_to_3 + passengers_4_to_6 + passengers_above_6) AS total_passenger_capacity,
    
    -- Calculate average passengers per vehicle
    CASE 
        WHEN total_vehicles > 0 THEN 
            ROUND(
                (passengers_1_to_3 + passengers_4_to_6 + passengers_above_6) * 1.0 / total_vehicles, 
                2
            )
        ELSE 0
    END AS avg_passengers_per_vehicle
FROM VehicleMetrics

--)7  EV adoption percenatge

WITH VehicleMetrics AS (
    SELECT 
        dist_code,
        SUM(fuel_type_electric) AS total_electric_vehicles,
        SUM(fuel_type_petrol + fuel_type_diesel + fuel_type_electric + fuel_type_others) AS total_vehicles
    FROM Transports
    GROUP BY dist_code
)
SELECT 
    d.district AS district_name,
    vm.dist_code,
    vm.total_electric_vehicles,
    vm.total_vehicles,
    CASE 
        WHEN vm.total_vehicles > 0 THEN 
            (vm.total_electric_vehicles * 100.0) / vm.total_vehicles
        ELSE 0
    END AS ev_adoption_percentage
FROM VehicleMetrics vm
JOIN dim_districts d ON vm.dist_code = d.dist_code
ORDER BY ev_adoption_percentage DESC



--Metrics for iPASS

--1) Total investment
select sum(investment_in_cr)
from iPass

--2) Total employemnet 
select sum(number_of_employees) from iPass

--3) Monthly growth rate

WITH MonthlyInvestments AS (
    SELECT 
        CAST(Month AS DATE) AS registration_month,
        SUM([investment_in_cr]) AS total_investment
    FROM fact_TS_iPASS
    GROUP BY CAST(Month AS DATE)
),
MonthlyGrowth AS (
    SELECT 
        registration_month,
        total_investment,
        LAG(total_investment, 1, NULL) OVER (ORDER BY registration_month) AS prev_month_investment
    FROM MonthlyInvestments
)
SELECT 
    registration_month,
    total_investment,
    prev_month_investment,
    ROUND(
        ((total_investment - prev_month_investment) * 100.0) / NULLIF(prev_month_investment, 0),
        2
    ) AS growth_rate_percentage
FROM MonthlyGrowth
WHERE prev_month_investment IS NOT NULL
ORDER BY registration_month

--4) avg investment per sector
WITH SectorInvestment AS (
    SELECT 
        sector,
        SUM(investment_in_cr) AS total_investment
    FROM iPASS
    GROUP BY sector
)
SELECT 
    AVG(total_investment) AS average_investment_per_sector
FROM SectorInvestment

--5) 
SELECT 
    sector,
    SUM(investment_in_cr) AS total_investment_crores,
    SUM(number_of_employees) AS total_number_of_employees
FROM fact_TS_iPASS
GROUP BY sector
ORDER BY total_investment_crores DESC

--6)

SELECT 
    sector,
    SUM(investment_in_cr) AS total_investment_crores,
    SUM(number_of_employees) AS total_number_of_employees,
    CASE 
        WHEN SUM(number_of_employees) > 0 THEN 
            SUM(investment_in_cr) / SUM(number_of_employees)
        ELSE 0
    END AS labour_efficiency_per_employee
FROM fact_TS_iPASS
GROUP BY sector
ORDER BY labour_efficiency_per_employee DESC








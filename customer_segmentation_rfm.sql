CREATE DATABASE customer_segmentation;
use customer_segmentation;

CREATE TABLE online_retail_raw (
    InvoiceNo VARCHAR(20),
    StockCode VARCHAR(20),
    Description VARCHAR(255),
    Quantity INT,
    InvoiceDate VARCHAR(30),
    UnitPrice DECIMAL(12,4),
    CustomerID VARCHAR(20),
    Country VARCHAR(100)
);
SHOW VARIABLES LIKE 'local_infile';
SET GLOBAL local_infile = 1;
SHOW VARIABLES LIKE 'local_infile';

LOAD DATA LOCAL INFILE 'C:/Users/HP/Desktop/Online Retail DATA.csv'
INTO TABLE online_retail_raw
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(InvoiceNo, StockCode, Description, Quantity, InvoiceDate, UnitPrice, CustomerID, Country);

SELECT * FROM online_retail_raw;

--#Data Quality Checks


--#Checking CustomerID 
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE
        WHEN CustomerID IS NULL OR TRIM(CustomerID) = ''
        THEN 1 ELSE 0
    END) AS missing_customer_id,
    SUM(CASE
        WHEN CustomerID IS NOT NULL AND TRIM(CustomerID) <> ''
        THEN 1 ELSE 0
    END) AS customer_id_present
FROM online_retail_raw;

--#Checking cancelled transactions

select
count(*) as total_rows,
sum(case
    when InvoiceNo like 'c%' then 1 else 0 end) As Cancelled,
    sum(case
        when InvoiceNo not like 'c%' then 1 else 0 end) As Normal
        from online_retail_raw;
 
 --#Duplicates Checks
SELECT
    total_rows,
    distinct_rows,
    total_rows - distinct_rows AS duplicate_rows
FROM (
    SELECT
        COUNT(*) AS total_rows,
        COUNT(DISTINCT CONCAT_WS('|',
            InvoiceNo,
            StockCode,
            Description,
            Quantity,
            InvoiceDate,
            UnitPrice,
            CustomerID,
            Country
        )) AS distinct_rows
    FROM online_retail_raw
) AS counts;

    
    SELECT
    InvoiceNo,
    StockCode,
    Description,
    Quantity,
    InvoiceDate,
    UnitPrice,
    CustomerID,
    Country,
    COUNT(*) AS duplicate_count
FROM online_retail_raw
GROUP BY
    InvoiceNo,
    StockCode,
    Description,
    Quantity,
    InvoiceDate,
    UnitPrice,
    CustomerID,
    Country
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC
LIMIT 20;

--#Quantity checks 
SELECT
    COUNT(*) AS total_rows,
    
    SUM(CASE
        WHEN Quantity < 0 THEN 1
        ELSE 0
    END) AS negative_quantity,
    
    SUM(CASE
        WHEN Quantity = 0 THEN 1
        ELSE 0
    END) AS zero_quantity,
    
    SUM(CASE
        WHEN Quantity > 0 THEN 1
        ELSE 0
    END) AS positive_quantity

FROM online_retail_raw;

SELECT
    InvoiceNo,
    StockCode,
    Description,
    Quantity,
    InvoiceDate,
    UnitPrice,
    CustomerID,
    Country
FROM online_retail_raw
WHERE Quantity < 0
LIMIT 20;

SELECT
    SUM(CASE
        WHEN Quantity < 0
         AND InvoiceNo LIKE 'C%'
        THEN 1 ELSE 0
    END) AS negative_and_cancelled,

    SUM(CASE
        WHEN Quantity < 0
         AND InvoiceNo NOT LIKE 'C%'
        THEN 1 ELSE 0
    END) AS negative_not_cancelled,

    SUM(CASE
        WHEN Quantity < 0
        THEN 1 ELSE 0
    END) AS total_negative_quantity
FROM online_retail_raw;



SELECT
    InvoiceNo,
    StockCode,
    Description,
    Quantity,
    InvoiceDate,
    UnitPrice,
    CustomerID,
    Country
FROM online_retail_raw
WHERE Quantity < 0
  AND InvoiceNo NOT LIKE 'C%'
LIMIT 20;

--#UnitPrice Checks
SELECT
    COUNT(*) AS total_rows,

    SUM(CASE
        WHEN UnitPrice = 0 THEN 1
        ELSE 0
    END) AS zero_unit_price,

    SUM(CASE
        WHEN UnitPrice < 0 THEN 1
        ELSE 0
    END) AS negative_unit_price,

    SUM(CASE
        WHEN UnitPrice > 0 THEN 1
        ELSE 0
    END) AS positive_unit_price

FROM online_retail_raw;
   
   --# Negative Unit price
      SELECT
    InvoiceNo,
    StockCode,
    Description,
    Quantity,
    InvoiceDate,
    UnitPrice,
    CustomerID,
    Country
FROM online_retail_raw
WHERE UnitPrice < 0;  



        
 SELECT
    MIN(STR_TO_DATE(InvoiceDate, '%d-%m-%Y %H:%i')) AS earliest_date,
    MAX(STR_TO_DATE(InvoiceDate, '%d-%m-%Y %H:%i')) AS latest_date,
    COUNT(*) AS total_rows,
    COUNT(STR_TO_DATE(InvoiceDate, '%d-%m-%Y %H:%i')) AS valid_dates,
    COUNT(*) - COUNT(STR_TO_DATE(InvoiceDate, '%d-%m-%Y %H:%i')) AS invalid_dates
FROM online_retail_raw;  

--#Creating New Clean Table
CREATE TABLE online_retail_clean AS
SELECT DISTINCT
    InvoiceNo,
    StockCode,
    Description,
    Quantity,
    STR_TO_DATE(InvoiceDate, '%d-%m-%Y %H:%i') AS InvoiceDate,
    UnitPrice,
    CustomerID,
    Country
FROM online_retail_raw
WHERE Quantity > 0
  AND UnitPrice > 0
  AND InvoiceNo NOT LIKE 'C%';  
  
  describe online_retail_clean;

  
SELECT COUNT(*) AS clean_rows
FROM online_retail_clean; 

SELECT
    COUNT(*) AS total_clean_rows,
    COUNT(DISTINCT InvoiceNo) AS unique_invoices,
    COUNT(DISTINCT StockCode) AS unique_products,
    COUNT(DISTINCT CustomerID) AS unique_customers
FROM online_retail_clean;

--# Total Revenue
select sum(Quantity*Unitprice) as Total_Revenue
from online_retail_clean;

--# Revenue By Country
select country,
       count(*) as transactions_rows,
       count(DISTINCT InvoiceNo) as unique_Invoice,
       sum(Quantity*Unitprice)as Total_Revenue
       from online_retail_clean
       group by country
       order by Total_Revenue desc;
        
--#Top 10 Customers by Revenue
	SELECT
    CustomerID,
    COUNT(DISTINCT InvoiceNo) AS total_orders,
    SUM(Quantity) AS total_quantity,
    SUM(Quantity * UnitPrice) AS total_revenue
FROM online_retail_clean
WHERE CustomerID IS NOT NULL
  AND TRIM(CustomerID) <> ''
GROUP BY CustomerID
ORDER BY total_revenue DESC
LIMIT 10;

--# Creating Customer_level RFM table

CREATE TABLE customer_rfm AS
SELECT
    CustomerID,

    DATEDIFF(
        '2011-12-10',
        DATE(MAX(InvoiceDate))
    ) AS Recency,

    COUNT(DISTINCT InvoiceNo) AS Frequency,

    ROUND(
        SUM(Quantity * UnitPrice),
        2
    ) AS Monetary

FROM online_retail_clean

WHERE CustomerID IS NOT NULL
  AND TRIM(CustomerID) <> ''

GROUP BY CustomerID;

SELECT *
FROM customer_rfm
LIMIT 10;

SELECT COUNT(*) AS customer_count
FROM customer_rfm;

SELECT
    MIN(Recency) AS min_recency,
    MAX(Recency) AS max_recency,
    MIN(Frequency) AS min_frequency,
    MAX(Frequency) AS max_frequency,
    MIN(Monetary) AS min_monetary,
    MAX(Monetary) AS max_monetary
FROM customer_rfm;
--# Creating RFM Score
CREATE TABLE customer_rfm_scores AS
SELECT
    CustomerID,
    Recency,
    Frequency,
    Monetary,

    NTILE(5) OVER (
        ORDER BY Recency desc
    ) AS R_Score,

    NTILE(5) OVER (
        ORDER BY Frequency ASC
    ) AS F_Score,

    NTILE(5) OVER (
        ORDER BY Monetary ASC
    ) AS M_Score
FROM customer_rfm;

select * from customer_rfm_scores limit 20  ;

Alter table customer_rfm_scores
add column RFM_Score varchar(3);

update customer_rfm_scores
set RFM_Score = concat(R_Score,F_Score,M_Score);

SET SQL_SAFE_UPDATES = 1;

--#Creating customer segments
Create table customer_rfm_segmented as
select 
     CustomerID,
     Recency,
     Frequency,
     Monetary,
     R_Score,
     F_Score,
     M_Score,
     RFM_Score,
     
     case
     when R_Score>=4
     and F_Score>=4
     and M_Score>=4
     then 'Champions'
     
      WHEN R_Score <= 2
             AND F_Score >= 4
             AND M_Score >= 4
        THEN 'Cannot Lose Them'

        WHEN R_Score <= 2
             AND F_Score >= 3
             AND M_Score >= 3
        THEN 'At Risk'

        WHEN R_Score >= 3
             AND F_Score >= 4
             AND M_Score >= 3
        THEN 'Loyal Customers'

        WHEN R_Score >= 4
             AND F_Score BETWEEN 2 AND 3
             AND M_Score >= 2
        THEN 'Potential Loyalists'

        WHEN R_Score >= 4
             AND F_Score <= 2
        THEN 'New Customers'

        WHEN R_Score = 1
             AND F_Score <= 2
             AND M_Score <= 2
        THEN 'Lost Customers'

        WHEN R_Score <= 2
             AND F_Score <= 2
             AND M_Score <= 2
        THEN 'Hibernating'

        ELSE 'Needs Attention'

    END AS Customer_Segment

FROM customer_rfm_scores;

select * from customer_rfm_segmented;

select customer_segment, count(*) as Customer_Count
from customer_rfm_segmented
group by customer_segment
order by Customer_Count desc;

--#Percentage of customers in each segment
SELECT
    Customer_Segment,
    COUNT(*) AS Customer_Count,
    ROUND(
        COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM customer_rfm_segmented),
        2
    ) AS Customer_Percentage
FROM customer_rfm_segmented
GROUP BY Customer_Segment
ORDER BY Customer_Count DESC;

--#Revenue by customer segment
SELECT
    customer_segment,
    COUNT(*) AS Customer_Count,
    ROUND(SUM(monetary), 2) AS Total_Revenue,
    ROUND(AVG(monetary), 2) AS Average_Revenue_per_customer
FROM customer_rfm_segmented
GROUP BY customer_segment
ORDER BY Total_Revenue DESC;

--# Top 20 customers by revenue

SELECT
    CustomerID,
    frequency AS Number_of_Orders,
    monetary AS Total_Revenue,
    recency AS Recency_Days,
    customer_segment
FROM customer_rfm_segmented
ORDER BY monetary DESC
LIMIT 20;

--# At Risk customers

SELECT
    CustomerID,
    recency,
    frequency,
    monetary,
    customer_segment
FROM customer_rfm_segmented
WHERE customer_segment = 'At Risk'
ORDER BY monetary DESC;

--#Top 10 Products 
SELECT
    StockCode,
    Description,
    SUM(Quantity) AS Total_Quantity_Sold,
    ROUND(SUM(Quantity * UnitPrice), 2) AS Total_Revenue,
    ROUND(AVG(UnitPrice), 2) AS Average_Unit_Price
FROM online_retail_clean
GROUP BY StockCode, Description
ORDER BY Total_Revenue DESC
LIMIT 10;

--#Monthly Sales Trend
SELECT
    YEAR(InvoiceDate) AS Sales_Year,
    MONTH(InvoiceDate) AS Sales_Month,
    ROUND(SUM(Quantity * UnitPrice), 2) AS Monthly_Revenue,
    COUNT(DISTINCT InvoiceNo) AS Total_Orders
FROM online_retail_clean
GROUP BY
    YEAR(InvoiceDate),
    MONTH(InvoiceDate)
ORDER BY
    Sales_Year,
    Sales_Month;
    
    SELECT
    CustomerID,
    COUNT(DISTINCT InvoiceNo) AS Number_of_Orders,
    SUM(Quantity) AS Total_Items_Purchased,
    ROUND(SUM(Quantity * UnitPrice), 2) AS Total_Revenue,
    ROUND(
        SUM(Quantity * UnitPrice) /
        COUNT(DISTINCT InvoiceNo),
        2
    ) AS Average_Order_Value
FROM online_retail_clean
WHERE CustomerID IS NOT NULL
  AND TRIM(CustomerID) <> ''
GROUP BY CustomerID
ORDER BY Total_Revenue DESC;

--# Top 10 Products by Quantity Sold
SELECT
    StockCode,
    Description,
    SUM(Quantity) AS Total_Quantity_Sold,
    ROUND(SUM(Quantity * UnitPrice), 2) AS Total_Revenue
FROM online_retail_clean
GROUP BY
    StockCode,
    Description
ORDER BY Total_Quantity_Sold DESC
LIMIT 10;






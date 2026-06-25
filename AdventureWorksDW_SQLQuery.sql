USE AdventureWorksDW2022;
GO

--- Sales Performance ---
-- Q1. Tổng doanh thu
SELECT SUM(SalesAmount) AS 'Revenue'
FROM FactInternetSales;

-- Q2. Tổng số đơn
SELECT COUNT(*) AS 'TotalOrders'
FROM FactInternetSales;

-- Q3. Doanh thu theo năm
SELECT 
	SUM(SalesAmount) AS 'Revenue',
	YEAR(OrderDate) AS 'Year'
FROM FactInternetSales
GROUP BY YEAR(OrderDate)
ORDER BY SUM(SalesAmount) DESC;

-- Q4.1. Doanh thu theo tháng
SELECT 
	SUM(SalesAmount) AS 'Revenue',
	YEAR(OrderDate) AS 'Year',
	MONTH(OrderDate) AS 'Month'
FROM FactInternetSales
GROUP BY 
	YEAR(OrderDate), 
	MONTH(OrderDate)
ORDER BY YEAR(OrderDate) ASC, MONTH(OrderDate) ASC;

-- Q4.2. Tháng có doanh thu cao nhất theo từng năm
WITH CTE AS (
SELECT 
	SUM(SalesAmount) AS 'Revenue',
	YEAR(OrderDate) AS 'Years',
	MONTH(OrderDate) AS 'Months'
FROM FactInternetSales
GROUP BY 
	YEAR(OrderDate), 
	MONTH(OrderDate)
)
SELECT *
FROM (
	SELECT *,
		   ROW_NUMBER() OVER( PARTITION BY Years ORDER BY Revenue DESC) rnk
	FROM CTE
) t
WHERE rnk=1;

-- Q5. Top 10 sản phảm có doanh thu cao nhất
SELECT TOP 10 WITH TIES
	d.EnglishProductName,
	SUM(f.SalesAmount) Revenue
FROM FactInternetSales f
JOIN DimProduct d
ON f.ProductKey=d.ProductKey
GROUP BY d.EnglishProductName
ORDER BY Revenue DESC;

-- Q6. Doanh thu theo countries
SELECT
	g.EnglishCountryRegionName,
	SUM(f.SalesAmount) Revenue,
	SUM(f.SalesAmount)*100.0/(SELECT SUM(SalesAmount) FROM FactInternetSales) AS Rate
FROM FactInternetSales f
JOIN DimCustomer c
ON f.CustomerKey=c.CustomerKey
JOIN DimGeography g
ON c.GeographyKey=g.GeographyKey
GROUP BY g.EnglishCountryRegionName
ORDER BY Revenue DESC;

-- Q7. Tốc độ tăng trưởng doanh thu
WITH RevenueByYear AS (
    SELECT
        d.CalendarYear,
        SUM(f.SalesAmount) AS Revenue
    FROM FactInternetSales f
    JOIN DimDate d
	ON f.OrderDateKey = d.DateKey
	WHERE d.CalendarYear BETWEEN 2011 AND 2013
    GROUP BY d.CalendarYear
),
Growth AS (
    SELECT
        CalendarYear,
        Revenue,
        LAG(Revenue) OVER(ORDER BY CalendarYear) AS PrevRevenue
    FROM RevenueByYear
)
SELECT
    CalendarYear,
    Revenue,
    PrevRevenue,
    (Revenue - PrevRevenue) * 100.0/NULLIF(PrevRevenue,0) AS YoY_Growth_Pct
FROM Growth;

-- Customer Analysis --
-- Q1. Top khách hàng
SELECT TOP 5 WITH TIES
	c.CustomerKey,
	CONCAT_WS(' ', c.FirstName, c.MiddleName, c.LastName) CustomerName,
	SUM(f.SalesAmount) Revenue
FROM FactInternetSales f
LEFT JOIN DimCustomer c
ON f.CustomerKey=c.CustomerKey
GROUP BY 
	c.CustomerKey,
	CONCAT_WS(' ', c.FirstName, c.MiddleName, c.LastName)
ORDER BY Revenue DESC;

-- Q2. Tỷ lệ duy trì khách hàng & Tỷ lệ mất khách 2012 - 2013
WITH CusYear AS (
	SELECT DISTINCT 
		CustomerKey,
		YEAR(OrderDate) AS OrderYear
	FROM FactInternetSales
),
RET AS (
	SELECT
		CY1.OrderYear AS LastYear,
		CY1.OrderYear+1 AS RetentionYear,
		COUNT(DISTINCT CY1.CustomerKey) AS TotalCustomersLastYear,
		COUNT(DISTINCT CY2.CustomerKey) AS RetainedCustomers
	FROM CusYear CY1
	LEFT JOIN CusYear CY2
	ON CY1.CustomerKey=CY2.CustomerKey 
	AND CY2.OrderYear=CY1.OrderYear+1
	GROUP BY CY1.OrderYear, CY1.OrderYear+1
)
SELECT
	LastYear,
	RetentionYear,
	RetainedCustomers*100.0/TotalCustomersLastYear AS RetentionRate,
	100.0-(RetainedCustomers*100.0/TotalCustomersLastYear) AS ChurnRate
FROM RET 
WHERE LastYear=2012
ORDER BY LastYear;

-- Q3. CLV
WITH CTE AS (
	SELECT
		CustomerKey,
		DATEDIFF(
			DAY, 
			MAX(OrderDate), 
			(SELECT MAX(OrderDate) FROM FactInternetSales) 
		) AS Recency,
		COUNT(DISTINCT SalesOrderNumber) AS Frequency,
		SUM(SalesAmount) AS Monetary,
		SUM(SalesAmount) AS CLV
FROM FactInternetSales
GROUP BY CustomerKey
),
RFM AS (
	SELECT *,
		NTILE(5) OVER (ORDER BY Recency ASC) AS R_Score,
		NTILE(5) OVER (ORDER BY Frequency DESC) AS F_Score,
		NTILE(5) OVER (ORDER BY Monetary DESC) AS M_Score
    FROM CTE
)
SELECT
	*,
	(CASE
    WHEN R_Score >=4 AND F_Score >=4 AND M_Score >=4 THEN 'Champions'
    WHEN R_Score >=3 AND F_Score >=3 THEN 'Loyal Customers'
    WHEN R_Score <=2 AND F_Score >=4 THEN 'At Risk'
    ELSE 'Others'
END) AS CategoryRFM
FROM RFM;


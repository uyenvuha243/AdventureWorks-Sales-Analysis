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

-->> Insights: 
/*Từ năm 2010 đến năm 2014, tổng doanh thu đạt 29,358,677.22 với tổng số 60,398 đơn hàng. 
Trong giai đoạn này, năm 2013 ghi nhận mức doanh thu cao nhất. Xét theo mùa vụ, các tháng 
có doanh thu cao nhất trong từng năm thường rơi vào nửa cuối năm, cho thấy nhu cầu mua hàng 
có xu hướng tăng mạnh vào giai đoạn cuối năm.

Tuy nhiên, cần lưu ý rằng dữ liệu chỉ trải dài từ tháng 12/2010 đến tháng 01/2014, do đó 
các năm 2010 và 2014 chưa có dữ liệu đầy đủ, có thể ảnh hưởng đến tính chính xác khi so sánh 
theo năm.

Doanh thu năm 2012 giảm từ 7,08 triệu USD xuống 5,84 triệu USD, tương ứng giảm 17,43% so với năm 2011.
Sang năm 2013, doanh thu tăng mạnh lên 16,35 triệu USD, tương ứng tăng 179,87% so với năm 2012.
Điều này cho thấy doanh nghiệp đã trải qua giai đoạn suy giảm trong năm 2012 nhưng phục hồi rất mạnh 
trong năm 2013, với doanh thu gần gấp 3 lần năm trước.

Về cơ cấu sản phẩm, các mặt hàng có doanh thu cao nhất chủ yếu thuộc dòng Mountain-200 Black & Silver 
và Road-150 Red. Đây là các sản phẩm có hiệu suất bán hàng tốt, do đó doanh nghiệp có thể cân nhắc 
tập trung đẩy mạnh sản xuất và chiến lược marketing cho các dòng sản phẩm này.

US, Australia là 2 khu vực có doanh thu cao nhất trong toàn bộ thị trường, đều chiếm hơn 30% so với tổng 
doanh thu, cho thấy đây là thị trường trọng điểm của doanh nghiệp và cần tiếp tục được ưu tiên đầu tư để 
duy trì tăng trưởng doanh thu.*/

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

-->> Insights: 
/*Từ kết quả phân tích, có thể xác định được nhóm khách hàng  mang lại doanh thu cao nhất 
cho doanh nghiệp. Đây là nhóm khách hàng có giá trị lớn, đóng góp đáng kể vào tổng doanh thu, 
do đó cần được ưu tiên trong các hoạt động chăm sóc khách hàng, chương trình khách hàng thân thiết 
và các chiến dịch giữ chân khách hàng.

Phân tích Retention Rate cho thấy khả năng duy trì khách hàng của doanh nghiệp qua các giai đoạn. 
Chỉ số này giúp đánh giá mức độ trung thành của khách hàng và hiệu quả của các chiến lược chăm sóc 
khách hàng hiện tại.

Kết hợp mô hình RFM và Customer Lifetime Value (CLV) cho thấy nhóm khách hàng thuộc phân khúc Champions 
có giá trị vòng đời cao, tần suất mua hàng lớn và vẫn duy trì giao dịch gần đây (tính từ cuối thời điểm 
của data). Đây là nhóm khách hàng quan trọng nhất cần được ưu tiên giữ chân nhằm tối đa hóa doanh thu dài hạn.

Bên cạnh đó, nhóm Loyal Customers cũng sở hữu CLV tương đối cao và có hành vi mua hàng ổn định. Doanh nghiệp 
có thể triển khai các chiến lược Upselling và Cross-selling để gia tăng giá trị đơn hàng, đồng thời nâng cao 
doanh thu từ nhóm khách hàng này.*/


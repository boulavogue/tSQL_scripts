CREATE TABLE #t1
(  OrderID int 
,CustID int 
,SellDate [varchar](11) 
,Product [varchar](5)
,BarCode [varchar](5)
,Price int
);

Insert Into #t1
(OrderID,CustID,SellDate,Product,BarCode,Price)
VALUES
(1,100,'2013-08-20','Itm1','BarC1',50),   
(1,100,'2013-08-20','Itm2','BarC2',75),   
(2,200,'2013-08-20','Itm1','BarC1',50),   
(2,200,'2013-08-20','Itm2','BarC2',75),   
(2,200,'2013-08-20','Itm3','BarC3',80),   
(3,100,'2013-08-21','Itm3','BarC3',80);   


/* Lets take a look at the data */
--Select * from #t1;

DECLARE @SQL VARCHAR(MAX); 
DECLARE @Columns VARCHAR(MAX); 

Select @Columns = 
COALESCE(@Columns +',','') + QUOTENAME(SellDate) 
FROM 
(
SELECT DISTINCT SellDate 
FROM #t1
)b
Order by b.SellDate

SET @SQL = '
WITH PivotData AS 
(
	SELECT
	CustID 
	,Product
	,SellDate
	,Price 
	FROM #t1 
)

SELECT 
CustID
,Product
,' + @Columns + '
FROM PivotData 
 PIVOT
(
	SUM(Price) 
	FOR SellDate 
	IN (' + @Columns + ')
) AS PivotResult
ORDER BY CustID,Product' 

--PRINT @SQL
EXEC (@SQL)

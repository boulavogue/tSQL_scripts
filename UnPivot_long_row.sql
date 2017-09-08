/* 
https://www.mssqltips.com/sqlservertip/3002/use-sql-servers-unpivot-operator-to-dynamically-normalize-output/
*/

CREATE TABLE #t
(  OrderID int 
,CustID int 
,SellDate [nchar](11) 
,Product1 [nchar](5)
,Product2 [nchar](5)
,Product3 [nchar](5)
,BarCode1 [nchar](5)
,BarCode2 [nchar](5)
,BarCode3 [nchar](5)
,Price1 [nchar](5)
,Price2 [nchar](5)
,Price3 [nchar](5)
);

Insert Into #t
Values
(1,100,'2013-08-20','Itm1','Itm2','','BarC1','BarC2','','50','75','')
,(2,200,'2013-08-20','Itm1','Itm2','Itm3','BarC1','BarC2','BarC3','50','75','80')
,(3,100,'2013-08-21','Itm3','','','BarC3','','','80','','');

/* Lets take a look at the data */
--Select * from #t;

SELECT OrderID, Product, BarCode, Price
FROM 
(
SELECT OrderID, Product, BarCode, Price,
iCnt = SUBSTRING(Products, LEN(Products) - PATINDEX('%[^0-9]%', REVERSE(Products)) + 2, 32),
bCnt = SUBSTRING(BarCodes, LEN(BarCodes) - PATINDEX('%[^0-9]%', REVERSE(BarCodes)) + 2, 32),
pCnt = SUBSTRING(Prices, LEN(Prices) - PATINDEX('%[^0-9]%', REVERSE(Prices)) + 2, 32)
FROM
(
SELECT OrderID, Product1, Product2, Product3, BarCode1, BarCode2, BarCode3, Price1, Price2, Price3
FROM #t
) AS cp
UNPIVOT 
(
Product FOR Products IN ( Product1, Product2, Product3)
) AS i
UNPIVOT
(
BarCode FOR BarCodes IN ( BarCode1, BarCode2, BarCode3)
) AS b
UNPIVOT
(
Price FOR Prices IN ( Price1, Price2, Price3)
) AS p
) AS x
WHERE iCnt = bCnt
AND   iCnt = pCnt
AND LEN(Product)>0;

drop table #t

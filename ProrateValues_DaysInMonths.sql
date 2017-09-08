/* 
Use case:
- A large contract over a number of months effort will be invoiced in one installment
- However finance wish to prorate this value over the number days per month and disply as monthly sum
- Assume invoice at the end of each month, except the final month where we invoice on "FinalDate"
*/

CREATE TABLE #t
(  OrderID int 
,StartDate [nchar](11) 
,FinalDate [nchar](11)
,Amount decimal(18,4)
);

Insert Into #t
Values
(1,'2013-08-20','2013-08-20',2134.57)
,(2,'2013-08-20','2013-09-03',90658.69)
,(3,'2013-08-21','2014-02-26',126940.42);

/* Lets take a look at the data */
--Select * from #t;

With cte (datelist, maxdate) as(
Select distinct
EOMONTH(StartDate) as datelist
,EOMONTH(FinalDate) as maxdate
from #t
union all
    select EOMONTH(dateadd(m, 1, datelist)), maxdate
    from cte
    where datelist <= maxdate
)

, dataframe as (
select  distinct 
 t.OrderID
,(SELECT MAX(x) FROM (VALUES (DateAdd(Day,1,EOMONTH(datelist,-1))),(t.StartDate)) AS value(x)) as FromInvoiceDate
,(SELECT MIN(x) FROM (VALUES (datelist),(t.FinalDate)) AS value(x)) as ToInvoiceDate
,CAST(
	DateDiff(Day,
				(SELECT MAX(x) FROM (VALUES (EOMONTH(datelist,-1)),(t.StartDate)) AS value(x)) /* as FromInvoiceDate */
				,(SELECT MIN(x) FROM (VALUES (datelist),(t.FinalDate)) AS value(x)) /* as ToInvoiceDate */
	        ) 
	as decimal(18,4)) as DaysToInvoice
,DateDiff(Day,t.StartDate,t.FinalDate) as Days
                from cte d
left join #t t on EOMONTH(d.datelist) between EOMONTH(t.StartDate) and EOMONTH(t.FinalDate)
Where OrderID IS NOT NULL
)

Select 
df.OrderID
,df.FromInvoiceDate
,df.ToInvoiceDate
,ROUND(t.Amount *
				(SELECT MAX(x) FROM (VALUES (df.DaysToInvoice),(1)) AS value(x))
				/
				(SELECT MAX(x) FROM (VALUES (df.Days),(1)) AS value(x))
,2) as ProRate
from Dataframe df
JOIN #t t ON df.OrderID=t.OrderID


drop table #t

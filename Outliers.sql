/* https://www.anexinet.com/blog/finding-outliers-using-t-sql/ */

Create table #SetWithOutliers (Amount int);
Insert into #SetWithOutliers values (1),(3),(3),(5),(6),(8),(9),(15),(46);

Declare @MajorLowerOutlier int;
Declare @MinorLowerOutlier int;
Declare @SecondQuartile int;
Declare @MinorUpperOutlier int;
Declare @MajorUpperOutlier int;

       SELECT
              @MajorLowerOutlier = (max(FirstQuartile) - (max(ThirdQuartile) - max(FirstQuartile)) * 1.5)
			 ,@MinorLowerOutlier = MAX(SecondQuartile) - (max(ThirdQuartile) - max(FirstQuartile))
			 ,@SecondQuartile = MAX(SecondQuartile)
			 ,@MinorUpperOutlier = MAX(SecondQuartile) + (max(ThirdQuartile) - max(FirstQuartile))
			 ,@MajorUpperOutlier = (max(ThirdQuartile) - max(FirstQuartile)) * 1.5 + max(ThirdQuartile)
       FROM
              (
              SELECT
                     percentile_disc(0.75) within group (order by Amount) over() as ThirdQuartile,
					 percentile_disc(0.50) within group (order by Amount) over() as SecondQuartile,
                     percentile_disc(0.25) within group (order by Amount) over() as FirstQuartile
              FROM #SetWithOutliers
       ) quartiles
	   
SELECT amount as Outliers
,@MajorLowerOutlier as MajorOutlier_Lower
,@MinorLowerOutlier	as LowerInterquartileRange
,@SecondQuartile as SecondQuartile 
,@MinorUpperOutlier	as UpperInterquartileRange
,@MajorUpperOutlier as MajorOutlier_Upper
FROM #SetWithOutliers 
WHERE amount NOT BETWEEN @MajorLowerOutlier AND @MajorUpperOutlier;
DROP TABLE #SetWithOutliers;
GO

CREATE TABLE #t
(State [varchar](20)
,Region [varchar](20)
,ZipFrom int
,ZipTo int
);
/* list from "australia wide postcode breakdown - Prospect Shop" */
Insert Into #t
Values
('ACT','Metro'			,2600,	2601),
('ACT','Metro'			,2610,	NULL),
('ACT','Metro'			,2600,	2609),
('ACT','Regional'		,2610,	2620),
('NSW','Metro'				,1100,	1299),
('NSW','Metro'				,2000,	2001),
('NSW','Metro'				,2007,	NULL),
('NSW','Metro'				,2009,	NULL),
('NSW','Metro'				,2000,	2234), 
('NSW','Regional'			,2235,	2999),
('NSW','Regional'			,2640,	2660),
('NSW','Regional'			,2500,	2534),
('NSW','Regional'			,2265,	2333),
('NSW','Regional'			,2413,	2484),
('NSW','Regional'			,2460,	2465),
('NSW','Regional'			,2450, NULL),
('VIC','Metro'			,3000,	3006),
('VIC','Metro'			,3205, NULL),
('VIC','Metro'			,8000,	8399),
('VIC','Metro'			,3000,	3207),
('VIC','Regional'		,3208,	3999),
('QLD','Metro'			,4000,	4001),
('QLD','Metro'			,4003, NULL),
('QLD','Metro'			,9000,	9015),
('QLD','Metro'			,4000,	4207),
('QLD','Metro'			,4300,	4305),
('QLD','Metro'			,4500,	4519),
('QLD','Regional'		,4208,	4299),
('QLD','Regional'		,4306,	4499),
('QLD','Regional'		,4520,	4999),
('QLD','Metro'			,4208,	4287), 
('QLD','Regional'		,4550,	4575),
('SA','Metro'			,5000,	5001),
('SA','Metro'			,5004,	5005),
('SA','Metro'			,5810, NULL),
('SA','Metro'			,5839, NULL),
('SA','Metro'			,5880,	5889),
('SA','Metro'			,5000,	5199),
('SA','Regional'		,5200,	5749),
('SA','Regional'		,5825,	5854),
('WA','Metro'				,6000,	6001),
('WA','Metro'				,6004, NULL),
('WA','Metro'				,6827, NULL),
('WA','Metro'				,6830,	6832),
('WA','Metro'				,6837,	6849),
('WA','Metro'				,6000,	6199),
('WA','Regional'			,6200,	6999),
('TAS','Metro'				,7000,	7001),
('TAS','Metro'				,7000,	7099),
('TAS','Regional'			,7100,	7999),
('NT','Metro' 			,0800,	0832),
('NT','Regional'			,0833,	0899);

/* Testing
Select * from #t
*/

With cte (State, Region, ZipFrom,ZipTo) as(
Select distinct
State
,Region
,ZipFrom
,ZipTo as ZipTo
from #t
Where ZipTo IS NOT NULL
union all
    select
	State
	,Region
	,ZipFrom+1 as ZipFrom
	,ZipTo
    from cte
    where ZipFrom < ZipTo
),t2 as (
Select distinct 
  State
  ,Region
 ,ZipFrom
 ,Row_NUMBER()OVER(Partition by ZipFrom Order by ZipFrom,Region) as Flag
from cte
)
Select 
ZipFrom as Zip
,State
,Region
from t2 
where Flag =1
UNION
Select 
ZipFrom as Zip
,State
,Region
from #t 
Where ZipTo IS NULL
Order by State,Zip
option ( MaxRecursion 0 )
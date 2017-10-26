Declare @today varchar(10);
Declare @Yesterday varchar(10);
Declare @LastBusinessDay varchar(10);

Set @today = convert(varchar(10),  getdate() ,112);
Set @Yesterday =convert(varchar(10),  DATEADD(dd,-1, getdate()) ,112);

SET @LastBusinessDay = convert(varchar(10),  DATEADD(DAY, CASE (DATEPART(WEEKDAY, getdate()) + @@DATEFIRST) % 7 
                        WHEN 1 THEN -2 
                        WHEN 2 THEN -3 
                        ELSE -1 
                    END, DATEDIFF(DAY, 0, getdate())) ,112);

Select @today,@Yesterday,@LastBusinessDay

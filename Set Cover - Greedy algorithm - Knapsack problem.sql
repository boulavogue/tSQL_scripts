	
/***
Credit to peter.petrov on StackOverflow
https://stackoverflow.com/questions/28202429/dynamic-t-sql-approach-for-combinatorics-knapsack

Use Case:
Let's say you are in a hardware store and need to buy 21 screws. They only offer them in bags:

Bag X - 16 Screws - 1.56$ per screw - 25$ Total
Bag Y - 8 Screws - 2.00$ per screw - 14$ Total
Bag Z - 4 Screws - 1.75$ per screw - 7$ Total
Now you have to figure out which Bags you should buy to get your 21 screws (or more!) for the lowest possible price.
***/

-- use TEST;

declare @limit decimal(19,4);
set @limit = 1000;

declare @ReqQty int;
set @ReqQty = 21;

create table #bags
(
    id int primary key,
    qty int,
    price decimal(19,4),
    unit_price decimal(19,4),
    w int, -- weight
    v decimal(19,4), -- value
    reqAmount int,
    CONSTRAINT UNQ_qty UNIQUE(qty) 
);

insert into #bags(id, qty, price) 
values
 (10, 16, 25.00)
,(20, 7, 14.00)
,(30, 4, 7.00);


update #bags set unit_price = price / ( 1.0 * qty );

update #bags set w = qty;
update #bags set v = -price;

update #bags set reqAmount = 0;

-- Uncomment the next line when debugging!
-- select * From #bags;

create table #m(w int primary key, m int, prev_w int);
declare @w int;
set @w = 0;
while (@w<=@limit)
begin
    insert into #m(w) values (@w);
    set @w = @w + 1;
end;

update #m
set m = 0;

set @w = 1;

declare @x decimal(19,4);
declare @y decimal(19,4);

    update m1
    set
    m1.m = 0 
    from #m m1
    where m1.w = 0;

while (@w<=@limit)
begin
    select 
        @x = max(b.v + m2.m) 
    from #m m1 
    join #bags b on m1.w >= b.w and m1.w = @w
    join #m m2 on m2.w = m1.w-b.w;

    select @y = min(m22.w) 
    from #m m11 
    join #bags bb on m11.w >= bb.w and m11.w = @w
    join #m m22 on m22.w = m11.w-bb.w
    where (bb.v + m22.m) = ( @x );

    update m1
    set m1.m = @x,
        m1.prev_w = @y
    from #m m1
    where m1.w = @w;

    set @w = @w + 1;
end;

-- Uncomment the next line when debugging!
-- select * from #m;

declare @z int;
set @z = -1;

select 
      @x = -m1.m, 
      @y = m1.w ,
      @z = m1.prev_w
from #m m1
where m1.w =  
(  select top 1 best.w 
   from ( select m1.m, max(m1.w) as w
          from 
          #m m1
          where
          m1.m is not null
          group by m1.m) best 
   where best.w >= @ReqQty and best.w < 2 * @ReqQty
   order by best.m desc
)


-- Uncomment the next line when debugging!
-- select * From #m m1 where m1.w = @y;

while (@y > 0)
begin
    update #bags
    set reqAmount = reqAmount + 1
    where
    qty = @y-@z;

    select 
          @x = -m1.m, 
          @y = m1.w ,
          @z = m1.prev_w
    from #m m1
    where m1.w = @z;
end;

select * from #bags;

select sum(price * reqAmount) as best_price
from #bags;

drop table #bags;
drop table #m;

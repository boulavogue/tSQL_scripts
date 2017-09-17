/*
Use case:
How can I write a query that can select all orders that are at least % similar to a specific order?  (Order #4 and 75% used in this example)

Approach:
Jaccard index, also known as Intersection over Union:
- The two orders (specified order & potential matching order) must have at least one item in common
- The number of items in an order that it has in common with the specified order. 
- The number of items in each order.

To meet an 85% Jaccard Similarity criterion, if the number of items in either order is less than some threshold, the orders must be identical. 
For example, if both orders A and B have 5 items, say, but there's one item different between the two, 
it gives you 4 items in common (|A∩B|) and 6 items in total (|A∪B|), so the Jaccard Similarity J(A,B) is only 66.666%.

*/

IF OBJECT_ID('tempdb.dbo.#Order', 'U') IS NOT NULL DROP TABLE #Order; 
IF OBJECT_ID('tempdb.dbo.#Item', 'U') IS NOT NULL DROP TABLE #Item; 
IF OBJECT_ID('tempdb.dbo.#OrderItem', 'U') IS NOT NULL DROP TABLE #OrderItem; 

CREATE TABLE #Order (ID INTEGER NOT NULL PRIMARY KEY);
CREATE TABLE #Item  (ID INTEGER NOT NULL PRIMARY KEY);
CREATE TABLE #OrderItem
(
    OrderID INTEGER NOT NULL,
    ItemID INTEGER NOT NULL,
    Quantity DECIMAL(8,2) NOT NULL
);

INSERT INTO #Order (ID) VALUES (1),(2),(3),(4),(5),(6),(7);
INSERT INTO #Item (ID) VALUES (111),(222),(333),(444),(555),(666),(777),(888),(999);
INSERT INTO #OrderItem (OrderID, ItemID, Quantity) 
VALUES	 (1, 111, 1),(1, 222, 1),(1, 333, 1),(1, 555, 1)
		,(2, 111, 1),(2, 222, 1),(2, 333, 1),(2, 555, 1)
		,(3, 111, 1),(3, 222, 1),(3, 333, 1),(3, 444, 1),(3, 555, 1),(3, 666, 1)
		,(4, 111, 1),(4, 222, 1),(4, 333, 1),(4, 444, 1),(4, 555, 1),(4, 777, 1)
		,(5, 111, 1),(5, 222, 1),(5, 333, 1),(5, 444, 1),(5, 555, 1),(5, 777, 1),(5, 999, 1)
		,(6, 111, 1),(6, 222, 1),(6, 333, 1),(6, 444, 1),(6, 555, 1),(6, 777, 1),(6, 888, 1),(6, 999, 1)
		,(7, 111, 1),(7, 222, 1),(7, 333, 1),(7, 444, 1),(7, 555, 1),(7, 777, 1),(7, 888, 1),(7, 999, 1),(7, 666, 1);

WITH SO AS (SELECT OrderID AS ID, COUNT(*) AS NA       -- Specified Order (SO)
              FROM #OrderItem
             WHERE OrderID = 4 /*** Specify order ID ***/
             GROUP BY OrderID
           ),
     OO AS (SELECT OI.OrderID AS ID, COUNT(*) AS NB    -- Other orders (OO)
              FROM #OrderItem AS OI
              JOIN SO ON OI.OrderID != SO.ID
             GROUP BY OI.OrderID
           ),
     CI AS (SELECT I1.OrderID AS ID, COUNT(*) AS NC    -- Common Items (CI)
              FROM #OrderItem AS I1
              JOIN SO AS S1 ON I1.OrderID != S1.ID
              JOIN #OrderItem AS I2 ON I2.ItemID = I1.ItemID
              JOIN SO AS S2 ON I2.OrderID  = S2.ID
             GROUP BY I1.OrderID
           )
SELECT OrderID_1, NS, OrderID_2, NL, NC,
        CAST(NC AS NUMERIC) / CAST(NL + NS - NC AS NUMERIC) AS Similarity
  FROM (SELECT v1.ID AS OrderID_1, v1.NA AS NS, v2.ID AS OrderID_2, v2.NB AS NL, v3.NC AS NC
          FROM SO AS v1
          JOIN OO AS v2 ON v1.NA <= v2.NB
          JOIN CI AS v3 ON v3.ID  = v2.ID
        UNION
        SELECT v2.ID AS OrderID_1, v2.NB AS NS, v1.ID AS OrderID_2, v1.NA AS NL, v3.NC AS NC
          FROM SO AS v1
          JOIN OO AS v2 ON v1.NA  > v2.NB
          JOIN CI AS v3 ON v3.ID  = v1.ID
       ) AS u
 WHERE CAST(NC AS NUMERIC) / CAST(NL + NS - NC AS NUMERIC) >= 0.75 -- F

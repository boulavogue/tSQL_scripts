/* script altered from Jonathan Kehayias great explanation on https://www.sqlskills.com/blogs/jonathan/finding-key-lookups-inside-the-plan-cache/ 
at time of writing the site was accessed via cache https://webcache.googleusercontent.com/search?q=cache:2Ip3Rlpfg3YJ:https://www.sqlskills.com/blogs/jonathan/finding-key-lookups-inside-the-plan-cache/+&cd=1&hl=en&ct=clnk&gl=au
*/ 

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

WITH XMLNAMESPACES(
   DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'
   )
,tab as (
	SELECT plan_handle, query_plan, name
        FROM (  SELECT DISTINCT plan_handle
                FROM sys.dm_exec_query_stats WITH(NOLOCK)) AS qs
        OUTER APPLY sys.dm_exec_query_plan(qs.plan_handle) tp
		LEFT JOIN sys.objects AS OBJ ON tp.objectid  = OBJ.object_id
		-- Where obj.name = /*stored proc name*/ 
      ) 
SELECT
    n.value('(@StatementText)[1]', 'VARCHAR(4000)') AS sql_text,
    n.query('.'),
    i.value('(@PhysicalOp)[1]', 'VARCHAR(128)') AS PhysicalOp,
	i.value('(./TableScan/Object/@IndexKind)[1]', 'VARCHAR(128)') as SearchKind,
    i.value('(./IndexScan/Object/@Database)[1]', 'VARCHAR(128)') AS DatabaseName,
    i.value('(./IndexScan/Object/@Schema)[1]', 'VARCHAR(128)') AS SchemaName,
    i.value('(./IndexScan/Object/@Table)[1]', 'VARCHAR(128)') AS TableName,
    i.value('(./IndexScan/Object/@Index)[1]', 'VARCHAR(128)') as IndexName,
    i.query('.'),
    STUFF((SELECT DISTINCT ', ' + cg.value('(@Column)[1]', 'VARCHAR(128)')
       FROM i.nodes('./OutputList/ColumnReference') AS t(cg)
       FOR  XML PATH('')),1,2,'') AS output_columns,
    STUFF((SELECT DISTINCT ', ' + cg.value('(@Column)[1]', 'VARCHAR(128)')
       FROM i.nodes('./IndexScan/SeekPredicates/SeekPredicateNew//ColumnReference') AS t(cg)
       FOR  XML PATH('')),1,2,'') AS seek_columns,
    i.value('(./IndexScan/Predicate/ScalarOperator/@ScalarString)[1]', 'VARCHAR(4000)') as Predicate,
	cp.usecounts,
    query_plan
	,name
FROM tab
INNER JOIN sys.dm_exec_cached_plans AS cp 
    ON tab.plan_handle = cp.plan_handle
CROSS APPLY query_plan.nodes('/ShowPlanXML/BatchSequence/Batch/Statements/*') AS q(n)
CROSS APPLY n.nodes('.//RelOp[IndexScan[@Lookup="1"] and IndexScan/Object[@Schema!="[sys]"]]') as s(i)

UNION ALL

SELECT
    n.value('(@StatementText)[1]', 'VARCHAR(4000)') AS sql_text,
    n.query('.'),
    i.value('(@PhysicalOp)[1]', 'VARCHAR(128)') AS PhysicalOp,
	i.value('(./TableScan/Object/@IndexKind)[1]', 'VARCHAR(128)') as SearchKind,
    i.value('(./TableScan/Object/@Database)[1]', 'VARCHAR(128)') AS DatabaseName,
    i.value('(./TableScan/Object/@Schema)[1]', 'VARCHAR(128)') AS SchemaName,
    i.value('(./TableScan/Object/@Table)[1]', 'VARCHAR(128)') AS TableName,
    i.value('(./TableScan/Object/@Index)[1]', 'VARCHAR(128)') as IndexName,
    i.query('.'),
    STUFF((SELECT DISTINCT ', ' + cg.value('(@Column)[1]', 'VARCHAR(128)')
       FROM i.nodes('./OutputList/ColumnReference') AS t(cg)
       FOR  XML PATH('')),1,2,'') AS output_columns,
    STUFF((SELECT DISTINCT ', ' + cg.value('(@Column)[1]', 'VARCHAR(128)')
       FROM i.nodes('./TableScan/SeekPredicates/SeekPredicateNew//ColumnReference') AS t(cg)
       FOR  XML PATH('')),1,2,'') AS seek_columns,
    i.value('(./TableScan/Predicate/ScalarOperator/@ScalarString)[1]', 'VARCHAR(4000)') as Predicate,
	cp.usecounts,
    query_plan
	,name
FROM tab
INNER JOIN sys.dm_exec_cached_plans AS cp 
    ON tab.plan_handle = cp.plan_handle
CROSS APPLY query_plan.nodes('/ShowPlanXML/BatchSequence/Batch/Statements/*') AS q(n)
CROSS APPLY n.nodes('.//RelOp[TableScan/Object[@Schema != "[sys]" ]]') as s(i)
OPTION(RECOMPILE, MAXDOP 1);
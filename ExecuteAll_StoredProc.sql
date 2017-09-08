/* EXECUTES ALL STORED PROCEDURES */
USE [DatabaseName]
declare @SQL nvarchar(max)

SELECT @SQL = STUFF((SELECT '; EXEC ' + quotename(SPECIFIC_SCHEMA) + '.' + quotename(SPECIFIC_NAME) 
FROM INFORMATION_SCHEMA.Routines WHERE Routine_Type = 'Procedure'
--AND Routine_Name NOT LIKE '%_old'
FOR XML PATH('')),1,2,'')

PRINT @SQL
/* Careful now, uncommenting the next line will execute the script */
--EXECUTE (@SQL)

/* DROPS ALL TABLES */
USE [DatabaseName]
declare @SQL nvarchar(max)

SELECT @SQL = STUFF((SELECT ', ' + quotename(TABLE_SCHEMA) + '.' + quotename(TABLE_NAME) 
FROM INFORMATION_SCHEMA.TABLES 
/* I really recomend you use a condition in the Where clause */
WHERE Table_Name LIKE 'TEST_%'
FOR XML PATH('')),1,2,'')

SET @SQL = 'DROP TABLE ' + @SQL

PRINT @SQL
/* Careful now, uncommenting the next line will execute the script */
--EXECUTE (@SQL)

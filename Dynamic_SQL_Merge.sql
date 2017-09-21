/***
Credit http://www.sqlservercentral.com/articles/T-SQL/66066/

***/

--USE [DB_name]
--GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-------------------------------------------------------------------------------------------------------------------------------
-- Procedure Name: usp_merge
-- Author: Glen Schwickerath
-- Date Created: 02/05/2009
-- Purpose: Stored procedure to utilize SQL Server 2008 MERGE statement. This stored procedure will
-- dynamically generate the required MERGE SQL statement and execute it.
--
-- This procedure is open source and free. The author is not responsible for any use, misuse,
-- or system errors which occur as a result of utilizing this code.
--
-- This code is provide freely to the reader. If you find usp_merge a useful, time-saving tool, 
-- please contribute $10 to your local food bank.
--
-- Parameters: @SrcServer Link server for iSeries or SQL Server. NULL for local.
-- @SrcDatabase Source database.
-- @SrcSchema Source schema. Default to "dbo".
-- @SrcTable Source table
-- @SrcColumn = Join on this column. Default to PK
-- @SrcType Source server type. "LINK" (SQL Server Link), or "SQL" (default)
-- @TgtDatabase Target database
-- @TgtSchema Target schema Default to "dbo".
-- @TgtTable Target table. If NULL, default to @SrcTable.
-- @WhereClause Where clause to subset data merged. If left empty->entire table is merged.
-- @Debug Displays debugging information. "Y" or "N" (default)
-- @OutputPK Output key values and operations performed. "Y" or "N" (Default)
-- @ParseOnly Generate MERGE statement but do not execute. "Y" or "N" (Default)
--
-- Example Syntax:
--
-- SQL Server->SQL Server 
-- 
-- EXEC usp_merge @SrcServer=NULL,
-- @SrcDatabase='AdventureWorks',
-- @SrcSchema='Production',
-- @SrcTable='TransactionHistory',
-- @SrcColumn = '', 
-- @SrcType='SQL',
-- @TgtDatabase='AdventureWorksCopy',
-- @TgtSchema=Production,
-- @TgtTable=NULL,
-- @WhereClause='TransactionID between 100000 and 102000',
-- @Debug='Y',
-- @OutputPK='Y', 
-- @ParseOnly = 'N'
--
-- Updates: 21/09/2017 - Boulavogue
-- @SrcColumn /* If populated join on this column, else will look for PK*/
-- Check if column has identity & turn IDENTITY_INSERT ON & OFF where approprate
--------------------------------------------------------------------------------------------------------------------------------
CREATE PROCEDURE [dbo].[usp_merge] (
 @SrcServer varchar(100),
 @SrcDatabase varchar(100),
 @SrcSchema varchar(100),
 @SrcTable varchar(100),
 @SrcColumn varchar(100),
 @SrcType varchar(100),
 @TgtDatabase varchar(100),
 @TgtSchema varchar(100),
 @TgtTable varchar(100),
 @WhereClause varchar(500),
 @Debug char(1),
 @OutputPK char(1),
 @ParseOnly char(1)
 )
as
begin

SET NOCOUNT ON
DECLARE @MergeSQL varchar(max), --Complete sql string
 @TempSQL varchar(max), --Temporary sql string
 @Str varchar(500), --Temporary results string
 @CTR int, --Temporary results counter
 @NoPK int=0 --Indicates no primary key found
 

CREATE TABLE #IdtyCols (IdtyTable varchar(100), IdtyColumn varchar(100)) 
CREATE TABLE #SrcCols (SelColumn varchar(100), SrcColumn varchar(100))
CREATE TABLE #SrcPK (SrcColumn varchar(100))

--
-- Edit input values
--
IF @SrcDatabase is null or
 @SrcTable is null or
 (@SrcServer is null and @SrcType = 'LINK') or
 (@SrcSchema is null and @SrcType = 'LINK')
 BEGIN
 RAISERROR('usp_merge: Invalid input parameters',16,1)
 RETURN -1
 END
 
IF @Debug IS NULL SELECT @Debug = 'N'
IF @OutputPK IS NULL SELECT @OutputPK = 'N'

IF @SrcColumn IS NULL 
BEGIN
Select @SrcColumn = ''
END
ELSE 
BEGIN
SELECT @TempSQL = ' select TABLE_NAME as IdtyTable, COLUMN_NAME as IdtyColumn'+
 ' from '+@SrcDatabase+'.INFORMATION_SCHEMA.COLUMNS '+
 ' where COLUMNPROPERTY(object_id(TABLE_SCHEMA+''.''+TABLE_NAME), COLUMN_NAME, ''IsIdentity'') = 1 '+
 ' and TABLE_NAME = '''+@SrcTable+''''+
 ' and TABLE_SCHEMA = '''+@SrcSchema+''''+
 ' and COLUMN_NAME = '''+@SrcColumn+''';'
END

INSERT INTO #IdtyCols exec(@TempSQL)

IF @TgtTable IS NULL SELECT @TgtTable = @SrcTable
IF @TgtSchema IS NULL SELECT @TgtSchema = 'dbo'
IF @TgtDatabase IS NULL SELECT @TgtDatabase = DB_NAME()
IF @SrcType IS NULL SELECT @SrcType = 'SQL'
IF @SrcSchema IS NULL SELECT @SrcSchema = 'dbo'
IF @ParseOnly IS NULL SELECT @ParseOnly = 'N'
IF @Debug = 'Y' 
BEGIN
SELECT @Str = 'Starting MERGE from '+@SrcDatabase+'.'+@SrcSchema+'.'+@SrcTable+' to '
 +@TgtDatabase+'.'+@TgtSchema+'.'+@TgtTable+'.'
PRINT @Str
PRINT ''
SELECT @Str = 'Where clause: '+@WhereClause
IF len(@WhereClause) > 0 PRINT @Str
PRINT ''
IF @ParseOnly = 'Y' BEGIN PRINT '@ParseOnly=''Y'' selected. Statement will not be executed.' PRINT '' END
END
 
------------------------------------------------------------------------------------------------------------------------
-- Generate MERGE statement
------------------------------------------------------------------------------------------------------------------------
 
--*********************************************************
-- Retrieve source column and primay key definitions *
--*********************************************************
IF @SrcType = 'LINK'
BEGIN
SELECT @TempSQL = ' select COLUMN_NAME as SelColumn, COLUMN_NAME as SrcColumn '+
 ' from ['+@SrcServer+'].['+@SrcDatabase+'].INFORMATION_SCHEMA.COLUMNS '+
 ' where TABLE_NAME = '''+@SrcTable+''''+
 ' and TABLE_SCHEMA = '''+@SrcSchema+''''
IF @Debug = 'Y' PRINT 'Retrieving column information from SQL Linked Server...'
END
ELSE
BEGIN
SELECT @TempSQL = ' select COLUMN_NAME as SelColumn, COLUMN_NAME as SrcColumn '+
 ' from '+@SrcDatabase+'.INFORMATION_SCHEMA.COLUMNS '+
 ' where TABLE_NAME = '''+@SrcTable+''''+
 ' and TABLE_SCHEMA = '''+@SrcSchema+''''
IF @Debug = 'Y' PRINT 'Retrieving column information from SQL Server...'
END
INSERT INTO #SrcCols exec(@TempSQL)
IF @Debug = 'Y' PRINT ''
-- Check for columns
IF NOT EXISTS (SELECT 1 FROM #SrcCols)
BEGIN
SELECT @Str = 'No column information found for table '+@SrcTable+'. Exiting...'
IF @Debug = 'Y' PRINT @Str
SELECT @Str = 'usp_merge: '+@Str
RAISERROR(@Str,16,1)
RETURN -1
END
IF @Debug = 'Y'
BEGIN
SELECT @Str = 'Source table columns: '
SELECT @Str = @Str + SrcColumn + ',' from #SrcCols
SELECT @Str = SUBSTRING(@Str,1,len(@Str)-1)
PRINT @Str
PRINT ''
END

-- Use specified fields for joins where available  
IF @SrcColumn > ''
BEGIN
SELECT @TempSQL = 'select '''+@SrcColumn+''' as SrcColumn;'  
IF @Debug = 'Y' PRINT 'Retrieving SrcColumn provided when stored proc was called...'
END
ELSE 
-- Retrieve primary keys
IF @SrcType = 'LINK'
BEGIN
SELECT @TempSQL = ' select b.COLUMN_NAME as SrcColumn from ['+@SrcDatabase+'].information_schema.TABLE_CONSTRAINTS a '+
 ' JOIN ['+@SrcServer+'].['+@SrcDatabase+'].information_schema.CONSTRAINT_COLUMN_USAGE b on a.CONSTRAINT_NAME=b.CONSTRAINT_NAME '+
 ' where a.CONSTRAINT_SCHEMA='''+@SrcSchema+''' and a.TABLE_NAME = '''+@SrcTable+''''+
 ' and a.CONSTRAINT_TYPE = ''PRIMARY KEY'''
IF @Debug = 'Y' PRINT 'Retrieving primary key information from SQL Linked Server...'
END
ELSE --@SrcType = 'SQL'
BEGIN
SELECT @TempSQL = ' select b.COLUMN_NAME as SrcColumn from ['+@SrcDatabase+'].information_schema.TABLE_CONSTRAINTS a '+
 ' JOIN ['+@SrcDatabase+'].information_schema.CONSTRAINT_COLUMN_USAGE b on a.CONSTRAINT_NAME=b.CONSTRAINT_NAME '+
 ' where a.CONSTRAINT_SCHEMA='''+@SrcSchema+''' and a.TABLE_NAME = '''+@SrcTable+''''+
 ' and a.CONSTRAINT_TYPE = ''PRIMARY KEY'''
IF @Debug = 'Y' PRINT 'Retrieving primary key information from SQL Server...'
END
INSERT INTO #SrcPK exec(@TempSQL)
 
--***************************************************************************************************************** 
-- Primary keys could not be found on source server. First try to locate primary keys on target server. If
-- they cannot be found on target server, resort to matching on every column.
--*****************************************************************************************************************
-- If we can't get the primary keys from the AS400, take them from SQL Server
 IF NOT EXISTS(SELECT 1 from #SrcPK) 
 BEGIN
 SELECT @TempSQL = ' select b.COLUMN_NAME as SrcColumn from ['+@TgtDatabase+'].information_schema.TABLE_CONSTRAINTS a '+
 ' JOIN ['+@TgtDatabase+'].information_schema.CONSTRAINT_COLUMN_USAGE b on a.CONSTRAINT_NAME=b.CONSTRAINT_NAME '+
 ' where a.CONSTRAINT_SCHEMA='''+@TgtSchema+''' and a.TABLE_NAME = '''+@TgtTable+''''+
 ' and a.CONSTRAINT_TYPE = ''PRIMARY KEY'''
 IF @Debug = 'Y' PRINT 'Could not locate primary keys from the source. Trying target server...' 
 INSERT INTO #SrcPK exec(@TempSQL)

 -- Final hack - use every column
 IF NOT EXISTS(SELECT 1 from #SrcPK) 
 BEGIN
 IF @Debug = 'Y' PRINT 'Could not locate primary keys from target server. Using all columns to match. This may be painful...'
 INSERT INTO #SrcPK SELECT SrcColumn FROM #SrcCols
 SELECT @NoPK = 1 
 END
END
IF @Debug = 'Y' AND @NoPK = 0
BEGIN
SELECT @Str = 'Primary key(s) utilized: '
SELECT @Str = @Str + SrcColumn + ',' from #SrcPK
SELECT @Str = SUBSTRING(@Str,1,len(@Str)-1)
PRINT @Str
PRINT ''
END
--***************************************************************************************************************** 
-- Step 0) Check if table has identity columns & Generate approprate merge statement 
--
-- Syntax: MERGE [Production].[TransactionHistory] T 
--*****************************************************************************************************************
IF NOT EXISTS (Select 1 from #IdtyCols)
BEGIN
SELECT @MergeSQL = ''
END
ELSE 
BEGIN
 SELECT @MergeSQL = 'SET IDENTITY_INSERT ['+@TgtDatabase+'].['+@TgtSchema+'].['+@TgtTable+'] ON; '
END
--***************************************************************************************************************** 
-- Step 1) Generate Merge statement & append
--
-- Syntax: MERGE [Production].[TransactionHistory] T 
--*****************************************************************************************************************
SELECT @MergeSQL=@MergeSQL+'MERGE ['+@TgtDatabase+'].['+@TgtSchema+'].['+@TgtTable+'] T USING ('
 
--***************************************************************************************************************** 
-- Step 2) Generate Merge statement source selection
--
-- Syntax: USING (select "all fields" 
-- from Production.TransactionHistory 
-- where TransactionID between 100000 and 102000 ') ) S 
--
--*****************************************************************************************************************
SELECT @TempSQL =''
IF @SrcType = 'LINK'
BEGIN
SELECT @TempSQL = @TempSQL + SelColumn + ',' from #SrcCols
select @TempSQL = substring(@TempSQL,1,len(@TempSQL)-1)
select @TempSQL = replace(@TempSQL,'"','''''')
select @TempSQL = ' select '+@TempSQL+' from ['+@SrcServer+'].['+@SrcDatabase+'].['+@SrcSchema+'].['+@SrcTable+'] '+
 (case when @WhereClause > '' THEN ' where '+@WhereClause else '' end)+') S '
END
ELSE -- @SrcType = 'SQL'
BEGIN
SELECT @TempSQL = @TempSQL + SelColumn + ',' from #SrcCols
select @TempSQL = substring(@TempSQL,1,len(@TempSQL)-1)
select @TempSQL = replace(@TempSQL,'"','''''')
select @TempSQL = ' select '+@TempSQL+' from ['+@SrcDatabase+'].['+@SrcSchema+'].['+@SrcTable+'] '+
 (case when @WhereClause > '' THEN ' where '+@WhereClause else '' end)+') S ' 
END
SELECT @MergeSQL=@MergeSQL+@TempSQL
 
--***************************************************************************************************************** 
-- Step 3) Join syntax between source and target using primary keys
--
-- Syntax: ON S.TransactionID = T.TransactionID
--
--*****************************************************************************************************************
IF EXISTS(Select 1 from #SrcPK)
BEGIN
SELECT @TempSQL = ' on '
SELECT @TempSQL = @TempSQL + 'S.'+SrcColumn+' = T.'+SrcColumn+' and ' from #SrcPK
SELECT @TempSQL = SUBSTRING(@TempSQL,1,len(@TempSQL)-4)
SELECT @MergeSQL = @MergeSQL+@TempSQL
END
 
--***************************************************************************************************************** 
-- Step 4) Update matching rows. If there is no PK, this statement is bypassed
--
-- Syntax: WHEN MATCHED AND 
-- "target field values" <> "source field values" THEN
-- UPDATE SET "non-key target field values" = "non-key source field values"
--
--*****************************************************************************************************************
IF @NoPK = 0
BEGIN
SELECT @TempSQL = ' WHEN MATCHED AND '
SELECT @TempSQL = @TempSQL + 'S.'+cols.SrcColumn+' <> T.'+cols.SrcColumn+' or ' 
 from #SrcCols cols
 left outer join #SrcPK PK on cols.SrcColumn=PK.SrcColumn
 where PK.SrcColumn IS NULL
SELECT @TempSQL = SUBSTRING(@TempSQL,1,len(@TempSQL)-3)
SELECT @TempSQL = @TEMPSQL+' THEN UPDATE SET '
SELECT @TempSQL = @TempSQL + 'T.'+cols.SrcColumn+' = S.'+cols.SrcColumn+',' 
 from #SrcCols cols
 left outer join #SrcPK PK on cols.SrcColumn=PK.SrcColumn
 where PK.SrcColumn IS NULL
SELECT @TempSQL = SUBSTRING(@TempSQL,1,len(@TempSQL)-1)
SELECT @MergeSQL = @MergeSQL+@TempSQL
END
--***************************************************************************************************************** 
-- Step 5) Inserting new rows
--
-- Syntax: WHEN NOT MATCHED BY TARGET THEN
-- INSERT ("target columns") 
-- VALUES ("source columns")
--
--*****************************************************************************************************************
SELECT @TempSQL = ' WHEN NOT MATCHED BY TARGET THEN INSERT ('
SELECT @TempSQL = @TempSQL+SrcColumn+',' from #SrcCols
SELECT @TempSQL = SUBSTRING(@TempSQL,1,len(@TempSQL)-1)
SELECT @TempSQL = @TempSQL+') VALUES ('
SELECT @TempSQL = @TempSQL+SrcColumn+',' from #SrcCols
SELECT @TempSQL = SUBSTRING(@TempSQL,1,len(@TempSQL)-1)
SELECT @TempSQL = @TempSQL+') '
SELECT @MergeSQL = @MergeSQL+@TempSQL
 
--***************************************************************************************************************** 
-- Step 6) Delete rows from target that do not exist in source. Utilize @WhereClause if it has been provided
--
-- Syntax: WHEN NOT MATCHED BY SOURCE AND TransactionID between 100000 and 102000 THEN DELETE
--
--*****************************************************************************************************************
--SELECT @MergeSQL = @MergeSQL+' WHEN NOT MATCHED BY SOURCE '+
-- (CASE WHEN @WhereClause > '' then ' AND '+@WhereClause else '' end)+' THEN DELETE '

--***************************************************************************************************************** 
-- Step 7) Include debugging information if @OutputPK = 'Y'
--
-- Syntax: OUTPUT $action, inserted.TransactionID as Inserted, deleted.TransactionID as Deleted; 
--
--*****************************************************************************************************************
IF @OutputPK = 'Y'
BEGIN
SELECT @TempSQL=' OUTPUT $action,'
SELECT @TempSQL=@TempSQL+'INSERTED.'+SrcColumn+' AS ['+SrcColumn+' Ins Upd],' from #SrcPK
SELECT @TempSQL=@TempSQL+'DELETED.' +SrcColumn+' AS ['+SrcColumn+' Deleted],' from #SrcPK
SELECT @TempSQL = SUBSTRING(@TempSQL,1,len(@TempSQL)-1)
SELECT @MergeSQL = @MergeSQL + @TempSQL
END
 
--***************************************************************************************************************** 
-- Step 8) MERGE statement must end with a semi-colon
--
-- Syntax: ; 
--
--*****************************************************************************************************************
SELECT @MergeSQL=@MergeSQL+';'

--***************************************************************************************************************** 
-- Step 9) If approprate Turn the IDENTITY_INSERT OFF
--
-- Syntax: MERGE [Production].[TransactionHistory] T 
--*****************************************************************************************************************
 
 IF EXISTS (Select 1 from #IdtyCols)
BEGIN
SELECT @MergeSQL=@MergeSQL+'SET IDENTITY_INSERT ['+@TgtDatabase+'].['+@TgtSchema+'].['+@TgtTable+'] OFF;'
END
 
--***************************************************************************************************************** 
-- Include other debugging information
--*****************************************************************************************************************
IF @Debug = 'Y' 
BEGIN
PRINT ''
select @STR='Length of completed merge sql statement: '+convert(varchar(10),len(@Mergesql))
print @STR
PRINT ''
PRINT 'Text of completed merge sql statement'
PRINT '-------------------------------------'
SELECT @CTR = 1
WHILE @CTR < len(@Mergesql)
 BEGIN
 SELECT @Str = substring(@MergeSQL,@CTR,200)
 PRINT @Str
 SELECT @CTR=@CTR+200
 END
PRINT ''
-- Add a rowcount
SELECT @MergeSQL = @MergeSQL + ' PRINT CONVERT(VARCHAR(10),@@ROWCOUNT) '
END

--***************************************************************************************************************** 
-- Execute MERGE statement
--***************************************************************************************************************** 
IF @ParseOnly = 'N' EXEC (@MergeSQL)
IF (@@ERROR <> 0)
 BEGIN
 RAISERROR('usp_merge: SQL execution failed',16,1)
 RETURN -1
 END
IF @Debug = 'Y' and @ParseOnly = 'N'
BEGIN
SELECT @Str = '^Number of rows affected (insert/update/delete)'
PRINT @Str
END
 
 
--***************************************************************************************************************** 
-- Cleanup
--***************************************************************************************************************** 
DROP TABLE #SrcCols
DROP TABLE #SrcPK
RETURN 0


END






GO



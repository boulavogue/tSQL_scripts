/***
Credit: http://sqlblog.com/blogs/merrill_aldrich/archive/2009/07/24/flow-control-in-t-sql-scripts.aspx

When the example runs, in SQLCMD mode, /* must be in SQLCMD mode, otherwise will error on the colon */
the first batch will not insert any rows – because of the combination of BEGIN TRANSACTION, ROLLBACK, and, importantly, RETURN. 
Without the RETURN statements, the first insert statement would be rolled back, 
but the next two would succeed as the batch continues to execute even after the error was detected. 
With the RETURN statements, the server is directed to stop immediately, with the effect 
that control seems to “skip down” to the next line after the GO statement. 
That’s an imperfect analogy, but that is roughly the effect from the client side.

Next, the combination of setting :On Error exit AND Raiserror() statements with severity 11 will cause 
SQLCMD to also stop execution of the script, which would otherwise continue at the next batch. 
This means that Batch 2 will be prevented from executing after there is an error in Batch 1
***/

:ON Error EXIT

-- Batch 1
DECLARE  @pretendError INT;

SET @pretendError = 1;

BEGIN TRANSACTION

      INSERT INTO test1 (testcolumn) VALUES ('First Row');

      IF @pretendError != 0
        BEGIN
            RAISERROR ('Something Bad Happened', 11, 1);
            ROLLBACK;
            RETURN;
        END

      INSERT INTO test1 (testcolumn) VALUES ('Second Row');

      IF @@ERROR != 0
        BEGIN
            RAISERROR ('Something Bad Happened', 11, 1);
            ROLLBACK;
            RETURN;
        END

      INSERT INTO test1 (testcolumn) VALUES ('Third Row');

      IF @@ERROR != 0
        BEGIN
            RAISERROR ('Something Bad Happened', 11, 1);
            ROLLBACK;
            RETURN;
        END

COMMIT

GO -- End of Batch 1

-- Batch 2 (Should NOT execute in case of failure in Batch 1)
PRINT 'This second batch should not run'
GO -- End of Batch 2

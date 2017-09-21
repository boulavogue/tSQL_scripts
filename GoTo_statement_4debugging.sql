/***
Credit https://stackoverflow.com/a/10005134

RAISERROR ('Raise Error does not stop processing, so we will call GOTO to skip over the script', 1, 1);
GOTO Skipper -- This will skip over the script and go to Skipper
-- CODE to SKIP
Skipper: -- Placed at the end of the script
***/

DECLARE  @RunScript bit;
SET @RunScript = 0;

IF @RunScript != 1
BEGIN
RAISERROR ('Raise Error does not stop processing, so we will call GOTO to skip over the script', 1, 1);
GOTO Skipper -- This will skip over the script and go to Skipper
END

PRINT 'This is where your working script can go';
PRINT 'This is where your working script can go';
PRINT 'This is where your working script can go';
PRINT 'This is where your working script can go';

Skipper: -- Don't do nuttin!

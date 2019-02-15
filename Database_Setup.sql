--SQL Server Setup 

/************************************************************

0.1 - SCRIPT VARIABLES

************************************************************/

SET NOCOUNT ON;

IF EXISTS (SELECT name FROM tempdb.dbo.sysobjects o where o.name LIKE '#Actions%')

BEGIN

DROP TABLE #Actions

END

CREATE TABLE #Actions 
(
    Step_ID varchar(5),
    Section_Name varchar(400),
    Value varchar(400),
    Reference_URL nvarchar(400),
    Notes nvarchar(2000)
)

DECLARE 
  @SAPwd nvarchar(128)
  ,@PartOfAG BIT
  ,@DefaultData nvarchar(1000)
  ,@DefaultLog nvarchar(1000)
  ,@DefaultBackup nvarchar(1000)
  ,@TempDBLocation nvarchar(1000)
  ,@AgentLog nvarchar(1000)
  ,@ScriptVersion varchar(5)
  ,@operator_email nvarchar(200)
  ,@operator_name nvarchar(200)
  ,@ProductVersion NVARCHAR(128)
  ,@ProductVersionMajor DECIMAL(10,2)
  ,@ProductVersionMinor DECIMAL(10,2)
  ,@MaxServerMemory varchar(10)
  ,@EnableDac INT
  ,@DatabaseName varchar(500)
  ,@DegreeOfParalelism varchar(5)
  ,@Testing BIT
  ,@CreateDB varchar(500)
  ,@OlaExists INT
  ,@OzarExists INT
  ,@AlertCnt INT = 0
  ,@CompressBackups INT
  ,@TruncateSQL nvarchar(500)
  ,@SQLVersionsRef BIT

SET @ScriptVersion = 0.1

SET @ProductVersion = CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128));

SELECT  @ProductVersionMajor = SUBSTRING(@ProductVersion, 1,CHARINDEX('.', @ProductVersion) + 1 ),
        @ProductVersionMinor = PARSENAME(CONVERT(varchar(32), @ProductVersion), 2);

/************************************************************

0.1 - INSTANCE CONFIGURATION

************************************************************/

--Would you like to run this script in test mode? I.E No changes made
--1 = yes
--0 = no
SET @Testing = 1

--This is the password for the SA account, please write it down, preferably somewhere secure.
SET @SAPwd = 'sdsadsadsaddasdasdas'

--The name you would like to use for the default "DBA" Operator
SET @operator_name = 'The DBA Team'

--Would you like to install the SQL Versions Reference table? 
SET @SQLVersionsRef = 1

--The Email address you would like to use for the "DBA" Operator
SET @operator_email = 'the.dba@test.com'

--Is this server going in an availability group? 1 yes 0 no
SET @PartOfAG = 0

--Default location for data files, leave blank to make no canges
SET @DefaultData = 'D:\'

--Default location for log files, leave blank to make no canges
SET @DefaultLog = 'L:\'

--Default location for backup files, leave blank to make no canges
SET @DefaultBackup = 'B:\'

--Default location for the SQL Agent Log, leave blank to make no canges
SET @AgentLog = 'F:\SQLAGENT.OUT'

--Set the location of where you would like TempDB to go
SET @TempDBLocation = 'T:\'

--Maximum server memory you would like to assign to this instance 
SET @MaxServerMemory = '3000'

--The Max Defree Of Paralelism you would like to assign to this instance
SET @DegreeOfParalelism = '8'

--Do you want to enable the DAC or Disable the DAC 
--1 = Enable 
--0 = Disable
SET @EnableDac = 1

--Name of the database we are going to use for DBA Related tasks and procedures.
SET @DatabaseName = 'DBA_Tasks'

--Do you want to compress your backups by default
--1 = yes
--0 = no
SET @CompressBackups = 1 

/************************************************************

0.1 - INSTANCE CONFIGURATION

************************************************************/

IF @Testing = 1 

BEGIN

	INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
	VALUES
	(0.0,'*TEST MODE*',NULL,'No Changes made to the configuration, this is a dry run')

END

INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
VALUES
(0.1,'Script Details',NULL,NULL),
(0.2,'Script Version',CAST(@ScriptVersion as varchar) ,NULL),
(0.3,'Script Author','Bonza Owl',NULL),
(0.4,'Last Updated','07/10/2018',NULL),
(0.5,'Run Date',CONVERT(varchar(20),GETDATE()),NULL),
(0.7,'Run By',SYSTEM_USER,NULL),
(1.0,'SQL Server Version',NULL,NULL),
(1.1,'Product Version',@ProductVersion,NULL),
(1.2,'Product Version Major',CAST(@ProductVersionMajor as varchar),NULL),
(1.3,'Product Version Minor',CAST(@ProductVersionMinor as varchar),NULL)

/************************************************************

0.2 - CONTENTS

************************************************************/

-- 1.0 - Alter Default File Locations
-- 1.1 - Move Temp DB Off C Drive
-- 1.2 - Disable & Update SA
-- 1.3 - Add Operator
-- 1.4 - Setup Alerts
-- 1.5 - DBA_Tasks Database Check & Creation
-- 1.6 - Schema Please

/************************************************************

1.0 - DEAULT MEMORY ALLOCATION

************************************************************/

IF @Testing = 0 

BEGIN

	EXEC sys.sp_configure N'show advanced options', N'1'  RECONFIGURE WITH OVERRIDE;

	EXEC sys.sp_configure N'max server memory (MB)', @MaxServerMemory;

	RECONFIGURE WITH OVERRIDE;

	EXEC sys.sp_configure N'show advanced options', N'0'  RECONFIGURE WITH OVERRIDE;

END

INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
VALUES
(2.0,'Max Server Memory',NULL,'These are the settings you have selected to use for this install'),
(2.1,'Max Server Memory Allocated',@MaxServerMemory,NULL)


/************************************************************

1.0 - MAX DEGRE OF PARALLELISM

 I would suggest to use the 8 as a thumb rule number. Just keep a simple formula 
 in your mind that if you have 8 or more Logical Processor in one NUMA Node (Physical Processor) 
 then use 8 as the MAXDOP settings number. If you have less than 8 Logical Processor 
 in one NUMA Node, then use that number instead. 

************************************************************/

IF @Testing = 0 

BEGIN

    IF @DegreeOfParalelism <> ' ' OR LEN(@DegreeOfParalelism) > 0

    BEGIN

		IF @Testing = 0

		BEGIN

			EXEC sys.sp_configure N'show advanced options', N'1'  RECONFIGURE WITH OVERRIDE;

			EXEC sys.sp_configure N'max degree of parallelism', @DegreeOfParalelism;

			RECONFIGURE WITH OVERRIDE;

			EXEC sys.sp_configure N'show advanced options', N'0'  RECONFIGURE WITH OVERRIDE;

		END

    END

	INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
	VALUES
	(3.0,'Max degree of parallelism',NULL,'These are the settings you have selected to use for this install'),
	(3.1,'Max degree of parallelism configured',@DegreeOfParalelism,NULL)

END

/************************************************************

1.0 - CHANGE DEFAULT FILE LOCATIONS

************************************************************/

INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
VALUES
(4.0,'Default File Locations',NULL,'These are the settings you have selected to use for this install')


    USE [master];

    IF @DefaultData IS NOT NULL OR LEN(@DefaultData) > 1 

    BEGIN

		IF @Testing = 0

		BEGIN

			EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultData', REG_SZ, @DefaultData;

		END	       

    END 

	INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
    VALUES
    (4.1,'Default Data Directory',@DefaultData,NULL)

    IF @DefaultLog IS NOT NULL OR LEN(@DefaultLog) > 1 

    BEGIN

		IF @Testing = 0

		BEGIN

			EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultLog', REG_SZ, @DefaultLog;

		END
		        
    END

    INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
    VALUES
    (4.2,'Default Log Directory',@DefaultLog,NULL)

    IF @DefaultBackup IS NOT NULL OR LEN(@DefaultBackup) > 1 

    BEGIN

		IF @Testing = 0

		BEGIN

			EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'BackupDirectory', REG_SZ, @DefaultBackup;
			
		END       

    END

    INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
    VALUES
    (4.3,'Default Backup Directory',@DefaultBackup,NULL),
	(4.4,'WARNING','Changes to default file location will require the SQL Service to be restarted for them to take effect. make sure that the dbengine service account and sql service account have permission to that new directory too.',NULL)


/************************************************************

1.0 - CHANGE DEFAULT FILE LOCATIONS

************************************************************/

IF @AgentLog <> ' ' OR LEN(@AgentLog) > 0

BEGIN

	IF @Testing = 0

	BEGIN

		USE [Msdb];

		EXEC msdb.dbo.sp_set_sqlagent_properties @errorlog_file = @AgentLog;  
		
	END  

    INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
    VALUES
    (5.0,'Default Agent Log Location',NULL,'These are the settings you have selected to use for this install'),
    (5.1,'Agent Log Directory',@AgentLog,NULL),
    (5.2,'WARNING','Changes to the Agent Log location will not take effect until the agent service is re-started, make sure that the agent service account has permission to that new directory too.',NULL)

END

/************************************************************

1.0 - ENABLE THE DAC INTERFACE
--https://www.brentozar.com/archive/2011/08/dedicated-admin-connection-why-want-when-need-how-tell-whos-using/

************************************************************/

IF @EnableDac <> ' ' OR LEN(@EnableDac) > 0

BEGIN

	IF @Testing = 0

	BEGIN

		EXEC sp_configure 'remote admin connections', @EnableDac;

		RECONFIGURE;		

	END

END

INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
VALUES
(6.0,'DAC Settings',NULL,'These are the settings you have selected to use for this install'),
(6.1,'Is the DAC enabled for this instance',CASE WHEN @EnableDac = 1 THEN 'Yes' ELSE 'No' END,NULL)

/************************************************************

1.1 - MOVE TEMP DB OFF C DRIVE
Ideally onto some fast disks. 

************************************************************/

DECLARE @MaxTempDB INT, @TempDBCnt INT, @TempDBSQL varchar(4000),@TempDBName varchar(500)

INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
VALUES
(7.0,'TempDB File Locations',NULL,'These are the settings you have selected to use for this install')

USE [master];

CREATE TABLE #TempDb
(
ID INT IDENTITY(1,1) NOT NULL,
name sysname,
type varchar(5)
)

INSERT INTO #TempDb
SELECT name, type_desc FROM sys.master_files where database_id = 2 and type_desc = 'ROWS'

SET @MaxTempDB = (SELECT MAX(ID) FROM #TempDb)
SET @TempDBCnt = 1

WHILE @TempDBCnt <= @MaxTempDB

BEGIN

SET @TempDBName = (SELECT name from #TempDb WHERE ID = @TempDBCnt)

SET @TempDBSQL = 'ALTER DATABASE [tempdb]
MODIFY FILE 
(
	name=''' + @TempDBName + ''',
    filename='''+ @TempDBLocation + @TempDBName + '.mdf' + '''
)';

IF @Testing = 0

BEGIN

EXEC(@TempDBSQL)

END

INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
VALUES
(6. + @TempDBCnt,'TempDB File Locations',NULL,@TempDBName + '.mdf' + ' has been moved to ' + @TempDBLocation )

SET @TempDBCnt = @TempDBCnt + 1

END

TRUNCATE TABLE #TempDB;

INSERT INTO #TempDb
SELECT 
	name, 
	type_desc 
FROM 
	sys.master_files 
where 
	database_id = 2 
	and type_desc = 'LOG'

SET @MaxTempDB = (SELECT MAX(ID) FROM #TempDb)
SET @TempDBCnt = 1

WHILE @TempDBCnt <= @MaxTempDB

BEGIN

SET @TempDBName = (SELECT name from #TempDb WHERE ID = @TempDBCnt)

SET @TempDBSQL = 'ALTER DATABASE [tempdb]
MODIFY FILE 
(
	name=''' + @TempDBName + ''',
    filename='''+ @TempDBLocation + @TempDBName + '.ldf' + '''
)';

IF @Testing = 0

BEGIN

EXEC(@TempDBSQL)

END;

INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
VALUES
(7.1 + @TempDBCnt,'TempDB File Locations',NULL,@TempDBName + '.ldf' + ' has been moved to ' + @TempDBLocation )

SET @TempDBCnt = @TempDBCnt + 1

END

DROP TABLE #TempDb

/************************************************************

1.2 - Disable & Update SA
We are callinh sa essey becuase they both sound the same so when
talking about it with other members of the team everyone will 
know what we are talking about

************************************************************/

DECLARE @SASQL nvarchar(MAX)

IF @SAPwd <> ' ' OR LEN(@SAPwd) > 0

BEGIN

	IF @Testing = 0 

	BEGIN

		USE [master];

		SET @SASQL = 'ALTER LOGIN [sa] WITH PASSWORD = ' + @SAPwd +''

		EXEC sp_executesql @SASQL

	END

    INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes,Reference_URL)
    VALUES
    (8.0,'SA Account Settings',NULL,'These are the settings you have selected to use for this install','https://www.mssqltips.com/sqlservertip/3695/best-practices-to-secure-the-sql-server-sa-account/'),
    (8.1,'New SA Password',@SAPwd,NULL,NULL),
    (8.2,'WARNING','Ensure the password is recorded, loosing the SA password will render the DAC useless',NULL,NULL)

END

IF @Testing = 0

BEGIN

	ALTER LOGIN [sa]
	DISABLE;

END

INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes,Reference_URL)
VALUES
(8.3,'SA Disabled','The SA account has been disabled',NULL,'https://www.brentozar.com/archive/2016/01/how-to-talk-people-out-of-the-sa-account/')    

IF @Testing = 0

BEGIN

	ALTER LOGIN [sa] WITH NAME = [essey] 

END

INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes,Reference_URL)
VALUES
(8.4,'SA Renamed','New Name essey',NULL,NULL)    

/************************************************************

1.3 - Add Operator

************************************************************/

IF NOT EXISTS (SELECT name FROM msdb.dbo.sysoperators where (name = @operator_name or email_address = @operator_email))

BEGIN

	IF @Testing = 0 

	BEGIN

		USE [msdb];

		EXEC msdb.dbo.sp_add_operator @name= @operator_name, 
				@enabled=1, 
				@pager_days=0, 
				@email_address= @operator_email

	END

    INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
    VALUES
    (9.0,'Operator Configuration',NULL,'These are the settings you have selected to use for this install'),
    (9.1,'Operator Name',@operator_name,NULL),
    (9.2,'Operator Email',@operator_email,NULL)

END

/************************************************************

1.3 - SETUP DATABASE MAIL

************************************************************/



DECLARE @Broker INT = (SELECT is_broker_enabled FROM sys.databases WHERE name = 'msdb')

DECLARE @MailXP sql_variant	 = (SELECT value_in_use FROM  sys.configurations WHERE name = 'Database Mail XPs')

IF @MailXP = 0  AND @MailXP = 0

BEGIN

	IF @Testing = 0

	BEGIN
    
		EXEC sp_configure 'show advanced options', '1';
		RECONFIGURE

		EXEC sp_configure 'Database Mail XPs', 1;
		RECONFIGURE

	END

END

INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
VALUES
(10.0,'Operator Configuration',NULL,'These are the settings you have selected to use for this install'),
(10.1,'Operator Name',@operator_name,NULL),
(10.2,'Operator Email',@operator_email,NULL),
(10.3,'WARNING','Don''t forget to add a profile and SMTP account, we can''t do that here',NULL) 

/************************************************************

1. - Setup SQL Agent Failsafe Notification Operator

************************************************************/

IF @Testing = 0 

BEGIN

    USE [msdb];
    EXEC master.dbo.sp_MSsetalertinfo @failsafeoperator= @operator_name, @notificationmethod=1;

    USE [msdb];
    EXEC msdb.dbo.sp_set_sqlagent_properties @email_save_in_sent_folder=1;

END

INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
VALUES
(11.0,'Failsafe Operator Configuration',NULL,'These are the settings you have selected to use for this install'),
(11.1,'Operator Name',@operator_name,NULL),
(11.2,'Operator Email',@operator_email,NULL),
(11.3,'WARNING','Don''t forget to add a profile and SMTP account, we can''t do that here',NULL) 

/************************************************************

1.3 - Setup SQL Versions Ref

The code used in this section was povided as part of the 
First Responder Toolkit from Brent Ozar and has been added to
this setup script. Bonza Owl does not own the copy right or 
origional code to this section of the Database Setup Script.

************************************************************/

DECLARE @TableSQL nvarchar(MAX)

IF @Testing = 0 

BEGIN

    IF @SQLVersionsRef = 1

    BEGIN

        IF EXISTS (SELECT name from msdb.sys.databases where name = @DatabaseName)

            BEGIN

                IF NOT EXISTS (SELECT NULL FROM sys.tables WHERE [name] = 'SqlServerVersions')
                
                BEGIN

                    SET @TableSQL = ''
                    

                END

                ELSE 
                
                BEGIN
                
                    SET @TruncateSQL = 'TRUNCATE TABLE ' + QUOTENAME(@DatabaseName) + '.dbo.SqlServerVersions'

                    --SET @InsertSQL = ''                    

                    --EXEC sp_ExecuteSQL @InsertSQL

                END

            END

        ELSE 

            BEGIN

				SET @CreateDB = 'CREATE DATABASE ' + QUOTENAME(@DatabaseName) + ''

				EXEC sp_executesql @CreateDB

				--SET @InsertSQL = ''                    

				--EXEC sp_ExecuteSQL @InsertSQL

            END

    END

END


/************************************************************

1.3 - Setup Alerts

************************************************************/

INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
VALUES
(12.0,'System Wide Alerts',NULL,'These are the settings you have selected to use for this install')

    IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name  = 'Severity 016')

    BEGIN

		IF @Testing = 0

		BEGIN

        USE [msdb];
        EXEC msdb.dbo.sp_add_alert @name=N'Severity 016',
        @message_id=0,
        @severity=16,
        @enabled=1,
        @delay_between_responses=60,
        @include_event_description_in=1,
        @job_id=N'00000000-0000-0000-0000-000000000000';

        EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 016', @operator_name=N'The DBA Team', @notification_method = 7;

		END

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes,Reference_URL)
        VALUES
        (12.1,'Severity 016',NULL,'Severity 16 Installed', 'https://docs.microsoft.com/en-us/sql/relational-databases/errors-events/database-engine-error-severities?view=sql-server-2017')

        SET @AlertCnt = 1

    END

	ELSE 

	BEGIN

		INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (12.2,'Severity 017',NULL,'Severity 16 Already Exists')

	END

    IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name  = 'Severity 017')

    BEGIN

		IF @Testing = 0

		BEGIN

			EXEC msdb.dbo.sp_add_alert @name=N'Severity 017',
			@message_id=0,
			@severity=17,
			@enabled=1,
			@delay_between_responses=60,
			@include_event_description_in=1,
			@job_id=N'00000000-0000-0000-0000-000000000000';

			EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 017', @operator_name=N'The DBA Team', @notification_method = 7;

		END

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes,Reference_URL)
        VALUES
        (12.2,'Severity 017',NULL,'Severity 17 Installed', 'https://docs.microsoft.com/en-us/sql/relational-databases/errors-events/database-engine-error-severities?view=sql-server-2017')

        SET @AlertCnt = @AlertCnt + 1

    END

	ELSE 

	BEGIN

		INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (12.2,'Severity 017',NULL,'Severity 17 Already Exists')

	END

    IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name  = 'Severity 018')

        BEGIN

		IF @Testing = 0

		BEGIN

        EXEC msdb.dbo.sp_add_alert @name=N'Severity 018',
        @message_id=0,
        @severity=18,
        @enabled=1,
        @delay_between_responses=60,
        @include_event_description_in=1,
        @job_id=N'00000000-0000-0000-0000-000000000000';

        EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 018', @operator_name=N'The DBA Team', @notification_method = 7;

		END

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (12.3,'Severity 018',NULL,'These are the settings you have selected to use for this install')

        SET @AlertCnt = @AlertCnt + 1

    END

	ELSE 

	BEGIN

		INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (12.3,'Severity 018',NULL,'Severity 18 Already Exists')

	END

    IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name  = 'Severity 019')

    BEGIN
		
		IF @Testing = 0

		BEGIN

        EXEC msdb.dbo.sp_add_alert @name=N'Severity 019',
        @message_id=0,
        @severity=19,
        @enabled=1,
        @delay_between_responses=60,
        @include_event_description_in=1,
        @job_id=N'00000000-0000-0000-0000-000000000000';

        EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 019', @operator_name=N'The DBA Team', @notification_method = 7;

		END

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (12.4,'Severity 019',NULL,'These are the settings you have selected to use for this install')

        SET @AlertCnt = @AlertCnt + 1

    END

	ELSE 

	BEGIN

		INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (12.4,'Severity 019',NULL,'Severity 19 Already Exists')

	END

    IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name  = 'Severity 020')

    BEGIN

		IF @Testing = 0

		BEGIN

        EXEC msdb.dbo.sp_add_alert @name=N'Severity 020',
        @message_id=0,
        @severity=20,
        @enabled=1,
        @delay_between_responses=60,
        @include_event_description_in=1,
        @job_id=N'00000000-0000-0000-0000-000000000000';

        EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 020', @operator_name=N'The DBA Team', @notification_method = 7;

		END

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (12.5,'Severity 020',NULL,'These are the settings you have selected to use for this install')

        SET @AlertCnt = @AlertCnt + 1

    END

	ELSE 

	BEGIN

		INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (12.5,'Severity 020',NULL,'Severity 20 Already Exists')

	END

    IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name  = 'Severity 021')

    BEGIN

		IF @Testing = 0

		BEGIN

        EXEC msdb.dbo.sp_add_alert @name=N'Severity 021',
        @message_id=0,
        @severity=21,
        @enabled=1,
        @delay_between_responses=60,
        @include_event_description_in=1,
        @job_id=N'00000000-0000-0000-0000-000000000000';

        EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 021', @operator_name=N'The DBA Team', @notification_method = 7;

		END

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (12.6,'Severity 021',NULL,'These are the settings you have selected to use for this install')

        SET @AlertCnt = @AlertCnt + 1

    END

	ELSE 

	BEGIN

		INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (12.6,'Severity 021',NULL,'Severity 21 Already Exists')

	END

    IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name  = 'Severity 022')

    BEGIN

		IF @Testing = 0 

		BEGIN

        EXEC msdb.dbo.sp_add_alert @name=N'Severity 022',
        @message_id=0,
        @severity=22,
        @enabled=1,
        @delay_between_responses=60,
        @include_event_description_in=1,
        @job_id=N'00000000-0000-0000-0000-000000000000';

        EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 022', @operator_name=N'The DBA Team', @notification_method = 7;

		END

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (12.7,'Severity 022',NULL,'These are the settings you have selected to use for this install')

        SET @AlertCnt = @AlertCnt + 1

    END

	ELSE 

	BEGIN

		INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (12.7,'Severity 022',NULL,'Severity 22 Already Exists')

	END

    IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name  = 'Severity 023')

    BEGIN

		IF @Testing = 0

		BEGIN

        EXEC msdb.dbo.sp_add_alert @name=N'Severity 023',
        @message_id=0,
        @severity=23,
        @enabled=1,
        @delay_between_responses=60,
        @include_event_description_in=1,
        @job_id=N'00000000-0000-0000-0000-000000000000';

        EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 023', @operator_name=N'The DBA Team', @notification_method = 7;

		END

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (12.8,'Severity 023',NULL,'These are the settings you have selected to use for this install')

        SET @AlertCnt = @AlertCnt + 1

    END

	ELSE 

	BEGIN

		INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (12.8,'Severity 023',NULL,'Severity 23 Already Exists')

	END

    IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name  = 'Severity 024')

    BEGIN

		IF @Testing = 0

		BEGIN

        EXEC msdb.dbo.sp_add_alert @name=N'Severity 024',
        @message_id=0,
        @severity=24,
        @enabled=1,
        @delay_between_responses=60,
        @include_event_description_in=1,
        @job_id=N'00000000-0000-0000-0000-000000000000';

        EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 024', @operator_name=N'The DBA Team', @notification_method = 7;

		END

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (12.9,'Severity 024',NULL,'These are the settings you have selected to use for this install')

        SET @AlertCnt = @AlertCnt + 1

    END

	ELSE 

	BEGIN

		INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (12.9,'Severity 024',NULL,'Severity 24 Already Exists')

	END

    IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name  = 'Severity 025')

    BEGIN
		
		IF @Testing = 0

		BEGIN

        EXEC msdb.dbo.sp_add_alert @name=N'Severity 025',
        @message_id=0,
        @severity=25,
        @enabled=1,
        @delay_between_responses=60,
        @include_event_description_in=1,
        @job_id=N'00000000-0000-0000-0000-000000000000';

        EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 025', @operator_name=N'The DBA Team', @notification_method = 7;

		END

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (12.10,'Severity 025',NULL,'These are the settings you have selected to use for this install')

        SET @AlertCnt = @AlertCnt + 1

    END

	ELSE 

	BEGIN

		INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (12.10,'Severity 025',NULL,'Severity 25 Already Exists')

	END

    IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name  = 'Error Number 823')

    BEGIN

		IF @Testing = 0

		BEGIN

        EXEC msdb.dbo.sp_add_alert @name=N'Error Number 823',
        @message_id=823,
        @severity=0,
        @enabled=1,
        @delay_between_responses=60,
        @include_event_description_in=1,
        @job_id=N'00000000-0000-0000-0000-000000000000';

        EXEC msdb.dbo.sp_add_notification @alert_name=N'Error Number 823', @operator_name=N'The DBA Team', @notification_method = 7;

		END

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (12.11,'Error Number 823',NULL,'These are the settings you have selected to use for this install')

        SET @AlertCnt = @AlertCnt + 1

    END

	ELSE 

	BEGIN

		INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (12.11,'Severity 823',NULL,'Severity 823 Already Exists')

	END

    IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name  = 'Error Number 824')

    BEGIN

		IF @Testing = 0

		BEGIN

        EXEC msdb.dbo.sp_add_alert @name=N'Error Number 824',
        @message_id=824,
        @severity=0,
        @enabled=1,
        @delay_between_responses=60,
        @include_event_description_in=1,
        @job_id=N'00000000-0000-0000-0000-000000000000';

        EXEC msdb.dbo.sp_add_notification @alert_name=N'Error Number 824', @operator_name=N'The DBA Team', @notification_method = 7;

		END

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (12.12,'Error Number 824',NULL,'These are the settings you have selected to use for this install')

        SET @AlertCnt = @AlertCnt + 1

    END

	ELSE 

	BEGIN

		INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (12.12,'Severity 824',NULL,'Severity 824 Already Exists')

	END

    IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name  = 'Error Number 825')

    BEGIN

		IF @Testing = 0

		BEGIN

        EXEC msdb.dbo.sp_add_alert @name=N'Error Number 825',
        @message_id=825,
        @severity=0,
        @enabled=1,
        @delay_between_responses=60,
        @include_event_description_in=1,
        @job_id=N'00000000-0000-0000-0000-000000000000';

        EXEC msdb.dbo.sp_add_notification @alert_name=N'Error Number 825', @operator_name=N'The DBA Team', @notification_method = 7;

		END

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (12.13,'Error Number 825',NULL,'These are the settings you have selected to use for this install')

        SET @AlertCnt = @AlertCnt + 1

    END

	ELSE 

	BEGIN

		INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (12.13,'Severity 825',NULL,'Severity 17 Already Exists')

	END

	INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
	VALUES
	(12.14,'Total Errors Added',CAST((CASE WHEN @AlertCnt = 0 THEN NULL ELSE @AlertCnt END) as varchar),'This is the total number of alerts that was added to this instance')

/************************************************************

1. - Setup Default Backup Compression

************************************************************/

IF @Testing = 0 

BEGIN

EXEC sp_configure 'backup compression default', @CompressBackups;  

RECONFIGURE WITH OVERRIDE;

END

INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
VALUES
(13.0,'Backup Compression Settings',NULL,'These are the settings you have selected to use for this install'),
(13.1,'Are backups being compressed by default',CASE WHEN @CompressBackups = 1 THEN 'Yes' ELSE 'No' END,'These are the backup compression settings you have selected for this install')
 
/************************************************************

1. - DBA_Tasks Database Check & Creation

************************************************************/

IF NOT EXISTS (SELECT name from sys.databases where name = QUOTENAME(@DatabaseName)) 

	BEGIN

		IF @Testing = 0

		BEGIN

			SET @CreateDB = 'CREATE DATABASE ' + QUOTENAME(@DatabaseName) + ''

			EXEC sp_executesql @CreateDB

		END

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (14.0,'Default DBA Database',NULL,'These are the settings you have selected to use for this install'),
        (14.1,'Database Created',QUOTENAME(@DatabaseName),'These are the settings you have selected to use for this install')

	END	

/************************************************************

1. - Availablity Group Check Job

************************************************************/

--IF @Testing = 0 

--    BEGIN

--    IF @ProductVersionMajor >= 12.0

--    BEGIN

--    INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
--    VALUES
--    (15.0,'Default DBA Database',NULL,'These are the settings you have selected to use for this install'),
--    (15.1,'Database Created',@DatabaseName,'These are the settings you have selected to use for this install')

--    END

--END

/************************************************************

1. - Availablity Group Execution Agent Job
We only want to run this part of the script IF we are running
the the script on an actual Availability Group.

************************************************************/


    IF @ProductVersionMajor >= 12.0 AND NOT EXISTS (SELECT name FROM msdb.dbo.sysjobs where name = 'Availability Member Check')

    BEGIN

    IF @Testing = 0 

    BEGIN

    USE [msdb]

    BEGIN TRANSACTION
    DECLARE @ReturnCode INT
    SELECT @ReturnCode = 0

    IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
    BEGIN
    EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

    END

    DECLARE @jobId BINARY(16)
    EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Availability Member Check', 
        @enabled=1, 
        @notify_level_eventlog=0, 
        @notify_level_email=2, 
        @notify_level_netsend=0, 
        @notify_level_page=0, 
        @delete_level=0, 
        @description=N'No description available.', 
        @category_name=N'[Uncategorized (Local)]', 
        @owner_login_name=N'essey', 
        @notify_email_operator_name=N'The DBA Team', @job_id = @jobId OUTPUT
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

    EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Run Stored Procedure', 
        @step_id=1, 
        @cmdexec_success_code=0, 
        @on_success_action=1, 
        @on_success_step_id=0, 
        @on_fail_action=2, 
        @on_fail_step_id=0, 
        @retry_attempts=0, 
        @retry_interval=0, 
        @os_run_priority=0, @subsystem=N'TSQL', 
        @command=N'EXEC dbo.p_ExcludedJobCheck', 
        @database_name=N'DBA_Tasks', 
        @flags=0
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
    EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
    EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Every Minute', 
        @enabled=1, 
        @freq_type=4, 
        @freq_interval=1, 
        @freq_subday_type=4, 
        @freq_subday_interval=1, 
        @freq_relative_interval=0, 
        @freq_recurrence_factor=0, 
        @active_start_date=20180831, 
        @active_end_date=99991231, 
        @active_start_time=0, 
        @active_end_time=235959, 
        @schedule_uid=N'3e02404d-8693-43da-9aaa-ff05dc95b026'
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
    EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
    IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
    COMMIT TRANSACTION
    GOTO EndSave
    QuitWithRollback:
        IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
    EndSave:    

		INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes,Reference_URL)
		VALUES
		(16.0,'Availability Member Check Agent Job',NULL,'These are the settings you have selected to use for this install',NULL),
		(16.1,'Availability Member Check Created','Agent Job has been created','This agent job is used to run the availability group member check','https://www.codenameowl.com/managing-agent-jobs-in-availability-groups/')
    
    END

    ELSE 

    BEGIN

		INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
		VALUES
		(16.0,'Availability Member Check',NULL,'These are the settings you have selected to use for this install'),
		(16.1,'Availability Member Agent Job','Agent Job Already Exists, SKIPPING',NULL)

    END

    END

/************************************************************

1. - Check for tools

************************************************************/

IF EXISTS (SELECT name from msdb.sys.databases where name = @DatabaseName) 

BEGIN
	
	--This needs fixing
	SET @OlaExists = (SELECT COUNT(name) from DBA_Tasks.sys.objects where (name = 'DatabaseBackup' or name = 'DatabaseIntegrityCheck' or name = 'CommandExecute' or name = 'IndexOptimize'))

    IF @OlaExists = 0 

    BEGIN

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes,Reference_URL)
        VALUES
        (17.0,'Ola Scripts',NULL,'These are the settings you have selected to use for this install',NULL),
        (17.1,'Ola Scripts Missing',NULL,'Ola Scripts dont exist, they are good you know, go get them and set them up','https://ola.hallengren.com/')

    END

    ELSE

    BEGIN

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes,Reference_URL)
        VALUES
        (17.0,'Ola Scripts',NULL,'These are the settings you have selected to use for this install',NULL),
        (17.1,'Ola Scripts Exist',NULL,'Ola Scripts, exist, they may need confiuring check the reference URL for documentation','https://ola.hallengren.com/')

    END	

	--This needs fixing
    SET @OzarExists = (SELECT COUNT(name) from DBA_Tasks.sys.objects where (name = 'sp_Blitz' or name = 'sp_BlitzBackups' or name = 'sp_BlitzCache' or name = 'sp_BlitzFirst' or name = 'sp_BlitzIndex' or name = 'sp_BlitzInMemoryOLTP' or name = 'sp_BlitzLock' or name = 'sp_BlitzQueryStore' or name = 'sp_BlitzWho'))

    IF @OzarExists = 0 

    BEGIN

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes,Reference_URL)
        VALUES
        (18.0,'First Responder Kit',NULL,'These are the settings you have selected to use for this install',NULL),
        (18.1,'Database Created',NULL,'Looks like none of the First Responder Kit exist here, these are some great tools, go grab them, they may just save the day.','https://www.brentozar.com/first-aid/')

    END

    ELSE 

    BEGIN

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes,Reference_URL)
        VALUES
        (18,'First Responder Kit',NULL,'These are the settings you have selected to use for this install',NULL),
        (18.1,'First Responder Kit Exists',NULL,'Looks like the First Responder Kit exists here, if you are unsure how to use them, check out the documentation.','https://www.brentozar.com/first-aid/')

    END

END

SELECT * FROM #Actions
##Compare AG Jobs 

powershell.exe -NoLogo -NonInteractive -File "$(ESCAPE_NONE(SQLLOGDIR))\..\JOBS\CompareAGJobs.ps1" -ThisServer $(ESCAPE_NONE(SRVR)) -EmailTo rjah.adminalerts@nhs.net;rjah.developmentalerts@nhs.net

## Copy AG Logins 
powershell.exe -NoLogo -NonInteractive -File "$(ESCAPE_NONE(SQLLOGDIR))\..\JOBS\CopyAgLogins.ps1" -ThisServer $(ESCAPE_NONE(SRVR)) -LogFileFolder "$(ESCAPE_NONE(SQLLOGDIR))"

##_MAINT_CycleErrorLog

### Step 1 Cycle SQL Server Error Log
Exec sys.sp_cycle_errorlog 

### Step 2 Cycle SQL Agent LogExec dbo.sp_cycle_agent_errorlog
Exec msdb.dbo.sp_cycle_agent_errorlog

### Who is active data collection 

SET NOCOUNT ON;

DECLARE @retention INT = 3,
        @destination_table VARCHAR(500) = 'WhoIsActive',
        @destination_database sysname = 'DB_Administration',
        @schema VARCHAR(MAX),
        @SQL NVARCHAR(4000),
        @parameters NVARCHAR(500),
        @exists BIT;

SET @destination_table = @destination_database + '.dbo.' + @destination_table;

--create the logging table
IF OBJECT_ID(@destination_table) IS NULL
    BEGIN;
        EXEC dbo.sp_WhoIsActive @get_transaction_info = 1,
                                @get_outer_command = 1,
                                @get_plans = 1,
                                @return_schema = 1,
                                @schema = @schema OUTPUT;
        SET @schema = REPLACE(@schema, '<table_name>', @destination_table);
        EXEC ( @schema );
    END;

--create index on collection_time
SET @SQL
    = 'USE ' + QUOTENAME(@destination_database)
      + '; IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(@destination_table) AND name = N''cx_collection_time'') SET @exists = 0';
SET @parameters = N'@destination_table varchar(500), @exists bit OUTPUT';
EXEC sys.sp_executesql @SQL, @parameters, @destination_table = @destination_table, @exists = @exists OUTPUT;

IF @exists = 0
    BEGIN;
        SET @SQL = 'CREATE CLUSTERED INDEX cx_collection_time ON ' + @destination_table + '(collection_time ASC)';
        EXEC ( @SQL );
    END;

--collect activity into logging table
EXEC dbo.sp_WhoIsActive @get_transaction_info = 1,
                        @get_outer_command = 1,
                        @get_plans = 1,
                        @destination_table = @destination_table;

--purge older data
SET @SQL
    = 'DELETE FROM ' + @destination_table + ' WHERE collection_time < DATEADD(day, -' + CAST(@retention AS VARCHAR(10))
      + ', GETDATE());';
EXEC ( @SQL );

### Database Space Tracking 

/*
TD Clarke
20220524
Manage retention of, and log, database space information.
Primary only, logs to Utility.
*/

	/*A few of the variables we will use*/
	DECLARE @maxDays int --number of days to keep historical data for
	DECLARE @maxDate date --date calculated from maxDays
	DECLARE @command varchar(max) 
	DECLARE @Sort bit
	DECLARE @Availability_Role nvarchar(20)
	DECLARE @pollDate datetime

	/*Set the variables*/
	SET @maxDays = -365
	SET @maxDate = DATEADD(dd,@maxDays,GETDATE())
	SET @pollDate = GETDATE()

	--print @maxDays
	--print @maxDate

	/*Remove rows > @maxDate*/
	DELETE FROM [Utility].[DBA].[SpaceTracking]
	WHERE 
	(
	CAST([PollDate] AS DATE) < @maxDate
	)

	--Create Temporary Table 
	CREATE TABLE #SpaceTrack 
	([DatabaseName] varchar(60),
		[LogicalName] varchar(60), 
		[FileType] varchar(10), 
		[FilegroupName] varchar(50), 
		[PhysicalFileLocation] varchar(300), 
		[SpaceMB] decimal(18,2),
		[UsedSpaceMB] int,
		[FreeSpaceMB] decimal(18,2)) 

	---Create Stored Procedure String 
	SELECT @command = 'SELECT
	DB_NAME() [DatabaseName]
	,dbf.[name] [LogicalName]
	,CASE WHEN dbf.[type_desc] = ''ROWS'' THEN ''DATA'' ELSE dbf.[type_desc] END AS [FileType]
	,fg.[name] [FilegroupName]
	,dbf.[physical_name] [PhysicalFileLocation]
	,CONVERT(decimal(10,2),dbf.[size]/128.0) [SpaceMB]
	,CAST(FILEPROPERTY(dbf.[name],''SPACEUSED'') AS int)/128.0 [UsedSpaceMB]
	,(CONVERT(decimal(10,2),dbf.[size]/128.0) - CAST(FILEPROPERTY(dbf.[name],''SPACEUSED'') AS int)/128.0) [FreeSpaceMB]
	FROM [sys].[database_files] dbf
	LEFT JOIN [sys].[filegroups] fg 
	ON dbf.[data_space_id] = fg.[data_space_id]'

	 --print @command
	 --EXEC dbo.[sp_ineachdb] @command, @print_command_only = 1--, @user_only = 1

	--Populate Tempoary Table 
	INSERT INTO #SpaceTrack 
	EXEC [Master].[dbo].[sp_ineachdb] @command

	--Determine sorting method and load
	INSERT INTO [Utility].[DBA].[SpaceTracking]
	([PollDate]
	,[DatabaseName]
	,[LogicalName]
	,[FileType]
	,[FilegroupName]
	,[PhysicalFileLocation]
	,[SpaceMB]
	,[UsedSpaceMB]
	,[FreeSpaceMB]
	)
	SELECT 
	@pollDate
	,[DatabaseName]
	,[LogicalName]
	,[FileType]
	,[FilegroupName]
	,[PhysicalFileLocation]
	,[SpaceMB]
	,[UsedSpaceMB]
	,[FreeSpaceMB]
	FROM #SpaceTrack
	ORDER BY [LogicalName],[FileType]

	--Tidy up
	IF OBJECT_ID('tempdb..#SpaceTrack', 'U') IS NOT NULL
	BEGIN
		DROP TABLE #SpaceTrack
	END


    ### DB Sync Status 

    /*
TD Clarke
20220810
Check AG databases are either synchronised, or have been added to the exclusions table.
Runs on all replicas
*/

/*Ensure temp table built afresh*/
	IF OBJECT_ID('tempdb..#syncDbChk','U') IS NOT NULL
	DROP TABLE #syncDbChk

/*Create temp #IxDatabases table*/
	CREATE TABLE #syncDbChk(
	[DatabaseName] varchar(128) NOT NULL
	)

/*Populate Table*/
	INSERT INTO #syncDbChk 
	([DatabaseName])
	SELECT d.[name]
	FROM [master].[sys].[databases] d
	LEFT JOIN [master].[sys].[dm_hadr_database_replica_states] r 
	ON d.[database_id] = r.[database_id]
	LEFT JOIN [Utility].[DBA].[UnsyncedDBs] u
	ON d.[name] = u.[DatabaseName]
	WHERE u.[DatabaseName] IS NULL --Not excluded
	AND d.[database_id] > 4 --Not system database
	AND ((d.[state_desc] <> 'OFFLINE' AND r.[database_id] IS NULL) OR (r.[synchronization_state_desc] <> 'SYNCHRONIZED' OR r.[synchronization_health_desc] <> 'HEALTHY'))

/*Trigger for the email to be generated*/
	DECLARE @unsyncDatabases INT =
	(
		SELECT COUNT(*) FROM #syncDbChk
	)
	IF (@unsyncDatabases > 0)

	BEGIN

		DECLARE @Body NVARCHAR(MAX), @Subject VARCHAR(255), @To VARCHAR(MAX), @Cc VARCHAR(MAX), @Query NVARCHAR(MAX), @xml NVARCHAR(MAX)

		/*Create the XML content*/
		SET @xml = CAST(( 

			SELECT 
	
			'left' as [td/@align] ,
				case when ISNULL(Sub.[DatabaseName],'NULL') = 'NULL' then 'color:#FF00FF;' else 'color:black' end AS [td/@style] ,
				ISNULL(Sub.[DatabaseName],'NULL') as 'td',
				''
		FROM
			#syncDbChk AS Sub
		
		GROUP BY Sub.[DatabaseName]
								
		FOR XML PATH('tr'), ELEMENTS ) AS NVARCHAR(MAX))

		/*Get the server name*/
		DECLARE @ServerName varchar(45) =
		(
			SELECT @@SERVERNAME
		)

		/*Create the body of the email to include the xml*/
   		SET @Body = '<html><body><p style="font-family: Arial; font-size: 12pt">
   					<H3 style="font-family: Arial; font-size: 12pt">Unsynchronised Databases - '+@ServerName+'</H3>'
   		SET @Body = @Body +'<p style="font-family: Arial; font-size: 10pt">The following databases are not synchronised.</p>
					<p style="font-family: Arial; font-size: 10pt"> Please either add to the availability group, resolve the issues with synchronisation, or add to [Utility].[DBA].[UnsyncedDBs] to exclude them from the monitoring.</p>
   					<p style="font-family: Arial; font-size: 10pt">
					<table border = 1> 
					<tr>
					<th align="left"><p style="font-family: Arial; font-size: 12pt"> DatabaseName </p></th> 
					</tr>' 
		SET @Body = @Body + @xml +'</table></p></body></html>'+ CHAR(10)

		/*Set the extra email variables*/
		SET @Subject = 'Unsynchronised Databases - '+@ServerName
		SET @To = 'rjah.adminalerts@nhs.net'
		SET @Cc = 'rjah.developmentalerts@nhs.net'
		--SET @To = 'danni.clarke@nhs.net'

		/*Create the email*/
		EXEC msdb.dbo.sp_send_dbmail
			@Recipients = @To,
   			@Subject = @Subject,
   			@Body = @Body,
   			@body_format ='HTML',
			@copy_recipients = @Cc 

		 /*Tidy up*/
		IF OBJECT_ID('tempdb..#syncDbChk','U') IS NOT NULL
		DROP TABLE #syncDbChk

	END


    ### Temp DB Space Usage

    /*A few of the variables we will use*/
DECLARE @maxDays int --number of days to keep historical data for
DECLARE @maxDate date --date calculated from maxDays
DECLARE @minAlert int --remaining memory threshold - Used to trigger additional reporting if server under pressure
DECLARE @minActual int --min percent remaining memory this execution

/*Set the variables*/
SET @maxDays = -30
SET @maxDate = DATEADD(dd,@maxDays,GETDATE())
SET @minAlert = 40

--print @maxDays
--print @maxDate
--print @minAlert

/*Create temp table so we can use data from just this execution to make logic decisions*/
CREATE TABLE #TempDBSpaceUsage
(
[ServerName] [nvarchar](128) NULL,
[DatabaseName] [varchar](6) NOT NULL,
[LogicalFileName] [sysname] NOT NULL,
[PhysicalFileName] [nvarchar](260) NOT NULL,
[Status] [sysname] NULL,
[Updateability] [sysname] NULL,
[RecoveryMode] [sysname] NULL,
[FileSizeMB] [int] NULL,
[SpaceUsedMB] [int] NULL,
[FreeSpaceMB] [int] NULL,
[FreeSpacePct] [varchar](11) NULL,
[Max Size] [varchar](13) NULL,
[Growth] [varchar](13) NULL,
[PollDate] [datetime] NOT NULL
)

/*Get Space Requests*/
INSERT INTO #TempDBSpaceUsage
	([ServerName]
		,[DatabaseName]
		,[LogicalFileName]
		,[PhysicalFileName]
		,[Status]
		,[Updateability]
		,[RecoveryMode]
		,[FileSizeMB]
		,[SpaceUsedMB]
		,[FreeSpaceMB]
		,[FreeSpacePct]
		,[Max Size]
		,[Growth]
		,[PollDate])
SELECT
	@@servername as ServerName,
	'TempDB' AS DatabaseName,
	sysfiles.name AS LogicalFileName, sysfiles.filename AS PhysicalFileName,
	CONVERT(sysname,DatabasePropertyEx('TempDB','Status')) AS Status,
	CONVERT(sysname,DatabasePropertyEx('TempDB','Updateability')) AS Updateability,
	CONVERT(sysname,DatabasePropertyEx('TempDB','Recovery')) AS RecoveryMode,
	CAST(sysfiles.size/128.0 AS int) AS FileSizeMB,
	CAST(FILEPROPERTY(sysfiles.name, 'SpaceUsed' ) AS int)/128  AS SpaceUsedMB,
	CAST(sysfiles.size/128.0 - CAST(FILEPROPERTY(sysfiles.name, 'SpaceUsed' ) AS int)/128.0 AS int) AS FreeSpaceMB,
	CAST(100 * (CAST (((sysfiles.size/128.0 -CAST(FILEPROPERTY(sysfiles.name,'SpaceUsed' ) AS int)/128.0)/(sysfiles.size/128.0)) AS decimal(5,3))) AS varchar(10)) + '%' AS FreeSpacePct,
	CASE WHEN [maxsize]=-1 THEN 'Unlimited' ELSE CONVERT(VARCHAR(10),CONVERT(bigint,[maxsize])/128) +' MB' END AS [Max Size],
	CASE [status] & 0x100000 WHEN 0x100000 then CONVERT(VARCHAR(10),growth) +'%' ELSE Convert(VARCHAR(10),growth/128) +' MB' END AS [Growth],
	GETDATE() as PollDate
	FROM dbo.sysfiles

/*Get @minActual*/
SELECT @minActual = MIN(CAST(LEFT(FreeSpacePct,CHARINDEX('.',FreeSpacePct,0)-1) as int)) FROM #TempDBSpaceUsage

/*If tempdb under pressure log additional details*/
IF @minActual < @minAlert
BEGIN
	EXEC [DB_Administration].[DBA].[p_ManageTempDBSpaceRequests]
END

/*Log the space usage data*/
INSERT INTO [DB_Administration].[DBA].[TempDBSpaceUsage]
(
[ServerName]
,[DatabaseName]
,[LogicalFileName]
,[PhysicalFileName]
,[Status]
,[Updateability]
,[RecoveryMode]
,[FileSizeMB]
,[SpaceUsedMB]
,[FreeSpaceMB]
,[FreeSpacePct]
,[Max Size]
,[Growth]
,[PollDate]
)
SELECT 
[ServerName]
,[DatabaseName]
,[LogicalFileName]
,[PhysicalFileName]
,[Status]
,[Updateability]
,[RecoveryMode]
,[FileSizeMB]
,[SpaceUsedMB]
,[FreeSpaceMB]
,[FreeSpacePct]
,[Max Size]
,[Growth]
,[PollDate]
FROM #TempDBSpaceUsage

/*Tidy up*/
DROP TABLE #TempDBSpaceUsage

/*Remove rows > @maxDate*/
DELETE FROM [DB_Administration].[DBA].[TempDBSpaceUsage]
WHERE 
(
CAST([PollDate] AS DATE) < @maxDate
)

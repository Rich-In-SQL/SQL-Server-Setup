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
  ,@SASQL varchar(600)
  ,@TableSQL nvarchar(MAX)
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
SET @DefaultData = ' '

--Default location for log files, leave blank to make no canges
SET @DefaultLog = 'L:'

--Default location for backup files, leave blank to make no canges
SET @DefaultBackup = 'B:'

--Default location for the SQL Agent Log, leave blank to make no canges
SET @AgentLog = 'C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\fog\SQLAGENT.OUT'

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

INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
VALUES
(0.1,'Script Details',NULL,NULL),
(0.2,'Script Version',CAST(@ScriptVersion as varchar) ,NULL),
(0.3,'Script Author','Bonza Owl',NULL),
(0.4,'Last Updated','07/10/2018',NULL),
(0.5,'Run Date',CONVERT(varchar(20),GETDATE()),NULL),
(0.6,'Run By',SYSTEM_USER,NULL),
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
(2,'Max Server Memory',NULL,'These are the settings you have selected to use for this install'),
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

        EXEC sys.sp_configure N'show advanced options', N'1'  RECONFIGURE WITH OVERRIDE;

        EXEC sys.sp_configure N'max degree of parallelism', @DegreeOfParalelism;

        RECONFIGURE WITH OVERRIDE;

        EXEC sys.sp_configure N'show advanced options', N'0'  RECONFIGURE WITH OVERRIDE;

    END

END

INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
VALUES
(3,'Max degree of parallelism',NULL,'These are the settings you have selected to use for this install'),
(3.1,'Max degree of parallelism configured',@DegreeOfParalelism,NULL)

/************************************************************

1.0 - CHANGE DEFAULT FILE LOCATIONS

************************************************************/

IF @Testing = 0 

BEGIN

    INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
    VALUES
    (4,'Default File Locations',NULL,'These are the settings you have selected to use for this install')

    USE [master];

    IF @DefaultData IS NOT NULL OR LEN(@DefaultData) > 1 

    BEGIN

        EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultData', REG_SZ, @DefaultData;

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (4.1,'Default Data Directory',@DefaultData,NULL)

    END

    ELSE 

    BEGIN

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (4.1,'Default Data Directory','No Changes Made',NULL)

    END 

    IF @DefaultLog IS NOT NULL OR LEN(@DefaultLog) > 1 

    BEGIN

        EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultLog', REG_SZ, @DefaultLog;

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (4.2,'Default Log Directory',@DefaultLog,NULL)

    END

    ELSE 

    BEGIN

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (4.2,'Default Log Directory','No Changes Made',NULL)

    END 

    IF @DefaultBackup IS NOT NULL OR LEN(@DefaultBackup) > 1 

    BEGIN

        EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'BackupDirectory', REG_SZ, @DefaultBackup;

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (4.3,'Default Backup Directory',@DefaultBackup,NULL)

    END

    ELSE 

    BEGIN

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (4.3,'Default Backup Directory','No Changes Made',NULL)

    END 

END

INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
VALUES
(4.4,'WARNING','Changes to default file location will require the SQL Service to be restarted for them to take effect. make sure that the dbengine service account and sql service account have permission to that new directory too.',NULL)

/************************************************************

1.0 - CHANGE DEFAULT FILE LOCATIONS

************************************************************/

IF @Testing = 0 

BEGIN

    IF @AgentLog <> ' ' OR LEN(@AgentLog) > 0

    BEGIN

        USE [Msdb];

        EXEC msdb.dbo.sp_set_sqlagent_properties @errorlog_file = @AgentLog;    

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (5,'Default Agent Log Location',NULL,'These are the settings you have selected to use for this install'),
        (5.1,'Agent Log Directory',@AgentLog,NULL),
        (5.2,'WARNING','Changes to the Agent Log location will not take effect until the agent service is re-started, make sure that the agent service account has permission to that new directory too.',NULL)

    END

END

/************************************************************

1.0 - ENABLE THE DAC INTERFACE
--https://www.brentozar.com/archive/2011/08/dedicated-admin-connection-why-want-when-need-how-tell-whos-using/

************************************************************/

IF @Testing = 0 

BEGIN

    IF @EnableDac <> ' ' OR LEN(@EnableDac) > 0

    BEGIN

        EXEC sp_configure 'remote admin connections', @EnableDac;

        RECONFIGURE;

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (5,'DAC Settings',NULL,'These are the settings you have selected to use for this install'),
        (5.1,'Is the DAC enabled for this instance',CASE WHEN @EnableDac = 1 THEN 'Yes' ELSE 'No' END,NULL)

    END

    ELSE

    BEGIN

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (5,'DAC Settings',NULL,'These are the settings you have selected to use for this install'),
        (5.1,'No Changes Made To The DAC',NULL,NULL)

    END

END

/************************************************************

1.1 - MOVE TEMP DB OFF C DRIVE
Ideally onto some fast disks. 

************************************************************/

IF @Testing = 0 

BEGIN

USE [master];

ALTER DATABASE [tempdb]
MODIFY FILE 
(
	name='tempdev',
    filename='D:\tempdb.mdf'
);

ALTER DATABASE [tempdb]
MODIFY FILE 
(
	name='templog',
    filename='D:\tempdb_log.ldf'
);

END

INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
VALUES
(6,'TempDB File Locations',NULL,'These are the settings you have selected to use for this install'),
(6.1,'Is the DAC enabled for this instance',CASE WHEN @EnableDac = 1 THEN 'Yes' ELSE 'No' END,NULL)

/************************************************************

1.2 - Disable & Update SA
We are callinh sa essey becuase they both sound the same so when
talking about it with other members of the team everyone will 
know what we are talking about

************************************************************/

IF @Testing = 0 

BEGIN

    IF @SAPwd <> ' ' OR LEN(@SAPwd) > 0

    BEGIN

        USE [master];

        SET @SASQL = 'ALTER LOGIN [sa] WITH PASSWORD = ' + @SAPwd +''

        EXEC sp_executesql @SASQL

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes,Reference_URL)
        VALUES
        (7,'SA Account Settings',NULL,'These are the settings you have selected to use for this install','https://www.mssqltips.com/sqlservertip/3695/best-practices-to-secure-the-sql-server-sa-account/'),
        (7.1,'New SA Password',@SAPwd,NULL,NULL),
        (7.2,'WARNING','Ensure the password is recorded, loosing the SA password will render the DAC useless',NULL,NULL)

    END

    ELSE 

    BEGIN

    INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes,Reference_URL)
    VALUES
    (7,'SA Account Settings',NULL,'These are the settings you have selected to use for this install','https://www.mssqltips.com/sqlservertip/3695/best-practices-to-secure-the-sql-server-sa-account/'),
    (7.1,'SA Password Not Amended',NULL,NULL,NULL)

    END

    ALTER LOGIN [sa]
    DISABLE;

    INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes,Reference_URL)
    VALUES
    (7.3,'SA Disabled',NULL,NULL,NULL)    

    ALTER LOGIN [sa] WITH NAME = [essey] 

    INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes,Reference_URL)
    VALUES
    (7.4,'SA Renamed','New Name essey',NULL,NULL)    

END

/************************************************************

1.3 - Add Operator

************************************************************/

IF @Testing = 0 

BEGIN

IF NOT EXISTS (SELECT name FROM msdb.dbo.sysoperators where (name = @operator_name or email_address = @operator_email))

BEGIN

    USE [msdb];

    EXEC msdb.dbo.sp_add_operator @name= @operator_name, 
            @enabled=1, 
            @pager_days=0, 
            @email_address= @operator_email

    INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
    VALUES
    (8,'Operator Configuration',NULL,'These are the settings you have selected to use for this install'),
    (8.1,'Operator Name',@operator_name,NULL),
    (8.2,'Operator Email',@operator_email,NULL)

END

ELSE

BEGIN

    INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
    VALUES
    (8,'Operator Configuration',NULL,'These are the settings you have selected to use for this install'),
    (8.1,'Operator Name Not Changes',NULL,NULL),
    (8.2,'Operator Email',NULL,NULL)

END

END

/************************************************************

1.3 - SETUP DATABASE MAIL

************************************************************/

IF @Testing = 0 

BEGIN

    DECLARE @Broker INT = (SELECT is_broker_enabled FROM sys.databases WHERE name = 'msdb')

    DECLARE @MailXP sql_variant	 = (SELECT value_in_use FROM  sys.configurations WHERE name = 'Database Mail XPs')

    IF @MailXP = 0  AND @MailXP = 0

    BEGIN
    
        EXEC sp_configure 'show advanced options', '1';
        RECONFIGURE

        EXEC sp_configure 'Database Mail XPs', 1;
        RECONFIGURE

    END

END

INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
VALUES
(8,'Operator Configuration',NULL,'These are the settings you have selected to use for this install'),
(8.1,'Operator Name',@operator_name,NULL),
(8.2,'Operator Email',@operator_email,NULL),
(8.3,'WARNING','Don''t forget to add a profile and SMPTP account, we can''t do that here',NULL) 

/************************************************************

1. - Setup SQL Agent Failsafe Notification Operator

************************************************************/

IF @Testing = 0 

BEGIN

    USE [msdb];
    EXEC master.dbo.sp_MSsetalertinfo @failsafeoperator= @operator_name, @notificationmethod=1;

    USE [msdb];
    EXEC msdb.dbo.sp_set_sqlagent_properties @email_save_in_sent_folder=1;

    INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
    VALUES
    (9,'Failsafe Operator Configuration',NULL,'These are the settings you have selected to use for this install'),
    (9.1,'Operator Name',@operator_name,NULL),
    (9.2,'Operator Email',@operator_email,NULL),
    (9.3,'WARNING','Don''t forget to add a profile and SMTP account, we can''t do that here',NULL) 

END

ELSE

BEGIN

    INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
    VALUES
    (9,'Failsafe Operator Configuration',NULL,'These are the settings you have selected to use for this install'),
    (9.1,'Operator Name Not Changed',@operator_name,NULL),
    (9.2,'Operator Email Not Changed',@operator_email,NULL)

END

/************************************************************

1.3 - Setup SQL Versions Ref

The code used in this section was povided as part of the 
First Responder Toolkit from Brent Ozar and has been added to
this setup script. Bonza Owl does not own the copy right or 
origional code to this section of the Database Setup Script.

************************************************************/

IF @Testing = 0 

BEGIN

    IF @SQLVersionsRef = 1

    BEGIN

        IF EXISTS (SELECT name from msdb.sys.databases where name = @DatabaseName)

            BEGIN

                IF NOT EXISTS (SELECT NULL FROM sys.tables WHERE [name] = 'SqlServerVersions')
                
                BEGIN

                    SET @TableSQL =

                    'CREATE TABLE ' + QUOTENAME(@DatabaseName) + '.dbo.SqlServerVersions
                    (
                        MajorVersionNumber tinyint not null,
                        MinorVersionNumber smallint not null,
                        Branch varchar(34) not null,
                        [Url] varchar(99) not null,
                        ReleaseDate date not null,
                        MainstreamSupportEndDate date not null,
                        ExtendedSupportEndDate date not null,
                        MajorVersionName varchar(19) not null,
                        MinorVersionName varchar(67) not null,

                        CONSTRAINT PK_SqlServerVersions PRIMARY KEY CLUSTERED
                        (
                            MajorVersionNumber ASC,
                            MinorVersionNumber ASC,
                            ReleaseDate ASC
                        )
                    );'

                END

                ELSE 
                
                BEGIN
                
                    SET @TruncateSQL = 'TRUNCATE TABLE ' + QUOTENAME(@DatabaseName) + '.dbo.SqlServerVersions'

                    SET @InsertSQL = 

                    'INSERT INTO ' + QUOTENAME(@DatabaseName) + '.dbo.SqlServerVersions
                    (MajorVersionNumber, MinorVersionNumber, Branch, [Url], ReleaseDate, MainstreamSupportEndDate, ExtendedSupportEndDate, MajorVersionName, MinorVersionName)
                    VALUES
                    (14, 3037, ''RTM CU10'', ''https://support.microsoft.com/en-us/help/4342123'', ''2018-08-27'', ''2022-10-11'', ''2027-10-12'', ''SQL Server 2017'', ''RTM Cumulative Update 10''),
                    (14, 3030, ''RTM CU9'', ''https://support.microsoft.com/en-us/help/4341265'', ''2018-07-18'', ''2022-10-11'', ''2027-10-12'', ''SQL Server 2017'', ''RTM Cumulative Update 9''),
                    (14, 3029, ''RTM CU8'', ''https://support.microsoft.com/en-us/help/4338363'', ''2018-06-21'', ''2022-10-11'', ''2027-10-12'', ''SQL Server 2017'', ''RTM Cumulative Update 8''),
                    (14, 3026, ''RTM CU7'', ''https://support.microsoft.com/en-us/help/4229789'', ''2018-05-23'', ''2022-10-11'', ''2027-10-12'', ''SQL Server 2017'', ''RTM Cumulative Update 7''),
                    (14, 3025, ''RTM CU6'', ''https://support.microsoft.com/en-us/help/4101464'', ''2018-04-17'', ''2022-10-11'', ''2027-10-12'', ''SQL Server 2017'', ''RTM Cumulative Update 6''),
                    (14, 3023, ''RTM CU5'', ''https://support.microsoft.com/en-us/help/4092643'', ''2018-03-20'', ''2022-10-11'', ''2027-10-12'', ''SQL Server 2017'', ''RTM Cumulative Update 5''),
                    (14, 3022, ''RTM CU4'', ''https://support.microsoft.com/en-us/help/4056498'', ''2018-02-20'', ''2022-10-11'', ''2027-10-12'', ''SQL Server 2017'', ''RTM Cumulative Update 4''),
                    (14, 3015, ''RTM CU3'', ''https://support.microsoft.com/en-us/help/4052987'', ''2018-01-04'', ''2022-10-11'', ''2027-10-12'', ''SQL Server 2017'', ''RTM Cumulative Update 3''),
                    (14, 3008, ''RTM CU2'', ''https://support.microsoft.com/en-us/help/4052574'', ''2017-11-28'', ''2022-10-11'', ''2027-10-12'', ''SQL Server 2017'', ''RTM Cumulative Update 2''),
                    (14, 3006, ''RTM CU1'', ''https://support.microsoft.com/en-us/help/4038634'', ''2017-10-24'', ''2022-10-11'', ''2027-10-12'', ''SQL Server 2017'', ''RTM Cumulative Update 1''),
                    (14, 1000, ''RTM '', '''', ''2017-10-02'', ''2022-10-11'', ''2027-10-12'', ''SQL Server 2017'', ''RTM ''),
                    (13, 5201, ''SP2 CU2 + Security Update'', ''https://support.microsoft.com/en-us/help/4458621'', ''2018-08-21'', ''2021-07-13'', ''2026-07-14'', ''SQL Server 2016'', ''Service Pack 2 Cumulative Update 2 + Security Update''),
                    (13, 5153, ''SP2 CU2'', ''https://support.microsoft.com/en-us/help/4340355'', ''2018-07-16'', ''2021-07-13'', ''2026-07-14'', ''SQL Server 2016'', ''Service Pack 2 Cumulative Update 2''),
                    (13, 5149, ''SP2 CU1'', ''https://support.microsoft.com/en-us/help/4135048'', ''2018-05-30'', ''2021-07-13'', ''2026-07-14'', ''SQL Server 2016'', ''Service Pack 2 Cumulative Update 1''),
                    (13, 5026, ''SP2 '', ''https://support.microsoft.com/en-us/help/4052908'', ''2018-04-24'', ''2021-07-13'', ''2026-07-14'', ''SQL Server 2016'', ''Service Pack 2 ''),
                    (13, 4514, ''SP1 CU10'', ''https://support.microsoft.com/en-us/help/4341569'', ''2018-07-16'', ''2019-07-09'', ''2019-07-09'', ''SQL Server 2016'', ''Service Pack 1 Cumulative Update 10''),
                    (13, 4502, ''SP1 CU9'', ''https://support.microsoft.com/en-us/help/4100997'', ''2018-05-30'', ''2019-07-09'', ''2019-07-09'', ''SQL Server 2016'', ''Service Pack 1 Cumulative Update 9''),
                    (13, 4474, ''SP1 CU8'', ''https://support.microsoft.com/en-us/help/4077064'', ''2018-03-19'', ''2019-07-09'', ''2019-07-09'', ''SQL Server 2016'', ''Service Pack 1 Cumulative Update 8''),
                    (13, 4466, ''SP1 CU7'', ''https://support.microsoft.com/en-us/help/4057119'', ''2018-01-04'', ''2019-07-09'', ''2019-07-09'', ''SQL Server 2016'', ''Service Pack 1 Cumulative Update 7''),
                    (13, 4457, ''SP1 CU6'', ''https://support.microsoft.com/en-us/help/4037354'', ''2017-11-20'', ''2019-07-09'', ''2019-07-09'', ''SQL Server 2016'', ''Service Pack 1 Cumulative Update 6''),
                    (13, 4451, ''SP1 CU5'', ''https://support.microsoft.com/en-us/help/4024305'', ''2017-09-18'', ''2019-07-09'', ''2019-07-09'', ''SQL Server 2016'', ''Service Pack 1 Cumulative Update 5''),
                    (13, 4446, ''SP1 CU4'', ''https://support.microsoft.com/en-us/help/4024305'', ''2017-08-08'', ''2019-07-09'', ''2019-07-09'', ''SQL Server 2016'', ''Service Pack 1 Cumulative Update 4''),
                    (13, 4435, ''SP1 CU3'', ''https://support.microsoft.com/en-us/help/4019916'', ''2017-05-15'', ''2019-07-09'', ''2019-07-09'', ''SQL Server 2016'', ''Service Pack 1 Cumulative Update 3''),
                    (13, 4422, ''SP1 CU2'', ''https://support.microsoft.com/en-us/help/4013106'', ''2017-03-20'', ''2019-07-09'', ''2019-07-09'', ''SQL Server 2016'', ''Service Pack 1 Cumulative Update 2''),
                    (13, 4411, ''SP1 CU1'', ''https://support.microsoft.com/en-us/help/3208177'', ''2017-01-17'', ''2019-07-09'', ''2019-07-09'', ''SQL Server 2016'', ''Service Pack 1 Cumulative Update 1''),
                    (13, 4224, ''SP1 CU10 + Security Update'', ''https://support.microsoft.com/en-us/help/4458842'', ''2018-08-22'', ''2019-07-09'', ''2019-07-09'', ''SQL Server 2016'', ''Service Pack 1 Cumulative Update 10 + Security Update''),
                    (13, 4001, ''SP1 '', ''https://support.microsoft.com/en-us/help/3182545 '', ''2016-11-16'', ''2019-07-09'', ''2019-07-09'', ''SQL Server 2016'', ''Service Pack 1 ''),
                    (13, 2216, ''RTM CU9'', ''https://support.microsoft.com/en-us/help/4037357'', ''2017-11-20'', ''2018-01-09'', ''2018-01-09'', ''SQL Server 2016'', ''RTM Cumulative Update 9''),
                    (13, 2213, ''RTM CU8'', ''https://support.microsoft.com/en-us/help/4024304'', ''2017-09-18'', ''2018-01-09'', ''2018-01-09'', ''SQL Server 2016'', ''RTM Cumulative Update 8''),
                    (13, 2210, ''RTM CU7'', ''https://support.microsoft.com/en-us/help/4024304'', ''2017-08-08'', ''2018-01-09'', ''2018-01-09'', ''SQL Server 2016'', ''RTM Cumulative Update 7''),
                    (13, 2204, ''RTM CU6'', ''https://support.microsoft.com/en-us/help/4019914'', ''2017-05-15'', ''2018-01-09'', ''2018-01-09'', ''SQL Server 2016'', ''RTM Cumulative Update 6''),
                    (13, 2197, ''RTM CU5'', ''https://support.microsoft.com/en-us/help/4013105'', ''2017-03-20'', ''2018-01-09'', ''2018-01-09'', ''SQL Server 2016'', ''RTM Cumulative Update 5''),
                    (13, 2193, ''RTM CU4'', ''https://support.microsoft.com/en-us/help/3205052 '', ''2017-01-17'', ''2018-01-09'', ''2018-01-09'', ''SQL Server 2016'', ''RTM Cumulative Update 4''),
                    (13, 2186, ''RTM CU3'', ''https://support.microsoft.com/en-us/help/3205413 '', ''2016-11-16'', ''2018-01-09'', ''2018-01-09'', ''SQL Server 2016'', ''RTM Cumulative Update 3''),
                    (13, 2164, ''RTM CU2'', ''https://support.microsoft.com/en-us/help/3182270 '', ''2016-09-22'', ''2018-01-09'', ''2018-01-09'', ''SQL Server 2016'', ''RTM Cumulative Update 2''),
                    (13, 2149, ''RTM CU1'', ''https://support.microsoft.com/en-us/help/3164674 '', ''2016-07-25'', ''2018-01-09'', ''2018-01-09'', ''SQL Server 2016'', ''RTM Cumulative Update 1''),
                    (13, 1601, ''RTM '', '''', ''2016-06-01'', ''2019-01-09'', ''2019-01-09'', ''SQL Server 2016'', ''RTM ''),
                    (12, 5590, ''SP2 CU13'', ''https://support.microsoft.com/en-us/help/4456287'', ''2018-08-27'', ''2019-07-09'', ''2024-07-09'', ''SQL Server 2014'', ''Service Pack 2 Cumulative Update 13''),
                    (12, 5589, ''SP2 CU12'', ''https://support.microsoft.com/en-us/help/4130489'', ''2018-06-18'', ''2019-07-09'', ''2024-07-09'', ''SQL Server 2014'', ''Service Pack 2 Cumulative Update 12''),
                    (12, 5579, ''SP2 CU11'', ''https://support.microsoft.com/en-us/help/4077063'', ''2018-03-19'', ''2019-07-09'', ''2024-07-09'', ''SQL Server 2014'', ''Service Pack 2 Cumulative Update 11''),
                    (12, 5571, ''SP2 CU10'', ''https://support.microsoft.com/en-us/help/4052725'', ''2018-01-16'', ''2019-07-09'', ''2024-07-09'', ''SQL Server 2014'', ''Service Pack 2 Cumulative Update 10''),
                    (12, 5563, ''SP2 CU9'', ''https://support.microsoft.com/en-us/help/4055557'', ''2017-12-18'', ''2019-07-09'', ''2024-07-09'', ''SQL Server 2014'', ''Service Pack 2 Cumulative Update 9''),
                    (12, 5557, ''SP2 CU8'', ''https://support.microsoft.com/en-us/help/4037356'', ''2017-10-16'', ''2019-07-09'', ''2024-07-09'', ''SQL Server 2014'', ''Service Pack 2 Cumulative Update 8''),
                    (12, 5556, ''SP2 CU7'', ''https://support.microsoft.com/en-us/help/4032541'', ''2017-08-28'', ''2019-07-09'', ''2024-07-09'', ''SQL Server 2014'', ''Service Pack 2 Cumulative Update 7''),
                    (12, 5553, ''SP2 CU6'', ''https://support.microsoft.com/en-us/help/4019094'', ''2017-08-08'', ''2019-07-09'', ''2024-07-09'', ''SQL Server 2014'', ''Service Pack 2 Cumulative Update 6''),
                    (12, 5546, ''SP2 CU5'', ''https://support.microsoft.com/en-us/help/4013098'', ''2017-04-17'', ''2019-07-09'', ''2024-07-09'', ''SQL Server 2014'', ''Service Pack 2 Cumulative Update 5''),
                    (12, 5540, ''SP2 CU4'', ''https://support.microsoft.com/en-us/help/4010394'', ''2017-02-21'', ''2019-07-09'', ''2024-07-09'', ''SQL Server 2014'', ''Service Pack 2 Cumulative Update 4''),
                    (12, 5538, ''SP2 CU3'', ''https://support.microsoft.com/en-us/help/3204388 '', ''2016-12-19'', ''2019-07-09'', ''2024-07-09'', ''SQL Server 2014'', ''Service Pack 2 Cumulative Update 3''),
                    (12, 5522, ''SP2 CU2'', ''https://support.microsoft.com/en-us/help/3188778 '', ''2016-10-17'', ''2019-07-09'', ''2024-07-09'', ''SQL Server 2014'', ''Service Pack 2 Cumulative Update 2''),
                    (12, 5511, ''SP2 CU1'', ''https://support.microsoft.com/en-us/help/3178925 '', ''2016-08-25'', ''2019-07-09'', ''2024-07-09'', ''SQL Server 2014'', ''Service Pack 2 Cumulative Update 1''),
                    (12, 5000, ''SP2 '', ''https://support.microsoft.com/en-us/help/3171021 '', ''2016-07-11'', ''2019-07-09'', ''2024-07-09'', ''SQL Server 2014'', ''Service Pack 2 ''),
                    (12, 4522, ''SP1 CU13'', ''https://support.microsoft.com/en-us/help/4019099'', ''2017-08-08'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 Cumulative Update 13''),
                    (12, 4511, ''SP1 CU12'', ''https://support.microsoft.com/en-us/help/4017793'', ''2017-04-17'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 Cumulative Update 12''),
                    (12, 4502, ''SP1 CU11'', ''https://support.microsoft.com/en-us/help/4010392'', ''2017-02-21'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 Cumulative Update 11''),
                    (12, 4491, ''SP1 CU10'', ''https://support.microsoft.com/en-us/help/3204399 '', ''2016-12-19'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 Cumulative Update 10''),
                    (12, 4474, ''SP1 CU9'', ''https://support.microsoft.com/en-us/help/3186964 '', ''2016-10-17'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 Cumulative Update 9''),
                    (12, 4468, ''SP1 CU8'', ''https://support.microsoft.com/en-us/help/3174038 '', ''2016-08-15'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 Cumulative Update 8''),
                    (12, 4459, ''SP1 CU7'', ''https://support.microsoft.com/en-us/help/3162659 '', ''2016-06-20'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 Cumulative Update 7''),
                    (12, 4457, ''SP1 CU6'', ''https://support.microsoft.com/en-us/help/3167392 '', ''2016-05-30'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 Cumulative Update 6''),
                    (12, 4449, ''SP1 CU6'', ''https://support.microsoft.com/en-us/help/3144524'', ''2016-04-18'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 Cumulative Update 6''),
                    (12, 4438, ''SP1 CU5'', ''https://support.microsoft.com/en-us/help/3130926'', ''2016-02-22'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 Cumulative Update 5''),
                    (12, 4436, ''SP1 CU4'', ''https://support.microsoft.com/en-us/help/3106660'', ''2015-12-21'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 Cumulative Update 4''),
                    (12, 4427, ''SP1 CU3'', ''https://support.microsoft.com/en-us/help/3094221'', ''2015-10-19'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 Cumulative Update 3''),
                    (12, 4422, ''SP1 CU2'', ''https://support.microsoft.com/en-us/help/3075950'', ''2015-08-17'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 Cumulative Update 2''),
                    (12, 4416, ''SP1 CU1'', ''https://support.microsoft.com/en-us/help/3067839'', ''2015-06-19'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 Cumulative Update 1''),
                    (12, 4213, ''SP1 MS15-058: GDR Security Update'', ''https://support.microsoft.com/en-us/help/3070446'', ''2015-07-14'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 MS15-058: GDR Security Update''),
                    (12, 4100, ''SP1 '', ''https://support.microsoft.com/en-us/help/3058865'', ''2015-05-04'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 ''),
                    (12, 2569, ''RTM CU14'', ''https://support.microsoft.com/en-us/help/3158271 '', ''2016-06-20'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM Cumulative Update 14''),
                    (12, 2568, ''RTM CU13'', ''https://support.microsoft.com/en-us/help/3144517'', ''2016-04-18'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM Cumulative Update 13''),
                    (12, 2564, ''RTM CU12'', ''https://support.microsoft.com/en-us/help/3130923'', ''2016-02-22'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM Cumulative Update 12''),
                    (12, 2560, ''RTM CU11'', ''https://support.microsoft.com/en-us/help/3106659'', ''2015-12-21'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM Cumulative Update 11''),
                    (12, 2556, ''RTM CU10'', ''https://support.microsoft.com/en-us/help/3094220'', ''2015-10-19'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM Cumulative Update 10''),
                    (12, 2553, ''RTM CU9'', ''https://support.microsoft.com/en-us/help/3075949'', ''2015-08-17'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM Cumulative Update 9''),
                    (12, 2548, ''RTM MS15-058: QFE Security Update'', ''https://support.microsoft.com/en-us/help/3045323'', ''2015-07-14'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM MS15-058: QFE Security Update''),
                    (12, 2546, ''RTM CU8'', ''https://support.microsoft.com/en-us/help/3067836'', ''2015-06-19'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM Cumulative Update 8''),
                    (12, 2495, ''RTM CU7'', ''https://support.microsoft.com/en-us/help/3046038'', ''2015-04-20'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM Cumulative Update 7''),
                    (12, 2480, ''RTM CU6'', ''https://support.microsoft.com/en-us/help/3031047'', ''2015-02-16'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM Cumulative Update 6''),
                    (12, 2456, ''RTM CU5'', ''https://support.microsoft.com/en-us/help/3011055'', ''2014-12-17'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM Cumulative Update 5''),
                    (12, 2430, ''RTM CU4'', ''https://support.microsoft.com/en-us/help/2999197'', ''2014-10-21'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM Cumulative Update 4''),
                    (12, 2402, ''RTM CU3'', ''https://support.microsoft.com/en-us/help/2984923'', ''2014-08-18'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM Cumulative Update 3''),
                    (12, 2381, ''RTM MS14-044: QFE Security Update'', ''https://support.microsoft.com/en-us/help/2977316'', ''2014-08-12'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM MS14-044: QFE Security Update''),
                    (12, 2370, ''RTM CU2'', ''https://support.microsoft.com/en-us/help/2967546'', ''2014-06-27'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM Cumulative Update 2''),
                    (12, 2342, ''RTM CU1'', ''https://support.microsoft.com/en-us/help/2931693'', ''2014-04-21'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM Cumulative Update 1''),
                    (12, 2269, ''RTM MS15-058: GDR Security Update '', ''https://support.microsoft.com/en-us/help/3045324'', ''2015-07-14'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM MS15-058: GDR Security Update ''),
                    (12, 2254, ''RTM MS14-044: GDR Security Update'', ''https://support.microsoft.com/en-us/help/2977315'', ''2014-08-12'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM MS14-044: GDR Security Update''),
                    (12, 2000, ''RTM '', '''', ''2014-04-01'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM ''),
                    (11, 7001, ''SP4 '', ''https://support.microsoft.com/en-us/help/4018073'', ''2017-10-02'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''Service Pack 4 ''),
                    (11, 6607, ''SP3 CU10'', ''https://support.microsoft.com/en-us/help/4025925'', ''2017-08-08'', ''2018-10-09'', ''2018-10-09'', ''SQL Server 2012'', ''Service Pack 3 Cumulative Update 10''),
                    (11, 6598, ''SP3 CU9'', ''https://support.microsoft.com/en-us/help/4016762'', ''2017-05-15'', ''2018-10-09'', ''2018-10-09'', ''SQL Server 2012'', ''Service Pack 3 Cumulative Update 9''),
                    (11, 6594, ''SP3 CU8'', ''https://support.microsoft.com/en-us/help/3205051 '', ''2017-03-20'', ''2018-10-09'', ''2018-10-09'', ''SQL Server 2012'', ''Service Pack 3 Cumulative Update 8''),
                    (11, 6579, ''SP3 CU7'', ''https://support.microsoft.com/en-us/help/3205051 '', ''2017-01-17'', ''2018-10-09'', ''2018-10-09'', ''SQL Server 2012'', ''Service Pack 3 Cumulative Update 7''),
                    (11, 6567, ''SP3 CU6'', ''https://support.microsoft.com/en-us/help/3194992 '', ''2016-11-17'', ''2018-10-09'', ''2018-10-09'', ''SQL Server 2012'', ''Service Pack 3 Cumulative Update 6''),
                    (11, 6544, ''SP3 CU5'', ''https://support.microsoft.com/en-us/help/3180915 '', ''2016-09-19'', ''2018-10-09'', ''2018-10-09'', ''SQL Server 2012'', ''Service Pack 3 Cumulative Update 5''),
                    (11, 6540, ''SP3 CU4'', ''https://support.microsoft.com/en-us/help/3165264 '', ''2016-07-18'', ''2018-10-09'', ''2018-10-09'', ''SQL Server 2012'', ''Service Pack 3 Cumulative Update 4''),
                    (11, 6537, ''SP3 CU3'', ''https://support.microsoft.com/en-us/help/3152635 '', ''2016-05-16'', ''2018-10-09'', ''2018-10-09'', ''SQL Server 2012'', ''Service Pack 3 Cumulative Update 3''),
                    (11, 6523, ''SP3 CU2'', ''https://support.microsoft.com/en-us/help/3137746'', ''2016-03-21'', ''2018-10-09'', ''2018-10-09'', ''SQL Server 2012'', ''Service Pack 3 Cumulative Update 2''),
                    (11, 6518, ''SP3 CU1'', ''https://support.microsoft.com/en-us/help/3123299'', ''2016-01-19'', ''2018-10-09'', ''2018-10-09'', ''SQL Server 2012'', ''Service Pack 3 Cumulative Update 1''),
                    (11, 6020, ''SP3 '', ''https://support.microsoft.com/en-us/help/3072779'', ''2015-11-20'', ''2018-10-09'', ''2018-10-09'', ''SQL Server 2012'', ''Service Pack 3 ''),
                    (11, 5678, ''SP2 CU16'', ''https://support.microsoft.com/en-us/help/3205416 '', ''2016-11-17'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 16''),
                    (11, 5676, ''SP2 CU15'', ''https://support.microsoft.com/en-us/help/3205416 '', ''2016-11-17'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 15''),
                    (11, 5657, ''SP2 CU14'', ''https://support.microsoft.com/en-us/help/3180914 '', ''2016-09-19'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 14''),
                    (11, 5655, ''SP2 CU13'', ''https://support.microsoft.com/en-us/help/3165266 '', ''2016-07-18'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 13''),
                    (11, 5649, ''SP2 CU12'', ''https://support.microsoft.com/en-us/help/3152637 '', ''2016-05-16'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 12''),
                    (11, 5646, ''SP2 CU11'', ''https://support.microsoft.com/en-us/help/3137745'', ''2016-03-21'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 11''),
                    (11, 5644, ''SP2 CU10'', ''https://support.microsoft.com/en-us/help/3120313'', ''2016-01-19'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 10''),
                    (11, 5641, ''SP2 CU9'', ''https://support.microsoft.com/en-us/help/3098512'', ''2015-11-16'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 9''),
                    (11, 5634, ''SP2 CU8'', ''https://support.microsoft.com/en-us/help/3082561'', ''2015-09-21'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 8''),
                    (11, 5623, ''SP2 CU7'', ''https://support.microsoft.com/en-us/help/3072100'', ''2015-07-20'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 7''),
                    (11, 5613, ''SP2 MS15-058: QFE Security Update'', ''https://support.microsoft.com/en-us/help/3045319'', ''2015-07-14'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 MS15-058: QFE Security Update''),
                    (11, 5592, ''SP2 CU6'', ''https://support.microsoft.com/en-us/help/3052468'', ''2015-05-18'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 6''),
                    (11, 5582, ''SP2 CU5'', ''https://support.microsoft.com/en-us/help/3037255'', ''2015-03-16'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 5''),
                    (11, 5569, ''SP2 CU4'', ''https://support.microsoft.com/en-us/help/3007556'', ''2015-01-19'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 4''),
                    (11, 5556, ''SP2 CU3'', ''https://support.microsoft.com/en-us/help/3002049'', ''2014-11-17'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 3''),
                    (11, 5548, ''SP2 CU2'', ''https://support.microsoft.com/en-us/help/2983175'', ''2014-09-15'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 2''),
                    (11, 5532, ''SP2 CU1'', ''https://support.microsoft.com/en-us/help/2976982'', ''2014-07-23'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 1''),
                    (11, 5343, ''SP2 MS15-058: GDR Security Update'', ''https://support.microsoft.com/en-us/help/3045321'', ''2015-07-14'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 MS15-058: GDR Security Update''),
                    (11, 5058, ''SP2 '', ''https://support.microsoft.com/en-us/help/2958429'', ''2014-06-10'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 ''),
                    (11, 3513, ''SP1 MS15-058: QFE Security Update'', ''https://support.microsoft.com/en-us/help/3045317'', ''2015-07-14'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 MS15-058: QFE Security Update''),
                    (11, 3482, ''SP1 CU13'', ''https://support.microsoft.com/en-us/help/3002044'', ''2014-11-17'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 Cumulative Update 13''),
                    (11, 3470, ''SP1 CU12'', ''https://support.microsoft.com/en-us/help/2991533'', ''2014-09-15'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 Cumulative Update 12''),
                    (11, 3460, ''SP1 MS14-044: QFE Security Update '', ''https://support.microsoft.com/en-us/help/2977325'', ''2014-08-12'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 MS14-044: QFE Security Update ''),
                    (11, 3449, ''SP1 CU11'', ''https://support.microsoft.com/en-us/help/2975396'', ''2014-07-21'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 Cumulative Update 11''),
                    (11, 3431, ''SP1 CU10'', ''https://support.microsoft.com/en-us/help/2954099'', ''2014-05-19'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 Cumulative Update 10''),
                    (11, 3412, ''SP1 CU9'', ''https://support.microsoft.com/en-us/help/2931078'', ''2014-03-17'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 Cumulative Update 9''),
                    (11, 3401, ''SP1 CU8'', ''https://support.microsoft.com/en-us/help/2917531'', ''2014-01-20'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 Cumulative Update 8''),
                    (11, 3393, ''SP1 CU7'', ''https://support.microsoft.com/en-us/help/2894115'', ''2013-11-18'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 Cumulative Update 7''),
                    (11, 3381, ''SP1 CU6'', ''https://support.microsoft.com/en-us/help/2874879'', ''2013-09-16'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 Cumulative Update 6''),
                    (11, 3373, ''SP1 CU5'', ''https://support.microsoft.com/en-us/help/2861107'', ''2013-07-15'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 Cumulative Update 5''),
                    (11, 3368, ''SP1 CU4'', ''https://support.microsoft.com/en-us/help/2833645'', ''2013-05-30'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 Cumulative Update 4''),
                    (11, 3349, ''SP1 CU3'', ''https://support.microsoft.com/en-us/help/2812412'', ''2013-03-18'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 Cumulative Update 3''),
                    (11, 3339, ''SP1 CU2'', ''https://support.microsoft.com/en-us/help/2790947'', ''2013-01-21'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 Cumulative Update 2''),
                    (11, 3321, ''SP1 CU1'', ''https://support.microsoft.com/en-us/help/2765331'', ''2012-11-20'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 Cumulative Update 1''),
                    (11, 3156, ''SP1 MS15-058: GDR Security Update'', ''https://support.microsoft.com/en-us/help/3045318'', ''2015-07-14'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 MS15-058: GDR Security Update''),
                    (11, 3153, ''SP1 MS14-044: GDR Security Update'', ''https://support.microsoft.com/en-us/help/2977326'', ''2014-08-12'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 MS14-044: GDR Security Update''),
                    (11, 3000, ''SP1 '', ''https://support.microsoft.com/en-us/help/2674319'', ''2012-11-07'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 ''),
                    (11, 2424, ''RTM CU11'', ''https://support.microsoft.com/en-us/help/2908007'', ''2013-12-16'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''RTM Cumulative Update 11''),
                    (11, 2420, ''RTM CU10'', ''https://support.microsoft.com/en-us/help/2891666'', ''2013-10-21'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''RTM Cumulative Update 10''),
                    (11, 2419, ''RTM CU9'', ''https://support.microsoft.com/en-us/help/2867319'', ''2013-08-20'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''RTM Cumulative Update 9''),
                    (11, 2410, ''RTM CU8'', ''https://support.microsoft.com/en-us/help/2844205'', ''2013-06-17'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''RTM Cumulative Update 8''),
                    (11, 2405, ''RTM CU7'', ''https://support.microsoft.com/en-us/help/2823247'', ''2013-04-15'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''RTM Cumulative Update 7''),
                    (11, 2401, ''RTM CU6'', ''https://support.microsoft.com/en-us/help/2728897'', ''2013-02-18'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''RTM Cumulative Update 6''),
                    (11, 2395, ''RTM CU5'', ''https://support.microsoft.com/en-us/help/2777772'', ''2012-12-17'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''RTM Cumulative Update 5''),
                    (11, 2383, ''RTM CU4'', ''https://support.microsoft.com/en-us/help/2758687'', ''2012-10-15'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''RTM Cumulative Update 4''),
                    (11, 2376, ''RTM MS12-070: QFE Security Update'', ''https://support.microsoft.com/en-us/help/2716441'', ''2012-10-09'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''RTM MS12-070: QFE Security Update''),
                    (11, 2332, ''RTM CU3'', ''https://support.microsoft.com/en-us/help/2723749'', ''2012-08-31'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''RTM Cumulative Update 3''),
                    (11, 2325, ''RTM CU2'', ''https://support.microsoft.com/en-us/help/2703275'', ''2012-06-18'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''RTM Cumulative Update 2''),
                    (11, 2316, ''RTM CU1'', ''https://support.microsoft.com/en-us/help/2679368'', ''2012-04-12'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''RTM Cumulative Update 1''),
                    (11, 2218, ''RTM MS12-070: GDR Security Update'', ''https://support.microsoft.com/en-us/help/2716442'', ''2012-10-09'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''RTM MS12-070: GDR Security Update''),
                    (11, 2100, ''RTM '', '''', ''2012-03-06'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''RTM ''),
                    (10, 6529, ''SP3 MS15-058: QFE Security Update'', ''https://support.microsoft.com/en-us/help/3045314'', ''2015-07-14'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''Service Pack 3 MS15-058: QFE Security Update''),
                    (10, 6220, ''SP3 MS15-058: QFE Security Update'', ''https://support.microsoft.com/en-us/help/3045316'', ''2015-07-14'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''Service Pack 3 MS15-058: QFE Security Update''),
                    (10, 6000, ''SP3 '', ''https://support.microsoft.com/en-us/help/2979597'', ''2014-09-26'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''Service Pack 3 ''),
                    (10, 4339, ''SP2 MS15-058: QFE Security Update'', ''https://support.microsoft.com/en-us/help/3045312'', ''2015-07-14'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 MS15-058: QFE Security Update''),
                    (10, 4321, ''SP2 MS14-044: QFE Security Update'', ''https://support.microsoft.com/en-us/help/2977319'', ''2014-08-14'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 MS14-044: QFE Security Update''),
                    (10, 4319, ''SP2 CU13'', ''https://support.microsoft.com/en-us/help/2967540'', ''2014-06-30'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 Cumulative Update 13''),
                    (10, 4305, ''SP2 CU12'', ''https://support.microsoft.com/en-us/help/2938478'', ''2014-04-21'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 Cumulative Update 12''),
                    (10, 4302, ''SP2 CU11'', ''https://support.microsoft.com/en-us/help/2926028'', ''2014-02-18'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 Cumulative Update 11''),
                    (10, 4297, ''SP2 CU10'', ''https://support.microsoft.com/en-us/help/2908087'', ''2013-12-17'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 Cumulative Update 10''),
                    (10, 4295, ''SP2 CU9'', ''https://support.microsoft.com/en-us/help/2887606'', ''2013-10-28'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 Cumulative Update 9''),
                    (10, 4290, ''SP2 CU8'', ''https://support.microsoft.com/en-us/help/2871401'', ''2013-08-22'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 Cumulative Update 8''),
                    (10, 4285, ''SP2 CU7'', ''https://support.microsoft.com/en-us/help/2844090'', ''2013-06-17'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 Cumulative Update 7''),
                    (10, 4279, ''SP2 CU6'', ''https://support.microsoft.com/en-us/help/2830140'', ''2013-04-15'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 Cumulative Update 6''),
                    (10, 4276, ''SP2 CU5'', ''https://support.microsoft.com/en-us/help/2797460'', ''2013-02-18'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 Cumulative Update 5''),
                    (10, 4270, ''SP2 CU4'', ''https://support.microsoft.com/en-us/help/2777358'', ''2012-12-17'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 Cumulative Update 4''),
                    (10, 4266, ''SP2 CU3'', ''https://support.microsoft.com/en-us/help/2754552'', ''2012-10-15'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 Cumulative Update 3''),
                    (10, 4263, ''SP2 CU2'', ''https://support.microsoft.com/en-us/help/2740411'', ''2012-08-31'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 Cumulative Update 2''),
                    (10, 4260, ''SP2 CU1'', ''https://support.microsoft.com/en-us/help/2720425'', ''2012-07-24'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 Cumulative Update 1''),
                    (10, 4042, ''SP2 MS15-058: GDR Security Update'', ''https://support.microsoft.com/en-us/help/3045313'', ''2015-07-14'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 MS15-058: GDR Security Update''),
                    (10, 4033, ''SP2 MS14-044: GDR Security Update'', ''https://support.microsoft.com/en-us/help/2977320'', ''2014-08-12'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 MS14-044: GDR Security Update''),
                    (10, 4000, ''SP2 '', ''https://support.microsoft.com/en-us/help/2630458'', ''2012-07-26'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 ''),
                    (10, 2881, ''SP1 CU14'', ''https://support.microsoft.com/en-us/help/2868244'', ''2013-08-08'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 Cumulative Update 14''),
                    (10, 2876, ''SP1 CU13'', ''https://support.microsoft.com/en-us/help/2855792'', ''2013-06-17'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 Cumulative Update 13''),
                    (10, 2874, ''SP1 CU12'', ''https://support.microsoft.com/en-us/help/2828727'', ''2013-04-15'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 Cumulative Update 12''),
                    (10, 2869, ''SP1 CU11'', ''https://support.microsoft.com/en-us/help/2812683'', ''2013-02-18'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 Cumulative Update 11''),
                    (10, 2868, ''SP1 CU10'', ''https://support.microsoft.com/en-us/help/2783135'', ''2012-12-17'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 Cumulative Update 10''),
                    (10, 2866, ''SP1 CU9'', ''https://support.microsoft.com/en-us/help/2756574'', ''2012-10-15'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 Cumulative Update 9''),
                    (10, 2861, ''SP1 MS12-070: QFE Security Update'', ''https://support.microsoft.com/en-us/help/2716439'', ''2012-10-09'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 MS12-070: QFE Security Update''),
                    (10, 2822, ''SP1 CU8'', ''https://support.microsoft.com/en-us/help/2723743'', ''2012-08-31'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 Cumulative Update 8''),
                    (10, 2817, ''SP1 CU7'', ''https://support.microsoft.com/en-us/help/2703282'', ''2012-06-18'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 Cumulative Update 7''),
                    (10, 2811, ''SP1 CU6'', ''https://support.microsoft.com/en-us/help/2679367'', ''2012-04-16'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 Cumulative Update 6''),
                    (10, 2806, ''SP1 CU5'', ''https://support.microsoft.com/en-us/help/2659694'', ''2012-02-22'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 Cumulative Update 5''),
                    (10, 2796, ''SP1 CU4'', ''https://support.microsoft.com/en-us/help/2633146'', ''2011-12-19'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 Cumulative Update 4''),
                    (10, 2789, ''SP1 CU3'', ''https://support.microsoft.com/en-us/help/2591748'', ''2011-10-17'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 Cumulative Update 3''),
                    (10, 2772, ''SP1 CU2'', ''https://support.microsoft.com/en-us/help/2567714'', ''2011-08-15'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 Cumulative Update 2''),
                    (10, 2769, ''SP1 CU1'', ''https://support.microsoft.com/en-us/help/2544793'', ''2011-07-18'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 Cumulative Update 1''),
                    (10, 2550, ''SP1 MS12-070: GDR Security Update'', ''https://support.microsoft.com/en-us/help/2754849'', ''2012-10-09'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 MS12-070: GDR Security Update''),
                    (10, 2500, ''SP1 '', ''https://support.microsoft.com/en-us/help/2528583'', ''2011-07-12'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 ''),
                    (10, 1815, ''RTM CU13'', ''https://support.microsoft.com/en-us/help/2679366'', ''2012-04-16'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM Cumulative Update 13''),
                    (10, 1810, ''RTM CU12'', ''https://support.microsoft.com/en-us/help/2659692'', ''2012-02-21'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM Cumulative Update 12''),
                    (10, 1809, ''RTM CU11'', ''https://support.microsoft.com/en-us/help/2633145'', ''2011-12-19'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM Cumulative Update 11''),
                    (10, 1807, ''RTM CU10'', ''https://support.microsoft.com/en-us/help/2591746'', ''2011-10-17'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM Cumulative Update 10''),
                    (10, 1804, ''RTM CU9'', ''https://support.microsoft.com/en-us/help/2567713'', ''2011-08-15'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM Cumulative Update 9''),
                    (10, 1797, ''RTM CU8'', ''https://support.microsoft.com/en-us/help/2534352'', ''2011-06-20'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM Cumulative Update 8''),
                    (10, 1790, ''RTM MS11-049: QFE Security Update'', ''https://support.microsoft.com/en-us/help/2494086'', ''2011-06-14'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM MS11-049: QFE Security Update''),
                    (10, 1777, ''RTM CU7'', ''https://support.microsoft.com/en-us/help/2507770'', ''2011-04-18'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM Cumulative Update 7''),
                    (10, 1765, ''RTM CU6'', ''https://support.microsoft.com/en-us/help/2489376'', ''2011-02-21'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM Cumulative Update 6''),
                    (10, 1753, ''RTM CU5'', ''https://support.microsoft.com/en-us/help/2438347'', ''2010-12-20'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM Cumulative Update 5''),
                    (10, 1746, ''RTM CU4'', ''https://support.microsoft.com/en-us/help/2345451'', ''2010-10-18'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM Cumulative Update 4''),
                    (10, 1734, ''RTM CU3'', ''https://support.microsoft.com/en-us/help/2261464'', ''2010-08-16'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM Cumulative Update 3''),
                    (10, 1720, ''RTM CU2'', ''https://support.microsoft.com/en-us/help/2072493'', ''2010-06-21'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM Cumulative Update 2''),
                    (10, 1702, ''RTM CU1'', ''https://support.microsoft.com/en-us/help/981355'', ''2010-05-18'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM Cumulative Update 1''),
                    (10, 1617, ''RTM MS11-049: GDR Security Update'', ''https://support.microsoft.com/en-us/help/2494088'', ''2011-06-14'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM MS11-049: GDR Security Update''),
                    (10, 1600, ''RTM '', '''', ''2010-05-10'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM ''),
                    (10, 6535, ''SP3 MS15-058: QFE Security Update'', ''https://support.microsoft.com/en-us/help/3045308'', ''2015-07-14'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 MS15-058: QFE Security Update''),
                    (10, 6241, ''SP3 MS15-058: GDR Security Update'', ''https://support.microsoft.com/en-us/help/3045311'', ''2015-07-14'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 MS15-058: GDR Security Update''),
                    (10, 5890, ''SP3 MS15-058: QFE Security Update'', ''https://support.microsoft.com/en-us/help/3045303'', ''2015-07-14'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 MS15-058: QFE Security Update''),
                    (10, 5869, ''SP3 MS14-044: QFE Security Update'', ''https://support.microsoft.com/en-us/help/2984340, https://support.microsoft.com/en-us/help/2977322'', ''2014-08-12'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 MS14-044: QFE Security Update''),
                    (10, 5861, ''SP3 CU17'', ''https://support.microsoft.com/en-us/help/2958696'', ''2014-05-19'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 17''),
                    (10, 5852, ''SP3 CU16'', ''https://support.microsoft.com/en-us/help/2936421'', ''2014-03-17'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 16''),
                    (10, 5850, ''SP3 CU15'', ''https://support.microsoft.com/en-us/help/2923520'', ''2014-01-20'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 15''),
                    (10, 5848, ''SP3 CU14'', ''https://support.microsoft.com/en-us/help/2893410'', ''2013-11-18'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 14''),
                    (10, 5846, ''SP3 CU13'', ''https://support.microsoft.com/en-us/help/2880350'', ''2013-09-16'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 13''),
                    (10, 5844, ''SP3 CU12'', ''https://support.microsoft.com/en-us/help/2863205'', ''2013-07-15'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 12''),
                    (10, 5840, ''SP3 CU11'', ''https://support.microsoft.com/en-us/help/2834048'', ''2013-05-20'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 11''),
                    (10, 5835, ''SP3 CU10'', ''https://support.microsoft.com/en-us/help/2814783'', ''2013-03-18'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 10''),
                    (10, 5829, ''SP3 CU9'', ''https://support.microsoft.com/en-us/help/2799883'', ''2013-01-21'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 9''),
                    (10, 5828, ''SP3 CU8'', ''https://support.microsoft.com/en-us/help/2771833'', ''2012-11-19'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 8''),
                    (10, 5826, ''SP3 MS12-070: QFE Security Update'', ''https://support.microsoft.com/en-us/help/2716435'', ''2012-10-09'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 MS12-070: QFE Security Update''),
                    (10, 5794, ''SP3 CU7'', ''https://support.microsoft.com/en-us/help/2738350'', ''2012-09-17'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 7''),
                    (10, 5788, ''SP3 CU6'', ''https://support.microsoft.com/en-us/help/2715953'', ''2012-07-16'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 6''),
                    (10, 5785, ''SP3 CU5'', ''https://support.microsoft.com/en-us/help/2696626'', ''2012-05-21'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 5''),
                    (10, 5775, ''SP3 CU4'', ''https://support.microsoft.com/en-us/help/2673383'', ''2012-03-19'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 4''),
                    (10, 5770, ''SP3 CU3'', ''https://support.microsoft.com/en-us/help/2648098'', ''2012-01-16'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 3''),
                    (10, 5768, ''SP3 CU2'', ''https://support.microsoft.com/en-us/help/2633143'', ''2011-11-21'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 2''),
                    (10, 5766, ''SP3 CU1'', ''https://support.microsoft.com/en-us/help/2617146'', ''2011-10-17'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 1''),
                    (10, 5538, ''SP3 MS15-058: GDR Security Update'', ''https://support.microsoft.com/en-us/help/3045305'', ''2015-07-14'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 MS15-058: GDR Security Update''),
                    (10, 5520, ''SP3 MS14-044: GDR Security Update'', ''https://support.microsoft.com/en-us/help/2977321'', ''2014-08-12'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 MS14-044: GDR Security Update''),
                    (10, 5512, ''SP3 MS12-070: GDR Security Update'', ''https://support.microsoft.com/en-us/help/2716436'', ''2012-10-09'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 MS12-070: GDR Security Update''),
                    (10, 5500, ''SP3 '', ''https://support.microsoft.com/en-us/help/2546951'', ''2011-10-06'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 ''),
                    (10, 4371, ''SP2 MS12-070: QFE Security Update'', ''https://support.microsoft.com/en-us/help/2716433'', ''2012-10-09'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 MS12-070: QFE Security Update''),
                    (10, 4333, ''SP2 CU11'', ''https://support.microsoft.com/en-us/help/2715951'', ''2012-07-16'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 Cumulative Update 11''),
                    (10, 4332, ''SP2 CU10'', ''https://support.microsoft.com/en-us/help/2696625'', ''2012-05-21'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 Cumulative Update 10''),
                    (10, 4330, ''SP2 CU9'', ''https://support.microsoft.com/en-us/help/2673382'', ''2012-03-19'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 Cumulative Update 9''),
                    (10, 4326, ''SP2 CU8'', ''https://support.microsoft.com/en-us/help/2648096'', ''2012-01-16'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 Cumulative Update 8''),
                    (10, 4323, ''SP2 CU7'', ''https://support.microsoft.com/en-us/help/2617148'', ''2011-11-21'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 Cumulative Update 7''),
                    (10, 4321, ''SP2 CU6'', ''https://support.microsoft.com/en-us/help/2582285'', ''2011-09-19'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 Cumulative Update 6''),
                    (10, 4316, ''SP2 CU5'', ''https://support.microsoft.com/en-us/help/2555408'', ''2011-07-18'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 Cumulative Update 5''),
                    (10, 4311, ''SP2 MS11-049: QFE Security Update'', ''https://support.microsoft.com/en-us/help/2494094'', ''2011-06-14'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 MS11-049: QFE Security Update''),
                    (10, 4285, ''SP2 CU4'', ''https://support.microsoft.com/en-us/help/2527180'', ''2011-05-16'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 Cumulative Update 4''),
                    (10, 4279, ''SP2 CU3'', ''https://support.microsoft.com/en-us/help/2498535'', ''2011-03-17'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 Cumulative Update 3''),
                    (10, 4272, ''SP2 CU2'', ''https://support.microsoft.com/en-us/help/2467239'', ''2011-01-17'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 Cumulative Update 2''),
                    (10, 4266, ''SP2 CU1'', ''https://support.microsoft.com/en-us/help/2289254'', ''2010-11-15'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 Cumulative Update 1''),
                    (10, 4067, ''SP2 MS12-070: GDR Security Update'', ''https://support.microsoft.com/en-us/help/2716434'', ''2012-10-09'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 MS12-070: GDR Security Update''),
                    (10, 4064, ''SP2 MS11-049: GDR Security Update'', ''https://support.microsoft.com/en-us/help/2494089'', ''2011-06-14'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 MS11-049: GDR Security Update''),
                    (10, 4000, ''SP2 '', ''https://support.microsoft.com/en-us/help/2285068'', ''2010-09-29'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 ''),
                    (10, 2850, ''SP1 CU16'', ''https://support.microsoft.com/en-us/help/2582282'', ''2011-09-19'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 16''),
                    (10, 2847, ''SP1 CU15'', ''https://support.microsoft.com/en-us/help/2555406'', ''2011-07-18'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 15''),
                    (10, 2841, ''SP1 MS11-049: QFE Security Update'', ''https://support.microsoft.com/en-us/help/2494100'', ''2011-06-14'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 MS11-049: QFE Security Update''),
                    (10, 2821, ''SP1 CU14'', ''https://support.microsoft.com/en-us/help/2527187'', ''2011-05-16'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 14''),
                    (10, 2816, ''SP1 CU13'', ''https://support.microsoft.com/en-us/help/2497673'', ''2011-03-17'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 13''),
                    (10, 2808, ''SP1 CU12'', ''https://support.microsoft.com/en-us/help/2467236'', ''2011-01-17'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 12''),
                    (10, 2804, ''SP1 CU11'', ''https://support.microsoft.com/en-us/help/2413738'', ''2010-11-15'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 11''),
                    (10, 2799, ''SP1 CU10'', ''https://support.microsoft.com/en-us/help/2279604'', ''2010-09-20'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 10''),
                    (10, 2789, ''SP1 CU9'', ''https://support.microsoft.com/en-us/help/2083921'', ''2010-07-19'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 9''),
                    (10, 2775, ''SP1 CU8'', ''https://support.microsoft.com/en-us/help/981702'', ''2010-05-17'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 8''),
                    (10, 2766, ''SP1 CU7'', ''https://support.microsoft.com/en-us/help/979065'', ''2010-03-26'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 7''),
                    (10, 2757, ''SP1 CU6'', ''https://support.microsoft.com/en-us/help/977443'', ''2010-01-18'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 6''),
                    (10, 2746, ''SP1 CU5'', ''https://support.microsoft.com/en-us/help/975977'', ''2009-11-16'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 5''),
                    (10, 2734, ''SP1 CU4'', ''https://support.microsoft.com/en-us/help/973602'', ''2009-09-21'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 4''),
                    (10, 2723, ''SP1 CU3'', ''https://support.microsoft.com/en-us/help/971491'', ''2009-07-20'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 3''),
                    (10, 2714, ''SP1 CU2'', ''https://support.microsoft.com/en-us/help/970315'', ''2009-05-18'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 2''),
                    (10, 2710, ''SP1 CU1'', ''https://support.microsoft.com/en-us/help/969099'', ''2009-04-16'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 1''),
                    (10, 2573, ''SP1 MS11-049: GDR Security update'', ''https://support.microsoft.com/en-us/help/2494096'', ''2011-06-14'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 MS11-049: GDR Security update''),
                    (10, 2531, ''SP1 '', '''', ''2009-04-01'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 ''),
                    (10, 1835, ''RTM CU10'', ''https://support.microsoft.com/en-us/help/979064'', ''2010-03-15'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008'', ''RTM Cumulative Update 10''),
                    (10, 1828, ''RTM CU9'', ''https://support.microsoft.com/en-us/help/977444'', ''2010-01-18'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008'', ''RTM Cumulative Update 9''),
                    (10, 1823, ''RTM CU8'', ''https://support.microsoft.com/en-us/help/975976'', ''2009-11-16'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008'', ''RTM Cumulative Update 8''),
                    (10, 1818, ''RTM CU7'', ''https://support.microsoft.com/en-us/help/973601'', ''2009-09-21'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008'', ''RTM Cumulative Update 7''),
                    (10, 1812, ''RTM CU6'', ''https://support.microsoft.com/en-us/help/971490'', ''2009-07-20'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008'', ''RTM Cumulative Update 6''),
                    (10, 1806, ''RTM CU5'', ''https://support.microsoft.com/en-us/help/969531'', ''2009-05-18'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008'', ''RTM Cumulative Update 5''),
                    (10, 1798, ''RTM CU4'', ''https://support.microsoft.com/en-us/help/963036'', ''2009-03-16'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008'', ''RTM Cumulative Update 4''),
                    (10, 1787, ''RTM CU3'', ''https://support.microsoft.com/en-us/help/960484'', ''2009-01-19'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008'', ''RTM Cumulative Update 3''),
                    (10, 1779, ''RTM CU2'', ''https://support.microsoft.com/en-us/help/958186'', ''2008-11-19'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008'', ''RTM Cumulative Update 2''),
                    (10, 1763, ''RTM CU1'', ''https://support.microsoft.com/en-us/help/956717'', ''2008-09-22'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008'', ''RTM Cumulative Update 1''),
                    (10, 1600, ''RTM '', '''', ''2008-08-06'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008'', ''RTM '');'

                    EXEC sp_ExecuteSQL @InsertSQL

                END

            END

        ELSE 

            BEGIN

            SET @CreateDB = 'CREATE DATABASE ' + QUOTENAME(@DatabaseName) + ''

            EXEC sp_executesql @CreateDB

            SET @InsertSQL = 

                    'INSERT INTO ' + QUOTENAME(@DatabaseName) + '.dbo.SqlServerVersions
                    (MajorVersionNumber, MinorVersionNumber, Branch, [Url], ReleaseDate, MainstreamSupportEndDate, ExtendedSupportEndDate, MajorVersionName, MinorVersionName)
                    VALUES
                    (14, 3037, ''RTM CU10'', ''https://support.microsoft.com/en-us/help/4342123'', ''2018-08-27'', ''2022-10-11'', ''2027-10-12'', ''SQL Server 2017'', ''RTM Cumulative Update 10''),
                    (14, 3030, ''RTM CU9'', ''https://support.microsoft.com/en-us/help/4341265'', ''2018-07-18'', ''2022-10-11'', ''2027-10-12'', ''SQL Server 2017'', ''RTM Cumulative Update 9''),
                    (14, 3029, ''RTM CU8'', ''https://support.microsoft.com/en-us/help/4338363'', ''2018-06-21'', ''2022-10-11'', ''2027-10-12'', ''SQL Server 2017'', ''RTM Cumulative Update 8''),
                    (14, 3026, ''RTM CU7'', ''https://support.microsoft.com/en-us/help/4229789'', ''2018-05-23'', ''2022-10-11'', ''2027-10-12'', ''SQL Server 2017'', ''RTM Cumulative Update 7''),
                    (14, 3025, ''RTM CU6'', ''https://support.microsoft.com/en-us/help/4101464'', ''2018-04-17'', ''2022-10-11'', ''2027-10-12'', ''SQL Server 2017'', ''RTM Cumulative Update 6''),
                    (14, 3023, ''RTM CU5'', ''https://support.microsoft.com/en-us/help/4092643'', ''2018-03-20'', ''2022-10-11'', ''2027-10-12'', ''SQL Server 2017'', ''RTM Cumulative Update 5''),
                    (14, 3022, ''RTM CU4'', ''https://support.microsoft.com/en-us/help/4056498'', ''2018-02-20'', ''2022-10-11'', ''2027-10-12'', ''SQL Server 2017'', ''RTM Cumulative Update 4''),
                    (14, 3015, ''RTM CU3'', ''https://support.microsoft.com/en-us/help/4052987'', ''2018-01-04'', ''2022-10-11'', ''2027-10-12'', ''SQL Server 2017'', ''RTM Cumulative Update 3''),
                    (14, 3008, ''RTM CU2'', ''https://support.microsoft.com/en-us/help/4052574'', ''2017-11-28'', ''2022-10-11'', ''2027-10-12'', ''SQL Server 2017'', ''RTM Cumulative Update 2''),
                    (14, 3006, ''RTM CU1'', ''https://support.microsoft.com/en-us/help/4038634'', ''2017-10-24'', ''2022-10-11'', ''2027-10-12'', ''SQL Server 2017'', ''RTM Cumulative Update 1''),
                    (14, 1000, ''RTM '', '''', ''2017-10-02'', ''2022-10-11'', ''2027-10-12'', ''SQL Server 2017'', ''RTM ''),
                    (13, 5201, ''SP2 CU2 + Security Update'', ''https://support.microsoft.com/en-us/help/4458621'', ''2018-08-21'', ''2021-07-13'', ''2026-07-14'', ''SQL Server 2016'', ''Service Pack 2 Cumulative Update 2 + Security Update''),
                    (13, 5153, ''SP2 CU2'', ''https://support.microsoft.com/en-us/help/4340355'', ''2018-07-16'', ''2021-07-13'', ''2026-07-14'', ''SQL Server 2016'', ''Service Pack 2 Cumulative Update 2''),
                    (13, 5149, ''SP2 CU1'', ''https://support.microsoft.com/en-us/help/4135048'', ''2018-05-30'', ''2021-07-13'', ''2026-07-14'', ''SQL Server 2016'', ''Service Pack 2 Cumulative Update 1''),
                    (13, 5026, ''SP2 '', ''https://support.microsoft.com/en-us/help/4052908'', ''2018-04-24'', ''2021-07-13'', ''2026-07-14'', ''SQL Server 2016'', ''Service Pack 2 ''),
                    (13, 4514, ''SP1 CU10'', ''https://support.microsoft.com/en-us/help/4341569'', ''2018-07-16'', ''2019-07-09'', ''2019-07-09'', ''SQL Server 2016'', ''Service Pack 1 Cumulative Update 10''),
                    (13, 4502, ''SP1 CU9'', ''https://support.microsoft.com/en-us/help/4100997'', ''2018-05-30'', ''2019-07-09'', ''2019-07-09'', ''SQL Server 2016'', ''Service Pack 1 Cumulative Update 9''),
                    (13, 4474, ''SP1 CU8'', ''https://support.microsoft.com/en-us/help/4077064'', ''2018-03-19'', ''2019-07-09'', ''2019-07-09'', ''SQL Server 2016'', ''Service Pack 1 Cumulative Update 8''),
                    (13, 4466, ''SP1 CU7'', ''https://support.microsoft.com/en-us/help/4057119'', ''2018-01-04'', ''2019-07-09'', ''2019-07-09'', ''SQL Server 2016'', ''Service Pack 1 Cumulative Update 7''),
                    (13, 4457, ''SP1 CU6'', ''https://support.microsoft.com/en-us/help/4037354'', ''2017-11-20'', ''2019-07-09'', ''2019-07-09'', ''SQL Server 2016'', ''Service Pack 1 Cumulative Update 6''),
                    (13, 4451, ''SP1 CU5'', ''https://support.microsoft.com/en-us/help/4024305'', ''2017-09-18'', ''2019-07-09'', ''2019-07-09'', ''SQL Server 2016'', ''Service Pack 1 Cumulative Update 5''),
                    (13, 4446, ''SP1 CU4'', ''https://support.microsoft.com/en-us/help/4024305'', ''2017-08-08'', ''2019-07-09'', ''2019-07-09'', ''SQL Server 2016'', ''Service Pack 1 Cumulative Update 4''),
                    (13, 4435, ''SP1 CU3'', ''https://support.microsoft.com/en-us/help/4019916'', ''2017-05-15'', ''2019-07-09'', ''2019-07-09'', ''SQL Server 2016'', ''Service Pack 1 Cumulative Update 3''),
                    (13, 4422, ''SP1 CU2'', ''https://support.microsoft.com/en-us/help/4013106'', ''2017-03-20'', ''2019-07-09'', ''2019-07-09'', ''SQL Server 2016'', ''Service Pack 1 Cumulative Update 2''),
                    (13, 4411, ''SP1 CU1'', ''https://support.microsoft.com/en-us/help/3208177'', ''2017-01-17'', ''2019-07-09'', ''2019-07-09'', ''SQL Server 2016'', ''Service Pack 1 Cumulative Update 1''),
                    (13, 4224, ''SP1 CU10 + Security Update'', ''https://support.microsoft.com/en-us/help/4458842'', ''2018-08-22'', ''2019-07-09'', ''2019-07-09'', ''SQL Server 2016'', ''Service Pack 1 Cumulative Update 10 + Security Update''),
                    (13, 4001, ''SP1 '', ''https://support.microsoft.com/en-us/help/3182545 '', ''2016-11-16'', ''2019-07-09'', ''2019-07-09'', ''SQL Server 2016'', ''Service Pack 1 ''),
                    (13, 2216, ''RTM CU9'', ''https://support.microsoft.com/en-us/help/4037357'', ''2017-11-20'', ''2018-01-09'', ''2018-01-09'', ''SQL Server 2016'', ''RTM Cumulative Update 9''),
                    (13, 2213, ''RTM CU8'', ''https://support.microsoft.com/en-us/help/4024304'', ''2017-09-18'', ''2018-01-09'', ''2018-01-09'', ''SQL Server 2016'', ''RTM Cumulative Update 8''),
                    (13, 2210, ''RTM CU7'', ''https://support.microsoft.com/en-us/help/4024304'', ''2017-08-08'', ''2018-01-09'', ''2018-01-09'', ''SQL Server 2016'', ''RTM Cumulative Update 7''),
                    (13, 2204, ''RTM CU6'', ''https://support.microsoft.com/en-us/help/4019914'', ''2017-05-15'', ''2018-01-09'', ''2018-01-09'', ''SQL Server 2016'', ''RTM Cumulative Update 6''),
                    (13, 2197, ''RTM CU5'', ''https://support.microsoft.com/en-us/help/4013105'', ''2017-03-20'', ''2018-01-09'', ''2018-01-09'', ''SQL Server 2016'', ''RTM Cumulative Update 5''),
                    (13, 2193, ''RTM CU4'', ''https://support.microsoft.com/en-us/help/3205052 '', ''2017-01-17'', ''2018-01-09'', ''2018-01-09'', ''SQL Server 2016'', ''RTM Cumulative Update 4''),
                    (13, 2186, ''RTM CU3'', ''https://support.microsoft.com/en-us/help/3205413 '', ''2016-11-16'', ''2018-01-09'', ''2018-01-09'', ''SQL Server 2016'', ''RTM Cumulative Update 3''),
                    (13, 2164, ''RTM CU2'', ''https://support.microsoft.com/en-us/help/3182270 '', ''2016-09-22'', ''2018-01-09'', ''2018-01-09'', ''SQL Server 2016'', ''RTM Cumulative Update 2''),
                    (13, 2149, ''RTM CU1'', ''https://support.microsoft.com/en-us/help/3164674 '', ''2016-07-25'', ''2018-01-09'', ''2018-01-09'', ''SQL Server 2016'', ''RTM Cumulative Update 1''),
                    (13, 1601, ''RTM '', '''', ''2016-06-01'', ''2019-01-09'', ''2019-01-09'', ''SQL Server 2016'', ''RTM ''),
                    (12, 5590, ''SP2 CU13'', ''https://support.microsoft.com/en-us/help/4456287'', ''2018-08-27'', ''2019-07-09'', ''2024-07-09'', ''SQL Server 2014'', ''Service Pack 2 Cumulative Update 13''),
                    (12, 5589, ''SP2 CU12'', ''https://support.microsoft.com/en-us/help/4130489'', ''2018-06-18'', ''2019-07-09'', ''2024-07-09'', ''SQL Server 2014'', ''Service Pack 2 Cumulative Update 12''),
                    (12, 5579, ''SP2 CU11'', ''https://support.microsoft.com/en-us/help/4077063'', ''2018-03-19'', ''2019-07-09'', ''2024-07-09'', ''SQL Server 2014'', ''Service Pack 2 Cumulative Update 11''),
                    (12, 5571, ''SP2 CU10'', ''https://support.microsoft.com/en-us/help/4052725'', ''2018-01-16'', ''2019-07-09'', ''2024-07-09'', ''SQL Server 2014'', ''Service Pack 2 Cumulative Update 10''),
                    (12, 5563, ''SP2 CU9'', ''https://support.microsoft.com/en-us/help/4055557'', ''2017-12-18'', ''2019-07-09'', ''2024-07-09'', ''SQL Server 2014'', ''Service Pack 2 Cumulative Update 9''),
                    (12, 5557, ''SP2 CU8'', ''https://support.microsoft.com/en-us/help/4037356'', ''2017-10-16'', ''2019-07-09'', ''2024-07-09'', ''SQL Server 2014'', ''Service Pack 2 Cumulative Update 8''),
                    (12, 5556, ''SP2 CU7'', ''https://support.microsoft.com/en-us/help/4032541'', ''2017-08-28'', ''2019-07-09'', ''2024-07-09'', ''SQL Server 2014'', ''Service Pack 2 Cumulative Update 7''),
                    (12, 5553, ''SP2 CU6'', ''https://support.microsoft.com/en-us/help/4019094'', ''2017-08-08'', ''2019-07-09'', ''2024-07-09'', ''SQL Server 2014'', ''Service Pack 2 Cumulative Update 6''),
                    (12, 5546, ''SP2 CU5'', ''https://support.microsoft.com/en-us/help/4013098'', ''2017-04-17'', ''2019-07-09'', ''2024-07-09'', ''SQL Server 2014'', ''Service Pack 2 Cumulative Update 5''),
                    (12, 5540, ''SP2 CU4'', ''https://support.microsoft.com/en-us/help/4010394'', ''2017-02-21'', ''2019-07-09'', ''2024-07-09'', ''SQL Server 2014'', ''Service Pack 2 Cumulative Update 4''),
                    (12, 5538, ''SP2 CU3'', ''https://support.microsoft.com/en-us/help/3204388 '', ''2016-12-19'', ''2019-07-09'', ''2024-07-09'', ''SQL Server 2014'', ''Service Pack 2 Cumulative Update 3''),
                    (12, 5522, ''SP2 CU2'', ''https://support.microsoft.com/en-us/help/3188778 '', ''2016-10-17'', ''2019-07-09'', ''2024-07-09'', ''SQL Server 2014'', ''Service Pack 2 Cumulative Update 2''),
                    (12, 5511, ''SP2 CU1'', ''https://support.microsoft.com/en-us/help/3178925 '', ''2016-08-25'', ''2019-07-09'', ''2024-07-09'', ''SQL Server 2014'', ''Service Pack 2 Cumulative Update 1''),
                    (12, 5000, ''SP2 '', ''https://support.microsoft.com/en-us/help/3171021 '', ''2016-07-11'', ''2019-07-09'', ''2024-07-09'', ''SQL Server 2014'', ''Service Pack 2 ''),
                    (12, 4522, ''SP1 CU13'', ''https://support.microsoft.com/en-us/help/4019099'', ''2017-08-08'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 Cumulative Update 13''),
                    (12, 4511, ''SP1 CU12'', ''https://support.microsoft.com/en-us/help/4017793'', ''2017-04-17'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 Cumulative Update 12''),
                    (12, 4502, ''SP1 CU11'', ''https://support.microsoft.com/en-us/help/4010392'', ''2017-02-21'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 Cumulative Update 11''),
                    (12, 4491, ''SP1 CU10'', ''https://support.microsoft.com/en-us/help/3204399 '', ''2016-12-19'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 Cumulative Update 10''),
                    (12, 4474, ''SP1 CU9'', ''https://support.microsoft.com/en-us/help/3186964 '', ''2016-10-17'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 Cumulative Update 9''),
                    (12, 4468, ''SP1 CU8'', ''https://support.microsoft.com/en-us/help/3174038 '', ''2016-08-15'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 Cumulative Update 8''),
                    (12, 4459, ''SP1 CU7'', ''https://support.microsoft.com/en-us/help/3162659 '', ''2016-06-20'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 Cumulative Update 7''),
                    (12, 4457, ''SP1 CU6'', ''https://support.microsoft.com/en-us/help/3167392 '', ''2016-05-30'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 Cumulative Update 6''),
                    (12, 4449, ''SP1 CU6'', ''https://support.microsoft.com/en-us/help/3144524'', ''2016-04-18'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 Cumulative Update 6''),
                    (12, 4438, ''SP1 CU5'', ''https://support.microsoft.com/en-us/help/3130926'', ''2016-02-22'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 Cumulative Update 5''),
                    (12, 4436, ''SP1 CU4'', ''https://support.microsoft.com/en-us/help/3106660'', ''2015-12-21'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 Cumulative Update 4''),
                    (12, 4427, ''SP1 CU3'', ''https://support.microsoft.com/en-us/help/3094221'', ''2015-10-19'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 Cumulative Update 3''),
                    (12, 4422, ''SP1 CU2'', ''https://support.microsoft.com/en-us/help/3075950'', ''2015-08-17'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 Cumulative Update 2''),
                    (12, 4416, ''SP1 CU1'', ''https://support.microsoft.com/en-us/help/3067839'', ''2015-06-19'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 Cumulative Update 1''),
                    (12, 4213, ''SP1 MS15-058: GDR Security Update'', ''https://support.microsoft.com/en-us/help/3070446'', ''2015-07-14'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 MS15-058: GDR Security Update''),
                    (12, 4100, ''SP1 '', ''https://support.microsoft.com/en-us/help/3058865'', ''2015-05-04'', ''2017-10-10'', ''2017-10-10'', ''SQL Server 2014'', ''Service Pack 1 ''),
                    (12, 2569, ''RTM CU14'', ''https://support.microsoft.com/en-us/help/3158271 '', ''2016-06-20'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM Cumulative Update 14''),
                    (12, 2568, ''RTM CU13'', ''https://support.microsoft.com/en-us/help/3144517'', ''2016-04-18'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM Cumulative Update 13''),
                    (12, 2564, ''RTM CU12'', ''https://support.microsoft.com/en-us/help/3130923'', ''2016-02-22'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM Cumulative Update 12''),
                    (12, 2560, ''RTM CU11'', ''https://support.microsoft.com/en-us/help/3106659'', ''2015-12-21'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM Cumulative Update 11''),
                    (12, 2556, ''RTM CU10'', ''https://support.microsoft.com/en-us/help/3094220'', ''2015-10-19'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM Cumulative Update 10''),
                    (12, 2553, ''RTM CU9'', ''https://support.microsoft.com/en-us/help/3075949'', ''2015-08-17'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM Cumulative Update 9''),
                    (12, 2548, ''RTM MS15-058: QFE Security Update'', ''https://support.microsoft.com/en-us/help/3045323'', ''2015-07-14'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM MS15-058: QFE Security Update''),
                    (12, 2546, ''RTM CU8'', ''https://support.microsoft.com/en-us/help/3067836'', ''2015-06-19'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM Cumulative Update 8''),
                    (12, 2495, ''RTM CU7'', ''https://support.microsoft.com/en-us/help/3046038'', ''2015-04-20'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM Cumulative Update 7''),
                    (12, 2480, ''RTM CU6'', ''https://support.microsoft.com/en-us/help/3031047'', ''2015-02-16'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM Cumulative Update 6''),
                    (12, 2456, ''RTM CU5'', ''https://support.microsoft.com/en-us/help/3011055'', ''2014-12-17'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM Cumulative Update 5''),
                    (12, 2430, ''RTM CU4'', ''https://support.microsoft.com/en-us/help/2999197'', ''2014-10-21'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM Cumulative Update 4''),
                    (12, 2402, ''RTM CU3'', ''https://support.microsoft.com/en-us/help/2984923'', ''2014-08-18'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM Cumulative Update 3''),
                    (12, 2381, ''RTM MS14-044: QFE Security Update'', ''https://support.microsoft.com/en-us/help/2977316'', ''2014-08-12'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM MS14-044: QFE Security Update''),
                    (12, 2370, ''RTM CU2'', ''https://support.microsoft.com/en-us/help/2967546'', ''2014-06-27'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM Cumulative Update 2''),
                    (12, 2342, ''RTM CU1'', ''https://support.microsoft.com/en-us/help/2931693'', ''2014-04-21'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM Cumulative Update 1''),
                    (12, 2269, ''RTM MS15-058: GDR Security Update '', ''https://support.microsoft.com/en-us/help/3045324'', ''2015-07-14'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM MS15-058: GDR Security Update ''),
                    (12, 2254, ''RTM MS14-044: GDR Security Update'', ''https://support.microsoft.com/en-us/help/2977315'', ''2014-08-12'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM MS14-044: GDR Security Update''),
                    (12, 2000, ''RTM '', '''', ''2014-04-01'', ''2016-07-12'', ''2016-07-12'', ''SQL Server 2014'', ''RTM ''),
                    (11, 7001, ''SP4 '', ''https://support.microsoft.com/en-us/help/4018073'', ''2017-10-02'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''Service Pack 4 ''),
                    (11, 6607, ''SP3 CU10'', ''https://support.microsoft.com/en-us/help/4025925'', ''2017-08-08'', ''2018-10-09'', ''2018-10-09'', ''SQL Server 2012'', ''Service Pack 3 Cumulative Update 10''),
                    (11, 6598, ''SP3 CU9'', ''https://support.microsoft.com/en-us/help/4016762'', ''2017-05-15'', ''2018-10-09'', ''2018-10-09'', ''SQL Server 2012'', ''Service Pack 3 Cumulative Update 9''),
                    (11, 6594, ''SP3 CU8'', ''https://support.microsoft.com/en-us/help/3205051 '', ''2017-03-20'', ''2018-10-09'', ''2018-10-09'', ''SQL Server 2012'', ''Service Pack 3 Cumulative Update 8''),
                    (11, 6579, ''SP3 CU7'', ''https://support.microsoft.com/en-us/help/3205051 '', ''2017-01-17'', ''2018-10-09'', ''2018-10-09'', ''SQL Server 2012'', ''Service Pack 3 Cumulative Update 7''),
                    (11, 6567, ''SP3 CU6'', ''https://support.microsoft.com/en-us/help/3194992 '', ''2016-11-17'', ''2018-10-09'', ''2018-10-09'', ''SQL Server 2012'', ''Service Pack 3 Cumulative Update 6''),
                    (11, 6544, ''SP3 CU5'', ''https://support.microsoft.com/en-us/help/3180915 '', ''2016-09-19'', ''2018-10-09'', ''2018-10-09'', ''SQL Server 2012'', ''Service Pack 3 Cumulative Update 5''),
                    (11, 6540, ''SP3 CU4'', ''https://support.microsoft.com/en-us/help/3165264 '', ''2016-07-18'', ''2018-10-09'', ''2018-10-09'', ''SQL Server 2012'', ''Service Pack 3 Cumulative Update 4''),
                    (11, 6537, ''SP3 CU3'', ''https://support.microsoft.com/en-us/help/3152635 '', ''2016-05-16'', ''2018-10-09'', ''2018-10-09'', ''SQL Server 2012'', ''Service Pack 3 Cumulative Update 3''),
                    (11, 6523, ''SP3 CU2'', ''https://support.microsoft.com/en-us/help/3137746'', ''2016-03-21'', ''2018-10-09'', ''2018-10-09'', ''SQL Server 2012'', ''Service Pack 3 Cumulative Update 2''),
                    (11, 6518, ''SP3 CU1'', ''https://support.microsoft.com/en-us/help/3123299'', ''2016-01-19'', ''2018-10-09'', ''2018-10-09'', ''SQL Server 2012'', ''Service Pack 3 Cumulative Update 1''),
                    (11, 6020, ''SP3 '', ''https://support.microsoft.com/en-us/help/3072779'', ''2015-11-20'', ''2018-10-09'', ''2018-10-09'', ''SQL Server 2012'', ''Service Pack 3 ''),
                    (11, 5678, ''SP2 CU16'', ''https://support.microsoft.com/en-us/help/3205416 '', ''2016-11-17'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 16''),
                    (11, 5676, ''SP2 CU15'', ''https://support.microsoft.com/en-us/help/3205416 '', ''2016-11-17'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 15''),
                    (11, 5657, ''SP2 CU14'', ''https://support.microsoft.com/en-us/help/3180914 '', ''2016-09-19'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 14''),
                    (11, 5655, ''SP2 CU13'', ''https://support.microsoft.com/en-us/help/3165266 '', ''2016-07-18'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 13''),
                    (11, 5649, ''SP2 CU12'', ''https://support.microsoft.com/en-us/help/3152637 '', ''2016-05-16'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 12''),
                    (11, 5646, ''SP2 CU11'', ''https://support.microsoft.com/en-us/help/3137745'', ''2016-03-21'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 11''),
                    (11, 5644, ''SP2 CU10'', ''https://support.microsoft.com/en-us/help/3120313'', ''2016-01-19'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 10''),
                    (11, 5641, ''SP2 CU9'', ''https://support.microsoft.com/en-us/help/3098512'', ''2015-11-16'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 9''),
                    (11, 5634, ''SP2 CU8'', ''https://support.microsoft.com/en-us/help/3082561'', ''2015-09-21'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 8''),
                    (11, 5623, ''SP2 CU7'', ''https://support.microsoft.com/en-us/help/3072100'', ''2015-07-20'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 7''),
                    (11, 5613, ''SP2 MS15-058: QFE Security Update'', ''https://support.microsoft.com/en-us/help/3045319'', ''2015-07-14'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 MS15-058: QFE Security Update''),
                    (11, 5592, ''SP2 CU6'', ''https://support.microsoft.com/en-us/help/3052468'', ''2015-05-18'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 6''),
                    (11, 5582, ''SP2 CU5'', ''https://support.microsoft.com/en-us/help/3037255'', ''2015-03-16'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 5''),
                    (11, 5569, ''SP2 CU4'', ''https://support.microsoft.com/en-us/help/3007556'', ''2015-01-19'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 4''),
                    (11, 5556, ''SP2 CU3'', ''https://support.microsoft.com/en-us/help/3002049'', ''2014-11-17'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 3''),
                    (11, 5548, ''SP2 CU2'', ''https://support.microsoft.com/en-us/help/2983175'', ''2014-09-15'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 2''),
                    (11, 5532, ''SP2 CU1'', ''https://support.microsoft.com/en-us/help/2976982'', ''2014-07-23'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 Cumulative Update 1''),
                    (11, 5343, ''SP2 MS15-058: GDR Security Update'', ''https://support.microsoft.com/en-us/help/3045321'', ''2015-07-14'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 MS15-058: GDR Security Update''),
                    (11, 5058, ''SP2 '', ''https://support.microsoft.com/en-us/help/2958429'', ''2014-06-10'', ''2017-01-10'', ''2017-01-10'', ''SQL Server 2012'', ''Service Pack 2 ''),
                    (11, 3513, ''SP1 MS15-058: QFE Security Update'', ''https://support.microsoft.com/en-us/help/3045317'', ''2015-07-14'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 MS15-058: QFE Security Update''),
                    (11, 3482, ''SP1 CU13'', ''https://support.microsoft.com/en-us/help/3002044'', ''2014-11-17'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 Cumulative Update 13''),
                    (11, 3470, ''SP1 CU12'', ''https://support.microsoft.com/en-us/help/2991533'', ''2014-09-15'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 Cumulative Update 12''),
                    (11, 3460, ''SP1 MS14-044: QFE Security Update '', ''https://support.microsoft.com/en-us/help/2977325'', ''2014-08-12'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 MS14-044: QFE Security Update ''),
                    (11, 3449, ''SP1 CU11'', ''https://support.microsoft.com/en-us/help/2975396'', ''2014-07-21'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 Cumulative Update 11''),
                    (11, 3431, ''SP1 CU10'', ''https://support.microsoft.com/en-us/help/2954099'', ''2014-05-19'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 Cumulative Update 10''),
                    (11, 3412, ''SP1 CU9'', ''https://support.microsoft.com/en-us/help/2931078'', ''2014-03-17'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 Cumulative Update 9''),
                    (11, 3401, ''SP1 CU8'', ''https://support.microsoft.com/en-us/help/2917531'', ''2014-01-20'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 Cumulative Update 8''),
                    (11, 3393, ''SP1 CU7'', ''https://support.microsoft.com/en-us/help/2894115'', ''2013-11-18'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 Cumulative Update 7''),
                    (11, 3381, ''SP1 CU6'', ''https://support.microsoft.com/en-us/help/2874879'', ''2013-09-16'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 Cumulative Update 6''),
                    (11, 3373, ''SP1 CU5'', ''https://support.microsoft.com/en-us/help/2861107'', ''2013-07-15'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 Cumulative Update 5''),
                    (11, 3368, ''SP1 CU4'', ''https://support.microsoft.com/en-us/help/2833645'', ''2013-05-30'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 Cumulative Update 4''),
                    (11, 3349, ''SP1 CU3'', ''https://support.microsoft.com/en-us/help/2812412'', ''2013-03-18'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 Cumulative Update 3''),
                    (11, 3339, ''SP1 CU2'', ''https://support.microsoft.com/en-us/help/2790947'', ''2013-01-21'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 Cumulative Update 2''),
                    (11, 3321, ''SP1 CU1'', ''https://support.microsoft.com/en-us/help/2765331'', ''2012-11-20'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 Cumulative Update 1''),
                    (11, 3156, ''SP1 MS15-058: GDR Security Update'', ''https://support.microsoft.com/en-us/help/3045318'', ''2015-07-14'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 MS15-058: GDR Security Update''),
                    (11, 3153, ''SP1 MS14-044: GDR Security Update'', ''https://support.microsoft.com/en-us/help/2977326'', ''2014-08-12'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 MS14-044: GDR Security Update''),
                    (11, 3000, ''SP1 '', ''https://support.microsoft.com/en-us/help/2674319'', ''2012-11-07'', ''2015-07-14'', ''2015-07-14'', ''SQL Server 2012'', ''Service Pack 1 ''),
                    (11, 2424, ''RTM CU11'', ''https://support.microsoft.com/en-us/help/2908007'', ''2013-12-16'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''RTM Cumulative Update 11''),
                    (11, 2420, ''RTM CU10'', ''https://support.microsoft.com/en-us/help/2891666'', ''2013-10-21'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''RTM Cumulative Update 10''),
                    (11, 2419, ''RTM CU9'', ''https://support.microsoft.com/en-us/help/2867319'', ''2013-08-20'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''RTM Cumulative Update 9''),
                    (11, 2410, ''RTM CU8'', ''https://support.microsoft.com/en-us/help/2844205'', ''2013-06-17'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''RTM Cumulative Update 8''),
                    (11, 2405, ''RTM CU7'', ''https://support.microsoft.com/en-us/help/2823247'', ''2013-04-15'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''RTM Cumulative Update 7''),
                    (11, 2401, ''RTM CU6'', ''https://support.microsoft.com/en-us/help/2728897'', ''2013-02-18'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''RTM Cumulative Update 6''),
                    (11, 2395, ''RTM CU5'', ''https://support.microsoft.com/en-us/help/2777772'', ''2012-12-17'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''RTM Cumulative Update 5''),
                    (11, 2383, ''RTM CU4'', ''https://support.microsoft.com/en-us/help/2758687'', ''2012-10-15'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''RTM Cumulative Update 4''),
                    (11, 2376, ''RTM MS12-070: QFE Security Update'', ''https://support.microsoft.com/en-us/help/2716441'', ''2012-10-09'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''RTM MS12-070: QFE Security Update''),
                    (11, 2332, ''RTM CU3'', ''https://support.microsoft.com/en-us/help/2723749'', ''2012-08-31'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''RTM Cumulative Update 3''),
                    (11, 2325, ''RTM CU2'', ''https://support.microsoft.com/en-us/help/2703275'', ''2012-06-18'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''RTM Cumulative Update 2''),
                    (11, 2316, ''RTM CU1'', ''https://support.microsoft.com/en-us/help/2679368'', ''2012-04-12'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''RTM Cumulative Update 1''),
                    (11, 2218, ''RTM MS12-070: GDR Security Update'', ''https://support.microsoft.com/en-us/help/2716442'', ''2012-10-09'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''RTM MS12-070: GDR Security Update''),
                    (11, 2100, ''RTM '', '''', ''2012-03-06'', ''2017-07-11'', ''2022-07-12'', ''SQL Server 2012'', ''RTM ''),
                    (10, 6529, ''SP3 MS15-058: QFE Security Update'', ''https://support.microsoft.com/en-us/help/3045314'', ''2015-07-14'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''Service Pack 3 MS15-058: QFE Security Update''),
                    (10, 6220, ''SP3 MS15-058: QFE Security Update'', ''https://support.microsoft.com/en-us/help/3045316'', ''2015-07-14'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''Service Pack 3 MS15-058: QFE Security Update''),
                    (10, 6000, ''SP3 '', ''https://support.microsoft.com/en-us/help/2979597'', ''2014-09-26'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''Service Pack 3 ''),
                    (10, 4339, ''SP2 MS15-058: QFE Security Update'', ''https://support.microsoft.com/en-us/help/3045312'', ''2015-07-14'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 MS15-058: QFE Security Update''),
                    (10, 4321, ''SP2 MS14-044: QFE Security Update'', ''https://support.microsoft.com/en-us/help/2977319'', ''2014-08-14'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 MS14-044: QFE Security Update''),
                    (10, 4319, ''SP2 CU13'', ''https://support.microsoft.com/en-us/help/2967540'', ''2014-06-30'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 Cumulative Update 13''),
                    (10, 4305, ''SP2 CU12'', ''https://support.microsoft.com/en-us/help/2938478'', ''2014-04-21'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 Cumulative Update 12''),
                    (10, 4302, ''SP2 CU11'', ''https://support.microsoft.com/en-us/help/2926028'', ''2014-02-18'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 Cumulative Update 11''),
                    (10, 4297, ''SP2 CU10'', ''https://support.microsoft.com/en-us/help/2908087'', ''2013-12-17'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 Cumulative Update 10''),
                    (10, 4295, ''SP2 CU9'', ''https://support.microsoft.com/en-us/help/2887606'', ''2013-10-28'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 Cumulative Update 9''),
                    (10, 4290, ''SP2 CU8'', ''https://support.microsoft.com/en-us/help/2871401'', ''2013-08-22'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 Cumulative Update 8''),
                    (10, 4285, ''SP2 CU7'', ''https://support.microsoft.com/en-us/help/2844090'', ''2013-06-17'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 Cumulative Update 7''),
                    (10, 4279, ''SP2 CU6'', ''https://support.microsoft.com/en-us/help/2830140'', ''2013-04-15'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 Cumulative Update 6''),
                    (10, 4276, ''SP2 CU5'', ''https://support.microsoft.com/en-us/help/2797460'', ''2013-02-18'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 Cumulative Update 5''),
                    (10, 4270, ''SP2 CU4'', ''https://support.microsoft.com/en-us/help/2777358'', ''2012-12-17'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 Cumulative Update 4''),
                    (10, 4266, ''SP2 CU3'', ''https://support.microsoft.com/en-us/help/2754552'', ''2012-10-15'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 Cumulative Update 3''),
                    (10, 4263, ''SP2 CU2'', ''https://support.microsoft.com/en-us/help/2740411'', ''2012-08-31'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 Cumulative Update 2''),
                    (10, 4260, ''SP2 CU1'', ''https://support.microsoft.com/en-us/help/2720425'', ''2012-07-24'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 Cumulative Update 1''),
                    (10, 4042, ''SP2 MS15-058: GDR Security Update'', ''https://support.microsoft.com/en-us/help/3045313'', ''2015-07-14'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 MS15-058: GDR Security Update''),
                    (10, 4033, ''SP2 MS14-044: GDR Security Update'', ''https://support.microsoft.com/en-us/help/2977320'', ''2014-08-12'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 MS14-044: GDR Security Update''),
                    (10, 4000, ''SP2 '', ''https://support.microsoft.com/en-us/help/2630458'', ''2012-07-26'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008 R2'', ''Service Pack 2 ''),
                    (10, 2881, ''SP1 CU14'', ''https://support.microsoft.com/en-us/help/2868244'', ''2013-08-08'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 Cumulative Update 14''),
                    (10, 2876, ''SP1 CU13'', ''https://support.microsoft.com/en-us/help/2855792'', ''2013-06-17'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 Cumulative Update 13''),
                    (10, 2874, ''SP1 CU12'', ''https://support.microsoft.com/en-us/help/2828727'', ''2013-04-15'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 Cumulative Update 12''),
                    (10, 2869, ''SP1 CU11'', ''https://support.microsoft.com/en-us/help/2812683'', ''2013-02-18'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 Cumulative Update 11''),
                    (10, 2868, ''SP1 CU10'', ''https://support.microsoft.com/en-us/help/2783135'', ''2012-12-17'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 Cumulative Update 10''),
                    (10, 2866, ''SP1 CU9'', ''https://support.microsoft.com/en-us/help/2756574'', ''2012-10-15'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 Cumulative Update 9''),
                    (10, 2861, ''SP1 MS12-070: QFE Security Update'', ''https://support.microsoft.com/en-us/help/2716439'', ''2012-10-09'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 MS12-070: QFE Security Update''),
                    (10, 2822, ''SP1 CU8'', ''https://support.microsoft.com/en-us/help/2723743'', ''2012-08-31'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 Cumulative Update 8''),
                    (10, 2817, ''SP1 CU7'', ''https://support.microsoft.com/en-us/help/2703282'', ''2012-06-18'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 Cumulative Update 7''),
                    (10, 2811, ''SP1 CU6'', ''https://support.microsoft.com/en-us/help/2679367'', ''2012-04-16'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 Cumulative Update 6''),
                    (10, 2806, ''SP1 CU5'', ''https://support.microsoft.com/en-us/help/2659694'', ''2012-02-22'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 Cumulative Update 5''),
                    (10, 2796, ''SP1 CU4'', ''https://support.microsoft.com/en-us/help/2633146'', ''2011-12-19'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 Cumulative Update 4''),
                    (10, 2789, ''SP1 CU3'', ''https://support.microsoft.com/en-us/help/2591748'', ''2011-10-17'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 Cumulative Update 3''),
                    (10, 2772, ''SP1 CU2'', ''https://support.microsoft.com/en-us/help/2567714'', ''2011-08-15'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 Cumulative Update 2''),
                    (10, 2769, ''SP1 CU1'', ''https://support.microsoft.com/en-us/help/2544793'', ''2011-07-18'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 Cumulative Update 1''),
                    (10, 2550, ''SP1 MS12-070: GDR Security Update'', ''https://support.microsoft.com/en-us/help/2754849'', ''2012-10-09'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 MS12-070: GDR Security Update''),
                    (10, 2500, ''SP1 '', ''https://support.microsoft.com/en-us/help/2528583'', ''2011-07-12'', ''2013-10-08'', ''2013-10-08'', ''SQL Server 2008 R2'', ''Service Pack 1 ''),
                    (10, 1815, ''RTM CU13'', ''https://support.microsoft.com/en-us/help/2679366'', ''2012-04-16'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM Cumulative Update 13''),
                    (10, 1810, ''RTM CU12'', ''https://support.microsoft.com/en-us/help/2659692'', ''2012-02-21'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM Cumulative Update 12''),
                    (10, 1809, ''RTM CU11'', ''https://support.microsoft.com/en-us/help/2633145'', ''2011-12-19'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM Cumulative Update 11''),
                    (10, 1807, ''RTM CU10'', ''https://support.microsoft.com/en-us/help/2591746'', ''2011-10-17'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM Cumulative Update 10''),
                    (10, 1804, ''RTM CU9'', ''https://support.microsoft.com/en-us/help/2567713'', ''2011-08-15'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM Cumulative Update 9''),
                    (10, 1797, ''RTM CU8'', ''https://support.microsoft.com/en-us/help/2534352'', ''2011-06-20'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM Cumulative Update 8''),
                    (10, 1790, ''RTM MS11-049: QFE Security Update'', ''https://support.microsoft.com/en-us/help/2494086'', ''2011-06-14'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM MS11-049: QFE Security Update''),
                    (10, 1777, ''RTM CU7'', ''https://support.microsoft.com/en-us/help/2507770'', ''2011-04-18'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM Cumulative Update 7''),
                    (10, 1765, ''RTM CU6'', ''https://support.microsoft.com/en-us/help/2489376'', ''2011-02-21'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM Cumulative Update 6''),
                    (10, 1753, ''RTM CU5'', ''https://support.microsoft.com/en-us/help/2438347'', ''2010-12-20'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM Cumulative Update 5''),
                    (10, 1746, ''RTM CU4'', ''https://support.microsoft.com/en-us/help/2345451'', ''2010-10-18'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM Cumulative Update 4''),
                    (10, 1734, ''RTM CU3'', ''https://support.microsoft.com/en-us/help/2261464'', ''2010-08-16'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM Cumulative Update 3''),
                    (10, 1720, ''RTM CU2'', ''https://support.microsoft.com/en-us/help/2072493'', ''2010-06-21'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM Cumulative Update 2''),
                    (10, 1702, ''RTM CU1'', ''https://support.microsoft.com/en-us/help/981355'', ''2010-05-18'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM Cumulative Update 1''),
                    (10, 1617, ''RTM MS11-049: GDR Security Update'', ''https://support.microsoft.com/en-us/help/2494088'', ''2011-06-14'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM MS11-049: GDR Security Update''),
                    (10, 1600, ''RTM '', '''', ''2010-05-10'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008 R2'', ''RTM ''),
                    (10, 6535, ''SP3 MS15-058: QFE Security Update'', ''https://support.microsoft.com/en-us/help/3045308'', ''2015-07-14'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 MS15-058: QFE Security Update''),
                    (10, 6241, ''SP3 MS15-058: GDR Security Update'', ''https://support.microsoft.com/en-us/help/3045311'', ''2015-07-14'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 MS15-058: GDR Security Update''),
                    (10, 5890, ''SP3 MS15-058: QFE Security Update'', ''https://support.microsoft.com/en-us/help/3045303'', ''2015-07-14'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 MS15-058: QFE Security Update''),
                    (10, 5869, ''SP3 MS14-044: QFE Security Update'', ''https://support.microsoft.com/en-us/help/2984340, https://support.microsoft.com/en-us/help/2977322'', ''2014-08-12'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 MS14-044: QFE Security Update''),
                    (10, 5861, ''SP3 CU17'', ''https://support.microsoft.com/en-us/help/2958696'', ''2014-05-19'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 17''),
                    (10, 5852, ''SP3 CU16'', ''https://support.microsoft.com/en-us/help/2936421'', ''2014-03-17'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 16''),
                    (10, 5850, ''SP3 CU15'', ''https://support.microsoft.com/en-us/help/2923520'', ''2014-01-20'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 15''),
                    (10, 5848, ''SP3 CU14'', ''https://support.microsoft.com/en-us/help/2893410'', ''2013-11-18'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 14''),
                    (10, 5846, ''SP3 CU13'', ''https://support.microsoft.com/en-us/help/2880350'', ''2013-09-16'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 13''),
                    (10, 5844, ''SP3 CU12'', ''https://support.microsoft.com/en-us/help/2863205'', ''2013-07-15'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 12''),
                    (10, 5840, ''SP3 CU11'', ''https://support.microsoft.com/en-us/help/2834048'', ''2013-05-20'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 11''),
                    (10, 5835, ''SP3 CU10'', ''https://support.microsoft.com/en-us/help/2814783'', ''2013-03-18'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 10''),
                    (10, 5829, ''SP3 CU9'', ''https://support.microsoft.com/en-us/help/2799883'', ''2013-01-21'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 9''),
                    (10, 5828, ''SP3 CU8'', ''https://support.microsoft.com/en-us/help/2771833'', ''2012-11-19'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 8''),
                    (10, 5826, ''SP3 MS12-070: QFE Security Update'', ''https://support.microsoft.com/en-us/help/2716435'', ''2012-10-09'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 MS12-070: QFE Security Update''),
                    (10, 5794, ''SP3 CU7'', ''https://support.microsoft.com/en-us/help/2738350'', ''2012-09-17'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 7''),
                    (10, 5788, ''SP3 CU6'', ''https://support.microsoft.com/en-us/help/2715953'', ''2012-07-16'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 6''),
                    (10, 5785, ''SP3 CU5'', ''https://support.microsoft.com/en-us/help/2696626'', ''2012-05-21'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 5''),
                    (10, 5775, ''SP3 CU4'', ''https://support.microsoft.com/en-us/help/2673383'', ''2012-03-19'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 4''),
                    (10, 5770, ''SP3 CU3'', ''https://support.microsoft.com/en-us/help/2648098'', ''2012-01-16'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 3''),
                    (10, 5768, ''SP3 CU2'', ''https://support.microsoft.com/en-us/help/2633143'', ''2011-11-21'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 2''),
                    (10, 5766, ''SP3 CU1'', ''https://support.microsoft.com/en-us/help/2617146'', ''2011-10-17'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 Cumulative Update 1''),
                    (10, 5538, ''SP3 MS15-058: GDR Security Update'', ''https://support.microsoft.com/en-us/help/3045305'', ''2015-07-14'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 MS15-058: GDR Security Update''),
                    (10, 5520, ''SP3 MS14-044: GDR Security Update'', ''https://support.microsoft.com/en-us/help/2977321'', ''2014-08-12'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 MS14-044: GDR Security Update''),
                    (10, 5512, ''SP3 MS12-070: GDR Security Update'', ''https://support.microsoft.com/en-us/help/2716436'', ''2012-10-09'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 MS12-070: GDR Security Update''),
                    (10, 5500, ''SP3 '', ''https://support.microsoft.com/en-us/help/2546951'', ''2011-10-06'', ''2015-10-13'', ''2015-10-13'', ''SQL Server 2008'', ''Service Pack 3 ''),
                    (10, 4371, ''SP2 MS12-070: QFE Security Update'', ''https://support.microsoft.com/en-us/help/2716433'', ''2012-10-09'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 MS12-070: QFE Security Update''),
                    (10, 4333, ''SP2 CU11'', ''https://support.microsoft.com/en-us/help/2715951'', ''2012-07-16'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 Cumulative Update 11''),
                    (10, 4332, ''SP2 CU10'', ''https://support.microsoft.com/en-us/help/2696625'', ''2012-05-21'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 Cumulative Update 10''),
                    (10, 4330, ''SP2 CU9'', ''https://support.microsoft.com/en-us/help/2673382'', ''2012-03-19'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 Cumulative Update 9''),
                    (10, 4326, ''SP2 CU8'', ''https://support.microsoft.com/en-us/help/2648096'', ''2012-01-16'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 Cumulative Update 8''),
                    (10, 4323, ''SP2 CU7'', ''https://support.microsoft.com/en-us/help/2617148'', ''2011-11-21'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 Cumulative Update 7''),
                    (10, 4321, ''SP2 CU6'', ''https://support.microsoft.com/en-us/help/2582285'', ''2011-09-19'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 Cumulative Update 6''),
                    (10, 4316, ''SP2 CU5'', ''https://support.microsoft.com/en-us/help/2555408'', ''2011-07-18'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 Cumulative Update 5''),
                    (10, 4311, ''SP2 MS11-049: QFE Security Update'', ''https://support.microsoft.com/en-us/help/2494094'', ''2011-06-14'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 MS11-049: QFE Security Update''),
                    (10, 4285, ''SP2 CU4'', ''https://support.microsoft.com/en-us/help/2527180'', ''2011-05-16'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 Cumulative Update 4''),
                    (10, 4279, ''SP2 CU3'', ''https://support.microsoft.com/en-us/help/2498535'', ''2011-03-17'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 Cumulative Update 3''),
                    (10, 4272, ''SP2 CU2'', ''https://support.microsoft.com/en-us/help/2467239'', ''2011-01-17'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 Cumulative Update 2''),
                    (10, 4266, ''SP2 CU1'', ''https://support.microsoft.com/en-us/help/2289254'', ''2010-11-15'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 Cumulative Update 1''),
                    (10, 4067, ''SP2 MS12-070: GDR Security Update'', ''https://support.microsoft.com/en-us/help/2716434'', ''2012-10-09'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 MS12-070: GDR Security Update''),
                    (10, 4064, ''SP2 MS11-049: GDR Security Update'', ''https://support.microsoft.com/en-us/help/2494089'', ''2011-06-14'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 MS11-049: GDR Security Update''),
                    (10, 4000, ''SP2 '', ''https://support.microsoft.com/en-us/help/2285068'', ''2010-09-29'', ''2012-10-09'', ''2012-10-09'', ''SQL Server 2008'', ''Service Pack 2 ''),
                    (10, 2850, ''SP1 CU16'', ''https://support.microsoft.com/en-us/help/2582282'', ''2011-09-19'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 16''),
                    (10, 2847, ''SP1 CU15'', ''https://support.microsoft.com/en-us/help/2555406'', ''2011-07-18'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 15''),
                    (10, 2841, ''SP1 MS11-049: QFE Security Update'', ''https://support.microsoft.com/en-us/help/2494100'', ''2011-06-14'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 MS11-049: QFE Security Update''),
                    (10, 2821, ''SP1 CU14'', ''https://support.microsoft.com/en-us/help/2527187'', ''2011-05-16'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 14''),
                    (10, 2816, ''SP1 CU13'', ''https://support.microsoft.com/en-us/help/2497673'', ''2011-03-17'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 13''),
                    (10, 2808, ''SP1 CU12'', ''https://support.microsoft.com/en-us/help/2467236'', ''2011-01-17'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 12''),
                    (10, 2804, ''SP1 CU11'', ''https://support.microsoft.com/en-us/help/2413738'', ''2010-11-15'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 11''),
                    (10, 2799, ''SP1 CU10'', ''https://support.microsoft.com/en-us/help/2279604'', ''2010-09-20'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 10''),
                    (10, 2789, ''SP1 CU9'', ''https://support.microsoft.com/en-us/help/2083921'', ''2010-07-19'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 9''),
                    (10, 2775, ''SP1 CU8'', ''https://support.microsoft.com/en-us/help/981702'', ''2010-05-17'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 8''),
                    (10, 2766, ''SP1 CU7'', ''https://support.microsoft.com/en-us/help/979065'', ''2010-03-26'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 7''),
                    (10, 2757, ''SP1 CU6'', ''https://support.microsoft.com/en-us/help/977443'', ''2010-01-18'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 6''),
                    (10, 2746, ''SP1 CU5'', ''https://support.microsoft.com/en-us/help/975977'', ''2009-11-16'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 5''),
                    (10, 2734, ''SP1 CU4'', ''https://support.microsoft.com/en-us/help/973602'', ''2009-09-21'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 4''),
                    (10, 2723, ''SP1 CU3'', ''https://support.microsoft.com/en-us/help/971491'', ''2009-07-20'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 3''),
                    (10, 2714, ''SP1 CU2'', ''https://support.microsoft.com/en-us/help/970315'', ''2009-05-18'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 2''),
                    (10, 2710, ''SP1 CU1'', ''https://support.microsoft.com/en-us/help/969099'', ''2009-04-16'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 Cumulative Update 1''),
                    (10, 2573, ''SP1 MS11-049: GDR Security update'', ''https://support.microsoft.com/en-us/help/2494096'', ''2011-06-14'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 MS11-049: GDR Security update''),
                    (10, 2531, ''SP1 '', '''', ''2009-04-01'', ''2011-10-11'', ''2011-10-11'', ''SQL Server 2008'', ''Service Pack 1 ''),
                    (10, 1835, ''RTM CU10'', ''https://support.microsoft.com/en-us/help/979064'', ''2010-03-15'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008'', ''RTM Cumulative Update 10''),
                    (10, 1828, ''RTM CU9'', ''https://support.microsoft.com/en-us/help/977444'', ''2010-01-18'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008'', ''RTM Cumulative Update 9''),
                    (10, 1823, ''RTM CU8'', ''https://support.microsoft.com/en-us/help/975976'', ''2009-11-16'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008'', ''RTM Cumulative Update 8''),
                    (10, 1818, ''RTM CU7'', ''https://support.microsoft.com/en-us/help/973601'', ''2009-09-21'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008'', ''RTM Cumulative Update 7''),
                    (10, 1812, ''RTM CU6'', ''https://support.microsoft.com/en-us/help/971490'', ''2009-07-20'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008'', ''RTM Cumulative Update 6''),
                    (10, 1806, ''RTM CU5'', ''https://support.microsoft.com/en-us/help/969531'', ''2009-05-18'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008'', ''RTM Cumulative Update 5''),
                    (10, 1798, ''RTM CU4'', ''https://support.microsoft.com/en-us/help/963036'', ''2009-03-16'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008'', ''RTM Cumulative Update 4''),
                    (10, 1787, ''RTM CU3'', ''https://support.microsoft.com/en-us/help/960484'', ''2009-01-19'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008'', ''RTM Cumulative Update 3''),
                    (10, 1779, ''RTM CU2'', ''https://support.microsoft.com/en-us/help/958186'', ''2008-11-19'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008'', ''RTM Cumulative Update 2''),
                    (10, 1763, ''RTM CU1'', ''https://support.microsoft.com/en-us/help/956717'', ''2008-09-22'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008'', ''RTM Cumulative Update 1''),
                    (10, 1600, ''RTM '', '''', ''2008-08-06'', ''2014-07-08'', ''2019-07-09'', ''SQL Server 2008'', ''RTM '');'

                    EXEC sp_ExecuteSQL @InsertSQL

            END

    END

END


/************************************************************

1.3 - Setup Alerts

************************************************************/

INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
VALUES
(10,'System Wide Alerts',NULL,'These are the settings you have selected to use for this install')

IF @Testing = 0 

BEGIN

    IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name  = 'Severity 016')

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

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (10.1,'Severity 016',NULL,'These are the settings you have selected to use for this install')

        SET @AlertCnt = 1

    END

    IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name  = 'Severity 017')

    BEGIN

        EXEC msdb.dbo.sp_add_alert @name=N'Severity 017',
        @message_id=0,
        @severity=17,
        @enabled=1,
        @delay_between_responses=60,
        @include_event_description_in=1,
        @job_id=N'00000000-0000-0000-0000-000000000000';

        EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 017', @operator_name=N'The DBA Team', @notification_method = 7;

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (10.2,'Severity 017',NULL,'These are the settings you have selected to use for this install')

        SET @AlertCnt = @AlertCnt + 1

    END

    IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name  = 'Severity 018')

        BEGIN

        EXEC msdb.dbo.sp_add_alert @name=N'Severity 018',
        @message_id=0,
        @severity=18,
        @enabled=1,
        @delay_between_responses=60,
        @include_event_description_in=1,
        @job_id=N'00000000-0000-0000-0000-000000000000';

        EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 018', @operator_name=N'The DBA Team', @notification_method = 7;

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (10.3,'Severity 018',NULL,'These are the settings you have selected to use for this install')

        SET @AlertCnt = @AlertCnt + 1

    END

    IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name  = 'Severity 019')

    BEGIN

        EXEC msdb.dbo.sp_add_alert @name=N'Severity 019',
        @message_id=0,
        @severity=19,
        @enabled=1,
        @delay_between_responses=60,
        @include_event_description_in=1,
        @job_id=N'00000000-0000-0000-0000-000000000000';

        EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 019', @operator_name=N'The DBA Team', @notification_method = 7;

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (10.4,'Severity 019',NULL,'These are the settings you have selected to use for this install')

        SET @AlertCnt = @AlertCnt + 1

    END

    IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name  = 'Severity 020')

    BEGIN

        EXEC msdb.dbo.sp_add_alert @name=N'Severity 020',
        @message_id=0,
        @severity=20,
        @enabled=1,
        @delay_between_responses=60,
        @include_event_description_in=1,
        @job_id=N'00000000-0000-0000-0000-000000000000';

        EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 020', @operator_name=N'The DBA Team', @notification_method = 7;

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (10.5,'Severity 020',NULL,'These are the settings you have selected to use for this install')

        SET @AlertCnt = @AlertCnt + 1

    END

    IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name  = 'Severity 021')

    BEGIN

        EXEC msdb.dbo.sp_add_alert @name=N'Severity 021',
        @message_id=0,
        @severity=21,
        @enabled=1,
        @delay_between_responses=60,
        @include_event_description_in=1,
        @job_id=N'00000000-0000-0000-0000-000000000000';

        EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 021', @operator_name=N'The DBA Team', @notification_method = 7;

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (10.6,'Severity 021',NULL,'These are the settings you have selected to use for this install')

        SET @AlertCnt = @AlertCnt + 1

    END

    IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name  = 'Severity 022')

    BEGIN

        EXEC msdb.dbo.sp_add_alert @name=N'Severity 022',
        @message_id=0,
        @severity=22,
        @enabled=1,
        @delay_between_responses=60,
        @include_event_description_in=1,
        @job_id=N'00000000-0000-0000-0000-000000000000';

        EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 022', @operator_name=N'The DBA Team', @notification_method = 7;

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (10.7,'Severity 022',NULL,'These are the settings you have selected to use for this install')

        SET @AlertCnt = @AlertCnt + 1

    END

    IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name  = 'Severity 023')

    BEGIN

        EXEC msdb.dbo.sp_add_alert @name=N'Severity 023',
        @message_id=0,
        @severity=23,
        @enabled=1,
        @delay_between_responses=60,
        @include_event_description_in=1,
        @job_id=N'00000000-0000-0000-0000-000000000000';

        EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 023', @operator_name=N'The DBA Team', @notification_method = 7;

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (10.8,'Severity 023',NULL,'These are the settings you have selected to use for this install')

        SET @AlertCnt = @AlertCnt + 1

    END

    IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name  = 'Severity 024')

    BEGIN

        EXEC msdb.dbo.sp_add_alert @name=N'Severity 024',
        @message_id=0,
        @severity=24,
        @enabled=1,
        @delay_between_responses=60,
        @include_event_description_in=1,
        @job_id=N'00000000-0000-0000-0000-000000000000';

        EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 024', @operator_name=N'The DBA Team', @notification_method = 7;

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (10.9,'Severity 024',NULL,'These are the settings you have selected to use for this install')

        SET @AlertCnt = @AlertCnt + 1

    END

    IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name  = 'Severity 025')

    BEGIN

        EXEC msdb.dbo.sp_add_alert @name=N'Severity 025',
        @message_id=0,
        @severity=25,
        @enabled=1,
        @delay_between_responses=60,
        @include_event_description_in=1,
        @job_id=N'00000000-0000-0000-0000-000000000000';

        EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 025', @operator_name=N'The DBA Team', @notification_method = 7;

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (10.10,'Severity 025',NULL,'These are the settings you have selected to use for this install')

        SET @AlertCnt = @AlertCnt + 1

    END

    IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name  = 'Error Number 823')

    BEGIN

        EXEC msdb.dbo.sp_add_alert @name=N'Error Number 823',
        @message_id=823,
        @severity=0,
        @enabled=1,
        @delay_between_responses=60,
        @include_event_description_in=1,
        @job_id=N'00000000-0000-0000-0000-000000000000';

        EXEC msdb.dbo.sp_add_notification @alert_name=N'Error Number 823', @operator_name=N'The DBA Team', @notification_method = 7;

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (10.11,'Error Number 823',NULL,'These are the settings you have selected to use for this install')

        SET @AlertCnt = @AlertCnt + 1

    END

    IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name  = 'Error Number 824')

    BEGIN

        EXEC msdb.dbo.sp_add_alert @name=N'Error Number 824',
        @message_id=824,
        @severity=0,
        @enabled=1,
        @delay_between_responses=60,
        @include_event_description_in=1,
        @job_id=N'00000000-0000-0000-0000-000000000000';

        EXEC msdb.dbo.sp_add_notification @alert_name=N'Error Number 824', @operator_name=N'The DBA Team', @notification_method = 7;

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (10.12,'Error Number 824',NULL,'These are the settings you have selected to use for this install')

        SET @AlertCnt = @AlertCnt + 1

    END

    IF NOT EXISTS (SELECT name FROM msdb.dbo.sysalerts WHERE name  = 'Error Number 825')

    BEGIN

        EXEC msdb.dbo.sp_add_alert @name=N'Error Number 825',
        @message_id=825,
        @severity=0,
        @enabled=1,
        @delay_between_responses=60,
        @include_event_description_in=1,
        @job_id=N'00000000-0000-0000-0000-000000000000';

        EXEC msdb.dbo.sp_add_notification @alert_name=N'Error Number 825', @operator_name=N'The DBA Team', @notification_method = 7;

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (10.13,'Error Number 825',NULL,'These are the settings you have selected to use for this install')

        SET @AlertCnt = @AlertCnt + 1

    END

END

INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
VALUES
(10.14,'Total Errors Added',CAST((CASE WHEN @AlertCnt = 0 THEN NULL ELSE @AlertCnt END) as varchar),'These are the settings you have selected to use for this install')

/************************************************************

1. - Setup Default Backup Compression

************************************************************/

IF @Testing = 0 

BEGIN

EXEC sp_configure 'backup compression default', @CompressBackups;  

RECONFIGURE WITH OVERRIDE;

INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
VALUES
(11,'Backup Compression Settings',NULL,'These are the settings you have selected to use for this install'),
(11.1,'Are backups being compressed by default',CASE WHEN @CompressBackups = 1 THEN 'Yes' ELSE 'No' END,'These are the settings you have selected to use for this install')

END
 
/************************************************************

1. - DBA_Tasks Database Check & Creation

************************************************************/

IF @Testing = 0 

BEGIN

IF NOT EXISTS (SELECT name from sys.databases where name = @DatabaseName) 

	BEGIN

        SET @CreateDB = 'CREATE DATABASE ' + QUOTENAME(@DatabaseName) + ''

        EXEC sp_executesql @CreateDB

        INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
        VALUES
        (12,'Default DBA Database',NULL,'These are the settings you have selected to use for this install'),
        (12.1,'Database Created',@DatabaseName,'These are the settings you have selected to use for this install')

	END	

END

/************************************************************

1. - Availablity Group Check Job

************************************************************/

IF @Testing = 0 

    BEGIN

    IF @ProductVersionMajor >= 12.0

    BEGIN

    INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
    VALUES
    (13,'Default DBA Database',NULL,'These are the settings you have selected to use for this install'),
    (13.1,'Database Created',@DatabaseName,'These are the settings you have selected to use for this install')

    END

END

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
    (14,'Default DBA Database',NULL,'These are the settings you have selected to use for this install',NULL),
    (14.1,'Database Created','Agent Job has been created','This agent job is used to run the availability group member check','https://www.codenameowl.com/managing-agent-jobs-in-availability-groups/')
    
    END

    ELSE 

    BEGIN

    INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes)
    VALUES
    (14,'Availability Member Check',NULL,'These are the settings you have selected to use for this install'),
    (14.1,'Availability Member Agent Job','Agent Job Already Exists, SKIPPING',NULL)

    END

    END

/************************************************************

1. - Check for tools

************************************************************/

IF @Testing = 0 

BEGIN

    IF EXISTS (SELECT name from msdb.sys.databases where name = @DatabaseName) 

    BEGIN

        SET @OlaExists = (SELECT COUNT(name) from sys.objects where (name = 'DatabaseBackup' or name = 'DatabaseIntegrityCheck' or name = 'CommandExecute' or name = 'IndexOptimize'))

        IF @OlaExists = 0 

        BEGIN

            INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes,Reference_URL)
            VALUES
            (15,'Ola Scripts',NULL,'These are the settings you have selected to use for this install',NULL),
            (15.1,'Ola Scripts Missing',NULL,'Ola Scripts dont exist, they are good you know, go get them and set them up','https://ola.hallengren.com/')

        END

        ELSE

        BEGIN

            INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes,Reference_URL)
            VALUES
            (15,'Ola Scripts',NULL,'These are the settings you have selected to use for this install',NULL),
            (15.1,'Ola Scripts Exist',NULL,'Ola Scripts, exist, they may need confiuring check the reference URL for documentation','https://ola.hallengren.com/')

        END

        SET @OzarExists = (SELECT COUNT(name) from sys.objects where (name = 'sp_Blitz' or name = 'sp_BlitzBackups' or name = 'sp_BlitzCache' or name = 'sp_BlitzFirst' or name = 'sp_BlitzIndex' or name = 'sp_BlitzInMemoryOLTP' or name = 'sp_BlitzLock' or name = 'sp_BlitzQueryStore' or name = 'sp_BlitzWho'))

        IF @OzarExists = 0 

        BEGIN

            INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes,Reference_URL)
            VALUES
            (16,'First Responder Kit',NULL,'These are the settings you have selected to use for this install',NULL),
            (16.1,'Database Created',NULL,'Looks like none of the First Responder Kit exist here, these are some great tools, go grab them, they may just save the day.','https://www.brentozar.com/first-aid/')

        END

        ELSE 

        BEGIN

            INSERT INTO #Actions (Step_ID,Section_Name,[Value],Notes,Reference_URL)
            VALUES
            (15,'First Responder Kit',NULL,'These are the settings you have selected to use for this install',NULL),
            (15.1,'First Responder Kit Exists',NULL,'Looks like the First Responder Kit exists here, if you are unsure how to use them, check out the documentation.','https://www.brentozar.com/first-aid/')

        END

    END

END

SELECT * FROM #Actions
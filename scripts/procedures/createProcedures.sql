CREATE PROCEDURE [DBA].[GetInstanceCPUUsage]

AS

BEGIN

SET NOCOUNT ON;

	BEGIN TRY

	DECLARE @ms_ticks_now BIGINT
	SELECT @ms_ticks_now = [ms_ticks]
	FROM sys.dm_os_sys_info;

	INSERT INTO [DBA].[InstanceCPUUsage]
	(
		[Instance]
		,[RecordID]
		,[EventTime]
		,[SQLProcess(%)]
		,[SystemIdle]
		,[OtherProcess(%)]
	  )

	SELECT TOP 15
		@@SERVERNAME [Instance]
		,y.[record_id]
		,DATEADD(ms, - 1 * (@ms_ticks_now - [timestamp]), GETDATE()) AS [EventTime]
		,y.[SQLProcess (%)]
		,y.[SystemIdle]
		,100 - y.[SystemIdle] - [SQLProcess (%)] AS [OtherProcess (%)]
	FROM (
    SELECT 
		record.value('(./Record/@id)[1]', 'int') AS [record_id]
        ,record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') AS [SystemIdle]
        ,record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS [SQLProcess (%)]
        ,[TIMESTAMP]
    FROM (
        SELECT 
			[TIMESTAMP]
            ,convert(XML, [record]) AS [record]
        FROM 
			sys.dm_os_ring_buffers
        WHERE 
			[ring_buffer_type] = N'RING_BUFFER_SCHEDULER_MONITOR'
            AND [record] LIKE '%<SystemHealth>%'
        ) AS x
    ) AS y
	
	LEFT JOIN [DBA].[InstanceCPUUsage] u
		ON y.[record_id] = u.[RecordID]
	
	WHERE 
		u.[RecordID] IS NULL 
		AND (DATEADD(ms, - 1 * (@ms_ticks_now - [timestamp]), GETDATE()) > DATEADD(mi,-15,GETDATE()))
	
	ORDER BY 
		y.[record_id] DESC

	DECLARE @maxDays int
	DECLARE @maxDate date

	SET @maxDays = -31
	SET @maxDate = DATEADD(dd,@maxDays,GETDATE())

	DELETE FROM [DBA].[InstanceCPUUsage]
	WHERE 	
	CAST([EventTime] AS date) < @maxDate	

	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0 ROLLBACK
		;
		THROW
		;
	END CATCH
END

CREATE PROCEDURE [DBA].[CompareDAGAgentJobDefinitions]

AS

BEGIN

SET NOCOUNT ON;

	BEGIN TRY

		DECLARE @Availability_Role nvarchar(20)

		SET @Availability_Role = 
			(
			SELECT ars.role_desc
			FROM 
				sys.dm_hadr_availability_replica_states AS ars 
				
				INNER JOIN sys.availability_groups AS ag 
					ON ars.group_id = ag.group_id

			WHERE 
				ag.name = 'AVAILABILITY GROUP NAME HERE' 
				and ars.is_local = 1
			)

		IF @Availability_Role = 'SECONDARY'
		BEGIN
		WAITFOR DELAY '00:00:20'; 
		END

		IF @Availability_Role = 'PRIMARY'

			BEGIN

				DECLARE @maxDays int
				DECLARE @maxDate date

				SET @maxDays = -30
				SET @maxDate = DATEADD(dd,@maxDays,GETDATE())

				print @maxDays
				print @maxDate

				DELETE FROM [DBA].[AgentJobDetailsLog]
				WHERE CAST([AuditDate] AS DATE) < @maxDate

				DELETE FROM [DBA].[AgentJobDetailsLog]
				WHERE CAST([AuditDate] AS DATE) = CAST(GETDATE() AS DATE)

				INSERT INTO [DBA].[AgentJobDetailsLog] 
				(
					[JobName]
					,[JobOwner]
					,[JobCategory]
					,[JobDescription]
					,[IsEnabled]
					,[JobCreatedOn]
					,[JobLastModifiedOn]
					,[OriginatingServerName]
					,[JobStartStepNo]
					,[JobStartStepName]
					,[IsScheduled]
					,[JobScheduleName]
					,[JobDeletionCriterion]
					,[ScheduleType]
					,[Occurrence]
					,[Recurrence]
					,[Frequency]
					,[ScheduleUsageStartDate]
					,[ScheduleUsageEndDate]
					,[ScheduleCreatedOn]
					,[ScheduleLastModifiedOn]
					,[StepNo]
					,[StepName]
					,[StepType]
					,[RunAs]
					,[Database]
					,[ExecutableCommand]
					,[OnSuccessAction]
					,[RetryAttempts]
					,[RetryInterval (Minutes)]
					,[OnFailureAction]
				)
				SELECT 
					[sJOB].[name] AS [JobName]
					, [sDBP].[name] AS [JobOwner]
					, [sCAT].[name] AS [JobCategory]
					, [sJOB].[description] AS [JobDescription]
					, CASE [sJOB].[enabled]
						WHEN 1 THEN 'Yes'
						WHEN 0 THEN 'No'
					  END AS [IsEnabled]
					, [sJOB].[date_created] AS [JobCreatedOn]
					, [sJOB].[date_modified] AS [JobLastModifiedOn]
					, [sSVR].[name] AS [OriginatingServerName]
					, [sJSTP].[step_id] AS [JobStartStepNo]
					, [sJSTP].[step_name] AS [JobStartStepName]
					, CASE
						WHEN [sSCH].[schedule_uid] IS NULL THEN 'No'
						ELSE 'Yes'
					  END AS [IsScheduled]
					, [sSCH].[name] AS [JobScheduleName]
					, CASE [sJOB].[delete_level]
						WHEN 0 THEN 'Never'
						WHEN 1 THEN 'On Success'
						WHEN 2 THEN 'On Failure'
						WHEN 3 THEN 'On Completion'
					  END AS [JobDeletionCriterion]
					, CASE 
						WHEN [freq_type] = 64 THEN 'Start automatically when SQL Server Agent starts'
						WHEN [freq_type] = 128 THEN 'Start whenever the CPUs become idle'
						WHEN [freq_type] IN (4,8,16,32) THEN 'Recurring'
						WHEN [freq_type] = 1 THEN 'One Time'
					  END [ScheduleType]
					, CASE [freq_type]
						WHEN 1 THEN 'One Time'
						WHEN 4 THEN 'Daily'
						WHEN 8 THEN 'Weekly'
						WHEN 16 THEN 'Monthly'
						WHEN 32 THEN 'Monthly - Relative to Frequency Interval'
						WHEN 64 THEN 'Start automatically when SQL Server Agent starts'
						WHEN 128 THEN 'Start whenever the CPUs become idle'
					  END [Occurrence]
					, CASE [freq_type]
						WHEN 4 THEN 'Occurs every ' + CAST([freq_interval] AS VARCHAR(3)) + ' day(s)'
						WHEN 8 THEN 'Occurs every ' + CAST([freq_recurrence_factor] AS VARCHAR(3)) 
									+ ' week(s) on '
									+ CASE WHEN [freq_interval] & 1 = 1 THEN 'Sunday' ELSE '' END
									+ CASE WHEN [freq_interval] & 2 = 2 THEN ', Monday' ELSE '' END
									+ CASE WHEN [freq_interval] & 4 = 4 THEN ', Tuesday' ELSE '' END
									+ CASE WHEN [freq_interval] & 8 = 8 THEN ', Wednesday' ELSE '' END
									+ CASE WHEN [freq_interval] & 16 = 16 THEN ', Thursday' ELSE '' END
									+ CASE WHEN [freq_interval] & 32 = 32 THEN ', Friday' ELSE '' END
									+ CASE WHEN [freq_interval] & 64 = 64 THEN ', Saturday' ELSE '' END
						WHEN 16 THEN 'Occurs on Day ' + CAST([freq_interval] AS VARCHAR(3)) 
									 + ' of every '
									 + CAST([freq_recurrence_factor] AS VARCHAR(3)) + ' month(s)'
						WHEN 32 THEN 'Occurs on '
									 + CASE [freq_relative_interval]
										WHEN 1 THEN 'First'
										WHEN 2 THEN 'Second'
										WHEN 4 THEN 'Third'
										WHEN 8 THEN 'Fourth'
										WHEN 16 THEN 'Last'
									   END
									 + ' ' 
									 + CASE [freq_interval]
										WHEN 1 THEN 'Sunday'
										WHEN 2 THEN 'Monday'
										WHEN 3 THEN 'Tuesday'
										WHEN 4 THEN 'Wednesday'
										WHEN 5 THEN 'Thursday'
										WHEN 6 THEN 'Friday'
										WHEN 7 THEN 'Saturday'
										WHEN 8 THEN 'Day'
										WHEN 9 THEN 'Weekday'
										WHEN 10 THEN 'Weekend day'
									   END
									 + ' of every ' + CAST([freq_recurrence_factor] AS VARCHAR(3)) 
									 + ' month(s)'
					  END AS [Recurrence]
					, CASE [freq_subday_type]
						WHEN 1 THEN 'Occurs once at ' 
									+ STUFF(
								 STUFF(RIGHT('000000' + CAST([active_start_time] AS VARCHAR(6)), 6)
												, 3, 0, ':')
											, 6, 0, ':')
						WHEN 2 THEN 'Occurs every ' 
									+ CAST([freq_subday_interval] AS VARCHAR(3)) + ' Second(s) between ' 
									+ STUFF(
								   STUFF(RIGHT('000000' + CAST([active_start_time] AS VARCHAR(6)), 6)
												, 3, 0, ':')
											, 6, 0, ':')
									+ ' & ' 
									+ STUFF(
									STUFF(RIGHT('000000' + CAST([active_end_time] AS VARCHAR(6)), 6)
												, 3, 0, ':')
											, 6, 0, ':')
						WHEN 4 THEN 'Occurs every ' 
									+ CAST([freq_subday_interval] AS VARCHAR(3)) + ' Minute(s) between ' 
									+ STUFF(
								   STUFF(RIGHT('000000' + CAST([active_start_time] AS VARCHAR(6)), 6)
												, 3, 0, ':')
											, 6, 0, ':')
									+ ' & ' 
									+ STUFF(
									STUFF(RIGHT('000000' + CAST([active_end_time] AS VARCHAR(6)), 6)
												, 3, 0, ':')
											, 6, 0, ':')
						WHEN 8 THEN 'Occurs every ' 
									+ CAST([freq_subday_interval] AS VARCHAR(3)) + ' Hour(s) between ' 
									+ STUFF(
									STUFF(RIGHT('000000' + CAST([active_start_time] AS VARCHAR(6)), 6)
												, 3, 0, ':')
											, 6, 0, ':')
									+ ' & ' 
									+ STUFF(
									STUFF(RIGHT('000000' + CAST([active_end_time] AS VARCHAR(6)), 6)
												, 3, 0, ':')
											, 6, 0, ':')
					  END [Frequency]
					, STUFF(
							STUFF(CAST([active_start_date] AS VARCHAR(8)), 5, 0, '-')
								, 8, 0, '-') AS [ScheduleUsageStartDate]
					, STUFF(
							STUFF(CAST([active_end_date] AS VARCHAR(8)), 5, 0, '-')
								, 8, 0, '-') AS [ScheduleUsageEndDate]
					, [sSCH].[date_created] AS [ScheduleCreatedOn]
					, [sSCH].[date_modified] AS [ScheduleLastModifiedOn]
					, [sJSTP].[step_id] AS [StepNo]
					, [sJSTP].[step_name] AS [StepName]
					, CASE [sJSTP].[subsystem]
						WHEN 'ActiveScripting' THEN 'ActiveX Script'
						WHEN 'CmdExec' THEN 'Operating system (CmdExec)'
						WHEN 'PowerShell' THEN 'PowerShell'
						WHEN 'Distribution' THEN 'Replication Distributor'
						WHEN 'Merge' THEN 'Replication Merge'
						WHEN 'QueueReader' THEN 'Replication Queue Reader'
						WHEN 'Snapshot' THEN 'Replication Snapshot'
						WHEN 'LogReader' THEN 'Replication Transaction-Log Reader'
						WHEN 'ANALYSISCOMMAND' THEN 'SQL Server Analysis Services Command'
						WHEN 'ANALYSISQUERY' THEN 'SQL Server Analysis Services Query'
						WHEN 'SSIS' THEN 'SQL Server Integration Services Package'
						WHEN 'TSQL' THEN 'Transact-SQL script (T-SQL)'
						ELSE sJSTP.subsystem
					  END AS [StepType]
					, [sPROX].[name] AS [RunAs]
					, [sJSTP].[database_name] AS [Database]
					, [sJSTP].[command] AS [ExecutableCommand]
					, CASE [sJSTP].[on_success_action]
						WHEN 1 THEN 'Quit the job reporting success'
						WHEN 2 THEN 'Quit the job reporting failure'
						WHEN 3 THEN 'Go to the next step'
						WHEN 4 THEN 'Go to Step: ' 
									+ QUOTENAME(CAST([sJSTP].[on_success_step_id] AS VARCHAR(3))) 
									+ ' ' 
									+ [sOSSTP].[step_name]
					  END AS [OnSuccessAction]
					, [sJSTP].[retry_attempts] AS [RetryAttempts]
					, [sJSTP].[retry_interval] AS [RetryInterval (Minutes)]
					, CASE [sJSTP].[on_fail_action]
						WHEN 1 THEN 'Quit the job reporting success'
						WHEN 2 THEN 'Quit the job reporting failure'
						WHEN 3 THEN 'Go to the next step'
						WHEN 4 THEN 'Go to Step: ' 
									+ QUOTENAME(CAST([sJSTP].[on_fail_step_id] AS VARCHAR(3))) 
									+ ' ' 
									+ [sOFSTP].[step_name]
					  END AS [OnFailureAction]
				FROM
					[msdb].[dbo].[sysjobs] AS [sJOB]
					
					LEFT JOIN [msdb].[sys].[servers] AS [sSVR]
						ON [sJOB].[originating_server_id] = [sSVR].[server_id]
					
					LEFT JOIN [msdb].[dbo].[syscategories] AS [sCAT]
						ON [sJOB].[category_id] = [sCAT].[category_id]
					
					LEFT JOIN [msdb].[dbo].[sysjobsteps] AS [sJSTP]
						ON [sJOB].[job_id] = [sJSTP].[job_id]
				   
				   LEFT JOIN [msdb].[dbo].[sysjobsteps] AS [sOSSTP]
						ON [sJSTP].[job_id] = [sOSSTP].[job_id]
						AND [sJSTP].[on_success_step_id] = [sOSSTP].[step_id]
					
					LEFT JOIN [msdb].[dbo].[sysjobsteps] AS [sOFSTP]
						ON [sJSTP].[job_id] = [sOFSTP].[job_id]
						AND [sJSTP].[on_fail_step_id] = [sOFSTP].[step_id]
					
					LEFT JOIN [msdb].[dbo].[sysproxies] AS [sPROX]
						ON [sJSTP].[proxy_id] = [sPROX].[proxy_id]
					
					LEFT JOIN [master].[sys].[server_principals] AS [sDBP]
						ON [sJOB].[owner_sid] = [sDBP].[sid]
					
					LEFT JOIN [msdb].[dbo].[sysjobschedules] AS [sJOBSCH]
						ON [sJOB].[job_id] = [sJOBSCH].[job_id]
					
					LEFT JOIN [msdb].[dbo].[sysschedules] AS [sSCH]
						ON [sJOBSCH].[schedule_id] = [sSCH].[schedule_id]
			END
		ELSE
			BEGIN

				SELECT 
					[sJOB].[name] AS [JobName]
					, [sDBP].[name] AS [JobOwner]
					, [sCAT].[name] AS [JobCategory]
					, [sJOB].[description] AS [JobDescription]
					, CASE [sJOB].[enabled]
						WHEN 1 THEN 'Yes'
						WHEN 0 THEN 'No'
					  END AS [IsEnabled]
					, [sJOB].[date_created] AS [JobCreatedOn]
					, [sJOB].[date_modified] AS [JobLastModifiedOn]
					, [sSVR].[name] AS [OriginatingServerName]
					, [sJSTP].[step_id] AS [JobStartStepNo]
					, [sJSTP].[step_name] AS [JobStartStepName]
					, CASE
						WHEN [sSCH].[schedule_uid] IS NULL THEN 'No'
						ELSE 'Yes'
					  END AS [IsScheduled]
					, [sSCH].[name] AS [JobScheduleName]
					, CASE [sJOB].[delete_level]
						WHEN 0 THEN 'Never'
						WHEN 1 THEN 'On Success'
						WHEN 2 THEN 'On Failure'
						WHEN 3 THEN 'On Completion'
					  END AS [JobDeletionCriterion]
					, CASE 
						WHEN [freq_type] = 64 THEN 'Start automatically when SQL Server Agent starts'
						WHEN [freq_type] = 128 THEN 'Start whenever the CPUs become idle'
						WHEN [freq_type] IN (4,8,16,32) THEN 'Recurring'
						WHEN [freq_type] = 1 THEN 'One Time'
					  END [ScheduleType]
					, CASE [freq_type]
						WHEN 1 THEN 'One Time'
						WHEN 4 THEN 'Daily'
						WHEN 8 THEN 'Weekly'
						WHEN 16 THEN 'Monthly'
						WHEN 32 THEN 'Monthly - Relative to Frequency Interval'
						WHEN 64 THEN 'Start automatically when SQL Server Agent starts'
						WHEN 128 THEN 'Start whenever the CPUs become idle'
					  END [Occurrence]
					, CASE [freq_type]
						WHEN 4 THEN 'Occurs every ' + CAST([freq_interval] AS VARCHAR(3)) + ' day(s)'
						WHEN 8 THEN 'Occurs every ' + CAST([freq_recurrence_factor] AS VARCHAR(3)) 
									+ ' week(s) on '
									+ CASE WHEN [freq_interval] & 1 = 1 THEN 'Sunday' ELSE '' END
									+ CASE WHEN [freq_interval] & 2 = 2 THEN ', Monday' ELSE '' END
									+ CASE WHEN [freq_interval] & 4 = 4 THEN ', Tuesday' ELSE '' END
									+ CASE WHEN [freq_interval] & 8 = 8 THEN ', Wednesday' ELSE '' END
									+ CASE WHEN [freq_interval] & 16 = 16 THEN ', Thursday' ELSE '' END
									+ CASE WHEN [freq_interval] & 32 = 32 THEN ', Friday' ELSE '' END
									+ CASE WHEN [freq_interval] & 64 = 64 THEN ', Saturday' ELSE '' END
						WHEN 16 THEN 'Occurs on Day ' + CAST([freq_interval] AS VARCHAR(3)) 
									 + ' of every '
									 + CAST([freq_recurrence_factor] AS VARCHAR(3)) + ' month(s)'
						WHEN 32 THEN 'Occurs on '
									 + CASE [freq_relative_interval]
										WHEN 1 THEN 'First'
										WHEN 2 THEN 'Second'
										WHEN 4 THEN 'Third'
										WHEN 8 THEN 'Fourth'
										WHEN 16 THEN 'Last'
									   END
									 + ' ' 
									 + CASE [freq_interval]
										WHEN 1 THEN 'Sunday'
										WHEN 2 THEN 'Monday'
										WHEN 3 THEN 'Tuesday'
										WHEN 4 THEN 'Wednesday'
										WHEN 5 THEN 'Thursday'
										WHEN 6 THEN 'Friday'
										WHEN 7 THEN 'Saturday'
										WHEN 8 THEN 'Day'
										WHEN 9 THEN 'Weekday'
										WHEN 10 THEN 'Weekend day'
									   END
									 + ' of every ' + CAST([freq_recurrence_factor] AS VARCHAR(3)) 
									 + ' month(s)'
					  END AS [Recurrence]
					, CASE [freq_subday_type]
						WHEN 1 THEN 'Occurs once at ' 
									+ STUFF(
								 STUFF(RIGHT('000000' + CAST([active_start_time] AS VARCHAR(6)), 6)
												, 3, 0, ':')
											, 6, 0, ':')
						WHEN 2 THEN 'Occurs every ' 
									+ CAST([freq_subday_interval] AS VARCHAR(3)) + ' Second(s) between ' 
									+ STUFF(
								   STUFF(RIGHT('000000' + CAST([active_start_time] AS VARCHAR(6)), 6)
												, 3, 0, ':')
											, 6, 0, ':')
									+ ' & ' 
									+ STUFF(
									STUFF(RIGHT('000000' + CAST([active_end_time] AS VARCHAR(6)), 6)
												, 3, 0, ':')
											, 6, 0, ':')
						WHEN 4 THEN 'Occurs every ' 
									+ CAST([freq_subday_interval] AS VARCHAR(3)) + ' Minute(s) between ' 
									+ STUFF(
								   STUFF(RIGHT('000000' + CAST([active_start_time] AS VARCHAR(6)), 6)
												, 3, 0, ':')
											, 6, 0, ':')
									+ ' & ' 
									+ STUFF(
									STUFF(RIGHT('000000' + CAST([active_end_time] AS VARCHAR(6)), 6)
												, 3, 0, ':')
											, 6, 0, ':')
						WHEN 8 THEN 'Occurs every ' 
									+ CAST([freq_subday_interval] AS VARCHAR(3)) + ' Hour(s) between ' 
									+ STUFF(
									STUFF(RIGHT('000000' + CAST([active_start_time] AS VARCHAR(6)), 6)
												, 3, 0, ':')
											, 6, 0, ':')
									+ ' & ' 
									+ STUFF(
									STUFF(RIGHT('000000' + CAST([active_end_time] AS VARCHAR(6)), 6)
												, 3, 0, ':')
											, 6, 0, ':')
					  END [Frequency]
					, STUFF(
							STUFF(CAST([active_start_date] AS VARCHAR(8)), 5, 0, '-')
								, 8, 0, '-') AS [ScheduleUsageStartDate]
					, STUFF(
							STUFF(CAST([active_end_date] AS VARCHAR(8)), 5, 0, '-')
								, 8, 0, '-') AS [ScheduleUsageEndDate]
					, [sSCH].[date_created] AS [ScheduleCreatedOn]
					, [sSCH].[date_modified] AS [ScheduleLastModifiedOn]
					, [sJSTP].[step_id] AS [StepNo]
					, [sJSTP].[step_name] AS [StepName]
					, CASE [sJSTP].[subsystem]
						WHEN 'ActiveScripting' THEN 'ActiveX Script'
						WHEN 'CmdExec' THEN 'Operating system (CmdExec)'
						WHEN 'PowerShell' THEN 'PowerShell'
						WHEN 'Distribution' THEN 'Replication Distributor'
						WHEN 'Merge' THEN 'Replication Merge'
						WHEN 'QueueReader' THEN 'Replication Queue Reader'
						WHEN 'Snapshot' THEN 'Replication Snapshot'
						WHEN 'LogReader' THEN 'Replication Transaction-Log Reader'
						WHEN 'ANALYSISCOMMAND' THEN 'SQL Server Analysis Services Command'
						WHEN 'ANALYSISQUERY' THEN 'SQL Server Analysis Services Query'
						WHEN 'SSIS' THEN 'SQL Server Integration Services Package'
						WHEN 'TSQL' THEN 'Transact-SQL script (T-SQL)'
						ELSE sJSTP.subsystem
					  END AS [StepType]
					, [sPROX].[name] AS [RunAs]
					, [sJSTP].[database_name] AS [Database]
					, [sJSTP].[command] AS [ExecutableCommand]
					, CASE [sJSTP].[on_success_action]
						WHEN 1 THEN 'Quit the job reporting success'
						WHEN 2 THEN 'Quit the job reporting failure'
						WHEN 3 THEN 'Go to the next step'
						WHEN 4 THEN 'Go to Step: ' 
									+ QUOTENAME(CAST([sJSTP].[on_success_step_id] AS VARCHAR(3))) 
									+ ' ' 
									+ [sOSSTP].[step_name]
					  END AS [OnSuccessAction]
					, [sJSTP].[retry_attempts] AS [RetryAttempts]
					, [sJSTP].[retry_interval] AS [RetryInterval (Minutes)]
					, CASE [sJSTP].[on_fail_action]
						WHEN 1 THEN 'Quit the job reporting success'
						WHEN 2 THEN 'Quit the job reporting failure'
						WHEN 3 THEN 'Go to the next step'
						WHEN 4 THEN 'Go to Step: ' 
									+ QUOTENAME(CAST([sJSTP].[on_fail_step_id] AS VARCHAR(3))) 
									+ ' ' 
									+ [sOFSTP].[step_name]
					  END AS [OnFailureAction]
					INTO  #AgentJobDetailsLog
				FROM
					[msdb].[dbo].[sysjobs] AS [sJOB]
					
					LEFT JOIN [msdb].[sys].[servers] AS [sSVR]
						ON [sJOB].[originating_server_id] = [sSVR].[server_id]
					
					LEFT JOIN [msdb].[dbo].[syscategories] AS [sCAT]
						ON [sJOB].[category_id] = [sCAT].[category_id]
					
					LEFT JOIN [msdb].[dbo].[sysjobsteps] AS [sJSTP]
						ON [sJOB].[job_id] = [sJSTP].[job_id]
				   	
					LEFT JOIN [msdb].[dbo].[sysjobsteps] AS [sOSSTP]
						ON [sJSTP].[job_id] = [sOSSTP].[job_id]
					AND [sJSTP].[on_success_step_id] = [sOSSTP].[step_id]
					
					LEFT JOIN [msdb].[dbo].[sysjobsteps] AS [sOFSTP]
						ON [sJSTP].[job_id] = [sOFSTP].[job_id]
						AND [sJSTP].[on_fail_step_id] = [sOFSTP].[step_id]
					
					LEFT JOIN [msdb].[dbo].[sysproxies] AS [sPROX]
						ON [sJSTP].[proxy_id] = [sPROX].[proxy_id]
					
					LEFT JOIN [master].[sys].[server_principals] AS [sDBP]
						ON [sJOB].[owner_sid] = [sDBP].[sid]
					
					LEFT JOIN [msdb].[dbo].[sysjobschedules] AS [sJOBSCH]
						ON [sJOB].[job_id] = [sJOBSCH].[job_id]
					
					LEFT JOIN [msdb].[dbo].[sysschedules] AS [sSCH]
						ON [sJOBSCH].[schedule_id] = [sSCH].[schedule_id]
			IF EXISTS
			(
			SELECT 
				lower([JobName])[JobName]
				,[JobOwner]
				,[JobCategory]
				,lower([JobDescription])[JobDescription]
				,[JobStartStepNo]
				,lower([JobStartStepName])[JobStartStepName]
				,[IsScheduled]
				,lower([JobScheduleName])[JobScheduleName]
				,[JobDeletionCriterion]
				,[ScheduleType]
				,[Occurrence]
				,[Recurrence]
				,[Frequency]
				,[ScheduleUsageEndDate]
				,[StepNo]
				,lower([StepName])[StepName]
				,lower([StepType])[StepType]
				,[RunAs]
				,lower([Database])[Database]
				,[OnSuccessAction]
				,[RetryAttempts]
				,[RetryInterval (Minutes)]
				,[OnFailureAction]
				,CASE 
					WHEN lower([ExecutableCommand]) IS NOT NULL THEN 1 
					ELSE 0 
				END AS [ExecutableCommand]
				,lower([JobDescription])[JobDescription]
				,lower([ExecutableCommand]) [ExecutableCommand]
			  FROM 
			  	[DBA].[AgentJobDetailsLog]
			  WHERE 
			  	CAST([AuditDate] AS DATE) = cast(getdate() as date)
			  AND [JobName] NOT IN ('')
			  
			  EXCEPT
			  
			  SELECT 
				lower([JobName])[JobName]
				,[JobOwner]
				,[JobCategory]
				,lower([JobDescription])[JobDescription]
				,[JobStartStepNo]
				,lower([JobStartStepName])[JobStartStepName]
				,[IsScheduled]
				,lower([JobScheduleName])[JobScheduleName]
				,[JobDeletionCriterion]
				,[ScheduleType]
				,[Occurrence]
				,[Recurrence]
				,[Frequency]
				,[ScheduleUsageEndDate]
				,[StepNo]
				,lower([StepName])[StepName]
				,lower([StepType])[StepType]
				,[RunAs]
				,lower([Database])[Database]
				,[OnSuccessAction]
				,[RetryAttempts]
				,[RetryInterval (Minutes)]
				,[OnFailureAction]
				,CASE 
					WHEN lower([ExecutableCommand]) IS NOT NULL THEN 1 
					ELSE 0 
				END AS [ExecutableCommand]
				,lower([JobDescription])[JobDescription]
				,lower([ExecutableCommand]) [ExecutableCommand]
			  FROM 
			  	#AgentJobDetailsLog
			  WHERE 
			  	[JobName] NOT IN ('')
			)
			OR EXISTS(
			  SELECT 
				  lower([JobName])[JobName]
				  ,[JobOwner]
				  ,[JobCategory]
				  ,lower([JobDescription])[JobDescription]
				  ,[JobStartStepNo]
				  ,lower([JobStartStepName])[JobStartStepName]
				  ,[IsScheduled]
				  ,lower([JobScheduleName])[JobScheduleName]
				  ,[JobDeletionCriterion]
				  ,[ScheduleType]
				  ,[Occurrence]
				  ,[Recurrence]
				  ,[Frequency]
				  ,[ScheduleUsageEndDate]
				  ,[StepNo]
				  ,lower([StepName])[StepName]
				  ,lower([StepType])[StepType]
				  ,[RunAs]
				  ,lower([Database])[Database]
				  ,[OnSuccessAction]
				  ,[RetryAttempts]
				  ,[RetryInterval (Minutes)]
				  ,[OnFailureAction]
				  ,CASE when lower([ExecutableCommand]) is not null then 1 else 0 end as [ExecutableCommand]
				  ,lower([JobDescription])[JobDescription]
				  ,lower([ExecutableCommand]) [ExecutableCommand]
			  FROM #AgentJobDetailsLog
			  WHERE [JobName] NOT IN ('')
			  except
			  SELECT 
				  lower([JobName])[JobName]
				  ,[JobOwner]
				  ,[JobCategory]
				  ,lower([JobDescription])[JobDescription]
				  ,[JobStartStepNo]
				  ,lower([JobStartStepName])[JobStartStepName]
				  ,[IsScheduled]
				  ,lower([JobScheduleName])[JobScheduleName]
				  ,[JobDeletionCriterion]
				  ,[ScheduleType]
				  ,[Occurrence]
				  ,[Recurrence]
				  ,[Frequency]
				  ,[ScheduleUsageEndDate]
				  ,[StepNo]
				  ,lower([StepName])[StepName]
				  ,lower([StepType])[StepType]
				  ,[RunAs]
				  ,lower([Database])[Database]
				  ,[OnSuccessAction]
				  ,[RetryAttempts]
				  ,[RetryInterval (Minutes)]
				  ,[OnFailureAction]
				  ,CASE when lower([ExecutableCommand]) is not null then 1 else 0 end as [ExecutableCommand]
				  ,lower([JobDescription])[JobDescription]
				  ,lower([ExecutableCommand]) [ExecutableCommand]
			  FROM [DBA].[AgentJobDetailsLog]
			  WHERE CAST([AuditDate] AS DATE) = cast(getdate() as date)
			  AND [JobName] NOT IN ('')
			 )

			 BEGIN

				 /*Send an email*/
				DECLARE @Body nvarchar(max), @Subject varchar(255), @To varchar(max), @Cc varchar(max)

					SET @Body = 'Agent Job definitions differ between Primary and Secondary servers. Please check and resolve ASAP, or exclude from this check if completely unavoidable.' + CHAR(10)+ CHAR(13)
					SET @Body = @Body + 'Primary job details logged to [DBA].[AgentJobDetailsLog]. Run the temp table loading part of the script ([DBA].[p_CompareDAGAgentJobDefinitions]) on secondary to compare.'
					SET @Subject = 'Agent job definitions differ between Primary and Secondary. Current secondary: ' + @@servername
					SET @To = ''
					SET @Cc = ''

					EXEC [DBA].[Insert_Email_Notifications] @Body = @Body, @sub = @Subject, @recipient = @To, @format = 'HTML', @copy_recipients = @Cc;

			END
		 END
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0 ROLLBACK
		;
		THROW
		;
	END CATCH
END

GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [DBA].[Check_Database_Mail_State]
AS

BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT,
        QUOTED_IDENTIFIER,
        ANSI_NULLS,
        ANSI_PADDING,
        ANSI_WARNINGS,
        ARITHABORT,
        CONCAT_NULL_YIELDS_NULL ON;

		If Object_Id('tempdb..#Status') Is Not Null

		BEGIN

			Drop Table #Status		
		
		END

		ELSE

		BEGIN

		Create Table #Status 
		(
			[Status] Nvarchar(10)
		)

		END

		INSERT INTO	#Status
		EXEC msdb.dbo.sysmail_help_status_sp

		If Not Exists (
			Select	Top 1
					0
			From	#Status
			Where	Status = 'STARTED'
		)
		Begin			
			Exec msdb.dbo.sysmail_start_sp
		End

		DROP TABLE #Status

END

GO

CREATE PROCEDURE [dbo].[p_AG_HealthReport]

AS

BEGIN

	SET NOCOUNT ON;

DECLARE 
	@tableHTML nvarchar(MAX),
	@body nvarchar(MAX),
	@ServerName SYSNAME, 
	@MemberState nvarchar(100),
	@AGName nvarchar(100),
	@Sub nvarchar(500),
	@To nvarchar(200),
	@cc_To nvarchar(200)

SET @ServerName = @@SERVERNAME 
SET @Sub = 'Availability Group Health Alert For ' + @ServerName
SET @To = ''
SET @cc_To = ''

SELECT 
@MemberState = ARS.role_desc,
@AGName = AGC.name
FROM  
	sys.availability_groups_cluster AS AGC

INNER JOIN sys.dm_hadr_availability_replica_cluster_states AS RCS 
	ON RCS.group_id = AGC.group_id

INNER JOIN sys.dm_hadr_availability_replica_states AS ARS
	ON ARS.replica_id = RCS.replica_id

WHERE 
	replica_server_name = @@SERVERNAME

			SET @tableHTML = '<html><head><style>' +
			'td {border: solid black 1px;padding-left:5px;padding-right:5px;padding-top:1px;padding-bottom:1px;font-size:11pt;} ' +
			'</style></head><body>' +
			'Hello, ' +
			'<br><br>' +     
			'Below is the daily instance health report for ' + '<b>' + @ServerName + '</b>' + ' this instance is currently the ' + '<b>' + @MemberState + '</b>' + ' member of the ' + '<b>' + @AGName + '</b>' + ' group' +
			'<br><br>' +    
			'<div style="margin-left:50px; font-family:Calibri;"><table cellpadding=0 cellspacing=0 border=0>' +
			'<tr bgcolor=#EEEDED>' +
			'<td align=center><font face="calibri" color=Black><b>Database Name</b></font></td>' +    
			'<td align=center><font face="calibri" color=Black><b>Synchronization State</b></font></td>' +   
			'<td align=center><font face="calibri" color=Black><b>Synchronization Health</b></font></td>' + 
			'<td align=center><font face="calibri" color=Black><b>Database State</b></font></td>'   		

			select @BODY =
			(
				select ROW_NUMBER() over(order by database_ID) % 2 as TRRow,
					td = DB_NAME(database_ID),
					td = synchronization_state_desc,
					td =synchronization_health_desc,
					td = database_state_desc

						FROM sys.dm_hadr_database_replica_states 
						WHERE 
							is_local = 1
							AND synchronization_state_desc IN ('NOT_HEALTHY','PARTIALLY_HEALTHY')
				order by database_ID
				for XML raw('tr'), elements
			)

			IF (@body IS NOT NULL)
			BEGIN				
				set @BODY = REPLACE(@BODY, '<td>', '<td align=center><font face="calibri">')
				set @BODY = REPLACE(@BODY, '</td>', '</font></td>')
				set @BODY = REPLACE(@BODY, '_x0020_', space(1))
				set @BODY = Replace(@BODY, '_x003D_', '=')
				set @BODY = Replace(@BODY, '<tr><TRRow>0</TRRow>', '<tr bgcolor=#EEEDED>')
				set @BODY = Replace(@BODY, '<tr><TRRow>1</TRRow>', '<tr bgcolor=#FFFFFF>')
				set @BODY = Replace(@BODY, '<TRRow>0</TRRow>', '')
				
				set @tableHTML = @tableHTML + @body + '</table></div>'

				set @tableHTML= @tableHTML + '<br><br> </body></html>'
				
				set @tableHTML = '<div style="color:Black; font-size:11pt; font-family:Calibri; width:100px;">' + @tableHTML + '</div>'		

				EXEC [DBA].[Insert_Email_Notifications] @Body = @tableHTML, @sub = @sub, @recipient = @To, @format = 'HTML', @copy_recipients = @Cc_To

			END
END
GO

CREATE PROCEDURE [DBA].[p_LogAgentJobEnabledStatus]

AS

BEGIN

SET NOCOUNT ON;

	BEGIN TRY

		INSERT INTO [DBA].[AgentJobEnabledStatus]
		(
		[AGRole]
		,[JobID]
		,[JobName]
		,[IsEnabled]
		)	
		SELECT 
			[AGRole] = 
				(
				SELECT ars.role_desc
				FROM sys.dm_hadr_availability_replica_states AS ars
				INNER JOIN sys.availability_groups AS ag
				ON ars.group_id = ag.group_id
				WHERE ars.is_local = 1
				)
			,[sJOB].[job_id] AS [JobID]
			,[sJOB].[name] AS [JobName]
			,CASE [sJOB].[enabled]
				WHEN 1 THEN 'Yes'
				WHEN 0 THEN 'No'
				END AS [IsEnabled]
		FROM
			[msdb].[dbo].[sysjobs] AS [sJOB]

		DECLARE @maxDays int 
		DECLARE @maxDate date 

		SET @maxDays = -100
		SET @maxDate = DATEADD(dd,@maxDays,GETDATE())

		DELETE FROM [DBA].[AgentJobEnabledStatus]
		WHERE 
		(
		CAST([AuditDate] AS DATE) < @maxDate
		)

	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0 ROLLBACK
		;
		THROW
		;
	END CATCH
END

GO

CREATE PROCEDURE [DBA].[Run_SpaceTracking]

AS

BEGIN

	DECLARE @maxDays int
	DECLARE @maxDate date
	DECLARE @command varchar(max) 
	DECLARE @Sort bit
	DECLARE @Availability_Role nvarchar(20)
	DECLARE @pollDate datetime

	SET @maxDays = -365
	SET @maxDate = DATEADD(dd,@maxDays,GETDATE())
	SET @pollDate = GETDATE()

	DELETE FROM [DBA].[SpaceTracking]
	WHERE 	
	CAST([PollDate] AS DATE) < @maxDate
	

	CREATE TABLE #SpaceTrack 
	(	
		[DatabaseName] varchar(60),
		[LogicalName] varchar(60), 
		[FileType] varchar(10), 
		[FilegroupName] varchar(50), 
		[PhysicalFileLocation] varchar(300), 
		[SpaceMB] decimal(18,2),
		[UsedSpaceMB] int,
		[FreeSpaceMB] decimal(18,2)
	) 

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

	INSERT INTO #SpaceTrack 
	EXEC [Master].[dbo].[sp_ineachdb] @command

	INSERT INTO [DBA].[SpaceTracking]
	(
		[PollDate]
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
	FROM 
		#SpaceTrack
	ORDER BY 
		[LogicalName],[FileType]

	IF OBJECT_ID('tempdb..#SpaceTrack', 'U') IS NOT NULL
	BEGIN
		DROP TABLE #SpaceTrack
	END

END;

GO

CREATE PROCEDURE [DBA].[Run_TempDBSpaceTracking]

AS

BEGIN

	DECLARE @maxDays int 
	DECLARE @maxDate date 
	DECLARE @minAlert int 
	DECLARE @minActual int 

	/*Set the variables*/
	SET @maxDays = -30
	SET @maxDate = DATEADD(dd,@maxDays,GETDATE())
	SET @minAlert = 40

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
		CASE 
			WHEN [maxsize]=-1 THEN 'Unlimited' 
			ELSE CONVERT(VARCHAR(10),CONVERT(bigint,[maxsize])/128) +' MB' 
		END AS [Max Size],
		CASE [status] & 0x100000 
			WHEN 0x100000 then CONVERT(VARCHAR(10),growth) +'%' 
			ELSE Convert(VARCHAR(10),growth/128) +' MB' 
		END AS [Growth],
		GETDATE() as PollDate
		FROM dbo.sysfiles

	SELECT @minActual = MIN(CAST(LEFT(FreeSpacePct,CHARINDEX('.',FreeSpacePct,0)-1) as int)) FROM #TempDBSpaceUsage

	IF @minActual < @minAlert
	BEGIN
		EXEC [DB_Administration].[DBA].[p_ManageTempDBSpaceRequests]
	END

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
	FROM 
		#TempDBSpaceUsage

	DROP TABLE #TempDBSpaceUsage

	DELETE FROM [DBA].[TempDBSpaceUsage]
	WHERE 
	CAST([PollDate] AS DATE) < @maxDate

END

CREATE PROCEDURE [DBA].[AvailabilityDatabaseSyncCheck]

AS

	IF OBJECT_ID('tempdb..#syncCheck','U') IS NOT NULL
	DROP TABLE #syncCheck

	CREATE TABLE #syncCheck(
	[DatabaseName] varchar(128) NOT NULL
	)

	INSERT INTO #syncCheck
	([DatabaseName])
	SELECT 
		d.[name]
	FROM 
		[master].[sys].[databases] d
	LEFT JOIN [master].[sys].[dm_hadr_database_replica_states] r 
		ON d.[database_id] = r.[database_id]
	
	LEFT JOIN [Utility].[DBA].[UnsyncedDBs] u
		ON d.[name] = u.[DatabaseName]
	
	WHERE 
		u.[DatabaseName] IS NULL
		AND d.[database_id] > 4 
		AND ((d.[state_desc] <> 'OFFLINE' AND r.[database_id] IS NULL) OR (r.[synchronization_state_desc] <> 'SYNCHRONIZED' OR r.[synchronization_health_desc] <> 'HEALTHY'))

	DECLARE @databasesNotAdded INT =
	(
		SELECT COUNT(*) FROM #syncCheck
	)
	IF (@databasesNotAdded > 0)

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
			#syncCheck AS Sub
		
		GROUP BY Sub.[DatabaseName]
								
		FOR XML PATH('tr'), ELEMENTS ) AS NVARCHAR(MAX))


		DECLARE @ServerName varchar(45) = (SELECT @@SERVERNAME)

   		SET @Body = '<html><body><p style="font-family: Arial; font-size: 12pt">
   					<H3 style="font-family: Arial; font-size: 12pt">Unsynchronised Databases - '+@ServerName+'</H3>'
   		SET @Body = @Body +'<p style="font-family: Arial; font-size: 10pt">The following databases are not synchronised.</p>
					<p style="font-family: Arial; font-size: 10pt"> Please either add these databases to the availability group, resolve the issues with synchronisation, or add to [DBA].[IgnoredDatabases] to exclude them from the monitoring.</p>
   					<p style="font-family: Arial; font-size: 10pt">
					<table border = 1> 
					<tr>
					<th align="left"><p style="font-family: Arial; font-size: 12pt"> DatabaseName </p></th> 
					</tr>' 
		SET @Body = @Body + @xml +'</table></p></body></html>'+ CHAR(10)

		SET @Subject = 'Unsynchronised Databases - '+@ServerName
		SET @To = ''
		SET @Cc = ''

		EXEC [DBA].[Insert_Email_Notifications] @Body = @Body, @sub = @Subject, @recipient = @To, @format = 'HTML', @copy_recipients = @cc

		IF OBJECT_ID('tempdb..#syncCheck','U') IS NOT NULL
		DROP TABLE #syncDbChk

	END;

GO

CREATE PROCEDURE [DBA].[Insert_Email_Notifications]

AS

DECLARE 
	@Body nvarchar(2000),
	@format varchar(5),
	@sub nvarchar(100),
	@recipient nvarchar(100),
	@cc_recipient nvarchar(100)

BEGIN	

	INSERT INTO DBA.Email_notifications 
	(
		[MailBody]
		,[MailFormat]
		,[MailSubject]
		,[MailRecipients]
		,[CC_MailRecipients]		
	)
	VALUES
	(	@Body
		,@format
		,@sub
		,@recipient
		,@cc_recipient		
	)

END;

GO

CREATE PROCEDURE [DBA].[Send_Email_Notifications]

AS

DECLARE 
	@Body nvarchar(2000),
	@format varchar(5),
	@sub nvarchar(100),
    @maxID INT, 
    @cnt INT, 
	@rcnt INT,
    @notificationID INT,    
	@Email nvarchar(100),
	@cc_Email nvarchar(100),	
	@mailState INT

BEGIN
	SET NOCOUNT ON;	

    CREATE TABLE #notifications 
    (
        ID INT IDENTITY (1,1)
        ,NotificationID INT
        ,MailBody nvarchar(MAX)
        ,MailFormat VARCHAR(5)
        ,MailSubject varchar(4000)
        ,Recipient nvarchar(1000)
		,cc_Recipient nvarchar(1000)
    );

    INSERT INTO #notifications 
	(
		NotificationID
		,MailBody
		,MailFormat
		,MailSubject
		,Recipient
		,cc_recipient
		)
    SELECT 
		Notification_ID
		,MailBody
		,MailFormat
		,MailSubject
		,MailRecipients
		,cc_Recipient
	FROM 
		[DBA].[Email_notifications]
	WHERE Delivered = 0

	SET @cnt = 1

    SET @maxID = (SELECT MAX(ID) FROM #notifications)
	SET @rcnt = (SELECT COUNT(ID) FROM #notifications)

	IF @rcnt >= 1

	BEGIN

    WHILE @cnt <= @maxID

		BEGIN

			SET @notificationID = (SELECT notificationID FROM #notifications WHERE ID = @cnt)
		
			SELECT 
			@Body = MailBody
			,@format = MailFormat
			,@sub = MailSubject
			,@Email = Recipient
			,@cc_Email = cc_recipient
			FROM 
				#notifications
			WHERE 
				ID = @cnt 		

			EXEC @mailState = msdb.dbo.sp_send_dbmail
			@profile_name = '',
			@body_format = 'HTML',
			@body = @Body,           
			@subject = @sub,
			@recipients = @Email,
			@copy_recipients = @cc_Email

			IF (@mailState = 0)
			BEGIN
				UPDATE DBA.Email_notifications  
				SET 
					Delivered = 1, 
					MailDelivered = GETDATE()
				WHERE 
					Notification_ID = @notificationID
			END

			SET @cnt = @cnt + 1 

		END

	END

END	

DROP TABLE #notifications

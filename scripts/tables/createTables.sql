CREATE TABLE [DBA].[UnsyncedDBs]
(
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[DatabaseName] [sysname] NOT NULL
);

GO

CREATE TABLE [DBA].[SpaceTracking]
(
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[PollDate] [datetime] NOT NULL,
	[DatabaseName] [varchar](60) NULL,
	[LogicalName] [varchar](60) NULL,
	[FileType] [varchar](10) NULL,
	[FilegroupName] [varchar](50) NULL,
	[PhysicalFileLocation] [varchar](300) NULL,
	[SpaceMB] [decimal](18, 2) NULL,
	[UsedSpaceMB] [int] NULL,
	[FreeSpaceMB] [decimal](18, 2) NULL
);

GO

CREATE TABLE [DBA].[InstanceCPUUsage]
(
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Instance] [nvarchar](512) NULL,
	[RecordID] [bigint] NULL,
	[EventTime] [datetime] NULL,
	[SQLProcess(%)] [int] NULL,
	[SystemIdle] [int] NULL,
	[OtherProcess(%)] [int] NULL
);

GO

CREATE TABLE [DBA].[DatabaseAudit]
(
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Database] [varchar](50) NULL,
	[ObjectName] [varchar](128) NULL,
	[ObjectType] [char](2) NULL,
	[Action] [varchar](50) NULL,
	[User_Name] [varchar](100) NULL,
	[Timestamp] [datetime] NULL DEFAULT GETDATE()
);

GO

CREATE TABLE [DBA].[AgentJobDetailsLog]
(
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[AuditDate] [datetime] NOT NULL DEFAULT GETDATE(),
	[JobName] [sysname] NOT NULL,
	[JobOwner] [sysname] NULL,
	[JobCategory] [sysname] NULL,
	[JobDescription] [nvarchar](512) NULL,
	[IsEnabled] [varchar](3) NULL,
	[JobCreatedOn] [datetime] NOT NULL,
	[JobLastModifiedOn] [datetime] NOT NULL,
	[OriginatingServerName] [sysname] NULL,
	[JobStartStepNo] [int] NULL,
	[JobStartStepName] [sysname] NULL,
	[IsScheduled] [varchar](3) NOT NULL,
	[JobScheduleName] [sysname] NULL,
	[JobDeletionCriterion] [varchar](13) NULL,
	[ScheduleType] [varchar](48) NULL,
	[Occurrence] [varchar](48) NULL,
	[Recurrence] [varchar](90) NULL,
	[Frequency] [varchar](54) NULL,
	[ScheduleUsageStartDate] [varchar](10) NULL,
	[ScheduleUsageEndDate] [varchar](10) NULL,
	[ScheduleCreatedOn] [datetime] NULL,
	[ScheduleLastModifiedOn] [datetime] NULL,
	[StepNo] [int] NULL,
	[StepName] [sysname] NULL,
	[StepType] [nvarchar](40) NULL,
	[RunAs] [sysname] NULL,
	[Database] [sysname] NULL,
	[ExecutableCommand] [nvarchar](max) NULL,
	[OnSuccessAction] [nvarchar](399) NULL,
	[RetryAttempts] [int] NULL,
	[RetryInterval (Minutes)] [int] NULL,
	[OnFailureAction] [nvarchar](399) NULL
);

GO

CREATE TABLE [DBA].[WhoIsActive]
(
	[dd hh:mm:ss.mss] [varchar](8000) NULL,
	[session_id] [smallint] NOT NULL,
	[sql_text] [xml] NULL,
	[sql_command] [xml] NULL,
	[login_name] [nvarchar](128) NOT NULL,
	[wait_info] [nvarchar](4000) NULL,
	[tran_log_writes] [nvarchar](4000) NULL,
	[CPU] [varchar](30) NULL,
	[tempdb_allocations] [varchar](30) NULL,
	[tempdb_current] [varchar](30) NULL,
	[blocking_session_id] [smallint] NULL,
	[reads] [varchar](30) NULL,
	[writes] [varchar](30) NULL,
	[physical_reads] [varchar](30) NULL,
	[query_plan] [xml] NULL,
	[used_memory] [varchar](30) NULL,
	[status] [varchar](30) NOT NULL,
	[tran_start_time] [datetime] NULL,
	[implicit_tran] [nvarchar](3) NULL,
	[open_tran_count] [varchar](30) NULL,
	[percent_complete] [varchar](30) NULL,
	[host_name] [nvarchar](128) NULL,
	[database_name] [nvarchar](128) NULL,
	[program_name] [nvarchar](128) NULL,
	[start_time] [datetime] NOT NULL,
	[login_time] [datetime] NULL,
	[request_id] [int] NULL,
	[collection_time] [datetime] NOT NULL
);

GO

CREATE TABLE [DBA].[TempDBSpaceUsage]
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
);

GO

CREATE TABLE [DBA].[AgentJobEnabledStatus]
(
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[AuditDate] [datetime] NULL DEFAULT GETDATE(),
	[AGRole] [nvarchar](60) NULL,
	[JobID] [nvarchar](36) NULL,
	[JobName] [sysname] NULL,
	[IsEnabled] [varchar](3) NULL
);

GO

CREATE TABLE [DBA].[WhoIsActive_WMICPUAlertResults](
	[dd hh:mm:ss.mss] [varchar](8000) NULL,
	[session_id] [smallint] NOT NULL,
	[sql_text] [xml] NULL,
	[sql_command] [xml] NULL,
	[login_name] [nvarchar](128) NOT NULL,
	[wait_info] [nvarchar](4000) NULL,
	[tran_log_writes] [nvarchar](4000) NULL,
	[CPU] [varchar](30) NULL,
	[tempdb_allocations] [varchar](30) NULL,
	[tempdb_current] [varchar](30) NULL,
	[blocking_session_id] [smallint] NULL,
	[reads] [varchar](30) NULL,
	[writes] [varchar](30) NULL,
	[physical_reads] [varchar](30) NULL,
	[query_plan] [xml] NULL,
	[used_memory] [varchar](30) NULL,
	[status] [varchar](30) NOT NULL,
	[tran_start_time] [datetime] NULL,
	[open_tran_count] [varchar](30) NULL,
	[percent_complete] [varchar](30) NULL,
	[host_name] [nvarchar](128) NULL,
	[database_name] [nvarchar](128) NULL,
	[program_name] [nvarchar](128) NULL,
	[start_time] [datetime] NOT NULL,
	[login_time] [datetime] NULL,
	[request_id] [int] NULL,
	[collection_time] [datetime] NOT NULL
);

GO

CREATE TABLE [DBA].[TempDBSpaceRequests](
	[session_id] [smallint] NULL,
	[request_id] [int] NULL,
	[task_alloc_MB] [numeric](10, 1) NULL,
	[task_dealloc_MB] [numeric](10, 1) NULL,
	[task_alloc_GB] [numeric](10, 1) NULL,
	[task_dealloc_GB] [numeric](10, 1) NULL,
	[host] [nvarchar](128) NULL,
	[login_name] [nvarchar](128) NULL,
	[status] [nvarchar](30) NULL,
	[last_request_start_time] [datetime] NULL,
	[last_request_end_time] [datetime] NULL,
	[row_count] [bigint] NULL,
	[transaction_isolation_level] [smallint] NULL,
	[query_text] [nvarchar](max) NULL,
	[query_plan] [xml] NULL,
	[PollDate] [datetime] NOT NULL
);

GO

CREATE TABLE [DBA].[JobHistory_Archive](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[instance_id] [int] NULL,
	[job_id] [nvarchar](36) NULL,
	[Name] [nvarchar](128) NULL,
	[step_id] [int] NULL,
	[step_name] [nvarchar](128) NULL,
	[run_date_time] [datetime] NULL,
	[run_duration (HH:MM:SS)] [varchar](8) NULL,
	[run_status] [nvarchar](11) NULL,
	[message] [nvarchar](4000) NULL,
	[sql_severity] [int] NULL,
	[sql_message_id] [int] NULL,
	[operator_id_emailed] [int] NULL,
	[operator_id_netsent] [int] NULL,
	[operator_id_paged] [int] NULL,
	[retries_attempted] [int] NULL,
	[Server] [nvarchar](128) NULL,
	[Date_Added] [datetime] NULL,
	[ModifiedByLogin] [varchar](150) NOT NULL,
	[ModifiedByUser] [varchar](150) NOT NULL
) ON [PRIMARY]

GO
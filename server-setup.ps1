[CmdletBinding()]
Param(
    [Parameter(Mandatory=$false, Position=0, ValueFromPipeline=$false)]
    [System.String]
    $sourceServer,
    [Parameter(Mandatory=$True, Position=1, ValueFromPipeline=$false)]
    [System.String]
    $destinationServer,
    [Parameter(Mandatory=$false, Position=2, ValueFromPipeline=$false)]
    [System.String]
    $sharedLocation,
    [Parameter(Mandatory=$True, Position=3, ValueFromPipeline=$false)]
    [System.String]
    $operatorEmail,
    [Parameter(Mandatory=$True, Position=3, ValueFromPipeline=$false)]
    [System.String]
    $logFileDirectory,
    [Parameter(Mandatory=$True, Position=3, ValueFromPipeline=$false)]
    [System.String]
    $dataFileDirectory
)

$adminDatabase = 'DB_Administration'

$theRoot = $PSScriptRoot

$logDirectory = $theRoot + '\logs\'
$logName = 'SQL-Setup-' + $destinationServer
$logFileName = $logName + (Get-Date -f yyyy-MM-dd-HH-mm) + ".log"
$logFullPath =  Join-Path $logDirectory $logFileName
$logFileLimit = (Get-Date).AddDays(-15)

$scriptPathRoot = $theRoot
$scriptPath = $scriptPathRoot + '\scripts\' 

$availabilityGroup = Get-DbaAvailabilityGroup -SqlInstance $destinationServer | Select-Object -ExpandProperty AvailabilityGroup

Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Script starting" -ForegroundColor Gray

if(-Not(Test-Path -Path $logFullPath -PathType Leaf))
{
    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attepmting to create log file '$logFileName' " -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attepmting to create log file '$logFileName' "
    
    try 
    {
        $null =  New-Item -ItemType File -Path $logFullPath -Force -ErrorAction Stop
        
        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - The log file '$logFileName' has been created" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - The log file '$logFileName' has been created"
    }
    catch 
    {
        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error creating log file '$logFileName'" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error creating log file '$logFileName'. The Error was: $error"
    }
}

Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Yellow
Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer"

if($null -ne $availabilityGroup) {
    
    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server: $destinationServer is part of $availabilityGroup availability group" -ForegroundColor Gray
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server: $destinationServer is part of $availabilityGroup availability group"
}

Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to delete old log files" -ForegroundColor Yellow
Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to delete old log files $destinationServer"

try {  
    
    Get-ChildItem -Path $logFullPath -Recurse -Force | Where-Object { !$_.PSIsContainer -and $_.CreationTime -lt $logFileLimit } | Remove-Item -Force
    
    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Log files sucessfully deleted" -ForegroundColor Green
    Add-Content -Path $logFullPath -Value "$(Get-Date -f "yyyy-MM-dd-HH-mm") - Log files sucessfully deleted"
    
}
catch {

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error deleting log files" -ForegroundColor Red
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error deleting log files. The Error was: $error"
}

$dacState = Invoke-DbaQuery -SqlInstance $destinationServer -Query "SELECT value_in_use FROM sys.configurations where name = 'remote admin connections'"

Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to enable the dedicated admin connection" -ForegroundColor Yellow    
Add-Content -Path $logFullPath -Value "$(Get-Date -f "yyyy-MM-dd-HH-mm") - Attempting to enable the dedicated admin connection"

if($dacState.value_in_use -eq 0) {

    Invoke-DbaQuery -SqlInstance $destinationServer -Query "sp_configure 'remote admin connections', 1; RECONFIGURE"    
    
    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Dedicated admin connection configured sucessfully." -ForegroundColor Green    
    Add-Content -Path $logFullPath -Value "$(Get-Date -f "yyyy-MM-dd-HH-mm") - Dedicated admin connection configured sucessfully."
    
}

$Broker = Invoke-DbaQuery -SqlInstance $destinationServer -Query "SELECT is_broker_enabled FROM sys.databases WHERE name = 'msdb'"
$MailXP = Invoke-DbaQuery -SqlInstance $destinationServer -Query "SELECT value_in_use FROM  sys.configurations WHERE name = 'Database Mail XPs'"

Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to set the maximum memory" -ForegroundColor Yellow
Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Maximum memory has been set on this server"

if($Broker.is_broker_enabled -eq $False -and $MailXP.value_in_use -eq 0) {    
    
    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Maximum memory has been set on this server"

    try {

        Invoke-DbaQuery -SqlInstance $destinationServer -Query "EXEC sp_configure 'show advanced options', '1'"

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Maximum memory has been set on this server" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Maximum memory has been set on this server"
    }
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error deleting log files" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error deleting log files. The Error was: $error"
    }

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Maximum memory has been set on this server"

    try {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Maximum memory has been set on this server"
	
        Invoke-DbaQuery -SqlInstance $destinationServer -Query "EXEC sp_configure 'Database Mail XPs', 1"
    }
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error deleting log files" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error deleting log files. The Error was: $error"

    }

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Maximum memory has been set on this server"

    try {

        Invoke-DbaQuery -SqlInstance $destinationServer -Query "EXEC master.dbo.sp_MSsetalertinfo @failsafeoperator= @operator_name, @notificationmethod=1;" -SqlParameter @(operator_name = "The DBA Team")

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Maximum memory has been set on this server"

    }
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error deleting log files" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error deleting log files. The Error was: $error"

    }

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Maximum memory has been set on this server"

    try {

        Invoke-DbaQuery -SqlInstance $destinationServer -Query "EXEC msdb.dbo.sp_set_sqlagent_properties @email_save_in_sent_folder=1;"

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Maximum memory has been set on this server"

    }
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error deleting log files" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error deleting log files. The Error was: $error"

    }    

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Maximum memory has been set on this server"
    
    try {

        Invoke-DbaQuery -SqlInstance $destinationServer -Query "RECONFIGURE;"

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Maximum memory has been set on this server"

    }
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error deleting log files" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error deleting log files. The Error was: $error"

    }     
}

Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Enabling backup compression" -ForegroundColor Yellow
Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Enabling backup compression"

try {   
    
    Invoke-DbaQuery -SqlInstance $destinationServer -Query "EXEC sp_configure 'backup compression default', 1; RECONFIGURE WITH OVERRIDE;"

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Backup compression sucessfully enabled" -ForegroundColor Green
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Backup compression sucessfully enabled"

} catch {

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Unable to set backup compression, refer to the log file" -ForegroundColor Red
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Unable to set backup compression'. The Error was: $error"
}

Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to add trace flags" -ForegroundColor Yellow
Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to add trace flags"

try {    
    
    Enable-DbaTraceFlag -SqlInstance $destinationServer -TraceFlag 3226

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Trace flags set sucessfully" -ForegroundColor Green
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Trace flags set sucessfully"

}
catch {

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - There was a problem setting the trace flags" -ForegroundColor Green
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - There was a problem setting the trace flags. The Error was: $error"
}

Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to set the maximum memory for this instance" -ForegroundColor Yellow
Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to set the maximum memory for this instance"

try {

    Set-DbaMaxMemory -SqlInstance $destinationServer

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully set the maximum memory for this instance" -ForegroundColor Green
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully set the maximum memory for this instance"
    
}
catch {

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - There was an error setting the maximum memory for this instance" -ForegroundColor Green
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - There was an error setting the maximum memory for this instance. The Error was: $error"    
}

Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to set the maxDop for this instance" -ForegroundColor Yellow
Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to set the maxDop for this instance"

try {

    Set-DbaMaxDop -SqlInstance $destinationServer

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully set the maxDop for this instance" -ForegroundColor Green
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully set the maxDop for this instance"
}
catch {

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - There was an error setting the maxDop for this instance" -ForegroundColor Red
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - There was an error setting the maxDop for this instance. The Error was: $error"
}

if($sourceServer -ne $null) {

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - MaxDop has been set on this server"

    try {

        Copy-DbaDatabase -source $sourceServer -Destination $destinationServer -BackupRestore -SharedPath $sharedLocation
        
        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - MaxDop has been set on this server"
    }
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Unable to delete old log files from '$logFullPath'. The Error was: $error"
    }

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - MaxDop has been set on this server"

    try {

        Copy-DbaAgentJob -source $sourceServer -Destination $destinationServer -BackupRestore -SharedPath $sharedLocation

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - MaxDop has been set on this server"
    }
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Unable to delete old log files from '$logFullPath'. The Error was: $error"
    }

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - MaxDop has been set on this server"

    try {

        Copy-DbaLogin -source $sourceServer -Destination $destinationServer

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - MaxDop has been set on this server"
    }
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Unable to delete old log files from '$logFullPath'. The Error was: $error"
    }

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - MaxDop has been set on this server"

    try {

        Copy-DbaDbMail -source $sourceServer -Destination $destinationServer

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - MaxDop has been set on this server"
    }
    catch {
        
        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Unable to delete old log files from '$logFullPath'. The Error was: $error"  
    }

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - MaxDop has been set on this server"

    try {

        Copy-DbaAgentOperator -source $sourceServer -Destination $destinationServer
        
        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - MaxDop has been set on this server"
    }
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Unable to delete old log files from '$logFullPath'. The Error was: $error"
    }

} else
{
    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - MaxDop has been set on this server"

    try
    {
        New-DbaAgentOperator -SqlInstance $destinationServer -Operator 'The DBA Team' -EmailAddress $operatorEmail
        
        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - MaxDop has been set on this server"
    }
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Unable to delete old log files from '$logFullPath'. The Error was: $error"
    }

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - MaxDop has been set on this server"

    try
    {        
        Invoke-DbaQuery -SqlInstance $destinationServer -File $scriptPath + 'scripts\' + 'alerts.sql'
        
        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - MaxDop has been set on this server"
    }
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Unable to delete old log files from '$logFullPath'. The Error was: $error"
    }
}

if($null -eq (Get-DbaDatabase -SqlInstance $destinationServer -Database $adminDatabase))
{
    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - MaxDop has been set on this server"

    try {

        New-DbaDatabase -SqlInstance $destinationServer -Name $adminDatabase
        
        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Unable to delete old log files from '$logFullPath'. The Error was: $error"
    }
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Unable to delete old log files from '$logFullPath'. The Error was: $error"
    }
}

if($null -eq (Get-DbaDbSchema -SqlInstance $destinationServer -Database $adminDatabase -Schema 'DBA'))
{
    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - MaxDop has been set on this server"

    try {

        New-DbaDbSchema -SqlInstance $destinationServer -Database $adminDatabase -Schema 'DBA'
        
        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Unable to delete old log files from '$logFullPath'. The Error was: $error"
    }
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Unable to delete old log files from '$logFullPath'. The Error was: $error"
    }
}

if($null -eq(Get-DbaDbTable -SqlInstance $destinationServer -Database $adminDatabase -Table 'AgentJobEnabledStatus' -Schema 'dbo'))
{
    $columns = @()

    $columns += @{
         Name      = 'ID'
         Type      = 'int'
         Identity  = $true
    }
    $columns += @{
        Name      = 'AuditDate'
        Type      = 'datetime'
        Nullable  = $true
   }
    $columns += @{
        Name      = 'AGRole'
        Type      = 'nvarchar'
        MaxLength = 60
        Nullable  = $true
    }
    $columns += @{
        Name      = 'JobID'
        Type      = 'nvarchar'
        MaxLength = 36
        Nullable  = $true
    }
    $columns += @{
        Name      = 'JobName'
        Type      = 'sysname'
        Nullable  = $true
    }
    $columns += @{
        Name      = 'ID'
        Type      = 'varchar'
        MaxLength = 3
        Nullable  = $true
    }

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - MaxDop has been set on this server"

    try
    {
        New-DbaDbTable -SqlInstance $destinationServer -Database $adminDatabase -Name 'AgentJobEnabledStatus' -Schema = 'DBA' -ColumnMap $columns
        
        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Unable to delete old log files from '$logFullPath'. The Error was: $error"
    }
    catch
    {
        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Unable to delete old log files from '$logFullPath'. The Error was: $error"
    }
}

###

if($null -eq(Get-DbaDbTable -SqlInstance $destinationServer -Database $adminDatabase -Table 'AgentJobEnabledStatus' -Schema 'dbo'))
{

    # CREATE TABLE DBA.TempDBSpaceRequests(
    #     session_id smallint NULL,
    #     request_id int NULL,
    #     task_alloc_MB numeric(10, 1) NULL,
    #     task_dealloc_MB numeric(10, 1) NULL,
    #     task_alloc_GB numeric(10, 1) NULL,
    #     task_dealloc_GB numeric(10, 1) NULL,
    #     host nvarchar(128) NULL,
    #     login_name nvarchar(128) NULL,
    #     status nvarchar(30) NULL,
    #     last_request_start_time datetime NULL,
    #     last_request_end_time datetime NULL,
    #     row_count bigint NULL,
    #     transaction_isolation_level smallint NULL,
    #     query_text nvarchar(max) NULL,
    #     query_plan xml NULL,
    #     PollDate datetime NOT NULL
    # ) ON PRIMARY TEXTIMAGE_ON PRIMARY

    $columns = @()

    $columns += @{
         Name      = 'session_id'
         Type      = 'smallint'
    }
    $columns += @{
        Name      = 'request_id'
        Type      = 'int'
   }
    $columns += @{
        Name      = 'task_alloc_MB'
        Type      = 'numeric'
        Precision = 10

        Nullable  = $true
    }
    $columns += @{
        Name      = 'task_dealloc_MB'
        Type      = 'nvarchar'
        MaxLength = 36
        Nullable  = $true
    }
    $columns += @{
        Name      = 'host'
        Type      = 'sysname'
        Nullable  = $true
    }
    $columns += @{
        Name      = 'login_name'
        Type      = 'varchar'
        MaxLength = 3
        Nullable  = $true
    }
    $columns += @{
        Name      = 'status'
        Type      = 'varchar'
        MaxLength = 3
        Nullable  = $true
    }
    $columns += @{
        Name      = 'last_request_start_time'
        Type      = 'varchar'
        MaxLength = 3
        Nullable  = $true
    }
    $columns += @{
        Name      = 'last_request_end_time'
        Type      = 'varchar'
        MaxLength = 3
        Nullable  = $true
    }
    $columns += @{
        Name      = 'row_count'
        Type      = 'varchar'
        MaxLength = 3
        Nullable  = $true
    }
    $columns += @{
        Name      = 'transaction_isolation_level'
        Type      = 'varchar'
        MaxLength = 3
        Nullable  = $true
    }
    $columns += @{
        Name      = 'query_text'
        Type      = 'varchar'
        MaxLength = 3
        Nullable  = $true
    }
    $columns += @{
        Name      = 'query_plan'
        Type      = 'varchar'
        MaxLength = 3
        Nullable  = $true
    }
    $columns += @{
        Name      = 'PollDate'
        Type      = 'varchar'
        MaxLength = 3
        Nullable  = $true
    }

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - MaxDop has been set on this server"

    try {

        New-DbaDbTable -SqlInstance $destinationServer -Database $adminDatabase -Name 'TempDBSpaceRequests' -Schema = 'DBA' -ColumnMap $columns
        
        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Unable to delete old log files from '$logFullPath'. The Error was: $error"
    }
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Unable to delete old log files from '$logFullPath'. The Error was: $error"
    }
}

$vendorScripts = @('olaHallengren.sql','brentScripts.sql','spWho.sql')

foreach($script in $vendorScripts)
{
    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - MaxDop has been set on this server"

    try {

        Invoke-DbaQuery -SqlInstance $destinationServer -File $scriptPath + 'scripts\' + $script -Database $adminDatabase
        
        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Unable to delete old log files from '$logFullPath'. The Error was: $error"

    } catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Unable to delete old log files from '$logFullPath'. The Error was: $error"
    }
}

$sqlAgentJobs = @('_MAINT_Manage Agent Job History','DBA: Manage Agent Job History','DBA: TempDBSpaceMonitoring','DBA: WhoIsActive_WMICPUAlert','_MAINT_sp_WhoIsActive Data Collection','DBA: Check Database Mail State','DBA: DatabaseSpaceTracking','DBA: GetInstanceCPUUsage','DBA: IndexOpsExcludedDBs','DBA: IndexOpsSpaceRequirements',)
$availabilityGroupJobs = @('DBA: CompareDAGAgentJobDefinitions','DBA: DatabaseSyncStatus','DBA: ReviewAgentJobConfig')

#Last but not least create some jobs 
if($null -ne $availabilityGroup)
{
    foreach($agJob in $availabilityGroupJobs) {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Yellow
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - MaxDop has been set on this server"

        try {

            Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Green
            New-DbaAgentJob -SqlInstance $destinationServer -Job $agJob -EmailLevel OnFailure -EmailOperator 'The DBA Team'
            
        }
        catch {

            Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Red
            Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Unable to delete old log files from '$logFullPath'. The Error was: $error"
        }

        try {            

            Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Green
            New-DbaAgentJobStep -SqlInstance $destinationServer -Job $agJob -StepName 'Primary Instance Check' -Command '' -Database msdb
        }
        catch {

            Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Red
            Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Unable to delete old log files from '$logFullPath'. The Error was: $error"
        }

    }
}

foreach($job in $sqlAgentJobs) {

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - MaxDop has been set on this server"

    try {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Green
        New-DbaAgentJob -SqlInstance $destinationServer -Job $job -EmailLevel OnFailure -EmailOperator 'The DBA Team'

    } 
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Unable to delete old log files from '$logFullPath'. The Error was: $error"
    }

    if($null -ne $availabilityGroup)
    {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Yellow
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - MaxDop has been set on this server"

        try {     

            Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Green
            New-DbaAgentJobStep -SqlInstance $destinationServer -Job $job -StepName 'Primary Instance Check' -Command '' -Database msdb

        } 
        catch {

            Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Server being configured: $destinationServer" -ForegroundColor Red
            Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Unable to delete old log files from '$logFullPath'. The Error was: $error"
        }
    }
}
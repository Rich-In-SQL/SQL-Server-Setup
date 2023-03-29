#Requires -RunAsAdministrator
#Requires -Modules dbatools

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
    [Parameter(Mandatory=$True, Position=4, ValueFromPipeline=$false)]
    [System.String]
    $logFileDirectory,
    [Parameter(Mandatory=$True, Position=5, ValueFromPipeline=$false)]
    [System.String]
    $dataFileDirectory,
    [Parameter(Mandatory=$True, Position=6, ValueFromPipeline=$false)]
    [System.String]
    $adminDatabase,
    [Parameter(Mandatory=$True, Position=7, ValueFromPipeline=$false)]
    [System.String]
    $backupLocation
)

$sqlCredential = $host.ui.PromptForCredential("Please enter your credentials", "Please enter a username and password that has admin access to the SQL server.", "", "NetBiosUserName")

$theRoot = $PSScriptRoot

$logDirectory = $theRoot + '\logs\'
$logName = 'SQL-Setup-' + $destinationServer + '-'
$logFileName = $logName + (Get-Date -f yyyy-MM-dd-HH-mm) + ".log"
$logFullPath =  Join-Path $logDirectory $logFileName
$logFileLimit = (Get-Date).AddDays(-30)

$scriptPathRoot = $theRoot
$scriptPath = $scriptPathRoot + '\scripts\' 

$sourceSQLConnection = Connect-DbaInstance -SqlInstance $sourceServer -SqlCredential $sqlCredential
$destinationSQLConnection = Connect-DbaInstance -SqlInstance $destinationServer -SqlCredential $sqlCredential

$availableDisks = Get-DbaDiskSpace -ComputerName $destinationSQLConnection -Credential $sqlCredential | Select-Object -Property Name

if($availableDisks | Where-Object Name -ne $logFileDirectory -or $availableDisks | Where-Object Name -ne $dataFileDirectory)
{
    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - $logFileDirectory or $dataFileDirectory was not found on $destinationServer" -ForegroundColor Red
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - $logFileDirectory or $dataFileDirectory was not found on $destinationServer"
    return
}

$doIHaveInternet = ((Test-NetConnection www.google.com -Port 80 -InformationLevel "Detailed").TcpTestSucceeded)

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

$dacState = Invoke-DbaQuery -SqlInstance $destinationSQLConnection -Query "SELECT value_in_use FROM sys.configurations where name = 'remote admin connections'"

if($dacState.value_in_use -eq 0) {

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to enable the dedicated admin connection" -ForegroundColor Yellow    
    Add-Content -Path $logFullPath -Value "$(Get-Date -f "yyyy-MM-dd-HH-mm") - Attempting to enable the dedicated admin connection"
    
    try {

        Invoke-DbaQuery -SqlInstance $destinationSQLConnection -Query "sp_configure 'remote admin connections', 1; RECONFIGURE"   
        
        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Dedicated admin connection configured sucessfully." -ForegroundColor Green    
        Add-Content -Path $logFullPath -Value "$(Get-Date -f "yyyy-MM-dd-HH-mm") - Dedicated admin connection configured sucessfully."

    }
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error enabling the dedicated admin connection" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error enabling the dedicated admin connection. The Error was: $error"

    }

}

$Broker = Invoke-DbaQuery -SqlInstance $destinationSQLConnection -Query "SELECT is_broker_enabled FROM sys.databases WHERE name = 'msdb'"
$MailXP = Invoke-DbaQuery -SqlInstance $destinationSQLConnection -Query "SELECT value_in_use FROM  sys.configurations WHERE name = 'Database Mail XPs'"

if($Broker.is_broker_enabled -eq $False -and $MailXP.value_in_use -eq 0) {    
    
    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to configure database mail, operator and fallback operator" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to configure database mail, operator and fallback operator"

    try {

        Invoke-DbaQuery -SqlInstance $destinationSQLConnection -Query "EXEC sp_configure 'show advanced options', '1'"

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Enabling advanced featured was sucessful" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Enabling advanced featured was sucessful"
    }
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error deleting log files" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error deleting log files. The Error was: $error"
    }

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to enable database mail" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to enable database mail"

    try {

        Invoke-DbaQuery -SqlInstance $destinationSQLConnection -Query "EXEC sp_configure 'Database Mail XPs', 1"

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Database mail enabled sucessfully." -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Database mail enabled sucessfully."
    }
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error enabling database mail." -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error enabling database mail. The Error was: $error"

    }

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to set failsafe operator" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to set failsafe operator"

    try {

        Invoke-DbaQuery -SqlInstance $destinationSQLConnection -Query "EXEC master.dbo.sp_MSsetalertinfo @failsafeoperator= @operator_name, @notificationmethod=1;" -SqlParameter @(operator_name = "The DBA Team") -SqlCredential $sqlCredential

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Failsafe operator set sucessfully." -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Failsafe operator set sucessfully."

    }
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error setting failsafe operator." -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error setting failsafe operator. The Error was: $error"

    }

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to set save mail in sent folder." -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to set save mail in sent folder."

    try {

        Invoke-DbaQuery -SqlInstance $destinationSQLConnection -Query "EXEC msdb.dbo.sp_set_sqlagent_properties @email_save_in_sent_folder=1;" -SqlCredential $sqlCredential

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully set sent mail to save in sent folder." -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully set sent mail to save in sent folder."

    }
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error setting sent mail to save in sent folder." -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error setting sent mail to save in sent folder.. The Error was: $error"

    }    

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to apply settings" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to apply settings"
    
    try {

        Invoke-DbaQuery -SqlInstance $destinationSQLConnection -Query "RECONFIGURE;"

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Settings applied sucessfully." -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Settings applied sucessfully."

    }
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error applying settings" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error applying settings. The Error was: $error"

    }     
}

Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Enabling backup compression" -ForegroundColor Yellow
Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Enabling backup compression"

try {   
    
    Invoke-DbaQuery -SqlInstance $destinationSQLConnection -Query "EXEC sp_configure 'backup compression default', 1; RECONFIGURE WITH OVERRIDE;"

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Backup compression sucessfully enabled" -ForegroundColor Green
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Backup compression sucessfully enabled"

} catch {

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Unable to set backup compression, refer to the log file" -ForegroundColor Red
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Unable to set backup compression'. The Error was: $error"
}

Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to add trace flags" -ForegroundColor Yellow
Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to add trace flags"

try {    
    
    Enable-DbaTraceFlag -SqlInstance $destinationSQLConnection -TraceFlag 3226

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

    Set-DbaMaxMemory -SqlInstance $destinationSQLConnection

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

    Set-DbaMaxDop -SqlInstance $destinationSQLConnection

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully set the maxDop for this instance" -ForegroundColor Green
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully set the maxDop for this instance"
}
catch {

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - There was an error setting the maxDop for this instance" -ForegroundColor Red
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - There was an error setting the maxDop for this instance. The Error was: $error"
}

if($sourceServer -ne $null) {

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Source Server parameter was specified as $sourceServer, attempting to copy objects to $destinationServer" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Source Server parameter was specified as $sourceServer, attempting to copy objects to $destinationServer"

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to copy databases from $sourceServer to $destinationServer using backup & restore to $sharedLocation" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to copy databases from $sourceServer to $destinationServer using backup & restore to $sharedLocation"

    try {

        Copy-DbaDatabase -source $sourceSQLConnection -Destination $destinationSQLConnection -BackupRestore -SharedPath $sharedLocation
        
        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Databases sucessfully copied from $sourceServer to $destinationServer using backup & restore to $sharedLocation" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Databases sucessfully copied from $sourceServer to $destinationServer using backup & restore to $sharedLocation"
    }
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error copying databases from $sourceServer to $destinationServer using backup & restore to $sharedLocation" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error copying databases from $sourceServer to $destinationServer using backup & restore to $sharedLocation. The Error was: $error"
    }

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to copy agent jobs from $sourceServer to $destinationServer" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to copy agent jobs from $sourceServer to $destinationServer"

    try {

        Copy-DbaAgentJob -source $sourceSQLConnection -Destination $destinationSQLConnection

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully copied agent jobs from $sourceServer to $destinationServer" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully copied agent jobs from $sourceServer to $destinationServer"
    }
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error copying agent jobs from $sourceServer to $destinationServer" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error copying agent jobs from $sourceServer to $destinationServer. The Error was: $error"
    }

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to copy logins from $sourceServer to $destinationServer" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to copy logins from $sourceServer to $destinationServer"

    try {

        Copy-DbaLogin -source $sourceSQLConnection -Destination $destinationSQLConnection

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to copy logins from $sourceServer to $destinationServer" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to copy logins from $sourceServer to $destinationServer"
    }
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error copying logins from $sourceServer to $destinationServer" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error copying logins from $sourceServer to $destinationServer. The Error was: $error"
    }

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to copy database mail configuration from $sourceServer to $destinationServer" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to database mail configuration from $sourceServer to $destinationServer"

    try {

        Copy-DbaDbMail -source $sourceSQLConnection -Destination $destinationSQLConnection

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully copied database mail configuration from $sourceServer to $destinationServer" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully copied database mail configuration from $sourceServer to $destinationServer"
    }
    catch {
        
        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error copying database mail configuration from $sourceServer to $destinationServer" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error copying database mail configuration from $sourceServer to $destinationServer. The Error was: $error"  
    }

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to copy Agent Job Category from $sourceServer to $destinationServer" -ForegroundColor Green
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to copy Agent Job Category from $sourceServer to $destinationServer"

    try {
        
        Copy-DbaAgentJobCategory -Source $SourceSqlCredential -Destination $destinationSQLConnection

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully copied Agent Job Category's from $sourceServer to $destinationServer" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully copied Agent Job Category's from $sourceServer to $destinationServer"

    }
    catch {
        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error copying agent job category's from $sourceServer to $destinationServer" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error copying agent job category's from $sourceServer to $destinationServer. The Error was: $error"  
    }

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to copy linked servers from $sourceServer to $destinationServer" -ForegroundColor Green
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to copy linked servers from $sourceServer to $destinationServer"

    try {

        Copy-DbaLinkedServer -Source $SourceSqlCredential -Destination $destinationSQLConnection

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully copied linked servers from $sourceServer to $destinationServer" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully copied linked servers from $sourceServer to $destinationServer"

    }
    catch
    {
        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error copying linked servers from $sourceServer to $destinationServer" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error copying linked servers from $sourceServer to $destinationServer. The Error was: $error"  
    }

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to copy Custom error's from $sourceServer to $destinationServer" -ForegroundColor Green
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to copy Custom error's from $sourceServer to $destinationServer"

    try {
        
        Copy-DbaCustomError -Source $SourceSqlCredential -Destination $destinationSQLConnection

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully copied custom error's from $sourceServer to $destinationServer" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully copied custom error's from $sourceServer to $destinationServer"

    }
    catch
    {
        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error copying custom error's from $sourceServer to $destinationServer" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error copying custom error's from $sourceServer to $destinationServer. The Error was: $error"  
    }

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to copy Agent Alerts from $sourceServer to $destinationServer" -ForegroundColor Green
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to copy Agent Alerts from $sourceServer to $destinationServer"

    try {

        Copy-DbaAgentAlert -Source $SourceSqlCredential -Destination $destinationSQLConnection

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully copied Agent Alerts from $sourceServer to $destinationServer" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully copied Agent Alerts from $sourceServer to $destinationServer"

    }
    catch
    {
        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error copying Agent Alerts from $sourceServer to $destinationServer" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error copying Agent Alerts from $sourceServer to $destinationServer. The Error was: $error"  
    }


    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to copy database mail operator from $sourceServer to $destinationServer" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to copy database mail operator from $sourceServer to $destinationServer"

    try {

        Copy-DbaAgentOperator -source $sourceSQLConnection -Destination $destinationSQLConnection
        
        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully copied database mail operator from $sourceServer to $destinationServer" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully copied database mail operator from $sourceServer to $destinationServer"
    }
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error copying database mail operator from $sourceServer to $destinationServer" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error copying database mail operator from $sourceServer to $destinationServer. The Error was: $error"
    }

} else
{
    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - No source server was specified, attempting to create objects on $destinationServer" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - No source server was specified, attempting to create objects on $destinationServer"

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to create The DBA Team operator on $destinationServer" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to create The DBA Team operator on $destinationServer"

    try
    {
        New-DbaAgentOperator -SqlInstance $destinationSQLConnection -Operator 'The DBA Team' -EmailAddress $operatorEmail
        
        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully created The DBA Team operator on $destinationServer" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully created The DBA Team operator on $destinationServer"
    }
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error creating The DBA Team operator on $destinationServer" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error creating The DBA Team operator on $destinationServer. The Error was: $error"
    }

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to apply $scriptPath + 'scripts\' + 'alerts.sql' to $destinationServer" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to apply $scriptPath + 'scripts\' + 'alerts.sql' to $destinationServer"

    try
    {        
        Invoke-DbaQuery -SqlInstance $destinationSQLConnection -File $scriptPath + 'scripts\' + 'alerts.sql'
        
        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully applied $scriptPath + 'scripts\' + 'alerts.sql' to $destinationServer" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully applied $scriptPath + 'scripts\' + 'alerts.sql' to $destinationServer"
    }
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error applying $scriptPath + 'scripts\' + 'alerts.sql' to $destinationServer" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to copy agent jobs from $sourceServer to $destinationServer. The Error was: $error"
    }
}

if($null -eq (Get-DbaDatabase -SqlInstance $destinationSQLConnection -Database $adminDatabase))
{
    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to create $adminDatabase on $destinationServer" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to create $adminDatabase on $destinationServer"

    try {

        New-DbaDatabase -SqlInstance $destinationSQLConnection -Name $adminDatabase
        
        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully created $adminDatabase on $destinationServer" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully created $adminDatabase on $destinationServer. The Error was: $error"
    }
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error creating $adminDatabase on $destinationServer" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error creating $adminDatabase on $destinationServer. The Error was: $error"
    }
}

if($null -eq (Get-DbaDbSchema -SqlInstance $destinationSQLConnection -Database $adminDatabase -Schema 'DBA'))
{
    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to create schema DBA in $adminDatabase on $destinationServer" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to create schema DBA in $adminDatabase on $destinationServer"

    try {

        New-DbaDbSchema -SqlInstance $destinationSQLConnection -Database $adminDatabase -Schema 'DBA'
        
        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Succesfully created schema DBA in $adminDatabase on $destinationServer" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully created schema DBA in $adminDatabase on $destinationServer. The Error was: $error"
    }
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error creating schema DBA in $adminDatabase on $destinationServer" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error creating schema DBA in $adminDatabase on $destinationServer. The Error was: $error"
    }
}

$vendorScripts = @('olaHallengren.sql','brentScripts.sql','spWho.sql')

foreach($script in $vendorScripts)
{
    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to create $script in $adminDatabase" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to create $script in $adminDatabase"

    try {

        if($script -eq 'olaHallengren.sql' -and $true -eq $doIHaveInternet)
        {
            $mainSoloutionParams = @{

                SqlInstance = $destinationSQLConnection
                Database = $adminDatabase
                ReplaceExisting = $true
                InstallJobs = $true
                LogToTable = $true
                BackupLocation = $backupLocation
                Verbose = $true
            }

            Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Internet connection available, installing $script from the web" -ForegroundColor Yellow
            Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Internet connection available, installing $script from the web"

            try {

                Install-DbaMaintenanceSolution @mainSoloutionParams -Database $adminDatabase -SqlCredential $sqlCredential -LogToTable -InstallJobs
                Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully created $script in $adminDatabase" -ForegroundColor Green

                Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully created $script in $adminDatabase."
            }
            catch
            {
                Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error adding $script to $adminDatabase" -ForegroundColor Red
                Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error adding $script to $adminDatabase. The Error was: $error"
            }
        }
        elseif($script -eq 'brenScripts.sql' -and $true -eq $doIHaveInternet) 
        {
            Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Internet connection available, installing $script from the web" -ForegroundColor Yellow
            Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Internet connection available, installing $script from the web"

            try {
                Install-DbaFirstResponderKit -SqlInstance $destinationSQLConnection -Database $adminDatabase
                Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully created $script in $adminDatabase" -ForegroundColor Green
                Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully created $script in $adminDatabase."
            }
            catch
            {
                Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error adding $script to $adminDatabase" -ForegroundColor Red
                Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error adding $script to $adminDatabase. The Error was: $error"
            }
        }
        else {
            Invoke-DbaQuery -SqlInstance $destinationSQLConnection -File $scriptPath + 'scripts\' + $script -Database $adminDatabase
            Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully created $script in $adminDatabase" -ForegroundColor Green
            Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully created $script in $adminDatabase."
        }

    } catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - There was an error creating $script in $adminDatabase" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - There was an error creating $script in $adminDatabase. The Error was: $error"
    }
}

$sqlAgentJobs = @('DBA: Send Email Alerts','_MAINT_Manage Agent Job History','DBA: Manage Agent Job History','DBA: TempDBSpaceMonitoring','DBA: WhoIsActive_WMICPUAlert','_MAINT_sp_WhoIsActive Data Collection','DBA: Check Database Mail State','DBA: DatabaseSpaceTracking','DBA: GetInstanceCPUUsage','DBA: IndexOpsExcludedDBs','DBA: IndexOpsSpaceRequirements')
$availabilityGroupJobs = @('DBA: CompareDAGAgentJobDefinitions','DBA: DatabaseSyncStatus','DBA: ReviewAgentJobConfig','_MAINT_CopyAgLogins')

#Last but not least create some jobs 
if($null -ne $availabilityGroup)
{

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - $destinationServer is part of an availability group, attempting to create ag specific jobs." -ForegroundColor Green
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - $destinationServer is part of an availability group, attempting to create ag specific jobs."

    foreach($agJob in $availabilityGroupJobs) {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to create $agJob" -ForegroundColor Yellow
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to create $agJob"

        try {           

            New-DbaAgentJob -SqlInstance $destinationSQLConnection -Job $agJob -EmailLevel OnFailure -EmailOperator 'The DBA Team'
            
            Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully created $agJob" -ForegroundColor Green
            Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully created $agJob"
            
        }
        catch {

            Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error creating $agJob" -ForegroundColor Red
            Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully created $agJob. The Error was: $error"
        }

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to create job step, availability check in $agJob" -ForegroundColor Green
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to create job step, Primary Instance Check in $agJob"

        try { 
            
            New-DbaAgentJobStep -SqlInstance $destinationSQLConnection -Job $agJob -StepName 'Primary Instance Check' -Command 'SELECT ars.role_desc FROM sys.dm_hadr_availability_replica_states AS ars INNER JOIN sys.availability_groups AS ag ON ars.group_id = ag.group_id WHERE ars.is_local = 1' -Database msdb
            
            Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully created job step, Primary Instance Check in $agJob" -ForegroundColor Green
            Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully created job step, Primary Instance Check in $agJob"
            
            if($agJob -eq 'DBA: CompareDAGAgentJobDefinitions')
            {
                New-DbaAgentJobStep -SqlInstance $destinationSQLConnection -Job $agJob -StepName 'Compare AG Agent Job Definitions' -Command 'powershell.exe -NoLogo -NonInteractive -File "$(ESCAPE_NONE(SQLLOGDIR))\..\JOBS\CompareAGJobs.ps1" -ThisServer $(ESCAPE_NONE(SRVR)) -EmailTo ' -Database msdb                
            } elseif($agJob -eq '_MAINT_CopyAgLogins')
            {
                New-DbaAgentJobStep -SqlInstance $destinationSQLConnection -Job $agJob -StepName 'Copy Ag Logins' -Command 'powershell.exe -NoLogo -NonInteractive -File "$(ESCAPE_NONE(SQLLOGDIR))\..\JOBS\CopyAgLogins.ps1" -ThisServer $(ESCAPE_NONE(SRVR)) -LogFileFolder "$(ESCAPE_NONE(SQLLOGDIR))"' -Database msdb                
            } elseif($agJob -eq '')
            {
                New-DbaAgentJobStep -SqlInstance $destinationSQLConnection -Job $agJob -StepName 'Availability Database Sync Check' -Command 'EXEC [DBA].[AvailabilityDatabaseSyncCheck]' -Database $adminDatabase
            }            
        }
        catch {

            Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error creating job step, Primary Instance Check in $agJob" -ForegroundColor Red
            Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error creating job step, Primary Instance Check in $agJob. The Error was: $error"
        }
    }
}

foreach($job in $sqlAgentJobs) {

    Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to create $job on $destinationServer" -ForegroundColor Yellow
    Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to create $job on $destinationServer"

    try {

        

        if ($job -eq '_MAINT_CycleErrorLog') {

            Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to create step Cycle Error Log in $job on $destinationServer" -ForegroundColor Yellow
            Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to create step Cycle Error Log in $job on $destinationServer"

            try {
                New-DbaAgentJobStep -SqlInstance $destinationSQLConnection -Job $job -StepName 'Cycle Error Log' -Command 'Exec sys.sp_cycle_errorlog' -Database msdb                
            }
            catch {
                Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error creating job step, Primary Instance Check in $agJob" -ForegroundColor Red
                Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error creating job step, Primary Instance Check in $agJob. The Error was: $error"
            }

            Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to create step Cycle Agent Error Log in $job on $destinationServer" -ForegroundColor Yellow
            Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to create step Cycle Agent Error Log in $job on $destinationServer"
            
            try {
                
                New-DbaAgentJobStep -SqlInstance $destinationSQLConnection -Job $job -StepName 'Cycle Agent Error Log' -Command 'Exec dbo.sp_cycle_agent_errorlog' -Database msdb                
            }
            catch
            {
                Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error creating job step, Primary Instance Check in $agJob" -ForegroundColor Red
                Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error creating job step, Primary Instance Check in $agJob. The Error was: $error"
            }

        } elseif($job -eq '_MAINT_sp_WhoIsActive Data Collection')
        {
            Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to create step Collect Who Is Active Data in $job on $destinationServer" -ForegroundColor Yellow
            Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to create step Collect Who Is Active Data in $job on $destinationServer"

            try {
                
                New-DbaAgentJobStep -SqlInstance $destinationSQLConnection -Job $agJob -StepName 'Collect Who Is Active Data' -Command 'EXEC dbo.sp_WhoIsActive @get_transaction_info = 1,@get_outer_command = 1,@get_plans = 1,@destination_table = "DBA.DB_Administration";' -Database $adminDatabase
            }
            catch {
                Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error creating job step, Primary Instance Check in $agJob" -ForegroundColor Red
                Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error creating job step, Primary Instance Check in $agJob. The Error was: $error"
            }

            Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to create step Remove Old Who Is Active Data in $job on $destinationServer" -ForegroundColor Yellow
            Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to create step Remove Old Who Is Active Data in $job on $destinationServer"

            try {

                New-DbaAgentJobStep -SqlInstance $destinationSQLConnection -Job $agJob -StepName 'Remove Old Who Is Active Data' -Command 'DELETE FROM DBA.WhoIsActive WHERE collection_time < DATEADD(day,-30, GETDATE());' -Database $adminDatabase        
            }
            catch {
                Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error creating job step, Primary Instance Check in $agJob" -ForegroundColor Red
                Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error creating job step, Primary Instance Check in $agJob. The Error was: $error"
            }
            
        } elseif($job -eq 'DBA: DatabaseSpaceTracking')
        {
            Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to create step Remove Record TempDB Space Used in $job on $destinationServer" -ForegroundColor Yellow
            Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to create step Remove Record TempDB Space Used in $job on $destinationServer"

            try {
                
                New-DbaAgentJobStep -SqlInstance $destinationSQLConnection -Job $agJob -StepName 'Record TempDB Space Used' -Command 'EXEC [DBA].[Run_TempDBSpaceTracking]' -Database $adminDatabase
            }
            catch
            {
                Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error creating job step, Primary Instance Check in $agJob" -ForegroundColor Red
                Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error creating job step, Primary Instance Check in $agJob. The Error was: $error"
            }
        } elseif($job -eq 'DBA: Send Email Alerts')
        {
            Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to create step Send Email Notifications in $job on $destinationServer" -ForegroundColor Yellow
            Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to create step Send Email Notifications in $job on $destinationServer"

            try {
                
                New-DbaAgentJobStep -SqlInstance $destinationSQLConnection -Job $agJob -StepName 'Send Email Notifications' -Command 'EXEC [DBA].[Send_Email_Notifications]' -Database $adminDatabase

            }
            catch {
                Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error creating job step, Primary Instance Check in $agJob" -ForegroundColor Red
                Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error creating job step, Primary Instance Check in $agJob. The Error was: $error"
            }
        } else 
        {
            Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to create $job on $destinationServer" -ForegroundColor Green
            Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Attempting to create $job on $destinationServer"

            try
            {
                New-DbaAgentJob -SqlInstance $destinationSQLConnection -Job $job -EmailLevel OnFailure -EmailOperator 'The DBA Team'

            } catch {

                Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error creating $job on $destinationServer" -ForegroundColor Red
                Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error creating $job on $destinationServer. The Error was: $error"

            }
        
            Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully created $job on $destinationServer" -ForegroundColor Green
            Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Sucessfully created $job on $destinationServer"
        }

    } 
    catch {

        Write-Host -Message "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error creating $job on $destinationServer" -ForegroundColor Red
        Add-Content -Path $logFullPath -Value "$(Get-Date -f yyyy-MM-dd-HH-mm) - Error creating $job on $destinationServer. The Error was: $error"
    }           
}
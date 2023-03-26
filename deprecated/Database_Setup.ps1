$server = 'Server01'
 
#check formatting for all drives on the server
invoke-command -computername $server {Get-Volume  | Format-List DriveLetter, AllocationUnitSize, FileSystemLabel}
 
#format the "D:" drive for 64kb allocation unit size
invoke-command -computername $server {Format-Volume -DriveLetter D -FileSystem NTFS -AllocationUnitSize 65536} #65536 is 64Kb
 
Install-DbaFirstResponderKit -SqlInstance $server -Database master

Install-DbaWhoIsActive -SqlInstance $server -Database master

$mailProfile = New-DbaDbMailProfile -SqlInstance sql2017 -Profile 'The DBA Team'

$account = New-DbaDbMailAccount -SqlInstance sql2017 -Account 'The DBA Team' -EmailAddress admin@ad.local -MailServer smtp.ad.local
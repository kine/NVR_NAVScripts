param (
    #Object files from which to update. Should be complete set of objects
    [Parameter(Mandatory=$true,ValueFromPipelinebyPropertyName=$True)]
    [String]$Files,
    #SQL Server address
    [Parameter(Mandatory=$true,ValueFromPipelinebyPropertyName=$True)]
    [String]$Server,
    #SQL Database to update
    [Parameter(Mandatory=$true,ValueFromPipelinebyPropertyName=$True)]
    [String]$Database,
    #LogFolder
    [Parameter(Mandatory=$true,ValueFromPipelinebyPropertyName=$True)]
    [String]$LogFolder
)

Import-Module -Name NVR_NAVScripts -DisableNameChecking -Force
Import-Module -Name CommonPSFunctions
Import-Module (Get-NAVAdminModuleName)

$ProgressPreference="SilentlyContinue"
Update-NAVApplicationFromTxt -Files $Files -Server $Server -Database $Database -LogFolder $LogFolder -MarkToDelete -NoProgress
$ProgressPreference="Continue"

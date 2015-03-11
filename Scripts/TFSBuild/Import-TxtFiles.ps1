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

Import-Module CommonPSFunctions -Force

$ProgressPreference="SilentlyContinue"
. (Join-Path $PSScriptRoot '..\Update-NAVApplicationFromTxt.ps1') -Files $Files -Server $Server -Database $Database -LogFolder $LogFolder -MarkToDelete
$ProgressPreference="Continue"

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

$srcpath = (Split-Path (Split-Path $Files))
if (Test-Path (Join-Path $srcpath 'setup.xml')) {
    $config = (. "$PSScriptRoot\..\Get-NAVGITSetup.ps1" -SetupFile (Join-Path $srcpath 'setup.xml'))
}

Write-Host 'Importing NVR_NAVScripts'
Import-Module -Name NVR_NAVScripts -DisableNameChecking -Force
Write-Host 'Importing CommonPSFunctions'
Import-Module -Name CommonPSFunctions
$AdminModule = (Get-NAVAdminModuleName)
Write-Host "Importing $AdminModule"
Import-Module $AdminModule
Write-Host "Imported"
Write-Host "NAVIdePath: $($env:NAVIdePath)"
Import-NAVModelTool -Global

$ProgressPreference="SilentlyContinue"
Update-NAVApplicationFromTxt -Files $Files -Server $Server -Database $Database -LogFolder $LogFolder -MarkToDelete -NoProgress -All
$ProgressPreference="Continue"

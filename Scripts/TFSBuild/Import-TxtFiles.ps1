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

Import-Module -Name NVR_NAVScripts -DisableNameChecking -Force
Import-Module -Name CommonPSFunctions
Import-Module (Get-NAVAdminModuleName)
Import-NAVModelTool -Global

$ProgressPreference="SilentlyContinue"
Update-NAVApplicationFromTxt -Files $Files -Server $Server -Database $Database -LogFolder $LogFolder -MarkToDelete -NoProgress
$ProgressPreference="Continue"

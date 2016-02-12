param (
    #Object files from which to update. Should be complete set of objects
    [Parameter(ValueFromPipelinebyPropertyName=$True)]
    [String]$Files=(Join-Path $env:BUILD_SOURCESDIRECTORY $env:NAV_OBJECTFILES),
    #SQL Server address
    [Parameter(ValueFromPipelinebyPropertyName=$True)]
    [String]$Server=$env:NAV_SQLSERVER,
    #SQL Database to update
    [Parameter(ValueFromPipelinebyPropertyName=$True)]
    [String]$Database=$env:NAV_SQLSERVERDB,
    #LogFolder
    [Parameter(ValueFromPipelinebyPropertyName=$True)]
    [String]$LogFolder=$env:BUILD_STAGINGDIRECTORY,
    [Parameter(ValueFromPipelinebyPropertyName = $true)]
    [String]$NavServerName=$env:NAV_NAVSERVER,
    #Name of the NAV Server Instance
    [Parameter(ValueFromPipelinebyPropertyName = $true)]
    [String]$NavServerInstance=$env:NAV_SERVERINSTANCE
)
if (Test-Path $env:BUILD_SOURCESDIRECTORY\setup.xml) {
    $config = (. "$PSScriptRoot\..\Get-NAVGITSetup.ps1" -SetupFile "$env:BUILD_SOURCESDIRECTORY\setup.xml")
}
$env:NavIdePath | Write-Host

Import-Module -Name NVR_NAVScripts -DisableNameChecking -Force
Import-Module -Name CommonPSFunctions
Import-Module (Get-NAVAdminModuleName)

Sync-NAVDbWithRepo -Files $env:NAV_OBJECTFILES -Repository '.' -Server $Server -Database $Database -NavServerName $NavServerName -NavServerInstance $NavServerInstance
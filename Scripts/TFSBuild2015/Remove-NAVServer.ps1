param(
	[String]$NavIde=$env:NAV_NAVIDEPATH,
	[String]$Server=$env:NAV_SQLSERVER,
	[String]$Database=$env:NAV_SQLSERVERDB,
	[String]$Instance=$env:NAV_SERVERINSTANCE
)
if (Test-Path $env:BUILD_SOURCESDIRECTORY\setup.xml) {
    $config = (. "$PSScriptRoot\..\Get-NAVGITSetup.ps1" -SetupFile "$env:BUILD_SOURCESDIRECTORY\setup.xml")
}

Import-Module CommonPSFunctions -Force -DisableNameChecking
Import-Module NVR_NAVScripts -Force -DisableNameChecking
Import-Module (Get-NAVAdminModuleName -NAVVersion $config.NAVVersion) -Force
Remove-NAVLocalApplication -Server $Server -Database $Database -ServerInstance $Instance

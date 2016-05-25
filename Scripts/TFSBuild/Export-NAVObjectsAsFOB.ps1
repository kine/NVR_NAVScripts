Param (
	[String]$Server,
	[String]$Database,
	[String]$ResultFob,
	[String]$NavIde,
	[String]$LogFolder
)
Import-Module -Name NVR_NAVScripts -DisableNameChecking -Force
if (Test-Path $env:BUILD_SOURCESDIRECTORY\setup.xml) {
    $config = (. "$PSScriptRoot\..\Get-NAVGITSetup.ps1" -SetupFile "$env:BUILD_SOURCESDIRECTORY\setup.xml")
}

NVR_NAVScripts\Export-NAVApplicationObject -Server $Server -Database $Database -Path $ResultFob -Filter 'Compiled=1' -NavIde Get-NAVIde -LogFolder $LogFolder


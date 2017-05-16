param(
	[String]$NAVVersionName
)

if (Test-Path $env:BUILD_SOURCESDIRECTORY\setup.xml) {
    $config = (. "$PSScriptRoot\..\Get-NAVGITSetup.ps1" -SetupFile "$env:BUILD_SOURCESDIRECTORY\setup.xml")
}

Import-Module CommonPSFunctions -Force -DisableNameChecking
Import-Module NVR_NAVScripts -Force -DisableNameChecking
Import-Module (Get-NAVAdminModuleName -NAVVersion $config.NAVVersion) -Force


NVR_NAVScripts\Rename-NAVWebClientSite -NAVVersionName $NAVVersionName
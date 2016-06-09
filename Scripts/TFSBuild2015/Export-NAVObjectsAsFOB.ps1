Param (
    [String]$Server=$env:NAV_SQLSERVER,
    [String]$Database=$env:NAV_SQLSERVERDB,
    [String]$ResultFob=(Join-Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY ($env:BUILD_BUILDNUMBER+'.fob')) ,
    [String]$NavIde=$env:NAV_NAVIDEPATH,
    [String]$LogFolder=$env:BUILD_STAGINGDIRECTORY
)
if (Test-Path $env:BUILD_SOURCESDIRECTORY\setup.xml) {
    $config = (. "$PSScriptRoot\..\Get-NAVGITSetup.ps1" -SetupFile "$env:BUILD_SOURCESDIRECTORY\setup.xml")
}

if (-not $Server)
{
    $Server = $config.Server
}

if (-not $Database)
{
    $Database = $config.Database
}


#$env:NavIdePath | Write-Host
Import-Module -Name CommonPSFunctions -DisableNameChecking -Force
Import-Module -Name NVR_NAVScripts -DisableNameChecking -Force

Write-InfoMessage -Message "NVR_NAVScripts\Export-NAVApplicationObject -Server $Server -Database $Database -Path $ResultFob -Filter 'Compiled=1' -NavIde $(Get-NAVIde) -LogFolder $LogFolder"
NVR_NAVScripts\Export-NAVApplicationObject -Server $Server -Database $Database -Path $ResultFob -Filter 'Compiled=1' -NavIde (Get-NAVIde) -LogFolder $LogFolder


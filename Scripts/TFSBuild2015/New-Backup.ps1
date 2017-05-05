Param (
    [String]$DbBackupFile=$env:NAV_DBBACKUPFILE,
    [String]$TargetPath=$env:BUILD_SOURCESDIRECTORY,
    [String]$Server=$env:NAV_SQLSERVER,
    [String]$Database=$env:NAV_SQLSERVERDB,
    [String]$ResultBak=(Join-Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY ($env:BUILD_BUILDNUMBER+'.bak')) ,

)

if (Test-Path $TargetPath\setup.xml) {
    $null = (. "$TargetPath\NVRPowerShell\Scripts\Settings.ps1")
    $config = (. "$TargetPath\NVRPowerShell\Scripts\Get-NAVGITSetup.ps1" -SetupFile "$TargetPath\setup.xml")
}

if (-not $Server)
{
    $Server = $config.Server
}

if (-not $Database)
{
    $Database = $config.Database
}


Import-Module -Name NVR_NAVScripts -DisableNameChecking -Force
Import-Module -Name CommonPSFunctions -Force

$Result = Get-SQLCommandResult -Command "BACKUP DATABASE [$Database] TO  DISK = N'$ResultBak' WITH  COPY_ONLY, NOFORMAT, INIT,  NAME = N'NAVAPP_QA_MT-Full Database Backup', SKIP, COMPRESSION, NOREWIND, NOUNLOAD,  STATS = 10" -Database Master -Server $Server

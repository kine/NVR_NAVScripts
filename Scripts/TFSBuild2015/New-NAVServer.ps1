Param (
    [String]$BaseFob=$env:NAV_FOBTOIMPORT,
    [String]$DbBackupFile=$env:NAV_DBBACKUPFILE,
    [String]$LicenseFile=$env:NAV_LICENCEFILE,
    [String]$TargetPath=$env:BUILD_SOURCESDIRECTORY,
    [String]$Server=$env:NAV_SQLSERVER,
    [String]$Database=$env:NAV_SQLSERVERDB,
    [String]$Instance=$env:NAV_SERVERINSTANCE,
    [String]$ForceNewDB=$env:NAV_FORCENEWDB,
    [String]$SQLDbFolder=$env:NAV_SQLDBFOLDER

)

if (Test-Path $TargetPath\setup.xml) {
    $config = (. "$PSScriptRoot\..\Get-NAVGITSetup.ps1" -SetupFile "$TargetPath\setup.xml")
}

if (-not $BaseFob) {
    $BaseFob = $config.BaseFob
}

if (-not $DbBackupFile)
{
    $DbBackupFile = $config.DBBackupFile
}

if (-not $LicenseFile)
{
    $LicenseFile = $config.LicenseFile
}

if (-not $Server)
{
    $Server = $config.Server
}

if (-not $Database)
{
    $Database = $config.Database
}

if (-not $Instance)
{
    $Instance = $config.ServerInstance
}

if (-not $SQLDbFolder)
{
    $SQLDbFolder = $config.TargetPath
}

Import-Module -Name NVR_NAVScripts -DisableNameChecking -Force
Import-Module -Name CommonPSFunctions -Force
Import-Module (Get-NAVAdminModuleName) -Force

if ($ForceNewDB -eq '0') {
    $ForceNewDB = $false
}

if ((Get-NAVServerInstance -ServerInstance $Instance) -and ($ForceNewDB -eq $False)) {
    Write-Host "Server instance $Instance already exists, skipping the initialization of environment..."
} else {
    if (Get-NAVServerInstance -ServerInstance $Instance) 
    {
        Write-InfoMessage -Message "Remove-NAVLocalApplication -Server $Server -Database $Database -ServerInstance $Instance"
        Remove-NAVLocalApplication -Server $Server -Database $Database -ServerInstance $Instance
    }
    Write-InfoMessage -Message "New-NAVLocalApplication -Server $Server -Database $Database -BaseFob $BaseFob -License $LicenseFile -DbBackupFile $DbBackupFile -ServerInstance $Instance -TargetPath $SQLDbFolder -Version $($config.NAVVersion))"
    New-NAVLocalApplication -Server $Server -Database $Database -BaseFob $BaseFob -License $LicenseFile -DbBackupFile $DbBackupFile -ServerInstance $Instance -TargetPath $SQLDbFolder -Version $config.NAVVersion
}

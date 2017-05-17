Param (
    [String]$BaseFob=$env:NAV_FOBTOIMPORT,
    [String]$DbBackupFile=$env:NAV_DBBACKUPFILE,
    [String]$LicenseFile=$env:NAV_LICENCEFILE,
    [String]$TargetPath=$env:BUILD_SOURCESDIRECTORY,
    [String]$Server=$env:NAV_SQLSERVER,
    [String]$Database=$env:NAV_SQLSERVERDB,
    [String]$Instance=$env:NAV_SERVERINSTANCE,
    [String]$ForceNewDB=$env:NAV_FORCENEWDB,
    [String]$SQLDbFolder=$env:NAV_SQLDBFOLDER,
    [String]$NAVVersion=$env:NAV_Version,
    [String]$SQLDbTempFolder

)

if (Test-Path $TargetPath\setup.xml) {
    $null = (. "$TargetPath\NVRPowerShell\Scripts\Settings.ps1")
    $config = (. "$TargetPath\NVRPowerShell\Scripts\Get-NAVGITSetup.ps1" -SetupFile "$TargetPath\setup.xml")
}

if (-not $BaseFob) {
    $BaseFob = $config.BaseFob
}

if ($env:NAV_FOBTOIMPORT2) {
    $BaseFob = $env:NAV_FOBTOIMPORT2
    Write-Host "env:NAV_FOBTOIMPORT2 = $($env:NAV_FOBTOIMPORT2)"
}

if (-not $DbBackupFile)
{
    $DbBackupFile = $config.DBBackupFile
}

if ($env:NAV_BACKUP2)
{
    $DbBackupFile = $env:NAV_BACKUP2
    $BaseFob = ""
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

if (-not $NAVVersion)
{
    $NAVVersion = $config.NAVVersion
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
    Write-InfoMessage "Server instance $Instance already exists, skipping the initialization of environment..."
} else {
    if (Get-NAVServerInstance -ServerInstance $Instance) 
    {
        Write-InfoMessage -Message "Remove-NAVLocalApplication -Server $Server -Database $Database -ServerInstance $Instance"
        Remove-NAVLocalApplication -Server $Server -Database $Database -ServerInstance $Instance
    }
    if (($Server -ine 'localhost') -and ($DbBackupFile -notlike '\\*')) {
      if (-not $SQLDBTempFolder) {
        Write-Error -Message "SQL Server $Server will not have access to file $DbBackupFile. Please, specify SQLDBTempFolder parameter!" -ErrorAction Stop
      }
      $DbBackupFile2 = (Join-Path $SQLDBTempFolder (Split-Path -Path $DbBackupFile -Leaf))
      Write-InfoMessage "Copying $DbBackupFile to $DbBackupFile2..."
      Copy-Item -Path $DbBackupFile -Destination $DbBackupFile2 -Force
      $DbBackupFile = $DbBackupFile2
    }
    Write-InfoMessage -Message "New-NAVLocalApplication -Server $Server -Database $Database -BaseFob $BaseFob -License $LicenseFile -DbBackupFile $DbBackupFile -ServerInstance $Instance -TargetPath $SQLDbFolder -Version $NAVVersion)"
    New-NAVLocalApplication -Server $Server -Database $Database -BaseFob $BaseFob -License $LicenseFile -DbBackupFile $DbBackupFile -ServerInstance $Instance -TargetPath $SQLDbFolder -Version $NAVVersion
    if ($DbBackupFile2) {
      Write-InfoMessage "Removing $DbBackupFile2..."
      Remove-Item -Path $DbBackupFile2 -Force
    }
}

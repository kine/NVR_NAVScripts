Param (
	[String]$NavIde,
	[String]$Files,
	[String]$LogFolder,
	[Bool]$CompileAll,
	[String]$Server,
	[String]$Database
)

$srcpath = (Split-Path (Split-Path $Files))
if (Test-Path (Join-Path $srcpath 'setup.xml')) {
    $config = (. "$PSScriptRoot\..\Get-NAVGITSetup.ps1" -SetupFile (Join-Path $srcpath 'setup.xml'))
}

Import-Module NVR_NAVScripts -Force -DisableNameChecking
Import-NAVModelTool
$ProgressPreference="SilentlyContinue"
Write-Host 'Compiling uncompiled system tables...'
Compile-NAVApplicationObject2 -DatabaseServer $Server -DatabaseName $Database -Filter 'Type=Table;Id=2000000000..' -LogPath $LogFolder -SynchronizeSchemaChanges Force -NavServerName localhost -NavServerInstance $config.ServerInstance
#Preventing the error about "Must be compiled..."
Write-Host 'Compiling uncompiled menusuites...'
Compile-NAVApplicationObject2 -DatabaseServer $Server -DatabaseName $Database -Filter 'Type=MenuSuite;Compiled=0' -LogPath $LogFolder -SynchronizeSchemaChanges Force -ErrorAction SilentlyContinue -NavServerName localhost -NavServerInstance $config.ServerInstance
Write-Host 'Compiling all menusuites...'
Compile-NAVApplicationObject2 -DatabaseServer $Server -DatabaseName $Database -Filter 'Type=MenuSuite' -LogPath $LogFolder -SynchronizeSchemaChanges Force -ErrorAction SilentlyContinue -NavServerName localhost -NavServerInstance $config.ServerInstance
Write-Host 'Compiling rest of objects...'
if ($CompileAll -eq 1) {
#	Compile-NAVApplicationObjectFilesMulti -Files $Files -Server $Server -Database $Database -LogFolder $LogFolder -NavIde $NavIde
    Write-Host 'Compiling non-test objects...'
    Compile-NAVApplicationObjectMulti -Server $Server -Database $Database -Filter 'Compiled=0|1;Version List=<>*Test*'-LogFolder $LogFolder -NavIde $NavIde  -SynchronizeSchemaChanges Force -AsJob -NavServerName localhost -NavServerInstance $config.ServerInstance
    Write-Host 'Compiling test objects...'
    Compile-NAVApplicationObjectMulti -Server $Server -Database $Database -Filter 'Compiled=0|1;Version List=*Test*'-LogFolder $LogFolder -NavIde $NavIde  -SynchronizeSchemaChanges Force -AsJob -NavServerName localhost -NavServerInstance $config.ServerInstance
} else {
    Write-Host 'Compiling non-test objects...'
    Compile-NAVApplicationObject2 -DatabaseServer $Server -DatabaseName $Database -Filter 'Compiled=0;Version List=<>*Test*' -LogPath $LogFolder -SynchronizeSchemaChanges Force -NavServerName localhost -NavServerInstance $config.ServerInstance
    Write-Host 'Compiling test objects...'
    Compile-NAVApplicationObject2 -DatabaseServer $Server -DatabaseName $Database -Filter 'Compiled=0;Version List=*Test*' -LogPath $LogFolder -SynchronizeSchemaChanges Force -NavServerName localhost -NavServerInstance $config.ServerInstance
}
$ProgressPreference="Continue"

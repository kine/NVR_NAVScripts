Param (
	[String]$NavIde,
	[String]$Files,
	[String]$LogFolder,
	[Bool]$CompileAll,
	[String]$Server,
	[String]$Database
)
if (Test-Path $env:BUILD_SOURCESDIRECTORY\setup.xml) {
    $config = (. "$PSScriptRoot\..\Get-NAVGITSetup.ps1" -SetupFile "$env:BUILD_SOURCESDIRECTORY\setup.xml")
}
$env:NavIdePath | Write-Host

Import-Module NVR_NAVScripts -Force -DisableNameChecking
$ProgressPreference="SilentlyContinue"
Write-Host 'Compiling uncompiled system tables...'
Compile-NAVApplicationObject2 -DatabaseServer $Server -DatabaseName $Database -Filter 'Type=Table;Id=2000000000..' -LogPath $LogFolder -SynchronizeSchemaChanges Force
#Preventing the error about "Must be compiled..."
Write-Host 'Compiling uncompiled menusuites...'
Compile-NAVApplicationObject2 -DatabaseServer $Server -DatabaseName $Database -Filter 'Type=MenuSuite;Compiled=0' -LogPath $LogFolder -SynchronizeSchemaChanges Force -ErrorAction SilentlyContinue
Write-Host 'Compiling rest of objects...'
if ($CompileAll -eq 1) {
    #	Compile-NAVApplicationObjectFilesMulti -Files $Files -Server $Server -Database $Database -LogFolder $LogFolder -NavIde $NavIde
    Write-Host 'Compiling non-test objects...'
    Compile-NAVApplicationObjectMulti -Server $Server -Database $Database -Filter 'Compiled=0|1;Version List=<>*Test*'-LogFolder $LogFolder -NavIde $NavIde  -SynchronizeSchemaChanges Force -AsJob
    Write-Host 'Compiling test objects...'
    Compile-NAVApplicationObjectMulti -Server $Server -Database $Database -Filter 'Compiled=0|1;Version List=*Test*'-LogFolder $LogFolder -NavIde $NavIde  -SynchronizeSchemaChanges Force -AsJob
} else {
    Write-Host 'Compiling non-test objects...'
    Compile-NAVApplicationObject2 -DatabaseServer $Server -DatabaseName $Database -Filter 'Compiled=0;Version List=<>*Test*' -LogPath $LogFolder -SynchronizeSchemaChanges Force
    Write-Host 'Compiling test objects...'
    Compile-NAVApplicationObject2 -DatabaseServer $Server -DatabaseName $Database -Filter 'Compiled=0;Version List=*Test*' -LogPath $LogFolder -SynchronizeSchemaChanges Force
}
$ProgressPreference="Continue"

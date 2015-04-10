Param (
	[String]$NavIde,
	[String]$Files,
	[String]$LogFolder,
	[Bool]$CompileAll,
	[String]$Server,
	[String]$Database
)

Import-Module NVR_NAVScripts -Force -DisableNameChecking
$ProgressPreference="SilentlyContinue"
Compile-NAVApplicationObject2 -DatabaseServer $Server -DatabaseName $Database -Filter 'Type=Table;Id=2000000000..' -LogPath $LogFolder -SynchronizeSchemaChanges Force
#Preventing the error about "Must be compiled..."
Compile-NAVApplicationObject2 -DatabaseServer $Server -DatabaseName $Database -Filter 'Type=MenuSuite;Compiled=0' -LogPath $LogFolder -SynchronizeSchemaChanges Force

if ($CompileAll -eq 1) {
#	Compile-NAVApplicationObjectFilesMulti -Files $Files -Server $Server -Database $Database -LogFolder $LogFolder -NavIde $NavIde
	Compile-NAVApplicationObjectMulti -Server $Server -Database $Database -Filter 'Compiled=0|1'-LogFolder $LogFolder -NavIde $NavIde  -SynchronizeSchemaChanges Force -AsJob
} else {
	Compile-NAVApplicationObject2 -DatabaseServer $Server -DatabaseName $Database -Filter 'Compiled=0' -LogPath $LogFolder -SynchronizeSchemaChanges Force
}
$ProgressPreference="Continue"

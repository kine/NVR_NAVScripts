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
Compile-NAVApplicationObject -Server $Server -Database $Database -Filter 'Type=Table;Id=2000000000..' -LogFolder $LogFolder -NavIde $NavIde 
#Preventing the error about "Must be compiled..."
Compile-NAVApplicationObject -Server $Server -Database $Database -Filter 'Type=MenuSuite;Compiled=0' -LogFolder $LogFolder -NavIde $NavIde 

if ($CompileAll -eq 1) {
	Compile-NAVApplicationObjectFilesMulti -Files $Files -Server $Server -Database $Database -LogFolder $LogFolder -NavIde $NavIde
} else {
	Compile-NAVApplicationObject -Server $Server -Database $Database -Filter 'Compiled=0' -LogFolder $LogFolder -NavIde $NavIde 
}
$ProgressPreference="Continue"

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

if ($CompileAll -eq 1) {
	Compile-NAVApplicationObjectFiles -Files $Files -Server $Server -Database $Database -LogFolder $LogFolder -NavIde $NavIde -WarningVariable warnings -ErrorVariable errors -OutVariable outputs 
} else {
	Compile-NAVApplicationObject -Server $Server -Database $Database -Filter 'Compiled=0' -LogFolder $LogFolder -NavIde $NavIde -WarningVariable warnings -ErrorVariable errors -OutVariable outputs
}
$ProgressPreference="Continue"

foreach ($line in $outputs) {
    Write-TfsMessage -message $line
}

foreach ($line in $warnings) {
    Write-TfsWarning -message $line
}

foreach ($line in $errors) {
    Write-TfsError -message $line
}
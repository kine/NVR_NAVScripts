Param (
	[String]$NavIde,
	[String]$Files,
	[String]$LogFolder,
	[Bool]$CompileAll,
	[String]$Server,
	[String]$Database
)

try {
    $ProgressPreference="SilentlyContinue"
    . "$PSScriptRoot\Compile-NAVObjectsOnServer.ps1" -NavIde $NavIde -Files $Files -LogFolder $LogFolder -CompileAll $CompileAll -Server $Server -Database $Database
    $ProgressPreference="Continue"
} catch [system.exception]
{
    $errors += $_.Exception.Message
    Write-Error "Exception: $($_.Exception.Message)"
}
finally {
}


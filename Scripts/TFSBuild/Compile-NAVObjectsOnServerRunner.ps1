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
    . "$PSScriptRoot\Compile-NAVObjectsOnServer.ps1" -NavIde $NavIde -Files $Files -LogFolder $LogFolder -CompileAll $CompileAll -Server $Server -Database $Database -WarningVariable warnings -OutVariable outputs
    $ProgressPreference="Continue"
} catch [system.exception]
{
    $errors += $_.Exception.Message
    Write-Error "Exception: $($_.Exception.Message)"
}
finally {
    foreach ($line in $outputs) {
        Write-TfsMessage -message $line
    }

    foreach ($line in $warnings) {
        Write-TfsWarning -message $line
    }

    foreach ($line in $Error) {
        Write-TfsError -message $line
    }
}


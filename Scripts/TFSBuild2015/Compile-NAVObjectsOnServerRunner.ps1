Param (
	[String]$NavIde=$env:NAV_NAVIDEPATH,
	[String]$Files=(Join-Path $env:BUILD_SOURCESDIRECTORY $env:NAV_OBJECTFILES),
	[String]$LogFolder=$env:BUILD_STAGINGDIRECTORY,
	[bool]$CompileAll=($env:NAV_CompileOnlyNotCompiled -ne '1'),
	[String]$Server=$env:NAV_SQLSERVER,
	[String]$Database=$env:NAV_SQLSERVERDB
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


param (
	[String]$Server,
	[String]$Instance,
	[int]$CodeunitID
)
Import-Module CommonPSFunctions -DisableNameChecking
Import-Module NVR_NAVScripts -DisableNameChecking
Import-NAVAdminTool

if ($CodeunitID -gt 0) {
	Write-Output "Running test codeunit $CodeunitID"
	Invoke-NAVCodeunit -ServerInstance $Instance -CodeunitId $CodeunitID
} else {
	Write-Output "No testing codeunit set, skipping tests..."
}
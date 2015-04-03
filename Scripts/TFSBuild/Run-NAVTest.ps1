param (
	[String]$Server,
	[String]$Instance,
	[int]$CodeunitID
)
Import-Module -Name NVR_NAVScripts -DisableNameChecking -Force
Import-Module -Name CommonPSFunctions
Import-Module (Get-NAVAdminModuleName)

if ($CodeunitID -gt 0) {
	Write-Output "Running test codeunit $CodeunitID"
	Invoke-NAVCodeunit -ServerInstance $Instance -CodeunitId $CodeunitID
} else {
	Write-Output "No testing codeunit set, skipping tests..."
}
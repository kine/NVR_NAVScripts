param (
	[String]$Server=$env:NAV_NAVSERVER,
	[String]$Instance=$env:NAV_SERVERINSTANCE,
	[int]$CodeunitID=$env:NAV_NAVTESTINGCODEUNIT
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
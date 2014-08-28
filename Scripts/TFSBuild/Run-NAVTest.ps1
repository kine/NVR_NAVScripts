param (
	[String]$Server,
	[String]$Instance,
	[int]$CodeunitID
)

if ($CodeunitID -gt 0) {
	Write-Output "!!!NOT IMPLEMENTED YET!!! ...Running test codeunit $CodeunitID"
} else {
	Write-Output "No testing codeunit set, skipping tests..."
}
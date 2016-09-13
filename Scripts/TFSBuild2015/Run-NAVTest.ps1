param (
	[String]$NAVServerName=$env:NAV_NAVSERVER,
	[String]$NAVServerInstance=$env:NAV_SERVERINSTANCE,
	[String]$SQLServer=$env:NAV_SQLSERVER,
	[String]$SQLDb=$env:NAV_SQLSERVERDB,
	[String]$CompanyName=$env:NAV_COMPANYNAME,
    [String]$TestFile=$env:NAV_TESTFILENAME,
	[int]$CodeunitID=$env:NAV_NAVTESTINGCODEUNIT
)

if (Test-Path $env:BUILD_SOURCESDIRECTORY\setup.xml) {
    $config = (. "$PSScriptRoot\..\Get-NAVGITSetup.ps1" -SetupFile "$env:BUILD_SOURCESDIRECTORY\setup.xml")
}

Import-Module -Name NVR_NAVScripts -DisableNameChecking -Force
Import-Module -Name CommonPSFunctions
Import-Module (Get-NAVAdminModuleName)

if ($CodeunitID -gt 0) {
    Write-Output "Running test codeunit $CodeunitID"
    Test-NAVDatabase -SQLServer $SQLServer -SQLDb $SQLDB -NAVServerName $NAVServerName -NAVServerInstance $NAVServerInstance -CompanyName $CompanyName -CodeunitId $CodeunitID -OutTestFile $TestFile -ReportFailures $False
} else {
    Write-Output 'No testing codeunit set, skipping tests...'
}
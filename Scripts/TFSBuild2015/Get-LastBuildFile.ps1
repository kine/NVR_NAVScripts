param
(
    [String]$Folder=$env:NAV_BUILDFOLDER,
    [String]$Filter='*.fob',
    [String]$Default=$env:NAV_FOBTOIMPORT,
    [String]$Enabled=$env:NAV_IMPORTLASTBUILDFOB
)

$TargetPath=$env:BUILD_SOURCESDIRECTORY
if (Test-Path $TargetPath\setup.xml) {
    $config = (. "$PSScriptRoot\..\Get-NAVGITSetup.ps1" -SetupFile "$TargetPath\setup.xml")
}
$Default = $config.BaseFob

if ($Enabled) 
{
    $file = Get-ChildItem -Path $Folder -Filter $Filter -Recurse | Sort-Object -Property CreationTime -Descending | Select-Object -First 1
    $env:NAV_FOBTOIMPORT = "$Default;$($file.FullName)"
} else {
    $env:NAV_FOBTOIMPORT = "$Default"
}

Write-Host "Will import $($env:NAV_FOBTOIMPORT)"

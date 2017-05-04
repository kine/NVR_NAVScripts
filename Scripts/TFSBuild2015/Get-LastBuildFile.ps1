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

if (-not $env:NAV_FOBTOIMPORT) {
  $Default = $config.BaseFob
  Write-Host "env:NAV_FOBTOIMPORT = $($env:NAV_FOBTOIMPORT)"
} else {
  Write-Host "env:NAV_FOBTOIMPORT = $($env:NAV_FOBTOIMPORT)"
}
$Default = $Default.Replace("""","")

if ($Enabled) 
{
    $file = Get-ChildItem -Path $Folder -Filter $Filter -Recurse | Sort-Object -Property CreationTime -Descending | Select-Object -First 1
    if ($Default) {
      $Default = "$Default;$($file.FullName)"
    } else {
      $Default = $file.FullName
    }
    Write-Host "##vso[task.setvariable variable=NAV_FOBTOIMPORT2;]$Default"
    Write-Host "Will import ***$Default***"
} else {
    Write-Host "##vso[task.setvariable variable=NAV_FOBTOIMPORT2;]$Default"
    Write-Host "Will import ***$Default***"
}


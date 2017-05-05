param
(
    [String]$Folder=$env:NAV_BUILDFOLDER,
    [String]$Filter='*.bak',
    [String]$Enabled=$env:NAV_IMPORTLASTBUILDBAK
)

$TargetPath=$env:BUILD_SOURCESDIRECTORY
if (Test-Path $TargetPath\setup.xml) {
    $config = (. "$PSScriptRoot\..\Get-NAVGITSetup.ps1" -SetupFile "$TargetPath\setup.xml")
}


if ($Enabled) 
{
    $file = Get-ChildItem -Path $Folder -Filter $Filter -Recurse | Sort-Object -Property CreationTime -Descending | Select-Object -First 1
    if ($Default) {
      $Default = "$Default;$($file.FullName)"
    } else {
      $Default = $file.FullName
    }
    Write-Host "##vso[task.setvariable variable=NAV_BACKUP2;]$Default"
    Write-Host "Will import ***$Default***"
} else {
}


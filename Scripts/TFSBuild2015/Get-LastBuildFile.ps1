param
(
    [String]$Folder=$env:NAV_BUILDFOLDER,
    [String]$Filter='*.fob',
    [String]$Default=$env:NAV_FOBTOIMPORT,
    [String]$Enabled=$env:NAV_IMPORTLASTBUILDFOB
)
#Get-Item -Path env: | Out-String | Write-Host 
#Write-Host "$($env:PSModulePath)"

if ($Enabled) 
{
    $file = Get-ChildItem -Path $Folder -Filter $Filter -Recurse | Sort-Object -Property CreationTime -Descending | Select-Object -First 1
    $env:NAV_FOBTOIMPORT = "$Default;$($file.FullName)"
} else {
}

Write-Host "Will import $($env:NAV_FOBTOIMPORT)"

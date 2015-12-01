#requires -Version 1
#requires -runasadministrator

$installfolder = $PSScriptRoot

if (-not (([Environment]::GetEnvironmentVariable('PSModulePath','Machine')) -like "*$installfolder*")) 
{
    Write-Host -Object "Extending PSModulePath with $PSScriptRoot" -ForegroundColor Green
    $env:PSModulePath = $env:PSModulePath + ';' + $installfolder
    Write-Host -Object "Extending Computer wide PSModulePath with $PSScriptRoot" -ForegroundColor Green
    [Environment]::SetEnvironmentVariable('PSModulePath',[Environment]::GetEnvironmentVariable('PSModulePath','Machine')+';'+$installfolder,'Machine')

    Write-Host 'Importing the modules' -ForegroundColor Green
    Import-Module CommonPSFunctions -DisableNameChecking -Global
    Import-Module NVR_NAVScripts -DisableNameChecking -Global
} else 
{
    Write-Host -Object "PSModulePath already includes $PSScriptRoot, skipping the setting" -ForegroundColor Green
}

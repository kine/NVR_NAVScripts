function Get-GitBranch
{
    <#
            .SYNOPSIS
            Fetch all from origin and check-out the selected branch
            .DESCRIPTION
            Fetch all from origin and check-out the selected branch
            .EXAMPLE
            Get-GitBranch -Repository 'c:\git\myrepo' -Branch 'master'
    #>
    [CmdletBinding()]
    param(
        [String]$Repository,
        [String]$Branch
    )
    Push-Location
    Set-Location "filesystem::$Repository"
    
    Write-Host "Fetching all for $Repository..." -ForegroundColor Green
    $result = git.exe fetch --quiet --all
    
    Write-Host "Checking out $Branch in $Repository..." -ForegroundColor Green
    $result = git.exe checkout --force -B $Branch "origin/$Branch" --quiet
    
    #$result = git checkout --force "$Branch" --quiet
    
    Write-Host 'Update submodules...' -ForegroundColor Green
    $result = git.exe submodule update --init --recursive | Out-Null
    Pop-Location
}
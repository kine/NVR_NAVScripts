<#
    .Synopsis
    Publish NAV objects in given folder
    .DESCRIPTION
    Publish NAV objects in given folder. Set new version list on modified objects, clear the modified flag,
    set actual date and time to the object.
    .EXAMPLE
    Publish-NAVObject -Source c:\nav\objects\*.txt -NewVersionTag 'LOC9.0.0.123'
#>
function Publish-NAVObject
{
    param
    (
        [Parameter(Mandatory = $true)]
        [String]$Source,
        [Parameter(Mandatory = $true)]
        [String]$NewVersionTag
    )
    $DateTimeProperty = Get-Date -Format g
    
    Import-NAVModelTool -Global
    Get-NAVApplicationObjectProperty -Source $Source | `
    Where-Object {$_.Modified -eq $True} | `
    ForEach-Object {
        Write-Verbose "Publishing object $($_.FileName)"
        Set-NAVApplicationObjectProperty `
        -TargetPath $_.FileName `
        -VersionListProperty (Merge-NAVVersionListString -source $_.VersionList -target $_.VersionList -newversion $NewVersionTag) `
        -ModifiedProperty No `
        -DateTimeProperty $DateTimeProperty `
    }

}
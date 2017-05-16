<#
    .SYNOPSIS
    Rename NAV Web Client IIS Site to be able to create/remove NAVWebInstance without error

    .DESCRIPTION
    The Rename-NAVWebClientSite will find NAV Web Client site regardes version (2016/2017 etc.) and will rename it
    according the parameter

    .INPUTS
    System.String
    NAV Version to which we want o rename (e.g. 2017)

    .OUTPUTS
    None

    .EXAMPLE
    Rename-NAVWebClientSite -NAVVersionName '2017'
    This command Will rename IIS site 'Microsoft Dynamics 2016 Web Client' to 'Microsoft Dynamics 2017 Web Client'

#>
function Rename-NAVWebClientSite
{
    [CmdletBinding]
    Params (
      $NAVVersionName='2017'
    )

    Import-Module WebAdministration

    $site = (Get-ChildItem IIS:\Sites\ | Where-Object {$_.Name -Like '*Web Client'})
    if ($site.Name -notlike "*$NAVVersionName*") {
        Rename-Item $site.PSPath "Microsoft Dynamics NAV $NAVVersionName Web Client"
    }
}
function Import-NAVAdminTool
{
    Import-Module -Global 'C:\Program Files\Microsoft Dynamics NAV\71\Service\Microsoft.Dynamics.Nav.Management.dll'
    Write-Verbose 'NAV admin tool imported'
}

function Import-NAVModelTool
{
    Import-Module -Global 'c:\Program Files (x86)\Microsoft Dynamics NAV\71\RoleTailored Client\Microsoft.Dynamics.Nav.Model.Tools.psd1' #-force -WarningAction SilentlyContinue | Out-Null
    Write-Verbose 'NAV model tool imported'
}

function Get-NAVIde
{
    return 'c:\Program Files (x86)\Microsoft Dynamics NAV\71\RoleTailored Client\finsql.exe'
}

function Get-NAVAdminPath
{
    return 'c:\Program Files\Microsoft Dynamics NAV\71\Service'
}

function Get-MyEmail
{
    ### Get the Email address of the current user
    try
    {
        ### Get the Distinguished Name of the current user
        $userFqdn = (whoami /fqdn)
 
        ### Use ADSI and the DN to get the AD object
        $adsiUser = [adsi]("LDAP://{0}" -F $userFqdn)
 
        ### Get the email address of the user
        $senderEmailAddress = $adsiUser.mail[0]
    }
    catch
    {
        Throw ("Unable to get the Email Address for the current user. '{0}'" -f $userFqdn)
    }
    Write-Output $senderEmailAddress
}

function Send-EmailToMe
{
    [CmdletBinding()]
    Param(
        [String]$Subject,
        [String]$Body,
        [String]$SMTPServer,
        [String]$FromEmail
    )

    $myemail=Get-MyEmail
    Send-MailMessage -Body $Body -From $FromEmail -SmtpServer $SMTPServer -Subject $Subject -To $myemail
}

function Remove-SQLDatabase
{
    [CmdletBinding()]
    Param (
        [String]$Server,
        [String]$Database
    )
    [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')  | Out-Null
    $srv = new-Object Microsoft.SqlServer.Management.Smo.Server($Server)
    $srv.KillAllprocesses("$Database")
    $srv.databases[$Database].drop()
}

<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
function Get-SQLCommandResult
{
    [CmdletBinding()]
    Param
    (
        # SQL Server
        [Parameter(Mandatory=$true,
                   Position=0)]
        $Server,

        # SQL Database Name
        [String]
        $Database,
        # SQL Command to run
        [String]
        $Command
    )

    Push-Location
    Import-Module "sqlps" -DisableNameChecking
    $Result = Invoke-Sqlcmd -Database $Database -ServerInstance $Server -Query $Command
    Pop-Location
    return $Result
}

Function Get-NAVObjectTypeIdFromName
{
    param(
        [Parameter(Mandatory=$true,Position=0)]
        [String]$TypeName
    )
    switch ($TypeName)
    {
        "TableData" {$Type = 0}
        "Table" {$Type = 1}
        "Page" {$Type = 8}
        "Codeunit" {$Type = 5}
        "Report" {$Type = 3}
        "XMLPort" {$Type = 6}
        "Query" {$Type = 9}
        "MenuSuite" {$Type = 7}
    }
    Return $Type
}

Function Get-NAVObjectTypeNameFromId
{
    param(
        [Parameter(Mandatory=$true,Position=0)]
        [int]$TypeId
    )
    switch ($TypeId)
    {
        0 {$Type = "TableData"}
        1 {$Type = "Table"}
        8 {$Type = "Page"}
        5 {$Type = "Codeunit"}
        3 {$Type = "Report"}
        6 {$Type = "XMLPort"}
        9 {$Type = "Query"}
        7 {$Type = "MenuSuite"}
    }
    Return $Type
}

Export-ModuleMember -Function Import-NAVAdminTool
Export-ModuleMember -Function Import-NAVModelTool
Export-ModuleMember -Function Get-MyEmail
Export-ModuleMember -Function Send-EmailToMe
Export-ModuleMember -Function Remove-SQLDatabase
Export-ModuleMember -Function Get-NAVObjectTypeIdFromName
Export-ModuleMember -Function Get-NAVObjectTypeNameFromId
Export-ModuleMember -Function Get-NAVIde
Export-ModuleMember -Function Get-NAVAdminPath
Export-ModuleMember -Function Get-SQLCommandResult

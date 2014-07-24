function Get-NAVIde
{
    return 'c:\Program Files (x86)\Microsoft Dynamics NAV\71\RoleTailored Client\finsql.exe'
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
    #$srv.killallprocess($Database)
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

    Begin
    {
        Import-Module “sqlps” -DisableNameChecking
    }
    Process
    {
        return Invoke-Sqlcmd -Database $Database -ServerInstance $Server -Query $Command
    }
    End
    {
    }
}

Export-ModuleMember -Function Get-MyEmail
Export-ModuleMember -Function Send-EmailToMe
Export-ModuleMember -Function Remove-SQLDatabase
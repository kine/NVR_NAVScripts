function Get-NAVIde
{
    if ($ENV:NAVIdePath -eq '') {
      return 'c:\Program Files (x86)\Microsoft Dynamics NAV\71\RoleTailored Client\finsql.exe'
    }
    return (Join-Path $ENV:NAVIdePath 'finsql.exe')
}

function Get-NAVIdePath
{
    if ($ENV:NAVIdePath -eq '') {
      return 'c:\Program Files (x86)\Microsoft Dynamics NAV\71\RoleTailored Client'
    }
    return $ENV:NAVIdePath
}

function Get-NAVAdminPath
{
    if ($ENV:NAVServicePath -eq '') {
      return 'c:\Program Files\Microsoft Dynamics NAV\71\Service'
    }
    return $ENV:NAVServicePath
}

function Import-NAVAdminTool
{
    Import-Module -Global (Join-Path (Get-NAVAdminPath) 'Microsoft.Dynamics.Nav.Management.dll') -DisableNameChecking
    Write-Verbose 'NAV admin tool imported'
}

function Import-NAVModelTool
{
    Import-Module -Global (Join-Path (Get-NAVIdePath) 'Microsoft.Dynamics.Nav.Model.Tools.psd1') -DisableNameChecking #-force -WarningAction SilentlyContinue | Out-Null
    Write-Verbose 'NAV model tool imported'
}

function Write-TfsMessage
{
    [CmdletBinding()]
    param (
        [String]$message
    )
    Write-Output "0:$Message"
}

function Write-TfsError
{
    [CmdletBinding()]
    param (
        [String]$message
    )
    Write-Output "2:$Message"
}

function Write-TfsWarning
{
    [CmdletBinding()]
    param (
        [String]$message
    )
    Write-Output "1:$Message"
}

<#
.Synopsis
   Get the current user e-mail address from AD
.DESCRIPTION
   Get the current user e-mail address from AD
.EXAMPLE
   Get-MyEmail
#>
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

<#
.Synopsis
   Get the specified user e-mail address from AD
.DESCRIPTION
   Get the specified user e-mail address from AD
.EXAMPLE
   Get-UserEmail
#>
function Get-UserEmail
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipelinebyPropertyName=$True)]
        [String]$UserName
    )

    ### Get the Email address of the current user
    try
    {
        $domain = New-Object DirectoryServices.DirectoryEntry
        $search = [System.DirectoryServices.DirectorySearcher]$domain
        $search.Filter = "(&(objectClass=user)(sAMAccountname=$UserName))"
        $user = $search.FindOne().GetDirectoryEntry()
 
        ### Use ADSI and the DN to get the AD object
        $adsiUser = [adsi]("{0}" -F $user.Path)
 
        ### Get the email address of the user
        $senderEmailAddress = $adsiUser.mail[0]
    }
    catch
    {
        Throw ("Unable to get the Email Address for the current user. '{0}'" -f $userFqdn)
    }
    Write-Output $senderEmailAddress
}

<#
.Synopsis
   Send e-mail to the current user email address
.DESCRIPTION
   Send e-mail to the current user email address
.EXAMPLE
   Send-EmailToMe -Subject "Hello World" -Body "This is email from powershell" -From "from@address.net" -SMTPServer myserver
#>
function Send-EmailToMe
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipelinebyPropertyName=$True)]
        [String]$Subject,
        [Parameter(Mandatory=$true,ValueFromPipelinebyPropertyName=$True)]
        [String]$Body,
        [Parameter(Mandatory=$true,ValueFromPipelinebyPropertyName=$True)]
        [String]$SMTPServer,
        [Parameter(Mandatory=$true,ValueFromPipelinebyPropertyName=$True)]
        [String]$FromEmail
    )

    $myemail=Get-MyEmail
    Send-MailMessage -Body $Body -From $FromEmail -SmtpServer $SMTPServer -Subject $Subject -To $myemail
}

<#
.Synopsis
   Delete the selected database
.DESCRIPTION
   Delete the selected database from the SQL Server. Automatically kills all active sessions to this database
.EXAMPLE
   Remove-SQLDatabase -Server mysql -Database mydatabase
#>
function Remove-SQLDatabase
{
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,ValueFromPipelinebyPropertyName=$True)]
        [String]$Server,
        [Parameter(Mandatory=$true,ValueFromPipelinebyPropertyName=$True)]
        [String]$Database
    )
    [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')  | Out-Null
    $srv = new-Object Microsoft.SqlServer.Management.Smo.Server($Server)
    $srv.KillAllprocesses("$Database")
    $srv.databases[$Database].drop()
}

<#
.Synopsis
   Execute T-SQL command on SQL server
.DESCRIPTION
   Execute T-SQL command on SQL server and returns the result back
.EXAMPLE
   Get-SQLCommandResult -Server localhost -Database mydatabase -Command "select * from object"
#>
function Get-SQLCommandResult
{
    [CmdletBinding()]
    Param
    (
        # SQL Server
        [Parameter(Mandatory=$true,ValueFromPipelinebyPropertyName=$True,
                   Position=0)]
        $Server,

        # SQL Database Name
        [Parameter(Mandatory=$true,ValueFromPipelinebyPropertyName=$True)]
        [String]
        $Database,
        # SQL Command to run
        [Parameter(Mandatory=$true,ValueFromPipelinebyPropertyName=$True)]
        [String]
        $Command
    )

    #Push-Location
    #Import-Module "sqlps" -DisableNameChecking
    #$Result = Invoke-Sqlcmd -Database $Database -ServerInstance $Server -Query $Command
    #Pop-Location
    #return $Result
 
    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Server = $Server; Database = $Database; Integrated Security = True"
 
    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
    $SqlCmd.CommandText = $Command
    $SqlCmd.Connection = $SqlConnection
 
    $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
    $SqlAdapter.SelectCommand = $SqlCmd
 
    $DataSet = New-Object System.Data.DataSet
    $SqlAdapter.Fill($DataSet)
 
    $SqlConnection.Close()
 
    return $DataSet.Tables[0]

}

<#
.Synopsis
   Translate object type names to integer
.DESCRIPTION
   Function takes the ObjectType names and returns the intiger number representing the object type
.EXAMPLE
   Get-NAVObjectTypeIdFrom Name -TypeName "Report"
#>
Function Get-NAVObjectTypeIdFromName
{
    param(
        [Parameter(Mandatory=$true,ValueFromPipelinebyPropertyName=$True)]
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

<#
.Synopsis
   Translate object type number to object type name
.DESCRIPTION
   Function takes the ObjectType number and returns the name representing the object type
.EXAMPLE
   Get-NAVObjectTypeNameFromId -TypeId 3
#>
Function Get-NAVObjectTypeNameFromId
{
    param(
        [Parameter(Mandatory=$true,ValueFromPipelinebyPropertyName=$True)]
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
Export-ModuleMember -Function Get-UserEmail
Export-ModuleMember -Function Send-EmailToMe
Export-ModuleMember -Function Remove-SQLDatabase
Export-ModuleMember -Function Get-NAVObjectTypeIdFromName
Export-ModuleMember -Function Get-NAVObjectTypeNameFromId
Export-ModuleMember -Function Get-NAVIde
Export-ModuleMember -Function Get-NAVAdminPath
Export-ModuleMember -Function Get-SQLCommandResult
Export-ModuleMember -Function Write-TfsMessage
Export-ModuleMember -Function Write-TfsError
Export-ModuleMember -Function Write-TfsWarning

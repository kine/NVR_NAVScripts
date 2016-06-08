Get-Item $PSScriptRoot  | Get-ChildItem -Recurse -file -Filter '*.ps1' |  Sort Name | foreach {

    Write-Verbose "Loading $($_.Name)"

    . $_.fullname
}

function Get-NAVIde
{
    if ($NavIde) {
      Write-InfoMessage -Message "Get-NavIde = $NavIde"
      return $NavIde
    }
    if (!$env:NAVIdePath) 
    {
    Write-InfoMessage -Message "Get-NavIdePath = 'c:\Program Files (x86)\Microsoft Dynamics NAV\80\RoleTailored Client\finsql.exe'"
        return 'c:\Program Files (x86)\Microsoft Dynamics NAV\80\RoleTailored Client\finsql.exe'
    }
    Write-InfoMessage -Message "Get-NavIdePath = $((Join-Path -Path $env:NAVIdePath -ChildPath 'finsql.exe'))"
    return (Join-Path -Path $env:NAVIdePath -ChildPath 'finsql.exe')
}

function Get-NAVIdePath
{
    if ($NavIde) {
      Write-InfoMessage -Message "Get-NavIdePath = $(Split-Path $NavIde)"
      return (Split-Path $NavIde)
    }
    if (!$env:NAVIdePath) 
    {
        Write-InfoMessage -Message "Get-NavIdePath = 'c:\Program Files (x86)\Microsoft Dynamics NAV\80\RoleTailored Client'" -Level 10
        return 'c:\Program Files (x86)\Microsoft Dynamics NAV\80\RoleTailored Client'
    }
    Write-InfoMessage -Message "Get-NavIdePath = $($env:NAVIdePath)"
    return $env:NAVIdePath
}

function Get-NAVAdminPath
{
    if (!$env:NAVServicePath) 
    {
        return 'c:\Program Files\Microsoft Dynamics NAV\80\Service'
    }
    return $env:NAVServicePath
}

function Get-NAVAdminModuleName
{
    #    return (Join-Path -Path (Get-NAVAdminPath) -ChildPath 'Microsoft.Dynamics.Nav.Management.dll')
    return (Join-Path -Path (Get-NAVAdminPath) -ChildPath 'Microsoft.Dynamics.Nav.Management.dll')
}
function Import-NAVAdminTool
{
    [CmdletBinding()]
    param (
        [Switch]$Force
    )
    $module = Get-Module -Name 'Microsoft.Dynamics.Nav.Management'
    $modulepath = Get-NAVAdminModuleName
    if ($Force) 
    {
        Write-Host -Object "Removing module $($module.Path)"
        Remove-Module -Name 'Microsoft.Dynamics.Nav.Management' -Force
    }
    if (!($module) -or ($module.Path -ne $modulepath) -or ($Force)) 
    {
        if (!(Test-Path -Path $modulepath)) 
        {
            Write-Error -Message "Module $moduelpath not found!"
            return
        }
        Write-Host -Object "Importing NAVAdminTool from $modulepath"
        Import-Module "$modulepath" -DisableNameChecking -Force -Scope Local
        #& $modulepath #| Out-Null
        Write-Verbose -Message 'NAV admin tool imported'
    } else 
    {
        Write-Verbose -Message 'NAV admin tool already imported'
    }
}

function Import-NAVModelTool
{
    [CmdletBinding()]
    param (
        [Switch]$Global
    )
    $modulepath = (Join-Path -Path (Get-NAVIdePath) -ChildPath 'Microsoft.Dynamics.Nav.Model.Tools.psd1')
    $module = Get-Module -Name 'Microsoft.Dynamics.Nav.Model.Tools'
    if (!($module) -or ($module.Path -ne $modulepath)) 
    {
        if (!(Test-Path -Path $modulepath)) 
        {
            Write-Error -Message "Module $modulepath not found!"
            return
        }
        if ($Global) {
            Write-Host -Object "Importing Globally NAVModelTool from $modulepath"
            Import-Module "$modulepath" -ArgumentList (Get-NAVIde) -DisableNameChecking -Force -Scope Global #-WarningAction SilentlyContinue | Out-Null
            Write-Verbose -Message 'NAV model tool imported'
        } else {
            Write-Host -Object "Importing NAVModelTool from $modulepath"
            Import-Module "$modulepath" -ArgumentList (Get-NAVIde) -DisableNameChecking -Force -Scope Local #-WarningAction SilentlyContinue | Out-Null
            Write-Verbose -Message 'NAV model tool imported'
        }
    } else 
    {
        Write-Verbose -Message 'NAV model tool already imported'
    }
}

function Write-TfsMessage
{
    [CmdletBinding()]
    param (
        [String]$message
    )
    Write-Output -InputObject "0:$message"
}

function Write-TfsError
{
    [CmdletBinding()]
    param (
        [String]$message
    )
    Write-Output -InputObject "2:$message"
}

function Write-TfsWarning
{
    [CmdletBinding()]
    param (
        [String]$message
    )
    Write-Output -InputObject "1:$message"
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
        $userFqdn = (whoami.exe /fqdn)
 
        ### Use ADSI and the DN to get the AD object
        $adsiUser = [adsi]('LDAP://{0}' -F $userFqdn)
 
        ### Get the email address of the user
        $senderEmailAddress = $adsiUser.mail[0]
    }
    catch
    {
        Throw ("Unable to get the Email Address for the current user. '{0}'" -f $userFqdn)
    }
    Write-Output -InputObject $senderEmailAddress
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
        [Parameter(Mandatory = $true,ValueFromPipelinebyPropertyName = $true)]
        [String]$UserName
    )

    ### Get the Email address of the current user
    try
    {
        $domain = New-Object -TypeName DirectoryServices.DirectoryEntry
        $search = [System.DirectoryServices.DirectorySearcher]$domain
        $search.Filter = "(&(objectClass=user)(sAMAccountname=$UserName))"
        $user = $search.FindOne().GetDirectoryEntry()
 
        ### Use ADSI and the DN to get the AD object
        $adsiUser = [adsi]('{0}' -F $user.Path)
 
        ### Get the email address of the user
        $senderEmailAddress = $adsiUser.mail[0]
    }
    catch
    {
        Throw ("Unable to get the Email Address for the current user. '{0}'" -f $userFqdn)
    }
    Write-Output -InputObject $senderEmailAddress
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
        [Parameter(Mandatory = $true,ValueFromPipelinebyPropertyName = $true)]
        [String]$Subject,
        [Parameter(Mandatory = $true,ValueFromPipelinebyPropertyName = $true)]
        [String]$Body,
        [Parameter(Mandatory = $true,ValueFromPipelinebyPropertyName = $true)]
        [String]$SMTPServer,
        [Parameter(Mandatory = $true,ValueFromPipelinebyPropertyName = $true)]
        [String]$FromEmail
    )

    $myemail = Get-MyEmail
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
        [Parameter(Mandatory = $true,ValueFromPipelinebyPropertyName = $true)]
        [String]$Server,
        [Parameter(Mandatory = $true,ValueFromPipelinebyPropertyName = $true)]
        [String]$Database
    )
    $null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')
    $srv = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList ($Server)
    $srv.KillAllprocesses("$Database")
    if ($srv.databases[$Database]) 
    {
        $srv.databases[$Database].drop()
    }
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
        [Parameter(Mandatory = $true,ValueFromPipelinebyPropertyName = $true,
        Position = 0)]
        $Server,

        # SQL Database Name
        [Parameter(Mandatory = $true,ValueFromPipelinebyPropertyName = $true)]
        [String]
        $Database,
        # SQL Command to run
        [Parameter(Mandatory = $true,ValueFromPipelinebyPropertyName = $true)]
        [String]
        $Command,
        # Force return of dataset even when doesn't begin with SELECT
        [Parameter(ValueFromPipelinebyPropertyName = $true)]
        [Switch]
        $ForceDataset
      
    )
    Write-Verbose -Message "Executing SQL command: $Command"
    #Push-Location
    #Import-Module "sqlps" -DisableNameChecking
    #$Result = Invoke-Sqlcmd -Database $Database -ServerInstance $Server -Query $Command
    #Pop-Location
    #return $Result
 
    $SqlConnection = New-Object -TypeName System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Server = $Server; Database = $Database; Integrated Security = True"
 
    $SqlCmd = New-Object -TypeName System.Data.SqlClient.SqlCommand
    $SqlCmd.CommandText = $Command
    $SqlCmd.Connection = $SqlConnection
    
    if (($Command.Split(' ')[0] -ilike 'select') -or ($ForceDataset)) 
    {
        $SqlAdapter = New-Object -TypeName System.Data.SqlClient.SqlDataAdapter
        $SqlAdapter.SelectCommand = $SqlCmd
 
        $DataSet = New-Object -TypeName System.Data.DataSet
        $result = $SqlAdapter.Fill($DataSet)
 
        $result = $SqlConnection.Close()
 
        return $DataSet.Tables[0]
    }
    else 
    {
        $result = $SqlConnection.Open()
        #$result = $SqlCmd.ExecuteScalar()
        $result = $SqlCmd.ExecuteNonQuery()
        $SqlConnection.Close()
        return $result
    }
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
        [Parameter(Mandatory = $true,ValueFromPipelinebyPropertyName = $true)]
        [String]$TypeName
    )
    switch ($TypeName)
    {
        'TableData' 
        {
            $Type = 0
        }
        'Table' 
        {
            $Type = 1
        }
        'Page' 
        {
            $Type = 8
        }
        'Codeunit' 
        {
            $Type = 5
        }
        'Report' 
        {
            $Type = 3
        }
        'XMLPort' 
        {
            $Type = 6
        }
        'Query' 
        {
            $Type = 9
        }
        'MenuSuite' 
        {
            $Type = 7
        }
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
        [Parameter(Mandatory = $true,ValueFromPipelinebyPropertyName = $true)]
        [int]$TypeId
    )
    switch ($TypeId)
    {
        0 
        {
            $Type = 'TableData'
        }
        1 
        {
            $Type = 'Table'
        }
        8 
        {
            $Type = 'Page'
        }
        5 
        {
            $Type = 'Codeunit'
        }
        3 
        {
            $Type = 'Report'
        }
        6 
        {
            $Type = 'XMLPort'
        }
        9 
        {
            $Type = 'Query'
        }
        7 
        {
            $Type = 'MenuSuite'
        }
    }
    Return $Type
}

<#
        .Synopsis
        Get the content of blob in Byte[] and returns the content as Data and MagicConstant
        .DESCRIPTION
        Get the content of blob in Byte[] and returns the content as Data and MagicConstant (first 4 bytes).
        Can be used to read data from the blob stored by Microsoft Dynamics NAV
#>
function Get-NAVBlobToString
{
    [CmdletBinding()]
    [OutputType([PSObject])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory = $true,
                ValueFromPipelineByPropertyName = $true,
        Position = 0)]
        [byte[]]$CompressedByteArray
    )

    try 
    {
        $ms = New-Object -TypeName System.IO.MemoryStream
        #Write-Host "Magic constant: $($CompressedByteArray[0]) $($CompressedByteArray[1]) $($CompressedByteArray[2]) $($CompressedByteArray[3])"
        $null = $ms.Write($CompressedByteArray,4,$CompressedByteArray.Length-4)
        $null = $ms.Seek(0,0)

        $cs = New-Object -TypeName System.IO.Compression.DeflateStream -ArgumentList ($ms, [System.IO.Compression.CompressionMode]::Decompress)
        $sr = New-Object -TypeName System.IO.StreamReader -ArgumentList ($cs)

        $t = $sr.ReadToEnd()
    }
    catch 
    {

    }
    finally 
    {
        $null = $sr.Close()
        $null = $cs.Close()
        $null = $ms.Close()
    }
    return @{
        MagicConstant = $CompressedByteArray[0, 1, 2, 3]
        Data          = $t
    }
}

<#
        .Synopsis
        Create NAVBlob data from string and MagicConstant
        .DESCRIPTION
        Create NAVBlob data from string and MagicConstant. Can be used to prepare data for storin into BLOB field
        used by Microsoft Dynamics NAV to store data like profiles, images, notes etc.
    
#>
function Get-StringToNAVBlob
{
    [CmdletBinding()]
    [OutputType([byte[]])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory = $true,
                ValueFromPipelineByPropertyName = $true,
        Position = 0)]
        [byte[]]$MagicConstant,
        [Parameter(Mandatory = $true,
                ValueFromPipelineByPropertyName = $true,
        Position = 1)]
        [String]$Data
    )
    

    try 
    {
        $ms = New-Object -TypeName System.IO.MemoryStream

        $cs = New-Object -TypeName System.IO.Compression.DeflateStream -ArgumentList ($ms, [System.IO.Compression.CompressionMode]::Compress)
        $sw = New-Object -TypeName System.IO.StreamWriter -ArgumentList ($cs)
        

        $sw.Write($Data)
        $sw.Close()

        [byte[]]$result = $ms.ToArray()
    }
    catch 
    {

    }
    finally 
    {
        $null = $sw.Close()
        $null = $cs.Close()
        $null = $ms.Close()
    }
    $result = $MagicConstant+$result
    return $result
}

function Get-Confirmation
{
    <#
            .SYNOPSIS
            Display query with answer Yes or No
            .DESCRIPTION
            Display query with answer Yes or No and return the result
            .EXAMPLE
            Get-Confirmation -title "Question" -message "Do you want to continue?" -yeshint 'It will continue' -nohint 'processing will be cancelled'

            result is 0 for Yes, 1 is for no
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$false, Position=0)]
        [System.String]
        $title,
        
        [Parameter(Mandatory=$false, Position=1)]
        [Object]
        $message ,
        [Parameter(Mandatory=$false, Position=1)]
        [Object]
        $yeshint,
        [Parameter(Mandatory=$false, Position=1)]
        [Object]
        $nohint
    )
    
    $yes = New-Object -TypeName System.Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes', $yeshint
    $no = New-Object -TypeName System.Management.Automation.Host.ChoiceDescription -ArgumentList '&No', $nohint
    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    $result = $host.ui.PromptForChoice($title, $message, $options, 1) 
    return $result
}

function Test-Administrator  
{ 
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)  
}

function Set-InfoMessageVerbosity
{
    [CmdletBinding()]
    Param(
        [int]$Verbosity
    )
    [global]$VerbosityLevel=$Verbosity
}
function Write-InfoMessage
{
    
    [CmdletBinding()]
    Param(
        $Message,
        [int]$Level=0
    )
    if (!$VerbosityLevel -or ($VerbosityLevel -eq 0)) {
        if ($Level -eq 0) {
            Write-Host $Message -ForegroundColor Green
        } else {
            Write-Verbose -Message $Message
        }
    } else {
        if ($Level -le $VerbosityLevel) {
            Write-Host $Message -ForegroundColor DarkYellow
        } else {
            Write-Verbose -Message $Message
        }
    }
}

Export-ModuleMember -Function *

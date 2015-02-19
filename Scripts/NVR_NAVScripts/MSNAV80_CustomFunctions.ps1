function Get-NavIdeMajorVersion
{
    $IdeFile = Get-NavIde
    $IdeFileVersion= (Get-Command $IdeFile).FileVersionInfo.FileVersion
    return ($IdeFileVersion.Split('.')[0])
}

<#
    .SYNOPSIS
    Imports NAV application objects from a file into a database.

    .DESCRIPTION
    The Import-NAVApplicationObject function imports the objects from the specified file(s) into the specified database. When multiple files are specified, finsql is invoked for each file. For better performance the files can be joined first. However, using seperate files can be useful for analyzing import errors.

    .INPUTS
    System.String[]
    You can pipe a path to the Import-NavApplicationObject function.

    .OUTPUTS
    None

    .EXAMPLE
    Import-NAVApplicationObject MyAppSrc.txt MyApp
    This command imports all application objects in MyAppSrc.txt into the MyApp database.

    .EXAMPLE
    Import-NAVApplicationObject MyAppSrc.txt -DatabaseName MyApp
    This command imports all application objects in MyAppSrc.txt into the MyApp database.

    .EXAMPLE
    Get-ChildItem MyAppSrc | Import-NAVApplicationObject -DatabaseName MyApp
    This commands imports all objects in all files in the MyAppSrc folder into the MyApp database. The files are imported one by one.

    .EXAMPLE
    Get-ChildItem MyAppSrc | Join-NAVApplicationObject -Destination .\MyAppSrc.txt -PassThru | Import-NAVApplicationObject -Database MyApp
    This commands joins all objects in all files in the MyAppSrc folder into a single file and then imports them in the MyApp database.
#>
function Import-NAVApplicationObject2
{
    [CmdletBinding(DefaultParameterSetName="All", SupportsShouldProcess=$true, ConfirmImpact='High')]
    Param(
        # Specifies one or more files to import.  
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias('PSPath')]
        [string[]] $Path,

        # Specifies the name of the database into which you want to import.
        [Parameter(Mandatory=$true, Position=1)]
        [string] $DatabaseName,

        # Specifies the name of the SQL server instance to which the database you want to import into is attached. The default value is the default instance on the local host (.).
        [ValidateNotNullOrEmpty()]
        [string] $DatabaseServer = '.',

        # Specifies the log folder.
        [ValidateNotNullOrEmpty()]
        [string] $LogPath = "$Env:TEMP\NavIde\$([GUID]::NewGuid().GUID)",

        # Specifies the import action. The default value is 'Default'.
        [ValidateSet('Default','Overwrite','Skip')] [string] $ImportAction = 'Default',

        # Specifies the schema synchronization behaviour. The default value is 'Yes'.
        [ValidateSet('Yes','No','Force')] [string] $SynchronizeSchemaChanges = 'Yes',

        # The user name to use to authenticate to the database. The user name must exist in the database. If you do not specify a user name and password, then the command uses the credentials of the current Windows user to authenticate to the database.
        [Parameter(Mandatory=$true, ParameterSetName="DatabaseAuthentication")]
        [string] $Username,

        # The password to use with the username parameter to authenticate to the database. If you do not specify a user name and password, then the command uses the credentials of the current Windows user to authenticate to the database.
        [Parameter(Mandatory=$true, ParameterSetName="DatabaseAuthentication")]
        [string] $Password,

        # Specifies the name of the server that hosts the Microsoft Dynamics NAV Server instance, such as MyServer.
        [ValidateNotNullOrEmpty()]
        [string] $NavServerName,

        # Specifies the Microsoft Dynamics NAV Server instance that is being used.The default value is DynamicsNAV80.
        [ValidateNotNullOrEmpty()]
        [string] $NavServerInstance = "DynamicsNAV80",

        # Specifies the port on the Microsoft Dynamics NAV Server server that the Microsoft Dynamics NAV Windows PowerShell cmdlets access. The default value is 7045.
        [ValidateNotNullOrEmpty()]
        [int16]  $NavServerManagementPort = 7045)

    PROCESS
    {
        if ($Path.Count -eq 1)
        {
            $Path = (Get-Item $Path).FullName
        }

        if ($PSCmdlet.ShouldProcess(
            "Import application objects from $Path into the $DatabaseName database.",
            "Import application objects from $Path into the $DatabaseName database. If you continue, you may loose data in fields that are removed or changed in the imported file.",
            'Confirm'))
        {
            $navServerInfo = GetNavServerInfo $NavServerName $NavServerInstance $NavServerManagementPort

            foreach ($file in $Path)
            {
                # Log file name is based on the name of the imported file.
                $logFile = "$LogPath\$((Get-Item $file).BaseName).log"
                if ((Get-NavIdeMajorVersion) -ge 8) {
                    $command = "Command=ImportObjects`,ImportAction=$ImportAction`,SynchronizeSchemaChanges=$SynchronizeSchemaChanges`,File=`"$file`"" 
                } else {
                    $command = "Command=ImportObjects`,ImportAction=$ImportAction``,File=`"$file`"" 
                }

                try
                {
                    RunNavIdeCommand -Command $command `
                                     -DatabaseServer $DatabaseServer `
                                     -DatabaseName $DatabaseName `
                                     -NTAuthentication:($Username -eq $null) `
                                     -Username $Username `
                                     -Password $Password `
                                     -NavServerInfo $navServerInfo `
                                     -LogFile $logFile `
                                     -ErrText "Error while importing $file" `
                                     -Verbose:$VerbosePreference
                }
                catch
                {
                    Write-Error $_
                }
            }
        }
    }
}

function GetNavServerInfo
(
    [string] $NavServerName,
    [string] $NavServerInstance,
    [int16]  $NavServerManagementPort
)
{
    $navServerInfo = ""
    if ($navServerName)
    {
        $navServerInfo = @"
`,NavServerName="$NavServerName"`,NavServerInstance="$NavServerInstance"`,NavServerManagementport=$NavServerManagementPort
"@
    }

    $navServerInfo
}

function TestNavIde
{
    if (-not (Get-NavIde) -or (((Get-NavIde)) -and -not (Test-Path (Get-NavIde))))
    {
        throw '(Get-NavIde) was not correctly set. Please assign the path to finsql.exe to (Get-NavIde) ((Get-NavIde) = path).'
    }
}

function RunNavIdeCommand
{
    [CmdletBinding()]
    Param(
    [string] $Command,
    [string] $DatabaseServer,
    [string] $DatabaseName,
    [switch] $NTAuthentication,
    [string] $Username,
    [string] $Password,
    [string] $NavServerInfo,
    [string] $LogFile,
    [string] $ErrText)

    TestNavIde
    $logPath = (Split-Path $LogFile)

    Remove-Item "$logPath\navcommandresult.txt" -ErrorAction Ignore
    Remove-Item $logFile -ErrorAction Ignore

    $databaseInfo = @"
ServerName="$DatabaseServer"`,Database="$DatabaseName"
"@
    if ($Username)
    {
        $databaseInfo = @"
ntauthentication=No`,username="$Username"`,password="$Password"`,$databaseInfo
"@
    }
    $NavIde=Get-NavIde
    $finSqlCommand = @"
& "$NavIde" --% $Command`,LogFile="$logFile"`,${databaseInfo}${NavServerInfo} | Out-Null
"@ 

    Write-Verbose "Running command: $finSqlCommand"
    Invoke-Expression -Command  $finSqlCommand
  
    if (Test-Path "$logPath\navcommandresult.txt")
    {
        if (Test-Path $LogFile)
        {
            throw "${ErrorText}: $(Get-Content $LogFile -Raw)" -replace "`r[^`n]","`r`n"
        }
    }
    else
    {
        throw "${ErrorText}!"
    }
}

<#
    .SYNOPSIS    
    Export NAV application objects from a database into a file.

    .DESCRIPTION
    The Export-NAVApplicationObject function exports the objects from the specified database into the specified file. A filter can be specified to select the application objects to be exported.

    .INPUTS
    None
    You cannot pipe input to this function.

    .OUTPUTS
    System.IO.FileInfo
    An object representing the exported file.

    .EXAMPLE
    Export-NAVApplicationObject MyApp MyAppSrc.txt
    Exports all application objects from the MyApp database to MyAppSrc.txt.

    .EXAMPLE
    Export-NAVApplicationObject MyAppSrc.txt -DatabaseName MyApp
    Exports all application objects from the MyApp database to MyAppSrc.txt.

    .EXAMPLE
    Export-NAVApplicationObject MyApp COD1-10.txt -Filter 'Type=Codeunit;Id=1..10'
    Exports codeunits 1..10 from the MyApp database to COD1-10.txt

    .EXAMPLE
    Export-NAVApplicationObject COD1-10.txt -DatabaseName MyApp -Filter 'Type=Codeunit;Id=1..10'
    Exports codeunits 1..10 from the MyApp database to COD1-10.txt

    .EXAMPLE
    Export-NAVApplicationObject COD1-10.txt -DatabaseName MyApp -Filter 'Type=Codeunit;Id=1..10' | Import-NAVApplicationObject -DatabaseName MyApp2
    Copies codeunits 1..10 from the MyApp database to the MyApp2 database.

    .EXAMPLE
    Export-NAVApplicationObject MyAppSrc.txt -DatabaseName MyApp | Split-NAVApplicationObject -Destination MyAppSrc
    Exports all application objects from the MyApp database and splits into single-object files in the MyAppSrc folder.
#>
function Export-NAVApplicationObject2
{
    [CmdletBinding(DefaultParameterSetName="All",SupportsShouldProcess = $true)]
    Param(
        # Specifies the name of the database from which you want to export.
        [Parameter(Mandatory=$true, Position=0)]
        [string] $DatabaseName,

        # Specifies the file to export to.
        [Parameter(Mandatory=$true, Position=1)]
        [string] $Path,

        # Specifies the name of the SQL server instance to which the database you want to import into is attached. The default value is the default instance on the local host (.).
        [ValidateNotNullOrEmpty()]
        [string] $DatabaseServer = '.',

        # Specifies the log folder.
        [ValidateNotNullOrEmpty()]
        [string] $LogPath = "$Env:TEMP\NavIde\$([GUID]::NewGuid().GUID)",

        # Specifies the filter that selects the objects to export.
        [string] $Filter,

        # Allows the command to create a file that overwrites an existing file.
        [Switch] $Force,

        # Allows the command to skip application objects that are excluded from license, when exporting as txt.
        [Switch] $ExportTxtSkipUnlicensed,

        # The user name to use to authenticate to the database. The user name must exist in the database. If you do not specify a user name and password, then the command uses the credentials of the current Windows user to authenticate to the database.
        [Parameter(Mandatory=$true, ParameterSetName="DatabaseAuthentication")]
        [string] $Username,

        # The password to use with the username parameter to authenticate to the database. If you do not specify a user name and password, then the command uses the credentials of the current Windows user to authenticate to the database.
        [Parameter(Mandatory=$true, ParameterSetName="DatabaseAuthentication")]
        [string] $Password)

    if ($PSCmdlet.ShouldProcess(
        "Export application objects from $DatabaseName database to $Path.",
        "Export application objects from $DatabaseName database to $Path.",
        'Confirm'))
    {
        if (!$Force -and (Test-Path $Path) -and !$PSCmdlet.ShouldContinue(
            "$Path already exists. If you continue, $Path will be overwritten.",
            'Confirm'))
        {
            Write-Error "$Path already exists."
            return
        }
    }
    else
    {
        return
    }

    $skipUnlicensed = "No"
    if($ExportTxtSkipUnlicensed)
    {
        $skipUnlicensed = "Yes"
    }

    if ((Get-NavIdeMajorVersion) -ge 8) {
        $command = "Command=ExportObjects`,ExportTxtSkipUnlicensed=$skipUnlicensed`,File=`"$Path`"" 
    } else {
        $command = "Command=ExportObjects`,File=`"$Path`"" 
    }

    if($Filter)
    {
        $command = "$command`,Filter=`"$Filter`""
    }

    $logFile = (Join-Path $logPath naverrorlog.txt)

    try
    {
        RunNavIdeCommand -Command $command `
                         -DatabaseServer $DatabaseServer `
                         -DatabaseName $DatabaseName `
                         -NTAuthentication:($Username -eq $null) `
                         -Username $Username `
                         -Password $Password `
                         -NavServerInfo "" `
                         -LogFile $logFile `
                         -ErrText "Error while exporting $Filter" `
                         -Verbose:$VerbosePreference
        Get-Item $Path 
    }
    catch
    {
        Write-Error $_
    }
}

<#
    .SYNOPSIS
    Deletes NAV application objects from a database.

    .DESCRIPTION
    The Delete-NAVApplicationObject function deletes objects from the specified database. A filter can be specified to select the application objects to be deleted.

    .INPUTS
    None
    You cannot pipe input to this function.

    .OUTPUTS
    None

    .EXAMPLE
    Delete-NAVApplicationObject -DatabaseName MyApp -Filter 'Type=Codeunit;Id=1..10'
    Deletes codeunits 1..10 from the MyApp database
#>
function Delete-NAVApplicationObject2
{
    [CmdletBinding(DefaultParameterSetName="All", SupportsShouldProcess=$true, ConfirmImpact='High')]
    Param(
        # Specifies the name of the database from which you want to delete objects.
        [Parameter(Mandatory=$true, Position=0)]
        [string] $DatabaseName,

        # Specifies the name of the SQL server instance to which the database you want to delete objects from is attached. The default value is the default instance on the local host (.).
        [ValidateNotNullOrEmpty()]
        [string] $DatabaseServer = '.',

        # Specifies the log folder.
        [ValidateNotNullOrEmpty()]
        [string] $LogPath = "$Env:TEMP\NavIde\$([GUID]::NewGuid().GUID)",

        # Specifies the filter that selects the objects to delete.
        [string] $Filter,

        # Specifies the schema synchronization behaviour. The default value is 'Yes'.
        [ValidateSet('Yes','No','Force')]
        [string] $SynchronizeSchemaChanges = 'Yes',

        # The user name to use to authenticate to the database. The user name must exist in the database. If you do not specify a user name and password, then the command uses the credentials of the current Windows user to authenticate to the database.
        [Parameter(Mandatory=$true, ParameterSetName="DatabaseAuthentication")]
        [string] $Username,

        # The password to use with the username parameter to authenticate to the database. If you do not specify a user name and password, then the command uses the credentials of the current Windows user to authenticate to the database.
        [Parameter(Mandatory=$true, ParameterSetName="DatabaseAuthentication")]
        [string] $Password,

        # Specifies the name of the server that hosts the Microsoft Dynamics NAV Server instance, such as MyServer.
        [ValidateNotNullOrEmpty()]
        [string] $NavServerName,

        # Specifies the Microsoft Dynamics NAV Server instance that is being used.The default value is DynamicsNAV80.
        [ValidateNotNullOrEmpty()]
        [string] $NavServerInstance = "DynamicsNAV80",

        # Specifies the port on the Microsoft Dynamics NAV Server server that the Microsoft Dynamics NAV Windows PowerShell cmdlets access. The default value is 7045.
        [ValidateNotNullOrEmpty()]
        [int16]  $NavServerManagementPort = 7045)

    if ($PSCmdlet.ShouldProcess(
        "Delete application objects from $DatabaseName database.",
        "Delete application objects from $DatabaseName database.",
        'Confirm'))
    {
        if ((Get-NavIdeMajorVersion) -ge 8) {
            $command = "Command=DeleteObjects`,SynchronizeSchemaChanges=$SynchronizeSchemaChanges"
        } else {
            Write-Error "DeleteObjects command not supported!"
        }
        if($Filter)
        {
            $command = "$command`,Filter=`"$Filter`""
        } 

        $logFile = (Join-Path $logPath naverrorlog.txt)
        $navServerInfo = GetNavServerInfo $NavServerName $NavServerInstance $NavServerManagementPort

        try
        {
            RunNavIdeCommand -Command $command `
                             -DatabaseServer $DatabaseServer `
                             -DatabaseName $DatabaseName `
                             -NTAuthentication:($Username -eq $null) `
                             -Username $Username `
                             -Password $Password `
                             -NavServerInfo $navServerInfo `
                             -LogFile $logFile `
                             -ErrText "Error while deleting $Filter" `
                             -Verbose:$VerbosePreference
        }
        catch
        {
            Write-Error $_
        }
    }
}

<#
    .SYNOPSIS
    Compiles NAV application objects in a database.

    .DESCRIPTION
    The Compile-NAVApplicationObject function compiles application objects in the specified database. A filter can be specified to select the application objects to be compiled. Unless the Recompile switch is used only uncompiled objects are compiled.

    .INPUTS
    None
    You cannot pipe input to this function.

    .OUTPUTS
    None

    .EXAMPLE
    Compile-NAVApplicationObject MyApp
    Compiles all uncompiled application objects in the MyApp database.

    .EXAMPLE
    Compile-NAVApplicationObject MyApp -Filter 'Type=Codeunit' -Recompile
    Compiles all codeunits in the MyApp database.

    .EXAMPLE
    'Page','Codeunit','Table','XMLport','Report' | % { Compile-NAVApplicationObject -Database MyApp -Filter "Type=$_" -AsJob } | Receive-Job -Wait    
    Compiles all uncompiled Pages, Codeunits, Tables, XMLports, and Reports in the MyApp database in parallel and wait until it is done. Note that some objects may remain uncompiled due to race conditions. Those remaining objects can be compiled in a seperate command.

#>
function Compile-NAVApplicationObject2
{
    [CmdletBinding(DefaultParameterSetName="All")]
    Param(
        # Specifies the name of the Dynamics NAV database.
        [Parameter(Mandatory=$true, Position=0)]
        [string] $DatabaseName,

        # Specifies the name of the SQL server instance to which the Dynamics NAV database is attached. The default value is the default instance on the local host (.).
        [ValidateNotNullOrEmpty()]
        [string] $DatabaseServer = '.',

        # Specifies the log folder.
        [ValidateNotNullOrEmpty()]
        [string] $LogPath = "$Env:TEMP\NavIde\$([GUID]::NewGuid().GUID)",

        # Specifies the filter that selects the objects to compile.
        [string] $Filter,

        # Compiles objects that are already compiled.
        [Switch] $Recompile,

        # Compiles in the background returning an object that represents the background job.
        [Switch] $AsJob,
        
        # Specifies the schema synchronization behaviour. The default value is 'Yes'.
        [ValidateSet('Yes','No','Force')]
        [string] $SynchronizeSchemaChanges = 'Yes',

        # The user name to use to authenticate to the database. The user name must exist in the database. If you do not specify a user name and password, then the command uses the credentials of the current Windows user to authenticate to the database.
        [Parameter(Mandatory=$true, ParameterSetName="DatabaseAuthentication")]
        [string] $Username,

        # The password to use with the username parameter to authenticate to the database. If you do not specify a user name and password, then the command uses the credentials of the current Windows user to authenticate to the database.
        [Parameter(Mandatory=$true, ParameterSetName="DatabaseAuthentication")]
        [string] $Password,

        # Specifies the name of the server that hosts the Microsoft Dynamics NAV Server instance, such as MyServer.
        [ValidateNotNullOrEmpty()]
        [string] $NavServerName,

        # Specifies the Microsoft Dynamics NAV Server instance that is being used.The default value is DynamicsNAV80.
        [ValidateNotNullOrEmpty()]
        [string] $NavServerInstance = "DynamicsNAV80",

        # Specifies the port on the Microsoft Dynamics NAV Server server that the Microsoft Dynamics NAV Windows PowerShell cmdlets access. The default value is 7045.
        [ValidateNotNullOrEmpty()]
        [int16]  $NavServerManagementPort = 7045)
    
    if (-not $Recompile)
    {
        $Filter += ';Compiled=0'
        $Filter = $Filter.TrimStart(';')
    }

    if ($AsJob)
    {
        $LogPath = "$LogPath\$([GUID]::NewGuid().GUID)"
        Remove-Item $LogPath -ErrorAction Ignore -Recurse -Confirm:$False -Force
        $scriptBlock =
        {
            Param($ScriptPath,$NavIde,$DatabaseName,$DatabaseServer,$LogPath,$Filter,$Recompile,$SynchronizeSchemaChanges,$Username,$Password,$NavServerName,$NavServerInstance,$NavServerManagementPort,$VerbosePreference)

            Import-NAVModelTool

            $args = @{
                DatabaseName = $DatabaseName
                DatabaseServer = $DatabaseServer
                LogPath = $LogPath
                Filter = $Filter
                Recompile = $Recompile
                SynchronizeSchemaChanges = $SynchronizeSchemaChanges
            }

            if($Username)
            {
                $args.Add("Username",$Username)
                $args.Add("Password",$Password)
            }

            if($NavServerName)
            {
                $args.Add("NavServerName",$NavServerName)
                $args.Add("NavServerInstance",$NavServerInstance)
                $args.Add("NavServerManagementPort",$NavServerManagementPort)
            }

            Compile-NAVApplicationObject2 @args -Verbose:$VerbosePreference
        }

        $job = Start-Job $scriptBlock -ArgumentList $PSScriptRoot,Get-NavIde,$DatabaseName,$DatabaseServer,$LogPath,$Filter,$Recompile,$SynchronizeSchemaChanges,$Username,$Password,$NavServerName,$NavServerInstance,$NavServerManagementPort,$VerbosePreference
        return $job
    }
    else
    {
        try
        {
            $logFile = (Join-Path $LogPath naverrorlog.txt)
            $navServerInfo = GetNavServerInfo $NavServerName $NavServerInstance $NavServerManagementPort     
            if ((Get-NavIdeMajorVersion) -ge 8) {
                $command = "Command=CompileObjects`,SynchronizeSchemaChanges=$SynchronizeSchemaChanges"
            } else {
                $command = "Command=CompileObjects"
            }

            if($Filter)
            {
                $command = "$command,Filter=`"$Filter`""
            }

            RunNavIdeCommand -Command $command `
                             -DatabaseServer $DatabaseServer `
                             -DatabaseName $DatabaseName `
                             -NTAuthentication:($Username -eq $null) `
                             -Username $Username `
                             -Password $Password `
                             -NavServerInfo $navServerInfo `
                             -LogFile $logFile `
                             -ErrText "Error while compiling $Filter" `
                             -Verbose:$VerbosePreference
        }
        catch
        {
            Write-Error $_
        }
    }
}

<#
    .SYNOPSIS
    Creates a new NAV application database.

    .DESCRIPTION
    The Create-NAVDatabase creates a new NAV database that includes the NAV system tables.

    .INPUTS
    None
    You cannot pipe input into this function.

    .OUTPUTS
    None

    .EXAMPLE
    Create-NAVDatabase MyNewApp
    Creates a new NAV database named MyNewApp.

    .EXAMPLE
    Create-NAVDatabase MyNewApp -ServerName "TestComputer01\NAVDEMO" -Collation "da-dk"
    Creates a new NAV database named MyNewApp on TestComputer01\NAVDEMO Sql server with Danish collation.
#>
function Create-NAVDatabase2
{
    [CmdletBinding(DefaultParameterSetName="All")]
    Param(
         # Specifies the name of the Dynamics NAV database that will be created.
        [Parameter(Mandatory=$true, Position=0)]
        [string] $DatabaseName,

        # Specifies the name of the SQL server instance on which you want to create the database. The default value is the default instance on the local host (.).
        [ValidateNotNullOrEmpty()]
        [string] $DatabaseServer = '.',

        # Specifies the collation of the database.
        [ValidateNotNullOrEmpty()]
        [string] $Collation,

        # Specifies the log folder.
        [ValidateNotNullOrEmpty()]
        [string] $LogPath = "$Env:TEMP\NavIde\$([GUID]::NewGuid().GUID)",


        # The user name to use to authenticate to the database. The user name must exist in the database. If you do not specify a user name and password, then the command uses the credentials of the current Windows user to authenticate to the database.
        [Parameter(Mandatory=$true, ParameterSetName="DatabaseAuthentication")]
        [string] $Username,

        # The password to use with the username parameter to authenticate to the database. If you do not specify a user name and password, then the command uses the credentials of the current Windows user to authenticate to the database.
        [Parameter(Mandatory=$true, ParameterSetName="DatabaseAuthentication")]
        [string] $Password)

    $logFile = (Join-Path $LogPath naverrorlog.txt)

    if ((Get-NavIdeMajorVersion) -ge 8) {
       $command = "Command=CreateDatabase`,Collation=$Collation"
    } else {
       $command = "Command=CreateDatabase"
    }

    try
    {
        RunNavIdeCommand -Command $command `
                         -DatabaseServer $DatabaseServer `
                         -DatabaseName $DatabaseName `
                         -NTAuthentication:($Username -eq $null) `
                         -Username $Username `
                         -Password $Password `
                         -NavServerInfo $navServerInfo `
                         -LogFile $logFile `
                         -ErrText "Error while creating $DatabaseName" `
                         -Verbose:$VerbosePreference
    }
    catch
    {
        Write-Error $_
    }
}

<#
    .SYNOPSIS
    Performs a technical upgrade of a database from a previous version of Microsoft Dynamics NAV.

    .DESCRIPTION
    Performs a technical upgrade of a database from a previous version of Microsoft Dynamics NAV.

    .INPUTS
    None
    You cannot pipe input into this function.

    .OUTPUTS
    None

    .EXAMPLE
    Invoke-NAVDatabaseConversion MyApp
    Perform the technical upgrade on a NAV database named MyApp.

    .EXAMPLE
    Invoke-NAVDatabaseConversion MyApp -ServerName "TestComputer01\NAVDEMO"
    Perform the technical upgrade on a NAV database named MyApp on TestComputer01\NAVDEMO Sql server .
#>
function Invoke-NAVDatabaseConversion2
{
    [CmdletBinding(DefaultParameterSetName="All")]
    Param(
         # Specifies the name of the Dynamics NAV database that will be created.
        [Parameter(Mandatory=$true, Position=0)]
        [string] $DatabaseName,

        # Specifies the name of the SQL server instance on which you want to create the database. The default value is the default instance on the local host (.).
        [ValidateNotNullOrEmpty()]
        [string] $DatabaseServer = '.',

        # Specifies the log folder.
        [ValidateNotNullOrEmpty()]
        [string] $LogPath = "$Env:TEMP\NavIde\$([GUID]::NewGuid().GUID)",

        # The user name to use to authenticate to the database. The user name must exist in the database. If you do not specify a user name and password, then the command uses the credentials of the current Windows user to authenticate to the database.
        [Parameter(Mandatory=$true, ParameterSetName="DatabaseAuthentication")]
        [string] $Username,

        # The password to use with the username parameter to authenticate to the database. If you do not specify a user name and password, then the command uses the credentials of the current Windows user to authenticate to the database.
        [Parameter(Mandatory=$true, ParameterSetName="DatabaseAuthentication")]
        [string] $Password)

    $logFile = (Join-Path $LogPath naverrorlog.txt)

    $command = "Command=UpgradeDatabase"

    try
    {
        RunNavIdeCommand -Command $command `
                         -DatabaseServer $DatabaseServer `
                         -DatabaseName $DatabaseName `
                         -NTAuthentication:($Username -eq $null) `
                         -Username $Username `
                         -Password $Password `
                         -NavServerInfo "" `
                         -LogFile $logFile `
                         -ErrText "Error while converting $DatabaseName" `
                         -Verbose:$VerbosePreference
    }
    catch
    {
        Write-Error $_
    }
}

Export-ModuleMember -Function Import-NAVApplicationObject2
Export-ModuleMember -Function Export-NAVApplicationObject2
Export-ModuleMember -Function Delete-NAVApplicationObject2
Export-ModuleMember -Function Compile-NAVApplicationObject2
Export-ModuleMember -Function Create-NAVDatabase2
Export-ModuleMember -Function Invoke-NAVDatabaseConversion2

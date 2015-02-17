﻿#import-module -Name Microsoft.Dynamics.Nav.Ide -Verbose
#. "Merge-NAVVersionListString script.ps1"

#Import-Module 'c:\Program Files (x86)\Microsoft Dynamics NAV\71\RoleTailored Client\Microsoft.Dynamics.Nav.Model.Tools.psd1' -WarningAction SilentlyContinue | Out-Null
Import-NAVAdminTool
Import-NAVModelTool

. (Join-Path -Path $PSScriptRoot -ChildPath 'MSNAV80_CustomFunctions.ps1')

Add-Type -Language CSharp -TypeDefinition @"
  public enum VersionListMergeMode
  {
    SourceFirst,
    TargetFirst
  }
"@

function Get-VersionListModuleShortcut
{
    param
    (
        [System.String]
        $part
    )

    $index = $part.IndexOfAny('0123456789')
    if ($index -ge 1) 
    {
        $result = @{
            'shortcut' = $part.Substring(0,$index)
            'version' = $part.Substring($index)
        }
    }
    else 
    {
        $result = @{
            'shortcut' = $part
            'version' = ''
        }
    }
    return $result
}

function Get-VersionListHash
{
    param
    (
        [System.String]
        $versionlist
    )

    $hash = @{}
    $versionlistarray = $versionlist.Split(',')
    foreach ($element in $versionlistarray) 
    {
        $moduleinfo = Get-VersionListModuleShortcut($element)
        $hash.Add($moduleinfo.shortcut,$moduleinfo.version)
    }
    return $hash
}

function Merge-NAVVersionListString 
{
    param
    (
        [System.String]
        $source,

        [System.String]
        $target,

        [System.String]
        $newversion,

        [String]
        $mode = [VersionListMergeMode]::SourceFirst
    )

    if ($mode -eq [VersionListMergeMode]::TargetFirst) 
    {
        $temp = $source
        $source = $target
        $target = $temp
    }
    $result = ''
    $sourcearray = $source.Split(',')
    $targetarray = $target.Split(',')
    $sourcehash = Get-VersionListHash($source)
    $targethash = Get-VersionListHash($target)
    $newmoduleinfo = Get-VersionListModuleShortcut($newversion)
    foreach ($module in $sourcearray) 
    {
        $actualversion = ''
        $moduleinfo = Get-VersionListModuleShortcut($module)
        if ($sourcehash[$moduleinfo.shortcut] -ge $targethash[$moduleinfo.shortcut]) 
        {
            $actualversion = $sourcehash[$moduleinfo.shortcut]
        }
        else 
        {
            $actualversion = $targethash[$moduleinfo.shortcut]
        }
        if ($moduleinfo.shortcut -eq $newmoduleinfo.shortcut) 
        {
            $actualversion = $newmoduleinfo.version
        }
        if ($result.Length -gt 0) 
        {
            $result = $result + ','
        }
        $result = $result + $moduleinfo.shortcut + $actualversion
    }
    foreach ($module in $targetarray) 
    {
        $moduleinfo = Get-VersionListModuleShortcut($module)
        if (!$sourcehash.ContainsKey($moduleinfo.shortcut)) 
        {
            if ($result.Length -gt 0) 
            {
                $result = $result + ','
            }
            if ($moduleinfo.shortcut -eq $newmoduleinfo.shortcut) 
            {
                $result = $result + $newversion
            }
            else 
            {
                $result = $result + $module
            }
        }
    }
    return $result
}

function ClearFolder
{
    param
    (
        [String]
        $path
    )

    Remove-Item -Path $path'\*' -Exclude '.*' -Recurse -Include '*.txt', '*.conflict'
}

function Set-NAVModifiedObject
{
    param
    (
        [String]
        $path
    )

    #Write-Host $input
    foreach ($modifiedfile in $input) 
    {
        #Write-Host $modifiedfile.filename
        $filename = $path+'\'+$modifiedfile.filename
        #Write-Host $filename
        If (Test-Path ($filename)) 
        {
            Set-NAVApplicationObjectProperty -TargetPath $filename -ModifiedProperty Yes
        }
    }
}

function Get-NAVModifiedObject
{
    param
    (
        [String]
        $source
    )

    $result = @()
    $files = Get-ChildItem $source -Filter *.txt
    ForEach ($file in $files) 
    {
        $lineno = 0
        $content = Get-Content -Path $file.FullName
        $objectproperties = Get-NAVApplicationObjectProperty -Source $file.FullName
        $resultfile = @{
            'filename' = $file.Name
            'value'  = $objectproperties.Modified
        }
        $object = New-Object -TypeName PSObject -Property $resultfile
        $result += $object
    }
    return $result
}

function Merge-NAVObjectVersionList
{
    param
    (
        [String]
        $modifiedfilename,

        [String]
        $targetfilename,

        [String]
        $resultfilename,

        [String]
        $newversion
    )

    $ProgressPreference = 'SilentlyContinue'
    $modifiedproperty = Get-NAVApplicationObjectProperty -Source $modifiedfilename 
    $sourceproperty = Get-NAVApplicationObjectProperty -Source $targetfilename
    #$targetproperty = Get-NAVApplicationObjectProperty -Source $resultfilename;

    $targetversionlist = Merge-NAVVersionListString -source $sourceproperty.VersionList -target $modifiedproperty.VersionList -mode SourceFirst -newversion $newversion
    #Write-Host 'Updating version list on '$filename' from '$sourceversionlist' and '$modifiedversionlist' to '$targetversionlist
    Set-NAVApplicationObjectProperty -TargetPath $resultfilename -VersionListProperty $targetversionlist
    $ProgressPreference = 'Continue'
}

function Get-NAVDatabaseObjects
{
    param
    (
        [String]
        $sourceserver,

        [String]
        $sourcedb,

        [String]
        $sourcefilefolder,

        [String]
        $sourceclientfolder
    )

    ClearFolder($sourcefilefolder)
    $NavIde = $sourceclientfolder+'\finsql.exe'
    Write-Host 'Exporting Objects from '$sourceserver'\'$sourcedb'...'
    $exportresult = Export-NAVApplicationObject -Server $sourceserver -Database $sourcedb -path $sourcefilefolder'.txt'
    Write-Host -Object 'Splitting Objects...'
    $splitresult = Split-NAVApplicationObjectFile -Source $sourcefilefolder'.txt' -Destination $sourcefilefolder -Force
    Remove-Item -Path $sourcefilefolder'.txt'
}

function Import-NAVApplicationObjectFiles
{
    [CmdletBinding()]
    Param(
        [String]$files,
        [String]$Server,
        [String]$Database,
        [String]$LogFolder,
        [String]$NavIde = '',
        [String]$ClientFolder = ''
    )
    if ($NavIde -eq '') 
    {
        $NavIde = Get-NAVIde
    }

    $finsqlparams = "command=importobjects,servername=$Server,database=$Database,file="

    $TextFiles = Get-ChildItem -Path "$files"
    $i = 0

    $StartTime = Get-Date

    foreach ($TextFile in $TextFiles)
    {
        $NowTime = Get-Date
        $TimeSpan = New-TimeSpan $StartTime $NowTime
        $Command = $importfinsqlcommand + $TextFile
        $LogFile = "$LogFolder\$($TextFile.Basename).log"
        $i = $i+1
        $percent = $i / $TextFiles.Count
        $remtime = $TimeSpan.TotalSeconds / $percent * (1-$percent)
        $percent = $percent * 100
        if ($TextFiles.Count -gt 1) 
        {
            Write-Progress -Activity 'Importing object file...' -CurrentOperation $TextFile -PercentComplete $percent -SecondsRemaining $remtime
        }
        #Write-Debug $Command

        $params = "Command=ImportObjects`,File=`"$TextFile`"`,ServerName=$Server`,Database=`"$Database`"`,LogFile=`"$LogFile`"`,importaction=`"overwrite`""
        & $NavIde $params | Write-Output
        #cmd /c $importfinsqlcommand

        if (Test-Path -Path "$LogFolder\navcommandresult.txt")
        {
            Write-Verbose -Message "Processed $TextFile ."
            Remove-Item -Path "$LogFolder\navcommandresult.txt"
        }
        else
        {
            Write-Error -Message "Crashed when importing $TextFile !"
        }

        If (Test-Path -Path "$LogFile") 
        {
            $logcontent = Get-Content -Path $LogFile 
            #if ($logcontent.Count -gt 1) {
            #    $ErrorText=$logcontent
            #} else {
            #    $ErrorText=$logcontent
            #}
            Write-Error -Message "Error when importing $TextFile : $logcontent"
        }
    }
}

function Compile-NAVApplicationObjectFiles
{
    [CmdletBinding()]
    Param(
        [String]$files,
        [String]$Server,
        [String]$Database,
        [String]$LogFolder,
        [String]$NavIde = '',
        [String]$ClientFolder = ''

    )
    if ($NavIde -eq '') 
    {
        $NavIde = $sourceclientfolder+'\finsql.exe'
    }

    #$finsqlparams = "command=importobjects,servername=$Server,database=$Database,file="

    $TextFiles = Get-ChildItem -Path "$files"
    $i = 0

    $FilesProperty = Get-NAVApplicationObjectProperty -Source $files
    $StartTime = Get-Date
    foreach ($FileProperty in $FilesProperty)
    {
        $NowTime = Get-Date
        $TimeSpan = New-TimeSpan $StartTime $NowTime
        #$Command = $importfinsqlcommand + $TextFile
        $LogFile = "$LogFolder\$($FileProperty.FileName.Basename).log"
        $i = $i+1
        $percent = $i / $FilesProperty.Count
        $remtime = $TimeSpan.TotalSeconds / $percent * (1-$percent)
        $percent = $percent * 100
        if ($FilesProperty.Count -gt 1) 
        {
            Write-Progress -Activity 'Compiling object file...' -CurrentOperation $FileProperty.FileName -PercentComplete $percent -SecondsRemaining $remtime
        }
        #Write-Debug $Command

        $Type = $FileProperty.ObjectType
        $Id = $FileProperty.Id
        $Filter = "Type=$Type;Id=$Id"
        $params = "Command=CompileObjects`,Filter=`"$Filter`"`,ServerName=$Server`,Database=`"$Database`"`,LogFile=`"$LogFile`""
        & $NavIde $params | Write-Output
        #cmd /c $importfinsqlcommand

        if (Test-Path -Path "$LogFolder\navcommandresult.txt")
        {
            Write-Verbose -Message "Processed $($FileProperty.FileName) ."
            Remove-Item -Path "$LogFolder\navcommandresult.txt"
        }
        else
        {
            Write-Error -Message "Crashed when compiling $($FileProperty.FileName) !"
        }

        If (Test-Path -Path "$LogFile") 
        {
            $logcontent = Get-Content -Path $LogFile 
            if ($logcontent.Count -gt 1) 
            {
                $errortext = $logcontent[0]
            }
            else 
            {
                $errortext = $logcontent
            }
            Write-Error -Message "Error when compiling $($FileProperty.FileName): $errortext"
        }
    }
}

function Compile-NAVApplicationObjectFilesMulti
{
    [CmdletBinding()]
    Param(
        [String]$files,
        [String]$Server,
        [String]$Database,
        [String]$LogFolder,
        [String]$NavIde = '',
        [String]$ClientFolder = '',
        [switch]$AsJob
    )
    
    $CPUs = (Get-WmiObject -Class Win32_Processor -Property 'NumberOfLogicalProcessors' | Select-Object -Property 'NumberOfLogicalProcessors').NumberOfLogicalProcessors
    if ($NavIde -eq '') 
    {
        $NavIde = $sourceclientfolder+'\finsql.exe'
    }

    #$finsqlparams = "command=importobjects,servername=$Server,database=$Database,file="

    $TextFiles = Get-ChildItem -Path "$files"
    $i = 0
    $jobs = @()

    $FilesProperty = Get-NAVApplicationObjectProperty -Source $files
    $FilesSorted = $FilesProperty | Sort-Object -Property Id
    $CountOfObjects = $FilesProperty.Count
    $Ranges = @()
    $Step = $CountOfObjects/$CPUs
    $Last = 0
    for ($i = 0;$i -lt $CPUs;$i++) 
    {
        $Ranges += "$($Last+1)..$($FilesSorted[$i*$Step+$Step-1].Id)"
        $Last = $FilesSorted[$i*$Step+$Step-1].Id
    }

    Write-Host -Object "Ranges: $Ranges"

    $StartTime = Get-Date
    #foreach ($FileProperty in $FilesProperty){
    foreach ($Range in $Ranges) 
    {
        $LogFile = "$LogFolder\$Range.log"
        $Filter = "Id=$Range"
        if ($AsJob -eq $true) 
        {
            Write-Host -Object "Compiling $Filter as Job..."
            $jobs += Compile-NAVApplicationObject2 -DatabaseName $Database -DatabaseServer $Server -LogPath $LogFile -Filter $Filter -Recompile -AsJob
        }
        else 
        {
            Write-Host -Object "Compiling $Filter..."
            Compile-NAVApplicationObject2 -DatabaseName $Database -DatabaseServer $Server -LogPath $LogFile -Filter $Filter -Recompile
        }
    }
    if ($AsJob -eq $true) 
    {
        Receive-Job -Job $jobs -Wait
    }
}

function Compile-NAVApplicationObject
{
    Param(
        [Parameter(Mandatory = $true,ValueFromPipelinebyPropertyName = $true)]
        [String]$Filter,
        [Parameter(Mandatory = $true,ValueFromPipelinebyPropertyName = $true)]
        [String]$Server,
        [Parameter(Mandatory = $true,ValueFromPipelinebyPropertyName = $true)]
        [String]$Database,
        [Parameter(ValueFromPipelinebyPropertyName = $true)]
        [String]$LogFolder,
        [Parameter(ValueFromPipelinebyPropertyName = $true)]
        [String]$NavIde = '',
        [Parameter(ValueFromPipelinebyPropertyName = $true)]
        [String]$ClientFolder = ''

    )
    if ($NavIde -eq '') 
    {
        $NavIde = Get-NAVIde
    }

    #$finsqlparams = "command=importobjects,servername=$Server,database=$Database,file="

    $LogFile = "$LogFolder\filtercompile.log"
    Write-Progress -Activity 'Compiling objects...' 
    #Write-Debug $Command
    $params = "Command=CompileObjects`,Filter=`"$Filter`"`,ServerName=$Server`,Database=`"$Database`"`,LogFile=`"$LogFile`""
    & $NavIde $params | Write-Output

    if (Test-Path -Path "$LogFolder\navcommandresult.txt")
    {
        Write-Verbose -Message "Processed $Filter."
        Remove-Item -Path "$LogFolder\navcommandresult.txt"
    }
    else
    {
        Write-Error -Message "Crashed when compiling $Filter !"
    }

    If (Test-Path -Path "$LogFile") 
    {
        $logcontent = Get-Content -Path $LogFile 
        #if ($logcontent.Count -gt 1) {
        #    $errortext=$logcontent[0]
        #} else {
        #    $errortext=$logcontent
        #}
        Write-Error -Message "Error when compiling $Filter : $logcontent"
    }
}

function Export-NAVApplicationObject
{
    Param(
        [Parameter(Mandatory = $true,ValueFromPipelinebyPropertyName = $true)]
        [String]$Filter,
        [Parameter(Mandatory = $true,ValueFromPipelinebyPropertyName = $true)]
        [String]$Server,
        [Parameter(Mandatory = $true,ValueFromPipelinebyPropertyName = $true)]
        [String]$Database,
        [Parameter(Mandatory = $true,ValueFromPipelinebyPropertyName = $true)]
        [String]$LogFolder,
        [Parameter(ValueFromPipelinebyPropertyName = $true)]
        [String]$path,
        [Parameter(ValueFromPipelinebyPropertyName = $true)]
        [String]$NavIde = '',
        [Parameter(ValueFromPipelinebyPropertyName = $true)]
        [String]$ClientFolder = ''

    )
    if ($NavIde -eq '') 
    {
        $NavIde = $sourceclientfolder+'\finsql.exe'
    }

    #Write-Progress -Activity 'Exporting objects...' 
    #Write-Debug $Command
    $LogFile = (Join-Path -Path $LogFolder -ChildPath naverrorlog.txt)

    $params = "Command=ExportObjects`,Filter=`"$Filter`"`,ServerName=$Server`,Database=`"$Database`"`,LogFile=`"$LogFile`"`,File=`"$path`""
    & $NavIde $params | Write-Output

    if (Test-Path -Path "$LogFolder\navcommandresult.txt")
    {
        Write-Verbose -Message "Processed $Filter to $path."
        Remove-Item -Path "$LogFolder\navcommandresult.txt"
    }
    else
    {
        Write-Error -Message "Crashed when exportin $Filter into $path!"
    }

    If (Test-Path -Path "$LogFile") 
    {
        $logcontent = Get-Content -Path $LogFile 
        if ($logcontent.Count -gt 1) 
        {
            $errortext = $logcontent[0]
        }
        else 
        {
            $errortext = $logcontent
        }
        Write-Error -Message "Error when Exporting $Filter to $path : $errortext"
    }
}


function Merge-NAVDatabaseObjects
{
    param
    (
        [String]
        $sourceserver,

        [String]
        $sourcedb,

        [String]
        $sourcefilefolder,

        [String]
        $sourceclientfolder,

        [String]
        $modifiedserver,

        [String]
        $modifieddb,

        [String]
        $modifiedfilefolder,

        [String]
        $modifiedclientfolder,

        [String]
        $targetserver,

        [String]
        $targetdb,

        [String]
        $targetfilefolder,

        [String]
        $targetclientfolder,

        [String]
        $commonversionsource,

        [String]
        $newversion
    )

    Write-Host -Object 'Clearing target folder...'
    ClearFolder($targetfilefolder)

    if ($sourceserver) 
    {
        Get-NAVDatabaseObjects -sourceserver $sourceserver -sourcedb $sourcedb -sourcefilefolder $sourcefilefolder -sourceclientfolder $sourceclientfolder
    }

    if ($modifiedserver) 
    {
        Get-NAVDatabaseObjects -sourceserver $modifiedserver -sourcedb $modifieddb -sourcefilefolder $modifiedfilefolder -sourceclientfolder $modifiedclientfolder
    }

    $modifiedwithflag = Get-NAVModifiedObject -Source $modifiedfilefolder
    Write-Host -Object 'Merging Objects...'

    #<#
    $mergeresult = Merge-NAVApplicationObject -OriginalPath $commonversionsource -Modified $sourcefilefolder -TargetPath $modifiedfilefolder -ResultPath $targetfilefolder -PassThru -Force -DateTimeProperty FromTarget
    $merged = $mergeresult | Where-Object -FilterScript {
        $_.MergeResult -eq 'Merged'
    }
    Write-Host 'Merged:    '$merged.Count
    $inserted = $mergeresult | Where-Object -FilterScript {
        $_.MergeResult -eq 'Inserted'
    }
    Write-Host 'Inserted:  '$inserted.Count
    $deleted = $mergeresult | Where-Object -FilterScript {
        $_.MergeResult -EQ 'Deleted'
    }
    Write-Host 'Deleted:   '$deleted.Count
    $conflicts = $mergeresult | Where-Object -FilterScript {
        $_.MergeResult -EQ 'Conflict'
    }
    $identical = $mergeresult | Where-Object -FilterScript {
        $_.MergeResult -eq 'Identical'
    }

    Write-Host 'Conflicts: '$conflicts.Count
    Write-Host -Object ''
    Write-Host -Object 'Merging version list on merged files...'
    foreach ($merge in $merged) 
    {
        $merge |Format-Table
        if ($merge.Result.Filename -gt '') 
        {
            $file = Get-ChildItem -Path $merge.Result
            $filename = $file.Name
            Merge-NAVObjectVersionList -modifiedfilename $sourcefilefolder'\'$filename -targetfilename $modifiedfilefolder'\'$filename -resultfilename $merge.Result.FileName -newversion $newversion
        }
    }

    if ($deleted.Count -gt 0) 
    {
        Write-Host -Object '********Delete these objects in target DB:'
        foreach ($delobject in $deleted) 
        {
            Write-Host $delobject.ObjectType $delobject.Id
            #Set-NAVApplicationObjectProperty -Target $delobject.Result -VersionListProperty 'DELETE'
        }
    }
    #>
    Write-Host -Object 'Deleting Identical objects...'
    Remove-Item -Path $identical.Result
    Write-Host -Object 'Restoring Modfied flags...'
    $modifiedwithflag | Set-NAVModifiedObject -path $targetfilefolder
    Write-Host -Object 'Joining Objects...'
    $joinresult = Join-NAVApplicationObjectFile -Source $targetfilefolder -Destination $targetfilefolder'.txt' -Force
    #>
    if ($targetserver) 
    {
        Write-Host -Object 'Importing Objects...'
        Import-NAVApplicationObject2 -Path $targetfilefolder'.txt' -DatabaseServer $targetserver -DatabaseName $targetdb -Confirm
        Write-Host -Object 'Compiling Objects...'
        $compileoutput = Compile-NAVApplicationObject2 -DatabaseServer $targetserver -DatabaseName $targetdb -Recompile
    }
    #return $mergeresult
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
Function Remove-NAVLocalApplication
{
    param (
        #SQL Server address
        [Parameter(Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
        [String]$Server,

        #SQL Database to update
        [Parameter(Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
        [String]$Database,

        #Service Instance name to create
        [Parameter(Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
        [string] $ServerInstance
    )

    Write-Progress -Activity 'Remove NAV Application' -CurrentOperation "Removing server instance $ServerInstance..." -PercentComplete 50
    Stop-Service -Name ("MicrosoftDynamicsNavServer`$$ServerInstance") -Force
    Remove-NAVServerInstance -ServerInstance $ServerInstance -Force
    Write-Verbose -Message "Server instance $ServerInstance removed"

    Write-Progress -Activity 'Remove NAV Application' -CurrentOperation "Removing SQL DB $Database on server $Server ..." -PercentComplete 90
    Remove-SQLDatabase -Server $Server -Database $Database
    Write-Verbose -Message "SQL Database $Dataase on $Server removed"

    Write-Progress -Activity 'Remove NAV Application' -Completed
}

function Set-ServicePortSharing
{
    param (
        [String]$Name
    )
    #Enable and start Port Sharing
    Get-Service -Name NetTcpPortSharing | Set-Service -StartupType Manual -Status Running
    #turn on Port Sharing on the new service
    sc.exe config "$Name" depend= NetTcpPortSharing/HTTP > null
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
Function New-NAVLocalApplication
{
    [CmdletBinding()]
    param (
        #SQL Server address
        [Parameter(Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
        [String]$Server,

        #SQL Database to update
        [Parameter(Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
        [String]$Database,

        #FOB files imported before the txt files are imported. Could update the objects stored in the DB Backup file to newer version.
        [Parameter(Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
        [string] $BaseFob,

        #FLF file used to start the NAV Service tier. Must have enough permissions to import the txt files.
        [Parameter(Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
        [string] $LicenseFile,

        #File of the NAV SQL backup for creating new NAV database. Used as base for importing the objects.
        [Parameter(Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
        [string] $DbBackupFile,

        #Service Instance name to create
        [Parameter(Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
        [string] $ServerInstance,

        #Path to place DB files
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string] $TargetPath
    )
    Import-NAVAdminTool
    
    Write-Progress -Activity "Creating new database $Database on $Server..."
    Write-Host -Object "Creating new database $Database on $Server..."
        
    if ($TargetPath) 
    {
        $null = New-NAVDatabase -DatabaseName $Database -FilePath $DbBackupFile -DatabaseServer $Server -Force -DataFilesDestinationPath ( [IO.Path]::Combine($TargetPath,($Database+'.mdf'))) -LogFilesDestinationPath ( [IO.Path]::Combine($TargetPath,($Database+'.ldf'))) -ErrorAction Stop
    }
    else 
    {
        $null = New-NAVDatabase -DatabaseName $Database -FilePath $DbBackupFile -DatabaseServer $Server -Force -ErrorAction Stop
    }
    
    Write-Verbose -Message 'Database Restored'

    Write-Progress -Activity 'Creating new server instance $ServerInstance...'
    Write-Host -Object "Creating new server instance $ServerInstance..."
    $null = New-NAVServerInstance -DatabaseServer $Server -DatabaseName $Database -ServerInstance $ServerInstance -ManagementServicesPort 7045 -DatabaseInstance ''
    
    Set-ServicePortSharing -Name $("MicrosoftDynamicsNavServer`$$ServerInstance")

    Start-Service -Name ("MicrosoftDynamicsNavServer`$$ServerInstance")
    Write-Verbose -Message 'Server instance created'

    Write-Progress -Activity 'Importing License $LicenseFile...'
    Import-NAVServerLicense -LicenseFile $LicenseFile -Database NavDatabase -ServerInstance $ServerInstance -WarningAction SilentlyContinue 
    Write-Verbose -Message 'License imported'

    Stop-Service -Name ("MicrosoftDynamicsNavServer`$$ServerInstance")
    Start-Service -Name ("MicrosoftDynamicsNavServer`$$ServerInstance")
    Write-Verbose -Message 'Server instance restarted'

    Sync-NAVTenant -ServerInstance $ServerInstance -Force

    if ($BaseFob -gt '') 
    {
        $BaseFobs = $BaseFob.Split(';')
        foreach ($fob in $BaseFobs) 
        {
            if ($fob -gt '') 
            {
                Write-Progress -Activity "Importing FOB File $fob..."
                Import-NAVApplicationObjectFiles -files $fob -Server $Server -Database $Database -LogFolder (Join-Path $env:TEMP 'NVR_NAVScripts')
                Write-Host -Message 'FOB Objects from %fob imported'
            }
        }
    }
    Sync-NAVTenant -ServerInstance $ServerInstance -Force
}
$client = Split-Path (Get-NAVIde)
$NavIde = Get-NAVIde

#$result=Merge-NAVDatabaseObjects -sourceserver devel -sourcedb NVR2013R2_CSY -sourcefilefolder source -sourceclientfolder $client `
#-modifiedserver devel -modifieddb Adast2013 -modifiedfilefolder modified -modifiedclientfolder $client `
#-targetserver devel -targetdb Adast2013 -targetfilefolder target -targetclientfolder $client -commonversionsource common

#Get-NAVDatabaseObjects -sourceserver devel -sourcedb NVR2013R2_CSY -sourcefilefolder d:\ksacek\TFS\Realizace\NAV\NAV2013R2\CSY_NVR_Essentials\ -sourceclientfolder $client
Export-ModuleMember -Function Merge-NAVVersionListString
Export-ModuleMember -Function Merge-NAVObjectVersionList
Export-ModuleMember -Function Merge-NAVDatabaseObjects
Export-ModuleMember -Function Get-NAVDatabaseObjects
Export-ModuleMember -Function Import-NAVApplicationObjectFiles
Export-ModuleMember -Function Compile-NAVApplicationObjectFiles
Export-ModuleMember -Function Compile-NAVApplicationObjectFilesMulti
Export-ModuleMember -Function Compile-NAVApplicationObject
Export-ModuleMember -Function Export-NAVApplicationObject
Export-ModuleMember -Function New-NAVLocalApplication
Export-ModuleMember -Function Remove-NAVLocalApplication
Export-ModuleMember -Function Set-ServicePortSharing
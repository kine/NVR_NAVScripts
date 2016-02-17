#import-module -Name Microsoft.Dynamics.Nav.Ide -Verbose
#. "Merge-NAVVersionListString script.ps1"

#Import-Module 'c:\Program Files (x86)\Microsoft Dynamics NAV\71\RoleTailored Client\Microsoft.Dynamics.Nav.Model.Tools.psd1' -WarningAction SilentlyContinue | Out-Null
#Import-NAVAdminTool
#Import-NAVModelTool

Get-Item $PSScriptRoot  | Get-ChildItem -Recurse -file -Filter '*.ps1' |  Sort Name | foreach {
    Write-Verbose "Loading $($_.Name)"  
    . $_.fullname
}

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
    if ($result -notlike "*$($newmoduleinfo.shortcut)*") {
        $result = $result + ',' + $newversion
    }
    $result = $result.TrimStart(',')
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
            Convert-NAVLogFileToErrors -LogFile $LogFile
        }
    }
}

function Compile-NAVApplicationObjectFilesMulti
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true,ValueFromPipelinebyPropertyName = $true)]
        [String]$files,
        [Parameter(Mandatory = $true,ValueFromPipelinebyPropertyName = $true)]
        [String]$Server,
        [Parameter(Mandatory = $true,ValueFromPipelinebyPropertyName = $true)]
        [String]$Database,
        [Parameter(ValueFromPipelinebyPropertyName = $true)]
        [String]$NavIde = '',
        [Parameter(ValueFromPipelinebyPropertyName = $true)]
        [switch]$AsJob,
        # Specifies the schema synchronization behaviour. The default value is 'Yes'.
        [Parameter(ValueFromPipelinebyPropertyName = $true)]
        [ValidateSet('Yes','No','Force')]
        [string] $SynchronizeSchemaChanges = 'Yes',
        [Parameter(ValueFromPipelinebyPropertyName = $true)]
        [String]$NavServerName='',
        [Parameter(ValueFromPipelinebyPropertyName = $true)]
        [String]$NavServerInstance=''
            )
    
    $CPUs = (Get-WmiObject -Class Win32_Processor -Property 'NumberOfLogicalProcessors' | Select-Object -Property 'NumberOfLogicalProcessors').NumberOfLogicalProcessors
    if ($NavIde -eq '') 
    {
        $NavIde = Get-NAVIde
    }

    #$finsqlparams = "command=importobjects,servername=$Server,database=$Database,file="

    $TextFiles = Get-ChildItem -Path "$files"
    $i = 0
    $jobs = @()

    $FilesProperty = Get-NAVApplicationObjectProperty -Source $files
    $FilesSorted = $FilesProperty | Where-Object {$_.ObjectType -ne 'Table'} | Sort-Object -Property Id
    $CountOfObjects = $FilesProperty.Count
    $Ranges = @()
    $Step = $CountOfObjects/($CPUs-1)
    $Last = 0
    #Adding one CPU for compilation of tables (preventing deadlocks?)
    $Ranges += '0..2000000999;Type=Table'
    for ($i = 0;$i -lt ($CPUs-1);$i++) 
    {
        $Ranges += "$($Last+1)..$($FilesSorted[$i*$Step+$Step-1].Id);Type=2.."
        $Last = $FilesSorted[$i*$Step+$Step-1].Id
    }

    Write-Host -Object "Ranges: $Ranges"

    $StartTime = Get-Date
    #foreach ($FileProperty in $FilesProperty){
    foreach ($Range in $Ranges) 
    {
        $Filter = "Id=$Range"
        if ($AsJob -eq $true) 
        {
            Write-Host -Object "Compiling $Filter as Job..."
            $jobs += Compile-NAVApplicationObject2 -DatabaseName $Database -DatabaseServer $Server -Filter $Filter -Recompile -AsJob -SynchronizeSchemaChanges $SynchronizeSchemaChanges -NavServerName $NavServerName -NavServerInstance $NavServerInstance
        }
        else 
        {
            Write-Host -Object "Compiling $Filter..."
            Compile-NAVApplicationObject2 -DatabaseName $Database -DatabaseServer $Server -Filter $Filter -Recompile -SynchronizeSchemaChanges $SynchronizeSchemaChanges -NavServerName $NavServerName -NavServerInstance $NavServerInstance
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
    #Write-Progress -Activity 'Compiling objects...' 
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
        Convert-NAVLogFileToErrors -LogFile $LogFile
    }
}

function Compile-NAVApplicationObjectMulti
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
        [String]$ClientFolder = '',
        [Parameter(ValueFromPipelinebyPropertyName = $true)]
        [Switch]$AsJob,
        # Specifies the schema synchronization behaviour. The default value is 'Yes'.
        [ValidateSet('Yes','No','Force')]
        [string] $SynchronizeSchemaChanges = 'Yes',
        [int]$ParallelismLimit = 5,
        [Parameter(ValueFromPipelinebyPropertyName = $true)]
        [String]$NavServerName='',
        [Parameter(ValueFromPipelinebyPropertyName = $true)]
        [String]$NavServerInstance=''
            )
    
    $CPUs = (Get-WmiObject -Class Win32_Processor -Property 'NumberOfLogicalProcessors' | Select-Object -Property 'NumberOfLogicalProcessors').NumberOfLogicalProcessors
    if ($NavIde -eq '') 
    {
        $NavIde = Get-NAVIde
    }

    #$finsqlparams = "command=importobjects,servername=$Server,database=$Database,file="

    $i = 0
    $jobs = @()

    $ObjectProperty = Get-SQLCommandResult -Server $Server -Database $Database -Command "Select Type,ID from Object where Type > '1' order by ID"
    $CountOfObjects = $ObjectProperty.Count
    $Ranges = @()
    $Step = $CountOfObjects/($CPUs-1)
    
    if ($Step -lt $ParallelismLimit) 
    {
        $CPUs = $CountOfObjects / $ParallelismLimit   
        $Step = $CountOfObjects/($CPUs-1)
    }
    
    $Last = 0
    #Adding one CPU for compilation of tables (preventing deadlocks?)
    $Ranges += '0..2000000999;Type=Table'
    
    for ($i = 0;$i -lt ($CPUs-1);$i++) 
    {
        $Ranges += "$($Last+1)..$($ObjectProperty[$i*$Step+$Step-1].ID);Type=2.."
        $Last = $ObjectProperty[$i*$Step+$Step-1].ID
    }

    Write-Host -Object "Ranges: $Ranges"

    $StartTime = Get-Date
    #foreach ($FileProperty in $FilesProperty){
    foreach ($Range in $Ranges) 
    {
        $LogFile = "$LogFolder\$($Range -replace '\W','_').log"
        $Filter = "ID=$Range"
        if ($AsJob -eq $true) 
        {
            Write-Host -Object "Compiling $Filter as Job..."
            $jobs += Compile-NAVApplicationObject2 -DatabaseName $Database -DatabaseServer $Server -LogPath $LogFile -Filter $Filter -Recompile -AsJob -SynchronizeSchemaChanges $SynchronizeSchemaChanges -NavServerName $NavServerName -NavServerInstance $NavServerInstance
        }
        else 
        {
            Write-Host -Object "Compiling $Filter..."
            Compile-NAVApplicationObject2 -DatabaseName $Database -DatabaseServer $Server -LogPath $LogFile -Filter $Filter -Recompile -SynchronizeSchemaChanges $SynchronizeSchemaChanges -NavServerName $NavServerName -NavServerInstance $NavServerInstance
        }
    }
    if ($AsJob -eq $true) 
    {
        Receive-Job -Job $jobs -Wait
    }
}

function Convert-NAVLogFileToErrors
{
    Param(
        $LogFile
    )
    $lines = Get-Content $LogFile
    $message = ''
    foreach ($line in $lines) 
    {
        if ($line -match '\[.+\].+') 
        {
            if ($message) 
            {
                Write-Error $message
            }
            $message = ''
        }
        if ($message) 
        {
            $message += "`r`n"
        }
        $message += ($line)
    }
    if ($message) 
    {
        Write-Error $message
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
        [String]$ClientFolder = '',
        #Name of the NAV Server
        [Parameter(ValueFromPipelinebyPropertyName = $true)]
        [String]$NavServerName,
        #Name of the NAV Server Instance
        [Parameter(ValueFromPipelinebyPropertyName = $true)]
        [String]$NavServerInstance
        

    )
    if ($NavIde -eq '') 
    {
        $NavIde = $sourceclientfolder+'\finsql.exe'
    }

    #Write-Progress -Activity 'Exporting objects...' 
    #Write-Debug $Command
    $LogFile = (Join-Path -Path $LogFolder -ChildPath naverrorlog.txt)

    $params = "Command=ExportObjects`,Filter=`"$Filter`"`,ServerName=$Server`,Database=`"$Database`"`,LogFile=`"$LogFile`"`,File=`"$path`""
    if ($NavServerName -gt '') {
      $params = $params+@"
`,NavServerName="$NavServerName"`,NavServerInstance="$NavServerInstance"`"
"@
    }
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
    sc.exe config "$Name" depend= NetTcpPortSharing/HTTP | Out-Null
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
        [string] $TargetPath,
        
        [Parameter(ValueFromPipelineByPropertyName = $true,Alias)]
        [Alias('NAVVersion')]
        [string] $Version=''        
    )
    Test-Administrator
    
    Write-Host -Object 'Importing NAVAdminTool...'
    Write-Host -Object "NavServicePath $($env:NavServicePath)"
    Import-NAVAdminTool
    Write-Progress -Activity "Creating new database $Database on $Server..."
    Write-Host -Object "Creating new database $Database on $Server..."
        
    if ($TargetPath) 
    {
        $backupinfo = Get-SQLCommandResult -Server $Server -Database master -Command "RESTORE FILELISTONLY FROM DISK = `'$DbBackupFile`' WITH FILE = 1" -ForceDataset
        if ($backupinfo.Count -gt 2)
        {
            Write-Host -Object "Trying to restore under folder $TargetPath..."
            $null = New-NAVDatabase -DatabaseName $Database -FilePath $DbBackupFile -DatabaseServer $Server -Force -DataFilesDestinationPath $TargetPath -LogFilesDestinationPath $TargetPath -ErrorAction Stop
        }
        else 
        {
            Write-Host -Object "Trying to restore under new file names in folder $TargetPath..."
            $null = New-NAVDatabase -DatabaseName $Database -FilePath $DbBackupFile -DatabaseServer $Server -Force -DataFilesDestinationPath ( [IO.Path]::Combine($TargetPath,($Database+'.mdf'))) -LogFilesDestinationPath ( [IO.Path]::Combine($TargetPath,($Database+'.ldf'))) 
        }
    }
    else 
    {
        $null = New-NAVDatabase -DatabaseName $Database -FilePath $DbBackupFile -DatabaseServer $Server -Force -ErrorAction Stop
    }
    
    Write-Verbose -Message 'Database Restored'

    Write-Progress -Activity 'Creating new server instance $ServerInstance...'
    
    Write-Host 'Converting database...'
    Invoke-NAVDatabaseConversion2 -DatabaseName $Database -DatabaseServer $Server
    
    Write-Host -Object "Creating new server instance $ServerInstance..."
    $null = New-NAVServerInstance -DatabaseServer $Server -DatabaseName $Database -ServerInstance $ServerInstance -ManagementServicesPort 7045 -DatabaseInstance ''
    
    Set-ServicePortSharing -Name $("MicrosoftDynamicsNavServer`$$ServerInstance")
    
    Set-NAVServerConfiguration -ServerInstance $ServerInstance -KeyName 'ClientServicesEnabled' -KeyValue 'true'

    if ($Version -gt '') {
        Write-Host -Object 'Updating version of the service...'
        Update-NAVServiceVersion -ServerInstance $ServerInstance -Version $Version
    }

    Write-Verbose -Message 'Server instance created'
    Start-Service -Name ("MicrosoftDynamicsNavServer`$$ServerInstance") -ErrorAction Stop
        
    Write-Progress -Activity 'Importing License $LicenseFile...'
    Import-NAVServerLicense -LicenseFile $LicenseFile -Database NavDatabase -ServerInstance $ServerInstance -WarningAction SilentlyContinue -ErrorAction Stop
    Write-Verbose -Message 'License imported'
        
   
    
    Stop-Service -Name ("MicrosoftDynamicsNavServer`$$ServerInstance")
    Start-Service -Name ("MicrosoftDynamicsNavServer`$$ServerInstance") -ErrorAction Stop
    Write-Verbose -Message 'Server instance restarted'
    
    Write-Host -Object 'Adding current user as SUPER'
    New-NAVServerUser -WindowsAccount "$($env:USERDOMAIN)\$($env:USERNAME)" -ServerInstance $ServerInstance  
    New-NAVServerUserPermissionSet -WindowsAccount "$($env:USERDOMAIN)\$($env:USERNAME)" -ServerInstance $ServerInstance -PermissionSetId 'SUPER'
    
    #Sync-NAVTenant -ServerInstance $ServerInstance -Force

    if ($BaseFob -gt '') 
    {
        $BaseFobs = $BaseFob.Split(';')
        foreach ($fob in $BaseFobs) 
        {
            if ($fob -gt '') 
            {
                Write-Progress -Activity "Importing FOB File $fob..."
                Import-NAVApplicationObject2 -Path $fob -DatabaseServer $Server -DatabaseName $Database -LogPath (Join-Path -Path $env:TEMP -ChildPath 'NVR_NAVScripts') -ImportAction Overwrite -SynchronizeSchemaChanges Force
                Write-Host -Object "FOB Objects from $fob imported"
            }
        }
    }
    #Sync-NAVTenant -ServerInstance $ServerInstance -Force
}

<#
        .Synopsis
        Get list of changed files between two commits
        .DESCRIPTION
        Get list of changed files between two commits
        .EXAMPLE
        Example of how to use this cmdlet
        .EXAMPLE
        Another example of how to use this cmdlet
#>
function Get-GITModifiedFile
{
    [CmdletBinding()]
    Param
    (
        # GIT Repository path
        [Parameter(Mandatory = $false,
                ValueFromPipelineByPropertyName = $true,
        Position = 0)]
        $Repository='.',

        # From commit
        [String]
        $FromCommit='HEAD',
        # To commit
        [String]
        $ToCommit='HEAD~1'
    )
    Push-Location
    Set-Location -Path $Repository
    $list = (git.exe diff --name-only "$FromCommit" "$ToCommit")
    Pop-Location
    return $list
}

<#
        .Synopsis
        Try to find specified version of NAV in folders on same level as passed default path
        .DESCRIPTION
        Return folder name for selected NAV version. If not found, return the passed default path
        .EXAMPLE
        Find-NAVVersion 'C:\Program Files (x86)\Microsoft Dynamics NAV\80\RoleTailored Client' '8.0.40262.0'
        .EXAMPLE
        Find-NAVVersion 'C:\Program Files\Microsoft Dynamics NAV\80\Service' '8.0.40262.0'
#>

function Find-NAVVersion
{
    param
    (
        #Default path, where to start the search
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true, HelpMessage = 'Default path, where to start the search')]
        $path,
        #Version which we are looking for
        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true, HelpMessage = 'Version which we are looking for')]
        $Version
    )
    if (!($Version)) {
        return $path
    }
    
    if (Test-Path -Path (Join-Path -Path $path -ChildPath 'Microsoft.Dynamics.Nav.Server.exe')) 
    {
        $searchfile = 'Microsoft.Dynamics.Nav.Server.exe'
    }
    if (Test-Path -Path (Join-Path -Path $path -ChildPath 'finsql.exe')) 
    {
        $searchfile = 'finsql.exe'
    } 
    $result = Split-Path $path |
    Get-ChildItem -Filter $searchfile -Recurse |
    Where-Object -FilterScript {
        $_.VersionInfo.FileVersion -eq $Version
    } 
    if ($result) 
    {
        if ($result.Count -gt 1) {
            return $result[0].DirectoryName
        }
        return $result.DirectoryName
    }
    return $path
}

Function Set-NAVUIDOffset
{
    param (
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="SQL Server")]
        [String]$Server,
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="SQL Database")]
        [String]$Database,
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, HelpMessage="ID Offset to set")]
        [int]$UIDOffset
    )
    Get-SQLCommandResult -Server $Server -Database $Database -Command "UPDATE [`$ndo`$dbproperty] SET [uidoffset] = $UIDOffset" | Out-Null
}

<#
        .Synopsis
        Change version on existing NAV Server Instance
        .DESCRIPTION
        Change version on Existing NAV Server Instance by moving the config to new folder and setting the service to new .exe file
        .EXAMPLE
        Update-NAVServiceVersion -Name MicrosoftDynamicsNavServer$ServerInstance -TargetPath "C:\Program Files\Microsoft Dynamics NAV\80\Service_42222"
#>
function Update-NAVServiceVersion
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true, HelpMessage = 'Name of the service to upgrade')]
        $Name,
        [Parameter(Mandatory = $true, Position = 1, HelpMessage = 'Path to the target service folder')]
        $TargetFolder
    )

    begin {
    }
    process {
        $service = Get-Service $Name
        Write-Host "$($Service.DisplayName)"
        if ($service.Status -eq 'Running') {
            $service.Stop()
        }
        
        #Update registry - path to the exe file and config file
        $currentPath = (Get-ItemProperty -Path ('HKLM:\System\CurrentControlSet\Services\'+$service.Name) -Name ImagePath).ImagePath
        $originalPath = (Split-Path $currentPath.Split('$')[0]).Replace('"','')
        $newPath = $currentPath.Replace($originalPath,$TargetFolder)
        Set-ItemProperty -Path ('HKLM:\System\CurrentControlSet\Services\'+$service.Name) -Name ImagePath -Value $newPath
        
        #move config files to new folder
        Move-Item -Path "$originalPath\Instances\$($Name.Split('$')[1])" -Destination "$TargetFolder\Instances\"


        $option=[System.StringSplitOptions]::RemoveEmptyEntries
        $separator = " config ","DUMMY"
        $configFile = $newPath.Split($separator,$option)[1].Replace('"','')
        
        #modify content of the config file
        $config = [xml](Get-Content $configFile)
        $config.configuration.appSettings.file = $config.configuration.appSettings.file.Replace($originalPath,$TargetFolder)
        $config.configuration.tenants.file = $config.configuration.tenants.file.Replace($originalPath,$TargetFolder)
        $config.Save($configFile)
        
        Write-Host "Service $($Service.Name) moved from $originaPath to $TargetPath"
    }
    end{
    }
}

function Upgrade-NAVServerInstance
{
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true, HelpMessage = 'Name of the service to upgrade')]
        $Name,
        [Parameter(Mandatory = $true, Position = 1, HelpMessage = 'Path to the target service folder')]
        $TargetFolder
    )

    begin {
    }
    process {
        $service = Get-Service $Name
        Write-Host "$($Service.DisplayName)"
        if ($service.Status -eq 'Running') {
            $service.Stop()
        }
        $currentPath = (Get-ItemProperty -Path ('HKLM:\System\CurrentControlSet\Services\'+$service.Name) -Name ImagePath).ImagePath
        $originalPath = (Split-Path $currentPath.Split('$')[0]).Replace('"','')
        $newPath = $currentPath.Replace($originalPath,$TargetFolder)
        Set-ItemProperty -Path ('HKLM:\System\CurrentControlSet\Services\'+$service.Name) -Name ImagePath -Value $newPath
        Move-Item -Path "$originalPath\Instances\$($Name.Split('$')[1])" -Destination "$TargetFolder\Instances\"

        $option=[System.StringSplitOptions]::RemoveEmptyEntries
        $separator = " config ","DUMMY"
        $configFile = $newPath.Split($separator,$option)[1].Replace('"','')
        $config = [xml](Get-Content $configFile)
        $config.configuration.appSettings.file = $config.configuration.appSettings.file.Replace($originalPath,$TargetFolder)
        $config.configuration.tenants.file = $config.configuration.tenants.file.Replace($originalPath,$TargetFolder)
        $config.Save($configFile)
    }
    end{
    }
}

$client = Split-Path (Get-NAVIde)
$NavIde = Get-NAVIde

#$result=Merge-NAVDatabaseObjects -sourceserver devel -sourcedb NVR2013R2_CSY -sourcefilefolder source -sourceclientfolder $client `
#-modifiedserver devel -modifieddb Adast2013 -modifiedfilefolder modified -modifiedclientfolder $client `
#-targetserver devel -targetdb Adast2013 -targetfilefolder target -targetclientfolder $client -commonversionsource common

#Get-NAVDatabaseObjects -sourceserver devel -sourcedb NVR2013R2_CSY -sourcefilefolder d:\ksacek\TFS\Realizace\NAV\NAV2013R2\CSY_NVR_Essentials\ -sourceclientfolder $client
Export-ModuleMember -Function *-*

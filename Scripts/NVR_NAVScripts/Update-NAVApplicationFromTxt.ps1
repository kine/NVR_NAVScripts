function Set-NAVObjectAsDeleted
{
    <#
        .SYNOPSIS
        Short Description
        .DESCRIPTION
        Detailed Description
        .EXAMPLE
        Set-NAVObjectAsDeleted
        explains how to use the command
        can be multiple lines
        .EXAMPLE
        Set-NAVObjectAsDeleted
        another example
        can have as many examples as you like
    #>
    param
    (
        $Server,
        $Database,
        $NAVObjectType,
        $NAVObjectID
    )
    $Result = Get-SQLCommandResult -Server $Server -Database $Database -Command "select * from Object where [Type]=$($NAVObjectType) and [ID]=$($NAVObjectID)"
    if ($Result.Count -eq 0) {
        $command = ''+
        'insert into Object (Type,[Company Name],ID,Name,Modified,Compiled,[BLOB Reference],[BLOB Size],[DBM Table No_],Date,Time,[Version List],Locked,[Locked By])'+
        "VALUES($NAVObjectType,'',$NAVObjectID,'#DELETED $($NAVObjectType):$($NAVObjectID)',0,0,'',0,0,'1753-1-1 0:00:00','1754-1-1 12:00:00','#DELETE',0,'')"

        $Result = Get-SQLCommandResult -Server $Server -Database $Database -Command $command
    } else {
        $Result = Get-SQLCommandResult -Server $Server -Database $Database -Command "update Object set [Version List] = '#DELETE', [Name]='#DELETED $($NAVObjectType):$($NAVObjectID)', [Time]='1754-1-1 12:00:00' where [Type]=$($NAVObjectType) and [ID]=$($NAVObjectID)"
    }
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
function Update-NAVApplicationFromTxt
{
    [CmdletBinding()]
    param (
        #Object files from which to update. Should be complete set of objects
        [Parameter(Mandatory = $true,ValueFromPipelinebyPropertyName = $true)]
        [String]$Files,
        #SQL Server address
        [Parameter(Mandatory = $true,ValueFromPipelinebyPropertyName = $true)]
        [String]$Server,
        #SQL Database to update
        [Parameter(Mandatory = $true,ValueFromPipelinebyPropertyName = $true)]
        [String]$Database,
        #If set, all objects will be updated and compiled instead just different
        [Parameter(ValueFromPipelinebyPropertyName = $true)]
        [switch]$All,
        #If set, objects will be compiled after they are imported
        [Parameter(ValueFromPipelinebyPropertyName = $true)]
        [switch]$Compile,
        #If set, objects, which should be deleted, will be marked #TODELETE in version list
        [Parameter(ValueFromPipelinebyPropertyName = $true)]
        [switch]$MarkToDelete,
        #If set, script will not check for deleted objects
        [Parameter(ValueFromPipelinebyPropertyName = $true)]
        [switch]$SkipDeleteCheck,
        #Logfile path used to write the log files for each imported file
        [Parameter(ValueFromPipelinebyPropertyName = $true)]
        [String]$LogFolder,
        #Disable progress dialog
        [Parameter(ValueFromPipelinebyPropertyName = $true)]
        [switch]$NoProgress

    )

    Begin {
        function Invoke-PostImportCompilation
        {
            Param(
                $Object
            )
            if (($Object.Type -eq 1) -and ($Object.ID -gt 2000000004))
            {
                if ($Object.ID -eq 2000000006) 
                {
                    NVR_NAVScripts\Compile-NAVApplicationObjectMulti -Filter "Type=$($Object.Type);Id=$($Object.ID)" -Server $Server -Database $Database -NavIde (Get-NAVIde) -SynchronizeSchemaChanges No
                }
                else 
                {
                    NVR_NAVScripts\Compile-NAVApplicationObjectMulti -Filter "Type=$($Object.Type);Id=$($Object.ID)" -Server $Server -Database $Database -NavIde (Get-NAVIde) -SynchronizeSchemaChanges Force
                }
            }
            if ($Object.Type -eq 7) { #menusuite
                NVR_NAVScripts\Compile-NAVApplicationObjectMulti -Filter "Type=$($Object.Type);Id=$($Object.ID)" -Server $Server -Database $Database -NavIde (Get-NAVIde) -SynchronizeSchemaChanges Force
            }
        }

        if (!($env:PSModulePath -like "*;$PSScriptRoot*")) 
        {
            $env:PSModulePath = $env:PSModulePath + ";$PSScriptRoot"
        }
        Import-Module -Name NVR_NAVScripts -DisableNameChecking
        Import-NAVModelTool
    }    
    Process{
        if ($NavIde -eq '') 
        {
            $NavIde = Get-NAVIde
        }
        $FileObjects = Get-NAVApplicationObjectProperty -Source $Files
        $FileObjectsHash = $null
        $FileObjectsHash = @{}
        $i = 0
        $count = $FileObjects.Count
        $UpdatedObjects = New-Object -TypeName System.Collections.ArrayList
        $StartTime = Get-Date

        foreach ($FileObject in $FileObjects)
        {
            if (!$FileObject.Id) 
            {
                Continue
            }
            $i++
            $NowTime = Get-Date
            $TimeSpan = New-TimeSpan $StartTime $NowTime
            $percent = $i / $count
            if ($percent -gt 1) 
            {
                $percent = 1
            }
            $remtime = $TimeSpan.TotalSeconds / $percent * (1-$percent)

            if (($i % 10) -eq 0) 
            {
                if (-not $NoProgress) 
                {
                    Write-Progress -Status "Processing $i of $count" -Activity 'Comparing objects...' -PercentComplete ($percent*100) -SecondsRemaining $remtime
                }
            }
            $Type = Get-NAVObjectTypeIdFromName -TypeName $FileObject.ObjectType
            $Id = $FileObject.Id
            if ($FileObject.VersionList -eq '#DELETE') 
            {
                Write-Verbose -Message "$($FileObject.ObjectType) $($FileObject.Id) is deleted..."
            }
            else 
            {
                $FileObjectsHash.Add("$Type-$Id",$true)
                $NAVObject = Get-SQLCommandResult -Server $Server -Database $Database -Command "select [Type],[ID],[Version List],[Modified],[Name],[Date],[Time] from Object where [Type]=$Type and [ID]=$Id"
                #$NAVObject = $NAVObjects | ? (($_.Type -eq $Type) -and ($_.Id -eq $FileObject.Id))
                if (($FileObject.Modified -eq $NAVObject.Modified) -and
                    ($FileObject.VersionList -eq $NAVObject.'Version List') -and
                    ($FileObject.Time.TrimStart(' ') -eq $NAVObject.Time.ToString('H:mm:ss')) -and
                    ($FileObject.Date -eq $NAVObject.Date.ToString('dd.MM.yy')) -and
                    (!$All)
                )
                {
                    Write-Verbose -Message "$($FileObject.ObjectType) $($FileObject.Id) skipped..."
                }
                else 
                {
                    $ObjToImport = @{
                        'Type'   = $Type
                        'ID'     = $Id
                        'FileName' = $FileObject
                    }
                    if ($Id -gt 0) 
                    {
                        $UpdatedObjects += $ObjToImport
                        if ($All) 
                        {
                            Write-Verbose -Message "$($FileObject.ObjectType) $($FileObject.Id) forced..."
                        }
                        else 
                        {
                            if (($NAVObject -eq $null) -or ($NAVObject -eq '')) 
                            {
                                Write-Host -Object "$($FileObject.ObjectType) $($FileObject.Id) is new..."
                            }
                            else
                            {
                                Write-Host -Object "$($FileObject.ObjectType) $($FileObject.Id) differs: Modified=$($FileObject.Modified -eq $NAVObject.Modified) Version=$($FileObject.VersionList -eq $NAVObject.'Version List') Time=$($FileObject.Time.TrimStart(' ') -eq $NAVObject.Time.ToString('H:mm:ss')) Date=$($FileObject.Date -eq $NAVObject.Date.ToString('dd.MM.yy'))"
                            }
                        }
                    }
                }
            }
        }

        $i = 0
        $count = $UpdatedObjects.Count
        if (!$SkipDeleteCheck) 
        {
            $NAVObjects = Get-SQLCommandResult -Server $Server -Database $Database -Command 'select [Type],[ID],[Version List],[Modified],[Name],[Date],[Time] from Object where [Type]>0'
            $i = 0
            $count = $NAVObjects.Count
            $StartTime = Get-Date

            foreach ($NAVObject in $NAVObjects)
            {
                if (!$NAVObject.ID) 
                {
                    Continue
                }

                $i++
                $NowTime = Get-Date
                $TimeSpan = New-TimeSpan $StartTime $NowTime
                $percent = $i / $count
                $remtime = $TimeSpan.TotalSeconds / $percent * (1-$percent)

                if (-not $NoProgress) 
                {
                    Write-Progress -Status "Processing $i of $count" -Activity 'Checking deleted objects...' -PercentComplete ($i / $count*100) -SecondsRemaining $remtime
                }
                $Type = Get-NAVObjectTypeNameFromId -TypeId $NAVObject.Type
                #$FileObject = $FileObjects | Where-Object {($_.ObjectType -eq $Type) -and ($_.Id -eq $NAVObject.ID)}
                $Exists = $FileObjectsHash["$($NAVObject.Type)-$($NAVObject.ID)"]
                if (!$Exists) 
                {
                    Write-Warning -Message "$Type $($NAVObject.ID) Should be removed from the database!"
                    if ($MarkToDelete) 
                    {
                        Set-NAVObjectAsDeleted -Server $Server -Database $Database -NAVObjectType $NAVObject.Type -NAVObjectID $NAVObject.ID
                    }
                }
            }
        }
    
        $i = 0
        $count = $UpdatedObjects.Count
        
        $StartTime = Get-Date
        foreach ($ObjToImport in $UpdatedObjects) 
        {
            $i++
            $NowTime = Get-Date
            $TimeSpan = New-TimeSpan $StartTime $NowTime
            $percent = $i / $count
            if ($percent -gt 1) 
            {
                $percent = 1
            }
            $remtime = $TimeSpan.TotalSeconds / $percent * (1-$percent)

            if (-not $NoProgress) 
            {
                Write-Progress -Status "Importing $i of $count" -Activity 'Importing objects...' -CurrentOperation $ObjToImport.FileName.FileName -PercentComplete ($percent*100) -SecondsRemaining $remtime
            }
            if (($ObjToImport.Type -eq 7) -and ($ObjToImport.Id -lt 1050))
            {
                Write-Host -Object "Menusuite with ID < 1050 skipped... (Id=$($ObjToImport.Id))"
            }
            else 
            {
                if ($env:TF_BUILD) {
                    Write-Host "Importing $($ObjToImport.FileName.FileName)"
                }
                #Import-NAVApplicationObjectFiles -files $ObjToImport.FileName.FileName -Server $Server -Database $Database -NavIde (Get-NAVIde) -LogFolder $LogFolder
                Import-NAVApplicationObject2 -Path $ObjToImport.FileName.FileName -DatabaseName $Database -DatabaseServer $Server -LogPath $LogFolder -ImportAction Overwrite -SynchronizeSchemaChanges Force
            }
            Invoke-PostImportCompilation -Object $ObjectToImport
        }

        Write-Host -Object ''
        Write-Host -Object "Updated $($UpdatedObjects.Count) objects..."

        if ($Compile) 
        {
            $i = 0
            $count = $UpdatedObjects.Count
            $StartTime = Get-Date

            foreach ($UpdatedObject in $UpdatedObjects)
            {
                $i++
                $NowTime = Get-Date
                $TimeSpan = New-TimeSpan $StartTime $NowTime
                $percent = $i / $count
                $remtime = $TimeSpan.TotalSeconds / $percent * (1-$percent)

                if (-not $NoProgress) 
                {
                    Write-Progress -Status "Processing $i of $count" -Activity 'Compiling objects...' -PercentComplete ($i / $count*100) -SecondsRemaining $remtime
                }

                NVR_NAVScripts\Compile-NAVApplicationObject -Filter "Type=$($UpdatedObject.Type);Id=$($UpdatedObject.ID)" -Server $Server -Database $Database -NavIde (Get-NAVIde)
            }
            Write-Host -Object "Compiled $($UpdatedObjects.Count) objects..."
        }

    }
    End {
    }
}

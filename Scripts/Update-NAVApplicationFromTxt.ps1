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
param (
    #Object files from which to update. Should be complete set of objects
    [Parameter(Mandatory=$true,ValueFromPipelinebyPropertyName=$True)]
    [String]$Files,
    #SQL Server address
    [Parameter(Mandatory=$true,ValueFromPipelinebyPropertyName=$True)]
    [String]$Server,
    #SQL Database to update
    [Parameter(Mandatory=$true,ValueFromPipelinebyPropertyName=$True)]
    [String]$Database,
    #If set, all objects will be updated and compiled instead just different
    [Parameter(ValueFromPipelinebyPropertyName=$True)]
    [switch]$All,
    #If set, objects will be compiled after they are imported
    [Parameter(ValueFromPipelinebyPropertyName=$True)]
    [switch]$Compile,
    #If set, objects, which should be deleted, will be marked #TODELETE in version list
    [Parameter(ValueFromPipelinebyPropertyName=$True)]
    [switch]$MarkToDelete,
    #If set, script will not check for deleted objects
    [Parameter(ValueFromPipelinebyPropertyName=$True)]
    [switch]$SkipDeleteCheck
)

Begin {
    if (!($env:PSModulePath -like "*;$PSScriptRoot*")) {
        $env:PSModulePath = $env:PSModulePath + ";$PSScriptRoot"
    }

    Import-NAVModelTool
}
Process{
    if ($NavIde -eq "") {
      $NavIde = Get-NAVIde
    }
    $FileObjects=Get-NAVApplicationObjectProperty -Source $Files
    $FileObjectsHash=$null
    $FileObjectsHash=@{}
    $i=0
    $count = $FileObjects.Count
    $UpdatedObjects=New-Object System.Collections.ArrayList
    $StartTime = Get-Date

    foreach ($FileObject in $FileObjects)
    {
        $i++
        $NowTime = Get-Date
        $TimeSpan = New-TimeSpan $StartTime $NowTime
        $percent = $i / $count
        if ($percent -gt 1) {
            $percent = 1
        }
        $remtime = $TimeSpan.TotalSeconds / $percent * (1-$percent)

        if (($i % 10) -eq 0) {
            Write-Progress -Status "Processing $i of $count" -Activity 'Comparing objects...' -percentComplete ($percent*100) -SecondsRemaining $remtime
        }
        $Type= Get-NAVObjectTypeIdFromName -TypeName $FileObject.ObjectType
        $Id = $FileObject.Id
        $FileObjectsHash.Add("$Type-$Id",$true)
        $NAVObject=Get-SQLCommandResult -Server $Server -Database $Database -Command "select [Type],[ID],[Version List],[Modified],[Name],[Date],[Time] from Object where [Type]=$Type and [ID]=$Id"
        #$NAVObject = $NAVObjects | ? (($_.Type -eq $Type) -and ($_.Id -eq $FileObject.Id))
        if (($FileObject.Modified -eq $NAVObject.Modified) -and
             ($FileObject.VersionList -eq $NAVObject.'Version List') -and
             ($FileObject.Time.TrimStart(' ') -eq $NAVObject.Time.ToString('H:mm:ss')) -and
             ($FileObject.Date -eq $NAVObject.Date.ToString('dd.MM.yy')) -and
             (!$All)
            )
        {
            Write-Verbose "$($FileObject.ObjectType) $($FileObject.Id) skipped..."
        } else {
            $Object=@{"Type"=$Type;"ID"=$Id;"FileName"=$FileObject}
            if ($Id -gt 0) {
                $UpdatedObjects += $Object
                if ($All) {
                    Write-Host "$($FileObject.ObjectType) $($FileObject.Id) forced..."
                } else {
                    if (($NAVObject -eq $null) -or ($NAVObject -eq '')) {
                        Write-Host "$($FileObject.ObjectType) $($FileObject.Id) is new..."
                    } else
                    {
                        Write-Host "$($FileObject.ObjectType) $($FileObject.Id) differs: Modified=$($FileObject.Modified -eq $NAVObject.Modified) Version=$($FileObject.VersionList -eq $NAVObject.'Version List') Time=$($FileObject.Time.TrimStart(' ') -eq $NAVObject.Time.ToString('H:mm:ss')) Date=$($FileObject.Date -eq $NAVObject.Date.ToString('dd.MM.yy'))"
                    }
                }
            }
        }
    }

    $i =0
    $count = $UpdatedObjects.Count
    $StartTime = Get-Date
    foreach ($object in $UpdatedObjects) {
        $i++
        $NowTime = Get-Date
        $TimeSpan = New-TimeSpan $StartTime $NowTime
        $percent = $i / $count
        if ($percent -gt 1) {
            $percent = 1
        }
        $remtime = $TimeSpan.TotalSeconds / $percent * (1-$percent)

        Write-Progress -Status "Importing $i of $count" -Activity 'Importing objects...' -CurrentOperation $object.FileName.FileName -percentComplete ($percent*100) -SecondsRemaining $remtime
        Import-NAVApplicationObjectFiles -Files $object.FileName.FileName -Server $Server -Database $Database -NavIde (Get-NAVIde)
    }

    Write-Host ''
    Write-Host "Updated $($UpdatedObjects.Count) objects..."

    if ($Compile) {
        $i=0
        $count = $UpdatedObjects.Count
        $StartTime = Get-Date

        foreach ($UpdatedObject in $UpdatedObjects)
        {
            $i++
            $NowTime = Get-Date
            $TimeSpan = New-TimeSpan $StartTime $NowTime
            $percent = $i / $count
            $remtime = $TimeSpan.TotalSeconds / $percent * (1-$percent)

            Write-Progress -Status "Processing $i of $count" -Activity 'Compiling objects...' -percentComplete ($i / $count*100) -SecondsRemaining $remtime

            Compile-NAVApplicationObject -Filter "Type=$($UpdatedObject.Type);Id=$($UpdatedObject.ID)" -Server $Server -Database $Database -NavIde (Get-NAVIde)
        }
        Write-Host "Compiled $($UpdatedObjects.Count) objects..."
    }

    if (!$SkipDeleteCheck) {
        $NAVObjects=Get-SQLCommandResult -Server $Server -Database $Database -Command 'select [Type],[ID],[Version List],[Modified],[Name],[Date],[Time] from Object where [Type]>0'
        $i=0
        $count = $NAVObjects.Count
        $StartTime = Get-Date

        foreach ($NAVObject in $NAVObjects)
        {
            $i++
            $NowTime = Get-Date
            $TimeSpan = New-TimeSpan $StartTime $NowTime
            $percent = $i / $count
            $remtime = $TimeSpan.TotalSeconds / $percent * (1-$percent)

            Write-Progress -Status "Processing $i of $count" -Activity 'Checking deleted objects...' -percentComplete ($i / $count*100) -SecondsRemaining $remtime
            $Type= Get-NAVObjectTypeNameFromId -TypeId $NAVObject.Type
            #$FileObject = $FileObjects | Where-Object {($_.ObjectType -eq $Type) -and ($_.Id -eq $NAVObject.ID)}
            $Exists = $FileObjectsHash["$($NAVObject.Type)-$($NAVObject.ID)"]
            if (!$Exists) {
                Write-Warning "$Type $($NAVObject.ID) Should be removed from the database!"
                if ($MarkToDelete) {
                    $Result=Get-SQLCommandResult -Server $Server -Database $Database -Command "update Object set [Version List] = '#TODELETE '+ [Version List] where [Type]=$($NAVObject.Type) and [ID]=$($NAVObject.ID)"
               }
            }
        }
    }
}
End {
}
<#
.Synopsis
   Update .txt files on disk from objects in NAV database
.DESCRIPTION
   Scripts tries to update .txt files (folder with .txt files) to have up-to-date version of objects from NAV Database
.EXAMPLE
   Update-TxtFromNAVApplication.ps1 -Path E:\git\NAV\Objects\ -Server MySQLServer -Database MyNAVDatabase
#>
param (
    #Object files path into which export updated objects. Should be complete set of objects
    [Parameter(Mandatory=$true,ValueFromPipelinebyPropertyName=$True)]
    [String]$Path,
    #SQL Server address
    [Parameter(Mandatory=$true,ValueFromPipelinebyPropertyName=$True)]
    [String]$Server,
    #SQL Database to update
    [Parameter(Mandatory=$true,ValueFromPipelinebyPropertyName=$True)]
    [String]$Database,
    #If set, all objects will be updated instead just different
    [Parameter(ValueFromPipelinebyPropertyName=$True)]
    [switch]$All,
    #If set, objects, which should be deleted, will be removed from the path
    [Parameter(ValueFromPipelinebyPropertyName=$True)]
    [switch]$DeleteFiles
)

Begin {
    if (!($env:PSModulePath -like "*;$PSScriptRoot*")) {
        $env:PSModulePath = $env:PSModulePath + ";$PSScriptRoot"
    }
    Import-NAVModelTool
}

Process {
    $FileObjects=Get-NAVApplicationObjectProperty -Source $Path\*.txt
    $FileObjectsHash=$null
    $FileObjectsHash=@{}
    Write-Progress -Activity "Creating hash with file info" 
    foreach ($FileObject in $FileObjects)
    {
        $FileObjectsHash.Add("$($FileObject.ObjectType)-$($FileObject.Id)",$FileObject)
    }

    $NAVObjects=Get-SQLCommandResult -Server $Server -Database $Database -Command 'select [Type],[ID],[Version List],[Modified],[Name],[Date],[Time] from Object where [Type]>0'
    $NAVObjectsHash = $null
    $NAVObjectsHash = @{}
    $i=0
    $count = $NAVObjects.Count
    $UpdatedObjects=@()
    $StartTime = Get-Date

    foreach ($NAVObject in $NAVObjects)
    {
        $i++
        $NowTime = Get-Date
        $TimeSpan = New-TimeSpan $StartTime $NowTime
        $percent = $i / $count
        $remtime = $TimeSpan.TotalSeconds / $percent * (1-$percent)

        Write-Progress -Id 10 -Status "Processing $i of $count" -Activity 'Comparing objects...' -percentComplete ($i / $count*100) -SecondsRemaining $remtime

        $Type= Get-NAVObjectTypeNameFromId -TypeId $NAVObject.Type
        $Id = $NAVObject.ID
        $NAVObjectsHash.Add("$Type-$Id",$true)

        $FileObject = $FileObjectsHash["$Type-$Id"]

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
            if ($FileObject -eq $null) {
                $TargetFileName = $Type.ToString().ToUpper().Substring(0,3)
                $TargetFileName += $Id.ToString()
                $TargetFileName += '.TXT'
                $TargetFileName = (Join-Path $Path $TargetFileName)
            } else {
                $TargetFileName = $FileObject.FileName
            }
            $Filter= "Type=$($NAVObject.Type);ID=$($NAVObject.Id)"
            $Object=@{"Type"=$Type;"ID"=$Id;"Filter"=$Filter;"TargetFilename"=$TargetFileName}
            $UpdatedObjects += $Object
            if ($All) {
                Write-Host "$($FileObject.ObjectType) $($FileObject.Id) forced..."
            } else {
                if ($FileObject -eq $null) {
                    Write-Host "$Type $Id not exists as file, exporting..."
                } else {
                    Write-Host "$Type $Id differs: Modified=$($FileObject.Modified -eq $NAVObject.Modified) Version=$($FileObject.VersionList -eq $NAVObject.'Version List') Time=$($FileObject.Time.TrimStart(' ') -eq $NAVObject.Time.ToString('H:mm:ss')) Date=$($FileObject.Date -eq $NAVObject.Date.ToString('dd.MM.yy'))"
                }
            }
        }
    }

    $i =0
    $count = $UpdatedObjects.Count
    $StartTime = Get-Date
    foreach ($updateobject in $UpdatedObjects) {
        $i++
        $NowTime = Get-Date
        $TimeSpan = New-TimeSpan $StartTime $NowTime
        $percent = $i / $count
        $remtime = $TimeSpan.TotalSeconds / $percent * (1-$percent)

        Write-Progress -Id 10 -Status "Importing $i of $count" -Activity 'Importing objects...' -CurrentOperation $updateobject.Filter -percentComplete ($i / $count*100) -SecondsRemaining $remtime
        Write-Host "Exporting $($updateobject.Filter)..."
        Export-NAVApplicationObject -Filter $updateobject.Filter -Server $Server -Database $Database -LogFolder 'LOG' -Path $updateobject.TargetFileName -NavIde (Get-NAVIde)
    }

    Write-Host ''
    Write-Host "Exported $($UpdatedObjects.Count) files..."

    $i=0
    $count = $FileObjects.Count
    $StartTime = Get-Date

    foreach ($FileObject in $FileObjects)
    {
        $i++
        $NowTime = Get-Date
        $TimeSpan = New-TimeSpan $StartTime $NowTime
        $percent = $i / $count
        $remtime = $TimeSpan.TotalSeconds / $percent * (1-$percent)

        Write-Progress -Id 50 -Status "Processing $i of $count" -Activity 'Checking deleted objects...' -percentComplete ($i / $count*100) -SecondsRemaining $remtime
        $Type= Get-NAVObjectTypeIdFromName -TypeName $FileObject.ObjectType

        $Exists = $NAVObjectsHash["$($FileObject.ObjectType)-$($FileObject.ID)"]
        if (!$Exists) {
            Write-Warning "$($FileObject.FileName) should be removed!"
            if ($DeleteFiles) {
                Remove-Item -Path $FileObject.FileName -Force
           }
        }
    }
}

End {
}
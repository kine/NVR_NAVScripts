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
    [Parameter(Mandatory=$true)]
    [String]$Files,
    #SQL Server address
    [Parameter(Mandatory=$true)]
    [String]$Server,
    #SQL Database to update
    [Parameter(Mandatory=$true)]
    [String]$Database,
    #If set, all objects will be updated and compiled instead just different
    [switch]$All,
    #If set, objects will be compiled after they are imported
    [switch]$Compile,
    #If set, objects, which should be deleted, will be marked #TODELETE in version list
    [switch]$MarkToDelete
)

$FileObjects=Get-NAVApplicationObjectProperty -Source $Files
$FileObjectsHash=$null
$FileObjectsHash=@{}
$i=0
$count = $FileObjects.Count
$UpdatedObjects=@()
$StartTime = Get-Date

foreach ($FileObject in $FileObjects)
{
    $i++
    $NowTime = Get-Date
    $TimeSpan = New-TimeSpan $StartTime $NowTime
    $percent = $i / $count
    $remtime = $TimeSpan.TotalSeconds / $percent * (1-$percent)

    if (($i % 10) -eq 0) {
        Write-Progress -Id 50 -Status "Processing $i of $count" -Activity 'Comparing objects...' -percentComplete ($i / $count*100) -SecondsRemaining $remtime
    }
    switch ($FileObject.ObjectType)
    {
        "Table" {$Type = 1}
        "Page" {$Type = 8}
        "Codeunit" {$Type = 5}
        "Report" {$Type = 3}
        "XMLPort" {$Type = 6}
        "Query" {$Type = 9}
        "MenuSuite" {$Type = 7}
    }
    $Id = $FileObject.Id
    $FileObjectsHash.Add("$Type-$Id",$true)
    $NAVObject=Get-SQLCommandResult -Server $Server -Database $Database -Command "select [Type],[ID],[Version List],[Modified],[Name],[Date],[Time] from Object where [Type]=$Type and [Id]=$Id"
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
        $Object=@{"Type"=$Type;"ID"=$Id}
        $UpdatedObjects += $Object
        if ($All) {
            Write-Host "$($FileObject.ObjectType) $($FileObject.Id) forced..."
        } else {
            Write-Host "$($FileObject.ObjectType) $($FileObject.Id) differs: Modified=$($FileObject.Modified -eq $NAVObject.Modified) Version=$($FileObject.VersionList -eq $NAVObject.'Version List') Time=$($FileObject.Time.TrimStart(' ') -eq $NAVObject.Time.ToString('H:mm:ss')) Date=$($FileObject.Date -eq $NAVObject.Date.ToString('dd.MM.yy'))"
        }
        Import-NAVApplicationObjectFiles -Files $FileObject.FileName -Server $Server -Database $Database -NavIde (Get-NAVIde)
    }
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

        Write-Progress -Id 50 -Status "Processing $i of $count" -Activity 'Compiling objects...' -percentComplete ($i / $count*100) -SecondsRemaining $remtime

        Compile-NAVApplicationObject -Filter "Type=$($UpdatedObject.Type);Id=$($UpdatedObject.ID)" -Server $Server -Database $Database -NavIde (Get-NAVIde)
    }
    Write-Host "Compiled $($UpdatedObjects.Count) objects..."
}

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

    Write-Progress -Id 50 -Status "Processing $i of $count" -Activity 'Checking deleted objects...' -percentComplete ($i / $count*100) -SecondsRemaining $remtime
    switch ($NAVObject.Type)
    {
        1 {$Type = "Table"}
        8 {$Type = "Page"}
        5 {$Type = "Codeunit"}
        3 {$Type = "Report"}
        6 {$Type = "XMLPort"}
        9 {$Type = "Query"}
        7 {$Type = "MenuSuite"}
    }
    #$FileObject = $FileObjects | Where-Object {($_.ObjectType -eq $Type) -and ($_.Id -eq $NAVObject.ID)}
    $Exists = $FileObjectsHash["$($NAVObject.Type)-$($NAVObject.ID)"]
    if (!$Exists) {
        Write-Warning "$Type $($NAVObject.ID) Should be removed from the database!"
        if ($MarkToDelete) {
            $Result=Get-SQLCommandResult -Server $Server -Database $Database -Command "update Object set [Version List] = '#TODELETE '+ [Version List] where [Type]=$($NAVObject.Type) and [ID]=$($NAVObject.ID)"
       }
    }
}
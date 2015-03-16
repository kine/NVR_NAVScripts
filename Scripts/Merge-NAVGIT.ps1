Param (
    [Parameter(Mandatory = $true)]
    [string]$repository,
    [Parameter(Mandatory = $true)]
    [string]$sourcefiles,
    [Parameter(Mandatory = $true)]
    [string]$targetbranch,
    [switch]$skipcopytorep,
    [switch]$remerge,
    #Languages, which will be removed from modified version and added after merge back (when merging with version without this language)
    [String]$RemoveLanguageId
)
Import-Module -Name NVR_NAVScripts -WarningAction SilentlyContinue
Import-NAVModelTool
#Import-Module 'c:\Program Files (x86)\Microsoft Dynamics NAV\71\RoleTailored Client\Microsoft.Dynamics.Nav.Model.Tools.psd1' -WarningAction SilentlyContinue


$mergetool = 'C:\Program Files (x86)\Araxis\Araxis Merge v6.5\merge.exe'
#$mergetool = "C:\Program Files (x86)\KDiff3\kdiff3.exe"
$mergetoolparams = '{0} {3} {2}'
$mergetoolresult2source = $true
$diff = 'C:\Program Files (x86)\KDiff3\bin\diff3.exe'
$diffparams = '{0} {1} {2} -E'

function TestIfFolderClear([string]$repository)
{
    Set-Location $repository
    $gitstatus = git.exe status -s
    if ($gitstatus -gt '') 
    {
        Throw 'There are uncommited changes!!!'
    }
}

function SolveConflicts($conflicts) 
{
    $i = 0
    $count = $conflicts.Count
    if ($count -gt 0) 
    {
        $conflicts | ForEach-Object -Process {
            $i++
            Write-Progress -Id 50 -Status "Processing $i of $count" -Activity 'Mergin GIT repositories...' -CurrentOperation 'Resolving conflicts' -PercentComplete ($i / $count*100)
            $conflictfile = $_.Result.Filename.Replace('.TXT','') +'.conflict'
            if (Test-Path -Path $conflictfile) 
            {
                $filename = Split-Path -Path $_.result.FileName -Leaf
                $modified = (Split-Path -Path $_.Result.FileName -Parent)+'\ConflictModified\'+$filename
                $source = (Split-Path -Path $_.Result.FileName -Parent)+'\ConflictOriginal\'+$filename
                $target = (Split-Path -Path $_.Result.FileName -Parent)+'\ConflictTarget\'+$filename
                $result = $_.Result

                $params = $diffparams -f $modified, $source, $target, $result
                if ($mergetoolresult2source) 
                {
                    #Copy-Item -Path $result -Destination $source -Force
                }
                #Write-Output "----$filename conflicts-----"
                #& $diff $params.Split(" ")
                #Write-Output "----end-----"
                #$answer = Read-Host -Prompt "Solve conflict in $filename manually (Nothing = yes, something = no)?"
                #if ($answer -gt "") {

                & $conflictfile
                $params = $mergetoolparams -f $modified, $source, $target, $result
                $result = & $mergetool $params.Split(' ')
                Write-Host -Object "Reuslt: $result"
                $answer = Read-Host -Prompt "Was conflict in $filename resolved (Nothing = no, something = yes)?"
                if ($answer -gt '') 
                {
                    if ($answer -eq 'q') 
                    {
                        return
                    }
                    if (Test-Path -Path $conflictfile) 
                    {
                        Remove-Item -Path $conflictfile
                    }
                    if (Test-Path -Path $modified) 
                    {
                        Remove-Item -Path $modified
                    }
                    if (Test-Path -Path $source) 
                    {
                        Remove-Item -Path $source
                    }
                    if (Test-Path -Path $target) 
                    {
                        Remove-Item -Path $target
                    }
                }
                else 
                {

                }
                #}
            }        
        }
    }
}

function CreateResult([string]$resultfolder)
{
    $result = Remove-Item -Path $sourcefiles -Recurse
    $result = Copy-Item -Path (Join-Path $resultfolder $sourcefilespath) -Filter $sourcefiles -Destination . -Exclude Conflict -Recurse -Force
    $source = (Join-Path (Join-Path $resultfolder $sourcefilespath) $sourcefiles)
    $target = '.\'+$sourcefilespath
    Copy-Item -Path $source -Filter $sourcefiles -Destination $target -Force -Recurse
}

function CreateGitMerge
{
    $result = git.exe merge --no-ff --no-commit --strategy=ours --quiet --no-progress $targetbranch 2> $null
}

function ConvertTo-Date ($param1)
{
    if ($param1) 
    {
        return (Get-Date -Date $param1)
    }
    return (Get-Date -Year 1900 -Month 1 -Day 1)
}
function MergeVersionLists($mergeresult)
{
    $i = 0
    $count = $mergeresult.Count
    if ($count -gt 0) 
    {
        $mergeresult | ForEach-Object  -Process {
            $i = $i +1
            Write-Progress -Id 50 -Status "Processing $i of $count" -Activity 'Mergin GIT repositories...' -CurrentOperation 'Merging version lists' -PercentComplete ($i / $mergeresult.Count*100)
            $ProgressPreference = 'SilentlyContinue'
            $newversion = Merge-NAVVersionListString -source $_.Modified.VersionList -target $_.Target.VersionList -mode SourceFirst
            $newmodified = 'No'
            if ($_.Modified.Modified -or $_.Target.Modified) 
            {
                $newmodified = 'Yes'
            }

            #($_.Target.Date,$_.Modified.Date) | Measure-Object -Maximum).Maximum
            if ((ConvertTo-Date $_.Target.Date) -gt $(ConvertTo-Date $_.Modified.Date)) 
            {
                $newdate = $_.Target.Date
                $newtime = $_.Target.Time
            }
            else 
            {
                if ((ConvertTo-Date $_.Target.Date) -eq (ConvertTo-Date $_.Modified.Date)) 
                {
                    $newdate = $_.Modified.Date
                    $newtime = (($_.Target.Time, $_.Modified.Time) | Measure-Object -Maximum).Maximum
                }
                else 
                {
                    $newdate = $_.Modified.Date
                    $newtime = $_.Modified.Time
                }
            }
        
            #if ($newversion -ne $_.Target.VersionList) {
            if ($newdate -and $newtime) {
                Set-NAVApplicationObjectProperty -TargetPath $_.Result.FileName -VersionListProperty $newversion -ModifiedProperty $newmodified -DateTimeProperty "$newdate $newtime"
            } else {
                Set-NAVApplicationObjectProperty -TargetPath $_.Result.FileName -VersionListProperty $newversion -ModifiedProperty $newmodified
            }
            #}
            $ProgressPreference = 'Continue'
        }
    }
}


function MergeVersionList($merged)
{
    #$merged | Out-GridView
    $i = 0
    foreach ($merge in $merged) 
    {
        #$merge |ft
        $i = $i +1
        Write-Progress -Id 50 -Activity 'Mergin GIT repositories...' -CurrentOperation 'Merging version lists' -PercentComplete ($i / $merged.Count*100)
        if ($merge.Result.Filename -gt '') 
        {
            $file = Get-ChildItem -Path $merge.Result
            $filename = $file.Name
            Merge-NAVObjectVersionList -modifiedfilename $merge.Modified -targetfilename $merge.Target -resultfilename $merge.Result -newversion $newversion
        }
    }
}

function SetupGitRepository
{
    $result = git.exe config --local merge.ours.name 'always keep ours merge driver'
    $result = git.exe config --local merge.ours.driver 'true'
}

$currentfolder = Get-Location
Set-Location $repository 

$sourcebranch = git.exe rev-parse --abbrev-ref HEAD

TestIfFolderClear($repository)

$tempfolder = (Join-Path $env:TEMP 'NAVGIT')
$sourcefolder = $tempfolder+'\Source'
$sourcefolder2 = $tempfolder+'\Source2'
$targetfolder = $tempfolder+'\Target'
$targetfolder2 = $tempfolder+'\Target2'
$commonfolder = $tempfolder+'\Common'
$resultfolder = $tempfolder+'\Result'
$languagefolder = $tempfolder+'\Language'

$sourcefilespath = Split-Path $sourcefiles
if ($sourcefilespath -eq '') 
{
    $sourcefilespath = '.'
}
$sourcefilespath = $sourcefilespath+'\'

$sourcefiles = Split-Path -Path $sourcefiles -Leaf

Write-Progress -Id 50 -Activity  'Mergin GIT repositories...' -CurrentOperation 'Clearing temp folders...'
if (!$remerge) 
{
    $result = Remove-Item -Path $tempfolder -Force -Recurse
    $result = New-Item -Path $tempfolder -ItemType directory -Force

    #$result = Remove-Item -Path $sourcefolder -Force -Recurse
    $result = New-Item -Path $sourcefolder -ItemType directory -Force
    
    #$result = Remove-Item -Path $sourcefolder2 -Force -Recurse

    #$result = Remove-Item -Path $targetfolder -Force -Recurse
    $result = New-Item -Path $targetfolder -ItemType directory -Force

    #$result = Remove-Item -Path $commonfolder -Force -Recurse
    $result = New-Item -Path $commonfolder -ItemType directory -Force
    
    #$result = Remove-Item -Path $languagefolder -Force -Recurse
    $result = New-Item -Path $languagefolder -ItemType directory -Force
   
}

$result = Remove-Item -Path $resultfolder -Force -Recurse
$result = New-Item -Path $resultfolder -ItemType directory -Force

$result = New-Item -Path (Join-Path $resultfolder $sourcefilespath) -ItemType directory -Force



if (!$remerge) 
{
    SetupGitRepository
}

$startdatetime = Get-Date
Write-Host  Starting at $startdatetime


if (!$remerge) 
{
    Write-Progress -Id 50 -Activity  'Mergin GIT repositories...' -CurrentOperation 'Getting Common Ancestor...'
    $commonbranch = git.exe merge-base $sourcebranch $targetbranch

    Write-Progress -Id 50 -Activity  'Mergin GIT repositories...' -CurrentOperation "Switching to $commonbranch"
    $result = git.exe checkout --force "$commonbranch" --quiet

    Write-Progress -Id 50 -Activity  'Mergin GIT repositories...' -CurrentOperation "Copying the $commonbranch to temp folder..."
    $result = Copy-Item -Path $sourcefilespath -Filter $sourcefiles -Destination $commonfolder -Recurse -Container

    Write-Progress -Id 50 -Activity  'Mergin GIT repositories...' -CurrentOperation "Switching to $targetbranch"
    $result = git.exe checkout --force "$targetbranch" --quiet

    Write-Progress -Id 50 -Activity  'Mergin GIT repositories...' -CurrentOperation "Copying the $targetbranch to temp folder..."
    $result = Copy-Item -Path $sourcefilespath -Filter $sourcefiles -Destination $targetfolder -Recurse -Container

    Write-Progress -Id 50 -Activity  'Mergin GIT repositories...' -CurrentOperation "Switching to $sourcebranch"
    $result = git.exe checkout --force "$sourcebranch" --quiet

    Write-Progress -Id 50 -Activity  'Mergin GIT repositories...' -CurrentOperation "Copying the $sourcebranch to temp folder..."
    $result = Copy-Item -Path $sourcefilespath -Filter $sourcefiles -Destination $sourcefolder -Recurse -Container
}

if ($RemoveLanguageId) {
    $tempfolder2 = Join-Path $tempfolder 'TEMP'
    $result = New-Item -Path $tempfolder2 -ItemType directory -Force
    $result = New-Item -Path (Join-Path $tempfolder2 $sourcefilespath) -ItemType directory -Force
    Export-NAVApplicationObjectLanguage -Source (Join-Path $sourcefolder $sourcefilespath) -Destination (Join-Path $sourcefolder '..\SourceLanguage.txt') -LanguageId $RemoveLanguageId -DevelopmentLanguageId "ENU"
    Remove-NAVApplicationObjectLanguage -Source (Join-Path $sourcefolder $sourcefilespath) -Destination (Join-Path $tempfolder2 $sourcefilespath) -LanguageId $RemoveLanguageId -DevelopmentLanguageId "ENU" -RemoveRedundant
    $result = Remove-Item -Path $sourcefolder -Force -Recurse
    $result = Rename-Item -Path $tempfolder2 -NewName $sourcefolder -Force
    
    $result = New-Item -Path $tempfolder2 -ItemType directory -Force
    $result = New-Item -Path (Join-Path $tempfolder2 $sourcefilespath) -ItemType directory -Force
    Export-NAVApplicationObjectLanguage -Source (Join-Path $targetfolder $sourcefilespath) -Destination (Join-Path $targetfolder '..\TargetLanguage.txt') -LanguageId $RemoveLanguageId -DevelopmentLanguageId "ENU"
    Remove-NAVApplicationObjectLanguage -Source (Join-Path $targetfolder $sourcefilespath) -Destination (Join-Path $tempfolder2 $sourcefilespath) -LanguageId $RemoveLanguageId -DevelopmentLanguageId "ENU" -RemoveRedundant
    $result = Remove-Item -Path $targetfolder -Force -Recurse
    $result = Rename-Item -Path $tempfolder2 -NewName $targetfolder -Force
}

Write-Progress -Id 50 -Activity  'Mergin GIT repositories...' -CurrentOperation 'Merging NAV Object files...'

$mergeresult = Merge-NAVApplicationObject -Original (Join-Path $commonfolder $sourcefilespath) -Modified (Join-Path $sourcefolder $sourcefilespath) -Target (Join-Path $targetfolder $sourcefilespath) -Result (Join-Path $resultfolder $sourcefilespath) -Force -DateTimeProperty FromModified -ModifiedProperty FromModified -DocumentationConflict ModifiedFirst
$mergeresult | Export-Clixml -Path $resultfolder'..\mergeresult.xml'

$merged = $mergeresult | Where-Object -FilterScript {
    $_.MergeResult -eq 'Merged'
}
$inserted = $mergeresult | Where-Object -FilterScript {
    $_.MergeResult -eq 'Inserted'
}
$deleted = $mergeresult | Where-Object -FilterScript {
    $_.MergeResult -EQ 'Deleted'
}
$conflicts = $mergeresult | Where-Object -FilterScript {
    $_.MergeResult -EQ 'Conflict'
}
$identical = $mergeresult | Where-Object -FilterScript {
    $_.MergeResult -eq 'Identical'
}


#$mergeresult | Out-GridView  #debug output

$mergeresult.Summary

$enddatetime = Get-Date
$TimeSpan = New-TimeSpan $startdatetime $enddatetime

Write-Host  Merged in $TimeSpan

Write-Progress -Id 50 -Activity  'Mergin GIT repositories...' -CurrentOperation 'Merging version list for merged objects...'
MergeVersionLists($merged)
Write-Progress -Id 50 -Activity  'Mergin GIT repositories...' -CurrentOperation 'Merging version list for conflict objects...'
MergeVersionLists($conflicts)

$enddatetime = Get-Date
$TimeSpan = New-TimeSpan $startdatetime $enddatetime

Write-Host  Merged in $TimeSpan

Write-Progress -Id 50 -Activity  'Mergin GIT repositories...' -CurrentOperation 'Solving conflicts...'
SolveConflicts($conflicts)

if ($RemoveLanguageId) {
    $result = New-Item -Path (Join-Path $tempfolder2 $sourcefilespath) -ItemType directory -Force
    Import-NAVApplicationObjectLanguage -Source (Join-Path $resultfolder $sourcefilespath) -LanguagePath (Join-Path $sourcefolder '..\SourceLanguage.txt') -Destination (Join-Path $tempfolder2 $sourcefilespath) -LanguageId $RemoveLanguageId
    $result = Remove-Item -Path $resultfolder -Force -Recurse
    $result = Rename-Item -Path $tempfolder2 -NewName $resultfolder -Force
    Import-NAVApplicationObjectLanguage -Source (Join-Path $resultfolder $sourcefilespath) -LanguagePath (Join-Path $sourcefolder '..\TargetLanguage.txt') -Destination (Join-Path $tempfolder2 $sourcefilespath) -LanguageId $RemoveLanguageId
    $result = Remove-Item -Path $resultfolder -Force -Recurse
    $result = Rename-Item -Path $tempfolder2 -NewName $resultfolder -Force
}

if (!$skipcopytorep) 
{
    CreateGitMerge #set git to merge action, using ours strategy
    Write-Progress -Id 50 -Activity  'Mergin GIT repositories...' -CurrentOperation 'Copying result to the repository...'
    CreateResult($resultfolder)
}

Set-Location -Path $currentfolder.Path
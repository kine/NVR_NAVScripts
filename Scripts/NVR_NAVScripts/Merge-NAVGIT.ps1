<#
    .Synopsis
    Merge two local branches by using NAV Model tools.
    .DESCRIPTION
    Merge two local branches by using NAV model tools scripts. Can remove selected language 
    before merging and add them back after merge.
    .EXAMPLE
    Merge-NAVGIT -repository c:\git\myrepo -sourcefiles objects\*.txt -targetbranch master -RemoveLanguageId 'SKY'
#>
function Merge-NAVGIT
{
    [CmdletBinding()]
    Param (
        #Path to repostory root folder
        [Parameter(Mandatory = $true)]
        [string]$repository,
        #Relatife path to files in the repository (e.g. 'objects\*.txt')
        [Parameter(Mandatory = $true)]
        [string]$sourcefiles,
        #Name of local branch or hash of commit with which to merge
        [Parameter(Mandatory = $true)]
        [string]$targetbranch,
        #If needed, you can pass hash of the ancestor to be used for merging. If not used, ancestor is automatically detected
        [string]$ancestor,
        #Will not copy result back to the repository
        [switch]$skipcopytorep,
        #If used, objects are not copied from repo to temp folders and existing temp folders are used to merge
        [switch]$remerge,
        #Languages, which will be removed from modified version and added after merge back (when merging with version without this language)
        $RemoveLanguageId
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
                    $answer = Read-Host -Prompt "$i of $count : Was conflict in $filename resolved (Nothing = no, something = yes)?"
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
        $result = Copy-Item -Path (Join-Path -Path $resultfolder -ChildPath $sourcefilespath) -Filter $sourcefiles -Destination . -Exclude Conflict -Recurse -Force
        $source = (Join-Path -Path (Join-Path -Path $resultfolder -ChildPath $sourcefilespath) -ChildPath $sourcefiles)
        $target = '.\'+$sourcefilespath
        Copy-Item -Path $source -Filter $sourcefiles -Destination $target -Force -Recurse
    }

    function CreateGitMerge
    {
        $result = git.exe merge --no-ff --no-commit --strategy=ours --quiet --no-progress $targetbranch | Out-Null
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
                $newversion = Merge-NAVVersionListString -source $_.Modified.VersionList -target $_.Target.VersionList -mode TargetFirst
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
                if ($newdate -and $newtime) 
                {
                    Set-NAVApplicationObjectProperty -TargetPath $_.Result.FileName -VersionListProperty $newversion -ModifiedProperty $newmodified -DateTimeProperty "$newdate $newtime"
                } else 
                {
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

    function Get-GITNearAncestor ($source, $target)
    {
        $result = git.exe merge-base  "$source" "$target" --all
        if ($result.Count) 
        {
            $shortest = 999999
            foreach ($commit in $result) 
            {
                $path = git.exe rev-list --ancestry-path "$commit..$source"   
                if ($path.Count -lt $shortest) 
                {
                    $shortest = $path.Count
                    $ancestor = $commit
                }
            }  
            Return $ancestor
        }
        else 
        {
            Return $result
        }
    }

    function Remove-NAVEmptyTranslation
    {
        param
        (
            [Parameter(Mandatory = $true)]
            $Path,
            [Parameter(Mandatory = $true)]
            $Result
        )
        Get-Content -Path $Path | Where-Object {$_ -match '.+-L999:.+'} | Set-Content -Path $Result
    }

    $currentfolder = Get-Location
    Set-Location $repository 

    $sourcebranch = git.exe rev-parse --abbrev-ref HEAD

    TestIfFolderClear($repository)

    $tempfolder = (Join-Path -Path $env:TEMP -ChildPath 'NAVGIT')
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
        if (Get-Item $tempfolder) {
            $result = Remove-Item -Path $tempfolder -Force -Recurse
        }
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

    if (Get-Item $resultfolder) {
        $result = Remove-Item -Path $resultfolder -Force -Recurse
    }
    $result = New-Item -Path $resultfolder -ItemType directory -Force

    $result = New-Item -Path (Join-Path -Path $resultfolder -ChildPath $sourcefilespath) -ItemType directory -Force



    if (!$remerge) 
    {
        SetupGitRepository
    }

    $startdatetime = Get-Date
    Write-Host  Starting at $startdatetime


    if (!$remerge) 
    {
        Write-Progress -Id 50 -Activity  'Mergin GIT repositories...' -CurrentOperation 'Getting Common Ancestor...'
        if ($ancestor) 
        {
            $commonbranch = $ancestor
        } else 
        {
            $commonbranch = Get-GITNearAncestor -Source $sourcebranch -Target $targetbranch
        }

        Write-Progress -Id 50 -Activity  'Mergin GIT repositories...' -CurrentOperation "Switching to $commonbranch"
        $result = git.exe checkout --force "$commonbranch" --quiet

        Write-Progress -Id 50 -Activity  'Mergin GIT repositories...' -CurrentOperation "Copying the $commonbranch to temp folder..."
        $result = Copy-Item -Path $sourcefilespath -Filter $sourcefiles -Destination $commonfolder -Recurse -Container

        Write-Progress -Id 50 -Activity  'Mergin GIT repositories...' -CurrentOperation "Switching to $targetbranch"
        $result = git.exe checkout --force "$targetbranch" --quiet

        Write-Progress -Id 50 -Activity  'Mergin GIT repositories...' -CurrentOperation "Copying the $targetbranch to temp folder..."
        $result = Copy-Item -Path $sourcefilespath -Filter $sourcefiles -Destination $sourcefolder -Recurse -Container

        Write-Progress -Id 50 -Activity  'Mergin GIT repositories...' -CurrentOperation "Switching to $sourcebranch"
        $result = git.exe checkout --force "$sourcebranch" --quiet

        Write-Progress -Id 50 -Activity  'Mergin GIT repositories...' -CurrentOperation "Copying the $sourcebranch to temp folder..."
        $result = Copy-Item -Path $sourcefilespath -Filter $sourcefiles -Destination $targetfolder -Recurse -Container
    }

    if ($RemoveLanguageId) 
    {
        $tempfolder2 = Join-Path -Path $tempfolder -ChildPath 'TEMP'
        $result = New-Item -Path $tempfolder2 -ItemType directory -Force
        $result = New-Item -Path (Join-Path -Path $tempfolder2 -ChildPath $sourcefilespath) -ItemType directory -Force
        Export-NAVApplicationObjectLanguage -Source (Join-Path -Path $sourcefolder -ChildPath $sourcefilespath) -Destination (Join-Path -Path $sourcefolder -ChildPath '..\SourceLanguage.txt') -LanguageId $RemoveLanguageId -DevelopmentLanguageId 'ENU'
        Remove-NAVApplicationObjectLanguage -Source (Join-Path -Path $sourcefolder -ChildPath $sourcefilespath) -Destination (Join-Path -Path $tempfolder2 -ChildPath $sourcefilespath) -LanguageId $RemoveLanguageId -DevelopmentLanguageId 'ENU' -RemoveRedundant
        $result = Remove-Item -Path $sourcefolder -Force -Recurse
        $result = Rename-Item -Path $tempfolder2 -NewName $sourcefolder -Force
    
        $result = New-Item -Path $tempfolder2 -ItemType directory -Force
        $result = New-Item -Path (Join-Path -Path $tempfolder2 -ChildPath $sourcefilespath) -ItemType directory -Force
        Export-NAVApplicationObjectLanguage -Source (Join-Path -Path $targetfolder -ChildPath $sourcefilespath) -Destination (Join-Path -Path $targetfolder -ChildPath '..\TargetLanguage.txt') -LanguageId $RemoveLanguageId -DevelopmentLanguageId 'ENU'
        Remove-NAVApplicationObjectLanguage -Source (Join-Path -Path $targetfolder -ChildPath $sourcefilespath) -Destination (Join-Path -Path $tempfolder2 -ChildPath $sourcefilespath) -LanguageId $RemoveLanguageId -DevelopmentLanguageId 'ENU' -RemoveRedundant
        $result = Remove-Item -Path $targetfolder -Force -Recurse
        $result = Rename-Item -Path $tempfolder2 -NewName $targetfolder -Force
    }

    Write-InfoMessage -Message 'Merging NAV Object files...'

    $mergeresult = Merge-NAVApplicationObject -OriginalPath (Join-Path -Path $commonfolder -ChildPath $sourcefilespath) -Modified (Join-Path -Path $sourcefolder -ChildPath $sourcefilespath) -TargetPath (Join-Path -Path $targetfolder -ChildPath $sourcefilespath) -ResultPath (Join-Path -Path $resultfolder -ChildPath $sourcefilespath) -Force -DateTimeProperty FromModified -ModifiedProperty FromModified -DocumentationConflict ModifiedFirst
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

    Write-InfoMessage -Message 'Merging version list for merged objects...'
    MergeVersionLists($merged)
    Write-InfoMessage -Message 'Merging version list for conflict objects...'
    MergeVersionLists($conflicts)

    $enddatetime = Get-Date
    $TimeSpan = New-TimeSpan $startdatetime $enddatetime

    Write-Host  Merged in $TimeSpan

    Write-Progress -Id 50 -Activity  'Mergin GIT repositories...' -CurrentOperation 'Solving conflicts...'
    SolveConflicts($conflicts)

    if ($RemoveLanguageId) 
    {
        Remove-NAVEmptyTranslation -Path (Join-Path -Path $sourcefolder -ChildPath '..\SourceLanguage.txt') -Result (Join-Path -Path $sourcefolder -ChildPath '..\SourceLanguage2.txt')
        Remove-NAVEmptyTranslation -Path (Join-Path -Path $sourcefolder -ChildPath '..\TargetLanguage.txt') -Result (Join-Path -Path $sourcefolder -ChildPath '..\TargetLanguage2.txt')
        
        $result = New-Item -Path (Join-Path -Path $tempfolder2 -ChildPath $sourcefilespath) -ItemType directory -Force
        if (Test-Path -Path (Join-Path -Path $sourcefolder -ChildPath '..\SourceLanguage2.txt')) {
            Import-NAVApplicationObjectLanguage -Source (Join-Path -Path $resultfolder -ChildPath $sourcefilespath) -LanguagePath (Join-Path -Path $sourcefolder -ChildPath '..\SourceLanguage2.txt') -Destination (Join-Path -Path $tempfolder2 -ChildPath $sourcefilespath) -LanguageId $RemoveLanguageId
            $result = Rename-Item -Path $resultfolder -NewName "$resultfolder 3" -Force
            #$result = Remove-Item -Path $resultfolder -Force -Recurse
            $result = Rename-Item -Path $tempfolder2 -NewName $resultfolder -Force
        }
        $result = New-Item -Path (Join-Path -Path $tempfolder2 -ChildPath $sourcefilespath) -ItemType directory -Force
        if (Test-Path -Path (Join-Path -Path $sourcefolder -ChildPath '..\TargetLanguage2.txt')) {
            Import-NAVApplicationObjectLanguage -Source (Join-Path -Path $resultfolder -ChildPath $sourcefilespath) -LanguagePath (Join-Path -Path $sourcefolder -ChildPath '..\TargetLanguage2.txt') -Destination (Join-Path -Path $tempfolder2 -ChildPath $sourcefilespath) -LanguageId $RemoveLanguageId
            $result = Rename-Item -Path $resultfolder -NewName "$resultfolder 4" -Force
            #$result = Remove-Item -Path $resultfolder -Force -Recurse
            $result = Rename-Item -Path $tempfolder2 -NewName $resultfolder -Force
        }
    }

    if (!$skipcopytorep) 
    {
        CreateGitMerge #set git to merge action, using ours strategy
        Write-Progress -Id 50 -Activity  'Mergin GIT repositories...' -CurrentOperation 'Copying result to the repository...'
        CreateResult($resultfolder)
    }

    Set-Location -Path $currentfolder.Path
}

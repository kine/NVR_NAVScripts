#import-module -Name Microsoft.Dynamics.Nav.Ide -Verbose
#. "Merge-NAVVersionListString script.ps1"

Add-Type -Language CSharp -TypeDefinition @"
  public enum VersionListMergeMode
  {
    SourceFirst,
    TargetFirst
  }
"@

function Get-VersionListModuleShortcut([string] $part)
{
    $index = $part.IndexOfAny("0123456789");
    if ($index -ge 1) {
      $result = @{'shortcut' = $part.Substring(0,$index);'version' = $part.Substring($index)};
    } else {
      $result = @{'shortcut' = $part;'version' = ''};
    }
    return $result;
}

function Get-VersionListHash([string] $versionlist)
{
  $hash = @{}
  $versionlistarray=$versionlist.Split(",");
  foreach ($element in $versionlistarray) {
    $moduleinfo = Get-VersionListModuleShortcut($element);
    $hash.Add($moduleinfo.shortcut,$moduleinfo.version);
  }
  return $hash;
}

function Merge-NAVVersionListString([string] $source,[string] $target,[string] $newversion,[VersionListMergeMode] $mode=[VersionListMergeMode]::SourceFirst) 
{
  if ($mode -eq [VersionListMergeMode]::TargetFirst) {
    $temp = $source;
    $source = $target;
    $target = $temp;
  }
  $result = "";
  $sourcearray=$source.Split(",");
  $targetarray=$target.Split(",");
  $sourcehash=Get-VersionListHash($source);
  $targethash=Get-VersionListHash($target);
  $newmoduleinfo=Get-VersionListModuleShortcut($newversion);
  foreach ($module in $sourcearray) {
    $actualversion = "";
    $moduleinfo = Get-VersionListModuleShortcut($module);
    if ($sourcehash[$moduleinfo.shortcut] -ge $targethash[$moduleinfo.shortcut]) {
      $actualversion = $sourcehash[$moduleinfo.shortcut];
    } else {
      $actualversion = $targethash[$moduleinfo.shortcut];
    }
    if ($moduleinfo.shortcut -eq $newmoduleinfo.shortcut) {
      $actualversion = $newmoduleinfo.version;
    }
    if ($result.Length -gt 0) {
      $result = $result + ",";
    }
    $result = $result + $moduleinfo.shortcut + $actualversion;
  }
  foreach ($module in $targetarray) {
    $moduleinfo = Get-VersionListModuleShortcut($module);
    if (!$sourcehash.ContainsKey($moduleinfo.shortcut)) {
        if ($result.Length -gt 0) {
          $result = $result + ",";
        }
        if ($moduleinfo.shortcut -eq $newmoduleinfo.shortcut) {
          $result = $result + $newversion;
        } else {
          $result = $result + $module;
        }
    }
  }
  return $result;
}

function ClearFolder($path)
{
    Remove-Item $path'\*' -Exclude ".*" -Recurse -Include "*.txt","*.conflict"
}

function Set-NAVModifiedObject($path)
{
    #Write-Host $input
    foreach ($modifiedfile in $input) {
        #Write-Host $modifiedfile.filename
        $filename = $path+"\"+$modifiedfile.filename
        #Write-Host $filename
        If (Test-Path ($filename)) {
            Set-NAVApplicationObjectProperty -target $filename -ModifiedProperty Yes
        }
    }
}

function Get-NAVModifiedObject($source)
{
    $result=@();
    $files = Get-ChildItem $source -Filter *.txt
    ForEach ($file in $files) {
        $lineno=0
        $content = Get-Content $file.FullName
        $objectproperties = Get-NAVApplicationObjectProperty -Source $file.FullName
        $resultfile = @{'filename'=$file.Name;'value'=$objectproperties.Modified}
        $object = New-Object PSObject -Property $resultfile
        $result += $object

    }
    return $result
}

function Merge-NAVObjectVersionList($modifiedfilename,$targetfilename,$resultfilename,$newversion)
{
    $ProgressPreference = 'SilentlyContinue'
    $modifiedproperty=Get-NAVApplicationObjectProperty -Source $modifiedfilename 
    $sourceproperty = Get-NAVApplicationObjectProperty -Source $targetfilename;
    #$targetproperty = Get-NAVApplicationObjectProperty -Source $resultfilename;

    $targetversionlist = Merge-NAVVersionListString -source $sourceproperty.VersionList -target $modifiedproperty.VersionList -mode SourceFirst -newversion $newversion
    #Write-Host 'Updating version list on '$filename' from '$sourceversionlist' and '$modifiedversionlist' to '$targetversionlist
    Set-NAVApplicationObjectProperty -Target $resultfilename -VersionListProperty $targetversionlist
    $ProgressPreference = 'Continue'
}

function Get-NAVDatabaseObjects($sourceserver,$sourcedb,$sourcefilefolder,$sourceclientfolder)
{
    ClearFolder($sourcefilefolder);
    $NavIde = $sourceclientfolder+'\finsql.exe';
    Write-Host 'Exporting Objects from '$sourceserver'\'$sourcedb'...';
    $exportresult = Export-NAVApplicationObject -Server $sourceserver -Database $sourcedb -Path $sourcefilefolder'.txt'
    Write-Host 'Splitting Objects...';
    $splitresult = Split-NAVApplicationObjectFile -Source $sourcefilefolder'.txt' -Destination $sourcefilefolder -Force
    Remove-Item $sourcefilefolder'.txt'
}

function Merge-NAVDatabaseObjects($sourceserver,$sourcedb,$sourcefilefolder,$sourceclientfolder,
                                  $modifiedserver,$modifieddb,$modifiedfilefolder,$modifiedclientfolder,
                                  $targetserver,$targetdb,$targetfilefolder,$targetclientfolder,
                                  $commonversionsource,$newversion)
{
    Write-Host 'Clearing target folder...';
    ClearFolder($targetfilefolder);

    if ($sourceserver) {
        Get-NAVDatabaseObjects -sourceserver $sourceserver -sourcedb $sourcedb -sourcefilefolder $sourcefilefolder -sourceclientfolder $sourceclientfolder
    }

    if ($modifiedserver) {
        Get-NAVDatabaseObjects -sourceserver $modifiedserver -sourcedb $modifieddb -sourcefilefolder $modifiedfilefolder -sourceclientfolder $modifiedclientfolder
    }

    $modifiedwithflag = Get-NAVModifiedObject -Source $modifiedfilefolder
    Write-Host 'Merging Objects...';

#<#
    $mergeresult = Merge-NAVApplicationObject -Original $commonversionsource -Modified $sourcefilefolder -Target $modifiedfilefolder -Result $targetfilefolder -PassThru -Force -DateTimeProperty FromTarget
    $merged = $mergeresult | Where-Object {$_.MergeResult -eq 'Merged'}
    Write-Host 'Merged:    '$merged.Count
    $inserted = $mergeresult | Where-Object {$_.MergeResult -eq 'Inserted'}
    Write-Host 'Inserted:  '$inserted.Count
    $deleted = $mergeresult | Where-Object {$_.MergeResult -EQ 'Deleted'}
    Write-Host 'Deleted:   '$deleted.Count
    $conflicts =$mergeresult | Where-Object {$_.MergeResult -EQ 'Conflict'}
    $identical = $mergeresult | Where-Object {$_.MergeResult -eq 'Identical'}

    Write-Host 'Conflicts: '$conflicts.Count
    Write-Host ''
    Write-Host 'Merging version list on merged files...'
    foreach ($merge in $merged) {
        $merge |ft
        if ($merge.Result.Filename -gt "") {
          $file = Get-ChildItem $merge.Result;
          $filename = $file.Name;
          Merge-NAVObjectVersionList -modifiedfilename $sourcefilefolder'\'$filename -targetfilename $modifiedfilefolder'\'$filename -resultfilename $merge.Result.FileName -newversion $newversion
        }
    }

    if ($deleted.Count -gt 0) {
        Write-Host '********Delete these objects in target DB:'
        foreach ($delobject in $deleted) {
            Write-Host $delobject.ObjectType $delobject.Id
            #Set-NAVApplicationObjectProperty -Target $delobject.Result -VersionListProperty 'DELETE'
        }
    }
#>
    write-Host 'Deleting excluded objects...'
    Remove-Item $targetfilefolder'\MEN1010.TXT'
    Remove-Item $targetfilefolder'\MEN1030.TXT'
    write-Host 'Deleting Identical objects...'
    Remove-Item $identical.Result
    write-Host 'Restoring Modfied flags...'
    $modifiedwithflag | Set-NAVModifiedObject -path $targetfilefolder
    Write-Host 'Joining Objects...';
    $joinresult = Join-NAVApplicationObjectFile -Source $targetfilefolder -Destination $targetfilefolder'.txt' -Force
#>
    if ($targetserver) {
        Write-Host 'Importing Objects...';
        Import-NAVApplicationObject -path $targetfilefolder'.txt' -Server $targetserver -Database $targetdb -Confirm
        Write-Host 'Compiling Objects...';
        $compileoutput = Compile-NAVApplicationObject -Server $targetserver -Database $targetdb
    }
    #return $mergeresult
}

$client = "c:\Program Files (x86)\Microsoft Dynamics NAV\71\RoleTailored Client 36344\";
$NavIde = "c:\Program Files (x86)\Microsoft Dynamics NAV\71\RoleTailored Client 36344\finsql.exe";

#$result=Merge-NAVDatabaseObjects -sourceserver devel -sourcedb NVR2013R2_CSY -sourcefilefolder source -sourceclientfolder $client `
#-modifiedserver devel -modifieddb Adast2013 -modifiedfilefolder modified -modifiedclientfolder $client `
#-targetserver devel -targetdb Adast2013 -targetfilefolder target -targetclientfolder $client -commonversionsource common

#Get-NAVDatabaseObjects -sourceserver devel -sourcedb NVR2013R2_CSY -sourcefilefolder d:\ksacek\TFS\Realizace\NAV\NAV2013R2\CSY_NVR_Essentials\ -sourceclientfolder $client
Export-ModuleMember -Function Merge-NAVVersionListString
Export-ModuleMember -Function Merge-NAVObjectVersionList
Export-ModuleMember -Function Merge-NAVDatabaseObjects
Export-ModuleMember -Function Get-NAVDatabaseObjects

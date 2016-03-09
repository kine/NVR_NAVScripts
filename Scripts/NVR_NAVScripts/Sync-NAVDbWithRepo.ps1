<#
        .Synopsis
        Expand the CU archive to selected folder
        .DESCRIPTION
        Expand the downloaded CU archive to selected folder. Targetpathmask can include variables $version $langcode $BuildNo and $formatedCUNo to 
        create target folder.

        .EXAMPLE
        Get-NAVCumulativeUpdateFile -langcodes 'CSY','intl' -versions '2013 R2','2015','2016' | Expand-NAVCumulativeUpdateFile -targetpathmask '\\server\Microsoft\NAV\Dynamics_NAV_$($version)_$langcode\BUILD$($BuildNo)_CU$formatedCUNo'

        .EXAMPLE
        Expand-NAVCumulativeUpdateFile -filename '488130_intl_i386_zip.exe' -targetpathmask 'c:\NAV\NAV2015\CU2'
#>
function Sync-NAVDbWithRepo
{
    [CmdletBinding()]
    param (
        #GIT Repository path
        [Parameter(Mandatory = $true,ValueFromPipelinebyPropertyName = $true)]
        [String]$Repository='.',        
        #Object files from which to update. Should be complete set of objects
        [Parameter(Mandatory = $true,ValueFromPipelinebyPropertyName = $true)]
        [String]$Files,
        #SQL Server used for creating the database. Default is localhost (.)
        [Parameter(ValueFromPipelinebyPropertyName = $True)]
        [string] $Server = '.',
        [Parameter(Mandatory = $true,ValueFromPipelinebyPropertyName = $True)]
        #Name for the SQL Db created.
        [string] $Database,
        #Name of the NAV Server
        [Parameter(ValueFromPipelinebyPropertyName = $true)]
        [String]$NavServerName,
        #Name of the NAV Server Instance
        [Parameter(ValueFromPipelinebyPropertyName = $true)]
        [String]$NavServerInstance
               
    )
    Push-Location
    Set-Location -Path $Repository
    #test that the repository is clean, without uncommited changes
    $gitstatus = git.exe status -s
    if ($gitstatus -gt '') 
    {
        Write-Host $gitstatus
        Throw 'There are uncommited changes!!!'
    }
    
    $Filter='Name=<>#DELETE*'    
    $AllFile=(Join-Path -Path '.\' -ChildPath 'all.txt')
    
    Import-NAVModelTool
    $LogFolder = (Join-Path $env:TEMP 'NAVSyncLog')
        
    Write-InfoMessage 'Exporting all from DB to compare with repo...'
    $result = Export-NAVApplicationObject2 -Filter $Filter -DatabaseServer $Server -DatabaseName $Database -LogPath $LogFolder -Path $AllFile -ExportTxtSkipUnlicensed
    
    #-NavIde (Get-NAVIde) -NavServerName $NavServerName -NavServerInstance $NavServerInstance

    #Remove-Item $setup.Files -Force
    if ($Files.Contains(':')) {
        $TargetFolder = Split-Path $Files
    } else {
        $TargetFolder = Split-Path ((Join-Path (Get-Location) $Files))
    }
    Write-InfoMessage "Splitting the file into $Files..."
    Split-NAVApplicationObjectFile -Source $AllFile -Destination $TargetFolder -Force
    
    Write-InfoMessage "Removing the file $AllFile..."
    
    Remove-Item $AllFile
    
    Write-InfoMessage 'Getting the changes...'
    $changes = git.exe status --porcelain | ForEach-Object {if ($_.Substring(0,2) -ne '??') {Write-Output $_.Substring(3)}} | Where-Object {($_ -notlike '*MEN1010.TXT') -and ($_ -notlike '*MEN1030.TXT')}
    Write-InfoMessage "$($changes.Count) changed objects detected"
        
    Write-InfoMessage 'Reseting the repository...'
    $result = git.exe reset --hard --quiet 
    Write-InfoMessage 'Reseting untracked files...'
    $result = git.exe clean -fd --quiet
    
    Write-InfoMessage 'Importing changed objects...'
    if ($changes.Count -gt 0) {
        Import-NAVApplicationObject2 -Path $changes -DatabaseName $Database -DatabaseServer $Server -LogPath $LogFolder -ImportAction Overwrite -SynchronizeSchemaChanges Force -NavServerName $NavServerName -NavServerInstance $NavServerInstance
    }
    
    #Compile-NAVApplicationObject2 -DatabaseName $Database -DatabaseServer $Server -LogPath $LogFolder -Filter 'Compiled=0' -SynchronizeSchemaChanges Force -NavServerName $NavServerName -NavServerInstance $NavServerInstance    
    #Write-InfoMessage 'Compiling system tables...'
    #NVR_NAVScripts\Compile-NAVApplicationObjectMulti -Filter 'Type=1&ID=2000000004..' -Server $Server -Database $Database -NavIde (Get-NAVIde) -SynchronizeSchemaChanges No -NavServerName $NavServerName -NavServerInstance $NavServerInstance
    #Write-InfoMessage 'Compiling menusuites...'
    #NVR_NAVScripts\Compile-NAVApplicationObjectMulti -Filter 'Type=7&Compiled=0' -Server $Server -Database $Database -NavIde (Get-NAVIde) -SynchronizeSchemaChanges No -NavServerName $NavServerName -NavServerInstance $NavServerInstance
    #Write-InfoMessage 'Compiling uncompiled objects...'
    #NVR_NAVScripts\Compile-NAVApplicationObjectMulti -Filter 'Compiled=0' -Server $Server -Database $Database -NavIde (Get-NAVIde) -SynchronizeSchemaChanges Force -NavServerName $NavServerName -NavServerInstance $NavServerInstance
    Pop-Location
}
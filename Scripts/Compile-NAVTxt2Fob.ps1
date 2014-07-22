<#
    .SYNOPSIS
    Create NAV DB from SQL backup file, import selected FOB file, Import selected TXT file, compile them and export all objects into target FOB file

    .DESCRIPTION
    The Compile-NAVTxt2Fob script is atomatically creating FOB files from TXT files. Script will create new Database, NAV instance, import base FOB (e.g. with Cumulative Update), import TXT files, compile them and than export all objects into FOB and remove the NAV Instance.

    .INPUTS
    None
    You cannot pipe input to this function.

    .OUTPUTS
    None

    .EXAMPLE
    Compile-NAVTxt2Fob -SourceTxtFiles '*.txt' -BaseFob 'URObjects.W1.36897.fob' -ResultFob 'MyNewObjects.Fob' -LicenseFile 'c:\fin.flf' -DBBackupFile 'DemoData.bak'
    This command imports all *.txt files into DB createdfrom DemoData.Bak and UROBjects.W1.36897 and export them into MyNewObjects.fob file. During the process, fin.flf is used as a license.
#>
param (
    #SQL Server used for creating the database. Default is localhost (.)
    [string] $Sqlserver='.',

    #Name for the SQL Db created. Default is 'merge'
    [string] $Dbname='merge',

    #Source txt files for import
    [string] $SourceTxtFiles,

    #FOB file imported before the txt files are imported. Could update the objects stored in the DB Backup file to newer version.
    [string] $BaseFob,

    #FOB file to which the result will be exported
    [string] $ResultFob,

    #FLF file used to start the NAV Service tier. Must have enough permissions to import the txt files.
    [string] $LicenseFile,

    #Path of the client used for creating the DB, importing and exporting objects and compilation of them.
    [string] $NavIde='c:\Program Files (x86)\Microsoft Dynamics NAV\71\RoleTailored Client\finsql.exe',

    #File of the NAV SQL backup for creating new NAV database. Used as base for importing the objects.
    [string] $DbBackupFile,

    #Folder into which the DB will be stored
    [string] $DbFolder='',

    #Folder used for output of log files during import and compilation
    [string] $LogFolder='LOG\',

    #Could be used when "restarting" the script to skip db creation and continue directly from TXT import
    [bool] $ContinueFromTxt=$false,

    #Send emails when finished and prepared for manual step
    [bool] $SendEmail=$false,

    #SMTP Server name
    [string] $SMTPServer='exchange',

    #Skip manual check
    [bool] $SkipManual=$false
    )


#Import-Module -Global Microsoft.Dynamics.Nav.Ide -ArgumentList $NavIde -Force 
Import-Module -Global 'C:\Program Files\Microsoft Dynamics NAV\71\Service\NavAdminTool.ps1' -WarningAction SilentlyContinue | Out-Null
Import-Module -Global $PSScriptRoot\NVR_NAVScripts -Force -WarningAction SilentlyContinue | Out-Null
Import-Module -Global $PSScriptRoot\CommonPSFunctions -Force -WarningAction SilentlyContinue | Out-Null

if ($ContinueFromTxt -eq $false) {
    Write-Progress -Activity 'Creating new database...'
#    New-NAVDatabase -Database merge -Server $sqlserver
    Microsoft.Dynamics.Nav.Management\New-NAVDatabase -DatabaseName merge -FilePath $DbBackupFile -DatabaseServer localhost -Force -DataFilesDestinationPath $DbFolder -LogFilesDestinationPath $DbFolder | Out-Null

    Write-Progress -Activity 'Creating new server instance...'
    New-NAVServerInstance -DatabaseServer $Sqlserver -DatabaseName $Dbname -ServerInstance merge -ManagementServicesPort 7045 | Out-Null
    Start-Service -Name ('MicrosoftDynamicsNavServer$merge')

    Write-Progress -Activity 'Importing License...'
    Import-NAVServerLicense -LicenseFile $LicenseFile -Database NavDatabase -ServerInstance merge -WarningAction SilentlyContinue 
    Stop-Service -Name ('MicrosoftDynamicsNavServer$merge')
    Start-Service -Name ('MicrosoftDynamicsNavServer$merge')

    Write-Progress -Activity 'Importing FOB File...'
    Import-NAVApplicationObjectFiles -Files $BaseFob -Server $Sqlserver -Database $Dbname -LogFolder $LogFolder -NavIde $NavIde
}
$ScriptStartTime = Get-Date
Write-Output "Started at $ScriptStartTime"

Write-Progress -Activity 'Iporting TXT Files...'
Import-NAVApplicationObjectFiles -Files $SourceTxtFiles -Server $Sqlserver -Database $Dbname -LogFolder $LogFolder -NavIde $NavIde

Write-Progress -Activity 'Compiling System objects...'
Compile-NAVApplicationObject -Server $Sqlserver -Database $Dbname -Filter 'Type=Table;Id=2000000000..' -LogFolder $LogFolder -NavIde $NavIde
Write-Progress -Activity 'Compiling objects...'
Compile-NAVApplicationObjectFiles -Files $SourceTxtFiles -Server $Sqlserver -Database $Dbname -LogFolder $LogFolder -NavIde $NavIde

$ScriptEndTime = Get-Date
Write-Output "Ended at $ScriptEndTime"

if (!$SkipManual) {

    if ($SendEmail) {
        $myemail = Get-MyEmail
        Send-EmailToMe -Subject 'Compile-NAVTxt2FOB' -Body "Import and compilation done..." -SMTPServer $SMTPServer -FromEmail $myemail
    }

    Write-Progress -Activity 'Manual Check of uncompiled objects...'

    Write-Output 'Check the object in opened client. Than close the client.'
    $params = "ServerName=$Sqlserver`,Database=`"$Dbname`""
    & $NavIde $params | Write-Output
}

Write-Progress -Activity 'Exporting FOB File...'
NVR_NAVScripts\Export-NAVApplicationObject -Server $Sqlserver -Database $Dbname -Path $ResultFob -Force -Filter 'Compiled=1' -NavIde $NavIde -LogFolder $LogFolder

Write-Progress -Activity 'Removing server instance...'
Stop-Service -Name ('MicrosoftDynamicsNavServer$merge') -Force
Remove-NAVServerInstance -ServerInstance merge -Force

Write-Progress -Activity 'Removing SQL DB...'
Remove-SQLDatabase -Server $Sqlserver -Database $Dbname


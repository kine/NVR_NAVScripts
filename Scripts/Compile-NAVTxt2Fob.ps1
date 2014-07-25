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
    [Parameter(Mandatory=$true)]
    [String] $SourceTxtFiles,

    #FOB file imported before the txt files are imported. Could update the objects stored in the DB Backup file to newer version.
    [Parameter(Mandatory=$true)]
    [string] $BaseFob,

    #FOB file to which the result will be exported
    [Parameter(Mandatory=$true)]
    [string] $ResultFob,

    #FLF file used to start the NAV Service tier. Must have enough permissions to import the txt files.
    [Parameter(Mandatory=$true)]
    [string] $LicenseFile,

    #Path of the client used for creating the DB, importing and exporting objects and compilation of them.
    [string] $NavIde='',

    #File of the NAV SQL backup for creating new NAV database. Used as base for importing the objects.
    [Parameter(Mandatory=$true)]
    [string] $DbBackupFile,

    #Folder into which the DB will be stored
    [string] $DbFolder='',

    #Folder used for output of log files during import and compilation
    [string] $LogFolder='LOG\',

    #Could be used when "restarting" the script to skip db creation and continue directly from TXT import
    [switch] $ContinueFromTxt,

    #Send emails when finished and prepared for manual step
    [switch] $SendEmail,

    #SMTP Server name
    [string] $SMTPServer='exchange',

    #Skip manual check
    [switch] $SkipManual
    )

if (!($env:PSModulePath -like "*;$PSScriptRoot*")) {
    $env:PSModulePath = $env:PSModulePath + ";$PSScriptRoot"
}

Import-NAVAdminTool
Import-Module -Global NVR_NAVScripts

try {

    if ($NavIde -eq '') {
      $NavIde = Get-NAVIde
    }

    if ($ContinueFromTxt -eq $false) {
        New-NAVLocalApplication -Server $SqlServer -Database $Dbname -BaseFob $BaseFob -License $LicenseFile -DbBackupFile $DbBackupFile -ServiceInstance merge
    }

    $ScriptStartTime = Get-Date
    Write-Output "Started at $ScriptStartTime"


    Write-Progress -Activity 'Iporting TXT Files...'
    #Import-NAVApplicationObjectFiles -Files $SourceTxtFiles -Server $Sqlserver -Database $Dbname -LogFolder $LogFolder -NavIde $NavIde
    . $PSScriptRoot\Update-NAVApplicationFromTxt.ps1 -Files $SourceTxtFiles -Server $Sqlserver -Database $Dbname -Compile -SkipDeleteCheck
    Write-Verbose "TXT Objects imported"

    Write-Progress -Activity 'Compiling System objects...'
    Compile-NAVApplicationObject -Server $Sqlserver -Database $Dbname -Filter 'Type=Table;Id=2000000000..' -LogFolder $LogFolder -NavIde $NavIde
    Write-Verbose "System Objects compiled"
    Write-Progress -Activity 'Compiling objects...'
    Compile-NAVApplicationObjectFiles -Files $SourceTxtFiles -Server $Sqlserver -Database $Dbname -LogFolder $LogFolder -NavIde $NavIde
    Write-Verbose "Objects compiled"

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
    Write-Verbose "Object exported as FOB"
}
Finally
{
    Remove-NAVLocalApplication -Server $Sqlserver -Database $Dbname -ServiceInstance merge
}

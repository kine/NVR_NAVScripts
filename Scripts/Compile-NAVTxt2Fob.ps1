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
    Compile-NAVTxt2Fob -FileName '*.txt' -BaseFob 'URObjects.W1.36897.fob' -ResultFob 'MyNewObjects.Fob' -LicenseFile 'c:\fin.flf' -DBBackupFile 'DemoData.bak'
    This command imports all *.txt files into DB createdfrom DemoData.Bak and UROBjects.W1.36897 and export them into MyNewObjects.fob file. During the process, fin.flf is used as a license.
#>
param (
    #SQL Server used for creating the database. Default is localhost (.)
    [Parameter(ValueFromPipelinebyPropertyName = $True)]
    [string] $Server = '.',

    [Parameter(ValueFromPipelinebyPropertyName = $True)]
    #Name for the SQL Db created. Default is 'merge'
    [string] $Database = 'merge',

    #Source txt files for import
    [Parameter(Mandatory = $True,ValueFromPipelinebyPropertyName = $True)]
    [String] $FileName,

    #FOB file imported before the txt files are imported. Could update the objects stored in the DB Backup file to newer version.
    [Parameter(ValueFromPipelinebyPropertyName = $True)]
    [string] $BaseFob,

    #FOB file to which the result will be exported
    [Parameter(Mandatory = $True,ValueFromPipelinebyPropertyName = $True)]
    [string] $ResultFob,

    #FLF file used to start the NAV Service tier. Must have enough permissions to import the txt files.
    [Parameter(ValueFromPipelinebyPropertyName = $True)]
    [string] $LicenseFile,

    #Path of the client used for creating the DB, importing and exporting objects and compilation of them.
    [Parameter(ValueFromPipelinebyPropertyName = $True)]
    [string] $NavIde = '',

    #File of the NAV SQL backup for creating new NAV database. Used as base for importing the objects.
    [Parameter(Mandatory = $True,ValueFromPipelinebyPropertyName = $True)]
    [string] $DbBackupFile,

    #Folder into which the DB will be stored
    [Parameter(ValueFromPipelinebyPropertyName = $True)]
    [string] $DbFolder = '',

    #Folder used for output of log files during import and compilation
    [Parameter(ValueFromPipelinebyPropertyName = $True)]
    [string] $LogFolder = 'LOG\',

    #Could be used when "restarting" the script to skip db creation and continue directly from TXT import
    [Parameter(ValueFromPipelinebyPropertyName = $True)]
    [switch] $ContinueFromTxt,

    #Send emails when finished and prepared for manual step
    [Parameter(ValueFromPipelinebyPropertyName = $True)]
    [switch] $SendEmail,

    #SMTP Server name
    [Parameter(ValueFromPipelinebyPropertyName = $True)]
    [string] $SMTPServer = 'exchange',

    #Skip manual check
    [Parameter(ValueFromPipelinebyPropertyName = $True)]
    [switch] $SkipManual
)

Begin {
    if (!($env:PSModulePath -like "*;$PSScriptRoot*")) 
    {
        $env:PSModulePath = $env:PSModulePath + ";$PSScriptRoot"
    }
    Import-Module -Global -Name CommonPSFunctions
    Import-NAVAdminTool
    Import-Module -Global -Name NVR_NAVScripts -DisableNameChecking
}

Process {
    try 
    {
        if ($NavIde -eq '') 
        {
            $NavIde = Get-NAVIde
        }

        if (!$ContinueFromTxt) 
        {
            New-NAVLocalApplication -Server $Server -Database $Database -BaseFob $BaseFob -LicenseFile $LicenseFile -DbBackupFile $DbBackupFile -ServerInstance merge -TargetPath $DbFolder
        }

        $ScriptStartTime = Get-Date
        Write-Output -InputObject "Started at $ScriptStartTime"


        Write-Progress -Activity 'Importing TXT Files...'
        #Import-NAVApplicationObjectFiles -Files $FileName -Server $Server -Database $Database -LogFolder $LogFolder -NavIde $NavIde
        . $PSScriptRoot\Update-NAVApplicationFromTxt.ps1 -Files $FileName -Server $Server -Database $Database -Compile -SkipDeleteCheck
        Write-Verbose -Message 'TXT Objects imported'

        Write-Progress -Activity 'Compiling System objects...'
        Compile-NAVApplicationObject -Server $Server -Database $Database -Filter 'Type=Table;Id=2000000000..' -LogFolder $LogFolder -NavIde $NavIde
        Write-Verbose -Message 'System Objects compiled'
        Write-Progress -Activity 'Compiling objects...'
        Compile-NAVApplicationObjectFilesMulti -files $FileName -Server $Server -Database $Database -LogFolder $LogFolder -NavIde $NavIde -AsJob
        Write-Verbose -Message 'Objects compiled'

        $ScriptEndTime = Get-Date
        Write-Output -InputObject "Ended at $ScriptEndTime"

        if (!$SkipManual) 
        {
            if ($SendEmail) 
            {
                $myemail = Get-MyEmail
                Send-EmailToMe -Subject 'Compile-NAVTxt2FOB' -Body 'Import and compilation done...' -SMTPServer $SMTPServer -FromEmail $myemail
            }

            Write-Progress -Activity 'Manual Check of uncompiled objects...'

            Write-Output -InputObject 'Check the object in opened client. Than close the client.'
            $params = "ServerName=$Server`,Database=`"$Database`""
            & $NavIde $params | Write-Output
        }
        Write-Progress -Activity 'Exporting FOB File...'
        NVR_NAVScripts\Export-NAVApplicationObject -Server $Server -Database $Database -Path $ResultFob -Force -Filter 'Compiled=1' -NavIde $NavIde -LogFolder $LogFolder
        Write-Verbose -Message 'Object exported as FOB'
    }
    Finally
    {
        Remove-NAVLocalApplication -Server $Server -Database $Database -ServerInstance merge
    }
}

End {
}
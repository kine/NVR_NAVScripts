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
    #LogFolder
    [Parameter(Mandatory=$true,ValueFromPipelinebyPropertyName=$True)]
    [String]$LogFolder
)

try 
{
    Import-Module CommonPSFunctions -Force

    $ProgressPreference="SilentlyContinue"
    . 'c:\Program Files\WindowsPowerShell\Modules\Update-NAVApplicationFromTxt.ps1' -Files $Files -Server $Server -Database $Database -LogFolder $LogFolder
    $ProgressPreference="Continue"
} catch
{
    $errors += $_.Exception.Message
    Write-Error "Exception: $($_.Exception.Message)"
}
finally {
}
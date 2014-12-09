<#
.Synopsis
   Read the Profile metadata and export all CaptionML strings for translation
.DESCRIPTION
   Read the Profile metadata and export all CaptionML strings for translation. Result is in outputed as an array of value pairs "value","newvalue"
.EXAMPLE
   Export-NAVProfileCaptionML.ps1 -Server localhost -Database mydb | Export-Csv -Path ToTranslate.csv
.EXAMPLE
   Export-NAVProfileCaptionML.ps1 -Server localhost -Database mydb -Filter MYPROFILE | Export-Csv -Path ToTranslate.csv -Encoding UTF8 -Delimiter ";"
#>
[CmdletBinding()]
param (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string]$Server,
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [string]$Database,
        [Parameter(ValueFromPipelineByPropertyName=$true,
                   Position=2)]
        [string]$Filter
)


Import-Module CommonPSFunctions

if ($Filter -gt "") {
    $metadata = Get-SQLCommandResult -Server $server -Database $database -Command "select * from [Profile Metadata] where [Profile ID]='$Filter'"
} else {
    $metadata = Get-SQLCommandResult -Server $server -Database $database -Command "select * from [Profile Metadata]"
}

$i=0

$strings=@{}

foreach ($delta in $metadata) {
    $i++
    if ($delta["Page Metadata Delta"] -ne $null) {
        $blobdata = Get-NAVBlobToString -CompressedByteArray ($delta["Page Metadata Delta"])
        [xml]$deltaxml = $blobdata.Data
        $captions=$deltaxml.SelectNodes("/descendant::*[@name='CaptionML']")
        foreach ($caption in $captions) {

            if ($caption.value -gt "") {
                if (!$strings.ContainsKey($caption.value)) {
                    Write-Verbose "Saving value $($caption.value)..."
                    $strings.Add($caption.value,'')
                    $object=@{'value'=[string]$caption.value;'newvalue'=''}
                    $output = New-Object PSObject -Property $object
                    Write-Output $output
                } 
            }
        }
    }
}

Write-Host "$($strings.Count) strings for translation..."
#Write-Host "Exporting to file..."
#$strings.GetEnumerator() | Export-Csv -Path "e:\temp\profiletranslation.csv" -Encoding UTF8 -Delimiter ';'
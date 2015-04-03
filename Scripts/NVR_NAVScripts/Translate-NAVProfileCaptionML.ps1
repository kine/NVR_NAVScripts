<#
    .Synopsis
    Read the Profile metadata and translate all CaptionML based on input array of value pairs "value","newvalue"
    .DESCRIPTION
    Read the Profile metadata and translate all CaptionML based on input array of value pairs "value","newvalue". 
    First it reads the input and store it to Hash table, from which the traslation is done. If CaptionML is found in the "value" somewhere, the
    "newvalue" replace it. Result is stored back to the Profile Metadata table
    .EXAMPLE
    Import-Csv -Path ToTranslate.csv | Translate-NAVProfileCaptionML.ps1 -Server localhost -Database mydb
    .EXAMPLE
    Import-Csv -Path ToTranslate.csv -Encoding UTF8 -Delimiter ";" | Translate-NAVProfileCaptionML.ps1 -Server localhost -Database mydb -Filter MYPROFILE
#>
function Translate-NAVProfileCaptionML
{
    [CmdletBinding()]
    param (
        [parameter(ValueFromPipeline = $true)]
        $translations,
        [Parameter(Mandatory = $true,
        Position = 0)]
        [string]$Server,
        [Parameter(Mandatory = $true,
        Position = 0)]
        [string]$Database,
        [Parameter(Position = 0)]
        [string]$Filter,
        [switch]$Test
    )
    Begin
    {

        Import-Module -Name CommonPSFunctions

        if ($Filter -gt '') 
        {
            $metadata = Get-SQLCommandResult -Server $Server -Database $Database -Command "select * from [Profile Metadata] where [Profile ID]='$Filter'"
        }
        else 
        {
            $metadata = Get-SQLCommandResult -Server $Server -Database $Database -Command 'select * from [Profile Metadata]'
        }

        $i = 0

        $strings = @{}
    }

    Process
    {
        foreach ($entry in $translations) 
        {
            if (!$strings.ContainsKey($entry.value)) 
            {
                $strings.Add($entry.value,$entry.newvalue)
            }
        }
    }
    End {
        $totalcount = $metadata.Count
        foreach ($delta in $metadata) 
        {
            Write-Progress -Activity 'Processing profile' -PercentComplete (($i/$totalcount)*100) -CurrentOperation $delta.'Profile ID'
            $i++
            $changed = $false
            if ($delta['Page Metadata Delta'] -ne $null) 
            {
                $blobdata = Get-NAVBlobToString -CompressedByteArray ($delta['Page Metadata Delta'])
                [xml]$deltaxml = $blobdata.Data
                $captions = $deltaxml.SelectNodes("/descendant::*[@name='CaptionML']")
                foreach ($caption in $captions) 
                {
                    if ($caption.value -gt '') 
                    {
                        if (!$strings.ContainsKey($caption.value)) 
                        {
                            Write-Host -Object "Missing translation for $($caption.value)..."
                            $strings.Add($caption.value,'')
                            $object = @{
                                'value'  = [string]$caption.value
                                'newvalue' = ''
                            }
                            $output = New-Object -TypeName PSObject -Property $object
                            Write-Output -InputObject $output
                        }
                        else 
                        {
                            if (($strings[$caption.value] -gt '') -and ($strings[$caption.value] -ne $caption.value)) 
                            {
                                Write-Verbose -Message "Setting new value $($strings[$caption.value]) for $($caption.value)..."
                                $caption.value = $strings[$caption.value]
                                $changed = $true
                            }
                        }
                    }
                }
                if (!$Test) 
                {
                    if ($changed) 
                    {
                        $newvalue = Get-StringToNAVBlob -MagicConstant $blobdata.MagicConstant -Data $deltaxml.OuterXml

                        $SqlConnection = New-Object -TypeName System.Data.SqlClient.SqlConnection
                        $SqlConnection.ConnectionString = "Server = $Server; Database = $Database; Integrated Security = True"
 
                        $SqlCmd = New-Object -TypeName System.Data.SqlClient.SqlCommand
                        $SqlCmd.CommandText = 'update [Profile Metadata] set [Page Metadata Delta]=@metadata where [Profile ID]=@profileid and [Page ID]=@pageid and [Personalization ID]=@personalizationid'
                        $SqlCmd.Connection = $SqlConnection
                        $SqlCmd.Parameters.Add('@metadata',[System.Data.SqlDbType]::Image,$newvalue.Length).Value = [byte[]]$newvalue
                        $SqlCmd.Parameters.Add('@profileid',[System.Data.SqlDbType]::NVarChar,20).Value = $delta.'Profile ID'
                        $SqlCmd.Parameters.Add('@pageid',[System.Data.SqlDbType]::Int).Value = $delta.'Page ID'
                        $SqlCmd.Parameters.Add('@personalizationid',[System.Data.SqlDbType]::NVarChar,40).Value = $delta.'Personalization ID'
                        $SqlConnection.Open()
                        $result = $SqlCmd.ExecuteNonQuery()
                        $SqlConnection.Close()
                    }
                }
            }
        }
    }
}

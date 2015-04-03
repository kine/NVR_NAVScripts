<#
    .SYNOPSIS
    Check for non-existing trigger names in the profile metadata and correct them

    .DESCRIPTION
    The Fix-NAVProfileTriggerNames will search for non-existing trigger names in the profile metadata and will correct them to the actual trigger names.
    You need to do that when you change the Action name after you have configured the Action in some profile.

    .INPUTS
    Server and Database
    Name of the SQL Server and the SQL Database over which the check is performed

    .OUTPUTS
    None

    .EXAMPLE
    Fix-NAVProfileTriggerNames.ps1 -Server localhost -Database myNAVdb
    This command will fix all profiles on server localhost in myNAVdb database
#>
function Fix-NAVProfileTriggerNames
{
    param(
        [parameter(ValueFromPipelinebyPropertyName = $True,Mandatory = $True)]
        [string]$Server,
        [parameter(ValueFromPipelinebyPropertyName = $True,Mandatory = $True)]
        [string]$Database,
        [parameter(ValueFromPipelinebyPropertyName = $True,Mandatory = $True)]
        [switch]$Test
    )

    $metadata = Get-SQLCommandResult -Server $Server -Database $Database -Command 'select * from [Profile Metadata]' # where [Profile ID]='SLUŽBY RAPIDSTART' and [Page ID]=116
    $totalcount = $metadata.Count
    $i = 0
    foreach ($delta in $metadata) 
    {
        $i++
        Write-Progress -Activity 'Processing profile' -PercentComplete (($i/$totalcount)*100) -CurrentOperation $delta.'Profile ID'
        $modified = $false
        if ($delta['Page Metadata Delta'] -ne $null) 
        {
            #decompress the data from the BLOB
            $blobdata = Get-NAVBlobToString -CompressedByteArray ($delta['Page Metadata Delta'])

            #take the data and retype them to XML
            [xml]$deltaxml = $blobdata.Data

            #find all triggers
            $nodes = $deltaxml.SelectNodes("/descendant::*[@name='Trigger']")
            foreach ($node in $nodes)
            {
                #get the actual trigger name
                $triggername = $node.SelectSingleNode('Attributes/Attribute[@name="Name"]/@value')

                #read the object metadata for the page
                $objectmetadata = Get-SQLCommandResult -Server $Server -Database $Database -Command "select * from [Object Metadata] where [Object ID]=$($delta.'Page ID') and [Object Type]=8"

                foreach ($om in $objectmetadata) 
                {
                    if ($om['Metadata'] -ne $null) 
                    {
                        #decompress the metadata
                        $odata = Get-NAVBlobToString -CompressedByteArray ($om['Metadata'])
                        #retype to xml
                        [xml]$oxml = $odata.Data

                        #find trigger with the name from profile
                        $result = $oxml.SelectNodes("/descendant::*[@TriggerType='OnAction' and @Name=`'$($triggername.Value)`']")

                        #if not found, fix it
                        if ($result.Count -eq 0) 
                        {
                            #read the Action name from the profile
                            $actionname = $node.SelectSingleNode('../../Attributes/Attribute[@name="Name"]').value

                            #create ID from the Action name
                            $ID = $actionname.Replace('Action','')

                            #find the trigger for the ID in the metadata
                            $newtriggername = $oxml.SelectSingleNode("/descendant::*[@ID=`'$ID`']").Trigger.Name
                            Write-Host -Object "$($delta.'Profile ID') $($delta.'Page ID') $($delta.'Personalization ID') $($triggername.Value) $actionname $newtriggername"

                            #if Trigger name found, fix it
                            if ($newtriggername -gt '') 
                            {
                                $triggername.Value = $newtriggername
                                $modifed = $True
                            }
                        }
                    }
                }
            }
            if (!$Test) 
            {
                #save modified XML back to the NAV BLOB
                if ($modifed) 
                {
                    #compress the data with original Magic Constant
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

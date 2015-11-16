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
function Expand-NAVCumulativeUpdateFile
{
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName)]
        $filename,
        [Parameter(ValueFromPipelineByPropertyName)]
        $version,
        [Parameter(ValueFromPipelineByPropertyName)]
        $langcode,
        [Parameter(ValueFromPipelineByPropertyName)]
        $CUNo,
        #Example: '\\server\Microsoft\NAV\Dynamics_NAV_$($version)_$langcode\BUILD$($BuildNo)_CU$formatedCUNo'
        #You can use $version $langcode $BuildNo and $formatedCUNo to create the path mask
        [Parameter(ValueFromPipelineByPropertyName)]
        $targetpathmask
    )
            
    begin {
        $null = Add-Type -AssemblyName System.IO.Compression.FileSystem 
    }
    process {
        $archive = [io.compression.zipfile]::OpenRead($filename)
        $CUArchive = $archive.Entries | Where-Object {$_.Name -match '.zip'}
        $BuildNo = $CUArchive.Name.Split('.')[3]
        Write-Host "Build no. is $BuildNo" -ForegroundColor Green
    
        $null = $_ | Add-Member -type NoteProperty -name build -value $BuildNo -ErrorAction SilentlyContinue
        
        if ($langcode -eq 'intl') {
            $langcode = 'W1'
        }
        $formatedCUNo = '{0:D2}' -f [int]$CUNo
        #$buildpath = Join-Path (Join-Path $targetpath "Dynamics_NAV_$($version)_$langcode") "BUILD$($BuildNo)_CU$formatedCUNo"
        $buildpath = $ExecutionContext.InvokeCommand.ExpandString($targetpathmask)
        Write-Host "Creating target folder $buildpath" -ForegroundColor Green
        
        $null = New-Item -Path $buildpath  -ItemType Directory
        
        Write-Host "Extracting $filename into $buildpath" -ForegroundColor Green
        [io.compression.zipfile]::ExtractToDirectory($filename,$buildpath)

        $DVDArchive = (Get-ChildItem -Path $buildpath -Filter *.zip).FullName
        $dvdpath = Join-path $buildpath 'DVD'
        
        Write-Host "Extracting DVD $DVDArchive into $dvdpath" -ForegroundColor Green
        [io.compression.zipfile]::ExtractToDirectory($DVDArchive,$dvdpath)

        $null = $_ | Add-Member -type NoteProperty -name buildpath -value $buildpath -ErrorAction SilentlyContinue
                        
        Write-Output $_
    }
    end{
    }
}
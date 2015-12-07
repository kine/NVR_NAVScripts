function Update-WorkInstallFolder
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
        [Parameter(ValueFromPipelineByPropertyName)]
        $buildpath
    )
    begin {}           
    process 
    {
        $clientfolder = Get-ChildItem -Path (Join-Path $buildpath 'DVD\RoleTailoredClient\program files\Microsoft Dynamics NAV\') | 
        Select-Object -First 1 |
        Get-ChildItem |
        Select-Object -First 1
            
        $navversionstring = (Get-ChildItem -Path $clientfolder.FullName -Filter 'finsql.exe').VersionInfo.FileVersion
        $navversion = $navversionstring.Split('.')[0] + ($navversionstring.Split('.')[1])[0]
        $navbuild = $navversionstring.Split('.')[2]
        $destinationfolder = "\\brno\Work_Install\NAV\$navversion\RoleTailored Client $navbuild"
        Write-Host "Copying $($clientfolder.FullName) to $($destinationfolder)" -ForegroundColor Green
        $null = Copy-Item -Path ($clientfolder.FullName + '\*') -Filter *.* -Destination $destinationfolder -Recurse -Force
        
        if ($langcode -ne 'intl') {
        
            $installersfolder = Get-ChildItem -Path (Join-Path $buildpath 'DVD\Installers\') | 
            Select-Object -First 1 

            Write-Verbose "Installer folder in $(Join-Path $buildpath 'DVD\Installers\') is $($installersfolder.FullName)"
            if ($installersfolder) {
                $RTCFolder = (Join-Path $installersfolder.FullName "RTC\PFiles\Microsoft Dynamics NAV\$navversion\RoleTailored Client") + '\*'
                Write-Host "Copying language from $($RTCFolder.FullName) to $($destinationfolder)" -ForegroundColor Green
                $null = Copy-Item -Path $RTCFolder -Filter *.* -Destination $destinationfolder -Recurse -Force
            }
        }
        
    }
    end {}
}

function Update-GitRepositoryWithCu
{
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName)]
        $repository,
        [Parameter(ValueFromPipelineByPropertyName)]
        $branch,
        [Parameter(ValueFromPipelineByPropertyName)]
        $buildpath,
        [Parameter(ValueFromPipelineByPropertyName)]
        $commitmessage
        
    )
    begin {}
    process {
        $filename = (Get-ChildItem (Join-Path $buildpath 'APPLICATION') -Filter '*CUObjects.txt')[0].FullName
       
        Update-GitRepository -FileName $filename -Author $env:USERNAME -Message $commitmessage -Repository $repository -Branch $branch -Folder 'objects'
    }
    end{}
}

Import-Module NVR_NAVScripts -Force -DisableNameChecking
Import-Module NVR_GitScripts -Force -DisableNameChecking

$cus = Get-NAVCumulativeUpdateFile -CountryCodes 'CSY','intl' -versions '2013 R2','2015','2016' | Expand-NAVCumulativeUpdateFile -targetpathmask '\\brno\Products\Microsoft\NA\Dynamics_NAV_$($version)_$langcode\BUILD$($BuildNo)_CU$formatedCUNo'

#Save objects into repsitories
$body = 'Downloaded CUs:<br><br>'

foreach ($cu in $cus) {
    $cu | Update-WorkInstallFolder
    
    
    $branch = "NAV$($cu.version)_$($cu.CountryCode)"
    switch ($cu.version) {
        '2013' {$repository = '\\devel\GIT\NAV2013'}
        '2015' {$repository = '\\devel\GIT\NAV2015'}
        '2016' {$repository = '\\devel\GIT\NAV2015'}
    }
    
    $commitmessage = {'NAV{0} {1} CU{2}' -f $cu.version,$cu.CountryCode,$cu.CUNo}
    
    Update-GitRepositoryWithCu -repository $repository -branch $branch -commitmessage $commitmessage
    
    $body = $body + $cu.CountryCode + $cu.version + '   ' +$cu.CUNo +'<br>'
}

if ($cus.Count -gt 0) {
    Send-EmailToMe -Subject 'NAV Cumulative Update' -Body $body -SMTPServer 'mail' -FromEmail 'powershell@navertica.com'
}


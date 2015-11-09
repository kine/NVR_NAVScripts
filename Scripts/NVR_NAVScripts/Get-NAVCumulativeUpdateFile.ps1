#requires -Version 3 -Modules BitsTransfer
function Get-NAVCumulativeUpdateFile
{
    param (
        [string]$langcode = 'intl',
        [string]$version = '2016',
        [string]$CUNo = ''
    )

    Write-Host -Object 'Searching for RSS item' -ForegroundColor Green

    $feed = [xml](Invoke-WebRequest -Uri 'https://blogs.msdn.microsoft.com/nav/category/announcements/cu/feed/')

    if ($CUNo -gt '') {
        $blogurl = $feed.SelectNodes("/rss/channel/item[./category='NAV $version' and ./category='Cumulative Updates' and contains(./title,'$CUNo')]").link
    } else {
        $blogurl = $feed.SelectNodes("/rss/channel/item[./category='NAV $version' and ./category='Cumulative Updates']").link
    }

    if (!$blogurl) {
        Write-Error 'Blog url not found!'
        return
    }

    Write-Host -Object "Reading blog page $blogurl" -ForegroundColor Green
    
    $blogarticle = Invoke-WebRequest -Uri $blogurl
    
    Write-Host -Object 'Searching for KB link' -ForegroundColor Green

    $kblink = $blogarticle.Links | Where-Object -FilterScript {
        $_.innerText -match 'KB'
    }

    $ie = New-Object -ComObject 'internetExplorer.Application'
    $ie.Visible = $true
    Write-Host -Object "Opening KB link $($kblink.href)" -ForegroundColor Green
    $ie.Navigate($kblink.href)
    while ($ie.Busy -eq $true)
    {
        Start-Sleep -Seconds 1
    }

    if ($ie.LocationURL -match 'login.live.com') {
        Write-Host 'Please, login. Script will continue automatically...' -ForegroundColor Magenta
        while ($ie.LocationURL -match 'login.live.com') {
            Start-sleep -Seconds 1
        }
    }
    
    if ($ie.LocationURL -match 'https://corp.sts.microsoft.com') 
    {
        Write-Host -Object 'Trying to login' -ForegroundColor Green
        $loginlink = $ie.Document.getElementById('CustomHRD_LinkButton_LiveId')
        Write-Host -Object 'Clicking the link to login' -ForegroundColor Green
        $loginlink.click()
        while ($ie.Busy -eq $true)
        {
            Start-Sleep -Seconds 1
        }
    }

    if ($ie.LocationURL -match 'https://mbs2.microsoft.com/UserInfo/SelectProfile.aspx') 
    {
        Write-Host -Object 'Searching for identity selection radiobuttons' -ForegroundColor Green
        $radiobuttons = $ie.Document.body.getElementsByTagName('input') | Where-Object -FilterScript {$_.type -eq 'radio' -and $_.name -eq 'radioGroup' }
        Write-Host -Object 'Clicking first radio button' -ForegroundColor Green
        $radiobuttons[0].setActive()
        $radiobuttons[0].click()
        $ie.Document.IHTMLDocument3_getElementsByName('continueButton')[0].click()
        while ($ie.Busy -eq $true)
        {
            Start-Sleep -Seconds 1
        }
    }

    Write-Host -Object 'Searching for download link' -ForegroundColor Green
    $downloadlink = $ie.Document.links | Where-Object -FilterScript {
        $_.id -match 'kb_hotfix_link'
    }
    Write-Host -Object "Opening download link $($downloadlink.href)" -ForegroundColor Green
    $ie.Navigate($downloadlink.href)
    while ($ie.Busy -eq $true)
    {
        Start-Sleep -Seconds 1
    }

    Write-Host -Object 'Searching for Accept button' -ForegroundColor Green

    $button = $ie.Document.IHTMLDocument3_getElementsByName('accept')

    if ($button) 
    {
        Write-Host -Object 'Clicking Accept button' -ForegroundColor Green
        $button.click()
        while ($ie.Busy -eq $true)
        {
            Start-Sleep -Seconds 1
        }   
    }

    Write-Host -Object 'Searching for list of updates' -ForegroundColor Green

    [regex]$pattern = 'hfList = (\[.+\}\])'
    $matches = $pattern.Matches($ie.Document.body.innerText) 
    if (!$matches) 
    {
        Write-Error -Message 'list of hotfixes not found!'
        return
    } 

    Write-Host -Object 'Converting Json with updates' -ForegroundColor Green
    $hotfixes = $matches.Groups[1].Value.Replace('\x','') | ConvertFrom-Json

    $ie.Quit()
    
    #URL examples:
    #http://hotfixv4.microsoft.com/Dynamics NAV 2016/latest/W1KB3106089/43402/free/488130_intl_i386_zip.exe
    #http://hotfixv4.microsoft.com/Dynamics NAV 2015/latest/CZKB3106088/43389/free/488059_CSY_i386_zip.exe

    Write-Host -Object "Searching for update for language $langcode" -ForegroundColor Green

    $hotfix = $hotfixes | Where-Object -FilterScript {
        $_.langcode -eq $langcode
    }

    Write-Host -Object 'Creating hotfix URL' -ForegroundColor Green

    $url = "http://hotfixv4.microsoft.com/$($hotfix.product)/$($hotfix.release)/$($hotfix.filename)/$($hotfix.build)/free/$($hotfix.fixid)_$($hotfix.langcode)_i386_zip.exe"

    Write-Host -Object "Hotfix URL is $url" -ForegroundColor Green

    $filename = (Join-Path -Path $env:TEMP -ChildPath "$($hotfix.fixid)_$($hotfix.langcode)_i386_zip.exe")
    Write-Host -Object "Downloading hotfix to $filename" -ForegroundColor Green
    Start-BitsTransfer -Source $url -Destination $filename
    Write-Host -Object 'Hotfix downloaded' -ForegroundColor Green
    return Get-Item $filename
}

function Update-NAVWebServerVersion
{
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true, HelpMessage = 'Name of the service to upgrade')]
        $WebServerInstance,
        [Parameter(Mandatory = $true, Position = 1, HelpMessage = 'Target Version')]
        $Version
    )

    begin {
        function Find-NAVWebServerVersion 
        {
            param (
                [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
                $OldPath,
                [Parameter(Mandatory = $true, Position = 1, HelpMessage = 'Target Version')]
                $Version
            )
            $searchfile = 'Microsoft.Dynamics.Nav.Client.WebClient.dll'
            $result = $OldPath |
            Get-ChildItem -Filter $searchfile -Recurse |
            Where-Object -FilterScript {
                $_.VersionInfo.FileVersion -eq $Version
            } 
            if ($result) 
            {
                if ($result.Count -gt 1) {
                    Write-InfoMessage "Found $($result[0].DirectoryName)"
                    return (Split-Path $result[0].DirectoryName)
                }
                Write-InfoMessage "Found $($result.DirectoryName)"
                return (Split-Path $result.DirectoryName)
            } else {
                Write-InfoMessage "Version $Version not found in $OldPath!"
                return $OldPath
            }
            
        }
        $OldNavIdePath = $env:NAVIdePath
    }
    process {
        $WebServerInstanceFolder = (Join-Path 'c:\inetpub\wwwroot' $WebServerInstance)
        if (!(Test-Path $WebServerInstanceFolder)) {
            Write-Error "Folder for WebServer instance $WebServerInstance not found!"
            Return
        } 
        $dll = Get-Item (Join-Path $WebServerInstanceFolder 'WebClient\bin\Microsoft.Dynamics.Nav.Client.WebClient.dll')
        if ($dll.VersionInfo.FileVersion -eq $Version) {
            Write-InfoMessage "WebServer instance $WebServerInstance is already using version $Version"
        } else {
            Write-InfoMessage "Upgrading instance $WebServerInstance to version $Version"
            $NewPath = (Find-NAVWebServerVersion -OldPath (Split-Path (Get-NAVAdminPath)) -Version $Version)
            #Remove-Item (Join-Path $WebServerInstanceFolder 'WebClient') -Force
            cmd /c rmdir (Join-Path $WebServerInstanceFolder 'WebClient')
            Write-InfoMessage "Creating new symlink to $NewPath"
            $null = New-SymLink -Path $NewPath -SymName (Join-Path $WebServerInstanceFolder 'WebClient') -Directory
            Write-InfoMessage "WebServer instance $WebServerInstance sucessfully update to version $Version"
        }
        
    }
    end{
        $env:NAVIdePath = $OldNavIdePath
    }
}
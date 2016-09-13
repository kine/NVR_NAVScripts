function Update-NAVServiceVersion
{
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true, HelpMessage = 'Name of the service to upgrade')]
        $ServerInstance,
        [Parameter(Mandatory = $true, Position = 1, HelpMessage = 'Target Version')]
        $Version
    )

    begin {
    }
    process {
        Write-InfoMessage "Getting service for instance $ServerInstance"
        $service = Get-Service ("MicrosoftDynamicsNavServer`$$ServerInstance")
        
        if ($service.Status -eq 'Running') {
            Write-InfoMessage "Stopping the service $($service.Name)"
            $service.Stop()
        }
    
        Write-InfoMessage 'Getting current path for the service...'
        $currentPath = (Get-ItemProperty -Path ('HKLM:\System\CurrentControlSet\Services\'+$service.Name) -Name ImagePath).ImagePath
        $originalPath = (Split-Path $currentPath.Split('$')[0]).Replace('"','').Replace('''','')
    
        Write-InfoMessage 'Getting target path...'
        $TargetFolder = Find-NAVVersion -path $originalPath -Version $Version
        $OldNavIdePath = $env:NAVIdePath
    
        if ($TargetFolder -eq $originalPath) {
            Write-InfoMessage 'Path is same. No change or version not found...'
            #Import-Module (Join-Path $TargetFolder 'Microsoft.Dynamics.Nav.Management.dll')
            $env:NAVIdePath = $TargetFolder
            $serviceconfig=(Get-NAVServerConfiguration -ServerInstance $ServerInstance -AsXml)
            $Database = $serviceconfig.configuration.appSettings.SelectSingleNode("add[@key='DatabaseName']").Value
            $Server = $serviceconfig.configuration.appSettings.SelectSingleNode("add[@key='DatabaseServer']").Value
            $DatabaseInstance = $serviceconfig.configuration.appSettings.SelectSingleNode("add[@key='DatabaseInstance']").Value
            if ($DatabaseInstance -gt '') {
                $Server = $Server +'\\'+$ServerInstance
            }
            Write-Host "Converting database $Database on $Server...$($env:NAVIdePath)"
            Invoke-NAVDatabaseConversion2 -DatabaseName $Database -DatabaseServer $Server
            Return
        }
        if ($TargetFolder -eq '') {
            Write-Error "Folder for version $Version not found somewhere near $originalPath" -ErrorAction Stop
        }
    
        $newPath = $currentPath.Replace($originalPath,$TargetFolder)
        Write-InfoMessage "Relocating configuration to folder $TargetFolder ..."
        Move-Item -Path "$originalPath\Instances\$ServerInstance\" -Destination "$TargetFolder\Instances\" -ErrorAction Stop

        Write-InfoMessage "Relocating service to folder $TargetFolder ..."
        Set-ItemProperty -Path ('HKLM:\System\CurrentControlSet\Services\'+$service.Name) -Name ImagePath -Value $newPath

        $option=[System.StringSplitOptions]::RemoveEmptyEntries
        $separator = ' config ','DUMMY'
        $configFile = $newPath.Split($separator,$option)[1].Replace('"','')
        $config = [xml](Get-Content $configFile)
        $config.configuration.appSettings.file = $config.configuration.appSettings.file.Replace($originalPath,$TargetFolder)
        if ($config.configuration.tenants) {
            $config.configuration.tenants.file = $config.configuration.tenants.file.Replace($originalPath,$TargetFolder)
        }
    
        Write-InfoMessage 'Modifying config files to new paths...'
        $config.Save($configFile)
        
        #Import-Module (Join-Path $TargetFolder 'Microsoft.Dynamics.Nav.Management.dll')
        $env:NAVIdePath = $TargetFolder
        $serviceconfig=(Get-NAVServerConfiguration -ServerInstance $ServerInstance -AsXml)
        $Database = $serviceconfig.configuration.appSettings.SelectSingleNode("add[@key='DatabaseName']").Value
        $Server = $serviceconfig.configuration.appSettings.SelectSingleNode("add[@key='DatabaseServer']").Value
        $DatabaseInstance = $serviceconfig.configuration.appSettings.SelectSingleNode("add[@key='DatabaseInstance']").Value
        if ($DatabaseInstance -gt '') {
            $Server = $Server +'\\'+$ServerInstance
        }
        Write-Host "Converting database $Database on $Server...$($env:NAVIdePath)"
        Invoke-NAVDatabaseConversion2 -DatabaseName $Database -DatabaseServer $Server

        Write-InfoMessage 'Starting service...'
        Start-Service -Name ("MicrosoftDynamicsNavServer`$$ServerInstance")
        
        Write-InfoMessage 'Syncing schema...'
        Sync-NAVTenant -ServerInstance $ServerInstance -Mode Sync -Force
    }
    end{
        $env:NAVIdePath = $OldNavIdePath
    }
}
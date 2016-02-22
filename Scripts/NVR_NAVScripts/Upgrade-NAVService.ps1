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
        Write-InfoMessage -Message "Getting service for instance $InstanceName"
        $service = Get-Service ("MicrosoftDynamicsNavServer`$$InstanceName")
    
        if ($service.Status -eq 'Running') 
        {
            Write-InfoMessage -Message "Stopping the service $($service.Name)"
            $service.Stop()
        }
    
        Write-InfoMessage -Message 'Getting current path for the service...'
        $currentPath = (Get-ItemProperty -Path ('HKLM:\System\CurrentControlSet\Services\'+$service.Name) -Name ImagePath).ImagePath
        $originalPath = (Split-Path -Path $currentPath.Split('$')[0]).Replace('"','')
    
        Write-InfoMessage -Message 'Getting target path...'
        $TargetFolder = Find-NAVVersion -path $originalPath -Version $Version
    
        if ($TargetFolder -eq $originalPath) 
        {
            Write-InfoMessage -Message 'Path is same. No change or version not found...'
            Return
        }
        if ($TargetFolder -eq '') 
        {
            Write-Error -Message "Folder for version $Version not found somewhere near $originalPath" -ErrorAction Stop
        }
    
        $newPath = $currentPath.Replace($originalPath,$TargetFolder)
        Write-InfoMessage -Message "Relocating service to folder $TargetFolder ..."
        Set-ItemProperty -Path ('HKLM:\System\CurrentControlSet\Services\'+$service.Name) -Name ImagePath -Value $newPath
        Write-InfoMessage -Message "Relocating configuration to folder $TargetFolder ..."
        Move-Item -Path "$originalPath\Instances\$($Name.Split('$')[1])" -Destination "$TargetFolder\Instances\"

        $option = [System.StringSplitOptions]::RemoveEmptyEntries
        $separator = ' config ', 'DUMMY'
        $configFile = $newPath.Split($separator,$option)[1].Replace('"','')
        $config = [xml](Get-Content $configFile)
        $config.configuration.appSettings.file = $config.configuration.appSettings.file.Replace($originalPath,$TargetFolder)
        $config.configuration.tenants.file = $config.configuration.tenants.file.Replace($originalPath,$TargetFolder)
    
        Write-InfoMessage -Message 'Modifying config files to new paths...'
        $config.Save($configFile)
    }
    end{
    }
}

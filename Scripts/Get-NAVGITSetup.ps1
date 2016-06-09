<#
        .Synopsis
        Read setup from the xml and return the object to pipe to be used for other scripts
        .DESCRIPTION
        Read setup from the xml and return the object to pipe to be used for other scripts without setting their parameters directly

        Setup file structure
        <?xml version="1.0"?>
        <Object>
        <Property Name="Server">sqlserver</Property>
        <Property Name="Database">sqldatabase</Property>
        <Property Name="Path">Objects</Property>
        <Property Name="Files">Objects\*.txt</Property>
        <Property Name="NAVIdePath">c:\Program Files (x86)\Microsoft Dynamics NAV\71\RoleTailored Client\</Property>
        <Property Name="NAVServicePath">c:\Program Files\Microsoft Dynamics NAV\71\Service\</Property>
        </Object>
        .EXAMPLE
        Get-NAVGITSetup setup.xml | Update-NAVApplicationFromTxt
#>


param (
    [string]$SetupFile = 'setup.xml'
)

Begin {
    function ConvertFrom-Xml($XML) 
    {
        foreach ($Object in @($XML.Object)) 
        {
            $PSObject = New-Object -TypeName PSObject
            foreach ($Property in @($Object.Property)) 
            {
                $PSObject | Add-Member NoteProperty $Property.Name $ExecutionContext.InvokeCommand.ExpandString($Property.InnerText)
            }
            $PSObject
        }
    }
    function Get-GitBranchDetached
    {
        if ($env:TF_BUILD_SOURCEGETVERSION) 
        {
            #LG:refs/heads/master:e9d70f7fbb195712ae650d4ade5691c3971ecb73 
            return $env:TF_BUILD_SOURCEGETVERSION.Split('/:')[3]
        }
        if ($env:TF_BUILD_GITBRANCH) 
        {
            return $env:TF_BUILD_GITBRANCH
        }

        if ($env:BUILD_SOURCEBRANCHNAME) 
        {
            return $env:BUILD_SOURCEBRANCHNAME
        }
        Write-Error 'No Branch checked OUT!' -ErrorAction Stop
        $reflog = (git.exe reflog --all  | Select-Object -First 1)
        $reflog = $reflog.Split('@')[0]
        $reflog = $reflog.Split('/')
        $reflog = $reflog[$reflog.Count-1]
        return $reflog
        
    }
    function Get-GitBranch 
    {
        Push-Location
        Set-Location -Path (Join-Path -Path $PSScriptRoot -ChildPath '..\..\')
        #$GitBranch = git.exe symbolic-ref --short HEAD
        if ($env:TF_BUILD) {
            $GitBranch = Get-GitBranchDetached
        } else {
            $GitBranch = (git.exe status -b -s --ignore-submodules)
            $GitBranch = $GitBranch.Split(' ')[1]
            $GitBranch = $GitBranch.Split('...')[0]
            if ($GitBranch -eq 'HEAD') {
                $GitBranch = Get-GitBranchDetached
            }
        }
        Pop-Location
        return $GitBranch
    }
    
    function Convert-NAVPathByVersion
    {
        param (
            $setup
        )
        if ($setup.NAVVersion) {
            $setup.NAVIdePath = Find-NAVVersion -Path $setup.NAVIdePath -Version $setup.NAVVersion
            $setup.NAVServicePath = Find-NAVVersion -Path $setup.NAVServicePath -Version $setup.NAVVersion
        }
        return $setup
        
    }
    Import-Module NVR_NAVScripts -DisableNameChecking -ErrorAction Stop
    #Write-Host 'Creating setup file path'
    #$SetupFile = (Join-Path -Path $PSScriptRoot -ChildPath '..\..\setup.xml')
    Write-Host 'reading git branch'
    $GitBranch = Get-GitBranch
    Write-Host "Getting setup for branch $GitBranch..."
    if (Test-Path ($SetupFile -Replace '.xml', ($GitBranch+'.xml'))) 
    {
        [xml]$XML = Get-Content ($SetupFile -Replace '.xml', ($GitBranch+'.xml'))
    }
    else 
    {
        [xml]$XML = Get-Content $SetupFile
    }
    $setup = ConvertFrom-Xml -XML $XML

    $setup = Convert-NAVPathByVersion -Setup $setup
    
    $env:NAVIdePath = "$($setup.NavIdePath)"
    Set-Variable -Name NavIde -Value (Join-Path "$($setup.NavIdePath)" "finsql.exe") -Scope 0
    try 
    {
        #        if ([Environment]::GetEnvironmentVariable('NAVIdePath', 'Machine') -ne "$($setup.NavIdePath)") {
        #            [Environment]::SetEnvironmentVariable('NAVIdePath', "$($setup.NavIdePath)", 'Machine')
        #        }
    }
    catch 
    {

    }
    $env:NAVServicePath = "$($setup.NAVServicePath)"
    try 
    {
        #        if ([Environment]::GetEnvironmentVariable('NAVServicePath','Machine') -ne "$($setup.NAVServicePath)") {
        #            [Environment]::SetEnvironmentVariable('NAVServicePath', "$($setup.NAVServicePath)", 'Machine')
        #        }
    }
    catch 
    {

    }
    $setup
}
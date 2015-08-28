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
    [xml]$XML = Get-Content $SetupFile
    $setup = ConvertFrom-Xml $XML

    $env:NAVIdePath = $setup.NavIdePath
    try 
    {
        [Environment]::SetEnvironmentVariable('NAVIdePath', "$($setup.NavIdePath)", 'Machine')
        $env:NAVIdePath = $setup.NavIdePath
    }
    catch 
    {

    }
    $env:NAVServicePath = $setup.NAVServicePath
    try 
    {
        [Environment]::SetEnvironmentVariable('NAVServicePath', "$($setup.NAVServicePath)", 'Machine')
    }
    catch 
    {

    }
    $setup
}
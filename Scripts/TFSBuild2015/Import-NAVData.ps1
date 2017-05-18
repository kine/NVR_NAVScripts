param
(
        [String]$NAVServer=$env:NAVServer,
        [String]$NAVServerInstance=$env:NAVServerInstance,
        [String]$NAVVersion=$env:NAVVersion,
        [String]$NAVDataFile=$env:NAVDataFile
)

Import-Module NVR_NAVScripts -DisableNameChecking -Force
Import-Module (Get-NAVAdminModuleName -NAVVersion $NAVVersion)
Set-NAVVersion -NAVVersion $NAVVersion

Sync-NAVTenant -ServerInstance $NAVServerInstance -Mode Force -Force

Import-NAVData -AllCompanies -FilePath $NAVDataFile -ServerInstance $NAVServerInstance -Force -IncludeApplicationData -IncludeGlobalData
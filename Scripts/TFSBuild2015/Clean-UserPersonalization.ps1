param
(
        [String]$NAVServer=$env:NAVServer,
		[String]$NAVServerInstance=$env:NAVServerInstance,
        [String]$NAVVersion=$env:NAVVersion
)


Import-Module CommonPSFunctions -DisableNameChecking -Force
Import-Module NVR_NAVScripts -DisableNameChecking -Force
Import-Module (Get-NAVAdminModuleName -NAVVersion $NAVVersion)
Set-NAVVersion -NAVVersion $NAVVersion

$config = Get-NAVServerConfiguration -ServerInstance $NAVServerInstance

Get-SQLCommandResult -Server $config.DatabaseServer  -Database "$($config.DatabaseName)" -Command "update [User Personalization] set [Company]=''"

Sync-NAVTenant -ServerInstance $NAVServerInstance -Mode Force -Force
param
(
        [String]$NAVServer=$env:NAVServer
		[String]$NAVServerInstance=$env:NAVServerInstance,
        [String]$NAVVersion=$env:NAVVersion,
        [String]$SyncMode=Force,
        $FobFile
)


Import-Module CommonPSFunctions -DisableNameChecking -Force
Import-Module NVR_NAVScripts -DisableNameChecking -Force
Import-Module (Get-NAVAdminModuleName -NAVVersion $NAVVersion)
Set-NAVVersion -NAVVersion $NAVVersion
Import-NAVModelTool -Global -NAVVersion $NAVVersion

$config = Get-NAVServerConfiguration -ServerInstance $NAVServerInstance

Import-NAVApplicationObject2 -DatabaseName "$($config.DatabaseName)" -Path $FobFile -DatabaseServer $config.DatabaseServer -ImportAction Overwrite -NavServerInstance $NAVServerInstance -NavServerName $env:COMPUTERNAME -SynchronizeSchemaChanges $SyncMode
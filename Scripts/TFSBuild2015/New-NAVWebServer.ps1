param
(
        [String]$NAVServer=$env:NAVServer,
		[String]$NAVWebServerInstance=$env:NAVWebServerInstance,
		[String]$NAVServerInstance=$env:NAVServerInstance,
		[String]$NAVVersionName='2017',
        [String]$NAVVersion=$env:NAVVersion
)

Import-Module NVR_NAVScripts -DisableNameChecking -Force
Import-Module (Get-NAVAdminModuleName -NAVVersion $NAVVersion)
Set-NAVVersion -NAVVersion $NAVVersion

New-NAVWebServerInstance -Server $NAVServer -ServerInstance $NAVServerInstance -WebServerInstance $NAVWebServerInstance
Update-NAVWebServerVersion -WebServerInstance $NAVServerInstance -Version $NAVVersion
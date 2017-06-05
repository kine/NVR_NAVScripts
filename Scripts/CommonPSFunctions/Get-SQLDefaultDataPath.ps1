function Get-SQLDefaultDataPath
{
    param (
        $Server
    )
    $Command= "SELECT [DefaultDataPath] = SERVERPROPERTY('InstanceDefaultDataPath')"
    $Result = Get-SQLCommandResult -Server $Server -Database master -Command $Command
    return $Result.DefaultDataPath
}
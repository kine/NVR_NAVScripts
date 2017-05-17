function Create-NAVUserFromAD
{
    Param (
      #[string]$userNameFile,
      [Parameter(Mandatory = $true,ValueFromPipelinebyPropertyName = $true)]
      [string]$serverInstance,
      #Example of OUs parameter: @('ou=NAV,ou=Users,ou=Company,dc=mydomain,dc=local','ou=NAV2,ou=Users,ou=Company,dc=mydomain,dc=local')
      [Parameter(Manatory = $true, ValueFromPipelineByPropertyName = $true)]
      $OUs,
      [Parameter(ValueFromPipelineByPropertyName = $true)]
      $PermissionSets='SUPER'
    )
    #Install of needed module:
    #Import-Module ServerManager
    #Add-WindowsFeature RSAT-AD-PowerShell
    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
        Write-InfoMessage 'ActiveDirectory module not available, trying to install...'
        Write-InfoMessage 'Loading ServerManager module...'
        Import-Module ServerManager
        Write-InfoMessage 'Adding windows feature RSAT-AD-Powershell'
        Add-WindowsFeature RSAT-AD-PowerShell
    }

    Write-InfoMessage 'Reading existing users...'
    $ExistingUsers = (Get-NAVServerUser -ServerInstance $serverInstance).UserName

    foreach ($OU in $OUs) {
        $Users=Get-ADUser -Filter * -SearchBase $OU
        foreach ($User in $Users) {
          if ($ExistingUsers -icontains $User.UserPrincipalName) {
              Write-InfoMessage "User $($User.UserPrincipalName) already exists"
          } else {
              Write-InfoMessage "Creating user $User"
              New-NAVServerUser -ServerInstance $serverInstance -WindowsAccount $User.UserPrincipalName
          }
          foreach ($PermissionSet in $PermissionSets) {
              if (Get-NAVServerUserPermissionSet -ServerInstance $serverInstance -WindowsAccount $User.UserPrincipalName -PermissionSetId $PermissionSet) {
                  Write-InfoMessage "$User is already $PermissionSet"
              } else {
                  Write-InfoMessage "Assigning $PermissionSet to $User"
                  New-NAVServerUserPermissionSet -ServerInstance $serverInstance -WindowsAccount $User.UserPrincipalName -PermissionSetId $PermissionSet
              }
          }
        }
    }
}
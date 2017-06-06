function Commit-GitRepository
{
    [CmdletBinding()]
    param(
        [String]$Repository,
        [String]$Branch,
        [String]$Remote,
        [String]$CommitMessage,
        [String]$Author
    )
    Push-Location
    Set-Location -Path $Repository
    Write-Host "Commiting $Branch in $Repository..." -ForegroundColor Green
    #$result = git config --global user.email "$email" 
    $email = Get-UserEmail -UserName $Author
    Write-Host 'Adding all into git' -ForegroundColor Green
    $result = git add --all
    Write-Host 'Commiting changes to git' -ForegroundColor Green
    $result = git commit --message="$CommitMessage" --all --quiet --author="$Author <$email>"
    Write-Host 'Pushing all to remote' -ForegroundColor Green
    $result = git.exe push --quiet --porcelain | Out-Null
    Write-Host 'Fetching all from remote' -ForegroundColor Green
    $result = git fetch --quiet --all
    Pop-Location
}
function Update-GitRepository
{
    [CmdletBinding()]
    param(
        [String]$FileName,
        [String]$Author,
        [String]$Message,
        [String]$Repository,
        [String]$Branch,
        [String]$Folder,
        [String]$Remote
    )
    Get-GitBranch -Repository $Repository -Branch $Branch
    
    $TargetPath = (Join-Path $Repository $Folder)
    Write-Host "Splitting $FileName to the repository $TargetPath" -ForegroundColor Green
    Split-NAVApplicationObjectFile -Source $FileName -Destination $TargetPath -Force -PreserveFormatting
    $CommitMessage = ('{0}' -F $Message)

    Commit-GitRepository -Repository $Repository -Branch $Branch -Remote $Remote -CommitMessage $CommitMessage -Author $Author
}
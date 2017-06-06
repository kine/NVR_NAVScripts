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
    
    Import-NAVModelTool -Global
    Get-GitBranch -Repository $Repository -Branch $Branch
    
    if ($FileName.IndexOf('W1') -gt 0) {
        (Get-Content $FileName -Encoding Oem) `
        -replace '    Date=(\d{2})-(\d{2})-(\d{2});', '    Date=$1.$2.$3;' |
        Out-File (Join-Path (Split-Path $FileName) "TR_$(Split-Path $FileName -Leaf)") -Encoding oem -Force
        $FileName = (Join-Path (Split-Path $FileName) "TR_$(Split-Path $FileName -Leaf)")
    }
    
    $TargetPath = (Join-Path $Repository $Folder)
    Write-Host "Splitting $FileName to the repository $TargetPath" -ForegroundColor Green
    Split-NAVApplicationObjectFile -Source $FileName -Destination $TargetPath -Force -PreserveFormatting
    $CommitMessage = ('{0}' -F $Message)

    Commit-GitRepository -Repository $Repository -Branch $Branch -Remote $Remote -CommitMessage $CommitMessage -Author $Author
}
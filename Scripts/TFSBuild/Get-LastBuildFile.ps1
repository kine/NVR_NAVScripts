param
(
	[String]$Folder,
    [String]$Filter
)

$file = Get-ChildItem -Path $Folder -Filter $Filter -Recurse | Sort-Object -Property CreationTime -Descending | Select-Object -First 1


Write-Output $file.FullName
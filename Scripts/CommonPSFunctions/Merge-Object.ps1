function Merge-Object
{
    <#
        .SYNOPSIS
        Takes two objects and combine their's NoteProperty members into one resulting object

        .DESCRIPTION
        Result object is union of member of both objects

        .PARAMETER Object1
        Object to merge

        .PARAMETER Object2
        Object to merge

        .EXAMPLE
        Merge-Object -Object1 O1 -Object2 O2
    #>

    [CmdletBinding()]
    param(
        [Object]$Object1,
        [Object]$Object2
    )
    
    if (-not $Object1) {
        return $Object2
    }

    if (-not $Object2) {
        return $Object1
    }
        
    foreach ($property in (Get-Member -InputObject $Object2 -MemberType NoteProperty)) {
        if (-not (Get-Member -InputObject $Object1 -Name $property.Name)) {
            $Object1 = $Object1 | Add-Member -MemberType NoteProperty -Name $property.Name -Value $property.Value
        } else {
            (Get-Member -InputObject $Object1 -MemberType NoteProperty).Value=$property.Value
        }
    }
    
    return $Object1
}
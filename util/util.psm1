function Get-Capitalized
{
    param(
        [string]$String
    )

    $Excluded = @(
    'are',
    'to',
    'a',
    'the',
    'at',
    'in',
    'of',
    'with',
    'and',
    'but',
    'or')

    ( $String -split " " | ForEach-Object {
        if ($_ -notin $Excluded)
        {
            "$([char]::ToUpper($_[0]) )$($_.Substring(1) )"
        }
        else
        {
            $_
        }
    }) -join " "
}

Export-ModuleMember -Function Get-Capitalized
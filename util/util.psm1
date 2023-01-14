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

function SafeTrim
{
    param (
        [String]$string
    )
    return $string ? $string.Trim() : $null
}

function Set-ConsoleEncoding
{
    param (
        [String]$encoding
    )
    [Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding($encoding)
}

function Set-Extension
{
    param (
        [System.IO.FileInfo]$file,
        [String]$extension
    )
    return Join-Path $file.Directory "$($file.BaseName)$extension"
}

function Get-NormalizedFilename
{
    param (
        [String]$name
    )

    return ((($name -replace "[\\/:|<>]", "¦") -replace "[*]", "·") -replace "[?]", "$") -replace "[\`"]", "'"
}

Function Read-IniFile ($file) {
    $ini = @{}
    $section =
    switch -regex -file $file
    {
        "^\[(.+)\]$" # Section
        {
            $section = $matches[1]
            $ini[$section] = @{}
            $comments_count = 0
        }
        "^(;.*)$" # Comment
        {
            $value = $matches[1]
            $comments_count = $comments_count + 1
            $name = "Comment" + $comments_count
            $ini[$section][$name] = $value
        }
#        "(.+?)\s*=(.*)" # Key
#        {
#            $name,$value = $matches[1..2]
#            $ini[$section][$name] = $value
#        }
    }
    return $ini
}

Export-ModuleMember -Function SafeTrim
Export-ModuleMember -Function Get-Capitalized
Export-ModuleMember -Function Set-ConsoleEncoding
Export-ModuleMember -Function Set-Extension
Export-ModuleMember -Function Read-IniFile
Export-ModuleMember -Function Get-NormalizedFilename
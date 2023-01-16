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

function Get-IniContent
{
    param(
        [String]$filename
    )

    $map = @{ }
    $section = "no-section"
    $map[$section] = @{ }
    switch -regex -file $filename
    {
        "^\s*[;#](.*)$" {
            Write-Debug $matches[1]
        }
        "^\s*\[(.+)\]\s*$" {
            $section = $matches[1]
            $map[$section] = @{ }
        }
        "^\s*(.+)\s*=\s*(.*)$" {
            $name, $value = $matches[1..2]
            $map[$section][$name] = $value
        }
        default {
            if (-not$map[$section]["raw"])
            {
                $map[$section]["raw"] = @()
            }
            $map[$section]["raw"] += $_
        }
    }
    $map
}

Export-ModuleMember -Function Get-Capitalized
Export-ModuleMember -Function Set-ConsoleEncoding
Export-ModuleMember -Function Set-Extension
Export-ModuleMember -Function Get-NormalizedFilename
Export-ModuleMember -Function Get-IniContent
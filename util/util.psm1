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
    return Join-Path $file.Directory "$( $file.BaseName )$extension"
}

function Get-NormalizedFilename
{
    param (
        [String]$name
    )

    return ((($name -replace "[\\/:|<>]", "¦") -replace "[*]", "·") -replace "[?]", "$") -replace "[\`"]", "'"
}

function ConvertFrom-Ini
{
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [String[]]$lines
    )
    begin{
        $map = @{ }
        $section = "no_section"
        $map[$section] = @{ }
    }
    process{
        switch -regex ($lines)
        {
            "^\s*[;#](.*)$" {
                Write-Debug "Comment: $( $matches[1] )"
                continue
            }
            "^\s*\[(.+)\]\s*$" {
                $section = $matches[1].Trim()
                $map[$section] = @{ }
                continue
            }
            "^\s*(.+)=(.*)$" {
                $map[$section][$matches[1].Trim()] = $matches[2].Trim()
                continue
            }
            default {
                $section_map = $map[$section]
                if (-not$section_map.raw)
                {
                    $section_map.raw = @()
                }
                $section_map.raw += $_
            }
        }
    }
    end{
        return $map
    }
}

function Confirm-Proceed
{
    param (
        [String]$message
    )

    $input = (Read-Host "$message (y/n)").ToLower()
    if ($input -and -not $input.StartsWith("y"))
    {
        exit
    }
}

Export-ModuleMember -Function Confirm-Proceed
Export-ModuleMember -Function Get-Capitalized
Export-ModuleMember -Function Set-ConsoleEncoding
Export-ModuleMember -Function Set-Extension
Export-ModuleMember -Function Get-NormalizedFilename
Export-ModuleMember -Function ConvertFrom-Ini
function Set-ConsoleEncoding {
    param (
        [String]$encoding
    )
    [Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding($encoding)
}

function Set-Extension {
    param (
        [System.IO.FileInfo]$file,
        [String]$extension
    )
    return Join-Path $file.Directory "$( $file.BaseName )$extension"
}

function Get-NormalizedFilename {
    param (
        [String]$name
    )

    return ((($name -replace "[\\/:|<>｜：]", "¦") -replace "[*]", "·") -replace "[?]", "$") -replace "[\`"]", "'"
}

function Confirm-Proceed {
    param (
        [String]$Prompt
    )

    $Value = (Read-Host "$Prompt (y/n)").ToLower()
    return -not $Value -or $Value.StartsWith("y")
}

function Confirm-ProceedOrExit {
    param (
        [String]$message
    )

    if (-not (Confirm-Proceed($message))) {
        exit
    }
}
function Read-HostDefault {
    param (
        [String]$Prompt,
        $DefaultValue
    )
    if ($Value = Read-Host "$Prompt [$DefaultValue]") { 
        return $Value 
    }
    else {
        return $DefaultValue
    }
}

Export-ModuleMember -Function Confirm-Proceed
Export-ModuleMember -Function Confirm-ProceedOrExit
Export-ModuleMember -Function Get-Capitalized
Export-ModuleMember -Function Set-ConsoleEncoding
Export-ModuleMember -Function Set-Extension
Export-ModuleMember -Function Get-NormalizedFilename
Export-ModuleMember -Function Read-HostDefault
function Set-ConsoleEncoding {
    param (
        [String]$encoding
    )
    [Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding($encoding)
}

function ChangeExtension {
    param (
        [System.IO.FileInfo]$File,
        [String]$Extension
    )
    return Join-Path $File.Directory "$( $File.BaseName ).$Extension"
}

function Get-NormalizedFilename {
    param (
        [String]$name
    )

    return ((($name -replace "[\\/:|<>｜：]", "¦") -replace "[*]", "·") -replace "[?]", "$") -replace "[\`"]", "'"
}

function ConfirmProceed {
    param (
        [String]$Prompt
    )

    $Value = (Read-Host "$Prompt (y/n)").ToLower()
    return -not $Value -or $Value.StartsWith("y")
}

function ConfirmProceedOrExit {
    param (
        [String]$Message
    )

    if (-not (ConfirmProceed($Message))) {
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

Export-ModuleMember -Function ConfirmProceed
Export-ModuleMember -Function ConfirmProceedOrExit
Export-ModuleMember -Function Get-Capitalized
Export-ModuleMember -Function Set-ConsoleEncoding
Export-ModuleMember -Function ChangeExtension
Export-ModuleMember -Function Get-NormalizedFilename
Export-ModuleMember -Function Read-HostDefault
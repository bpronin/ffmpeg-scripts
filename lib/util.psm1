function Set-ConsoleEncoding {
    param (
        [String]$Encoding
    )
    process {
        [Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding($Encoding)
    }
}

function Rename-FileExtension {
    param (
        [System.IO.FileInfo]$File,
        [String]$Extension
    )
    process {
        return Join-Path $File.Directory "$( $File.BaseName ).$Extension"
    }
}

function Get-NormalizedFilename {
    param (
        [String]$Filename
    )
    process {
        return ((($Filename -replace "[\\/:|<>｜：]", "¦") -replace "[*]", "·") -replace "[?]", "$") -replace "[\`"]", "'"
    }
}

function Confirm-Proceed {
    param (
        [String]$Prompt
    )
    process {
        $Value = (Read-Host "$Prompt (y/n)").ToLower()
        return -not $Value -or $Value.StartsWith("y")
    }
}

function Confirm-ProceedOrExit {
    param (
        [String]$Message
    )
    process {
        if (-not (Confirm-Proceed($Message))) {
            exit
        }
    }
}
function Read-HostDefault {
    param (
        [String]$Prompt,
        $DefaultValue
    )
    process {
        if ($Value = Read-Host "$Prompt [$DefaultValue]") { 
            return $Value 
        }
        else {
            return $DefaultValue
        }
    }
}

Export-ModuleMember -Function Confirm-Proceed
Export-ModuleMember -Function Confirm-ProceedOrExit
Export-ModuleMember -Function Get-Capitalized
Export-ModuleMember -Function Set-ConsoleEncoding
Export-ModuleMember -Function Rename-FileExtension
Export-ModuleMember -Function Get-NormalizedFilename
Export-ModuleMember -Function Read-HostDefault
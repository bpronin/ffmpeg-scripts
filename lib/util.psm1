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
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$File,
        [String]$NewExtension = $File.Extension,
        [String]$Prefix
    )
    process {
        return Join-Path $File.Directory "$Prefix$( $File.BaseName ).$NewExtension"
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
        if ($DefaultValue) {
            $DefaultPrompt = " [$DefaultValue]"
        }
        if ($Value = Read-Host "$Prompt$DefaultPrompt") { 
            return $Value 
        }
        else {
            return $DefaultValue
        }
    }
}
   
function Get-FilesCollection {
    param (
        [Parameter(Mandatory)]
        $Paths,
        $Include
    )
    process {
        $Items = @()
        
        $Paths | ForEach-Object {
            $Path = Get-Item -Path $_
            if ($Path.PSIsContainer) {
                Get-ChildItem -Path $Path -Recurse -Include $Include | Foreach-Object {
                    $Items += $_
                }
            }
            else {
                $Items += $Path
            } 
        }
        return $Items
    }
}

Export-ModuleMember -Function Confirm-Proceed
Export-ModuleMember -Function Confirm-ProceedOrExit
Export-ModuleMember -Function Get-Capitalized
Export-ModuleMember -Function Get-NormalizedFilename
Export-ModuleMember -Function Get-FilesCollection
Export-ModuleMember -Function Rename-FileExtension
Export-ModuleMember -Function Read-HostDefault
Export-ModuleMember -Function Set-ConsoleEncoding
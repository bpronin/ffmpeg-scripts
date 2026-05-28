function Set-ConsoleEncoding {
    param (
        [String]$Encoding
    )
    process {
        [Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding($Encoding)
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

function Invoke-FailSafe {
    param (
        [scriptblock]$Block,
        [int]$Attempts = 3,
        [int]$Timeout = 100
    )
    process {
        for ($i = 0; $i -lt $Attempts; $i++) {
            try {
                Invoke-Command $Block
                return
            }
            catch {
                Write-Warning "$_ Trying again afret $Timeout ms ..."
            }
            Start-Sleep -Milliseconds $Timeout
        }
        throw "Give up trying: $Block"
    }
}

Export-ModuleMember -Function Set-ConsoleEncoding
Export-ModuleMember -Function Confirm-Proceed
Export-ModuleMember -Function Confirm-ProceedOrExit
Export-ModuleMember -Function Read-HostDefault
Export-ModuleMember -Function Get-FilesCollection
Export-ModuleMember -Function Invoke-FailSafe

using namespace System.IO

function Invoke-ForAllRecursivelyParallel
{
    param(
        [Parameter(ValueFromPipeline, Mandatory = $true)]
        [String[]]$Items,
        [Parameter(Mandatory = $true)]
        [String[]]$Include,
        [Parameter(Mandatory = $true)]
        [ScriptBlock]$ScriptBlock,
        [Int]$ThrottleLimit = 30
    )
    process{
        $Items | ForEach-Object {
            Get-ChildItem -Path $_ -Include $Include -Recurse | ForEach-Object{
                Start-ThreadJob -ScriptBlock $ScriptBlock -StreamingHost $Host -ThrottleLimit $ThrottleLimit `
                                    -InputObject $_ | Receive-Job
            }
        }
        Get-Job | Wait-Job | Out-Null

        #        $Items | ForEach-Object {
        #            Get-ChildItem -Path $_ -Include $Include -Recurse | ForEach-Object -Process $ScriptBlock -InputObject $_
        #            {
        #                Start-ThreadJob -ScriptBlock $ScriptBlock -StreamingHost $Host -ThrottleLimit $ThrottleLimit `
        #                                    -ArgumentList $_ | Receive-Job
        #            }
        #        }

    }
}

function Invoke-Ffmpeg
{
    param (
        [Parameter(Mandatory = $true)]
        [FileInfo]$Source,
        [Parameter(Mandatory = $true)]
        [String]$Target,
        [String]$Options,
        [String]$Executable = "c:\Opt\ffmpeg\bin\ffmpeg.exe"
    )
    process{
        $command = "$Executable -loglevel error -y -i `"$Source`" $Options `"$Target`""
        #        Write-Host $command
        Invoke-Expression $command
    }
}

function Convert-Audio
{
    param (
        [Parameter(Mandatory = $true)]
        [FileInfo]$Source,
        [Parameter(Mandatory = $true)]
        [String]$Target,
        [Hashtable]$Metadata,
        [String]$Options
    )
    process{
        Invoke-Ffmpeg -Source $Source -Target $Target -Options "$( Format-Metadata($Metadata) ) $Options"
    }
}

function Copy-Image
{
    param (
        [FileInfo]$Source,
        [FileInfo]$Target,
        [Int]$Frame = 1000
    )
    process{
        Invoke-Ffmpeg -Source $Source -Target $Target -Options "-filter:v `"select=eq(n\,$Frame)`" -frames:v 1"
    }
}

function Convert-AllAudio
{
    param(
        [Parameter(ValueFromPipeline, Mandatory = $true)]
        [String[]]$Paths,
        [String]$Options,
        [Parameter(Mandatory = $true)]
        [String[]]$Include,
        [Parameter(Mandatory = $true)]
        [String]$OutputFormat
    )
    process{
        $Paths | Invoke-ForAllRecursivelyParallel -Include $Include -ThrottleLimit 50 -ScriptBlock {
            $source = Get-Item -Path $input
            $target = Join-Path $source.DirectoryName "$( $source.BaseName ).$using:OutputFormat"
            $metadata = @{
                title = $source.BaseName
            }

            Write-Host "Converting: $target"

            Import-Module -Name $using:PSScriptRoot\ffmpeg
            Convert-Audio -Source $source -Target $target -Metadata $metadata -Options $using:Options
        }
    }
}

function Copy-Audio
{
    param (
        [FileInfo]$source,
        [String]$target,
        [Hashtable]$metadata,
        [String]$options
    )
    Invoke-Ffmpeg -source $source -target $target -options "$( Format-Metadata($metadata) ) $options -vn -c:a copy"
}

function Format-Metadata
{
    param (
        [Parameter(Mandatory = $true)]
        [Hashtable]$data
    )
    foreach ($k in $data.Keys)
    {
        $v = $data[$k]
        if ($v)
        {
            $result += "-metadata $k=`"$v`" "
        }
    }
    return $result
}

Export-ModuleMember -Function Copy-Audio
Export-ModuleMember -Function Copy-Image
Export-ModuleMember -Function Convert-Audio
Export-ModuleMember -Function Convert-AllAudio
Export-ModuleMember -Function Format-Metadata

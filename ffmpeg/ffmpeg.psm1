using namespace System.IO

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

#    Write-Host "$Executable -loglevel error -y -i `"$Source`" $Options `"$Target`""
    Invoke-Expression "$executable -loglevel error -y -i `"$source`" $options `"$target`""
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
    Invoke-Ffmpeg -Source $Source -Target $Target -Options "$( Format-Metadata($Metadata) ) $Options"
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
    $Paths | ForEach-Object {
        Get-ChildItem -Path $_ -Include $Include -Recurse | ForEach-Object{
            Start-ThreadJob -ScriptBlock {
                $source = $using:_
                $target = Join-Path $source.DirectoryName "$( $source.BaseName ).$using:OutputFormat"
                $metadata = @{
                    title = $source.BaseName
                }

                Write-Host "Extracting track: $target"

                Import-Module -Name $using:PSScriptRoot\ffmpeg
                Convert-Audio -Source $source -Target $target -Metadata $metadata -Options $using:Options
            } -StreamingHost $Host -ThrottleLimit 50 -ArgumentList $_ | Receive-Job
        }
    }
    Get-Job | Wait-Job | Out-Null
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

function Copy-Image
{
    param (
        [FileInfo]$Source,
        [FileInfo]$Target,
        [Int]$Frame = 1000
    )
    Invoke-Ffmpeg -source $Source -target $Target -options "-filter:v `"select=eq(n\,$Frame)`" -frames:v 1"
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

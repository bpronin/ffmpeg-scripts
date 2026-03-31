$FfmpegHome = "c:\opt\ffmpeg\bin"

function Invoke-Ffmpeg {
    param (
        [Switch] $Quiet,
        [String] $Arguments
    )
    process {
        $expession = "$FfmpegHome\ffmpeg $Arguments"
        if ($Quiet) {
            $expession += " -loglevel quiet -y"
        } 
        Invoke-Expression $expession
    }
}

function Invoke-Ffprobe {
    param (
        [String] $Arguments
    )
    process {
        Invoke-Expression "$FfmpegHome\ffprobe $Arguments"
    }
}

function Format-Metadata {
    param (
        [Parameter(Mandatory = $true)]
        $data
    )
    foreach ($k in $data.Keys) {
        $v = $data[$k]
        if ($v) {
            $result += "-metadata $k=`"$v`" "
        }
    }
    return $result
}

Export-ModuleMember -Function Invoke-Ffmpeg
Export-ModuleMember -Function Invoke-Ffprobe
Export-ModuleMember -Function Format-Metadata

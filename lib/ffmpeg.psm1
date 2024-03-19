$FfmpegHome = "c:\opt\ffmpeg\bin"

function Invoke-Ffmpeg
{
    param (
        $Arguments
    )
    process{
        Invoke-Expression "$FfmpegHome\ffmpeg $Arguments"
    }
}

function Invoke-Ffprobe
{
    param (
        $Arguments
    )
    process{
        Invoke-Expression "$FfmpegHome\ffprobe $Arguments"
    }
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

Export-ModuleMember -Function Invoke-Ffmpeg
Export-ModuleMember -Function Invoke-Ffprobe

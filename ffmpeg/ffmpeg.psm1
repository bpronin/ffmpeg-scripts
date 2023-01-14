using namespace System.IO

function Invoke-Ffmpeg
{
    param (
        [FileInfo]$source,
        [String]$target,
        [String]$options,
        $ffmpeg = "c:\Opt\ffmpeg\bin\ffmpeg.exe"
    )
    Invoke-Expression "$ffmpeg -loglevel error -y -i `"$source`" $options `"$target`""
#     "$ffmpeg -loglevel error -y -i `"$source`" $options `"$target`""
}

function Convert-Mp3
{
    param (
        [FileInfo]$source,
        [String]$target,
        [String]$title
    )
    Invoke-Ffmpeg -source $source -target $target -options "-metadata title=`"$title`" -acodec mp3 -aq 4"
}

function Copy-Audio
{
    param (
        [FileInfo]$source,
        [String]$target,
        [String]$options
    )
    Invoke-Ffmpeg -source $source -options "$options -vn -c:a copy" -target $target
}

function Copy-Image
{
    param (
        [FileInfo]$source,
        [FileInfo]$target,
        [int]$frame = 1000
    )
    Invoke-Ffmpeg -source $source -target $target -options "-filter:v `"select=eq(n\,$frame)`" -frames:v 1"
}

function Format-Metadata
{
    param (
        $data
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
Export-ModuleMember -Function Convert-Mp3
Export-ModuleMember -Function Format-Metadata

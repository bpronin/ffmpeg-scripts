using namespace System.IO

function Invoke-Ffmpeg
{
    param (
        [FileInfo]$source,
        [String]$target,
        [String]$options,
        [String]$executable = "c:\Opt\ffmpeg\bin\ffmpeg.exe"
    )
    Invoke-Expression "$executable -loglevel error -y -i `"$source`" $options `"$target`""
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
        [Hashtable]$metadata,
        [String]$options
    )
    Invoke-Ffmpeg -source $source -target $target -options "$(Format-Metadata($metadata)) $options -vn -c:a copy"
}

function Copy-Image
{
    param (
        [FileInfo]$source,
        [FileInfo]$target,
        [Int]$frame = 1000
    )
    Invoke-Ffmpeg -source $source -target $target -options "-filter:v `"select=eq(n\,$frame)`" -frames:v 1"
}

function Format-Metadata
{
    param (
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
Export-ModuleMember -Function Convert-Mp3
Export-ModuleMember -Function Format-Metadata

function Invoke-Ffmpeg
{
    param (
        [System.IO.FileInfo]$source,
        [string]$options,
        $ffmpeg = "c:\Opt\ffmpeg\bin\ffmpeg.exe"
    )
    Invoke-Expression "$ffmpeg -loglevel error -y -i `"$source`" $options"
}

function Copy-Audio
{
    param (
        [System.IO.FileInfo]$source,
        [String]$destination,
        [String]$title,
        [String]$options
    )
    Invoke-Ffmpeg -source $source -options "$options -vn -metadata title=`"$title`" -c:a copy `"$destination`""
}

function Copy-Image
{
    param (
        [System.IO.FileInfo]$source,
        [System.IO.FileInfo]$destination
    )
    Invoke-Ffmpeg -source $source -options "-filter:v `"select=eq(n\,1000)`" -frames:v 1 `"$destination`""
}

Export-ModuleMember -Function Copy-Audio
Export-ModuleMember -Function Copy-Image

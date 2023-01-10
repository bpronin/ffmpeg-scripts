$ffmpeg = "c:\Opt\ffmpeg\bin\ffmpeg.exe"

function Invoke-Ffmpeg
{
    param (
        [System.IO.FileInfo]$source,
        [string]$options
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

function Save-Image
{
    param (
        [System.IO.FileInfo]$source
    )
    $destination = [System.IO.Path]::ChangeExtension($source, ".jpg")
    "Extracting cover image: $destination ..."

    Invoke-Ffmpeg -source $source -options "-filter:v `"select=eq(n\,1000)`" -frames:v 1 `"$destination`""
}

function Save-Audio
{
    param (
        [System.IO.FileInfo]$source
    )
    $destination = [System.IO.Path]::ChangeExtension($source, ".$format")
    "Extracting audio: $destination ..."

    Copy-Audio -source $source -destination $destination -title $source.BaseName
}

Export-ModuleMember -Function Save-Audio
Export-ModuleMember -Function Copy-Audio
Export-ModuleMember -Function Save-Image

param (
    [Parameter(Mandatory = $true)]
    [string]$i,
    [string]$format = "m4a",
    [string]$ffmpeg = "c:\Opt\ffmpeg\bin\ffmpeg.exe"
)

[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("windows-1251")

function Read-Time
{
    param (
        [string]$string
    )
    $time_string = $string.Trim()
    if ($time_string.split("\:").count -eq 2)
    {
        $time_string = "00:" + $time_string
    }
    return [timespan]$time_string
}

function Read-Line
{
    param (
        [string] $line
    )
    $data = $line.split(";")
    $title = $data[0].Trim()
    $time = Read-Time $data[1]
    return $title, $time
}

function Format-Time
{
    param (
        [string]$prefix,
        $time
    )
    if ($null -ne $time)
    {
        return "{0}{1:hh\:mm\:ss}" -f $prefix, $time
    }
    else
    {
        return ""
    }
}

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
        [string]$destination,
        [string]$title,
        [string]$options
    )
    Invoke-Ffmpeg -source $source -options "$options -vn -metadata title=`"$title`" -c:a copy `"$destination`""
}

function Save-Image
{
    param (
        [System.IO.FileInfo]$source
    )
    $destination = [System.IO.Path]::ChangeExtension($source, ".jpg")
    "Extracting cover image: $destination"

    Invoke-Ffmpeg -source $source -options "-filter:v `"select=eq(n\,1000)`" -frames:v 1 `"$destination`""
}

function Save-Audio
{
    param (
        [System.IO.FileInfo]$source
    )
    $destination = [System.IO.Path]::ChangeExtension($source, ".$format")
    "Extracting audio: $destination"

    Copy-Audio -source $source -destination $destination -title $source.BaseName
}

function Split-Audio-By-Tracks
{
    param (
        [System.IO.FileInfo]$source,
        [System.IO.FileInfo]$tracklist
    )
    $path = $source.Directory

    $lines = @(Get-Content -Path $tracklist -Encoding UTF8)

    for ($index = 0; $index -lt $lines.count; $index++) {
        $next = $index + 1
        $title, $start = Read-Line $lines[$index]

        $destination = "{0}\{1:d2} - {2}.{3}" -f $path, $next, $title, $format
        "Extracting audio: " + $destination

        if ($next -lt $lines.count)
        {
            $_, $end = Read-Line $lines[$next]
        }
        else
        {
            $end = $null
        }

        $ss = Format-Time "-ss " $start
        $to = Format-Time "-to " $end
        Copy-Audio -source $source -title $title -destination $destination -options "$ss $to -vn -metadata track=`"$next`""
    }
}

function Split-File
{
    param (
        [string]$source_path
    )
    $source = Get-Item -Path $source_path
    "Source: " + $source

    $tracklist = Get-ChildItem -Path "$( $source.Directory )\tracks.txt" -File -ErrorAction Ignore
    if ($tracklist)
    {
        "Track list: " + $tracklist
        Split-Audio-By-Tracks -source $source -tracklist $tracklist
    }
    else
    {
        Save-Audio -source $source
    }

    Save-Image -source $source
}

Split-File -source $i

"Done"

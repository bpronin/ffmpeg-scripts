param (
    [Parameter(Mandatory = $true)]
    [string]$i
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

$source = Get-Item -Path $i
"Source: " + $source

$destination = $source.DirectoryName + "\tracks.txt"
"Destination: " + $destination

$lines = @(Get-Content -Path $source -Encoding UTF8)
[timespan]$start = 0

Out-File -FilePath $destination -Force

for ($index = 0; $index -lt $lines.count; $index++) {
    $next = $index + 1
    $title, $duration = Read-Line $lines[$index]

    $end = $start + $duration

    "$title;$end" | Out-File -FilePath $destination -Append
    $start = $end
}

"Done"

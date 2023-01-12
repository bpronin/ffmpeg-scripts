param (
    [Parameter(Mandatory = $true)]
    [string]$i,
    [string]$f = "m4a"
)

[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("windows-1251")

Import-Module -Name $PSScriptRoot\ffmpeg

function Read-Time
{
    param (
        [string]$string
    )
    $time_string = $string.Trim()
    if ($time_string.split(":").count -eq 2)
    {
        $time_string = "00:" + $time_string
    }
    return [timespan]$time_string
}

function Read-Track
{
    param (
        [String] $source,
        [String] $format
    )
    if ($source -match $format)
    {
        return @{
            title = $Matches["title"].Trim()
            artist = $Matches["artist"].Trim()
            time = Read-Time $Matches["time"]
        }
    }
    else
    {
        return $null
    }
}

function Read-LineFormat
{
    param (
        [String] $line
    )
    if ($line -match "^\[(.+)\]")
    {
        return $Matches[1], 1
    }
    else
    {
        return "(?<title>.+);(?<time>.+)", 0
    }
}

function Save-Image
{
    param (
        [System.IO.FileInfo]$source
    )
    $target = [System.IO.Path]::ChangeExtension($source, ".jpg")
    "Extracting cover image: $target ..."

    Copy-Image -source $source -target $target
}

function Save-Audio
{
    param (
        [System.IO.FileInfo]$source
    )
    $target = [System.IO.Path]::ChangeExtension($source, ".$f")
    "Extracting audio: $target ..."

    Copy-Audio -source $source -target $target -title $source.BaseName
}

function Read-Tracks
{
    param (
        [System.IO.FileInfo]$source
    )

    $lines = @(Get-Content -Path $source -Encoding UTF8)
    $line_format, $start_index = Read-LineFormat $lines[0]
    $tracks = [System.Collections.Arraylist]@()

    for ($index = $start_index; $index -lt $lines.count; $index++) {
        $track = Read-Track -source $lines[$index] -format $line_format
        if ($track)
        {
            $track.index = $tracks.Add($track) + 1
        }
    }

    return $tracks
}

function Format-Metadata
{
    param (
        [Object]$track,
        [int]$tracks_count
    )
    $data = "-metadata track=`"$( $track.index )`" -metadata totaltracks=`"$tracks_count`""
    if ($track.artist)
    {
        $data += " -metadata artist=`"$( $track.artist )`""
    }
    if ($track.composer)
    {
        $data += " -metadata artist=`"$( $track.composer )`""
    }
    if ($track.performer)
    {
        $data += " -metadata artist=`"$( $track.performer )`""
    }
    return $data
}

function Split-Audio
{
    param (
        [System.IO.FileInfo]$source,
        [Object[]]$tracks
    )
    $path = $source.Directory
    $tasks = [System.Collections.Arraylist]@()
    for ($index = 0; $index -lt $tracks.count; $index++) {
        $track = $tracks[$index]
        $next_track = $tracks[$index + 1]
        $target = ("{0}\{1:d2} - {2}.{3}" -f $path, $track.index, $track.title, $f)
        "Extracting track: $target ..."

        $tasks.Add(@{
            source = $source
            target = $target
            title = $track.title
            ss = "-ss $( $track.time )"
            to = $next_track ? "-to $( $next_track.time )" : ""
            metadata = Format-Metadata -track $track -tracks_count $tracks.count
        })> $null
    }

    $tasks | ForEach-Object -Parallel {
        Import-Module -Name $using:PSScriptRoot\ffmpeg
        Copy-Audio -source $( $_.source ) -target $( $_.target ) `
                           -title $( $_.title ) -options "$( $_.ss ) $( $_.to ) $( $_.metadata )"
    } -AsJob -ThrottleLimit 10 | Wait-Job | Receive-Job
}

# --- SCRIPT ENTRY POINT

$source = Get-Item -Path $i
"Source: " + $source

$tracklist = Get-ChildItem -Path "$( $source.Directory )\tracks.txt" -File -ErrorAction Ignore
if ($tracklist)
{
    "Track list: $tracklist"
    Split-Audio -source $source -tracks (Read-Tracks -source $tracklist)
}
else
{
    Save-Audio -source $source
}

Save-Image -source $source

"Done"

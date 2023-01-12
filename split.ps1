param (
    [Parameter(Mandatory = $true)]
    [String]$i,
    [String]$f = "m4a"
)

[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("windows-1251")

Import-Module -Name $PSScriptRoot\ffmpeg

function IfElse
{
    param (
        $condition,
        $yes,
        $no = $null
    )
    if ($condition)
    {
        return $yes
    }
    else
    {
        return $no
    }
}

function SafeTrim
{
    param (
        [String]$string
    )
    return IfElse -condition $string -yes $string.Trim()
}

function Read-Time
{
    param (
        [String]$string
    )
    $time_string = $string.Trim()
    if ($time_string.split(":").count -eq 2)
    {
        $time_string = "00:" + $time_string
    }
    return [TimeSpan]$time_string
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
            title = SafeTrim($Matches["title"])
            time = Read-Time $Matches["time"]
            artist = SafeTrim($Matches["artist"])
            date = SafeTrim($Matches["date"])
            performer = SafeTrim($Matches["performer"])
            composer = SafeTrim($Matches["composer"])
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

function Save-Image
{
    param (
        [System.IO.FileInfo]$source
    )
    $name = [System.IO.Path]::GetFileNameWithoutExtension($source)
    $target = [System.IO.Path]::Combine($source.DirectoryName, "$name-cover.jpg")
    "Extracting cover image: $target ..."

    Copy-Image -source $source -target $target
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
    if ($track.date)
    {
        $data += " -metadata date=`"$( $track.date )`""
    }
    return $data
}

function Normalize-Filename
{
    param (
        [String]$string
    )

    return ((($string -replace "[\\/:|<>]", "¦") -replace "[*]", "·") -replace "[?]", "$") -replace "[\`"]", "'"
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

function Split-Audio
{
    param (
        [System.IO.FileInfo]$source,
        [Object[]]$tracks
    )
    $tasks = [System.Collections.Arraylist]@()
    for ($index = 0; $index -lt $tracks.count; $index++) {
        $track = $tracks[$index]
        $next_track = $tracks[$index + 1]
        $track_file = Normalize-Filename($track.title)
        $target = ("{0}\{1:d2} - {2}.{3}" -f $( $source.Directory ), $track.index, $track_file, $f)
        Write-Host "Extracting track: $target ..."

        $tasks.Add(@{
            source = $source
            target = $target
            title = $track.title
            ss = "-ss $( $track.time )"
            to = IfElse -condition $next_track -yes "-to $( $next_track.time )" -no ""
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

$tracklist_path = [System.IO.Path]::ChangeExtension($source, ".tracks")
if (-not [System.IO.Path]::Exists($tracklist_path))
{
    $tracklist_path = [System.IO.Path]::Combine($source.Directory, "tracks.txt")
}
$tracklist = Get-ChildItem -Path $tracklist_path -File -ErrorAction Ignore
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

#Read-Host "Press enter to continue"

"Done"

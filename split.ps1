param (
    [Parameter(Mandatory = $true)]
    [String]$i,
    [String]$f = "m4a"
)

Import-Module -Name $PSScriptRoot\util
Import-Module -Name $PSScriptRoot\ffmpeg

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
            artist = SafeTrim($Matches["artist"])
            date = SafeTrim($Matches["date"])
            performer = SafeTrim($Matches["performer"])
            composer = SafeTrim($Matches["composer"])
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

function Read-Tracks
{
    param (
        [System.IO.FileInfo]$source
    )

    $lines = @(Get-Content -Path $source -Encoding UTF8)
    $line_format, $start_index = Read-LineFormat $lines[0]
    $tracks = @()

    for ($index = $start_index; $index -lt $lines.count; $index++) {
        $track = Read-Track -source $lines[$index] -format $line_format
        if ($track)
        {
            $tracks += $track
            $track.index = $tracks.count
        }
    }

    return $tracks
}

function Format-Interval
{
    param (
        [PSCustomObject]$track,
        [PSCustomObject]$next_track
    )
    $result = "-ss $( $track.time )"
    if ($next_track)
    {
        $result += " -to $( $next_track.time )"
    }
    return $result
}

function Normalize-Filename
{
    param (
        [String]$name
    )

    return ((($name -replace "[\\/:|<>]", "¦") -replace "[*]", "·") -replace "[?]", "$") -replace "[\`"]", "'"
}

function Get-OutputDir
{
    param (
        [System.IO.FileInfo]$source
    )
    $path = Join-Path -Path $source.Directory -ChildPath $source.BaseName
    return New-Item -ItemType Directory -Path $path -Force
}

function Save-Image
{
    param (
        [System.IO.FileInfo]$source
    )
    $target_path = Get-OutputDir -source $source
    $target = Join-Path $target_path "cover.jpg"
    Write-Host "Extracting cover image: $target ..."

    Copy-Image -source $source -target $target
}

function Save-Audio
{
    param (
        [System.IO.FileInfo]$source
    )
    $title = $source.BaseName
    $target_path = Get-OutputDir($source)
    $target_file = "$(Normalize-Filename -name $title).$f"
    $target = Join-Path $target_path $target_file

    $metadata = Format-Metadata @{
        title = $title
        album = $title
    }

    Write-Host "Extracting track: $target ..."
    Copy-Audio -source $source -target $target -options $metadata
}

function Split-Audio
{
    param (
        [System.IO.FileInfo]$source,
        [PSCustomObject[]]$tracks
    )
    $target_path = Get-OutputDir($source)
    $jobs = @()

    for ($index = 0; $index -lt $tracks.count; $index++) {
        $track = $tracks[$index]
        $next_track = $tracks[$index + 1]
        $target_file = "{0:d2} - $(Normalize-Filename -name $track.title).$f" -f $track.index
        $target = Join-Path $target_path $target_file
        Write-Host "Extracting track: $target ..."

        $jobs += @{
            source = $source
            target = $target
            interval = Format-Interval -track $track -next_track $next_track
            metadata = Format-Metadata @{
                track = $track.index
                title = $track.title
                artist = $track.artist
                composer = $track.composer
                performer = $track.performer
                date = $track.date
                totaltracks = $tracks_count
                album = $source.BaseName
            }
        }
    }

    $jobs | ForEach-Object -Parallel {
        Import-Module -Name $using:PSScriptRoot\ffmpeg
        Copy-Audio -source $( $_.source ) -target $( $_.target ) -options "$( $_.interval ) $( $_.metadata )"
    } -AsJob -ThrottleLimit 10 | Wait-Job | Receive-Job
}

# --- SCRIPT ENTRY POINT

Set-ConsoleEncoding "windows-1251"

$source = Get-Item -Path $i
"Source: " + $source

$tracklist_file = Set-Extension -file $source -extension ".tracks"
if (-not(Test-Path -Path $tracklist_file))
{
    $tracklist_file = Join-Path $source.Directory "tracks.txt"
}

$tracklist = Get-ChildItem -Path $tracklist_file -File -ErrorAction Ignore
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

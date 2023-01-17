param (
    [Parameter(Mandatory = $true)]
    [String]$i,
    [String]$f = "m4a"
)

Import-Module -Name $PSScriptRoot\util
Import-Module -Name $PSScriptRoot\ffmpeg

class Track
{
    [Int]$Index
    [TimeSpan]$Time
    [String]$Title
    [String]$Artist
    [String]$Date
    [String]$Performer
    [String]$Composer
    [String]$Genre
    [String]$Album
    [String]$AlbumArtist
    [Int]$DiskNumber
    [Int]$TotalDisks
}

function Read-Time
{
    param (
        [String]$string
    )
    $time_string = $string.Trim()
    if ($time_string.split(":").count -eq 2)
    {
        $time_string = "00:$time_string"
    }
    return [TimeSpan]$time_string
}

function Read-TrackField
{
    param (
        [String] $value,
        [String] $default_value
    )
    return $value ? $value.Trim() : $default_value
}

function Read-Track
{
    param (
        [String] $string,
        [String] $regex,
        $defaults
    )
    if ($string -match $regex)
    {
        return New-Object Track -Property @{
            Time = Read-Time $Matches.time
            Title = Read-TrackField $Matches.title
            Artist = Read-TrackField $Matches.artist $defaults.artist
            Date = Read-TrackField $Matches.date $defaults.date
            Genre = Read-TrackField $Matches.genre $defaults.genre
            Performer = Read-TrackField $Matches.performer $defaults.performer
            Composer = Read-TrackField $Matches.composer $defaults.composer
            Album = Read-TrackField $Matches.album $defaults.album
            AlbumArtist = Read-TrackField $Matches.album_artist $defaults.album_artist
            DiskNumber = Read-TrackField $Matches.disk_number $defaults.disk_number
            TotalDisks = Read-TrackField $Matches.total_disks $defaults.total_disks
        }
    }
    else
    {
        return $null
    }
}

function Read-Tracks
{
    param (
        $config
    )
    $tracks = @()
    foreach ($line in $config.tracks.raw)
    {
        $track = Read-Track -string $line -regex $config.formats.track -defaults $config.defaults
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
        [Track]$track,
        [Track]$next_track
    )
    $result = "-ss $( $track.time )"
    if ($next_track)
    {
        $result += " -to $( $next_track.time )"
    }
    return $result
}

function Get-OutputDir
{
    param (
        [System.IO.FileInfo]$file
    )
    $path = Join-Path -Path $file.Directory -ChildPath $file.BaseName
    return New-Item -ItemType Directory -Path $path -Force
}

function Save-Image
{
    param (
        [System.IO.FileInfo]$source
    )
    $target_path = Get-OutputDir $source
    $target = Join-Path $target_path "cover.jpg"
    Write-Output "Extracting cover image: $target ..."

    Copy-Image -source $source -target $target
}

function Save-Audio
{
    param (
        [System.IO.FileInfo]$source
    )
    $target_path = Get-OutputDir $source
    $title = $source.BaseName
    $target_file = "$( Get-NormalizedFilename $title ).$f"
    $target = Join-Path $target_path $target_file

    $metadata = Format-Metadata @{
        title = $title
        album = $title
    }

    Write-Output "Extracting track: $target ..."
    Copy-Audio -source $source -target $target -options $metadata
}

function Split-Audio
{
    param (
        [System.IO.FileInfo]$source,
        [Track[]]$track_list,
        $config
    )
    $target_path = Get-OutputDir $source
    $jobs = @()

    for ($index = 0; $index -lt $track_list.count; $index++) {
        $track = $track_list[$index]
        $next_track = $track_list[$index + 1]
        $target_file = "{0:d2} - $( Get-NormalizedFilename $track.title ).$f" -f $track.index
        $target = Join-Path $target_path $target_file
        #        Write-Output "Extracting track: $target ..."

        $jobs += @{
            source = $source
            target = $target
            interval = Format-Interval -track $track -next_track $next_track
            metadata = Format-Metadata @{
                track = $track.Index
                title = $track.Title
                artist = $track.Artist
                composer = $track.Composer
                performer = $track.Performer
                date = $track.Date
                genre = $track.Genre
                album = $track.Album
                album_artist = $track.AlbumArtist
                disc = $track.DiskNumber
                totaldiscs = $track.TotalDisks
                totaltracks = $tracks_count
            }
        }
    }

    $jobs | ForEach-Object -Parallel {
        Import-Module -Name $using:PSScriptRoot\ffmpeg
        #            Write-Output "Extracting track: $($_.target) ..."
        Copy-Audio -source $( $_.source ) -target $( $_.target ) -options "$( $_.interval ) $( $_.metadata )"
    } -AsJob -ThrottleLimit 10 | Wait-Job | Receive-Job
}

# --- SCRIPT ENTRY POINT

Set-ConsoleEncoding "windows-1251"

$source = Get-Item -Path $i
Write-Output "Source: $source"

#$config = (Get-Content -Path (Join-Path $source.Directory "extract-config.json") -ErrorAction Ignore) | ConvertFrom-Ini
$config = Get-IniContent -Path (Join-Path $source.Directory "tracks.ini")
if ($config -and -not$config.defaults.album)
{
    $config.defaults.album = $source.BaseName
}
if ($config -and -not$config.formats.track)
{
    $config.formats.track = "(?<title>.+);(?<time>.+)"
}

$track_list = Read-Tracks -config $config
if ($track_list.count -gt 0)
{
    Write-Output $track_list | Format-Table
    Confirm-Proceed "Proceed with this track list?"
    Split-Audio -source $source -config $config -track_list $track_list
}
else
{
    Confirm-Proceed "Track list is empty. Proceed with single track?"
    Save-Audio -source $source
}

Save-Image -source $source

#Read-Host "Press enter to continue"

"Done"

$include = @("*.mkv", "*.mp4", "*.m4a", "*.webm", "*.ogg")
$formats = @{
    ".mkv"  = "m4a" 
    ".mp4"  = "m4a" 
    ".m4a"  = "m4a" 
    ".webm" = "ogg" 
    ".ogg"  = "ogg"
}

Import-Module .\lib\util.psm1
Import-Module .\lib\ffmpeg.psm1

class Track {
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

function Read-Time {
    param (
        [String]$String
    )
    process {
        $timeString = $String.Trim()
        if ($timeString.split(":").count -eq 2) {
            $timeString = "00:$timeString"
        }
        return [TimeSpan]$timeString
    }
}

function Read-TrackField {
    param (
        [String] $Value,
        [String] $DefaultValue
    )
    process {
        if ($Value) {
            return $Value.Trim()
        }
        else {
            return $DefaultValue
        }
    }
}

function Read-Track {
    param (
        [String] $String,
        [String] $Regex,
        [Hashtable] $Defaults
    )
    process {
        if ($String -match $Regex) {
            return New-Object Track -Property @{
                Index       = Read-TrackField $Matches.index
                Time        = Read-Time $Matches.time
                Title       = Read-TrackField $Matches.title
                Artist      = Read-TrackField $Matches.artist $Defaults.artist
                Date        = Read-TrackField $Matches.date $Defaults.date
                Genre       = Read-TrackField $Matches.genre $Defaults.genre
                Performer   = Read-TrackField $Matches.performer $Defaults.performer
                Composer    = Read-TrackField $Matches.composer $Defaults.composer
                Album       = Read-TrackField $Matches.album $Defaults.album
                AlbumArtist = Read-TrackField $Matches.album_artist $Defaults.album_artist
                DiskNumber  = Read-TrackField $Matches.disk_number $Defaults.disk_number
                TotalDisks  = Read-TrackField $Matches.total_disks $Defaults.total_disks
            }
        }
        else {
            return $null
        }
    }
}

function Read-Tracks {
    param (
        [Hashtable] $Config
    )
    process {
        $tracks = @()
        foreach ($line in $Config.tracks.raw) {
            $track = Read-Track -string $line -regex $Config.formats.track -defaults $Config.defaults
            if ($track) {
                $tracks += $track
                if (-not$track.index) {
                    $track.index = $tracks.count
                }
            }
        }
        return $tracks
    }
}

function Format-Interval {
    param (
        [Track] $track,
        [Track] $next_track
    )
    $result = "-ss $( $track.time )"
    if ($next_track) {
        $result += " -to $( $next_track.time )"
    }
    return $result
}

function Get-OutputDir {
    param (
        [System.IO.FileInfo] $Source
    )
    process {
        $path = Join-Path -Path $Source.Directory -ChildPath $Source.BaseName
        return New-Item -ItemType Directory -Path $path -Force
    }
}

function Save-Image {
    param (
        [System.IO.FileInfo] $Source,
        [Hashtable] $Config
    )
    process {
        $targetPath = Get-OutputDir $Source
        $target = Join-Path $targetPath "cover.jpg"

        Write-Output "Extracting cover image: $target ..."

        Copy-Image -Source $Source -Target $target -Frame $Config.cover.frame
    }
}

function Split-Audio {
    param (
        [System.IO.FileInfo] $Source,
        [Track[]] $TrackList,
        [Hashtable] $Config
    )
    process {

        $targetPath = Get-OutputDir $Source
        $targetExt = $formats[$Source.Extension]
        $tasks = @()

        for ($index = 0; $index -lt $TrackList.count; $index++) {
            $track = $TrackList[$index]
            $nextTrack = $TrackList[$index + 1]           
            $targetFile = "{0:d2} - $( Get-NormalizedFilename $track.title ).$targetExt" -f $track.index
            $target = Join-Path $targetPath $targetFile

            $tasks += @{
                source   = $Source
                target   = $target
                interval = Format-Interval -track $track -next_track $nextTrack
                metadata = @{
                    track        = $track.Index
                    title        = $track.Title
                    artist       = $track.Artist
                    composer     = $track.Composer
                    performer    = $track.Performer
                    date         = $track.Date
                    genre        = $track.Genre
                    album        = $track.Album
                    album_artist = $track.AlbumArtist
                    disc         = $track.DiskNumber
                    totaldiscs   = $track.TotalDisks
                    totaltracks  = $tracks_count
                }
            }
        }

        $tasks | ForEach-Object -Parallel {
            Write-Host "Extracting track: $( $_.target )"

            Import-Module -Name $using:PSScriptRoot\ffmpeg
            Convert-Audio -Source $_.source -Target $_.target -Metadata $_.metadata `
                -Options "$( $_.interval ) -vn -c:a copy"
            # -Options "$( $_.interval ) -vn -c:a aac"
        }
    }
}

function Split-File() {
    param(
        [System.IO.FileInfo] $Source
    )
    process {
        Write-Output "Source: $Source"

        $config_path = Join-Path $Source.Directory "tracks.ini"
        if (-not(Test-Path -Path $config_path) -or -not(Confirm-Proceed("Found tracks.ini file. Proceed with it?"))) {
            $config_path = Get-Item -Path "$PSScriptRoot\default-tracks.ini"
        }

        $config = Get-Content -Path $config_path | ConvertFrom-Ini
        if ($config.defaults -and -not$config.defaults.album) {
            $config.defaults.album = $Source.BaseName
        }

        if ($config.formats -and -not$config.formats.track) {
            $config.formats.track = "(?<title>.+);(?<time>.+)"
        }

        $track_list = Read-Tracks -config $config
        if ($track_list.count -gt 0) {
            Write-Output $track_list | Format-Table
            Confirm-ProceedOrExit "Proceed with the tracks?"
        }
        else {
            $track_list += New-Object Track -Property @{
                Title       = $Source.BaseName
                Artist      = $config.defaults.artist
                Date        = $config.defaults.date
                Genre       = $config.defaults.genre
                Performer   = $config.defaults.performer
                Composer    = $config.defaults.composer
                Album       = $config.defaults.album
                AlbumArtist = $config.defaults.album_artist
                DiskNumber  = $config.defaults.disk_number
                TotalDisks  = $config.defaults.total_disks
            }
            #        Write-Output $track_list | Format-Table
            #        Confirm-ProceedOrExit "No track list data. Proceed with single track?"
        }

        Split-Audio -Source $Source -Config $config -TrackList $track_list
        
        if ($config.cover) {
            Save-Image -Source $Source -Config $config
        }
    }
}

# --- SCRIPT ENTRY POINT

Set-ConsoleEncoding "windows-1251"

$args | ForEach-Object {
    $path = Get-Item -Path $_
    Write-Output "Path: $path"

    if ($path.PSIsContainer) {
        Get-ChildItem -Path $path -Recurse -Include $include | Foreach-Object {
            Split-File -source $_
        }
    }
    else {
        Split-File -source $path
    }
}

Write-Output "Done"
Read-Host
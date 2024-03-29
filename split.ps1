﻿$ErrorActionPreference = "Break"
$IncludeFiles = @("*.mkv", "*.mp4", "*.m4a", "*.webm", "*.ogg")
$Formats = @{
    ".mkv"  = "m4a" 
    ".mp4"  = "m4a" 
    ".m4a"  = "m4a" 
    ".webm" = "ogg" 
    ".ogg"  = "ogg"
}
$FFmpeg = "C:\Opt\ffmpeg\bin\ffmpeg.exe"

Import-Module .\lib\util.psm1

class Track {
    [Int]$Index
    $Start
    $Duration
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
        if (-not $String) {
            return $Null
        }

        $TimeString = $String.Trim()
        if ($TimeString.Split(":").count -eq 2) {
            $TimeString = "00:$TimeString"
        }
        return [TimeSpan]$TimeString
    }
}

function Get-TrackRegex {
    param (
        [String]$Format
    )
    process {
        return $Format`
            -replace "{artist}|{author}", "(?<artist>.+)"`
            -replace "{title}", "(?<title>.+)"`
            -replace "{start}|{time}", "(?<start>[\d:]+\.?\d+)"`
            -replace "{duration}", "(?<duration>[\d:]+\.?\d+)"`
            -replace "{index}|{track}", "(?<index>\d+)"`
            -replace "(\s+)", "\s+"  
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
        [Int] $Index,
        [String] $String,
        [String] $Regex,
        [Hashtable] $Defaults
    )
    process {
        if ($String -match $Regex) {
            return New-Object Track -Property @{
                Index       = Read-TrackField $Matches.index $Index
                Start       = Read-Time $Matches.start
                Duration    = Read-Time $Matches.duration
                Title       = Read-TrackField $Matches.title
                Artist      = Read-TrackField $Matches.artist $Defaults.artist
                Date        = Read-TrackField $Matches.date $Defaults.date
                Genre       = Read-TrackField $Matches.genre $Defaults.genre
                Performer   = Read-TrackField $Matches.performer $Defaults.performer
                Composer    = Read-TrackField $Matches.composer $Defaults.composer
                Album       = Read-TrackField $Matches.album $Defaults.album
                AlbumArtist = Read-TrackField $Matches.album_artist $Defaults.album_artist
                DiskNumber  = Read-TrackField $Matches.disk_number 1
                TotalDisks  = Read-TrackField $Matches.total_disks 1
            }
        }
        else {
            throw "Invalid regex [$Regex] or track string [$String]"
        }
    }
}
function Read-TrackList {
    param(
        [System.IO.FileInfo] $ConfigPath
    )
    process {
        if (Test-Path $ConfigPath) {
            Write-Host "Tracks: $ConfigPath"
            $Config = Get-Content $ConfigPath
        }
        else {            
            throw "Tracks file [$ConfigPath] not found."
        }       
        
        $Format = Get-TrackRegex $Config[0]
        $TrackStart = 0
        $TrackList = @()
        for ($i = 1; $i -lt $Config.Count; $i++) {
            $Track = Read-Track -Index $i -String $Config[$i] -Regex $Format
            
            if ($Track.Duration) {
                $Track.Start = $TrackStart
                $TrackStart += $Track.Duration
            }
            
            $TrackList += $Track
        }       
        
        return $TrackList
    }
}

function Get-OutputDir {
    param (
        [System.IO.FileInfo] $Source
    )
    process {
        $Path = Join-Path -Path $Source.Directory -ChildPath $Source.BaseName
        return New-Item -ItemType Directory -Path $Path -Force
    }
}

function Invoke-Ffmpeg {
    param (
        [System.IO.FileInfo] $Source,
        [Track[]] $TrackList
    )
    process {
        $TargetPath = Get-OutputDir $Source
        $TargetExt = $Formats[$Source.Extension]

        $CoverFile = "$TargetPath\folder.jpg"
        Write-Host "Extracting cover art: $CoverFile"
        Invoke-Expression "$FFmpeg -loglevel error -y -i `"$Source`" -c:v copy -an `"$CoverFile`""  
        
        $Tasks = @()
        for ($i = 0; $i -lt $TrackList.Count; $i++) {
            $Tasks += @{
                Track     = $TrackList[$i]
                NextTrack = $TrackList[$i + 1]
            }
        }
            
        $Tasks | ForEach-Object -Parallel {
            Import-Module .\lib\util.psm1
            $Track = $_.Track
            $TargetFile = "{0:d2} - $( Get-NormalizedFilename $Track.Title ).$using:TargetExt" -f $Track.Index
            $Target = Join-Path $using:TargetPath $TargetFile

            $Command = "$using:FFmpeg -loglevel error -y"
            $Command += " -i `"$using:Source`"" 
            $Command += " -ss $($Track.Start)"
            
            if ($_.NextTrack) {
                $Command += " -to $( $_.NextTrack.Start )"
            } 

            $Command += " -map_chapters -1"
            $Command += " -metadata track=`"$($Track.Index)`""
            $Command += " -metadata title=`"$($Track.Title)`""
            $Command += " -metadata artist=`"$($Track.Artist)`""
            $Command += " -metadata composer=`"$($Track.Composer)`""
            $Command += " -metadata performer=`"$($Track.Performer)`""
            $Command += " -metadata date=`"$($Track.Date)`""
            $Command += " -metadata genre=`"$($Track.Genre)`""
            $Command += " -metadata album=`"$($Track.Album)`""
            $Command += " -metadata album_artist=`"$($Track.AlbumArtist)`""
            $Command += " -metadata disc=`"$($Track.DiskNumber)`""
            $Command += " -metadata totaldiscs=`"$($Track.TotalDisks)`""
            $Command += " -metadata totalTracks=`"$($using:TrackList.Count)`""
            $Command += " -vn -c:a copy"
            $Command += " `"$Target`""
            
            Write-Host "Extracting: $Target"
            # $Command
            Invoke-Expression $Command            
        }
    }
}

function Convert-File {
    param(
        [System.IO.FileInfo] $Source
    )
    process {
        Write-Host "Source: $Source"
        
        $Config = Rename-FileExtension -File $Source -NewExtension ".txt"
        $TrackList = Read-TrackList $Config

        $TrackList | Format-Table

        Confirm-ProceedOrExit "Proceed with these tracks?"
        Invoke-Ffmpeg -Source $Source -TrackList $TrackList
    }
}

# --- SCRIPT ENTRY POINT ---

Set-ConsoleEncoding "windows-1251"

Get-FilesCollection -Paths $args -Include $IncludeFiles | ForEach-Object {
    Convert-File -Source $_
}
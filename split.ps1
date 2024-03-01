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
        if (-not $String){
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
            -replace "{artist}", "(?<artist>.+)"`
            -replace "{title}", "(?<title>.+)"`
            -replace "{start}", "(?<start>[\d:]+\.?\d+)"`
            -replace "{duration}", "(?<duration>[\d:]+\.?\d+)"`
            -replace "{index}", "(?<index>\d+)"`
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
            return $Null
        }
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

function Split-Audio {
    param (
        [System.IO.FileInfo] $Source,
        [Track[]] $TrackList
    )
    process {
        $TargetPath = Get-OutputDir $Source
        $TargetExt = $Formats[$Source.Extension]
        
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

            Write-Host "Extracting track: $Target"

            $Command = "$using:FFmpeg -loglevel error -y"
            $Command += " -i `"$using:Source`""
 
            $Command += " -ss $($Track.Start)"
            
            if ($_.NextTrack) {
                $Command += " -to $( $_.NextTrack.Start )"
            } 

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
        Write-Output "Source: $Source"
        
        $ConfigPath = Rename-FileExtension -File $Source -Extension "txt"
        if (Test-Path $ConfigPath) {
            Write-Output "Tracks: $ConfigPath"
            $Config = Get-Content $ConfigPath
        }
        else {            
            Write-Output "Tracks file not found. Proceeding with single track."
            $Config = @("{start} {title}", "00:00 $($Source.BaseName)")
        }       
        
        $Format = Get-TrackRegex $Config[0]
        $TrackList = @()
        for ($i = 1; $i -lt $Config.Count; $i++) {
            $Track = Read-Track -Index $i -String $Config[$i] -Regex $Format
            $TrackList += $Track        
        }       

        Write-Output $TrackList | Format-Table
        Confirm-ProceedOrExit "Proceed with these tracks?"

        Split-Audio -Source $Source -TrackList $TrackList
    }
}

# --- SCRIPT ENTRY POINT ---

Set-ConsoleEncoding "windows-1251"

$Args | ForEach-Object {
    $Path = Get-Item -Path $_
    Write-Output "Path: $Path"

    if ($Path.PSIsContainer) {
        Get-ChildItem -Path $Path -Recurse -IncludeFiles $IncludeFiles | Foreach-Object {
            Convert-File -Source $_
        }
    }
    else {
        Convert-File -Source $Path        
    }
}

if ($Error) {
    Write-Host "Press a key."
    Read-Host
}
else {
    Write-Host "Done" -ForegroundColor DarkGreen
}
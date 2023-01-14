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

function Read-Track
{
    param (
        [String] $string,
        [String] $format
    )
    if ($string -match $format)
    {
        return New-Object Track -Property @{
            title = SafeTrim $Matches["title"]
            artist = SafeTrim $Matches["artist"]
            date = SafeTrim $Matches["date"]
            performer = SafeTrim $Matches["performer"]
            composer = SafeTrim $Matches["composer"]
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
        [String] $string
    )
    if ($string -match "^\[(.+)\]")
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
        [System.IO.FileInfo]$file
    )

    $lines = @(Get-Content -Path $file -Encoding UTF8)
    $line_format, $start_index = Read-LineFormat $lines[0]
    $tracks = @()

    for ($index = $start_index; $index -lt $lines.count; $index++) {
        $track = Read-Track -string $lines[$index] -format $line_format
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
    $title = $source.BaseName
    $target_path = Get-OutputDir $source
    $target_file = "$( Get-NormalizedFilename $title ).$f"
    $target = Join-Path $target_path $target_file

    $metadata = Format-Metadata @{
        title = $title
        album = $title
    }

    Write-Output "Extracting track: $target ..."
    Copy-Audio -source $source -target $target -options $metadata
}

function Confirm-Proceed
{
    param (
        [String]$message
    )

    $input = (Read-Host "$message (y/n)").ToLower()
    if ($input -and -not $input.StartsWith("y"))
    {
        exit
    }
}

function Split-Audio
{
    param (
        [System.IO.FileInfo]$source,
        [Track[]]$tracklist
    )
    $target_path = Get-OutputDir $source
    $jobs = @()

    for ($index = 0; $index -lt $tracklist.count; $index++) {
        $track = $tracklist[$index]
        $next_track = $tracklist[$index + 1]
        $target_file = "{0:d2} - $( Get-NormalizedFilename $track.title ).$f" -f $track.index
        $target = Join-Path $target_path $target_file
#        Write-Output "Extracting track: $target ..."

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
#            Write-Output "Extracting track: $($_.target) ..."
            Copy-Audio -source $( $_.source ) -target $( $_.target ) -options "$( $_.interval ) $( $_.metadata )"
        } -AsJob -ThrottleLimit 10 | Wait-Job | Receive-Job
}

# --- SCRIPT ENTRY POINT

Set-ConsoleEncoding "windows-1251"

$source = Get-Item -Path $i
"Source: " + $source

$tracklist_filename = Set-Extension -file $source -extension ".tracks"
if (-not(Test-Path -Path $tracklist_filename))
{
    $tracklist_filename = Join-Path $source.Directory "tracks.txt"
}

$tracklist_file = Get-ChildItem -Path $tracklist_filename -File -ErrorAction Ignore
if ($tracklist_file)
{
    Write-Output "Track list: $tracklist_file"

    $tracklist = Read-Tracks $tracklist_file
    if ($tracklist.count -gt 0){
        Write-Output $tracklist | Format-Table
        Confirm-Proceed "Proceed with this tracklist?"

        Split-Audio -source $source -tracklist $tracklist
    }
    else
    {
        Confirm-Proceed "Tracklist is empty. Proceed?"
    }
}
else
{
    Save-Audio -source $source
}

Save-Image -source $source

#Read-Host "Press enter to continue"

"Done"

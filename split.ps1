param (
    [Parameter(Mandatory = $true)]
    [String]$i,
    [String]$f = "m4a"
)

#Add-Type -TypeDefinition System.IO
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

function Format-Interval
{
    param (
        $track,
        $next_track
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
        [String]$string
    )

    return ((($string -replace "[\\/:|<>]", "¦") -replace "[*]", "·") -replace "[?]", "$") -replace "[\`"]", "'"
}

function Save-Image
{
    param (
        [System.IO.FileInfo]$source
    )
    $name = [System.IO.Path]::GetFileNameWithoutExtension($source)
    $target_path = [system.io.directory]::CreateDirectory([System.IO.Path]::Combine($source.Directory, $name))
    $target = [System.IO.Path]::Combine($target_path, "cover.jpg")
    Write-Host "Extracting cover image: $target ..."

    Copy-Image -source $source -target $target
}

function Save-Audio
{
    param (
        [System.IO.FileInfo]$source
    )
    $target = [System.IO.Path]::ChangeExtension($source, ".$f")
    Write-Host "Extracting audio: $target ..."

    Copy-Audio -source $source -target $target -title $source.BaseName
}

function Split-Audio
{
    param (
        [System.IO.FileInfo]$source,
        [Object[]]$tracks
    )
    $jobs = [System.Collections.Arraylist]@()
    $album = [System.IO.Path]::GetFileNameWithoutExtension($source)
    $target_path = [system.io.directory]::CreateDirectory([System.IO.Path]::Combine($source.Directory, $album))

    for ($index = 0; $index -lt $tracks.count; $index++) {
        $track = $tracks[$index]
        $next_track = $tracks[$index + 1]
        $track_file = Normalize-Filename($track.title)
        $target = ("{0}\{1:d2} - {2}.{3}" -f $target_path, $track.index, $track_file, $f)
        Write-Host "Extracting track: $target ..."

        $jobs.Add(@{
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
                album = $album
            }
        })> $null
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

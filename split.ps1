param (
    [Parameter(Mandatory = $true)]
    [string]$i,
    [string]$format = "m4a"
)

[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("windows-1251")

Import-Module -Name $PSScriptRoot\ffmpeg

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

function Split-Audio-By-Tracks
{
    param (
        [System.IO.FileInfo]$source,
        [System.IO.FileInfo]$tracklist
    )

    $path = $source.Directory
    $lines = @(Get-Content -Path $tracklist -Encoding UTF8)
    $tasks = @($null) * $lines.Length

    for ($index = 0; $index -lt $lines.count; $index++) {
        $next = $index + 1
        $title, $start = Read-Line $lines[$index]

        $destination = "{0}\{1:d2} - {2}.{3}" -f $path, $next, $title, $format

        if ($next -lt $lines.count)
        {
            $_, $end = Read-Line $lines[$next]
        }
        else
        {
            $end = $null
        }

        $tasks[$index] = @{
            source = $source
            index = $next
            title = $title
            ss = Format-Time "-ss " $start
            to = Format-Time "-to " $end
            destination = $destination
        }
    }

    $tasks | ForEach-Object -Parallel {
        Import-Module -Name $using:PSScriptRoot\ffmpeg

        "Extracting audio: $( $_.destination ) ..."
        Copy-Audio -source $( $_.source ) `
                   -destination $( $_.destination ) `
                   -title $( $_.title ) `
                   -options "$( $_.ss ) $( $_.to ) -vn -metadata track=`"$( $_.index )`""
    } -AsJob -ThrottleLimit 10 | Wait-Job | Receive-Job
}

function Split-File
{
    param (
        [string]$source_path
    )
    $source = Get-Item -Path $source_path
    "Source: " + $source

    $tracklist = Get-ChildItem -Path "$( $source.Directory )\tracks.txt" -File -ErrorAction Ignore
    if ($tracklist)
    {
        "Track list: " + $tracklist
        Split-Audio-By-Tracks -source $source -tracklist $tracklist
    }
    else
    {
        Save-Audio -source $source
    }

    Save-Image -source $source
}

Split-File -source $i

"Done"

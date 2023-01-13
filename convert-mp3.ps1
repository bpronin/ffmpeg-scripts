Import-Module -Name $PSScriptRoot\util

$SUPPORTED_FORMATS = @(".flac", ".mkv", ".mp4", ".m4a")

function Add-Tasks
{
    param (
        [System.IO.FileSystemInfo]$item,
        [ref]$jobs
    )

    if ($item.PSIsContainer)
    {
        Get-ChildItem -Path $item -Recurse | ForEach-Object{
            Add-Tasks -item $_ -tasks $jobs
        }
    }
    elseif ($item.Extension -in $SUPPORTED_FORMATS)
    {
        $target = Set-Extension -file $item -extension ".mp3"
        Write-Host "Converting: $target  ..."

        $jobs.value += @{
            source = $item
            target = $target
            title = $item.BaseName
        }
    }
}

$jobs = @()

foreach ($path in $args)
{
    Add-Tasks -item (Get-Item -Path $path) -tasks ([ref]$jobs)
}

$jobs | ForEach-Object -Parallel {
    Import-Module -Name $using:PSScriptRoot\ffmpeg
    Convert-Mp3 -source $( $_.source ) -target $( $_.target ) -title $( $_.title )
}  -AsJob -ThrottleLimit 50 | Wait-Job | Receive-Job

"Done"
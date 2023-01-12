using namespace System.IO
using namespace System.Collections

$SUPPORTED_FORMATS = @(".flac", ".mkv", ".mp4", ".m4a")

function Add-Tasks
{
    param (
        [FileSystemInfo]$item,
        [ref]$tasks
    )

    if ($item.PSIsContainer)
    {
        Get-ChildItem -Path $item -Recurse | ForEach-Object{
            Add-Tasks -item $_ -tasks $tasks
        }
    }
    elseif ($item.Extension -in $SUPPORTED_FORMATS)
    {
        $target = [Path]::ChangeExtension($item, ".mp3")
        "Converting: $target  ..."
        $tasks.value.Add(@{
            source = $item
            target = $target
            title = $item.BaseName
        }) > $null
    }
}

$tasks = [Arraylist]@()

foreach ($path in $args)
{
    Add-Tasks -item (Get-Item -Path $path) -tasks ([ref]$tasks)
}

$tasks | ForEach-Object -Parallel {
    Import-Module -Name $using:PSScriptRoot\ffmpeg
    Convert-Mp3 -source $( $_.source ) -target $( $_.target )  -title $( $_.title )
}  -AsJob -ThrottleLimit 50 | Wait-Job | Receive-Job

"Done"
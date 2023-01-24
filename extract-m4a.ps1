Import-Module -Name $PSScriptRoot\util

$supported_ext = @(".mkv", ".mp4")

function Add-Tasks
{
    param (
        [System.IO.FileSystemInfo]$path,
        [ref]$tasks
    )

    if ($path.PSIsContainer)
    {
        Get-ChildItem -Path $path -Recurse | ForEach-Object{
            Add-Tasks -item $_ -tasks $tasks
        }
    }
    else
    {
        $tasks.value += @{
            source = $path
            target = Set-Extension -File $path -Extension ".m4a"
            metadata = @{
                title = $path.BaseName
            }
        }
    }
}

$tasks = @()

foreach ($path in $args)
{
    Add-Tasks -path (Get-Item -Path $path) -tasks ([ref]$tasks)
}

foreach ($task in $tasks)
{
    Start-ThreadJob -ScriptBlock {
        Import-Module -Name $using:PSScriptRoot\ffmpeg
        $t = $using:task
        Write-Host "Extracting track: $( $t.target )"
        Copy-Audio -source $t.source -target $t.target -metadata $t.metadata
    } -StreamingHost $Host -ThrottleLimit 30 | Receive-Job
}
Get-Job | Wait-Job | Out-Null

Write-Output "Done"
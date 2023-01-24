$include = @("*.flac", "*.mkv", "*.mp4", "*.m4a")

$args | ForEach-Object {
    Get-ChildItem -Path $_ -Include $include -Recurse | ForEach-Object{
        Start-ThreadJob -ScriptBlock {
            $source = $using:_
            $target = Join-Path $source.DirectoryName "$($source.BaseName).mp3"
            $metadata = @{
                title = $source.BaseName
            }

            Write-Host "Extracting track: $target"

            Import-Module -Name $using:PSScriptRoot\ffmpeg
            Convert-Audio -source $source -target $target -metadata $metadata -options "-acodec mp3 -aq 4"
        } -StreamingHost $Host -ThrottleLimit 50 -ArgumentList $_ | Receive-Job
    }
}

Get-Job | Wait-Job | Out-Null

Write-Output "Done"

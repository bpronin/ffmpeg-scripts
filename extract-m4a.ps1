$include = @("*.mkv", "*.mp4")

$args | ForEach-Object {
    Get-ChildItem -Path $_ -Include $include -Recurse | ForEach-Object{
        Start-ThreadJob -ScriptBlock {
                $source = $using:_
                $target = Join-Path $source.DirectoryName "$($source.BaseName).m4a"
                $metadata = @{
                    title = $source.BaseName
                }

                Write-Host "Extracting track: $target"

                Import-Module -Name $using:PSScriptRoot\ffmpeg
                Copy-Audio -source $source -target $target -metadata $metadata
        } -StreamingHost $Host -ThrottleLimit 50 -ArgumentList $_ | Receive-Job
    }
}

Get-Job | Wait-Job | Out-Null

Write-Output "Done"
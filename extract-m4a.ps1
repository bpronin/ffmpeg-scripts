Import-Module -Name $PSScriptRoot\util
Import-Module -Name $PSScriptRoot\ffmpeg

$include = @("*.mkv", "*.mp4")
$tasks = @()

$args | ForEach-Object {
    Get-ChildItem -Path $_ -Include $include -Recurse | ForEach-Object{
        $tasks += @{
            source = $_
            target = Set-Extension -File $_ -Extension ".m4a"
            metadata = @{
                title = $_.BaseName
            }
        }
    }
}

$tasks | ForEach-Object {
    Start-ThreadJob -ScriptBlock {
        $task = $using:_
        Write-Host "Extracting track: $( $task.target )"
        Import-Module -Name $using:PSScriptRoot\ffmpeg
        Copy-Audio -source $task.source -target $task.target -metadata $task.metadata
    } -StreamingHost $Host -ThrottleLimit 50 -ArgumentList $_ | Receive-Job
}

Get-Job | Wait-Job | Out-Null

Write-Output "Done"
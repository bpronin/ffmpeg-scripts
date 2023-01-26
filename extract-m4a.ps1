Import-Module -Name $PSScriptRoot\ffmpeg

$args | Convert-AllAudio -Include @("*.mkv", "*.mp4") `
                         -OutputFormat "m4a" `
                         -Options "-vn -c:a copy"

Write-Output "Done"
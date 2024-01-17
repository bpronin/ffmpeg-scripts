Import-Module .\lib\ffmpeg.psm1

$args | Convert-AllAudio -Include @("*.flac", "*.mkv", "*.mp4", "*.m4a") `
                         -OutputFormat "ac3" `
                         -Options "-acodec ac3 -ab 448k -ar 48000"

Write-Output "Done"

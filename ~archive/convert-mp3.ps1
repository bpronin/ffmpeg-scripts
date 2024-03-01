Import-Module .\lib\ffmpeg.psm1

$args | Convert-AllAudio -Include @("*.flac", "*.mkv", "*.mp4", "*.m4a") `
                         -OutputFormat "mp3" `
                         -Options "-acodec mp3 -aq 4"

Write-Output "Done"

Import-Module .\lib\util.psm1

$ErrorActionPreference = "Break"
$FfmpegHome = "c:\opt\ffmpeg\bin"
$ProcessibleFiles = @("*.m4a")

# --- SCRIPT ENTRY POINT ---

Get-FilesCollection -Paths $args -Include $ProcessibleFiles | ForEach-Object {
    $Source = $_ 

    $Metadata = Invoke-Expression "$FfmpegHome\ffprobe -i `"$Source`" -show_entries format -show_chapters -of json -sexagesimal -loglevel error" 
    | Out-String | ConvertFrom-Json

    $TargetPath = "$($Source.Directory)\chapters" 
    New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
    
    $CoverFile = "$TargetPath\folder.jpg"
    Write-Host "Extracting cover art: $CoverFile"
    Invoke-Expression "$FfmpegHome\ffmpeg -loglevel error -y -i `"$Source`" -c:v copy -an `"$CoverFile`""  

    $Metadata.chapters | ForEach-Object -Parallel {
        $Chapter = $_
        $TrackIndex = $Chapter.id + 1
        $TrackTitle = $Chapter.tags.title
        $Target = "$using:TargetPath\$TrackIndex - $TrackTitle$($using:Source.Extension)"

        $Command = "$using:FfmpegHome\ffmpeg -loglevel error -y" `
            + " -i `"$using:Source`"" `
            + " -ss $($Chapter.start_time)" `
            + " -to $($Chapter.end_time)" `
            + " -map_chapters -1" `
            + " -metadata track=`"$TrackIndex`"" `
            + " -metadata title=`"$TrackTitle`"" `
            + " -vn -c:a copy `"$Target`""
            
        Write-Host "Extracting: $Target"
        Invoke-Expression $Command | Out-Default
    } 
}

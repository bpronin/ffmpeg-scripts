$ErrorActionPreference = "Stop"
# $PSStyle.Progress.View = 'Classic'

$FfmpegHome = "c:\opt\ffmpeg\bin"
$ImageMagickHome = "c:\opt\imagic" 
$Include = @("*.mp3", "*.m4a", "*.ogg")

Import-Module .\lib\util.psm1

function ProcessFile {
    param (
        [System.IO.FileInfo]$InputFile
    )
    process {
        # $InputFile

        $CoverFile = "$($InputFile.Directory)\~cover.jpg"
        Invoke-Expression "$FfmpegHome\ffmpeg -i `"$InputFile`" -c:v copy -an -y -loglevel error `"$CoverFile`""      
    
        if (Test-Path $CoverFile) {
            Invoke-Expression "$ImageMagickHome\magick mogrify -resize 400x400 -quality 80 -format jpg `"$CoverFile`""    

            $StrippedFile = "$($InputFile.Directory)\~temp$($InputFile.Extension)"
            Invoke-Expression "$FfmpegHome\ffmpeg -i `"$InputFile`" -c copy -vn -y -loglevel error `"$StrippedFile`""

            $ResizedFile = "$($InputFile.Directory)\~~temp$($InputFile.Extension)"
            Invoke-Expression "$FfmpegHome\ffmpeg -i `"$StrippedFile`" -i `"$CoverFile`" -c copy -map 0 -map 1 -y -loglevel error `"$ResizedFile`""

            Remove-Item -Path $CoverFile
            Remove-Item -Path $StrippedFile
            Remove-Item -Path $InputFile       
            Rename-Item -Path $ResizedFile -NewName $InputFile        
        }
    }
}

# --- SCRIPT ENTRY POINT

$Items = Get-FilesCollection -Paths @Args -Include $Include
$n = $Items.Count
for ($i = 0; $i -lt $n; $i++) {
    ProcessFile $Items[$i]
    Write-Progress -Activity "Processing" -Status "$i of $n" -PercentComplete (($i / $n) * 100)
}
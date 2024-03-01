$FfmpegHome = "c:\opt\ffmpeg\bin"
$ImageMagickHome = "c:\`"Program Files`"\ImageMagick-7.1.1-Q16-HDRI" 

$Include = @("*.mp3", "*.m4a", "*.ogg")

# --- SCRIPT ENTRY POINT

function ProcessFile {
    param (
        [System.IO.FileInfo]$InputFile
    )
    Write-Output "$InputFile"  
    
    $CoverFile = "$($InputFile.Directory)\~cover.jpg"

    Invoke-Expression "$FfmpegHome\ffmpeg -i `"$InputFile`" -c:v copy -an -y -loglevel error `"$CoverFile`""      
    
    if (Test-Path $CoverFile) {
        $TempFile1 = "$($InputFile.Directory)\~temp$($InputFile.Extension)"
        $TempFile2 = "$($InputFile.Directory)\~~temp$($InputFile.Extension)"

        Invoke-Expression "$ImageMagickHome\magick mogrify -resize 400x400 -quality 80 -format jpg `"$CoverFile`""    
        Invoke-Expression "$FfmpegHome\ffmpeg -i `"$InputFile`" -c copy -vn -y -loglevel error `"$TempFile1`""
        if ($Error) { 
            $Error
            Exit 
        }
        Invoke-Expression "$FfmpegHome\ffmpeg -i `"$TempFile1`" -i `"$CoverFile`" -c copy -map 0 -map 1 -y -loglevel error `"$TempFile2`""
        if ($Error) { 
            $Error
            Exit 
        }
        # Invoke-Expression "$FfmpegHome\ffmpeg -i `"$InputFile`" -i `"$CoverFile`" -c copy -map 0 -map 1 -y -loglevel error `"$TempFile`""
        

        Remove-Item -Path $CoverFile
        Remove-Item -Path $TempFile1
        Remove-Item -Path $InputFile       
        Rename-Item -Path $TempFile2 -NewName $InputFile        
    }
}
function IterateFiles {
    param (
        $Path
    )

    $Item = Get-Item -Path $Path
    if ($Item.PSIsContainer) {
        Get-ChildItem -Path $Path -Recurse -Include $Include | Foreach-Object {
            IterateFiles $_
        }
    }
    else {
        ProcessFile -InputFile $Item
    }    
}


$args | ForEach-Object {
    IterateFiles -Path $_
}

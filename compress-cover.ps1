$ErrorActionPreference = "Stop"

# $Include = @("*.mp3", "*.m4a", "*.ogg") 
# m4a does not copy all metadata tags
$Include = @("*.mp3")

Import-Module .\lib\util.psm1

function Invoke-Ffmpeg {
    param (
        [string]$Options
    )
    process {
        Invoke-Expression "c:\opt\ffmpeg\bin\ffmpeg -y $Options"      
        # Invoke-Expression "c:\opt\ffmpeg\bin\ffmpeg $Options"      
    }
}

function Invoke-Imagick {
    param (
        [string]$Options
    )
    process {
        Invoke-Expression "c:\opt\imagick\magick $Options"      
    }
}

function ProcessFile {
    param (
        [System.IO.FileInfo]$InputFile
    )
    process {
        # $InputFile

        $CoverFile = Rename-FileExtension -File $InputFile -NewExtension "jpg"
        Invoke-Ffmpeg "-i `"$InputFile`" -c:v copy -an -loglevel quiet `"$CoverFile`""      
    
        if (Test-Path $CoverFile) {
            Invoke-Imagick "mogrify -resize 400x400 -quality 80 -format jpg `"$CoverFile`""    

            $TempFile = Rename-FileExtension -File $InputFile -Prefix "~"
            Invoke-Ffmpeg "-i `"$InputFile`" -i `"$CoverFile`" -c copy -map 0:a -map 1:v -id3v2_version 3 -loglevel error `"$TempFile`""
            # Invoke-Ffmpeg "-i `"$InputFile`" -i `"$CoverFile`" -c copy -map 0:a -map 1:v -id3v2_version 3 -disposition:v attached_pic `"$TempFile`"" #for m4a

            Remove-Item -Path $CoverFile
            Remove-Item -Path $InputFile       
            Rename-Item -Path $TempFile -NewName $InputFile        
        }
    }
}

# --- SCRIPT ENTRY POINT ---
# $PSStyle.Progress.View = 'Classic'

$Items = Get-FilesCollection -Paths $args -Include $Include
$i = 1
$n = $Items.Count
$Items | ForEach-Object {
    ProcessFile $_
    Write-Progress -Activity "Processing" -Status "($i of $n) $_" -PercentComplete (($i / $n) * 100) -CurrentOperation $_    
    $i++
}
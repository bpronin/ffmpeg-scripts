Import-Module .\lib\util.psm1

function Invoke-Ffmpeg {
    param (
        [string]$Options
    )
    process {
        # Start-Process -FilePath "c:\opt\ffmpeg\bin\ffmpeg" -ArgumentList "-y $Options" -NoNewWindow -Wait -PassThru
        Invoke-Expression "c:\opt\ffmpeg\bin\ffmpeg -y $Options" | Out-Default # wait for completion  
        # Invoke-Expression "c:\opt\ffmpeg\bin\ffmpeg $Options"      
    }
}

function Invoke-Imagick {
    param (
        [string]$Options
    )
    process {
        # Start-Process -FilePath "c:\opt\imagick\magick" -ArgumentList "$Options" -NoNewWindow -Wait -PassThru
        Invoke-Expression "c:\opt\imagick\magick $Options" | Out-Default # wait for completion    
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
            Move-Item -Path $TempFile -Destination $InputFile -Force        
        }
    }
}

$ErrorActionPreference = "Break"
# $PSStyle.Progress.View = 'Classic'
# $Include = @("*.mp3", "*.m4a", "*.ogg") 
# m4a does not copy all metadata tags
$Include = @("*.mp3")

# --- SCRIPT ENTRY POINT ---

Write-Progress -Activity "Processing" -Status "Collecting ..."
$Items = Get-FilesCollection -Paths $args -Include $Include

$i = 1
$n = $Items.Count
$Items | ForEach-Object {
    ProcessFile $_
    Write-Progress -Activity "Processing" -Status "($i of $n) $_" -PercentComplete (($i / $n) * 100) -CurrentOperation $_    
    $i++
}
$IncludeFiles = @("*.mp3", "*.m4a")
# $ErrorActionPreference = "Break"
# $PSStyle.Progress.View = 'Classic'

Import-Module .\lib\util.psm1

# --- SCRIPT ENTRY POINT ---

Write-Progress -Activity "Collecting files" -Status "..." 
# Write-Host "Collecting files..." 
$Items = Get-FilesCollection -Paths $args -Include $IncludeFiles

$SynchronizedData = [hashtable]::Synchronized(@{
        i = 1
        n = $Items.Count    
    })

$Items | ForEach-Object -ThrottleLimit 8 -Parallel {
    
    Import-Module .\lib\util.psm1
    Import-Module .\lib\ffmpeg.psm1
    Import-Module .\lib\imagick.psm1

    $Source = $_
    $D = $using:SynchronizedData
    # Write-Host "Processing: $Source"

    $CoverFile = Rename-FileExtension -File $Source -NewExtension ".jpg"
    Invoke-Ffmpeg "-i `"$Source`" -c:v copy -an -loglevel quiet -y `"$CoverFile`""      
        
    if (Test-Path $CoverFile) {
        Invoke-Imagick "mogrify -resize 400x400 -quality 80 -format jpg `"$CoverFile`""    
    
        # $MetadataFile = Rename-FileExtension -File $Source -NewExtension ".metadata"
        # Invoke-Ffmpeg "-i `"$Source`" -f ffmetadata `"$MetadataFile`" -loglevel error -y"

        $TempFile = Rename-FileExtension -File $Source -Prefix "~"
        Invoke-Ffmpeg "-i `"$Source`" -i `"$CoverFile`" -c copy -map 0:a -map 1:v -disposition:v attached_pic -loglevel error -y `"$TempFile`""
        # Invoke-Ffmpeg "-i `"$Source`" -i `"$CoverFile`" -f ffmetadata -i `"$MetadataFile`" -c copy -map 0:a -map 1:v -map_metadata 2 -id3v2_version 3 -disposition:v attached_pic -loglevel error -y `"$TempFile`""
        # Invoke-Ffmpeg "-i `"$Source`" -f ffmetadata -i `"$MetadataFile`" -c copy -map 0:a -map_metadata 1 -loglevel error -y `"$TempFile`""
    
        Invoke-FailSafe { Remove-Item -Path $CoverFile  -ErrorAction Stop }
        Invoke-FailSafe { Move-Item -Path $TempFile -Destination $Source -Force -ErrorAction Stop } -Timeout 250       
    }

    Write-Progress -Activity "Processing" -Status "$($D.i) of $($D.n)) $_" -PercentComplete (($($D.i) / $($D.n)) * 100) -CurrentOperation $Source    

    $D.i++
}

Write-Progress -Completed 
Write-Host "Done." -ForegroundColor DarkGreen
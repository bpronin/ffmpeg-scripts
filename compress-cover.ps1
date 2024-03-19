# $ErrorActionPreference = "Break"
$IncludeFiles = @("*.mp3")
$FfmpegExe = "C:\Opt\ffmpeg\bin\ffmpeg.exe"
$ImagicExe = "C:\Opt\imagick\magick.exe"
# $PSStyle.Progress.View = 'Classic'
# $IncludeFiles = @("*.mp3", "*.m4a", "*.ogg") # m4a does not copy all metadata tags

Import-Module .\lib\util.psm1

# --- SCRIPT ENTRY POINT ---

# Write-Progress -Activity "Collecting files" -Status "..." 
Write-Host "Collecting files..." 
$Items = Get-FilesCollection -Paths $args -Include $IncludeFiles

$SynchronizedData = [hashtable]::Synchronized(@{
    i = 1
    n = $Items.Count    
})

$Items | ForEach-Object -ThrottleLimit 8 -Parallel {
    
    Import-Module .\lib\util.psm1

    $Source = $_
    $D = $using:SynchronizedData
    # Write-Host "Processing: $Source"

    $CoverFile = Rename-FileExtension -File $Source -NewExtension "jpg"
    Invoke-Expression "$using:FfmpegExe -i `"$Source`" -c:v copy -an -loglevel quiet -y `"$CoverFile`""      
        
    if (Test-Path $CoverFile) {
        Invoke-Expression "$using:ImagicExe mogrify -resize 400x400 -quality 80 -format jpg `"$CoverFile`""    
    
        $TempFile = Rename-FileExtension -File $Source -Prefix "~"
        Invoke-Expression "$using:FfmpegExe -i `"$Source`" -i `"$CoverFile`" -c copy -map 0:a -map 1:v -id3v2_version 3 -loglevel error -y `"$TempFile`""
        # Invoke-Ffmpeg "-i `"$Source`" -i `"$CoverFile`" -c copy -map 0:a -map 1:v -id3v2_version 3 -disposition:v attached_pic `"$TempFile`"" #for m4a
    
        Invoke-FailSafe { Remove-Item -Path $CoverFile  -ErrorAction Stop }
        Invoke-FailSafe { Move-Item -Path $TempFile -Destination $Source -Force -ErrorAction Stop } -Timeout 250       
    }

    Write-Progress -Activity "Processing" -Status "$($D.i) of $($D.n)) $_" -PercentComplete (($($D.i) / $($D.n)) * 100) -CurrentOperation $Source    

    $D.i++
}

Write-Progress -Completed 
Write-Host "Done." -ForegroundColor DarkGreen
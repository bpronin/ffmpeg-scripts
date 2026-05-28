$IncludeFiles = @("*.mp3", "*.m4a")

Import-Module .\lib\util.psm1
Import-Module .\lib\ffmpeg.psm1

# --- SCRIPT ENTRY POINT ---
 
Write-Host "Scanning..."

$Items = Get-FilesCollection -Paths $args -Include $IncludeFiles

Write-Host "Found $($Items.Count) files"

$n = $Items.Count
$i = $n

$Items | ForEach-Object {
    $Source = $_
    
    Write-Host "Processing ($i of $n): $Source"

    $CoverFile = Join-Path $Source.Directory "cover.jpg"

    if (-not (Test-Path $CoverFile)) {
        # extract cover
        Invoke-Ffmpeg "-i `"$Source`" -c:v copy -an `"$CoverFile`"" -Quiet      
    }

    # remove cover
    $tempFile = Rename-FileExtension -File $Source -Prefix "~"
    Invoke-Ffmpeg "-i `"$Source`" -c:a copy -vn `"$tempFile`"" -Quiet     
    Move-Item -LiteralPath "$tempFile" -Destination "$Source" -Force 
    
    $i--
}

Write-Host "Done." -ForegroundColor DarkGreen
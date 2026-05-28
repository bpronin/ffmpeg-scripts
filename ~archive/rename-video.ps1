# param(
#     [Parameter(Position = 0, mandatory = $true)]
#     [System.IO.FileInfo] $SourcePath
# )

$SourcePath  = "t:\Temp\Photo\CANON-NEW\"

$ErrorActionPreference = "Break"
Import-Module .\lib\util.psm1
Import-Module .\lib\ffmpeg.psm1

function GetCreationTime {
    param (
        $InputFile
    )
    # $time_tag = "DateTimeOriginal"
    $time_tag = "creation_time"

    $s = Invoke-Ffprobe "-v error -select_streams v:0 -show_entries stream_tags=$time_tag -of default=noprint_wrappers=1:nokey=1 $InputFile"
    if ($s) {
        return $s.Replace(':', '').Replace(' ', '_')
    } 
    return $null
}

Get-ChildItem -Path $SourcePath -File | ForEach-Object {
    $time = GetCreationTime -InputFile $_
    if ($time) {
        $new_name = Get-NormalizedFilename -FileName "$time$($_.Extension)"  
        "$($_.Name) -> $new_name"
        Rename-Item $_ -NewName $new_name
    }
}


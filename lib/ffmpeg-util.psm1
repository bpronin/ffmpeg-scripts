$FfmpegHome = "c:\opt\media\ffmpeg\bin"
$ffmpeg = Join-Path $FfmpegHome "ffmpeg.exe"
$ffprobe = Join-Path $FfmpegHome "ffprobe.exe"
# $ff_loglevel = "error"
# $ff_loglevel = "info"
$ff_loglevel = "warning"

function ReadFileMetadata {
    param (
        [System.IO.FileInfo] $InputFile
    )

    return & $ffprobe -v quiet -show_streams -show_entries stream_tags:format_tags -of json $InputFile | ConvertFrom-Json    
}

function ExtractPicture {
    param (
        [System.IO.FileInfo] $InputFile,
        [System.IO.FileInfo] $OutputFile
    )
    # & $ffmpeg -i $CoverSource -c:v copy -an $coverFile -y -loglevel $ff_loglevel 
    & $ffmpeg -i $InputFile -map 0:v -update 1 -c copy $OutputFile -y -loglevel $ff_loglevel
}

function AttachPicture {
    param (
        [System.IO.FileInfo] $InputFile,
        [System.IO.FileInfo] $PictureFile
    )

    $outputFile = $InputFile
    $tempFile = Join-Path $InputFile.Directory "~temp$($InputFile.Extension)"
    Rename-Item -Path $InputFile -NewName $tempFile

    & $ffmpeg -i $tempFile -i $PictureFile -map 0:a -map 1:v -c copy -disposition:v:0 attached_pic $outputFile -y -loglevel $ff_loglevel

    Remove-Item $tempFile
}

function ConvertToAacVbr {
    param (
        [System.IO.FileInfo] $InputFile,
        [System.IO.FileInfo] $OutputFile
    )
    
    & $ffmpeg -i $InputFile -map 0:a -map ?0:v -c:a aac -q:a 2 -c:v copy -disposition:v:0 attached_pic $OutputFile `
        -y -loglevel $ff_loglevel
}

function ConcatFiles {
    param (
        [System.IO.FileInfo] $ListFile,
        [System.IO.FileInfo] $MetadataFile,
        [System.IO.FileInfo] $OutputFile
    )
    
    & $ffmpeg -f concat -safe 0 -i $ListFile -i $MetadataFile -map_metadata 1 -map 0:a -c copy $OutputFile -y -loglevel $ff_loglevel
}


Export-ModuleMember -Function ReadFileMetadata 
Export-ModuleMember -Function ConvertToAacVbr 
Export-ModuleMember -Function ExtractPicture 
Export-ModuleMember -Function AttachPicture 
Export-ModuleMember -Function ConcatFiles 

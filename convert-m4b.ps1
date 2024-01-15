param(
    [Parameter(Position = 0, mandatory = $true)]
    [System.IO.DirectoryInfo] $InputPath,
    $FfmpegHome = "c:\opt\ffmpeg"
)
function GetMetadata {
    param (
        [System.IO.FileInfo] $InputFile
    )
    $Command = "$FfmpegHome\bin\ffprobe -v quiet -show_streams -show_entries stream_tags:format_tags -of json $InputFile"
    return Invoke-Expression $Command | ConvertFrom-Json    
}

<# Script entry point #>

$Chapters = @()
$ChapterStart = 0
Get-ChildItem -Path "$InputPath\*" -Include "*.mp3" | Foreach-Object {
    $Metadata = GetMetadata -InputFile $_
    $Stream = $Metadata.streams[0]
    $ChapterEnd = $ChapterStart + $Stream.duration_ts    

    $Chapters += @{
        file      = $_
        start     = $ChapterStart
        end       = $ChapterEnd 
        time_base = $Stream.time_base
        tags      = $Metadata.format.tags
    }
    
    $ChapterStart = $ChapterEnd
}

## TODO: Sort by track
## TODO: Add artwork
## TODO: Convert in theads then concat

# $Chapters

$Metadata = @(
    ";FFMETADATA1"
    "album=$($Chapters[0].tags.album)"
    "genre=$($Chapters[0].tags.genre)"
    "artist=$($Chapters[0].tags.artist)"
    "date=$($Chapters[0].tags.date)"
    "artist=$($Chapters[0].tags.artist)"
    "album_artist=$($Chapters[0].tags.album_artist)"
    "composer=$($Chapters[0].tags.composer)"
    "comment=$($Chapters[0].tags.comment)"
)

$FileList = @()

$Chapters | Foreach-Object {
    $Metadata += @(
        "[CHAPTER]"
        "TIMEBASE=$($_.time_base)"
        "START=$($_.start)"
        "END=$($_.end)"
        "title=$($_.tags.title)"    
    )
 
    $FileList += "file '$($_.file.FullName)'"
}

# $Metadata

$MetadataFile = "$InputPath\~ffmetadata.txt"
$ListFile = "$InputPath\~list.txt"
$OutputFile = "$InputPath\~output.m4b"

Out-File -FilePath $MetadataFile -InputObject $Metadata
Out-File -FilePath $ListFile -InputObject $FileList

$Command = "$FfmpegHome\bin\ffmpeg -f concat -safe 0 -i $ListFile -i $MetadataFile -map_metadata 1 -vn -y -b:a 64k -acodec aac -ac 2 $OutputFile"
# $Command = "$FfmpegHome\bin\ffmpeg -i $InputPath\~~output.m4a -i $MetadataFile -map_metadata 1 -c copy $OutputFile"
Invoke-Expression $Command

"Done"
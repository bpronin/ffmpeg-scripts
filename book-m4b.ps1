param(
    [Parameter(Position = 0, mandatory = $true)]
    [System.IO.DirectoryInfo] $InputPath,
    [System.IO.FileInfo] $FfmpegHome = "c:\opt\ffmpeg\bin"
)

$UtilsModule = ".\lib\util.psm1"
Import-Module $UtilsModule

function GetFileMetadata {
    param (
        [System.IO.FileInfo] $InputFile
    )
    
    # "$FfmpegHome\ffprobe -i $InputFile -show_entries format=duration -sexagesimal -v quiet -of csv=`"p=0`"" | Invoke-Expression
    
    return Invoke-Expression "$FfmpegHome\ffprobe -v quiet -show_streams -show_entries stream_tags:format_tags -of json $InputFile" 
    | ConvertFrom-Json    
}

function GetChapterTitle {
    param (
        $Chapter
    )
    if ($Chapter.tags.title) {
        return $Chapter.tags.title 
    }
    else {
        $Index = ($Chapter.tags.track -split "/")[0]
        return "Chapter $Index"
    }    
}
function GetOutputFile {
    param (
        $Chapter
    )

    $Album = if ($Chapter.tags.album) {
        $Chapter.tags.album
    }
    else {
        "image"
    }    

    $Artist = if ($Chapter.tags.album_artist) {
        $Chapter.tags.album_artist 
    }
    else {
        $Chapter.tags.artist
    }       

    return "$Artist - $Album"
}

<############## Script entry point ################>

$OutputPath = "$InputPath\~out"
New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null

#region Convert

Get-ChildItem -Path "$InputPath\*" -Include "*.mp3" | Foreach-Object -Parallel {
    Write-Host "Converting $_ ..."    
    $OutputFile = "$using:OutputPath\$($_.BaseName).m4a"
    # Invoke-Expression "$using:FfmpegHome\ffmpeg -i $_ -vn -c:a aac -q:a 2 -y -loglevel error $OutputFile"   
    Invoke-Expression "$using:FfmpegHome\ffmpeg -i $_ -vn -c:a aac -b:a 64k -y -loglevel error $OutputFile"   
}

#endregion
#region Metadata

Write-Host "Redaing metadata..."

$Chapters = @()
$ChapterStart = 0
Get-ChildItem -Path "$OutputPath\*" -Include "*.m4a" | Foreach-Object {
    $Metadata = GetFileMetadata -InputFile $_
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
    $Title = GetChapterTitle -Chapter $_
    $FileList += "file '$($_.file.FullName)'"
 
    $Metadata += @(
        "[CHAPTER]"
        "TIMEBASE=$($_.time_base)"
        "START=$($_.start)"
        "END=$($_.end)"
        "title=$Title"    
    ) 
}   

$MetadataFile = "$OutputPath\~metadata.txt"
Out-File -FilePath $MetadataFile -InputObject $Metadata

$ListFile = "$OutputPath\~files.txt"
Out-File -FilePath $ListFile -InputObject $FileList

#endregion

Write-Host "Joining chapters..."

$OutputFile = "`"$OutputPath\$(GetOutputFile $Chapters[0]).m4b`""
Invoke-Expression "$FfmpegHome\ffmpeg -hide_banner -f concat -safe 0 -i $ListFile -i $MetadataFile -map_metadata 1 -c copy -y $OutputFile"

Write-Host "Done" -ForegroundColor DarkGreen
param(
    # [Parameter(Position = 0, mandatory = $true)]
    # [System.IO.DirectoryInfo] $InputPath = "C:\Temp\t",
    # [System.IO.FileInfo] $FfmpegHome = "c:\opt\media\ffmpeg\bin"
)

$InputPath = "C:\Temp\t"
$FfmpegHome = "c:\opt\media\ffmpeg\bin"

$ffprobe = "$FfmpegHome\ffprobe"
$ffmpeg = "$FfmpegHome\ffmpeg"

function ReadFileMetadata {
    param (
        [System.IO.FileInfo] $InputFile
    )

    return & $ffprobe -v quiet -show_streams -show_entries stream_tags:format_tags -of json $InputFile | ConvertFrom-Json    
}

function GetChapterTitle {
    param (
        $Tags
    )

    if ($Tags.title) {
        return $Tags.title 
    }
    else {
        $index = ($Tags.track -split "/")[0]
        return "Chapter $index"
    }    
}

function GetOutputFileName {
    param (
        $Tags,
        [System.IO.FileInfo] $InputFile
    )

    $album = if ($Tags.album) { 
        $Tags.album 
    }
    else { 
        $InputFile.BaseName 
    }

    $artist = if ($Tags.album_artist) { 
        $Tags.album_artist 
    }
    else { 
        $Tags.artist 
    }

    return "$artist - $album"
}

function GetCoverFile {
    param (
        $InputFile
    )

    $coverFile = "$InputPath\cover.jpg"
    if (-not (Test-Path -Path $coverFile -PathType Leaf)) {
        $coverFile = "$outputPath\~cover.jpg"
        & $ffmpeg -i $InputFile -c:v copy -an $coverFile -y -hide_banner -loglevel error
    }

    return $coverFile
}

############## Script entry point ################

$outputPath = "$InputPath\~out"
Remove-Item -Path $outputPath -Recurse -Confirm:$false -Force -ErrorAction SilentlyContinue
New-Item -Path $outputPath -ItemType Directory -Force | Out-Null

### Collecting metadata ###

$chapters = @()
$start = 0
Get-ChildItem -Path "$InputPath\*" -Include "*.mp3" | Sort-Object -Property Name | Foreach-Object {
    $metadata = ReadFileMetadata -InputFile $_
    $stream = $metadata.streams[0]
    $end = $start + $stream.duration_ts    

    $chapters += @{
        file      = $_
        start     = $start
        end       = $end 
        time_base = $stream.time_base
        tags      = $metadata.format.tags
    }
    
    $start = $end
}

$tags = $chapters[0].tags
$metadata = @(
    ";FFMETADATA1"
    "album=$($tags.album)"
    "genre=$($tags.genre)"
    "artist=$($tags.artist)"
    "date=$($tags.date)"
    "artist=$($tags.artist)"
    "album_artist=$($tags.album_artist)"
    "composer=$($tags.composer)"
    "comment=$($tags.comment)"
    "disc=$($tags.disc)"
    # "GROUP=$($tags.GROUP)"
    # "URL=$($tags.URL)"
)

$files = @()

$chapters | Foreach-Object {
    $title = GetChapterTitle -Tags $_.tags
    $filename = $_.file.FullName.Replace("'", "'\''")
    $files += "file '$filename'"

    $metadata += @(
        "[CHAPTER]"
        "TIMEBASE=$($_.time_base)"
        "START=$($_.start)"
        "END=$($_.end)"
        "title=$title"    
    ) 
}   

$metadataFile = "$outputPath\~metadata.txt"
Out-File -FilePath $metadataFile -InputObject $metadata -Encoding utf8NoBOM

$listFile = "$outputPath\~files.txt"
Out-File -FilePath $listFile -InputObject $files -Encoding utf8NoBOM

$outputFilename = GetOutputFileName -Tags $tags -InputFile $InputPath.BaseName
$outputFile = "$outputPath\$outputFilename.m4b"
$coverFile = GetCoverFile -InputFile $chapters[0].file

### Joining chapters ###
& $ffmpeg -f concat -safe 0 -i $listFile -i $metadataFile -i $coverFile -map_metadata 1 -map 0:a -map 2:v -c copy `
    -disposition:v:0 attached_pic $outputFile -y -hide_banner -loglevel error

# & $ffprobe -i $outputFile -show_entries format_tags

Write-Host "Done" -ForegroundColor DarkGreen

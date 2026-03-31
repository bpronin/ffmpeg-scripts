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
function PrepareOutputPath {
    param (
        $InputPath
    )

    $outputPath = "$InputPath\~out"
    Remove-Item -Path $outputPath -Recurse -Confirm:$false -Force -ErrorAction SilentlyContinue
    New-Item -Path $outputPath -ItemType Directory -Force | Out-Null
    
    return $outputPath
}

function GetOutputFile {
    param (
        $Tags,
        $InputFile,
        $OutputPath
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

    $filename = "$artist - $album"
    return "$OutputPath\$filename.m4b"
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
function ReadChapters {
    param (
        $InputPath
    )
    $chapters = @()
    $start = 0

    Get-ChildItem -Path "$InputPath\*" -Include "*.m4a" | Sort-Object -Property Name | Foreach-Object {
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

    return $chapters
}
function PrepareSources {
    param (
        $Chapters,
        $OutputPath
    )

    $metadata = @(
        ";FFMETADATA1"
        "album=$($Chapters[0].tags.album)"
        "genre=$($Chapters[0].tags.genre)"
        "artist=$($Chapters[0].tags.artist)"
        "date=$($Chapters[0].tags.date)"
        "artist=$($Chapters[0].tags.artist)"
        "album_artist=$($Chapters[0].tags.album_artist)"
        "composer=$($Chapters[0].tags.composer)"
        "comment=$($Chapters[0].tags.comment)"
        "disc=$($Chapters[0].tags.disc)"
    )

    $files = @()

    foreach ($chapter in $Chapters) {
        $filename = $chapter.file.FullName.Replace("'", "'\''")
        $files += "file '$filename'"
        $metadata += @(
            "[CHAPTER]"
            "TIMEBASE=$($chapter.time_base)"
            "START=$($chapter.start)"
            "END=$($chapter.end)"
            "title=$(GetChapterTitle -Tags $chapter.tags)"    
        ) 
    }   
    
    $source = @{
        metadata = "$OutputPath\~metadata.txt"
        list     = "$OutputPath\~files.txt"
        cover    = GetCoverFile -InputFile $Chapters[0].file
    }
    
    Out-File -FilePath $source.metadata -InputObject $metadata -Encoding utf8NoBOM
    Out-File -FilePath $source.list -InputObject $files -Encoding utf8NoBOM

    return $source
}

############## Script entry point ################

$outputPath = PrepareOutputPath -InputPath $InputPath
$chapters = ReadChapters -InputPath $InputPath
$source = PrepareSources -Chapters $chapters -OutputPath $outputPath
$outputFile = GetOutputFile -Tags $chapters[0].tags -InputFile $InputPath.BaseName -OutputPath $outputPath

& $ffmpeg -f concat -safe 0 -i $source.list -i $source.metadata -i $source.cover -map_metadata 1 -map 0:a -map 2:v -c copy `
    -disposition:v:0 attached_pic $outputFile -y #-hide_banner -loglevel error

# & $ffprobe -i $outputFile -show_entries format_tags

Write-Host "Done" -ForegroundColor DarkGreen

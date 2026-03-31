param(
    # [Parameter(Position = 0, mandatory = $true)]
    # [System.IO.DirectoryInfo] $InputPath = "C:\Temp\t",
    # [System.IO.FileInfo] $FfmpegHome = "c:\opt\media\ffmpeg\bin"
)

[System.IO.DirectoryInfo] $InputPath = "C:\Temp\t"
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

function PrepareTempPath {
    param (
        [System.IO.DirectoryInfo] $InputPath
    )

    $tempPath = "$InputPath\~out"
    Remove-Item -Path $tempPath -Recurse -Confirm:$false -Force -ErrorAction SilentlyContinue
    New-Item -Path $tempPath -ItemType Directory -Force | Out-Null
    
    return $tempPath
}

function GetOutputFile {
    param (
        $Tags,
        [System.IO.FileInfo] $InputFile,
        [System.IO.DirectoryInfo] $OutputPath
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

function AttachCover {
    param (
        [System.IO.FileInfo] $CoverSource,
        [System.IO.FileInfo] $InputFile
    )
    
    ### Extract picture ###
    $coverFile = Join-Path $InputFile.Directory "~cover.jpg"
    & $ffmpeg -i $CoverSource -c:v copy -an $coverFile -y #-loglevel error 

    if (Test-Path -Path $coverFile -PathType Leaf) {
        $outputFile = $InputFile

        $tempFile = Join-Path $InputFile.Directory "~temp$($InputFile.Extension)"
        Rename-Item -Path $InputFile -NewName $tempFile

        ### Attach picture ###
        & $ffmpeg -i $tempFile -i $coverFile -map 0:a -map 1:v -c copy -disposition:v:0 attached_pic $outputFile -y # -loglevel error
    
        Remove-Item $tempFile, $coverFile
    }
}

function ReadChapters {
    param (
        [System.IO.DirectoryInfo] $InputPath
    )

    $chapters = @()
    $start = 0
    $files = Get-ChildItem -Path "$InputPath\*" -Include "*.m4a" | Sort-Object -Property Name
    foreach ($file in $files) {
        $metadata = ReadFileMetadata -InputFile $file
        $stream = $metadata.streams[0]
        $end = $start + $stream.duration_ts    

        $chapters += @{
            file      = $file
            start     = $start
            end       = $end 
            time_base = $stream.time_base
            tags      = $metadata.format.tags
        }
    
        $start = $end
    }

    return $chapters
}

function JoinChapters {
    param (
        $Chapters,
        [System.IO.FileInfo] $OutputFile
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
    
    $metadataFile = Join-Path $OutputFile.Directory "~metadata.txt"
    $listFile = Join-Path $OutputFile.Directory "~files.txt"
       
    Out-File -FilePath $metadataFile -InputObject $metadata -Encoding utf8NoBOM
    Out-File -FilePath $listFile -InputObject $files -Encoding utf8NoBOM
    
    & $ffmpeg -f concat -safe 0 -i $listFile -i $metadataFile -map_metadata 1 -map 0:a -c copy $OutputFile -y # -loglevel error
    
    Remove-Item $metadataFile, $listFile
}

function ConvertInputFiles {
    param (
        [System.IO.DirectoryInfo] $InputPath,
        [System.IO.DirectoryInfo] $OutputPath
    )

    $files = Get-ChildItem -Path "$InputPath\*" -Include "*.m4a"
    foreach ($file in $files) {
        Copy-Item -Path $file -Destination $OutputPath     
    }
    
    $files = Get-ChildItem -Path "$InputPath\*" -Include "*.mp3"
    foreach ($file in $files) {
        $outputFile = Join-Path $OutputPath ($file.BaseName + ".m4a")
        & $ffmpeg -i $file.FullName -c:a aac -q:a 2 $outputFile -y
    }
    
}

############## Script entry point ################

$tempPath = PrepareTempPath -InputPath $InputPath
ConvertInputFiles -InputPath $InputPath -OutputPath $tempPath
$chapters = ReadChapters -InputPath $tempPath
$outputFile = GetOutputFile -Tags $chapters[0].tags -InputFile $InputPath.BaseName -OutputPath $tempPath
JoinChapters -Chapters $chapters -OutputFile $outputFile
AttachCover -CoverSource $chapters[0].file -InputFile $outputFile 

# & $ffprobe -i $outputFile -show_entries format_tags
foreach ($chapter in $chapters) {
    Remove-Item $chapter.file
}
    
Write-Host "Done" -ForegroundColor DarkGreen

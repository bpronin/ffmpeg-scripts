param(
    # [Parameter(Position = 0, mandatory = $true)]
    # [System.IO.DirectoryInfo] $InputPath = "C:\Temp\t",
    # [System.IO.FileInfo] $FfmpegHome = "c:\opt\media\ffmpeg\bin"
)
$InputPath = "C:\Temp\~\temp"
$FfmpegHome = "c:\opt\media\ffmpeg\bin"
$ImagicHome = "C:\Opt\imagick"

$ffprobe = Join-Path $FfmpegHome "ffprobe.exe"
$ffmpeg = Join-Path $FfmpegHome "ffmpeg.exe"
$imagick = Join-Path $ImagicHome "magick.exe"
# $ff_loglevel = "error"
$ff_loglevel = "warning"

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

    $tempPath = "$InputPath\~tmp"
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
    
    $coverFile = Join-Path $InputFile.Directory "~cover.jpg"

    ### Extract picture ###
    # & $ffmpeg -i $CoverSource -c:v copy -an $coverFile -y -loglevel $ff_loglevel 
    & $ffmpeg -i $CoverSource -map 0:v -update 1 -c copy $coverFile -y -loglevel $ff_loglevel 

    if (Test-Path -Path $coverFile -PathType Leaf) {

        ### Convert image ###
        & $imagick mogrify -resize 400x400 -quality 80 -format jpg $coverFile 
        
        $outputFile = $InputFile

        $tempFile = Join-Path $InputFile.Directory "~temp$($InputFile.Extension)"
        Rename-Item -Path $InputFile -NewName $tempFile

        ### Attach picture ###
        & $ffmpeg -i $tempFile -i $coverFile -map 0:a -map 1:v -c copy -disposition:v:0 attached_pic $outputFile -y -loglevel $ff_loglevel
        
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
    
    & $ffmpeg -f concat -safe 0 -i $listFile -i $metadataFile -map_metadata 1 -map 0:a -c copy $OutputFile -y -loglevel $ff_loglevel
    
    Remove-Item $metadataFile, $listFile
}

function ConvertFiles {
    param (
        [System.IO.DirectoryInfo] $InputPath,
        [System.IO.DirectoryInfo] $OutputPath
    )

    $files = Get-ChildItem -Path "$InputPath\*" -Include *.mp3, *.m4a -File
    $files | Foreach-Object -ThrottleLimit 16 -Parallel {
        $inputFile = $_
        switch ($inputFile.Extension) {
            ".m4a" {  
                Copy-Item -Path $inputFile -Destination $using:OutputPath
            }
            ".mp3" {  
                $outputFile = Join-Path $using:OutputPath ($inputFile.BaseName + ".m4a")
                & $using:ffmpeg -i $inputFile -map 0:a -map 0:v -c:a aac -q:a 2 -c:v copy -disposition:v:0 attached_pic $outputFile `
                    -y -loglevel $using:ff_loglevel
            }
            Default {
                Write-Warning "Unsupported extension"
            }
        }
    } 
}

############## Script entry point ################

$tempPath = PrepareTempPath -InputPath $InputPath
ConvertFiles -InputPath $InputPath -OutputPath $tempPath
$chapters = ReadChapters -InputPath $tempPath
$outputFile = GetOutputFile -Tags $chapters[0].tags -InputFile $InputPath.BaseName -OutputPath $tempPath
JoinChapters -Chapters $chapters -OutputFile $outputFile
AttachCover -CoverSource $chapters[0].file -InputFile $outputFile 

# & $ffprobe -i $outputFile -show_entries format_tags
foreach ($chapter in $chapters) {
    Remove-Item $chapter.file
}
    
Write-Host "Done" -ForegroundColor DarkGreen
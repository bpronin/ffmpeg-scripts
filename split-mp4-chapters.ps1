Import-Module .\lib\util.psm1

$ffhome = "..\bin"

function New-TargetDirectory($source)
{
    $targetPath = Join-Path $source.DirectoryName "$( $source.BaseName )-converted"

    if (Test-Path $targetPath)
    {
        Remove-Item $targetPath -Recurse -Force
    }

    New-Item -ItemType Directory -Path $targetPath | Out-Null

    return $targetPath
}

function Get-Metadata($source)
{
    & $ffhome\ffprobe `
        -i $source `
        -show_entries format `
        -show_chapters `
        -of json `
        -sexagesimal `
        -loglevel error | Out-String | ConvertFrom-Json
}

function Get-CoverArt($source, $targetPath)
{
    $cover = Join-Path $targetPath "cover.jpg"

    & $ffhome\ffmpeg `
        -i $source `
        -loglevel error `
        -y `
        -map 0:v:0? `
        -c:v mjpeg `
        -vf "scale=400:-1" `
        -frames:v 1 `
        $cover

    return $cover
}

function Add-CoverArt($source, $cover)
{
    if (-not (Test-Path $cover))
    {
        return
    }

    $temp = "$source.tmp"
    Move-Item $source $temp

    try
    {
        & $ffhome\ffmpeg `
            -loglevel error `
            -y `
            -i $temp `
            -i $cover `
            -map 0:a `
            -map 1:v `
            -c:a copy `
            -c:v mjpeg `
            -disposition:v attached_pic `
            $source

        if ($LASTEXITCODE -ne 0)
        {
            throw "ffmpeg failed"
        }

        Remove-Item $temp
    }
    catch
    {
        if (Test-Path $source)
        {
            Remove-Item $source -Force
        }

        Move-Item $temp $source

        throw
    }
}

function Split-Chapter($source, $chapter, $index, $targetPath, $cover)
{
    $track = $index + 1

    $title = $chapter.tags.title
    if ( [string]::IsNullOrWhiteSpace($title))
    {
        $title = "Chapter $track"
    }
    $title = Remove-InvalidFileNameChars $title
    $titleParts = ($title -split '-').Trim()

    $targetName = "{0:d2} - {1}{2}" -f $track, $title, $source.Extension
    $target = Join-Path $targetPath $targetName

    Write-Host "Processing $targetName" -ForegroundColor DarkGray

    & $ffhome\ffmpeg `
        -loglevel error `
        -y `
        -i $source `
        -ss $chapter.start_time `
        -to $chapter.end_time `
        -c:a copy `
        -vn `
        -map_metadata 0 `
        -map_chapters -1 `
        -metadata track=$track `
        -metadata artist=$($titleParts[1]) `
        -metadata title=$($titleParts[0]) `
        $target

    return $target
}

# --- MAIN ---

$sources = Get-FilesCollection -Paths $args -Include "*.m4a"
if ($sources.Count -eq 0)
{
    Write-Warning "No sources"
    exit
}

foreach ($source in $sources)
{
    Write-Host "$( $source.Name )"

    $metadata = Get-Metadata $source

    if ($metadata.chapters.Count -eq 0)
    {
        Write-Host "No chapters. Skipped" -ForegroundColor DarkGray
        continue
    }

    $targetPath = New-TargetDirectory $source
    $cover = Get-CoverArt -source $source -targetPath $targetPath

    for ($i = 0; $i -lt $metadata.chapters.Count; $i++) {
        $chapterFile = Split-Chapter `
            -source $source `
            -chapter $metadata.chapters[$i] `
            -index $i `
            -targetPath $targetPath

        Add-CoverArt -source $chapterFile -cover $cover
    }

    if (Test-Path $cover)
    {
        Remove-Item $cover -Force
    }
}

Write-ScriptDone
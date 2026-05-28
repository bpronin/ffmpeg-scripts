Import-Module .\lib\util.psm1

$ffhome = "..\bin"

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

function Split-Chapter($source, $chapter, $index, $targetPath)
{
    $track = "{0:d2}" -f ($index + 1)

    $title = $chapter.tags.title
    if ( [string]::IsNullOrWhiteSpace($title))
    {
        $title = "Chapter $track"
    }

    $safeTitle = Remove-InvalidFileNameChars $title

    $fileName = "{0} - {1}{2}" -f $track, $safeTitle, $source.Extension
    $target = Join-Path $targetPath $fileName

    Write-Host "Processing $fileName" -ForegroundColor DarkGray

    $args = @(
        "-i", $source.FullName,
        "-loglevel", "error",
        "-ss", $chapter.start_time,
        "-to", $chapter.end_time,
        "-map_chapters", "-1",
        "-metadata", "track=$track",
        "-metadata", "title=$title",
        "-c", "copy",
        "-y",
        $target
    )

    & "$ffhome\ffmpeg" @args
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

    for ($i = 0; $i -lt $metadata.chapters.Count; $i++) {
        Split-Chapter `
            -source $source `
            -chapter $metadata.chapters[$i] `
            -index $i `
            -targetPath $targetPath
    }
}

Write-ScriptDone
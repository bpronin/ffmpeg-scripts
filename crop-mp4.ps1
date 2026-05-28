param(
    [Parameter(Position = 0, mandatory = $true)]
    [System.IO.FileInfo] $InputFile
)

Import-Module .\lib\util.psm1

$ffmpeg = "..\bin\ffmpeg.exe"

$start = Read-HostDefault -Prompt "Start" -DefaultValue "00:00:00"
$length = Read-HostDefault -Prompt "Length" -DefaultValue "01:00:00"
$target = Join-Path $InputFile.Directory "_$($InputFile.Name)"

& $ffmpeg -i $InputFile -ss $start -t $length -c copy $target

Write-ScriptDone
param(
    [Parameter(Position = 0, mandatory = $true)]
    [System.IO.FileInfo] $InputFile
)

Import-Module -Name $PSScriptRoot\lib\util

$FFmpeg = "C:\Opt\ffmpeg\bin\ffmpeg.exe"
$Start = Read-HostDefault -Prompt "Start" -DefaultValue "00:00:00"
$Length = Read-HostDefault -Prompt "Length" -DefaultValue "01:00:00"

$OutputFileName = Get-NormalizedFileName $InputFile.BaseName
$OutputFile = Join-Path $InputFile.Directory "_$($OutputFileName).m4a"

$Command = "$FFmpeg -i `"$InputFile`" -ss $Start -t $Length -vn -c:a copy `"$OutputFile`""

# Write-Host $Command
Invoke-Expression $Command
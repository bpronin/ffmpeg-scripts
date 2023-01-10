param (
    [Parameter(Mandatory = $true)]
    [string]$i
)

[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("windows-1251")

function Read-Time
{
    param (
        [string]$string
    )
    $time_string = $string.Trim()
    if ($time_string.split("\:").count -eq 2)
    {
        $time_string = "00:" + $time_string
    }
    return [timespan]$time_string
}

function Read-Line
{
    param (
        [string] $line
    )
    $data = $line.split(";")
    $title = $data[0].Trim()
    $time = Read-Time $data[1]
    return $title, $time
}

$source = Get-Item -Path $i
"Source: " + $source

$destination = $source.DirectoryName + "\tracks.txt"
"Destination: " + $destination

Out-File -FilePath $destination -Force

$lines = @(Get-Content -Path $source -Encoding UTF8)
[timespan]$start = 0
$lines | ForEach-Object{
    $title, $duration = Read-Line $_
    $end = $start + $duration
    "$title;$end" | Out-File -FilePath $destination -Append
    $start = $end
}
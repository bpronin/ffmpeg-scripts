Import-Module -Name $PSScriptRoot\util

function ProcessFile {
    param(
        [System.IO.FileInfo] $Source,
        [String]$Executable = "c:\Opt\ffmpeg\bin\ffprobe.exe"
    )
    process {
        # Write-Output "Path: $source"
        $command = "$Executable -i `"$Source`" -show_entries format=duration -sexagesimal -v quiet -of csv=`"p=0`""
        # Write-Host $command
        Invoke-Expression $command | Out-String -OutVariable duration
        Write-Host "Duration: $duration"
    }    
}

# --- SCRIPT ENTRY POINT

Set-ConsoleEncoding "windows-1251"

$Args | ForEach-Object {
    $path = Get-Item -Path $_

    if ($path.PSIsContainer)
    {
        Get-ChildItem –Path $path -Recurse -Include $include | Foreach-Object {
            ProcessFile -source $_
        }
    }
    else
    {
        ProcessFile -source $path
    }
}

Write-Output "Done"


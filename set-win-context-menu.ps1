[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("windows-1251")

Import-Module -Name $PSScriptRoot\desktop

$menu = "extract m4a audio"
$item = "Extract M4A audio"
$command = "pwsh.exe -file `"$PSScriptRoot\split.ps1`""
$icon = "$PSScriptRoot\music.ico"

[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("windows-1251")

SetContextMenu -app "Folder" -menu $menu -item $item -icon $icon -command $command
foreach ($ext in @("mp4", "mkv"))
{
    SetContextMenuExt -ext $ext -menu $menu -item $item -icon $icon -command $command
}

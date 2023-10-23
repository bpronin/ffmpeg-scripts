Import-Module -Name $PSScriptRoot\util
Import-Module -Name $PSScriptRoot\desktop

Set-ConsoleEncoding "windows-1251"

$menu = "extract m4a audio"
$item = "Extract M4A audio"
$command = "pwsh.exe -file `"$PSScriptRoot\split.ps1`""
$icon = "$PSScriptRoot\music.ico"

Set-ContextMenu -app "Folder" -menu $menu -item $item -icon $icon -command $command

foreach ($ext in @("mp4", "mkv"))
{
    Set-ContextMenuExt -ext $ext -menu $menu -item $item -icon $icon -command $command
}

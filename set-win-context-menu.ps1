[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("windows-1251")

Import-Module -Name "$PSScriptRoot\lib.ps1"

$menu = "extract m4a audio"
$item = "Extract M4A audio"
#$command = "$PSScriptRoot\extract-m4a.bat"
$command = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -file `"$PSScriptRoot\split.ps1 -i %1`""
$icon = "$PSScriptRoot\music.ico"

[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("windows-1251")

Set-Context-Menu -app "Folder" -menu $menu -item $item -icon $icon -command $command
foreach ($ext in @("mp4", "mkv"))
{
    Set-Context-Menu-Ext -ext $ext -menu $menu -item $item -icon $icon -command $command
}

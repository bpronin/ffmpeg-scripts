function Move-ToTrash
{
    param (
        [string]$path
    )
    $shell = New-Object -ComObject 'Shell.Application'
    ForEach ($path in $paths)
    {
        $shell.NameSpace(0).ParseName($path.FullName).InvokeVerb('delete')
    }
}

function Set-ContextMenu
{
    param (
        [parameter(Mandatory = $True)]
        [string]$app,
        [parameter(Mandatory = $True)]
        [string]$menu,
        [parameter(Mandatory = $True)]
        [string]$item,
        [parameter(Mandatory = $False)]
        [string]$icon,
        [parameter(Mandatory = $False)]
        [string]$position,
        [parameter(Mandatory = $True)]
        [string]$command
    )
    begin{
        $shell_key = "Registry::HKEY_CLASSES_ROOT\$app\shell"
    }
    process{
        if (Get-Item -Path "$shell_key\$menu" -ErrorAction Ignore)
        {
            Remove-Item -Path "$shell_key\$menu" -Recurse -Force
        }

        New-Item -Path "$shell_key" -Name "$menu"
        New-ItemProperty -Path "$shell_key\$menu" -Name "(default)" -PropertyType String -Value "$item"

        if ($icon)
        {
            New-ItemProperty -Path "$shell_key\$menu" -Name "Icon" -PropertyType String -Value "$icon"
        }

        if ($position)
        {
            New-ItemProperty -Path "$shell_key\$menu" -Name "Position" -PropertyType String -Value "$position"
        }

        New-Item -Path "$shell_key\$menu" -Name "command"
        New-ItemProperty -Path "$shell_key\$menu\command" -Name "(default)" -PropertyType String -Value "$command `"%1`""
    }
}

function Set-ContextMenuExt
{
    param (
        [parameter(Mandatory = $True)]
        [string]$ext,
        [parameter(Mandatory = $True)]
        [string]$menu,
        [parameter(Mandatory = $True)]
        [string]$item,
        [parameter(Mandatory = $False)]
        [string]$icon,
        [parameter(Mandatory = $False)]
        [string]$position,
        [parameter(Mandatory = $True)]
        [string]$command
    )
    process{
        $app = Get-ItemPropertyValue -Path "Registry::HKEY_CLASSES_ROOT\.$ext" -Name "(default)"
        Set-ContextMenu -app $app -menu $menu -item $item -icon $icon -position $position -command $command
    }
}

Export-ModuleMember -Function Set-ContextMenu
Export-ModuleMember -Function Set-ContextMenuExt
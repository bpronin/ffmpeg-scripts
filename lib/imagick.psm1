$ImagicHome = "C:\Opt\imagick"

function Invoke-Imagick
{
    param (
        $Arguments
    )
    process{
        Invoke-Expression "$ImagicHome\magick $Arguments"
    }
}

Export-ModuleMember -Function Invoke-Imagick

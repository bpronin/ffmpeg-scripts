Import-Module .\lib\ffmpeg.psm1
Import-Module .\lib\util.psm1

function Copy-Metadata {
    param (
        $Source,
        $Target
    )
    process {
        $Metadata = Invoke-Ffprobe "-i `"$Source`" -show_entries format -of json -loglevel error" | Out-String | ConvertFrom-Json
        $MetadataArgument = ""
        $tags = $Metadata.format.tags
        $tags.PSObject.Properties | ForEach-Object {
            # $V = $($_.Value) -replace "/", ";"
            $V = $($_.Value)
            $MetadataArgument += " -metadata $($_.Name)=`"$V`""
        }

        $A = "-i `"$Source`""
        $A += " -map_metadata -1" 
        $A += " -id3v2_version 3" 
        # $A += " -movflags use_metadata_tags" 
        $A += " $MetadataArgument" 
        $A += " -vn -c:a copy -loglevel error -y `"$Target`""
        Invoke-Ffmpeg $A
    }
}

# $Source = "d:\Temp\Music\~Pending\test\13 - Amore, Amore.m4a"
$Source = "d:\Temp\Music\~Pending\test\07 - Corcovado.wma"
$Target = Rename-FileExtension -File $Source -Prefix "~"

Copy-Metadata -Source $Source -Target $Target

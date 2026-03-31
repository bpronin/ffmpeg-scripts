# Путь к папке с файлами и имя выходного файла
$inputDir = "C:\Temp\t"
$outputFile = "Result_with_Chapters.m4a"
$FfmpegHome = "c:\opt\ffmpeg\bin"

# Переходим в рабочую директорию
Push-Location $inputDir

$files = Get-ChildItem -Filter *.m4a | Sort-Object Name
$metadataFile = "metadata.txt"
$listFile = "inputs.txt"

# Инициализация файла метаданных
$metadataContent = ";FFMETADATA1`n"
$inputsContent = ""

$currentTimeMs = 0

foreach ($file in $files) {
    # Получаем длительность в секундах и название из тегов через ffprobe
    $data = "$FfmpegHome\"ffprobe -v error -show_entries format_tags=title -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $file.FullName
    
    $durationSeconds = [double]$data[0]
    $title = if ($data[1]) { $data[1] } else { $file.BaseName } # Если тега title нет, берем имя файла
    
    $durationMs = [int][Math]::Round($durationSeconds * 1000)
    $endMs = $currentTimeMs + $durationMs

    # Формируем блок главы
    $metadataContent += "[CHAPTER]`n"
    $metadataContent += "TIMEBASE=1/1000`n"
    $metadataContent += "START=$currentTimeMs`n"
    $metadataContent += "END=$endMs`n"
    $metadataContent += "title=$title`n"

    # Добавляем в список для склейки
    $inputsContent += "file '$($file.Name)'`n"
    
    $currentTimeMs = $endMs
}

# Сохраняем временные файлы в UTF-8 без BOM (важно для ffmpeg)
$metadataContent | Out-File -FilePath $metadataFile -Encoding ascii
$inputsContent | Out-File -FilePath $listFile -Encoding ascii

# 1. Склеиваем аудиопотоки
ffmpeg -f concat -safe 0 -i $listFile -c copy "temp_combined.m4a" -y

# 2. Накладываем метаданные с главами
ffmpeg -i "temp_combined.md4a" -i $metadataFile -map_metadata 1 -c copy $outputFile -y

# Очистка временных файлов
Remove-Item $metadataFile, $listFile, "temp_combined.m4a"
Pop-Location

Write-Host "Готово! Файл сохранен как: $outputFile" -ForegroundColor Green
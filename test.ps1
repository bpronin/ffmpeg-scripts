# $Format = "{artist} - {title}    - {time}"
$Format = "{artist} - '{title}' - {time}"
$Format = $Format`
    -replace "{artist}","(?<artist>.+)"`
    -replace "{title}","(?<title>.+)"`
    -replace "{time}","(?<time>[\d:]+)"`
    -replace "{index}","(?<index>\d+)"`
    -replace "(\s+)","\s+"

$Format
@echo off
%~dp0\..\bin\ffmpeg.exe -i %1 -t 01:00:00 -vn -c:a copy "%~2 [1h]%~3"
exit
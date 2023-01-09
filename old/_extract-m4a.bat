@echo off
%~dp0\..\bin\ffmpeg.exe -i %1 -vn -c:a copy "%~2.m4a"
%~dp0\..\bin\ffmpeg.exe -i %1 -filter:v "select=eq(n\,1000)" -frames:v 1 "%~2.jpg"
exit
@echo off
%~dp0\..\bin\ffmpeg.exe -i %1 -vn -c:a copy "%~1.m4a"
rem pause
@echo off
%~dp0\..\bin\ffmpeg.exe -y -i %1 -acodec mp3 -aq 4 "%~2.mp3"
:: %~dp0\bin\ffmpeg.exe -y -i %1 -acodec mp3 -ab 320k "%~2.mp3"
exit

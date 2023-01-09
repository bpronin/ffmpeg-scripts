@echo off
:: note: tags cannot be copied into ac3
%~dp0\..\bin\ffmpeg.exe -y -i %1 -acodec ac3 -ab 448k -ar 48000 "%~2.ac3"
exit

@echo off

set file_mask=flac ape mp3 m4a wav ogg
set task=%~dp0\_crop-1-hour.bat

call _iterate.bat %*
@echo off

set file_mask=flac ape mp4 m4a wav
set task=%~dp0\_convert-mp3.bat

call _iterate.bat %*

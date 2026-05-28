@echo off

set input_disk=E
set output_path=C:\Temp
set output_ext=flac

set output_file=%output_path%\dvd-rip-output.%output_ext%
set temp_list_file=%output_path%\dvd-rip-input.txt

cd /d %input_disk%:\AUDIO_TS\

(for %%x in (*.aob) do @echo file '%%~fx') > %temp_list_file%
%~dp0\..\bin\ffmpeg.exe -f concat -safe 0 -i %temp_list_file% %output_file%

del %temp_list_file%
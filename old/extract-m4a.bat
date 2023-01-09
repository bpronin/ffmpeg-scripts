@echo off

set file_mask=mp4
set output_ext=m4a
set task=%~dp0\_extract-m4a.bat

call %~dp0\_iterate.bat %*
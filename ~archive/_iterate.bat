@echo off

for %%p in (%*) do (
	if exist %%p\* (
		cd /d %%p
        for /R %%f in (*.*) do (
            set src="%%f"
            call :processFile
		)         
	) else ( 
        set src=%%p
        call :processFile
	)
)
 
goto :eof

:processFile
    echo %src%
    for %%f in (%src%) do (
        for %%x in (%file_mask%) do (
            if .%%x==%%~xf (
                start %task% %%f "%%~dpnf" "%%~xf"
            )
        )
    )
exit /b

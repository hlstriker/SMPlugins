@echo off
@title SourcePawn compile script

SET COMPILER=PATH\TO\spcomp.exe
SET OUTPUT=PATH\TO\OUTPUT\DIR


if [%1] == [] (
	echo Drag and drop a file or folder, or use the command line.
	goto exit
)

if exist %1\* (
	for /r %1 %%i in (*.sp) do (
		"%COMPILER%" "%%i" "-o%OUTPUT%\%%~ni.smx"
	)
) else (
	"%COMPILER%" "%~1" "-o%OUTPUT%\%~n1.smx"
)

:exit
set /p TEMP=Press ENTER to exit...

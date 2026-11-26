@echo off
setlocal EnableExtensions
rem ============================================================
rem  Aquece o cache de shaders (traduz tudo antes de jogar).
rem  Demora: minutos na primeira vez. Rode uma vez depois do Setup.
rem ============================================================
set "RUNTIME=%~dp0"

if not exist "%RUNTIME%victory-warm.exe" (
    echo Faltam os binarios. Rode Setup.cmd primeiro.
    pause
    exit /b 1
)

set "VICTORY_LOG=warn"
"%RUNTIME%victory-warm.exe"
set "CODE=%ERRORLEVEL%"
echo.
echo Cache aquecido. Log: %RUNTIME%logs\latest-warm.txt
pause
exit /b %CODE%

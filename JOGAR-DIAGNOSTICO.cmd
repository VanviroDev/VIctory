@echo off
setlocal EnableExtensions
rem ============================================================
rem  DexNom RayTime - rodada de diagnostico
rem
rem  Roda o perfil 1080p com log detalhado e, no fim, copia o log
rem  para a Area de Trabalho com o nome do arquivo que a issue pede.
rem  E lento: o log detalhado custa alguns segundos por frame.
rem ============================================================
set "RUNTIME=%~dp0"
rem Se o runtime foi instalado pelo Setup.cmd, ele mora em %LOCALAPPDATA%.
if not exist "%RUNTIME%victory-play.exe" (
    if exist "%LOCALAPPDATA%\DexNom Runtime\victory-play.exe" set "RUNTIME=%LOCALAPPDATA%\DexNom Runtime\"
)

if not exist "%RUNTIME%victory-play.exe" (
    echo Rode Setup.cmd primeiro.
    pause
    exit /b 1
)

set "VICTORY_DISPLAY_MODE=1920x1080"
set "VICTORY_FRAME_INTERVAL=16667"
set "VICTORY_FSR_4K=0"
set "VICTORY_AMBIENT_FALLBACK=1"
set "VICTORY_FILL_WORKERS=6"
set "VICTORY_WIDE_WORKERS=12"
set "VICTORY_PIPELINE_WORKERS=8"
set "VICTORY_PARALLEL_PRELUDES=1"
set "VICTORY_WIDE_REFRESH=1"
set "VICTORY_INDIRECT_WINDOW=1"
set "VICTORY_INPLACE=1"
set "VICTORY_INPLACE_MB=2048"
set "VICTORY_TEXTURE_BUDGET_MB=2600"
set "VICTORY_TEXTURE_ROOM_PERCENT=80"
set "VICTORY_LOG=info"

echo.
echo  Rodada de diagnostico. Pode fechar a janela do jogo a qualquer momento.
echo.

"%RUNTIME%victory-play.exe" --no-rt --console series-s --local-gpu-memory --sparse-textures --no-upload-ahead
set "CODE=%ERRORLEVEL%"

set "STAMP=%DATE:~-4%%DATE:~3,2%%DATE:~0,2%-%TIME:~0,2%%TIME:~3,2%"
set "STAMP=%STAMP: =0%"
set "OUT=%USERPROFILE%\Desktop\dexnom-log-%STAMP%.txt"

if exist "%RUNTIME%logs\latest.txt" (
    copy /y "%RUNTIME%logs\latest.txt" "%OUT%" >nul
    echo.
    echo Log copiado para:
    echo   %OUT%
    echo Anexe esse arquivo na issue, junto da saida do VERIFICAR.cmd.
) else (
    echo.
    echo Nao encontrei logs\latest.txt. Rode VERIFICAR.cmd e anexe a saida.
)
echo.
echo Codigo de saida: %CODE%
pause
exit /b %CODE%

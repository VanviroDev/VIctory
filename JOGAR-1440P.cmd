@echo off
setlocal EnableExtensions
rem ============================================================
rem  DexNom RayTime - perfil qualidade 1440p
rem
rem  A cena renderiza em 1080p e a saida e 1440p (escala do
rem  proprio titulo). Pede mais VRAM e mais RAM que o 1080p.
rem  Use so se o JOGAR-1080P.cmd ja estiver estavel.
rem ============================================================
set "RUNTIME=%~dp0"
rem Se o runtime foi instalado pelo Setup.cmd, ele mora em %LOCALAPPDATA%.
if not exist "%RUNTIME%victory-play.exe" (
    if exist "%LOCALAPPDATA%\DexNom Runtime\victory-play.exe" set "RUNTIME=%LOCALAPPDATA%\DexNom Runtime\"
)

if not exist "%RUNTIME%victory-play.exe" (
    echo.
    echo Faltam os binarios do runtime.
    echo Rode Setup.cmd primeiro, ou VERIFICAR.cmd para ver o que falta.
    echo.
    pause
    exit /b 1
)

set "VICTORY_DISPLAY_MODE=2560x1440"
set "VICTORY_FRAME_INTERVAL=16667"
set "VICTORY_FSR_4K=0"
set "VICTORY_AMBIENT_FALLBACK=1"

set "VICTORY_FILL_WORKERS=6"
set "VICTORY_WIDE_WORKERS=12"
set "VICTORY_PIPELINE_WORKERS=8"
set "VICTORY_PARALLEL_PRELUDES=1"
set "VICTORY_WIDE_REFRESH=1"

set "VICTORY_INDIRECT_WINDOW=1"

rem 32 GB de RAM: 3072 e 3600. 16 GB: volte para o perfil 1080p.
set "VICTORY_INPLACE=1"
set "VICTORY_INPLACE_MB=3072"
set "VICTORY_TEXTURE_BUDGET_MB=3600"
set "VICTORY_TEXTURE_ROOM_PERCENT=85"

set "VICTORY_LOG=warn"

echo.
echo  Perfil 1440p - Series X, cena em 1080p
echo  Log desta execucao: %RUNTIME%logs\latest.txt
echo.

"%RUNTIME%victory-play.exe" --no-rt --console series-x --1080p-to-1440p --local-gpu-memory --sparse-textures --no-upload-ahead
set "CODE=%ERRORLEVEL%"
if not "%CODE%"=="0" (
    echo.
    echo Runtime terminou com codigo %CODE%.
    echo Log: %RUNTIME%logs\latest.txt
    echo.
    pause
)
exit /b %CODE%

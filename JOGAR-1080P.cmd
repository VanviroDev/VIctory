@echo off
setlocal EnableExtensions
rem ============================================================
rem  DexNom RayTime - perfil 1080p / 8 GB VRAM
rem  RTX 3060 Ti 8 GB + Ryzen 5 5600G + 16 GB RAM
rem  Sem ray tracing, Series S, texturas esparsas, sem upload adiantado.
rem ============================================================
set "RUNTIME=%~dp0"
set "GAME=%RUNTIME%game-path.txt"

if not exist "%RUNTIME%victory-play.exe" (
    echo Faltam os binarios. Rode Setup.cmd primeiro.
    pause
    exit /b 1
)

set "VICTORY_AMBIENT_FALLBACK=1"
set "VICTORY_FSR_4K=0"
set "VICTORY_LOG=warn"
set "VICTORY_FILL_WORKERS=4"
set "VICTORY_PARALLEL_PRELUDES=1"

"%RUNTIME%victory-play.exe" --no-rt --console series-s --local-gpu-memory --sparse-textures --no-upload-ahead
set "CODE=%ERRORLEVEL%"
if not "%CODE%"=="0" (
    echo.
    echo Runtime terminou com codigo %CODE%.
    echo Log: %RUNTIME%logs\latest.txt
    pause
)
exit /b %CODE%

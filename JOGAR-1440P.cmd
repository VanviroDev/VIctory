@echo off
setlocal EnableExtensions
rem ============================================================
rem  DexNom RayTime - perfil qualidade 1440p
rem  Cena renderiza em 1080p, saida 1440p (escala temporal do jogo).
rem  Mais bonito, mais VRAM. Use se o perfil 1080p rodar bem.
rem ============================================================
set "RUNTIME=%~dp0"

if not exist "%RUNTIME%victory-play.exe" (
    echo Faltam os binarios. Rode Setup.cmd primeiro.
    pause
    exit /b 1
)

set "VICTORY_AMBIENT_FALLBACK=1"
set "VICTORY_FSR_4K=0"
set "VICTORY_LOG=warn"
set "VICTORY_FILL_WORKERS=6"
set "VICTORY_WIDE_WORKERS=6"
set "VICTORY_PARALLEL_PRELUDES=1"
set "VICTORY_DISPLAY_MODE=2560x1440"

"%RUNTIME%victory-play.exe" --no-rt --console series-x --1080p-to-1440p --local-gpu-memory --sparse-textures --no-upload-ahead
set "CODE=%ERRORLEVEL%"
if not "%CODE%"=="0" (
    echo.
    echo Runtime terminou com codigo %CODE%.
    echo Log: %RUNTIME%logs\latest.txt
    pause
)
exit /b %CODE%

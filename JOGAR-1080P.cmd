@echo off
setlocal EnableExtensions
rem ============================================================
rem  DexNom RayTime - perfil 1080p / 16 GB de RAM / 8 GB de VRAM
rem
rem  Este e o perfil recomendado. Ele usa o conjunto medido na
rem  maquina de referencia (Ryzen 5 5600G, 16 GB, RTX 3060 Ti):
rem  GPU de 0,7%% para 18-40%% durante o carregamento e o dobro
rem  de tempo antes do crash conhecido de RAM.
rem
rem  Se algo falhar, rode VERIFICAR.cmd antes de abrir issue.
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
if not exist "%RUNTIME%game-path.txt" (
    echo.
    echo Falta o game-path.txt com o caminho do jogo.
    echo Rode Setup.cmd e aponte para o game_scarlett_master.exe.
    echo.
    pause
    exit /b 1
)

rem --- video ---
set "VICTORY_DISPLAY_MODE=1920x1080"
set "VICTORY_FRAME_INTERVAL=16667"
set "VICTORY_FSR_4K=0"
set "VICTORY_AMBIENT_FALLBACK=1"

rem --- CPU: 6 nucleos / 12 threads ---
set "VICTORY_FILL_WORKERS=6"
set "VICTORY_WIDE_WORKERS=12"
set "VICTORY_PIPELINE_WORKERS=8"
set "VICTORY_PARALLEL_PRELUDES=1"
set "VICTORY_WIDE_REFRESH=1"

rem --- GPU: agrupa draws indiretos. O maior ganho medido. ---
set "VICTORY_INDIRECT_WINDOW=1"

rem --- RAM: usa as paginas do titulo no lugar de copiar ---
set "VICTORY_INPLACE=1"
set "VICTORY_INPLACE_MB=2048"
set "VICTORY_TEXTURE_BUDGET_MB=2600"
set "VICTORY_TEXTURE_ROOM_PERCENT=80"

rem --- log ---
set "VICTORY_LOG=warn"

echo.
echo  Perfil 1080p - Series S, sem ray tracing
echo  Log desta execucao: %RUNTIME%logs\latest.txt
echo.

"%RUNTIME%victory-play.exe" --no-rt --console series-s --local-gpu-memory --sparse-textures --no-upload-ahead
set "CODE=%ERRORLEVEL%"
if not "%CODE%"=="0" (
    echo.
    echo Runtime terminou com codigo %CODE%.
    echo Log: %RUNTIME%logs\latest.txt
    echo Se foi 0x887A0005 no carregamento, e o crash de RAM descrito no README.
    echo.
    pause
)
exit /b %CODE%

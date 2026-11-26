@echo off
rem ============================================================
rem  DexNom RayTime - verificacao da maquina e do runtime
rem  Nao instala nada e nao altera nada: so confere e diz o que falta.
rem ============================================================
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0VERIFICAR.ps1" %*
exit /b %ERRORLEVEL%

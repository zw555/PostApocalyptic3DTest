@echo off
setlocal EnableExtensions EnableDelayedExpansion
set "GAME_DIR=%~dp0build"
set "GAME_EXE=%GAME_DIR%\Stage5C2_MeleeCombat.exe"
if exist "%GAME_EXE%" (
    start "Stage 5-C.2 Melee Combat" /D "%GAME_DIR%" "%GAME_EXE%"
    exit /b 0
)
echo Game executable not found:
echo %GAME_EXE%
echo Please export the project first with the Stage 5-C.2 Windows preset.
pause

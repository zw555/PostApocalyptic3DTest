@echo off
setlocal EnableExtensions EnableDelayedExpansion
set "GODOT_BIN=E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64.exe"
set "USER_DATA=%TEMP%\PostApocalyptic3DTest"
if not exist "%USER_DATA%\logs" mkdir "%USER_DATA%\logs"
if exist "%GODOT_BIN%" (
    start "Stage 5-C.2 Melee Combat" "%GODOT_BIN%" --path "%~dp0." --user-data-dir "!USER_DATA!" --log-file "!USER_DATA!\logs\godot.log" res://scenes/combat/stage5c2_melee_validation.tscn
    exit /b
)
where godot >nul 2>nul
if not errorlevel 1 (
    start "Stage 5-C.2 Melee Combat" godot --path "%~dp0." --user-data-dir "!USER_DATA!" --log-file "!USER_DATA!\logs\godot.log" res://scenes/combat/stage5c2_melee_validation.tscn
    exit /b
)
echo Godot 4.5.2 not found.
pause

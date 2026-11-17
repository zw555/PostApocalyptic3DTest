@echo off
setlocal
set "GODOT_BIN=E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64.exe"
if not exist "%GODOT_BIN%" (
    echo Godot 4.5.2 not found. Update GODOT_BIN to your installed engine.
    pause
    exit /b 1
)
start "Stage 6-A.3-A.4 - Region Presentation" "%GODOT_BIN%" --path "%~dp0." res://scenes/apartment/stage6a3a4_presentation.tscn

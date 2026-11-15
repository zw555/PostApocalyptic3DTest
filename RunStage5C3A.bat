@echo off
setlocal
set "GODOT_BIN=E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64.exe"
if not exist "%GODOT_BIN%" (
    echo Godot 4.5.2 not found. Edit GODOT_BIN to point to your installed engine.
    pause
    exit /b 1
)
start "Stage 5-C.3-A" "%GODOT_BIN%" --path "%~dp0." res://scenes/combat/stage5c3a_dual_combat_validation.tscn

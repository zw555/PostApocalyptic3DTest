@echo off
setlocal
set "GODOT_BIN=E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64.exe"
if exist "%GODOT_BIN%" (
    start "Wangjia Single Zombie Validation" "%GODOT_BIN%" --path "%~dp0." res://scenes/zombie_chase_validation.tscn
    exit /b
)
where godot >nul 2>nul
if not errorlevel 1 (
    start "Wangjia Single Zombie Validation" godot --path "%~dp0." res://scenes/zombie_chase_validation.tscn
    exit /b
)
echo Godot 4.5.2 not found.
pause

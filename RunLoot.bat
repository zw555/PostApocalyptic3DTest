@echo off
setlocal
set "GODOT_BIN=E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64.exe"
if exist "%GODOT_BIN%" (
    start "After Hours Loot Visual Test" "%GODOT_BIN%" --path "%~dp0." res://scenes/looted_convenience_store.tscn
    exit /b
)
where godot >nul 2>nul
if not errorlevel 1 (
    start "After Hours Loot Visual Test" godot --path "%~dp0." res://scenes/looted_convenience_store.tscn
    exit /b
)
echo Open scenes/looted_convenience_store.tscn in Godot 4.5.2 and press F6.
pause

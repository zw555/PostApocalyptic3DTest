@echo off
setlocal
set "GODOT_BIN=E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64.exe"
if exist "%GODOT_BIN%" (
    start "After Hours CAD Store" "%GODOT_BIN%" --path "%~dp0." res://scenes/cad_convenience_store.tscn
    exit /b
)
where godot >nul 2>nul
if not errorlevel 1 (
    start "After Hours CAD Store" godot --path "%~dp0." res://scenes/cad_convenience_store.tscn
    exit /b
)
echo Godot 4.5.2 not found. Open scenes/cad_convenience_store.tscn in the editor and press F6.
pause

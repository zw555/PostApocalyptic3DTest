@echo off
setlocal
if not defined GODOT_BIN set "GODOT_BIN=E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64.exe"
if not exist "%GODOT_BIN%" (
 echo Godot 4.5.2 not found. Set GODOT_BIN to the Godot executable.
 pause
 exit /b 1
)
start "After Hours - Stage 6-B.4-A Bandage" "%GODOT_BIN%" --path "%~dp0." res://stage6b4a/scenes/gameplay.tscn

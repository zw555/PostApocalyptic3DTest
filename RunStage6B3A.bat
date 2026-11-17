@echo off
setlocal
set "GODOT_BIN=E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64.exe"
if not exist "%GODOT_BIN%" (
 echo Godot 4.5.2 not found. Update GODOT_BIN in this launcher.
 pause
 exit /b 1
)
start "After Hours - Stage6 B3A Equipped Melee" "%GODOT_BIN%" --path "%~dp0." res://stage6b3a/scenes/gameplay.tscn

@echo off
setlocal
set "GODOT_BIN=E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64.exe"
if not exist "%GODOT_BIN%" (
 echo Godot 4.5.2 not found. Update GODOT_BIN in this launcher.
 pause
 exit /b 1
)
start "After Hours - A2.3 Item Integration" "%GODOT_BIN%" --path "%~dp0." res://stage_a23/scenes/gameplay.tscn

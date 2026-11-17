@echo off
setlocal
set "GODOT_BIN=E:\Godot_v4.5.2-stable_win64.exe\Godot_v4.5.2-stable_win64_console.exe"
"%GODOT_BIN%" --path "%~dp0.." --resolution 512x512 --script res://stage_a24a/tools/render_icons.gd
exit /b %errorlevel%

@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0tests\run_stage5c2_tests.ps1" %*
if errorlevel 1 pause

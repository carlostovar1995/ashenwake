@echo off
setlocal EnableExtensions
cd /d "%~dp0"
set "RL=%USERPROFILE%\.runelite"
set "DONE=%RL%\.portable-setup-done"

del "%DONE%" 2>nul
echo Removed: %DONE%
echo Close TovarLite if it is open, then run TovarLite.vbs again.
echo The next start copies plugins and profiles into your .runelite folder again.
echo Login files from this zip are never copied.
pause

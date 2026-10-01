@echo off
setlocal EnableExtensions
set "EXE=%LOCALAPPDATA%\RuneLite\RuneLite.exe"
if not exist "%EXE%" (
  echo RuneLite launcher not found at:
  echo   %EXE%
  echo Install the official RuneLite launcher from https://runelite.net first.
  pause
  exit /b 1
)
start "" "%EXE%" --configure
exit /b 0

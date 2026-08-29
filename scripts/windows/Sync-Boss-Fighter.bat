@echo off
title Sync Boss Fighter
echo Syncing game-sync (Origin + GitHub)...
echo.

rem WSL must exec /bin/bash (not "bash") or you get: execvpe(bash) failed
wsl.exe -d Ubuntu -e /bin/bash -lic "/bin/bash $HOME/game-sync/scripts/windows/sync-from-desktop.sh"
if errorlevel 1 (
  echo Trying default WSL distro with /bin/bash...
  wsl.exe -e /bin/bash -lic "/bin/bash $HOME/game-sync/scripts/windows/sync-from-desktop.sh"
)

echo.
pause

@echo off
title Sync Boss Fighter
echo Syncing game-sync (Origin + GitHub)...
echo.
wsl -e bash -lic "bash $HOME/game-sync/scripts/windows/sync-from-desktop.sh"
echo.
pause

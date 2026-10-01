@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

set "SCRIPTS=%~dp0..\..\..\scripts"
set "RESOLVE=%SCRIPTS%\Resolve-ClientJar.ps1"
set "LOGDIR=%USERPROFILE%\.runelite\logs"
set "LOG=%LOGDIR%\tovarlite-launcher.log"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" 2>nul

rem Copy newest shaded JAR from repo build output when present (dev checkout only)
set "DEVLIBS=%~dp0..\..\..\..\runelite-client\build\libs"
if exist "%RESOLVE%" if exist "%DEVLIBS%\" (
  set "NEWEST="
  for /f "usebackq delims=" %%p in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%RESOLVE%" -Directory "%DEVLIBS%"`) do set "NEWEST=%%p"
  if defined NEWEST if exist "!NEWEST!" (
    del /q "%~dp0client-*-shaded.jar" >nul 2>&1
    copy /y "!NEWEST!" "%~dp0" >nul
    if errorlevel 1 (
      echo Failed to copy client jar from build output:
      echo   !NEWEST!
      pause
      exit /b 1
    )
  )
)

rem Always refresh the official RuneLite.jar launcher so the client auto-updates.
if exist "%~dp0Update-TovarLite.ps1" if not defined TOVARLITE_SKIP_UPDATE (
  echo Checking for official RuneLite launcher updates...
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-TovarLite.ps1" -AppDir "%~dp0."
)

rem Optional git rebuild. Default path is the official launcher, which tracks OSRS.
set "CHECK=%SCRIPTS%\Check-ClientFreshness.ps1"
set "SYNC=%SCRIPTS%\Sync-Upstream.ps1"
if defined TOVARLITE_DEV_REBUILD if exist "%CHECK%" if exist "%SYNC%" if not defined TOVARLITE_SKIP_VERSION_CHECK (
  echo Checking client freshness against RuneLite upstream...
  powershell -NoProfile -ExecutionPolicy Bypass -File "%CHECK%" -AppDir "%~dp0." -CheckUpstreamGit
  set "CHECKERR=!ERRORLEVEL!"
  if "!CHECKERR!"=="1" (
    echo.
    echo Client outdated - syncing upstream and rebuilding...
    echo This can take a few minutes. Output is also logged to:
    echo   %LOG%
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SYNC%" >> "%LOG%" 2>&1
    set "SYNCERR=!ERRORLEVEL!"
    if not "!SYNCERR!"=="0" (
      echo.
      echo ERROR: Sync-Upstream failed ^(exit !SYNCERR!^). Refusing to launch outdated client.
      echo Run Sync-Upstream.bat for a visible rebuild, then try again.
      echo Log: %LOG%
      pause
      exit /b 1
    )
  ) else if "!CHECKERR!"=="2" (
    echo ERROR: Freshness check failed ^(missing jar?^).
    pause
    exit /b 1
  )
)

rem First argument:
rem   simple    - title-screen email/password (Jagex tokens set aside for this launch)
rem   jagexdev  - Jagex Account via local launcher tokens already on THIS PC
rem Login files are never shipped in the zip. Tokens stay on the machine that created them.
set "RL=%USERPROFILE%\.runelite"
if not exist "%RL%" mkdir "%RL%" 2>nul

set "MODE=%~1"
if not defined MODE set "MODE=simple"

if /i "!MODE!"=="simple" (
  if exist "%RL%\credentials.properties" (
    move /y "%RL%\credentials.properties" "%RL%\credentials.properties.portable_sidelined" >nul 2>&1
  )
) else (
  if not exist "%RL%\credentials.properties" if exist "%RL%\credentials.properties.portable_sidelined" (
    move /y "%RL%\credentials.properties.portable_sidelined" "%RL%\credentials.properties" >nul 2>&1
  )
  if exist "%~dp0EnsureLauncherCredentialsFlag.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0EnsureLauncherCredentialsFlag.ps1" 2>nul
  )
)

set "BUNDLE=%~dp0bundled-dot-runelite"
set "DONE=%RL%\.portable-setup-done"

if exist "%BUNDLE%\" (
  if not exist "%DONE%" (
    echo First run: installing plugins and settings to this PC...
    robocopy "%BUNDLE%" "%RL%" /E /R:2 /W:2 /IS /IT /XF session credentials.properties credentials.properties.portable_sidelined /XD jagexcache cache logs >nul
    if /i "!MODE!"=="simple" (
      if exist "%RL%\credentials.properties" del /f /q "%RL%\credentials.properties" >nul 2>&1
    )
    echo done> "%DONE%"
    echo.
  )
)

rem Prefer the Java runtime shipped in this zip so other PCs do not need Adoptium.
set "JAVA="
if exist "%~dp0jre\bin\javaw.exe" set "JAVA=%~dp0jre\bin\javaw.exe"
if not defined JAVA (
  where javaw >nul 2>&1
  if not errorlevel 1 set "JAVA=javaw"
)
if not defined JAVA (
  echo This copy is missing App\jre and no Java is installed on this PC.
  echo Re-download the latest TovarLite zip, or install Java 11+ from https://adoptium.net/
  pause
  exit /b 1
)

set "CREDARG="
if /i not "!MODE!"=="simple" set "CREDARG=--insecure-write-credentials"

rem Official launcher jar auto-updates the client from bootstrap.json on every start.
if exist "%~dp0RuneLite.jar" (
  echo Java: !JAVA!
  echo Starting official RuneLite launcher ^(auto-updates the client^)
  start "TovarLite" "!JAVA!" -jar "%~dp0RuneLite.jar" --noupdate -- --developer-mode !CREDARG!
  exit /b 0
)

set "JARFILE="
if exist "%RESOLVE%" (
  for /f "usebackq delims=" %%p in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%RESOLVE%" -Directory "%~dp0." -NameOnly`) do set "JARFILE=%%p"
)
if not defined JARFILE (
  for %%f in ("%~dp0client-*-shaded.jar") do set "JARFILE=%%~nxf"
)
if not defined JARFILE (
  echo Missing RuneLite.jar and client-*-shaded.jar. Check the update log:
  echo   %LOG%
  pause
  exit /b 1
)
if not exist "%~dp0!JARFILE!" (
  echo Client JAR not found: %~dp0!JARFILE!
  pause
  exit /b 1
)

set "PLUGVER="
if exist "%~dp0pluginhub-version.txt" (
  for /f "usebackq tokens=* delims= " %%v in ("%~dp0pluginhub-version.txt") do set "PLUGVER=%%v"
)
if not defined PLUGVER set "PLUGVER=1.12.36"
set "HUBARG=-Drunelite.pluginhub.version=!PLUGVER!"
echo Plugin Hub version: !PLUGVER!
echo Starting fallback shaded jar: !JARFILE!
echo Java: !JAVA!
start "TovarLite" "!JAVA!" -ea "!HUBARG!" -jar "!JARFILE!" --developer-mode !CREDARG!
exit /b 0

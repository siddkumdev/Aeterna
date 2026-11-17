@echo off
rem One click: export the Quest build, install it on the headset, start recording the headset log.
rem Double-click it. Keep the headset plugged in and awake (on your head or sensor covered).
setlocal
cd /d "%~dp0"
set "GODOT_EXE="
for /f "usebackq tokens=1,* delims==" %%a in ("local.env") do if /i "%%a"=="GODOT_EXE" set "GODOT_EXE=%%~b"
if not defined GODOT_EXE (echo GODOT_EXE missing in local.env & pause & exit /b 1)
set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if not exist "%ADB%" (echo adb not found at %ADB% & pause & exit /b 1)
if not exist _work mkdir _work

echo === 1/3 Exporting (takes a while) ===
"%GODOT_EXE%" --headless --xr-mode off --path godot --export-debug "Quest 3" ../_work/aeterna_quest.apk
if errorlevel 1 (echo EXPORT FAILED & pause & exit /b 1)

echo === 2/3 Installing on the headset ===
"%ADB%" install -r _work\aeterna_quest.apk
if errorlevel 1 (echo INSTALL FAILED: is the headset plugged in, awake, USB prompt accepted? & pause & exit /b 1)

echo === 3/3 Recording the headset log to _work\quest_log.txt ===
"%ADB%" logcat -c
start "Quest log (close when done)" /min cmd /c ""%ADB%" logcat -v time > _work\quest_log.txt"
echo.
echo DONE. Put the headset on and play. Then tell Claude what happened.
pause

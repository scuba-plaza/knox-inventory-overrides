@echo off
rem Regenerates C:\Users\win10\Zomboid\Lua\knox_overrides.txt (2 cells/kg items, 3 per capacity for bags,
rem then stack-rules.txt, then my-overrides.txt). The previous file is saved next to it as a timestamped .bak.
rem Afterwards: exit to the game's main menu and reload your save.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0generate-knox-overrides.ps1"
echo.
if errorlevel 1 (echo Something went wrong - see the messages above.) else (echo Done. Exit to the main menu and reload your save.)
pause

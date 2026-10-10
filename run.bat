@echo off
rem ============================================================
rem  Launch the locally-built Dusklight / TPVR.
rem
rem    run.bat         -> RelWithDebInfo build (recommended)
rem    run.bat debug   -> Debug build
rem
rem  Edit DVD below to point at your own disc image if the path changes.
rem ============================================================
setlocal

set "BUILDDIR=C:\Dev\TPVR-build\windows-msvc-rwdi"
if /I "%~1"=="debug" set "BUILDDIR=C:\Dev\TPVR-build\windows-msvc-debug"

set "DVD=D:\Games\TwilightVR\Legend of Zelda, The - Twilight Princess (USA).ciso"

if not exist "%BUILDDIR%\dusklight.exe" (
    echo [run] Build not found: %BUILDDIR%\dusklight.exe
    echo [run] Run build.bat first.
    exit /b 1
)
if not exist "%DVD%" (
    echo [run] Disc image not found: "%DVD%"
    echo [run] Edit the DVD path in run.bat to point at your .ciso/.iso/.rvz file.
    exit /b 1
)

cd /d "%BUILDDIR%"
start "" "%BUILDDIR%\dusklight.exe" --dvd "%DVD%"
endlocal

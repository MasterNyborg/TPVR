@echo off
rem ============================================================
rem  TPVR local build script
rem
rem  Usage:
rem    build.bat              -> RelWithDebInfo build (recommended)
rem    build.bat debug        -> Debug build
rem    build.bat clean        -> wipe the RelWithDebInfo build tree, then build
rem    build.bat debug clean  -> wipe the Debug build tree, then build
rem    build.bat configure    -> only run the CMake configure step (no compile)
rem
rem  Notes:
rem   - Source lives here (D:\Games\TwilightVRPlus).
rem   - Build tree lives on C: (C:\Dev\TPVR-build\...) to spare D: space.
rem   - Uses the toolchain bundled with VS 2022 Build Tools (cl / cmake / ninja).
rem   - OpenXR SDK is at C:\Dev\TPVR-deps\openxr (see OPENXR_SDK_DIR in CMakeUserPresets.json).
rem ============================================================
setlocal

set "VSDIR=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"
set "VCVARS=%VSDIR%\VC\Auxiliary\Build\vcvars64.bat"
set "CMAKE=%VSDIR%\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
set "XRTOOLS=%VSDIR%\Common7\IDE\CommonExtensions\Microsoft\CMake"

cd /d "%~dp0"

set "PRESET=win-local-rwdi"
set "BUILDDIR=C:\Dev\TPVR-build\windows-msvc-rwdi"
set "DO_CLEAN="

if /I "%~1"=="debug" (
    set "PRESET=win-local-debug"
    set "BUILDDIR=C:\Dev\TPVR-build\windows-msvc-debug"
)
if /I "%~2"=="debug" (
    set "PRESET=win-local-debug"
    set "BUILDDIR=C:\Dev\TPVR-build\windows-msvc-debug"
)
if /I "%~1"=="clean" set "DO_CLEAN=1"
if /I "%~2"=="clean" set "DO_CLEAN=1"
set "CONFIGURE_ONLY="
if /I "%~1"=="configure" set "CONFIGURE_ONLY=1"
if /I "%~2"=="configure" set "CONFIGURE_ONLY=1"

if defined DO_CLEAN (
    echo [build] Removing "%BUILDDIR%" ...
    rmdir /s /q "%BUILDDIR%"
)

tasklist /FI "IMAGENAME eq dusklight.exe" 2>nul | find /I "dusklight.exe" >nul
if not errorlevel 1 (
    echo [build] ERROR: dusklight.exe is running. Close the game first -- it locks the exe and the link step will fail with LNK1104.
    exit /b 1
)

call "%VCVARS%" >nul
if errorlevel 1 (
    echo [build] ERROR: failed to initialize the MSVC environment from vcvars64.bat
    exit /b 1
)

set "PATH=%XRTOOLS%\CMake\bin;%XRTOOLS%\Ninja;%PATH%"

echo [build] Preset : %PRESET%
echo [build] Build  : %BUILDDIR%
echo.

call "%CMAKE%" --preset %PRESET%
if errorlevel 1 exit /b 1

if defined CONFIGURE_ONLY (
    echo.
    echo [build] Configure complete. Run without "configure" to compile.
    endlocal
    exit /b 0
)

call "%CMAKE%" --build --preset %PRESET%
if errorlevel 1 exit /b 1

rem Stage bundled mods next to the exe so it can run straight from the build dir.
if exist "%BUILDDIR%\bundled_mods" (
    if not exist "%BUILDDIR%\mods" mkdir "%BUILDDIR%\mods"
    copy /y "%BUILDDIR%\bundled_mods\*.dusk" "%BUILDDIR%\mods\" >nul 2>nul
)

echo.
echo [build] Done. Executable:
echo          %BUILDDIR%\dusklight.exe
endlocal

@echo off
set STREAMER_ERROR=0
set LAUNCHER_ERROR=0
echo Building ALVR...
echo.

REM Create output directory
if not exist "output" mkdir output

REM Build streamer
echo Building streamer...
cargo xtask build-streamer --release
if %errorlevel% neq 0 (
    echo Error building streamer
    set STREAMER_ERROR=1
) else (
    REM Copy streamer build to output
    echo Copying streamer to output...
    xcopy /E /I /Y "build\alvr_streamer" "output\alvr_streamer"
    if %errorlevel% neq 0 (
        echo Error copying streamer
        set STREAMER_ERROR=1
    )
)

REM Build launcher
echo Building launcher...
cargo xtask build-launcher --release
if %errorlevel% neq 0 (
    echo Error building launcher
    set LAUNCHER_ERROR=1
) else (
    REM Copy launcher to output
    echo Copying launcher to output...
    xcopy /E /I /Y "build\alvr_launcher_windows" "output\alvr_launcher_windows"
    if %errorlevel% neq 0 (
        echo Error copying launcher
        set LAUNCHER_ERROR=1
    )
)

if %STREAMER_ERROR% equ 0 (
    if %LAUNCHER_ERROR% equ 0 (
        echo.
        echo Build complete! Both streamer and launcher are in the 'output' folder.
    ) else (
        echo.
        echo Streamer built successfully, but launcher failed. Check the logs above for details.
    )
) else (
    if %LAUNCHER_ERROR% equ 0 (
        echo.
        echo Launcher built successfully, but streamer failed. Check the logs above for details.
    ) else (
        echo.
        echo Build failed! Check the logs above for details.
    )
)

pause
if %STREAMER_ERROR% equ 0 (
    if %LAUNCHER_ERROR% equ 0 (
        exit /b 0
    ) else (
        exit /b 1
    )
) else (
    if %LAUNCHER_ERROR% equ 0 (
        exit /b 1
    ) else (
        exit /b 1
    )
)

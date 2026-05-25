@echo off
setlocal EnableDelayedExpansion

title ALVR Android APK Builder

REM Ensure window stays open even on crash
goto :main

:error_handler
echo.
echo ============================================================
echo                   SCRIPT ERROR
echo ============================================================
echo.
echo An error occurred. Press any key to close...
pause
exit /b 1

:main

REM ============================================================
REM                    ALVR ANDROID BUILDER
REM ============================================================

set APK_ERROR=0

REM Debug: Script started
echo [DEBUG] Script started successfully
echo.

echo.
echo ============================================================
echo                BUILDING ALVR ANDROID APK
echo ============================================================
echo.

REM ============================================================
REM CONFIGURATION
REM ============================================================

if not defined JAVA_HOME (
    set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
)

if not defined ANDROID_HOME (
    set "ANDROID_HOME=C:\Users\Admin\AppData\Local\Android\Sdk"
)

if not defined ANDROID_NDK_HOME (
    set "ANDROID_NDK_HOME=%ANDROID_HOME%\ndk\30.0.14904198"
)

REM ============================================================
REM EXPORT PATHS
REM ============================================================

set "PATH=%JAVA_HOME%\bin;%ANDROID_HOME%\platform-tools;%PATH%"

REM ============================================================
REM VALIDATE JAVA
REM ============================================================

echo [CHECK] Java...

if exist "%JAVA_HOME%\bin\javac.exe" (
    echo [OK] JAVA_HOME:
    echo      %JAVA_HOME%
) else (
    echo [FAIL] Java compiler not found:
    echo        %JAVA_HOME%\bin\javac.exe
    set APK_ERROR=1
)

echo.

REM ============================================================
REM VALIDATE ANDROID SDK
REM ============================================================

echo [CHECK] Android SDK...

if exist "%ANDROID_HOME%\platform-tools\adb.exe" (
    echo [OK] ANDROID_HOME:
    echo      %ANDROID_HOME%
) else (
    echo [FAIL] Android SDK not found:
    echo        %ANDROID_HOME%
    set APK_ERROR=1
)

echo.

REM ============================================================
REM VALIDATE ANDROID NDK
REM ============================================================

echo [CHECK] Android NDK...

set NDK_OK=0

if exist "%ANDROID_NDK_HOME%\source.properties" (
    set NDK_OK=1
)

if exist "%ANDROID_NDK_HOME%\ndk-build.cmd" (
    set NDK_OK=1
)

if !NDK_OK! equ 1 (
    echo [OK] ANDROID_NDK_HOME:
    echo      %ANDROID_NDK_HOME%
) else (
    echo [FAIL] Android NDK not found:
    echo        %ANDROID_NDK_HOME%
    set APK_ERROR=1
)

echo.

REM ============================================================
REM VALIDATE CARGO
REM ============================================================

echo [CHECK] Rust/Cargo...

where cargo >nul 2>nul

if !errorlevel! equ 0 (
    echo [OK] Cargo detected
) else (
    echo [FAIL] Cargo not found in PATH
    echo Install Rust from:
    echo https://rustup.rs/
    set APK_ERROR=1
)

echo.

REM ============================================================
REM VALIDATE RUSTUP
REM ============================================================

echo [CHECK] Rustup...

where rustup >nul 2>nul

if !errorlevel! equ 0 (
    echo [OK] Rustup detected
) else (
    echo [FAIL] Rustup not found in PATH
    set APK_ERROR=1
)

echo.

REM ============================================================
REM VALIDATE LLVM / CLANG
REM ============================================================

echo [CHECK] LLVM/Clang...

where clang >nul 2>nul

if !errorlevel! equ 0 (
    echo [OK] LLVM/Clang detected
) else (
    echo [WARNING] LLVM/Clang not found in PATH
    echo ALVR may still build if bundled toolchains work
)

echo.

REM ============================================================
REM STOP IF VALIDATION FAILED
REM ============================================================

if !APK_ERROR! neq 0 (
    echo ============================================================
    echo                 ENVIRONMENT CHECK FAILED
    echo ============================================================
    echo.
    pause
    exit /b 1
)

echo ============================================================
echo              ENVIRONMENT CHECK PASSED
echo ============================================================
echo.

REM ============================================================
REM CREATE OUTPUT FOLDER
REM ============================================================

if not exist "output" (
    mkdir output
)

REM ============================================================
REM INSTALL RUST TARGETS
REM ============================================================

echo [1/6] Installing Rust Android targets...
echo.

rustup target add aarch64-linux-android
if !errorlevel! neq 0 goto :rust_target_fail

rustup target add armv7-linux-androideabi
if !errorlevel! neq 0 goto :rust_target_fail

rustup target add x86_64-linux-android
if !errorlevel! neq 0 goto :rust_target_fail

echo.
echo Rust targets installed successfully.
echo.
goto :rust_target_ok

:rust_target_fail
echo.
echo ERROR: Failed installing Rust Android targets.
set APK_ERROR=1
goto :build_end

:rust_target_ok

REM ============================================================
RUN PREPARE-DEPS (MANUAL)
REM ============================================================

echo [2/6] Preparing Android dependencies...
echo.
echo Installing cargo tools manually...
echo.

cargo install cbindgen
if !errorlevel! neq 0 (
    echo WARNING: cbindgen installation failed, may already be installed
)

cargo install cargo-ndk --version 3.5.4
if !errorlevel! neq 0 (
    echo WARNING: cargo-ndk installation failed, may already be installed
)

cargo install --git https://github.com/zarik5/cargo-apk cargo-apk
if !errorlevel! neq 0 (
    echo WARNING: cargo-apk installation failed, may already be installed
)

echo.
echo Downloading OpenXR loaders manually...
echo.

set OPENXR_VERSION=1.1.36
set OPENXR_URL=https://github.com/KhronosGroup/OpenXR-SDK-Source/releases/download/release-%OPENXR_VERSION%/openxr_loader_for_android-%OPENXR_VERSION%.aar
set TEMP_AAR=%TEMP%\openxr_loader.aar
set TEMP_ZIP=%TEMP%\openxr_loader.zip
set EXTRACT_DIR=build\temp_download
set DEST_DIR=deps\android_openxr\arm64-v8a

REM Create directories
if not exist "%EXTRACT_DIR%" mkdir "%EXTRACT_DIR%"
if not exist "%DEST_DIR%" mkdir "%DEST_DIR%"

REM Download using PowerShell
echo Downloading from %OPENXR_URL%...
powershell -Command "Invoke-WebRequest -Uri '%OPENXR_URL%' -OutFile '%TEMP_AAR%'"

if !errorlevel! neq 0 (
    echo ERROR: Failed to download OpenXR loader
    set APK_ERROR=1
    goto :build_end
)

REM Rename .aar to .zip for extraction
echo Renaming to .zip...
ren "%TEMP_AAR%" "openxr_loader.zip"

REM Extract using PowerShell
echo Extracting...
powershell -Command "Expand-Archive -Path '%TEMP_ZIP%' -DestinationPath '%EXTRACT_DIR%' -Force"

if !errorlevel! neq 0 (
    echo ERROR: Failed to extract OpenXR loader
    set APK_ERROR=1
    goto :build_end
)

REM Copy the loader file
echo Copying libopenxr_loader.so...
copy /Y "%EXTRACT_DIR%\prefab\modules\openxr_loader\libs\android.arm64-v8a\libopenxr_loader.so" "%DEST_DIR%\libopenxr_loader.so"

if !errorlevel! neq 0 (
    echo ERROR: Failed to copy OpenXR loader
    set APK_ERROR=1
    goto :build_end
)

REM Cleanup
echo Cleaning up...
del "%TEMP_ZIP%"
rmdir /S /Q "%EXTRACT_DIR%"

echo.
echo Dependencies prepared successfully.
echo.

REM ============================================================
REM CLEAN BUILD (SKIP IF LOCKED)
REM ============================================================

echo [3/6] Cleaning old build artifacts...
echo.

REM Skip cargo clean to avoid crashes - build will work without it
echo SKIPPING cargo clean to prevent crashes...
echo.

REM ============================================================
REM BUILD CLIENT
REM ============================================================

echo [4/6] Building Android client...
echo.
echo This can take several minutes.
echo.

REM Kill any running cargo/rust processes to avoid file lock errors
echo Killing any running cargo processes...
taskkill /F /IM alvr_xtask.exe 2>nul
taskkill /F /IM cargo.exe 2>nul
taskkill /F /IM rustc.exe 2>nul
timeout /t 3 /nobreak >nul

REM Try to delete the locked file manually
if exist "target\debug\alvr_xtask.exe" (
    echo Attempting to delete locked file...
    del /F "target\debug\alvr_xtask.exe" 2>nul
    timeout /t 2 /nobreak >nul
)

REM Build with limited parallel jobs to reduce memory usage
set CARGO_BUILD_JOBS=2
set RUSTFLAGS=-C codegen-units=1

cargo xtask build-client --release

if !errorlevel! neq 0 (
    echo.
    echo ERROR: Android client build failed.
    set APK_ERROR=1
    goto :build_end
)

echo.
echo Android build completed successfully.
echo.

REM ============================================================
REM SEARCH APK
REM ============================================================

echo [5/6] Searching for generated APK...
echo.

set APK_FOUND=0

REM ------------------------------------------------------------
REM LOCATION 1
REM ------------------------------------------------------------

if exist "build\alvr_client_android\alvr_client_android.apk" (
    copy /Y ^
    "build\alvr_client_android\alvr_client_android.apk" ^
    "output\alvr_client_android.apk" >nul

    set APK_FOUND=1
)

REM ------------------------------------------------------------
REM LOCATION 2
REM ------------------------------------------------------------

if exist "target\release\apk\alvr_client_android.apk" (
    copy /Y ^
    "target\release\apk\alvr_client_android.apk" ^
    "output\alvr_client_android.apk" >nul

    set APK_FOUND=1
)

REM ------------------------------------------------------------
REM LOCATION 3
REM ------------------------------------------------------------

if exist "target\release\alvr_client_android.apk" (
    copy /Y ^
    "target\release\alvr_client_android.apk" ^
    "output\alvr_client_android.apk" >nul

    set APK_FOUND=1
)

REM ------------------------------------------------------------
REM LOCATION 4
REM ------------------------------------------------------------

for /r %%F in (*.apk) do (
    if !APK_FOUND! equ 0 (
        copy /Y "%%F" "output\alvr_client_android.apk" >nul
        set APK_FOUND=1
    )
)

echo.

REM ============================================================
REM APK RESULT
REM ============================================================

if !APK_FOUND! equ 1 (
    echo [SUCCESS] APK found and copied:
    echo.
    echo output\alvr_client_android.apk
    echo.
) else (
    echo [ERROR] APK could not be located.
    echo.
    echo Search manually inside:
    echo.
    echo build\
    echo target\
    echo.
    set APK_ERROR=1
)

echo.

REM ============================================================
REM OPTIONAL APK INFO
REM ============================================================

echo [6/6] Build process finished.
echo.

:build_end

if !APK_ERROR! equ 0 (
    echo ============================================================
    echo                    BUILD SUCCESSFUL
    echo ============================================================
    echo.
    echo APK Location:
    echo output\alvr_client_android.apk
    echo.
) else (
    echo ============================================================
    echo                      BUILD FAILED
    echo ============================================================
    echo.
)

pause
exit /b !APK_ERROR!
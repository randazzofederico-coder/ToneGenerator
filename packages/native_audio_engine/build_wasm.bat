@echo off
echo.
echo ==========================================================
echo    Tone Generator - WebAssembly Audio Engine Build
echo ==========================================================
echo.

set "BASE_DIR=%~dp0"
set "SRC_DIR=%BASE_DIR%src"
set "OUT_DIR=%BASE_DIR%..\..\web"

REM Create output directory if it doesn't exist
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

REM Exported functions list (C API wrapper)
set EXPORTED_FUNCTIONS="['_malloc', '_free', '_live_mixer_create', '_live_mixer_destroy', '_live_mixer_add_oscillator', '_live_mixer_remove_oscillator', '_live_mixer_set_oscillator_freq', '_live_mixer_set_oscillator_waveform', '_live_mixer_set_oscillator_volume', '_live_mixer_set_oscillator_pan', '_live_mixer_set_oscillator_mute', '_live_mixer_set_oscillator_solo', '_live_mixer_set_oscillator_phase_invert', '_live_mixer_set_master_volume', '_live_mixer_set_master_mute', '_live_mixer_start', '_live_mixer_stop', '_live_mixer_process']"

REM Exported runtime methods needed for memory manipulation from JS
set EXPORTED_RUNTIME_METHODS="['ccall', 'cwrap', 'setValue', 'getValue', 'HEAPU8', 'HEAP32', 'HEAPF32', 'HEAPF64', 'allocateUTF8']"

echo Compiling C++ files to WebAssembly...
echo.

REM Hardcoded path based on your setup
set EMSDK_PATH=C:\dev\emsdk
set EMSCRIPTEN_PYTHON=%EMSDK_PATH%\python\3.13.3_64bit\python.exe
set EMCC_PY=%EMSDK_PATH%\upstream\emscripten\emcc.py

call "%EMSCRIPTEN_PYTHON%" "%EMCC_PY%" ^
    "%SRC_DIR%\live_mixer.cpp" ^
    -I"%SRC_DIR%" ^
    -O3 ^
    -s WASM=1 ^
    -s EXPORTED_FUNCTIONS=%EXPORTED_FUNCTIONS% ^
    -s EXPORTED_RUNTIME_METHODS=%EXPORTED_RUNTIME_METHODS% ^
    -s ALLOW_MEMORY_GROWTH=1 ^
    -s USE_PTHREADS=0 ^
    -s MODULARIZE=1 ^
    -s EXPORT_NAME="LiveMixerModule" ^
    -DMINIAUDIO_IMPLEMENTATION ^
    -o "%OUT_DIR%\live_mixer.js"

REM Inject globalThis export so it is visible inside the isolated AudioWorkletGlobalScope
echo globalThis.LiveMixerModule = LiveMixerModule; >> "%OUT_DIR%\live_mixer.js"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Emscripten compilation failed.
    exit /b %ERRORLEVEL%
)

echo.
echo [SUCCESS] Build complete!
echo Output files:
echo   - %OUT_DIR%\live_mixer.js
echo   - %OUT_DIR%\live_mixer.wasm
echo.

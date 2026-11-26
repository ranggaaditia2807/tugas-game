@echo off
setlocal
cd /d "%~dp0"

REM PixelEduRacing - Free Pascal + SDL3
REM Source .pas berada di src, hasil unit .ppu/.o disimpan di compile.
if not exist "compile" mkdir "compile"

fpc -Mobjfpc -Sh -O2 -vew -Fu"src" -FU"compile" "src\main.pas"

if errorlevel 1 (
    echo.
    echo GAGAL KOMPILASI.
    pause
    exit /b 1
)

echo.
echo Kompilasi berhasil.
echo Jalankan game dengan: src\main.exe
pause

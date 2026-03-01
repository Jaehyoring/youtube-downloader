@echo off
chcp 65001 > nul
setlocal

echo ===============================
echo   YouTube Downloader 설치
echo ===============================

REM ── winget 확인 ──
winget --version > nul 2>&1
if errorlevel 1 (
    echo ❌ winget이 필요합니다. Windows 10 1709 이상에서 지원됩니다.
    pause
    exit /b 1
)

REM ── Python 3.12 ──
echo [1/4] Python 3.12 확인 중...
python --version 2>nul | findstr "3.12" > nul
if errorlevel 1 (
    echo   Python 3.12 설치 중...
    winget install Python.Python.3.12 --silent --accept-source-agreements --accept-package-agreements
    echo   PATH 적용을 위해 새 터미널에서 setup.bat을 다시 실행하세요.
    pause
    exit /b 0
)
echo   ✓ Python: 설치됨

REM ── Node.js ──
echo [2/4] Node.js 확인 중...
node --version > nul 2>&1
if errorlevel 1 (
    echo   Node.js 설치 중...
    winget install OpenJS.NodeJS.LTS --silent --accept-source-agreements --accept-package-agreements
    echo   PATH 적용을 위해 새 터미널에서 setup.bat을 다시 실행하세요.
    pause
    exit /b 0
)
echo   ✓ Node.js: 설치됨

REM ── ffmpeg ──
echo [3/4] ffmpeg 확인 중...
ffmpeg -version > nul 2>&1
if errorlevel 1 (
    echo   ffmpeg 설치 중...
    winget install Gyan.FFmpeg --silent --accept-source-agreements --accept-package-agreements
    echo   PATH 적용을 위해 새 터미널에서 setup.bat을 다시 실행하세요.
    pause
    exit /b 0
)
echo   ✓ ffmpeg: 설치됨

REM ── Python 의존성 ──
echo [4/4] Python 패키지 및 npm 패키지 설치 중...
python -m pip install --quiet fastapi uvicorn yt-dlp yt-dlp-ejs
echo   ✓ fastapi, uvicorn, yt-dlp, yt-dlp-ejs

set "DIR=%~dp0"
cd /d "%DIR%frontend"
call npm install --silent
echo   ✓ npm 패키지

echo.
echo ===============================
echo   설치 완료!
echo ===============================
echo.
echo 아래 파일을 더블클릭하여 실행하세요:
echo   start.bat
echo.
pause
endlocal

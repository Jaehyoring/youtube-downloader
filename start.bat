@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

set "DIR=%~dp0"

echo ===============================
echo   YouTube Downloader
echo ===============================

REM ── 기존 백엔드 프로세스 종료 ──
echo 기존 프로세스 확인 중...
for /f "tokens=5" %%p in ('netstat -ano 2^>nul ^| findstr ":8000 " ^| findstr "LISTENING"') do (
    taskkill /f /pid %%p > nul 2>&1
)

REM ── 백엔드 실행 ──
echo [1/2] 백엔드 서버 시작 중 (http://localhost:8000)...
cd /d "%DIR%backend"
start /b python -m uvicorn main:app --host 127.0.0.1 --port 8000
timeout /t 3 /nobreak > nul

REM ── 프론트엔드 실행 ──
echo [2/2] 프론트엔드 시작 중 (http://localhost:5173)...
cd /d "%DIR%frontend"
start /b npm run dev

REM ── 포트 5173이 열릴 때까지 대기 ──
echo 브라우저 준비 중...
:wait_loop
timeout /t 1 /nobreak > nul
netstat -ano 2>nul | findstr ":5173 " | findstr "LISTENING" > nul
if errorlevel 1 goto wait_loop

echo.
echo ✓ 앱이 실행되었습니다! (브라우저 창을 닫으면 자동 종료)

REM ── Chrome 앱 모드로 실행 (창 닫힐 때까지 대기) ──
set "CHROME64=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
set "CHROME32=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"

if exist "%CHROME64%" (
    start /wait "" "%CHROME64%" --app=http://localhost:5173 --user-data-dir="%DIR%.ytdl-chrome" --no-first-run --disable-extensions --window-size=1280,800
) else if exist "%CHROME32%" (
    start /wait "" "%CHROME32%" --app=http://localhost:5173 --user-data-dir="%DIR%.ytdl-chrome" --no-first-run --disable-extensions --window-size=1280,800
) else (
    echo Chrome을 찾을 수 없습니다. 기본 브라우저로 엽니다.
    start http://localhost:5173
    pause
)

REM ── 서버 종료 ──
echo.
echo 서버를 종료합니다...
for /f "tokens=5" %%p in ('netstat -ano 2^>nul ^| findstr ":8000 " ^| findstr "LISTENING"') do (
    taskkill /f /pid %%p > nul 2>&1
)
for /f "tokens=5" %%p in ('netstat -ano 2^>nul ^| findstr ":5173 " ^| findstr "LISTENING"') do (
    taskkill /f /pid %%p > nul 2>&1
)

endlocal

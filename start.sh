#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON="python3.12"
UVICORN="$PYTHON -m uvicorn"

echo "==============================="
echo "  YouTube Downloader"
echo "==============================="

# ── 시작 시: 실행 중인 터미널만 감지 (다른 앱은 건드리지 않음) ──
MY_TTY=$(tty 2>/dev/null || echo "")
TERM_WIN_ID=""

case "$TERM_PROGRAM" in
  "Apple_Terminal")
    # Terminal.app이 이 스크립트를 실행 중 → 창 ID 캡처
    TERM_WIN_ID=$(osascript -e 'tell application "Terminal" to return id of front window' 2>/dev/null || echo "")
    ;;
  "iTerm.app")
    # iTerm2가 이 스크립트를 실행 중 → TTY로 식별 (ID 불필요)
    ;;
  # 그 외 터미널은 자동 닫기 미지원
esac

# ── 기존 프로세스 정리 ──
EXISTING=$(lsof -ti TCP:8000 2>/dev/null || true)
if [ -n "$EXISTING" ]; then
  echo "기존 백엔드 프로세스 종료 중..."
  kill $EXISTING 2>/dev/null || true
  sleep 1
fi

# ── 백엔드 실행 ──
echo "[1/2] 백엔드 서버 시작 중 (http://localhost:8000)..."
cd "$DIR/backend"
$UVICORN main:app --host 127.0.0.1 --port 8000 --reload &
BACKEND_PID=$!
echo "      백엔드 PID: $BACKEND_PID"

sleep 2

# ── 프론트엔드 실행 ──
echo "[2/2] 프론트엔드 시작 중 (http://localhost:5173)..."
cd "$DIR/frontend"
npm run dev &
FRONTEND_PID=$!
echo "      프론트엔드 PID: $FRONTEND_PID"

# ── Ctrl+C 등으로 강제 종료 시 서버만 정리 ──
cleanup() {
  trap - EXIT SIGINT SIGTERM
  kill $BACKEND_PID 2>/dev/null || true
  kill $FRONTEND_PID 2>/dev/null || true
}
trap cleanup SIGINT SIGTERM EXIT

# ── 포트가 열릴 때까지 대기 ──
echo ""
echo "브라우저 준비 중..."
for i in $(seq 1 15); do
  if lsof -i TCP:5173 -s TCP:LISTEN &>/dev/null; then
    break
  fi
  sleep 1
done

echo "✓ 앱이 실행되었습니다! (브라우저 창을 닫으면 자동 종료)"

# ── Chrome 앱 모드로 실행 (창 닫힐 때까지 대기) ──
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
if [ -f "$CHROME" ]; then
  "$CHROME" \
    --app="http://localhost:5173" \
    --user-data-dir="$DIR/.ytdl-chrome" \
    --no-first-run \
    --disable-extensions \
    --window-size=1280,800 2>/dev/null || true
else
  open "http://localhost:5173"
  wait
fi

# ── Chrome 종료됨 → 서버 종료 후 터미널 창 닫기 ──
trap - EXIT SIGINT SIGTERM  # 재진입 방지
echo ""
echo "서버를 종료합니다..."
kill $BACKEND_PID 2>/dev/null || true
kill $FRONTEND_PID 2>/dev/null || true
sleep 0.5

# 실행 중인 터미널에 맞게 창 닫기
case "$TERM_PROGRAM" in
  "Apple_Terminal")
    # Terminal.app: 창 ID로 닫기 (iterate → 확실한 매칭)
    if [ -n "$TERM_WIN_ID" ]; then
      osascript -e "
        tell application \"Terminal\"
          repeat with w in windows
            if id of w = $TERM_WIN_ID then
              close w saving no
              exit repeat
            end if
          end repeat
        end tell
      " 2>/dev/null || true
    fi
    ;;
  "iTerm.app")
    # iTerm2: TTY로 해당 세션이 있는 창만 닫기
    if [ -n "$MY_TTY" ]; then
      osascript -e "
        tell application \"iTerm\"
          set myTTY to \"$MY_TTY\"
          repeat with w in windows
            repeat with t in tabs of w
              repeat with s in sessions of t
                if tty of s = myTTY then
                  close w
                  return
                end if
              end repeat
            end repeat
          end repeat
        end tell
      " 2>/dev/null || true
    fi
    ;;
esac

#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON="python3.12"
UVICORN="$PYTHON -m uvicorn"
DEBUGLOG="/tmp/ytdl_debug.log"

echo "==============================="
echo "  YouTube Downloader"
echo "==============================="

# ── 디버그 로그 ──
{
  echo ""
  echo "=== ytdl start $(date) ==="
  echo "TERM_PROGRAM='${TERM_PROGRAM:-}'"
  echo "ITERM_SESSION_ID='${ITERM_SESSION_ID:-}'"
} >> "$DEBUGLOG"

# ── 시작 시: 터미널 종류 감지 & 창 ID 캡처 ──
MY_TTY=$(tty 2>/dev/null) || MY_TTY=""
WIN_APP=""
WIN_ID=""

if [ "${TERM_PROGRAM:-}" = "Apple_Terminal" ]; then
  WIN_APP="Terminal"
  WIN_ID=$(osascript -e 'tell application "Terminal" to return id of front window' 2>/dev/null) || WIN_ID=""

elif [ "${TERM_PROGRAM:-}" = "iTerm.app" ] \
     || [ -n "${ITERM_SESSION_ID:-}" ] \
     || [ -n "${ITERM_PROFILE:-}" ]; then
  WIN_APP="iTerm"
  osascript -e '
    tell application "iTerm"
      tell current session of current window
        set close session on end to true
      end tell
    end tell
  ' 2>/dev/null || true
  if [ -n "$MY_TTY" ]; then
    WIN_ID=$(osascript -e "
      tell application \"iTerm\"
        repeat with w in windows
          repeat with t in tabs of w
            repeat with s in sessions of t
              if tty of s = \"$MY_TTY\" then
                return id of w
              end if
            end repeat
          end repeat
        end repeat
      end tell
    " 2>/dev/null) || WIN_ID=""
  fi
  if [ -z "$WIN_ID" ]; then
    WIN_ID=$(osascript -e 'tell application "iTerm" to return id of first window' 2>/dev/null) || WIN_ID=""
  fi
fi

echo "WIN_APP='$WIN_APP', WIN_ID='$WIN_ID'" >> "$DEBUGLOG"

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
echo "=== [PRE-CHROME] $(date) ===" >> "$DEBUGLOG"
if [ -f "$CHROME" ]; then
  "$CHROME" \
    --app="http://localhost:5173" \
    --user-data-dir="$DIR/.ytdl-chrome" \
    --no-first-run \
    --disable-extensions \
    --window-size=1280,800 2>/dev/null
  CHROME_EXIT=$?
  echo "=== [POST-CHROME exit=$CHROME_EXIT] $(date) ===" >> "$DEBUGLOG"
else
  open "http://localhost:5173"
  wait
fi

# ── Chrome 종료됨 → 정리 시작 ──
set +e
echo "=== [1] Chrome 종료 $(date) ===" >> "$DEBUGLOG"

trap - EXIT SIGINT SIGTERM
echo "=== [2] trap 해제 ===" >> "$DEBUGLOG"

echo ""
echo "서버를 종료합니다..."
kill $BACKEND_PID 2>/dev/null
echo "=== [3] backend kill ===" >> "$DEBUGLOG"
kill $FRONTEND_PID 2>/dev/null
echo "=== [4] frontend kill ===" >> "$DEBUGLOG"
pkill -f "ytdl-chrome" 2>/dev/null
echo "=== [5] pkill done ===" >> "$DEBUGLOG"
sleep 1
echo "=== [6] sleep done ===" >> "$DEBUGLOG"

# ── 터미널 창 닫기 ──
echo "=== [7] close section WIN_APP='$WIN_APP', WIN_ID='$WIN_ID' ===" >> "$DEBUGLOG"

if [ -n "$WIN_APP" ] && [ -n "$WIN_ID" ]; then
  echo "$WIN_ID"  > /tmp/ytdl_winid.txt
  echo "$WIN_APP" > /tmp/ytdl_winapp.txt

  cat > /tmp/ytdl_close.sh << 'CLOSESCRIPT'
#!/bin/bash
sleep 0.8
WIN_ID=$(cat /tmp/ytdl_winid.txt 2>/dev/null)
WIN_APP=$(cat /tmp/ytdl_winapp.txt 2>/dev/null)
LOGFILE=/tmp/ytdl_debug.log
echo "=== ytdl_close $(date) APP='$WIN_APP' ID='$WIN_ID' ===" >> "$LOGFILE"
if [ -n "$WIN_ID" ] && [ -n "$WIN_APP" ]; then
  result=$(osascript 2>&1 << OSASCRIPT
tell application "$WIN_APP"
  repeat with w in windows
    if id of w = $WIN_ID then
      close w
      return "closed"
    end if
  end repeat
  return "not found"
end tell
OSASCRIPT
)
  echo "osascript: $result" >> "$LOGFILE"
else
  echo "params empty" >> "$LOGFILE"
fi
rm -f /tmp/ytdl_winid.txt /tmp/ytdl_winapp.txt /tmp/ytdl_close.sh
CLOSESCRIPT

  chmod +x /tmp/ytdl_close.sh
  echo "=== [8] launching nohup ===" >> "$DEBUGLOG"
  nohup bash /tmp/ytdl_close.sh >> "$DEBUGLOG" 2>&1 &
  disown
  echo "=== [9] nohup pid=$! ===" >> "$DEBUGLOG"
else
  echo "=== [7b] WIN_APP or WIN_ID empty, skip ===" >> "$DEBUGLOG"
fi

echo "=== [10] exit 0 ===" >> "$DEBUGLOG"
exit 0

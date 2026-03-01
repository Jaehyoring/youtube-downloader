#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON="python3.12"
UVICORN="$PYTHON -m uvicorn"
DEBUGLOG="/tmp/ytdl_debug.log"

echo "==============================="
echo "  YouTube Downloader"
echo "==============================="

# ── 디버그 로그 (닫기 문제 진단용) ──
{
  echo ""
  echo "=== ytdl start $(date) ==="
  echo "TERM_PROGRAM='${TERM_PROGRAM:-}'"
  echo "ITERM_SESSION_ID='${ITERM_SESSION_ID:-}'"
  echo "ITERM_PROFILE='${ITERM_PROFILE:-}'"
} >> "$DEBUGLOG"

# ── 시작 시: 실행 중인 터미널 감지 ──
MY_TTY=$(tty 2>/dev/null) || MY_TTY=""
ITERM_WIN_ID=""

# iTerm2 감지: TERM_PROGRAM / ITERM_SESSION_ID / ITERM_PROFILE 중 하나라도 있으면 iTerm2
IN_ITERM=false
if [ "${TERM_PROGRAM:-}" = "iTerm.app" ] \
   || [ -n "${ITERM_SESSION_ID:-}" ] \
   || [ -n "${ITERM_PROFILE:-}" ]; then
  IN_ITERM=true
fi
echo "MY_TTY='$MY_TTY', IN_ITERM=$IN_ITERM" >> "$DEBUGLOG"

if [ "$IN_ITERM" = "true" ]; then
  # ── 방법0: 현재 세션 "종료 시 자동 닫기" 설정 (가장 우아한 해결책) ──
  # iTerm2 Profile > "When a session ends" 설정을 세션별로 런타임에 override
  cse_result=$(osascript -e '
    tell application "iTerm"
      tell current session of current window
        set close session on end to true
      end tell
      return "ok"
    end tell
  ' 2>&1) || cse_result="error"
  echo "close session on end: $cse_result" >> "$DEBUGLOG"

  # ── 방법1: TTY로 창 ID 찾기 (세션 활성 상태에서 가장 정확) ──
  if [ -n "$MY_TTY" ]; then
    ITERM_WIN_ID=$(osascript -e "
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
    " 2>/dev/null) || ITERM_WIN_ID=""
  fi

  # ── 방법2: TTY 방식 실패 시 frontmost 창 ID ──
  if [ -z "$ITERM_WIN_ID" ]; then
    ITERM_WIN_ID=$(osascript -e 'tell application "iTerm" to return id of first window' 2>/dev/null) || ITERM_WIN_ID=""
  fi
fi
echo "ITERM_WIN_ID='$ITERM_WIN_ID'" >> "$DEBUGLOG"

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

# ── Chrome 종료됨 → 모든 프로세스 종료 ──
trap - EXIT SIGINT SIGTERM  # 재진입 방지
echo ""
echo "서버를 종료합니다..."

kill $BACKEND_PID 2>/dev/null || true
kill $FRONTEND_PID 2>/dev/null || true
# Chrome 관련 잔여 프로세스(Helper 등) 정리
pkill -f "ytdl-chrome" 2>/dev/null || true
# 모든 프로세스가 완전히 종료될 때까지 대기
sleep 1

# ── 터미널 창 닫기 ──
# Terminal.app: exit 0 → shellExitAction=2 → 자동 닫힘 (AppleScript 불필요)
# iTerm2: ① close session on end (설정됨, exit 0으로 자동 닫힘)
#         ② nohup 백업 (창 ID로 강제 닫기)
echo "=== close $(date) ===" >> "$DEBUGLOG"
echo "IN_ITERM=$IN_ITERM, ITERM_WIN_ID='$ITERM_WIN_ID'" >> "$DEBUGLOG"

if [ "$IN_ITERM" = "true" ] && [ -n "$ITERM_WIN_ID" ]; then
  # 창 ID를 파일로 전달 (quoting 문제 완전 회피)
  echo "$ITERM_WIN_ID" > /tmp/ytdl_winid.txt

  # close script를 파일로 생성 (single-quoted heredoc = 내부 변수 미치환)
  # 내부의 $WIN_ID는 close script 실행 시 치환됨
  cat > /tmp/ytdl_close.sh << 'CLOSESCRIPT'
#!/bin/bash
sleep 0.8
WIN_ID=$(cat /tmp/ytdl_winid.txt 2>/dev/null)
LOGFILE=/tmp/ytdl_debug.log
echo "=== ytdl_close $(date) WIN_ID='$WIN_ID' ===" >> "$LOGFILE"
if [ -n "$WIN_ID" ]; then
  result=$(osascript 2>&1 << OSASCRIPT
tell application "iTerm"
  set winCount to count of windows
  repeat with w in windows
    if (id of w) = $WIN_ID then
      close w
      return "closed"
    end if
  end repeat
  return "not found (total windows: " & (winCount as string) & ")"
end tell
OSASCRIPT
)
  echo "osascript: $result" >> "$LOGFILE"
else
  echo "WIN_ID empty!" >> "$LOGFILE"
fi
rm -f /tmp/ytdl_winid.txt /tmp/ytdl_close.sh
CLOSESCRIPT

  chmod +x /tmp/ytdl_close.sh
  echo "Launching nohup /tmp/ytdl_close.sh" >> "$DEBUGLOG"
  nohup bash /tmp/ytdl_close.sh >> "$DEBUGLOG" 2>&1 &
  disown
  echo "nohup launched (pid=$!)" >> "$DEBUGLOG"

elif [ "$IN_ITERM" = "true" ]; then
  echo "IN_ITERM=true but ITERM_WIN_ID empty → relying on 'close session on end'" >> "$DEBUGLOG"
fi

exit 0

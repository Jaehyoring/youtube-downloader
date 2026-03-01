#!/bin/bash
# YouTube Downloader — macOS 설치 스크립트

set -e

echo "==============================="
echo "  YouTube Downloader 설치"
echo "==============================="

# ── Homebrew 확인 ──
if ! command -v brew &>/dev/null; then
  echo "❌ Homebrew가 필요합니다: https://brew.sh"
  exit 1
fi

# ── Python 3.12 ──
echo "[1/5] Python 3.12 확인 중..."
if ! command -v python3.12 &>/dev/null; then
  echo "  Python 3.12 설치 중..."
  brew install python@3.12
fi
echo "  ✓ Python 3.12: $(python3.12 --version)"

# ── Node.js ──
echo "[2/5] Node.js 확인 중..."
if ! command -v node &>/dev/null; then
  echo "  Node.js 설치 중..."
  brew install node
fi
echo "  ✓ Node.js: $(node --version)"

# ── ffmpeg ──
echo "[3/5] ffmpeg 확인 중..."
if ! command -v ffmpeg &>/dev/null; then
  echo "  ffmpeg 설치 중..."
  brew install ffmpeg
fi
echo "  ✓ ffmpeg: $(ffmpeg -version 2>&1 | head -1)"

# ── Python 의존성 ──
echo "[4/5] Python 패키지 설치 중..."
python3.12 -m pip install --break-system-packages --quiet \
  fastapi uvicorn yt-dlp yt-dlp-ejs
echo "  ✓ fastapi, uvicorn, yt-dlp, yt-dlp-ejs"

# ── 프론트엔드 의존성 ──
echo "[5/5] 프론트엔드 패키지 설치 중..."
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR/frontend" && npm install --silent
echo "  ✓ npm 패키지"

# ── alias 등록 ──
ALIAS_CMD="alias ytdl='$DIR/start.sh'"
ZSHRC="$HOME/.zshrc"
if ! grep -q "alias ytdl=" "$ZSHRC" 2>/dev/null; then
  echo "" >> "$ZSHRC"
  echo "# YouTube Downloader" >> "$ZSHRC"
  echo "$ALIAS_CMD" >> "$ZSHRC"
  echo "  ✓ alias 'ytdl' 등록 완료 (~/.zshrc)"
else
  echo "  ✓ alias 'ytdl' 이미 등록됨"
fi

echo ""
echo "==============================="
echo "  설치 완료!"
echo "==============================="
echo ""
echo "새 터미널을 열고 아래 명령어로 실행하세요:"
echo "  ytdl"
echo ""
echo "또는 지금 바로:"
echo "  source ~/.zshrc && ytdl"

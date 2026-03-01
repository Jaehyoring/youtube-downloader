# CLAUDE.md — YouTube Downloader 개발 노트

## 프로젝트 개요

YouTube 영상/오디오를 다운로드하는 로컬 웹 앱.
React 프론트엔드 + Python FastAPI 백엔드로 구성되며, yt-dlp를 다운로드 엔진으로 사용한다.

---

## 기술 스택

| 구분 | 기술 |
|------|------|
| 백엔드 | Python 3.12 + FastAPI 0.115 + uvicorn |
| 다운로드 엔진 | yt-dlp 2026.02.21 |
| JS 챌린지 해결 | yt-dlp-ejs + Node.js (`/usr/local/bin/node`) |
| 미디어 처리 | ffmpeg (`/opt/homebrew/bin/ffmpeg`) |
| 프론트엔드 | React 18 + Vite 7 |
| 진행률 스트리밍 | SSE (Server-Sent Events) |

---

## 핵심 경로

```
youtube_downloader/
├── backend/
│   ├── main.py          # FastAPI 앱 (포트 8000)
│   ├── downloader.py    # yt-dlp 래퍼 + SSE 스트리밍
│   └── requirements.txt
├── frontend/            # React + Vite (포트 5173)
│   └── src/
│       ├── App.jsx
│       ├── api.js
│       ├── utils.js
│       └── components/
│           ├── VideoInfo.jsx
│           ├── ProgressBar.jsx
│           └── HistoryList.jsx
├── downloads/           # 다운로드된 파일
│   └── .history.json    # 최근 다운로드 이력 (최대 50개)
├── start.sh             # 실행 스크립트
└── CLAUDE.md
```

---

## 실행 방법

```bash
# 터미널 어디서든 실행 가능 (alias 등록 필요)
ytdl
```

### alias 등록 (최초 1회)

```bash
echo "alias ytdl='~/Desktop/VibeCoding/youtube_downloader/start.sh'" >> ~/.zshrc
source ~/.zshrc
```

### start.sh 동작 흐름

1. 포트 8000에 기존 프로세스가 있으면 종료
2. Python 3.12로 uvicorn 백엔드 시작
3. npm run dev로 Vite 프론트엔드 시작
4. 포트 5173이 열리면 Chrome 앱 모드로 자동 실행
5. Chrome 창을 닫으면 백엔드/프론트엔드 자동 종료

---

## API 엔드포인트

| Method | Path | 설명 |
|--------|------|------|
| GET | `/api/health` | 헬스 체크 |
| GET | `/api/info?url=...` | 영상 메타데이터 조회 |
| POST | `/api/download` | SSE 스트림 다운로드 |
| GET | `/api/history` | 최근 다운로드 목록 |
| DELETE | `/api/history` | 이력 전체 삭제 |
| DELETE | `/api/history/{index}` | 이력 개별 삭제 |
| GET | `/api/open?path=...` | Finder에서 파일 열기 |

---

## 주요 문제 해결 기록

### 1. "The downloaded file is empty" 오류
- **원인**: yt-dlp가 HLS 포맷(m3u8)을 선택해 다운로드했으나 파일이 비어있음
- **해결**: yt-dlp를 2026.02.21로 업그레이드 + Python 3.12 사용

### 2. HTTP 403 오류 (한국 영상)
- **원인**: YouTube가 2026년부터 모든 영상에 JavaScript 챌린지(nsig/sig) 적용
  - yt-dlp 2025.x는 캐시된 플레이어로 우회했으나 만료됨
- **해결**: yt-dlp 2026.02.21 + yt-dlp-ejs + Node.js EJS 런타임
  ```python
  "js_runtimes": {"node": {"path": "/usr/local/bin/node"}}
  ```
- **Python 버전**: yt-dlp 2026.02.21은 Python 3.10+ 필요 → Python 3.12 사용

### 3. Python 3.9 비호환
- **원인**: 기존 uvicorn이 Python 3.9 바이너리 사용
- **해결**: `start.sh`에서 `python3.12 -m uvicorn`으로 변경

### 4. "Failed to fetch" (이벤트 루프 블로킹)
- **원인**: `get_video_info()`가 동기 함수인데 async 라우터에서 직접 호출
  → 이벤트 루프 블로킹 → 다른 요청 처리 불가
- **해결**: `await asyncio.to_thread(get_video_info, url)`으로 스레드 풀 실행

### 5. 포트 충돌 (Address already in use)
- **원인**: 이전 백엔드 프로세스가 포트 8000 점유
- **해결**: `start.sh` 시작 시 기존 프로세스 자동 종료
  ```bash
  EXISTING=$(lsof -ti TCP:8000 2>/dev/null || true)
  if [ -n "$EXISTING" ]; then kill $EXISTING; fi
  ```

### 6. start.sh가 즉시 종료되는 문제
- **원인**: `set -e` 설정 시 `lsof`가 프로세스 없으면 exit code 1 반환 → 스크립트 종료
- **해결**: `lsof ... || true`로 오류 무시

---

## yt-dlp 설정 (downloader.py)

```python
ydl_opts = {
    "format": format_selector,
    "outtmpl": outtmpl,
    "progress_hooks": [progress_hook],
    "quiet": True,
    "no_warnings": True,
    "ffmpeg_location": "/opt/homebrew/bin",
    "merge_output_format": format_type if format_type != "mp3" else None,
    # Node.js로 YouTube JS 챌린지(nsig/sig) 해결
    "js_runtimes": {"node": {"path": "/usr/local/bin/node"}},
    **cookies_opts,  # Chrome 쿠키 자동 사용
}
```

---

## 의존성 설치 (최초 1회)

```bash
# Python 3.12 의존성
python3.12 -m pip install --break-system-packages fastapi uvicorn yt-dlp yt-dlp-ejs

# Node.js (EJS 챌린지 해결용)
brew install node

# ffmpeg (영상/오디오 병합)
brew install ffmpeg

# 프론트엔드
cd frontend && npm install
```

# YouTube Downloader

YouTube 영상과 오디오를 손쉽게 다운로드하는 로컬 웹 앱입니다.

## 기능

- **영상 다운로드**: MP4, WebM 포맷 지원
- **오디오 추출**: MP3 변환
- **해상도 선택**: 최고화질 / 1080p / 720p / 480p / 360p
- **영상 정보 미리보기**: 썸네일, 제목, 재생 시간, 채널명
- **실시간 진행률**: 다운로드 진행률 스트리밍 표시
- **다운로드 이력**: 최근 50개 이력 관리 (개별/전체 삭제)
- **Finder 연동**: 다운로드된 파일을 바로 Finder에서 열기
- **Chrome 앱 모드**: 창 닫으면 서버 자동 종료

## 요구사항

- macOS
- Python 3.12+
- Node.js
- Google Chrome
- ffmpeg

## 설치

```bash
# 1. 의존성 설치
python3.12 -m pip install --break-system-packages fastapi uvicorn yt-dlp yt-dlp-ejs
brew install node ffmpeg
cd frontend && npm install && cd ..

# 2. alias 등록 (최초 1회)
echo "alias ytdl='~/Desktop/VibeCoding/youtube_downloader/start.sh'" >> ~/.zshrc
source ~/.zshrc
```

## 실행

```bash
ytdl
```

- Chrome 앱 창이 자동으로 열립니다
- 창을 닫으면 서버도 자동으로 종료됩니다

## 사용법

1. YouTube URL을 입력창에 붙여넣기
2. **정보 가져오기** 클릭으로 영상 정보 확인
3. 포맷(MP4/WebM/MP3)과 해상도 선택
4. **다운로드** 클릭
5. 완료 후 **열기** 버튼으로 Finder에서 파일 확인

> **참고**: Chrome 브라우저에서 YouTube에 로그인한 상태여야 일부 영상을 다운로드할 수 있습니다.

## 프로젝트 구조

```
youtube_downloader/
├── backend/
│   ├── main.py          # FastAPI 서버 (포트 8000)
│   ├── downloader.py    # yt-dlp 래퍼
│   └── requirements.txt
├── frontend/            # React + Vite (포트 5173)
│   └── src/
├── downloads/           # 다운로드 파일 저장 위치
├── start.sh             # 실행 스크립트
└── CLAUDE.md            # 개발 노트
```

## 기술 스택

- **백엔드**: Python 3.12 · FastAPI · yt-dlp 2026.02.21 · yt-dlp-ejs
- **프론트엔드**: React 18 · Vite 7
- **스트리밍**: Server-Sent Events (SSE)

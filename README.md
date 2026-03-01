# YouTube Downloader

YouTube 영상과 오디오를 손쉽게 다운로드하는 로컬 웹 앱입니다.
macOS와 Windows 모두 지원합니다.

## 기능

- **영상 다운로드**: MP4, WebM 포맷 지원
- **오디오 추출**: MP3 변환
- **해상도 선택**: 최고화질 / 1080p / 720p / 480p / 360p
- **영상 정보 미리보기**: 썸네일, 제목, 재생 시간, 채널명
- **실시간 진행률**: 다운로드 진행률 스트리밍 표시
- **다운로드 이력**: 최근 50개 이력 관리 (개별/전체 삭제)
- **Finder / 탐색기 연동**: 다운로드된 파일을 바로 열기
- **Chrome 앱 모드**: 창 닫으면 서버 자동 종료

---

## 설치 (최초 1회)

### macOS

```bash
# 1. 저장소 다운로드
git clone https://github.com/Jaehyoring/youtube-downloader.git
cd youtube-downloader

# 2. 설치 스크립트 실행 (Homebrew 필요)
chmod +x setup.sh && ./setup.sh
```

> **Homebrew 미설치 시**: https://brew.sh 에서 먼저 설치

### Windows

```
1. 저장소를 ZIP으로 다운로드 후 압축 해제
   https://github.com/Jaehyoring/youtube-downloader/archive/refs/heads/main.zip

2. setup.bat 더블클릭 (Python, Node.js, ffmpeg 자동 설치)
   - 설치 후 새 터미널에서 setup.bat을 한 번 더 실행

3. 설치 완료!
```

> **주의**: 설치 중 "PATH 적용을 위해 새 터미널에서 다시 실행" 메시지가 나오면
> 새 명령 프롬프트를 열고 `setup.bat`을 다시 실행하세요.

---

## 실행

### macOS
```bash
ytdl
```

### Windows
```
start.bat 더블클릭
```

- Chrome 앱 창이 자동으로 열립니다
- 창을 닫으면 서버도 자동으로 종료됩니다

---

## 사용법

1. YouTube URL을 입력창에 붙여넣기
2. **정보 가져오기** 클릭으로 영상 정보 확인
3. 포맷(MP4/WebM/MP3)과 해상도 선택
4. **다운로드** 클릭
5. 완료 후 **열기** 버튼으로 파일 위치 확인

> **참고**: Chrome 브라우저에서 YouTube에 로그인한 상태여야 일부 영상(한국 영상 등)을 다운로드할 수 있습니다.

---

## 요구사항

| 항목 | macOS | Windows |
|------|-------|---------|
| Python | 3.12+ | 3.12+ |
| Node.js | LTS | LTS |
| ffmpeg | Homebrew | winget |
| 브라우저 | Google Chrome | Google Chrome / Edge |

---

## 프로젝트 구조

```
youtube_downloader/
├── backend/
│   ├── main.py          # FastAPI 서버 (포트 8000)
│   ├── downloader.py    # yt-dlp 래퍼 (OS별 경로 자동 탐지)
│   └── requirements.txt
├── frontend/            # React + Vite (포트 5173)
│   └── src/
├── downloads/           # 다운로드 파일 저장 위치
├── start.sh             # macOS 실행 스크립트
├── start.bat            # Windows 실행 스크립트
├── setup.sh             # macOS 설치 스크립트
├── setup.bat            # Windows 설치 스크립트
└── CLAUDE.md            # 개발 노트
```

---

## 기술 스택

- **백엔드**: Python 3.12 · FastAPI · yt-dlp 2026+ · yt-dlp-ejs
- **프론트엔드**: React 18 · Vite 7
- **스트리밍**: Server-Sent Events (SSE)
- **JS 챌린지**: Node.js EJS (YouTube nsig/sig 해결)
